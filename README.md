# 맥에서 로지텍 마우스와 앱코 키보드 같이 쓰기

두 기기가 연결된 맥에서 커서를 화면 가장자리로 넘기면 상대 컴퓨터로 마우스와 키보드 입력이 함께 넘어갑니다. 반대쪽 가장자리로 움직이면 맥으로 돌아옵니다.

Deskflow를 사용하거나, 아래의 **Logitech Flow + 앱코 키보드 중계**를 사용할 수 있습니다. Logitech Flow의 자체 Keyboard Link에는 호환 로지텍 키보드가 필요합니다. [Logitech Flow 안내](https://support.logi.com/hc/en-001/articles/1500005634742-What-is-Logitech-Flow-and-how-do-I-set-it-up-and-troubleshoot-it)

## 처음 연결하기

1. 마우스와 키보드를 맥에 연결하고, 맥과 상대 컴퓨터를 같은 네트워크에 연결합니다. 양쪽 모두 [Deskflow 1.27.0](https://github.com/deskflow/deskflow/releases/tag/v1.27.0)을 설치합니다. 맥에서는 `Deskflow.app`을 응용 프로그램 폴더에 넣습니다.
2. 상대 컴퓨터에서 Deskflow를 열고 화면에 표시된 컴퓨터 이름을 확인합니다. 맥에 `Start.command`를 복사합니다. 맥의 터미널에서 `/bin/bash `까지 입력한 뒤 파일을 터미널 창에 끌어 넣고 Enter를 누릅니다.
3. 첫 번째 상대 컴퓨터 이름과 방향을 입력합니다. 방향은 맥 화면을 기준으로 `left`, `right`, `up`, `down` 중 하나입니다. 방향에서 Enter만 누르면 오른쪽으로 설정합니다. 상대 컴퓨터가 한 대 더 있으면 그 컴퓨터 이름과 다른 방향을 입력합니다.
4. 맥에서 권한이 요청되면 시스템 설정 → 개인정보 보호 및 보안에서 Deskflow의 손쉬운 사용과 입력 모니터링을 허용합니다. 로컬 네트워크 권한을 요청하면 함께 허용합니다. 다시 실행하라는 안내가 나오면 Deskflow를 완전히 종료하고 스크립트를 다시 실행합니다. [Deskflow macOS 권한 안내](https://github.com/deskflow/deskflow/wiki/Workarounds)
5. 맥의 Deskflow에서 **Server → Start**를 누릅니다. 상대 컴퓨터의 Deskflow에서 **Client**를 선택하고 맥 화면의 **Suggested IP**를 입력한 뒤 시작합니다. 양쪽에 지문 확인이 뜨면 상대 앱에 표시된 지문과 대조하고 승인합니다.

## 전환하기

- 화면 가장자리로 마우스를 이동하면 입력이 함께 넘어갑니다. 맥과 상대 컴퓨터들의 텍스트 편집기를 열고, 커서를 넘긴 다음 입력이 해당 컴퓨터에만 들어가는지 확인합니다.
- Deskflow의 단축키는 첫 번째 상대 컴퓨터 `Control+Option+Shift+F12`, 두 번째 `Control+Option+Shift+F10`, 맥 `Control+Option+Shift+F11`입니다.
- 마우스 밑면의 Easy-Switch 채널 버튼은 별도로 작동합니다. 마우스는 맥에 연결한 채 사용합니다. Logi Flow가 켜져 있다면 Deskflow를 사용하는 동안 끕니다.
- 상대 컴퓨터나 방향을 바꾸려면 맥에서 Deskflow를 완전히 종료하고, 터미널에서 같은 실행 명령 끝에 ` --setup`을 붙입니다. 다음부터는 같은 스크립트를 실행하고 **Start**를 누르면 됩니다.

## 밑면 Easy-Switch 버튼 진단

1. 로지텍 마우스를 이 맥에 블루투스로 연결합니다. `--nonexclusive`를 지원하는 hidapitester 빌드를 사용합니다. `hidapitester --help`에 옵션이 없으면 공유 모드를 지원하는 소스 버전을 빌드합니다. [hidapitester 빌드와 사용법](https://github.com/todbot/hidapitester)
2. MX Master 4는 프로젝트 폴더의 터미널에서 `/bin/bash Diagnose.command --mx-master-4`를 실행합니다. 다른 로지텍 마우스는 `/bin/bash Diagnose.command --list`로 `046D/` 뒤의 제품 ID를 확인한 다음, `/bin/bash Diagnose.command B034`처럼 실제 ID를 넣어 실행합니다.
3. 마우스가 맥에 붙어 있는 상태에서 밑면 버튼을 한 번 누르고 직전 보고서가 출력되는지 봅니다. `Control+C`로 종료합니다. 종료 후 마우스를 맥 채널로 돌리면 반복할 수 있습니다.

도구는 지정한 로지텍 제품의 블루투스 인터페이스에서 들어오는 보고서를 실시간으로 읽습니다. `read 0 bytes`는 시간 초과이고, `02`로 시작하는 보고서는 MX Master 4의 포인터 움직임에서도 관측됩니다. 버튼을 눌렀을 때 목적지 채널 보고서가 나오는지는 일반 움직임과 구분해서 확인해야 합니다. 맥에서 접근 권한을 거부하면 시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링에서 실행에 사용하는 터미널을 허용한 뒤 터미널을 다시 엽니다. [Logitech HID++ 보고서 형식](https://github.com/Logitech/cpg-docs/blob/master/hidpp20/README.rst)

호환성 제보에는 마우스와 키보드의 정확한 모델명, 컴퓨터별 OS, 채널 순서, 버튼 직전 보고서 관측 여부를 적어 주세요.

## Logitech Flow + 앱코 키보드 중계 (실험 기능)

Logitech Flow는 마우스와 화면 가장자리 전환을 담당합니다. 중계는 MX Master 4가 블루투스로 실제 연결된 윈도우를 확인한 뒤, 맥의 `ACH105 BT-3` 키보드 입력만 그 컴퓨터로 보냅니다. 마우스가 맥으로 돌아오거나 윈도우 연결이 끊기면 키보드가 맥으로 돌아옵니다. 동일한 윈도우 PC에서 Deskflow 클라이언트를 잠시 종료해 마우스 전달이 겹치지 않도록 합니다.

1. 맥에서 Python 3.8 이상과 Apple Command Line Tools를 준비합니다. 소스 파일을 `~/Applications/MacInputSwitch`에 놓고 터미널에 입력 모니터링 권한을 줍니다. 윈도우에서 맥으로 기존 SSH 키로 접속할 수 있어야 합니다. 맥이 호스트 키로 이미 등록되어 있어야 합니다.
2. 맥에서 터미널 창 하나를 열고 `/bin/bash ~/Applications/MacInputSwitch/Start-KeyboardRelay.command`를 실행합니다. 관리자 암호는 해당 터미널의 `sudo` 프롬프트에 입력합니다. 관리자 권한을 쓰는 도우미는 지정된 앱코 키보드만 엽니다.
3. 윈도우에서는 `Connect-KeyboardRelay.ps1`과 `AbkoKeyboard.cs`를 같은 폴더에 두고 Windows PowerShell 5.1에서 다음처럼 실행합니다. 두 번째 윈도우를 쓰려면 그 컴퓨터에서 `-Slot second`로 별도로 실행합니다.

   ```powershell
   .\Connect-KeyboardRelay.ps1 -Mac user@mac-host -IdentityFile "$env:USERPROFILE\.ssh\your_key" -Slot first
   ```

4. 앱코는 맥의 채널 3에 둡니다. MX Master 4를 마우스 밑면 버튼이나 Logitech Flow로 윈도우에 연결하면 앱코를 윈도우에서 사용할 수 있습니다. 맥 터미널에서 `Control+C`로 중계를 종료합니다.

이 기능은 앱코 ACH105 BT-3, MX Master 4, 맥 미니와 윈도우 데스크톱 조합을 대상으로 합니다. 일반 키와 키 조합을 전달하며 키 입력을 로그에 쓰지 않습니다. 윈도우 로그인 화면과 더 높은 권한으로 실행된 프로그램에는 일반 사용자 중계가 입력을 전달할 수 없습니다. [Windows 입력 전달 제한](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-sendinput)
