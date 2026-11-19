# Mac Input Switch

**Logitech Flow 또는 Easy-Switch로 맥과 윈도우를 오갈 때 블루투스 키보드 입력도 함께 전환하세요.**

Logitech Flow로 커서를 화면 끝에 밀거나 마우스 밑면의 **Easy-Switch** 버튼을 누르면, 키보드 입력이 마우스가 연결된 컴퓨터로 따라갑니다. 키보드는 사용자가 고른 블루투스 채널로 맥에 페어링하고, 윈도우로 넘어갈 때는 기존 SSH 연결로 키 입력을 전달합니다.

[빠른 시작](#빠른-시작) · [다른 장치 연결](#다른-장치-연결) · [언어 설정](#언어-설정) · [실기 검증](#실기-검증) · [English guide](README.en.md)

## 빠른 시작

**준비물**은 맥, Windows PC, 블루투스 HID 키보드, Flow 또는 Easy-Switch를 지원하는 Logitech 블루투스 마우스입니다. 맥에는 Python 3.8 이상과 Apple Command Line Tools, 윈도우에는 Windows PowerShell 5.1이 필요합니다. Flow로 화면 끝을 오가려면 양쪽에서 Logitech Flow를 설정하세요. 윈도우에서 맥으로 SSH 키 접속이 되는지도 확인하세요.

1. 프로젝트 파일을 맥의 `~/Applications/MacInputSwitch` 폴더에 복사합니다. **시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링**에서 터미널을 허용하고 다시 엽니다. [Apple 입력 모니터링 안내](https://support.apple.com/ko-kr/guide/mac-help/mchl4cedafb6/mac)
2. 맥에서 `Start-KeyboardRelay.command`를 더블클릭하거나 아래 명령을 실행합니다. 처음 시작할 때 언어를 선택하고, 관리자 암호를 맥 터미널에 입력합니다. 창을 닫아도 된다는 메시지가 나오면 닫아도 밑면 버튼 중계는 계속됩니다.

   ```bash
   /bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command
   ```

3. 윈도우에서 `Connect-KeyboardRelay.ps1`과 `AbkoKeyboard.cs`를 같은 폴더에 두고, 해당 폴더에서 Windows PowerShell 5.1로 아래 명령을 실행합니다. 처음 시작할 때 언어를 선택하고, `user@mac-host`와 `your_key`를 자신의 SSH 접속 정보로 바꿉니다. 처음 연결할 때는 맥 호스트 키를 확인해 윈도우의 `known_hosts`에 등록하세요.

   ```powershell
   .\Connect-KeyboardRelay.ps1 -Mac user@mac-host -IdentityFile "$env:USERPROFILE\.ssh\your_key" -Slot first
   ```

4. 키보드를 맥에 연결한 뒤 화면 끝 또는 밑면 버튼으로 마우스를 윈도우로 옮겨 보세요. 같은 맥·윈도우 쌍에 Deskflow도 연결돼 있다면 윈도우에서 Deskflow 클라이언트를 종료해 마우스 입력이 겹치는 것을 막습니다.

### 맥 백그라운드 중계 관리

같은 파일을 다시 열면 실행 상태가 표시됩니다. 종료와 상태 확인에도 같은 파일을 사용합니다. 맥을 재시동한 뒤에는 파일을 다시 실행합니다.

```bash
/bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command --status
/bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command --stop
```

중계 상태 로그는 같은 폴더의 `KeyboardRelay.log`에서 볼 수 있습니다. 터미널에서 직접 문제를 확인할 때는 `--foreground`로 시작하고 Ctrl+C로 종료합니다. 이전 버전을 터미널에서 실행 중이면 Ctrl+C로 먼저 종료한 뒤 새 버전을 실행하세요.

## 다른 장치 연결

- 키보드의 `BT-1`, `BT-2`, `BT-3` 중 어느 채널이든 맥에 페어링할 수 있습니다. 맥에 연결된 블루투스 키보드가 한 대면 자동 선택합니다. 여러 대 중 ACH105가 한 대면 기존 설치와 호환되도록 그 장치를 우선 선택합니다.
- 독거미(AULA)나 다른 표준 Bluetooth HID 키보드를 선택하려면 먼저 맥에서 `/bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command --list-keyboards`로 이름을 확인합니다. 이어서 같은 실행 명령에 `--keyboard "키보드 이름"`을 붙입니다. 같은 이름과 장치 ID를 가진 키보드가 여러 대면 하나만 연결하고 시작합니다. 중계는 한 번에 키보드 한 대를 사용합니다.
- 마우스 채널 번호도 사용자마다 정할 수 있습니다. 기본 마우스는 MX Master 4이며, 다른 모델은 맥에서 `Start-KeyboardRelay.command --list-mice`로 맥에 연결된 제품 이름을 확인한 다음 `--mouse "제품 이름"`을 붙입니다. 윈도우 실행 명령에도 같은 이름을 `-MouseName "제품 이름"`으로 지정합니다. 윈도우 Bluetooth 설정에 다른 이름이 표시되면 `-LocalMouseName "윈도우에 보이는 이름"`도 지정합니다.
- 블루투스 연결을 확인할 수 있는 Logitech Flow 또는 Easy-Switch 모델에 적용됩니다. Flow를 지원하는 마우스는 화면 끝 전환을 쓸 수 있고, Easy-Switch만 지원하는 모델은 밑면 버튼으로 전환합니다. Bolt·Unifying USB 수신기의 연결 감지는 현재 지원 범위 밖입니다.

## 언어 설정

맥과 윈도우에서 처음 실행할 때 **English** 또는 **한국어**를 선택할 수 있습니다. 각 장치가 자기 선택을 저장합니다. 중계를 시작하지 않고 다음 실행의 언어를 바꾸려면 아래 명령을 사용하세요.

```bash
/bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command --set-language en
```

```powershell
.\Connect-KeyboardRelay.ps1 -SetLanguage -Language en
```

한국어를 선택할 때는 `en`을 `ko`로 바꿉니다. 시작과 함께 바꾸려면 맥에서는 `--language en`, 윈도우에서는 `-Language en`을 실행 명령에 넣습니다.

## 실기 검증

| 확인한 동작 | 결과 |
| --- | --- |
| MX Master 4 밑면 버튼으로 맥 미니 → 윈도우 데스크톱 전환 | 앱코 키보드로 윈도우 메모장에 한글과 영문 입력 |
| Logitech Flow 화면 끝으로 윈도우 데스크톱 → 맥 미니 복귀 | 맥에서 앱코 키보드 입력 재개 |

실제로 검증한 조합은 **Apple Silicon 맥 미니 + 윈도우 데스크톱 + MX Master 4 + 앱코 ACH105**입니다. `BT-3`으로 실기 입력을 검증했고, 다른 채널 이름과 모델 선택은 분리해 검증합니다. 두 번째 윈도우용 `-Slot second` 옵션이 있으며, 독거미 등 다른 모델과 USB 수신기는 실기 검증 범위 밖입니다. 키 입력은 SSH로 전달되고 로그에는 연결 상태만 기록됩니다. 윈도우 로그인 화면과 관리자 권한으로 실행된 앱은 일반 사용자 중계의 지원 범위 밖입니다. [Windows 입력 전달 제한](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-sendinput)

## Deskflow로 화면 끝 전환 설정하기

Deskflow만으로 화면 가장자리에서 마우스와 키보드 입력을 함께 넘기려면 아래 설정을 사용하세요. 이 모드에서는 마우스와 키보드를 맥에 연결해 두고 Logitech Flow를 끕니다.

1. 두 컴퓨터를 같은 네트워크에 연결하고 양쪽 모두 [Deskflow 1.27.0](https://github.com/deskflow/deskflow/releases/tag/v1.27.0)을 설치합니다. 맥에서는 `Deskflow.app`을 응용 프로그램 폴더에 넣습니다.
2. 상대 컴퓨터의 Deskflow에 표시된 컴퓨터 이름을 확인합니다. 맥의 터미널에서 `/bin/bash `까지 입력한 뒤 `Start.command`를 끌어 넣고 Enter를 누릅니다.
3. 상대 컴퓨터 이름과 화면 방향을 입력합니다. 방향은 맥 기준 `left`, `right`, `up`, `down` 중 하나이고 기본값은 `right`입니다. 두 번째 상대 컴퓨터가 있으면 이름과 다른 방향을 입력합니다.
4. 맥에서 Deskflow의 손쉬운 사용, 입력 모니터링 및 요청된 로컬 네트워크 권한을 허용합니다. 앱이 다시 실행하라고 하면 종료한 뒤 스크립트를 다시 실행합니다. [Deskflow macOS 권한 안내](https://github.com/deskflow/deskflow/wiki/Workarounds)
5. 맥의 Deskflow에서 **Server → Start**를 누릅니다. 상대 컴퓨터에서 **Client**를 선택하고 맥 화면의 **Suggested IP**를 입력합니다. 지문 확인이 뜨면 상대 앱의 지문과 대조한 뒤 승인합니다.

첫 번째 상대 컴퓨터는 `Control+Option+Shift+F12`, 두 번째는 `Control+Option+Shift+F10`, 맥은 `Control+Option+Shift+F11`로도 선택할 수 있습니다. 화면 배치를 다시 설정하려면 Deskflow를 종료하고 실행 명령 끝에 `--setup`을 붙입니다.

## Easy-Switch 진단과 호환성 제보

1. 로지텍 마우스를 맥에 블루투스로 연결하고 `--nonexclusive`를 지원하는 hidapitester 빌드를 준비합니다. [hidapitester 빌드와 사용법](https://github.com/todbot/hidapitester)
2. 프로젝트 폴더에서 `/bin/bash Diagnose.command --mx-master-4`를 실행합니다. 다른 마우스는 `/bin/bash Diagnose.command --list`에서 `046D/` 뒤의 제품 ID를 확인하고 `/bin/bash Diagnose.command B034`처럼 자신의 ID를 넣습니다.
3. 밑면 버튼을 한 번 누르고 직전 보고서를 확인합니다. `read 0 bytes`는 읽기 시간 초과이며, `02`로 시작하는 보고서는 MX Master 4의 포인터 움직임에서도 관측됩니다. `Control+C`로 종료합니다. HID 접근이 거부되면 실행에 사용하는 터미널의 입력 모니터링 권한을 켜고 다시 엽니다. [Logitech HID++ 보고서 형식](https://github.com/Logitech/cpg-docs/blob/master/hidpp20/README.rst)

다른 조합으로 써봤다면 마우스와 키보드 모델명, 운영체제, 블루투스 채널 배치, 전환 결과를 알려주세요. [GitHub 이슈](https://github.com/SeonikKim/mac-input-switch/issues)

## English overview

**Share a Logitech MX Master 4 and an ABKO ACH105 keyboard across macOS and Windows.** Use Logitech Flow at the screen edge or press the mouse’s Easy-Switch button. Mac Input Switch detects the mouse’s Bluetooth connection on Windows and forwards keyboard input from the Mac over an existing SSH connection.

Tested with an Apple Silicon Mac mini, a Windows desktop, an MX Master 4, and an ACH105. See the [English installation guide](README.en.md) for device selection, language settings, and coverage.
