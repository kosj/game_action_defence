# 버전 분리 검증 — 2026-09-11

- Godot 4.3로 데스크톱 2272×1278 논리 화면 / 1280×720 창에서 타이틀, 메뉴, 설정, 게임 화면 렌더 확인.
- 모바일 720×1280 논리 화면 / 360×640 창에서 메뉴, 설정, 게임 화면 렌더 확인.
- 랭킹 핸들러 제거, 팝업 최대 폭 및 화면 내부 배치 검사 통과 (`tools/verify_editions.gd`).
- 키보드 이동 회귀 검사 8/8 통과 (`scenes/KeyboardMoveTest.tscn`).
- 출시 프리셋 치트 차단 검사 실패 0건 (`tools/verify_cheat_gate.gd`).
- GDScript 정적 검사 문제 0건, 다국어 텍스트 폭 검사 넘침 0건.
- Web/Windows/Mobile Preview 릴리스 빌드 및 ZIP 무결성 검사 통과. Windows 실행 파일의 실제 타이틀 실행 확인.
- Mobile Preview export pack에서 `mobile=true`, 720×1280 및 전용 저장 경로 확인. Windows 실행 파일에서 정식판 태그 및 기존 저장 경로 확인.
- Web export pack 실행에서 `demo=true`, 가로 화면 및 `Zombie Buster Demo` 저장 경로를 직접 확인.

검증 캡처와 로컬 로그는 `output/validation/`에 저장하며 버전 관리에서 제외합니다.

실행 환경의 인증서 저장소 읽기 오류와 종료 시 리소스 누수 경고가 있습니다. 동일한 누수 경고는 기존 키보드 회귀 테스트에서도 발생하며, 원인 규명은 이번 화면/버전 분리 작업에 포함하지 않았습니다. 검증이 경고 없는 출시 QA 완료를 뜻하지는 않습니다.

itch.io 실제 페이지 업로드/결제, 브라우저별 저장 지속성, Android/iOS 기기 검증은 아직 수행하지 않았습니다. 체험판 콘텐츠 제한과 Windows 판매 가격도 미정입니다.
