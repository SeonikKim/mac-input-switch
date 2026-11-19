#!/bin/bash
set -euo pipefail

base="$HOME/Applications/MacInputSwitch"
if [[ $(cd -- "$(dirname -- "$0")" && pwd) != "$base" ]]; then
    printf '%s\n' '먼저 이 프로젝트를 ~/Applications/MacInputSwitch에 복사하세요.' >&2
    exit 1
fi
if [[ -e $base/keyboard.sock ]]; then
    printf '%s\n' '이미 활성화된 중계가 있거나 이전 소켓이 남아 있습니다.' >&2
    exit 1
fi

python=$(command -v python3 || true)
if [[ -x /opt/homebrew/bin/python3 ]]; then python=/opt/homebrew/bin/python3; fi
if [[ -z $python ]]; then
    printf '%s\n' 'Python 3을 설치하세요.' >&2
    exit 1
fi
"$python" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else "Python 3.8 이상이 필요합니다.")'

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
mv -f "$output" "$base/bin/abko-access"
trap - EXIT

/usr/bin/sudo -v
exec "$python" "$base/keyboard-relay.py"
