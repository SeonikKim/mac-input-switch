#!/bin/bash
set -euo pipefail

write_profile() {
    local folder=$1 peer=$2 direction=$3
    local opposite peer_slot config_path
    local LC_ALL=C
    local label='[a-zA-Z0-9]([a-zA-Z0-9_-]*[a-zA-Z0-9])?'

    if [[ ! $peer =~ ^$label(\.$label)*$ || ${#peer} -gt 255 ]] ||
        [[ $(printf '%s' "$peer" | tr 'A-Z' 'a-z') == abko-mac ]]; then
        printf '%s\n' '상대 컴퓨터 이름을 다시 확인하세요. 예시 desk-pc' >&2
        return 1
    fi

    case "$direction" in
        left) opposite=right; peer_slot=7 ;;
        right) opposite=left; peer_slot=9 ;;
        up) opposite=down; peer_slot=3 ;;
        down) opposite=up; peer_slot=13 ;;
        *) printf '%s\n' '방향은 left, right, up, down 중 하나를 입력하세요.' >&2; return 1 ;;
    esac

    mkdir -p "$folder"
    config_path="$folder/ScreenLayout.conf"
    cat > "$config_path" <<EOF
section: links
    abko-mac:
        $direction = $peer
    $peer:
        $opposite = abko-mac
end
section: options
    keystroke(control+alt+shift+F11) = switchToScreen(abko-mac)
    keystroke(control+alt+shift+F12) = switchToScreen($peer)
end
EOF

    # Escape a quoted Qt INI string so paths with spaces and punctuation work.
    config_path=${config_path//\\/\\\\}
    config_path=${config_path//\"/\\\"}
    cat > "$folder/Deskflow.conf" <<EOF
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

[computer_$peer]
name=$peer

[internalConfig]
screens\\size=15
screens\\8\\name=abko-mac
screens\\$peer_slot\\name=$peer
EOF
}

main() {
    if [[ $(uname -s) != Darwin ]]; then
        printf '%s\n' '이 스크립트는 맥에서 실행해 주세요.' >&2
        return 1
    fi

    local app=/Applications/Deskflow.app
    if [[ ! -d $app ]]; then
        app="$HOME/Applications/Deskflow.app"
    fi
    local executable="$app/Contents/MacOS/Deskflow"
    if [[ ! -x $executable ]]; then
        printf '%s\n' 'Deskflow 1.27.0을 설치하고 응용 프로그램 폴더에 넣어 주세요.' >&2
        printf '%s\n' 'https://github.com/deskflow/deskflow/releases/tag/v1.27.0' >&2
        return 1
    fi

    local version
    version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || true)
    if [[ $version != 1.27.0 && $version != 1.27.0.0 ]]; then
        printf '이 스크립트는 Deskflow 1.27.0용입니다. 설치된 버전 %s\n' "${version:-확인 실패}" >&2
        return 1
    fi

    if /usr/bin/pgrep -x Deskflow >/dev/null || /usr/bin/pgrep -x deskflow-core >/dev/null; then
        printf '%s\n' '실행 중인 Deskflow를 Cmd+Q로 완전히 종료한 뒤 다시 실행해 주세요.' >&2
        return 1
    fi

    local profile="$HOME/Library/Application Support/ABKO Input Switch"
    local settings="$profile/Deskflow" peer direction
    if [[ ${1:-} == --setup || ! -f $settings/Deskflow.conf || ! -f $settings/ScreenLayout.conf ]]; then
        printf '%s\n' '상대 컴퓨터에서 Deskflow를 열고 This computer’s name을 확인하세요.'
        read -r -p '상대 컴퓨터 이름 > ' peer
        read -r -p '상대 화면 위치 left/right/up/down [right] > ' direction
        write_profile "$settings" "$peer" "${direction:-right}"
    fi

    mkdir -p "$profile/State"
    printf '%s\n' '맥의 Deskflow에서 Start를 누르세요.'
    printf '%s\n' '상대 컴퓨터의 Deskflow에서 Client를 선택하고 맥에 표시된 IP를 입력하세요.'
    XDG_CONFIG_HOME="$profile" XDG_STATE_HOME="$profile/State" exec "$executable"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
