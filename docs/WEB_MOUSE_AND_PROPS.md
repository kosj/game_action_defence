# 웹 마우스 이동 및 탑뷰 소품

웹에서는 게임 화면에서 왼쪽 마우스 버튼을 누르고 드래그하여 이동한다. 버튼을 놓으면 정지한다. WASD/방향키는 마우스보다 우선한다. 모바일 터치 방식은 유지한다.

GUI가 먼저 클릭을 처리한 뒤 남은 입력만 이동에 사용한다. 일시정지, 포커스 상실, 캔버스 이탈 시 입력을 초기화한다. 배경 ColorRect가 입력을 가로채지 않도록 수정했다.

`tools/verify_mouse_move.gd`는 실제 Viewport 이벤트 전달로 이동, GUI 클릭 차단, GUI 위에서 버튼 놓기, 키보드 우선, 일시정지/포커스/캔버스 이탈을 검증한다. 실패 0건. 기존 키보드 이동 검사 8/8 및 주택가 이동/보스전 검사 실패 0건. 이번 웹 빌드의 브라우저 실행 확인은 사용자가 직접 수행한다.

소화전과 우편함은 내장 imagegen으로 새로 생성한 탑뷰 이미지다. `assets/suburb/prop_hydrant_top.png`, `assets/suburb/prop_mailbox_top.png`에 알파 포함 원본을 보존한다. Godot 가져오기 크기는 최대 256이며, 게임에서는 알파 여백을 제외한 영역의 긴 변을 46 월드 단위로 맞춘다. 소품은 충돌 없이 표시한다.

## 소화전 생성 프롬프트

Create one isolated game prop sprite on TRUE transparent background for a 2D overhead suburban zombie survival game. Fixed orthographic camera from directly above, 85-degree elevation, north UP. Roof/top dominates; only a very thin south-facing side at the BOTTOM. Do not draw a standing side-view object, isometric diamond or turn the camera. Sun from upper-left, short soft southeast shadow. Muted realistic hand-painted textures matching weathered American suburban houses. No background, ground tile, text, scenery or characters. Center whole prop with transparent margin. A squat red American fire hydrant viewed FROM ABOVE: round red top cap clearly dominant, two short opposing side outlet caps left/right, circular dark base flange. Worn faded red paint, slight rust. Compact round silhouette, NOT a tall upright column.

## 우편함 생성 프롬프트

Create one isolated game prop sprite on TRUE transparent background for a 2D overhead suburban zombie survival game. Fixed orthographic camera from directly above, 85-degree elevation, north UP. Roof/top dominates; only a very thin south-facing side at the BOTTOM. Do not draw a standing side-view object, isometric diamond or turn the camera. Sun from upper-left, short soft southeast shadow. Muted realistic hand-painted textures matching weathered American suburban houses. No background, ground tile, text, scenery or characters. Center whole prop with transparent margin. An American roadside mailbox viewed FROM ABOVE: a long rounded blue-gray metal box with its curved TOP surface clearly visible, closed rectangular mail door facing SOUTH at bottom; small red flag folded flat along right side. Box length north-south. Supporting short timber post mostly hidden directly underneath, no tall vertical visible pole. Small soft cast shadow only.
