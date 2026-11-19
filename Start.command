#!/bin/bash
set -euo pipefail

language=${MAC_INPUT_SWITCH_LANG:-}
language_file="$HOME/Applications/MacInputSwitch/language"
if [[ -z $language && -r $language_file ]]; then read -r language < "$language_file" || true; fi
language=${language:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}
say() { if [[ $language == ko* ]]; then printf '%s\n' "$2"; else printf '%s\n' "$1"; fi; }

write_profile() {
    local folder=$1
    shift
    if [[ $# -ne 2 && $# -ne 4 ]]; then
        say 'Enter a name and a direction for each client.' '상대 컴퓨터 이름과 방향을 한 쌍씩 입력하세요.' >&2
        return 1
    fi

    local peer direction opposite config_path index
    local -a peers directions opposites hotkeys
    peers=() directions=() opposites=() hotkeys=(F12 F10)
    local LC_ALL=C
    local label='[a-zA-Z0-9]([a-zA-Z0-9_-]*[a-zA-Z0-9])?'

    while (( $# )); do
        peer=$1 direction=$2
        shift 2
        if [[ ! $peer =~ ^$label(\.$label)*$ || ${#peer} -gt 255 ]]; then
            say 'Enter a valid client name, such as desk-pc.' '상대 컴퓨터 이름을 다시 확인하세요. 예시 desk-pc' >&2
            return 1
        fi
        local peer_lower first_lower
        peer_lower=$(printf '%s' "$peer" | tr 'A-Z' 'a-z')
        first_lower=$(printf '%s' "${peers[0]:-}" | tr 'A-Z' 'a-z')
        if [[ $peer_lower == abko-mac || $peer_lower == "$first_lower" ]]; then
            say 'Computer names must be unique.' '컴퓨터 이름은 서로 달라야 합니다.' >&2
            return 1
        fi
        if [[ $direction == "${directions[0]:-}" ]]; then
            say 'Place the two clients in different directions.' '두 상대 화면을 서로 다른 방향에 배치하세요.' >&2
            return 1
        fi

        case "$direction" in
            left) opposite=right ;;
            right) opposite=left ;;
            up) opposite=down ;;
            down) opposite=up ;;
            *) say 'Choose left, right, up, or down.' '방향은 left, right, up, down 중 하나를 입력하세요.' >&2; return 1 ;;
        esac
        peers+=("$peer") directions+=("$direction") opposites+=("$opposite")
    done

    mkdir -p "$folder"
    config_path="$folder/ScreenLayout.conf"
    {
        printf 'section: links\n    abko-mac:\n'
        for index in "${!peers[@]}"; do
            printf '        %s = %s\n' "${directions[index]}" "${peers[index]}"
        done
        for index in "${!peers[@]}"; do
            printf '    %s:\n        %s = abko-mac\n' "${peers[index]}" "${opposites[index]}"
        done
        printf 'end\nsection: options\n    keystroke(control+alt+shift+F11) = switchToScreen(abko-mac)\n'
        for index in "${!peers[@]}"; do
            printf '    keystroke(control+alt+shift+%s) = switchToScreen(%s)\n' "${hotkeys[index]}" "${peers[index]}"
        done
        printf 'end\n'
    } > "$config_path"

    # Escape a quoted Qt INI string so paths with spaces and punctuation work.
    config_path=${config_path//\\/\\\\}
    config_path=${config_path//\"/\\\"}
    {
        cat <<EOF
[core]
computerName=abko-mac
coreMode=Server

[server]
externalConfig=true
externalConfigFile="$config_path"
enableClipboard=false
gridWidth=5
gridHeight=3

[security]
tlsEnabled=true

[computer_abko-mac]
name=abko-mac
EOF
        for peer in "${peers[@]}"; do
            printf '\n[computer_%s]\nname=%s\n' "$peer" "$peer"
        done
        # External layouts use the computer sections above. A partial internal grid
        # triggers Deskflow 1.27.0's legacy settings migration during startup.
    } > "$folder/Deskflow.conf"
}

main() {
    if [[ $(uname -s) != Darwin ]]; then
        say 'Run this script on your Mac.' '이 스크립트는 맥에서 실행해 주세요.' >&2
        return 1
    fi

    local app=/Applications/Deskflow.app
    if [[ ! -d $app ]]; then
        app="$HOME/Applications/Deskflow.app"
    fi
    local executable="$app/Contents/MacOS/Deskflow"
    if [[ ! -x $executable ]]; then
        say 'Install Deskflow 1.27.0 in the Applications folder.' 'Deskflow 1.27.0을 설치하고 응용 프로그램 폴더에 넣어 주세요.' >&2
        printf '%s\n' 'https://github.com/deskflow/deskflow/releases/tag/v1.27.0' >&2
        return 1
    fi

    local version
    version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || true)
    if [[ $version != 1.27.0 && $version != 1.27.0.0 ]]; then
        say "Deskflow 1.27.0 is required. Found ${version:-no version}." "이 스크립트는 Deskflow 1.27.0용입니다. 설치된 버전 ${version:-확인 실패}" >&2
        return 1
    fi

    if /usr/bin/pgrep -x Deskflow >/dev/null || /usr/bin/pgrep -x deskflow-core >/dev/null; then
        say 'Quit Deskflow with Cmd+Q before running this script again.' '실행 중인 Deskflow를 Cmd+Q로 완전히 종료한 뒤 다시 실행해 주세요.' >&2
        return 1
    fi

    local profile="$HOME/Library/Application Support/ABKO Input Switch"
    local settings="$profile/Deskflow" peer direction second_peer second_direction
    if [[ ${1:-} == --setup || ! -f $settings/Deskflow.conf || ! -f $settings/ScreenLayout.conf ]]; then
        say 'Open Deskflow on the client and check the computer name it displays.' '상대 컴퓨터에서 Deskflow를 열고 This computer’s name을 확인하세요.'
        read -r -p "$(say 'First client name > ' '첫 번째 상대 컴퓨터 이름 > ')" peer
        read -r -p "$(say 'First screen position left/right/up/down [right] > ' '첫 번째 화면 위치 left/right/up/down [right] > ')" direction
        read -r -p "$(say 'Second client name [Enter to skip] > ' '두 번째 상대 컴퓨터 이름 [없으면 Enter] > ')" second_peer
        local -a layout=("$peer" "${direction:-right}")
        if [[ -n $second_peer ]]; then
            read -r -p "$(say 'Second screen position left/right/up/down > ' '두 번째 화면 위치 left/right/up/down > ')" second_direction
            layout+=("$second_peer" "$second_direction")
        fi
        write_profile "$settings" "${layout[@]}"
    fi

    mkdir -p "$profile/State"
    say 'Click Start in Deskflow on the Mac.' '맥의 Deskflow에서 Start를 누르세요.'
    say 'Select Client in Deskflow on the other computer and enter the IP shown on the Mac.' '상대 컴퓨터의 Deskflow에서 Client를 선택하고 맥에 표시된 IP를 입력하세요.'
    XDG_CONFIG_HOME="$profile" XDG_STATE_HOME="$profile/State" exec "$executable"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
