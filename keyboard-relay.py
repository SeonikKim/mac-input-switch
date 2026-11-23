"""Route a Bluetooth keyboard over SSH to the host with the Logitech mouse."""

import argparse
import base64
import binascii
import errno
import fcntl
import os
import pwd
import selectors
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

BASE = Path.home() / "Applications" / "MacInputSwitch"
SOCKET = BASE / "keyboard.sock"
HID_HELPER = BASE / "bin" / "abko-access"
LEASE = 2.5
PEER_TIMEOUT = 6.0
KEYBOARD_RETRY = 1.0
DEFAULT_MOUSE = "mx master 4"


def say(english, korean):
    print(korean if os.environ.get("MAC_INPUT_SWITCH_LANG") == "ko" else english, flush=True)


def mouse_model(name):
    name = name.strip().lower()
    for prefix in ("logitech ", "logi "):
        if name.startswith(prefix):
            name = name[len(prefix):]
            break
    return DEFAULT_MOUSE if name == DEFAULT_MOUSE + " b" else name


def peer_slot(line, expected_mouse):
    parts = line.split(b" ")
    if len(parts) not in (2, 3) or parts[0] != b"HELLO" or parts[1] not in (b"first", b"second"):
        return None
    name = DEFAULT_MOUSE
    if len(parts) == 3:
        try:
            name = mouse_model(base64.b64decode(parts[2], validate=True).decode("utf-8"))
        except (binascii.Error, UnicodeError):
            return None
    return parts[1].decode("ascii") if name == expected_mouse else None


def mouse_is_local(name):
    try:
        result = subprocess.run(
            [str(HID_HELPER), "mouse", name],
            stdout=subprocess.DEVNULL, timeout=0.8,
        )
    except (OSError, subprocess.SubprocessError):
        return True
    # Only a successful enumeration with no matching local mouse enables routing.
    return result.returncode != 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--keyboard", help="Bluetooth product or model name")
    parser.add_argument("--mouse", default=DEFAULT_MOUSE, help="Logitech Bluetooth mouse model")
    parser.add_argument("--language", choices=("en", "ko"), help=argparse.SUPPRESS)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--status", action="store_true")
    mode.add_argument("--stop", action="store_true")
    mode.add_argument("--background", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.language:
        os.environ["MAC_INPUT_SWITCH_LANG"] = args.language
    if args.status or args.stop:
        return control(args.stop)
    mouse = mouse_model(args.mouse)
    if not mouse or len(mouse.encode("utf-8")) > 240:
        parser.error("--mouse requires a Bluetooth model name of up to 240 UTF-8 bytes")
    if args.background:
        return start_background(args.keyboard, mouse)
    serve(args.keyboard, mouse)
    return 0


def control(stop):
    try:
        with socket.socket(socket.AF_UNIX) as client:
            client.settimeout(4)
            client.connect(str(SOCKET))
            client.sendall(b"STOP\n" if stop else b"STATUS\n")
            if client.recv(32) != b"OK\n":
                raise OSError("Relay does not support background controls.")
    except OSError as error:
        if error.errno in (errno.ENOENT, errno.ECONNREFUSED):
            say("Keyboard relay is stopped.", "키보드 중계가 중지되어 있습니다.")
            return 0 if stop else 1
        say(f"Relay command failed: {error}", f"중계 명령을 실행하지 못했습니다. {error}")
        return 1
    if stop:
        deadline = time.monotonic() + 4
        while SOCKET.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        if SOCKET.exists():
            say("Relay is still stopping.", "키보드 중계를 종료하는 중입니다.")
            return 1
    say("Keyboard relay stopped." if stop else "Keyboard relay is running.",
        "키보드 중계를 종료했습니다." if stop else "키보드 중계가 실행 중입니다.")
    return 0


def start_background(keyboard, mouse):
    global SOCKET, HID_HELPER
    uid = int(os.environ.get("SUDO_UID", "0"))
    if os.geteuid() != 0 or not uid:
        raise SystemExit("Start background mode through Start-KeyboardRelay.command.")
    account = pwd.getpwuid(uid)
    base = Path(account.pw_dir) / "Applications" / "MacInputSwitch"
    reader, writer = os.pipe()
    if os.fork():
        os.close(writer)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(reader, selectors.EVENT_READ)
                ready = selector.select(10) and os.read(reader, 1) == b"1"
        finally:
            os.close(reader)
        if ready:
            say("Keyboard relay started. You can close this window.", "키보드 중계를 시작했습니다. 이 창을 닫아도 됩니다.")
            return 0
        say("Keyboard relay could not start. See KeyboardRelay.log.", "키보드 중계를 시작하지 못했습니다. KeyboardRelay.log를 확인하세요.")
        return 1

    os.close(reader)
    grabber = None
    try:
        os.setsid()
        # The HID process keeps administrator privileges. The network relay and log run as the desktop user.
        with open(os.devnull, "r+b", buffering=0) as null:
            for fd in (0, 1, 2):
                os.dup2(null.fileno(), fd)
        grabber = start_hid(base / "bin" / "abko-access", keyboard, elevated=True)
        os.initgroups(account.pw_name, account.pw_gid)
        os.setgid(account.pw_gid)
        os.setuid(uid)
        os.environ["HOME"] = account.pw_dir
        SOCKET = base / "keyboard.sock"
        HID_HELPER = base / "bin" / "abko-access"
        os.umask(0o077)
        with (base / "KeyboardRelay.log").open("a") as log:
            os.dup2(log.fileno(), 1)
            os.dup2(log.fileno(), 2)
        serve(keyboard, mouse, grabber, writer)
    except Exception as error:
        print(error, file=sys.stderr, flush=True)
    finally:
        if grabber is not None and not grabber.stdin.closed:
            grabber.stdin.close()
            grabber.wait(timeout=3)
    os._exit(0)


def serve(keyboard, mouse, grabber=None, ready_fd=None):
    os.umask(0o077)
    with SOCKET.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if SOCKET.is_socket():
            with socket.socket(socket.AF_UNIX) as probe:
                probe.settimeout(1)
                try:
                    probe.connect(str(SOCKET))
                except ConnectionRefusedError:
                    SOCKET.unlink()
                else:
                    raise RuntimeError("A keyboard relay is already running.")
        with socket.socket(socket.AF_UNIX) as listener, selectors.DefaultSelector() as select:
            listener.bind(str(SOCKET))
            try:
                run(listener, select, keyboard, mouse, grabber, ready_fd)
            finally:
                SOCKET.unlink(missing_ok=True)


def start_hid(helper, keyboard, elevated=False):
    command = [str(helper), "relay"]
    if not elevated:
        command[:0] = ["/usr/bin/sudo", "-n"]
    if keyboard:
        command.append(keyboard)
    return subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0)


def run(listener, select, keyboard, mouse, grabber, ready_fd):
    listener.listen(4)
    listener.setblocking(False)
    if grabber is None:
        grabber = start_hid(HID_HELPER, keyboard)
    select.register(grabber.stdout, selectors.EVENT_READ, "keyboard")
    peers = {}
    active = None
    active_ready = False
    next_poll = 0.0
    renew_at = 0.0
    mouse_local = True
    partial_keys = b""
    retry_keyboard_at = None

    def remove(peer):
        select.unregister(peer)
        peers.pop(peer, None)
        peer.close()

    def send(peer, payload):
        try:
            peer.sendall(payload)
        except OSError:
            remove(peer)

    def change_target(target):
        nonlocal active, active_ready, retry_keyboard_at
        retry_keyboard_at = None
        if active is not None:
            grabber.stdin.write(b"0")
            if active in peers:
                send(active, b"RESET\n")
        active = target
        active_ready = False
        if target is not None and target in peers:
            grabber.stdin.write(b"1")

    try:
        say("Keyboard relay ready.", "키보드 중계가 준비됐습니다.")
        if ready_fd is not None:
            if not select.select(3):
                raise RuntimeError("The privileged Bluetooth helper did not start.")
            if grabber.stdout.read(8) != b"STARTED\n":
                raise RuntimeError("The privileged Bluetooth helper did not start.")
            os.write(ready_fd, b"1")
            os.close(ready_fd)
        select.register(listener, selectors.EVENT_READ, "listener")
        while grabber.poll() is None:
            for event, _ in select.select(0.10):
                if event.data == "listener":
                    peer, _ = listener.accept()
                    peer.setblocking(False)
                    peers[peer] = [None, False, time.monotonic(), b""]
                    select.register(peer, selectors.EVENT_READ, "peer")
                elif event.data == "keyboard":
                    data = os.read(grabber.stdout.fileno(), 4096)
                    if not data:
                        return
                    parts = (partial_keys + data).split(b"\n")
                    partial_keys = parts.pop()
                    for line in parts:
                        if line == b"READY" and active in peers:
                            active_ready = True
                            retry_keyboard_at = None
                            slot = peers[active][0]
                            say(f"Keyboard routed to {slot}.", f"키보드 입력을 {slot} 윈도우로 전환했습니다.")
                        elif line == b"FAILED" and active in peers:
                            if retry_keyboard_at is None:
                                say("Waiting for the Bluetooth keyboard.", "블루투스 키보드 연결을 기다리는 중입니다.")
                            retry_keyboard_at = time.monotonic() + KEYBOARD_RETRY
                        elif active_ready and active in peers and line.startswith(b"KEY "):
                            send(active, line + b"\n")
                else:
                    peer = event.fileobj
                    try:
                        data = peer.recv(1024)
                    except OSError:
                        data = b""
                    if not data:
                        remove(peer)
                        continue
                    state = peers[peer]
                    parts = (state[3] + data).split(b"\n")
                    state[3] = parts.pop()
                    if len(state[3]) > 360:
                        remove(peer)
                        continue
                    for line in parts:
                        if state[0] is None:
                            if line in (b"STATUS", b"STOP"):
                                send(peer, b"OK\n")
                                if peer in peers:
                                    remove(peer)
                                if line == b"STOP":
                                    return
                                break
                            name = peer_slot(line, mouse)
                            if name is None or any(other[0] == name for other in peers.values()):
                                remove(peer)
                                break
                            state[0] = name
                            state[2] = time.monotonic()
                        elif state[0] and line in (b"PRESENT 0", b"PRESENT 1"):
                            state[1] = line == b"PRESENT 1"
                            state[2] = time.monotonic()
                        else:
                            remove(peer)
                            break

            now = time.monotonic()
            for peer, state in list(peers.items()):
                if now - state[2] >= PEER_TIMEOUT:
                    remove(peer)
            if now >= next_poll:
                mouse_local = mouse_is_local(mouse)
                next_poll = now + 0.35
            ready = [peer for peer, state in peers.items() if state[1] and now - state[2] < LEASE]
            target = ready[0] if not mouse_local and len(ready) == 1 else None
            if target != active:
                if target is None:
                    say("Keyboard released to the Mac.", "키보드 입력을 맥으로 반환했습니다.")
                change_target(target)
            if active is not None and retry_keyboard_at is not None and now >= retry_keyboard_at:
                grabber.stdin.write(b"1")
                retry_keyboard_at = now + KEYBOARD_RETRY
            if active is not None and now >= renew_at:
                grabber.stdin.write(b"2")
                renew_at = now + 0.5
    finally:
        for peer in list(peers):
            send(peer, b"RESET\n")
            if peer in peers:
                remove(peer)
        grabber.stdin.close()
        grabber.wait(timeout=3)


def stop(_signum, _frame):
    raise KeyboardInterrupt


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, stop)
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        pass
