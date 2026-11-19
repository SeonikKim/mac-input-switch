using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

public sealed class AbkoKeyboard
{
    [StructLayout(LayoutKind.Sequential)] private struct MouseInput
    { public int X, Y; public uint Data, Flags, Time; public IntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] private struct KeyInput
    { public ushort VirtualKey, Scan; public uint Flags, Time; public IntPtr Extra; }
    [StructLayout(LayoutKind.Explicit)] private struct InputData
    {
        [FieldOffset(0)] public MouseInput Mouse;
        [FieldOffset(0)] public KeyInput Key;
    }
    [StructLayout(LayoutKind.Sequential)] private struct Input
    { public uint Type; public InputData Data; }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")]
    private static extern bool SystemParametersInfo(uint action, uint parameter, out uint value, uint flags);

    private static readonly ushort[] Letters = {
        0x1e, 0x30, 0x2e, 0x20, 0x12, 0x21, 0x22, 0x23, 0x17, 0x24, 0x25, 0x26, 0x32,
        0x31, 0x18, 0x19, 0x10, 0x13, 0x1f, 0x14, 0x16, 0x2f, 0x11, 0x2d, 0x15, 0x2c
    };
    private static readonly ushort[] StandardKeys = {
        0x1c, 0x01, 0x0e, 0x0f, 0x39, 0x0c, 0x0d, 0x1a, 0x1b, 0x2b, 0x56, 0x27, 0x28,
        0x29, 0x33, 0x34, 0x35, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x40, 0x41, 0x42,
        0x43, 0x44, 0x57, 0x58, 0xe037, 0x46, 0, 0xe052, 0xe047, 0xe049, 0xe053, 0xe04f,
        0xe051, 0xe04d, 0xe04b, 0xe050, 0xe048, 0x45, 0xe035, 0x37, 0x4a, 0x4e, 0xe01c,
        0x4f, 0x50, 0x51, 0x4b, 0x4c, 0x4d, 0x47, 0x48, 0x49, 0x52, 0x53, 0x56, 0xe05d
    };
    private static readonly ushort[] Modifiers = {0x1d, 0x2a, 0x38, 0xe05b, 0xe01d, 0x36, 0xe038, 0xe05c};

    private readonly HashSet<int> pressed = new HashSet<int>();
    private readonly object gate = new object();
    private int repeatKey;
    private Timer repeat;
    public Thread Start(StreamReader reader)
    {
        var thread = new Thread(() => Run(reader));
        thread.IsBackground = true;
        thread.Start();
        return thread;
    }

    private void Run(StreamReader reader)
    {
        repeat = new Timer(Repeat);
        try
        {
            string line;
            while ((line = reader.ReadLine()) != null)
            {
                if (line == "RESET") { Release(); continue; }
                var words = line.Split(' ');
                int usage;
                if (words.Length != 3 || words[0] != "KEY" || !int.TryParse(words[1], out usage)
                    || (words[2] != "0" && words[2] != "1")) continue;
                bool down = words[2] == "1";
                lock (gate)
                {
                    if (down ? !pressed.Add(usage) : !pressed.Remove(usage)) continue;
                    Inject(usage, down);
                    if (down && Repeats(usage))
                    {
                        uint delay, speed;
                        if (!SystemParametersInfo(0x0016, 0, out delay, 0)) delay = 1;
                        if (!SystemParametersInfo(0x000a, 0, out speed, 0)) speed = 20;
                        repeatKey = usage;
                        repeat.Change(250 * (1 + (int)delay), 1000 / (3 + 27 * (int)speed / 31));
                    }
                    else if (!down && usage == repeatKey) StopRepeat();
                }
            }
        }
        catch (IOException) { }
        finally { Release(); repeat.Dispose(); }
    }

    private static bool Repeats(int usage)
    {
        return (usage >= 4 && usage <= 0x38) || (usage >= 0x49 && usage <= 0x52)
            || (usage >= 0x54 && usage <= 0x63);
    }

    private void Repeat(object unused)
    {
        lock (gate)
            if (repeatKey != 0) Inject(repeatKey, true);
    }

    private void StopRepeat()
    {
        repeatKey = 0;
        repeat.Change(Timeout.Infinite, Timeout.Infinite);
    }

    private void Release()
    {
        lock (gate)
        {
            StopRepeat();
            foreach (int key in pressed) Inject(key, false);
            pressed.Clear();
        }
    }

    private static void Inject(int usage, bool down)
    {
        var key = new KeyInput { Flags = down ? 0u : 2u };
        if (usage == 0x90) key.VirtualKey = 0x15;
        else if (usage == 0x91) key.VirtualKey = 0x19;
        else
        {
            ushort scan;
            if (usage >= 4 && usage <= 29) scan = Letters[usage - 4];
            else if (usage >= 30 && usage <= 39) scan = (ushort)(usage - 28);
            else if (usage >= 40 && usage < 40 + StandardKeys.Length) scan = StandardKeys[usage - 40];
            else if (usage >= 0xe0 && usage <= 0xe7) scan = Modifiers[usage - 0xe0];
            else return;
            if (scan == 0) return;
            key.Scan = (ushort)(scan & 0xff);
            key.Flags |= scan > 0xff ? 9u : 8u;
        }
        SendInput(1, new[] { new Input { Type = 1, Data = new InputData { Key = key } } }, Marshal.SizeOf(typeof(Input)));
    }
}
