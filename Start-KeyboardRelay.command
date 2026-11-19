#!/bin/bash
set -euo pipefail

base="$HOME/Applications/MacInputSwitch"
if [[ $(cd -- "$(dirname -- "$0")" && pwd) != "$base" ]]; then
    printf '%s\n' 'Move the project to ~/Applications/MacInputSwitch first.' >&2
    exit 1
fi
language_file="$base/language"
language=${MAC_INPUT_SWITCH_LANG:-}
if [[ -z $language && -r $language_file ]]; then read -r language < "$language_file" || true; fi
case "${1:-}" in
    --language|--set-language)
        language=${2:-}
        if [[ $language != en && $language != ko ]]; then
            printf '%s\n' 'Choose en (English) or ko (한국어).' >&2
            exit 2
        fi
        if [[ $1 == --set-language && $# -ne 2 ]]; then
            printf '%s\n' 'Usage: Start-KeyboardRelay.command --set-language en|ko' >&2
            exit 2
        fi
        (umask 077; printf '%s\n' "$language" > "$language_file")
        if [[ $1 == --set-language ]]; then
            [[ $language == en ]] && printf '%s\n' 'English saved.' || printf '%s\n' '한국어로 저장했습니다.'
            exit 0
        fi
        shift 2 ;;
esac
mode=relay
foreground=false
case "${1:-}" in
    --help|-h)
        printf '%s\n' 'Usage: Start-KeyboardRelay.command [--language en|ko] [--keyboard NAME] [--mouse NAME]' \
            'Manage the background relay: --status or --stop' 'Keep the relay attached for troubleshooting: --foreground' \
            'Device discovery: --list-keyboards or --list-mice' 'Change the saved language: --set-language en|ko'
        exit 0 ;;
    --foreground) foreground=true; shift ;;
    --status|--stop) mode=control ;;
    --list-keyboards) mode=list-keyboards; shift ;;
    --list-mice) mode=list-mice; shift ;;
esac
if [[ $mode != relay && $mode != control && $# -ne 0 ]]; then
    printf '%s\n' 'Use a device listing option on its own.' >&2
    exit 2
fi
if [[ $mode == relay && -z $language && -t 0 ]]; then
    printf '%s\n' 'Choose language / 언어 선택' '1. English' '2. 한국어'
    read -r -p '1 / 2 [1] > ' choice
    case "$choice" in
        ''|1) language=en ;;
        2) language=ko ;;
        *) printf '%s\n' 'Enter 1 or 2. / 1 또는 2를 입력하세요.' >&2; exit 2 ;;
    esac
    (umask 077; printf '%s\n' "$language" > "$language_file")
fi
case "${language:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}" in
    ko*) export MAC_INPUT_SWITCH_LANG=ko ;;
    *) export MAC_INPUT_SWITCH_LANG=en ;;
esac

python=$(command -v python3 || true)
if [[ -x /opt/homebrew/bin/python3 ]]; then python=/opt/homebrew/bin/python3; fi
if [[ -z $python ]]; then
    printf '%s\n' 'Install Python 3.8 or newer. / Python 3.8 이상을 설치하세요.' >&2
    exit 1
fi
"$python" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else "Python 3.8 or newer is required.")'
if [[ $mode == control ]]; then
    exec "$python" "$base/keyboard-relay.py" "$@"
fi
if [[ $mode == relay && -S $base/keyboard.sock ]]; then
    if "$python" "$base/keyboard-relay.py" --status; then exit 0; fi
    if "$python" -c 'import socket,sys; s=socket.socket(socket.AF_UNIX);s.settimeout(1);sys.exit(s.connect_ex(sys.argv[1]) != 0)' "$base/keyboard.sock"; then
        printf '%s\n' 'Close the previous foreground relay first. / 기존 중계 창에서 Ctrl+C를 눌러 먼저 종료해 주세요.' >&2
        exit 1
    fi
fi

mkdir -p "$base/bin"
toolchain=/Library/Developer/CommandLineTools
output=$(mktemp "$base/bin/abko-access.XXXXXX")
trap 'rm -f "$output"' EXIT
if [[ -x $toolchain/usr/bin/clang ]]; then
    "$toolchain/usr/bin/clang" -isysroot "$toolchain/SDKs/MacOSX.sdk" \
        -Wall -Wextra -Werror "$base/AbkoAccess.c" -framework IOKit -framework CoreFoundation -o "$output"
else
    /usr/bin/xcrun --sdk macosx clang \
        -Wall -Wextra -Werror "$base/AbkoAccess.c" -framework IOKit -framework CoreFoundation -o "$output"
fi
chmod 700 "$output"
if [[ $mode != relay ]]; then
    "$output" "$mode"
    exit
fi
mv -f "$output" "$base/bin/abko-access"
trap - EXIT

if $foreground; then
    /usr/bin/sudo -v
    exec "$python" "$base/keyboard-relay.py" "$@"
fi
exec /usr/bin/sudo -- "$python" -I "$base/keyboard-relay.py" --background --language "$MAC_INPUT_SWITCH_LANG" "$@"
