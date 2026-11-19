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
    printf '%s\n' '목록에서 로지텍 마우스의 046D: 뒤에 있는 제품 ID 네 자리를 확인하세요.'
    exec hidapitester --vidpid 046D --usagePage 0xFF43 --usage 0x0202 --list-usages
fi

if [[ $# -ne 1 || ! $1 =~ ^[[:xdigit:]]{4}$ || $1 == 0000 ]]; then
    printf '%s\n' '사용법은 bash Diagnose.command [제품 ID 네 자리]입니다.' >&2
    exit 2
fi

printf '%s\n' '이 맥에 연결된 상태에서 밑면 Easy-Switch 버튼을 한 번 누르세요. 종료는 Control+C입니다.'
exec hidapitester --vidpid "046D:$1" --usagePage 0xFF43 --usage 0x0202 \
    --nonexclusive --open --length 20 --timeout 1000 --read-input-report-forever 0x11
