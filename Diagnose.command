#!/bin/bash
set -euo pipefail

language=${MAC_INPUT_SWITCH_LANG:-}
language_file="$HOME/Applications/MacInputSwitch/language"
if [[ -z $language && -r $language_file ]]; then read -r language < "$language_file" || true; fi
language=${language:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}
say() { if [[ $language == ko* ]]; then printf '%s\n' "$2"; else printf '%s\n' "$1"; fi; }

if [[ $(uname -s) != Darwin ]]; then
    say 'Run this diagnostic on your Mac.' '이 진단은 맥에서 실행해 주세요.' >&2
    exit 1
fi

if ! command -v hidapitester >/dev/null; then
    say 'Install a hidapitester build with --nonexclusive support. See the README.' '--nonexclusive를 지원하는 hidapitester를 설치하세요. README를 참고하세요.' >&2
    exit 1
fi

if [[ $# -eq 0 || ( $# -eq 1 && $1 == --list ) ]]; then
    say 'Find the four-digit product ID after 046D/ in the list.' '목록에서 로지텍 마우스의 046D/ 뒤에 있는 제품 ID 네 자리를 확인하세요.'
    exec hidapitester --vidpid 046D --usagePage 0xFF43 --usage 0x0202 --list-usages
fi

if [[ $# -ne 1 ]]; then
    say 'Usage: bash Diagnose.command [--mx-master-4 or a four-digit product ID]' '사용법은 bash Diagnose.command [--mx-master-4 또는 제품 ID 네 자리]입니다.' >&2
    exit 2
fi

product=$1
if [[ $product == --mx-master-4 ]]; then
    devices=$(hidapitester --vidpid 046D --usagePage 0xFF43 --usage 0x0202 --list-usages || true)
    standard=false business=false
    if grep -iq '^046D/B042[[:space:]]' <<< "$devices"; then standard=true; fi
    if grep -iq '^046D/B048[[:space:]]' <<< "$devices"; then business=true; fi
    case "$standard/$business" in
        true/false) product=B042 ;;
        false/true) product=B048 ;;
        true/true)
            say 'Both models are connected. Specify B042 or B048.' '두 모델이 모두 연결되어 있습니다. B042 또는 B048을 직접 지정하세요.' >&2
            exit 2 ;;
        *)
            say 'MX Master 4 Bluetooth HID++ interface not found. Check that the mouse is connected to this Mac.' 'MX Master 4의 블루투스 HID++ 인터페이스를 찾지 못했습니다. 마우스가 이 맥 채널에 연결됐는지 확인하세요.' >&2
            exit 1 ;;
    esac
elif [[ ! $product =~ ^[[:xdigit:]]{4}$ || $product == 0000 ]]; then
    say 'Enter four hexadecimal digits, such as B042.' '제품 ID는 16진수 네 자리로 입력하세요. 예시 B042' >&2
    exit 2
fi

help=$(hidapitester --help 2>&1 || true)
if [[ $help != *--nonexclusive* ]]; then
    say 'This diagnostic needs a hidapitester build that supports --nonexclusive. See the README.' '공유 모드 옵션을 지원하는 hidapitester 빌드가 필요합니다. README의 설치 안내를 확인하세요.' >&2
    exit 1
fi

say 'With the mouse connected to this Mac, press the underside Easy-Switch button once. Ctrl+C stops the capture.' '이 맥에 연결된 상태에서 밑면 Easy-Switch 버튼을 한 번 누르세요. 종료는 Control+C입니다.'
exec hidapitester --vidpid "046D:$product" --usagePage 0xFF43 --usage 0x0202 \
    --nonexclusive --open --length 20 --timeout 1000 --read-input-forever
