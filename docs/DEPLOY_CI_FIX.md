# 2026-09-11 배포 검사 수정

실패 실행: https://github.com/kosj/game_action_defence/actions/runs/34571659651

- Text fit: 새 SuburbEncounter 안내 라벨이 커버리지 목록에 없었다. 준비/거리/자동 이동 문구와 시간 표시를 세 언어로 측정하는 항목을 추가했다.
- Check texture atlas: 썸네일 PNG 저장 경로를 런타임 PNG 로딩으로 오인했다. 캡처 도구는 이제 `output/validation/theme_suburb.png`에 저장한다. 검토 후 `assets/ui/thumbs/theme_suburb.png`로 복사하고 메뉴 아틀라스를 다시 생성한다. 실제 런타임 참조 검사는 그대로 유지한다.
- 후속 환경 검사: suburb가 비활성화한 옛 PropField를 계속 검사하고 있었다. 해당 테마는 옛 배치의 비활성 상태를 확인하고, 별도 verify_suburb 검사에서 새 구역/이동/보스전을 검증한다.
- 이미지 가져오기: --quit 대신 --import로 가져오기 완료를 기다리고, 타임아웃 외의 실패 코드도 전파한다. 실패한 CI 로그에는 UIStyle의 이미지 사전 로딩 오류도 있었다.
- 플랫폼별 글꼴 측정 차이: 기존 보상 등급 제목의 여유 폭이 Windows에서 12% 기준 아래였다. 제목 글꼴을 40에서 38로 조정하고 검사 수치도 일치시켰다.

로컬에서 문구 폭/아틀라스/배칭/환경/주택가/마우스 검사를 실행한다. CI의 나머지 씬과 verify 스크립트 30개 실행도 통과했다. 웹 게임 플레이 확인은 기존 사용자 요청에 따라 직접 수행하지 않는다.
