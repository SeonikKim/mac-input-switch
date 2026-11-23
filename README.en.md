# Mac Input Switch

[한국어](README.md)

**Let your Bluetooth keyboard follow your Logitech mouse between macOS and Windows.** Move the pointer across a screen edge with Logitech Flow or press the mouse’s Easy-Switch button. The keyboard stays paired to the Mac, and its input follows the mouse’s active Bluetooth connection over SSH.

## Quick start

1. Set up a Logitech Bluetooth mouse and a standard Bluetooth HID keyboard. Pair the keyboard to your Mac on any channel. Enable Logitech Flow on your Mac and Windows PC for screen-edge switching. Confirm that Windows can SSH into the Mac with a key and that you have verified its host key.
2. Put this project in `~/Applications/MacInputSwitch` on the Mac. Install Python 3.8 or later and Apple Command Line Tools. Allow your terminal app under **System Settings → Privacy & Security → Input Monitoring**, then reopen the terminal. [Apple input monitoring instructions](https://support.apple.com/en-asia/guide/mac-help/mchl4cedafb6/27/mac/27)
3. Double-click `Start-KeyboardRelay.command` or run the command below. Choose **English** or **한국어** when prompted, then enter your administrator password in the Mac terminal. Once the launcher says you can close the window, the relay keeps running in the background.

   ```bash
   /bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command
   ```

4. Put `Connect-KeyboardRelay.ps1` and `AbkoKeyboard.cs` in the same folder on Windows. Run the following from Windows PowerShell 5.1 with your SSH address and identity file. Choose a language when prompted.

   ```powershell
   .\Connect-KeyboardRelay.ps1 -Mac user@mac-host -IdentityFile "$env:USERPROFILE\.ssh\your_key" -Slot first
   ```

5. Use Logitech Flow or the Easy-Switch button to move the mouse to Windows. If Deskflow is active for the same two computers, stop its Windows client to avoid duplicate mouse input.

### Manage the Mac background relay

Open the same launcher again to check whether the relay is running. Run the launcher again after restarting your Mac.

```bash
/bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command --status
/bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command --stop
```

The launcher writes status messages to `KeyboardRelay.log` in the project folder. Use `--foreground` to troubleshoot in the terminal and stop that session with Ctrl+C. When upgrading from a relay already running in a terminal, stop it with Ctrl+C before starting the new version.

### Start the Windows relay at sign-in

Keep the Windows relay files in a permanent folder and run your usual command once with `-InstallStartup`. The relay starts in the background the next time you sign in to this Windows account. Register it again if the Mac address, SSH key path, or mouse model changes.

```powershell
.\Connect-KeyboardRelay.ps1 -Mac user@mac-host -IdentityFile "$env:USERPROFILE\.ssh\your_key" -Slot first -InstallStartup
```

To start it now, stop any manually launched Windows relay and run **MacInputSwitch Desktop Relay** in Task Scheduler. The task for `-Slot second` is **MacInputSwitch Second Relay**. Disable the task in Task Scheduler to turn off automatic startup.

After a Mac restart, sign in and open `Start-KeyboardRelay.command` again. The Mac startup service cannot reuse Terminal's HID permission, so automatic startup on macOS is still pending. While the Mac relay is running, it retries when the keyboard is unavailable and clears Windows peers that stop reporting their status.

## Device selection

- **Keyboard.** The relay selects a single connected Bluetooth HID keyboard on the Mac. If several are connected, it gives priority to one ACH105 for compatibility with existing setups. To select an AULA keyboard or another model, run `Start-KeyboardRelay.command --list-keyboards`, then start with `--keyboard "device name"`. If two indistinguishable keyboards are connected, disconnect one before starting.
- **Mouse.** MX Master 4 is the default. For another Logitech Bluetooth model, run `Start-KeyboardRelay.command --list-mice` while the mouse is connected to the Mac. Pass its model as `--mouse "device name"` on the Mac and `-MouseName "device name"` on Windows. Use `-LocalMouseName` if Windows displays a different name for the same model. Flow-capable models can use screen-edge switching. Easy-Switch models can use their physical channel button. Bolt and Unifying receiver presence detection is outside the current support scope.
- **Channels.** Bluetooth channel numbers do not have to match across devices. `-Slot first` and `-Slot second` identify the Windows clients in the relay rather than Bluetooth channel numbers.

## Change language

The first interactive launch offers English and Korean. Each computer remembers its selection. To save a new language without starting the relay, run one of these commands. Use `ko` for Korean.

```bash
/bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command --set-language en
```

```powershell
.\Connect-KeyboardRelay.ps1 -SetLanguage -Language en
```

To choose the language while starting, use `--language en` on the Mac or `-Language en` on Windows.

## Verified setup and limits

The hardware test used an Apple Silicon Mac mini, a Windows desktop, an MX Master 4, and an ABKO ACH105. It covered switching to Windows with the mouse button, typing in Korean and English, and returning to the Mac across the screen edge. AULA and other device combinations still need hardware reports. The relay logs connection status and uses regular Windows input privileges. [Windows input limitations](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-sendinput)

For the included Deskflow setup and HID++ diagnostic, see the [Korean guide](README.md). To report a tested pairing, include your device models, OS versions, Bluetooth connection type, and observed result. [GitHub issues](https://github.com/SeonikKim/mac-input-switch/issues)
