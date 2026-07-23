# Codex Usage Widget

Codex 데스크톱 앱의 메시지 입력창 근처에 **남은 사용량**과 다음 초기화까지 남은 시간을 작게 표시하는 macOS용 개인 위젯입니다.

> 비공식 개인 프로젝트입니다. OpenAI 제품이 아니며 OpenAI의 보증·지원과 무관합니다.

## 표시 예시

`71% 남음 · 6d 00h`

- 막대 길이와 색상은 현재 **사용률**을 나타냅니다.
- 숫자 문구는 직관적으로 확인할 수 있도록 **남은 사용량**을 나타냅니다.
- 사용량은 시작 시 한 번, 이후 60초마다 갱신됩니다.

## 동작 방식

- 현재 로그인된 Codex 데스크톱 앱의 로컬 App Server에서 `account/rateLimits/read` 응답을 읽습니다.
- 기본 `primary` 한도만 표시하며, 추가 모델 한도가 기본 값을 덮어쓰지 않습니다.
- Codex 창이 전면에 있을 때만 입력창 도구 모음 근처에 패널을 표시합니다.
- 다른 앱으로 전환하면 패널을 숨깁니다.
- 패널은 마우스 클릭을 통과하므로 입력창·모델 선택·마이크·전송 버튼을 방해하지 않습니다.
- 메뉴 막대의 게이지 아이콘에서 즉시 새로고침하거나 종료할 수 있습니다.

## 요구 사항

- macOS 13 이상
- Codex/ChatGPT 데스크톱 앱이 설치되어 있고 로그인된 상태
- 소스에서 설치할 경우 Xcode Command Line Tools

## 설치

```bash
git clone https://github.com/ellyk0163-web/codex-usage-widget.git
cd codex-usage-widget
make install
```

설치하면 다음을 수행합니다.

1. 앱을 `~/Applications/CodexUsageWidget.app`에 설치합니다.
2. macOS 로그인 시 위젯을 실행하는 사용자 LaunchAgent를 등록합니다.
3. 이후 Codex를 닫았다가 다시 열어도 위젯을 따로 실행할 필요가 없습니다.

현재 세션에서만 실행하려면 다음을 사용합니다.

```bash
make build
open build/CodexUsageWidget.app
```

제거는 다음 명령으로 합니다.

```bash
make uninstall
```

## 첫 실행과 접근성 권한

위젯은 Codex와 일반 ChatGPT 화면을 구분하고 표시 상태를 조정하기 위해 macOS 접근성 API를 사용합니다. 권한 요청이 나오면 허용하세요.

권한 창을 놓친 경우:

**시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 `Codex Usage Widget`을 허용합니다.

로컬 빌드 앱이 차단되면 Finder에서 앱을 Control-클릭한 뒤 **열기**를 선택하세요. 현재 빌드는 ad-hoc 서명으로, Apple 공증 빌드는 아닙니다.

## 개인정보 및 보안

- 별도 로그인 화면·비밀번호 입력·API 키가 필요하지 않습니다.
- 이미 로그인된 Codex 데스크톱 세션의 로컬 App Server만 사용합니다.
- 액세스 토큰, 쿠키, 계정 ID, 인증 헤더를 저장·출력·전송하지 않습니다.
- 사용량 값은 외부 서버로 보내지지 않습니다.
- 1분마다의 로컬 조회는 모델 대화 토큰이나 별도 API 비용을 사용하지 않습니다.

## 알려진 한계

- macOS 전용입니다.
- 현재 Codex 데스크톱 UI 구조에 맞춘 개인용 위젯입니다. Codex 업데이트, 화면 배율, 여러 모니터, 창 레이아웃 변화에 따라 위치가 달라질 수 있습니다.
- 일반 배포용으로는 Apple Developer 서명 및 공증이 필요합니다.
- 사용량·초기화 시각은 해당 로그인 계정이 현재 App Server에서 반환한 값입니다.

## 개발

```bash
make build    # build/CodexUsageWidget.app 생성
make package  # dist/CodexUsageWidget-0.1.0-macos.zip 생성
```

구현은 Objective-C/Cocoa 단일 소스 파일(`Sources/CodexUsageWidget.m`)이며 외부 라이브러리가 필요하지 않습니다.

## 기여

버그 제보에는 macOS 버전, Codex 앱 버전, 디스플레이 배율을 포함해 주세요. 스크린샷에는 계정 정보, 프로젝트명, 브라우저 탭, 토큰을 포함하지 마세요.

## License

[MIT](LICENSE)
