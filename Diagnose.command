#!/bin/bash
set -euo pipefail

if [[ $(uname -s) != Darwin ]]; then
    printf '%s\n' '이 진단은 맥에서 실행해 주세요.' >&2
    exit 1
fi

if ! command -v hidapitester >/dev/null; then
    printf '%s\n' 'Homebrew에서 brew install hidapitester로 진단 도구를 설치해 주세요.' >&2
    exit 1
fi

if [[ $# -eq 0 || ( $# -eq 1 && $1 == --list ) ]]; then
    printf '%s\n' '목록에서 로지텍 마우스의 046D/ 뒤에 있는 제품 ID 네 자리를 확인하세요.'
    exec hidapitester --vidpid 046D --usagePage 0xFF43 --usage 0x0202 --list-usages
fi

if [[ $# -ne 1 ]]; then
    printf '%s\n' '사용법은 bash Diagnose.command [--mx-master-4 또는 제품 ID 네 자리]입니다.' >&2
    exit 2
fi

product=$1
if [[ $product == --mx-master-4 ]]; then
    devices=$(hidapitester --vidpid 046D --usagePage 0xFF43 --usage 0x0202 --list-usages)
    standard=false business=false
    if grep -iq '^046D/B042[[:space:]]' <<< "$devices"; then standard=true; fi
    if grep -iq '^046D/B048[[:space:]]' <<< "$devices"; then business=true; fi
    case "$standard/$business" in
        true/false) product=B042 ;;
        false/true) product=B048 ;;
        true/true)
            printf '%s\n' '두 모델이 모두 연결되어 있습니다. B042 또는 B048을 직접 지정하세요.' >&2
            exit 2 ;;
        *)
            printf '%s\n' 'MX Master 4의 블루투스 HID++ 인터페이스를 찾지 못했습니다. 마우스가 이 맥 채널에 연결됐는지 확인하세요.' >&2
            exit 1 ;;
    esac
elif [[ ! $product =~ ^[[:xdigit:]]{4}$ || $product == 0000 ]]; then
    printf '%s\n' '제품 ID는 16진수 네 자리로 입력하세요. 예시 B042' >&2
    exit 2
fi

printf '%s\n' '이 맥에 연결된 상태에서 밑면 Easy-Switch 버튼을 한 번 누르세요. 종료는 Control+C입니다.'
exec hidapitester --vidpid "046D:$product" --usagePage 0xFF43 --usage 0x0202 \
    --nonexclusive --open --length 20 --timeout 1000 --read-input-report-forever 0x11
