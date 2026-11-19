"""Route an ACH105 over an existing SSH connection to the host with the mouse."""

import os
import selectors
import signal
import socket
import subprocess
import time
from pathlib import Path

BASE = Path.home() / "Applications" / "MacInputSwitch"
SOCKET = BASE / "keyboard.sock"
LEASE = 2.5


def mouse_is_local():
    matching = '{"VendorID":1133}'
    try:
        result = subprocess.run(
            ["/usr/bin/hidutil", "list", "--matching", matching],
            capture_output=True, text=True, timeout=0.8, check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return True
    return "MX Master 4" in result.stdout


def main():
    os.umask(0o077)
    # A pre-existing socket belongs to a running session or needs explicit cleanup.
    with socket.socket(socket.AF_UNIX) as listener, selectors.DefaultSelector() as select:
        listener.bind(str(SOCKET))
        try:
            run(listener, select)
        finally:
            SOCKET.unlink(missing_ok=True)


def run(listener, select):
    listener.listen(4)
    listener.setblocking(False)
    select.register(listener, selectors.EVENT_READ, "listener")
    grabber = subprocess.Popen(
        ["/usr/bin/sudo", "-n", str(BASE / "bin" / "abko-access"), "relay"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0,
    )
    select.register(grabber.stdout, selectors.EVENT_READ, "keyboard")
    peers = {}
    active = None
    active_ready = False
    next_poll = 0.0
    renew_at = 0.0
    mouse_local = True
    partial_keys = b""

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
        nonlocal active, active_ready
        if active is not None:
            grabber.stdin.write(b"0")
            if active in peers:
                send(active, b"RESET\n")
        active = target
        active_ready = False
        if target is not None and target in peers:
            grabber.stdin.write(b"1")

    print("Keyboard relay ready; Ctrl+C stops it.", flush=True)
    try:
        while grabber.poll() is None:
            for event, _ in select.select(0.10):
                if event.data == "listener":
                    peer, _ = listener.accept()
                    peer.setblocking(False)
                    peers[peer] = [None, False, 0.0, b""]
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
                            print(f"ACH105 routed to {peers[active][0]}.", flush=True)
                        elif line == b"FAILED":
                            print("ACH105 could not be opened; relay stopped.", flush=True)
                            return
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
                    if len(state[3]) > 64:
                        remove(peer)
                        continue
                    for line in parts:
                        if state[0] is None and line in (b"HELLO first", b"HELLO second"):
                            name = line.split()[1].decode("ascii")
                            if any(other[0] == name for other in peers.values()):
                                remove(peer)
                                break
                            state[0] = name
                        elif state[0] and line in (b"PRESENT 0", b"PRESENT 1"):
                            state[1] = line == b"PRESENT 1"
                            state[2] = time.monotonic()
                        else:
                            remove(peer)
                            break

            now = time.monotonic()
            if now >= next_poll:
                mouse_local = mouse_is_local()
                next_poll = now + 0.35
            ready = [peer for peer, state in peers.items() if state[1] and now - state[2] < LEASE]
            target = ready[0] if not mouse_local and len(ready) == 1 else None
            if target != active:
                if target is None:
                    print("ACH105 released to the Mac.", flush=True)
                change_target(target)
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
        main()
    except KeyboardInterrupt:
        pass
