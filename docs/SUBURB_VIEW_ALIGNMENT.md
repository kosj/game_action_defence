# 캐릭터와 주택가 시점 정렬

캐릭터는 유지하고 주택 4종의 아래쪽 벽면과 창문을 더 보이게 변경했다. 도로는 기존 평면 구조를 유지한다. 주택 표시 크기는 320×280, 충돌 크기는 기존 280×220이며 밑면 기준으로 배치한다. 우편함 표시 크기는 54, 소화전은 46 월드 단위다. 소품은 충돌하지 않는다.

내장 image_gen으로 생성한 PNG를 아래 경로에 복사했으며 실제 알파를 유지했다. CLI는 사용하지 않았다. 첫 번째 불투명 후보는 적용하지 않았다.

## 검증

- Godot 4.3 가로 화면과 모바일 세로 프리뷰에서 렌더 확인. 100구역 기하 검사, 네 종류 좀비 이동, 보스 안내·자동 이동·저장 복원 검사 실패 0건.
- 아틀라스 125개 항목, GDScript 정적 검사 119개 파일, 텍스트 크기 검사 통과.
- Windows / Web / Mobile Preview 내보내기 및 ZIP 무결성 검사 통과. 웹 브라우저 플레이는 사용자가 확인한다.
- 같은 로컬 환경 320마리, 1201프레임: 중앙값 16.794ms, 95백분위 19.833ms. 직전 주택가 기록 19.765ms 대비 약 0.34% 증가. 실제 모바일 기기 성능 보장은 아니다.
- 기존 인증서 저장소 및 종료 시 리소스 해제 경고는 남아 있다.

## assets/suburb/house_south.png

A single isolated 2D game sprite, RGBA PNG on an ACTUAL transparent background (alpha zero outside object). Never paint a checkerboard, white backdrop, floor or glow. Muted hand-painted realistic American suburb zombie survival game art. Fixed orthographic camera from SOUTH, elevation 60 degrees: roof/top remains dominant but upright SOUTH-facing wall is clearly visible across the BOTTOM (about 25-30 percent of sprite height). North stays UP, edges horizontal/vertical, NO diamond isometric view, NO rotation of the image, NO convergence. Light upper-left, tiny tight contact shadow at base only. Modest clear margins, no text, no people. Ivory single-storey ranch with dark brown shingle gable roof, modest chimney upper-left, centered front gabled porch and door facing SOUTH on bottom edge, shuttered front windows. Wide rectangular house, grounded low foundation.

## assets/suburb/house_north.png

A single isolated 2D game sprite, RGBA PNG on an ACTUAL transparent background (alpha zero outside object). Never paint a checkerboard, white backdrop, floor or glow. Muted hand-painted realistic American suburb zombie survival game art. Fixed orthographic camera from SOUTH, elevation 60 degrees: roof/top remains dominant but upright SOUTH-facing wall is clearly visible across the BOTTOM (about 25-30 percent of sprite height). North stays UP, edges horizontal/vertical, NO diamond isometric view, NO rotation of the image, NO convergence. Light upper-left, tiny tight contact shadow at base only. Modest clear margins, no text, no people. Sage-gray single-storey bungalow with charcoal shingle hip roof, chimney on right. Entry faces NORTH away from camera, only small canopy roof protrudes beyond TOP edge, no visible door at top and NO dormer on roof. The clearly visible BOTTOM wall is the BACK wall with three full rectangular windows. Wide rectangular house.

## assets/suburb/house_east.png

A single isolated 2D game sprite, RGBA PNG on an ACTUAL transparent background (alpha zero outside object). Never paint a checkerboard, white backdrop, floor or glow. Muted hand-painted realistic American suburb zombie survival game art. Fixed orthographic camera from SOUTH, elevation 60 degrees: roof/top remains dominant but upright SOUTH-facing wall is clearly visible across the BOTTOM (about 25-30 percent of sprite height). North stays UP, edges horizontal/vertical, NO diamond isometric view, NO rotation of the image, NO convergence. Light upper-left, tiny tight contact shadow at base only. Modest clear margins, no text, no people. Pale tan single-storey ranch with faded terracotta shingle hip roof and chimney upper-left. Front entrance canopy projects EAST on RIGHT edge. The clearly visible BOTTOM wall is the SOUTH side wall with three full rectangular windows. Wide rectangular house.

## assets/suburb/house_west.png

A single isolated 2D game sprite, RGBA PNG on an ACTUAL transparent background (alpha zero outside object). Never paint a checkerboard, white backdrop, floor or glow. Muted hand-painted realistic American suburb zombie survival game art. Fixed orthographic camera from SOUTH, elevation 60 degrees: roof/top remains dominant but upright SOUTH-facing wall is clearly visible across the BOTTOM (about 25-30 percent of sprite height). North stays UP, edges horizontal/vertical, NO diamond isometric view, NO rotation of the image, NO convergence. Light upper-left, tiny tight contact shadow at base only. Modest clear margins, no text, no people. Red-brown brick single-storey cottage with slate-gray shingle hip roof and chimney upper-right. Front entrance canopy projects WEST on LEFT edge. The clearly visible BOTTOM wall is the SOUTH side wall with three full rectangular windows. Wide rectangular house.

## assets/suburb/prop_mailbox_top.png

A single isolated 2D game sprite, RGBA PNG on an ACTUAL transparent background (alpha zero outside object). Never paint a checkerboard, white backdrop, floor or glow. Muted hand-painted realistic American suburb zombie survival game art. Fixed orthographic camera from SOUTH, elevation 60 degrees: roof/top remains dominant but upright SOUTH-facing wall is clearly visible across the BOTTOM (about 25-30 percent of sprite height). North stays UP, edges horizontal/vertical, NO diamond isometric view, NO rotation of the image, NO convergence. Light upper-left, tiny tight contact shadow at base only. Modest clear margins, no text, no people. A compact blue-gray American metal roadside mailbox, red flag on RIGHT side, closed rounded mail door facing SOUTH at bottom. Short broad model: body depth only 1.2 times its width. Readable broad front door occupies lower third; curved TOP visible in upper half. A short wooden post visible below the box, NOT a long pole. Overall sprite width about 70% of its height. Recognizable at tiny game scale.

## assets/suburb/prop_hydrant_top.png

A single isolated 2D game sprite, RGBA PNG on an ACTUAL transparent background (alpha zero outside object). Never paint a checkerboard, white backdrop, floor or glow. Muted hand-painted realistic American suburb zombie survival game art. Fixed orthographic camera from SOUTH, elevation 60 degrees: roof/top remains dominant but upright SOUTH-facing wall is clearly visible across the BOTTOM (about 25-30 percent of sprite height). North stays UP, edges horizontal/vertical, NO diamond isometric view, NO rotation of the image, NO convergence. Light upper-left, tiny tight contact shadow at base only. Modest clear margins, no text, no people. A squat faded red American fire hydrant. Round domed top and hexagonal cap visible, two stubby horizontal side outlets, clearly visible short cylindrical BODY below cap, tight round base flange. About as wide as tall, not a top-only red disc and not a tall side-view column. Worn red paint and subdued metal.
