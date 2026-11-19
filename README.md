# 맥에서 로지텍 마우스와 앱코 키보드 같이 쓰기

두 기기가 연결된 맥에서 커서를 화면 가장자리로 넘기면 상대 컴퓨터로 마우스와 키보드 입력이 함께 넘어갑니다. 반대쪽 가장자리로 움직이면 맥으로 돌아옵니다.

화면 가장자리 전환은 Deskflow로 구현했습니다. Logitech Flow의 Keyboard Link에는 호환 로지텍 키보드가 필요합니다. 밑면 Easy-Switch 버튼을 통한 앱코 입력 전환은 개발 중이며, 아래 진단으로 마우스의 블루투스 신호를 확인할 수 있습니다. [Logitech Flow 안내](https://support.logi.com/hc/en-001/articles/1500005634742-What-is-Logitech-Flow-and-how-do-I-set-it-up-and-troubleshoot-it)

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

1. 로지텍 마우스를 이 맥에 블루투스로 연결합니다. Homebrew에서 `brew install hidapitester`를 실행합니다. [hidapitester 사용법](https://github.com/todbot/hidapitester)
2. MX Master 4는 프로젝트 폴더의 터미널에서 `/bin/bash Diagnose.command --mx-master-4`를 실행합니다. 다른 로지텍 마우스는 `/bin/bash Diagnose.command --list`로 `046D/` 뒤의 제품 ID를 확인한 다음, `/bin/bash Diagnose.command B034`처럼 실제 ID를 넣어 실행합니다.
3. 마우스가 맥에 붙어 있는 상태에서 밑면 버튼을 한 번 누르고 직전 보고서가 출력되는지 봅니다. `Control+C`로 종료합니다. 종료 후 마우스를 맥 채널로 돌리면 반복할 수 있습니다.

도구는 지정한 로지텍 제품의 블루투스 HID++ 인터페이스에서 보고서를 읽습니다. 보고서가 관측되면 버튼을 누를 때마다 같은 패턴이 반복되는지 확인해야 합니다. 출력이 없으면 해당 인터페이스에서 전환 신호를 관측하지 못했다는 뜻입니다. [Logitech HID++ 보고서 형식](https://github.com/Logitech/cpg-docs/blob/master/hidpp20/README.rst)

호환성 제보에는 마우스와 키보드의 정확한 모델명, 컴퓨터별 OS, 채널 순서, 버튼 직전 보고서 관측 여부를 적어 주세요.
