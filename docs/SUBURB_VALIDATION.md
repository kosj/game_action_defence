# 주택가 테마 구현 및 검증 — 2026-09-11

첫 테마 식별자 `suburb`와 해금, 날씨, 보스 구성을 유지한다. 기존 다른 테마는 기존 Ground/PropField를 사용한다.

## 구조

- SuburbLayout: 2560 단위 구역, 고정 필지와 건물 경계, 안전 위치 계산. 좌표와 환경 시드로 외형 변형을 선택한다.
- SuburbWorld: TileMapLayer 도로/마당, 재사용 주택 씬, 구역별 NavigationRegion2D. 내비게이션은 사전 생성한 리소스를 사용한다.
- 기본 도로 폭 480, 진입로 160, 보스 중심 건물 금지 반경 780. 작은 소품에는 충돌을 넣지 않는다.
- 플레이어는 건물 레이어 16과 move_and_slide를 사용한다. 좀비 추적은 구역 내비게이션 경로를 공유하고 프레임당 새 경로 요청을 6개로 제한한다. 이동 및 군중 밀어내기에 같은 건물 경계를 적용한다.
- 3×3 구역과 보스 목적지만 유지하며 오래된 구역과 주택 노드를 해제한다.
- SuburbEncounter: 예정 시각 15초 전부터 경로 방향과 목적지를 표시하고, 미도착 시 암전/전투 정지/자동 이동/1초 보호를 적용한다. 드롭은 목적지에 보존하며 일반 적 정리에 보상을 지급하지 않는다. 이어하기는 미완료 보스를 다시 예약한다.

## 검증 결과

| 검사 | 결과 |
|---|---|
| 100개 고정 구역 건물과 반경 780 빈터, 건물 내부 안전 위치 보정 | 통과 |
| Godot 내비게이션의 건물 우회와 쓸어 이동 충돌 | 통과 |
| 일반 추적·좌우 흔들기·원거리·자폭 좀비 실제 이동 함수의 집 모서리 우회 | 통과 |
| 조기 도착, 자동 이동, 드롭/경험치 보존 | 통과 |
| 활성 보스 저장/복원, 일시정지 시 시간 정지, 사망 시 안내 취소 | 통과 |
| 12개 구역 이동 후 활성 구역 ≤10, 주택 ≤80 | 통과 |
| 키보드 이동 회귀 | 8/8 |
| 이어하기 회귀 | 13/13 |
| 기존 보스 울타리 전개/구속/해제 | 통과 |
| 한국어·일본어·영어 폰트 지원 | 일반/굵은 글꼴 통과 |
| Windows 가로 / 모바일 세로 렌더 | 캡처 확인 |
| Web 실제 브라우저 | 타이틀 → 새 게임 → 주택가 선택 → 플레이 확인, 콘솔 오류 없음 |

### 성능

Godot 4.3, Windows, NVIDIA RTX 5070 Ti Laptop 환경에서 기존 main(1969adf)과 비교했다. `tools/bench_suburb.gd`로 동일 시드 42, 일반 좀비 320마리, 5초 준비 후 20초를 측정했다. 각 실행 1201 프레임이다.

| 프레임 시간 | 기존 | 주택가 |
|---|---:|---:|
| 중앙값 | 16.702ms | 16.551ms |
| 95백분위 | 19.036ms | 20.291ms |

최종 95백분위 증가율 6.6%로 10% 이내다. 수정 과정에서는 26.551ms와 154.399ms로 기준을 넘은 실행도 있었다. 건물 경계 캐시와 선분 경계 사전 검사를 적용한 뒤 계측 실행 20.553ms, 계측을 제거한 최종 실행 20.291ms를 확인했다. 154.399ms 실행의 급격한 변동 원인은 확정하지 않았으며 원자료를 남겼다. 기존 버전 재측정은 19.376ms였다. 별도의 26분 후반 전투 벤치마크에서는 양쪽 모두 중앙 FPS 60이었다. 이는 모든 프레임이 16.67ms 이내라는 뜻이나 모바일 기기 60fps 보장은 아니다.

## 검증 범위와 남은 출시 QA

자동 검사는 건물 우회 경로, 공통 충돌 처리와 네 가지 좀비 이동 행동을 검증한다. 모서리 도달 판정이 너무 넓어 멈추던 문제와 군중 이동 후 내비게이션 여백 안에서 멈추던 문제를 이 검사로 발견하고 수정했다. 장시간 플레이, 실제 휴대전화 성능/메모리, 모든 브라우저 조합은 아직 별도 검증이 필요하다. 구역 수와 노드 수 상한은 확인했지만 장시간 OS 메모리 추적은 수행하지 않았다. 100구역 검사는 기하 구조 검사이며 100회의 완주 플레이가 아니다.

기존 코드에서도 발생하는 종료 시 CanvasItem/리소스 해제 경고와 실행 환경 인증서 저장소 경고가 있다. 경고 없는 출시 QA 완료로 간주하지 않는다. itch.io 업로드와 결제 설정은 수행하지 않았다.

로컬 로그, 성능 원자료와 화면 캡처는 무시된 `output/validation/`에 있다. 재실행은 Godot 4.3에서 `--headless --path . --script res://tools/verify_suburb.gd`를 사용한다. 세로 렌더 검사는 headless 옵션 없이 `-- --mobile-preview`를 추가한다.

## 아트 생성 기록

내장 imagegen 도구로 생성했다. 외부 CLI 또는 API 키를 사용하지 않았다. 생성본은 `assets/suburb/`에 원본 PNG로 보존하며, 런타임에서 알파 여백을 제외하고 크기를 맞춘다. 소품은 기존 아틀라스를 재사용한다. 테마 썸네일은 실제 게임 렌더를 캡처하여 메뉴 아틀라스에 반영했다.

공통 주택 프롬프트: single low one-storey American building, isolated transparent background, near top-down 70-degree orthographic, front at bottom, axis-aligned, gritty hand-painted muted realistic zombie-game art, no ground, trees, characters or text, generous transparent margin.

| 저장 경로 | 추가 프롬프트 |
|---|---|
| assets/suburb/building_0.png | ivory ranch, brown roof |
| assets/suburb/building_1.png | sage bungalow, charcoal roof |
| assets/suburb/building_2.png | brick cottage, blue-gray roof |
| assets/suburb/building_3.png | cream detached garage |
| assets/suburb/asphalt.png | seamless top-down charcoal asphalt, fine worn aggregate, faint patches and cracks, no markings, low contrast hand-painted texture |
| assets/suburb/lawn.png | seamless top-down clipped muted olive lawn, no paths, trees or flowers, low contrast hand-painted texture |
