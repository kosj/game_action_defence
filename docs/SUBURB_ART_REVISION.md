# 주택가 탑뷰 배치 보완

## 적용

- 사선 주택 그림의 90/180도 회전을 제거했다. 같은 카메라 방향에서 입구만 동서남북을 향하도록 네 가지 그림을 새로 생성했다. 기존 그림은 보존했다.
- 건물 표시 크기를 300×250으로 맞췄다. 기존 280×220 충돌 경계와 보스 빈터 반경 780은 유지한다.
- 폭 320의 주택가 도로와 보도를 추가했다. 집마다 독립된 짧은 진입로가 연결되며, 마당을 가로지르던 긴 공용 콘크리트 띠를 제거했다.
- 잔디 색·깎은 결·짧은 뒤뜰 화단으로 필지를 구분한다. 소품과 조경에는 충돌을 추가하지 않는다.
- 우편함을 각 진입로의 도로 쪽 입구에 배치한다. 보스 빈터에는 입구와 주차선이 있는 공용 주차장을 표현한다.

## 검증

Godot 4.3 실제 가로 화면에서 시점과 연결 상태를 확인했다. `verify_suburb.gd`의 일반/흔들기/원거리/자폭 좀비 이동, 빈터 확보, 보스전 자동 이동, 드롭 보존, 저장 복원, 일시정지, 사망 취소 검사는 실패 0건이다.

같은 Windows 환경의 좀비 320마리 벤치마크: 중앙값 16.682ms, 95백분위 19.765ms, 표본 1200개. 기존 main의 19.036ms 대비 약 3.8% 증가한다. 실제 휴대전화 성능을 뜻하지 않는다.

## 생성 기록

내장 imagegen 사용. 생성 PNG의 알파를 보존해 `assets/suburb/house_south.png`, `house_north.png`, `house_east.png`, `house_west.png`에 복사했다. 각 이미지의 Godot 가져오기 최대 크기는 512다. 실제 게임 렌더에서 썸네일을 다시 캡처한다.

### south

Game asset for a 2D overhead zombie survival game. One American single-storey suburban house isolated on a TRUE TRANSPARENT background. Fixed orthographic camera looking almost vertically downward (85 degrees), north is UP, camera very slightly south of building. Horizontal and vertical roof edges aligned with image axes, NO isometric diamond, NO camera roll. Roof dominates, only a very thin SOUTH wall is visible at the BOTTOM, never on top or the sides. Sun always from upper-left. Short soft shadow southeast only. Muted believable hand-painted game art, weathered shingles, small gutters, modest chimney. Building footprint is wider than tall (280x220 proportions). Center whole building with ample transparent margins. No lawn, roads, fence, people, text, watermark or background. Ivory ranch with warm dark brown gable roof. The front door and tiny entrance porch face SOUTH, on the BOTTOM side. House aligned east-west.

### north

Game asset for a 2D overhead zombie survival game. One American single-storey suburban house isolated on a TRUE TRANSPARENT background. Fixed orthographic camera looking almost vertically downward (85 degrees), north is UP, camera very slightly south of building. Horizontal and vertical roof edges aligned with image axes, NO isometric diamond, NO camera roll. Roof dominates, only a very thin SOUTH wall is visible at the BOTTOM, never on top or the sides. Sun always from upper-left. Short soft shadow southeast only. Muted believable hand-painted game art, weathered shingles, small gutters, modest chimney. Building footprint is wider than tall (280x220 proportions). Center whole building with ample transparent margins. No lawn, roads, fence, people, text, watermark or background. Sage-gray bungalow with charcoal hip roof. The tiny entrance porch faces NORTH at the TOP of the roof outline. The BOTTOM thin wall is the BACK wall with two small windows. Do not rotate camera or put a tall wall on top.

### east

Game asset for a 2D overhead zombie survival game. One American single-storey suburban house isolated on a TRUE TRANSPARENT background. Fixed orthographic camera looking almost vertically downward (85 degrees), north is UP, camera very slightly south of building. Horizontal and vertical roof edges aligned with image axes, NO isometric diamond, NO camera roll. Roof dominates, only a very thin SOUTH wall is visible at the BOTTOM, never on top or the sides. Sun always from upper-left. Short soft shadow southeast only. Muted believable hand-painted game art, weathered shingles, small gutters, modest chimney. Building footprint is wider than tall (280x220 proportions). Center whole building with ample transparent margins. No lawn, roads, fence, people, text, watermark or background. Pale tan single-storey ranch with muted terracotta hip roof. A tiny entrance canopy projects EAST at RIGHT center. The thin wall visible at BOTTOM remains the south side wall. Wide horizontal rectangular roof.

### west

Game asset for a 2D overhead zombie survival game. One American single-storey suburban house isolated on a TRUE TRANSPARENT background. Fixed orthographic camera looking almost vertically downward (85 degrees), north is UP, camera very slightly south of building. Horizontal and vertical roof edges aligned with image axes, NO isometric diamond, NO camera roll. Roof dominates, only a very thin SOUTH wall is visible at the BOTTOM, never on top or the sides. Sun always from upper-left. Short soft shadow southeast only. Muted believable hand-painted game art, weathered shingles, small gutters, modest chimney. Building footprint is wider than tall (280x220 proportions). Center whole building with ample transparent margins. No lawn, roads, fence, people, text, watermark or background. Red-brown brick cottage with slate gray hip roof. A tiny entrance canopy projects WEST at LEFT center. The thin wall visible at BOTTOM remains the south side wall. Wide horizontal rectangular roof.
