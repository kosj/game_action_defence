# 도심·연구소 구역 배치

도심은 낮은 상가와 하역 창고, 주차 면, 횡단보도, 폐차·쓰레기통·잔해를 사용한다. 연구소는 실험동과 냉각 설비, 차가운 콘크리트 통로, 설비 점검 구역, 콘솔·드럼통을 사용한다. 실내 미로가 아닌 넓은 연구 시설 구역이다.

건물은 남쪽 벽면이 보이는 주택가와 같은 시점이다. 남쪽 필지는 옆 진입로를 돌아 정면에 도달한다. 작은 소품은 통행을 막지 않는다.

## 공통 처리

`SuburbWorld.supports()`가 세 테마를 연결한다. 기존 클래스·그룹·저장 키의 이름은 이전 저장 및 호출부와의 호환을 위해 유지한다. `DistrictScenery`는 테마별 건물·바닥·부속물만 담당하고, 건물 위치와 크기, TileMapLayer, NavigationRegion2D, 군중 경로 공유, 넉백 충돌, 가림 반투명, 활성 구역 상한은 같은 구현을 사용한다.

세 테마 모두 2560 구역, 280×220 건물 충돌, 표시 크기 320×280, 주 이동로 320 이상, 보스 빈터 반경 780을 유지한다. 내비게이션은 저장된 구역 리소스를 재사용하며 전투 중 다시 굽지 않는다. 보스 안내 15초, 유예 후 자동 이동, 드롭 보존, 저장 복원도 공유한다. 위험물은 건물에서 85 이상 떨어진 점으로 보정하고 강제 이동 때 이전 위험물을 정리한다.

테마 식별자·해금·기존 보스·날씨·위험물 종류는 유지한다. 이전 무작위 PropField와 Ground는 세 테마에서 비활성화한다.

## 검증

세 테마의 100구역 기하, 연결 경로, 네 종류 좀비 이동, 가림, 보스 이동, 드롭 보존, 이어하기, 일시정지 및 사망 취소 검사를 실행한다. 도심·연구소에는 위험물이 건물 내부에 스폰되지 않는 검사도 추가했다. CI에서 세 테마를 각각 실행하도록 확장했다. 가로 및 모바일 세로 프리뷰는 실제 Godot 렌더로 확인한다. 브라우저 플레이는 사용자가 확인한다.

최종 세 테마 검사 실패 0건, 도심·연구소 세로 프리뷰 검사 실패 0건. CI 목록의 공통 씬·검증 스크립트 29개 모두 종료 코드 0이다. 아틀라스 125개, GDScript 정적 검사 120개 파일, 텍스트 크기 검사 통과. Windows / Web / Mobile Preview 내보내기와 ZIP 무결성 검사도 통과했다. 웹 PCK는 11,164,416바이트로 15MiB 제한 이내다.

Godot 4.3 / 동일 Windows GPU 환경 / 시드 42 / 좀비 320마리 / 5초 준비 후 20초 측정. 기준은 직전 main 48a8570의 각 테마이고, 같은 벤치마크에 테마 선택 인자만 추가했다.

| 테마 | 변경 전 p95 | 최종 p95 | 변화 | 최종 중앙값 |
|---|---:|---:|---:|---:|
| 도심 | 18.978ms | 19.605ms | +3.3% | 16.677ms |
| 연구소 | 19.013ms | 19.550ms | +2.8% | 16.826ms |

각 최종 실행은 1201프레임이다. 개별 소품 노드를 사용한 초기 실행은 도심 20.547ms, 연구소 20.907ms였으며, 소품을 구역별 CanvasItem 하나로 묶은 뒤 위 결과를 얻었다. 모든 프레임 60fps나 실제 모바일 기기의 성능을 보장하는 결과는 아니다. 기존 인증서 저장소 및 종료 시 리소스 해제 경고는 남아 있다.

## 이미지 생성

내장 image_gen 사용. 아래 PNG는 실제 RGBA 알파를 확인하고 프로젝트에 복사했다. 가져오기 최대 크기는 512다. 기존 소품은 테마별 아틀라스를 사용한다. 바닥은 Godot FastNoiseLite와 네이티브 그리기로 만든 콘크리트 및 구역 표시다.

### assets/districts/city_shop.png

Single isolated building sprite for a top-down 2D zombie survival game. RGBA PNG with ACTUAL TRANSPARENT background, alpha zero outside object; no painted checkerboard or background. Muted hand-painted realistic game art. Orthographic camera from SOUTH elevation 60 degrees. Roof dominates upper 70 percent, SOUTH wall clearly visible along BOTTOM 30 percent. All footprint edges horizontal/vertical, NO diamond isometric angle, NO camera roll. A low rectangular structure footprint ratio 280:220, no tall towers. Light upper-left, tiny tight contact shadow only, no surrounding street, lawn, people, lettering or glow. Entire structure inside image with modest margins. Abandoned American downtown corner retail building, single storey. Weathered red-brown brick facade, broad flat dark roof with parapet and small rectangular HVAC, dark storefront windows and faded dark teal awning on bottom facade, side service doors on left and right. No readable signage.

### assets/districts/city_depot.png

Single isolated building sprite for a top-down 2D zombie survival game. RGBA PNG with ACTUAL TRANSPARENT background, alpha zero outside object; no painted checkerboard or background. Muted hand-painted realistic game art. Orthographic camera from SOUTH elevation 60 degrees. Roof dominates upper 70 percent, SOUTH wall clearly visible along BOTTOM 30 percent. All footprint edges horizontal/vertical, NO diamond isometric angle, NO camera roll. A low rectangular structure footprint ratio 280:220, no tall towers. Light upper-left, tiny tight contact shadow only, no surrounding street, lawn, people, lettering or glow. Entire structure inside image with modest margins. Low urban service depot, single storey. Concrete and dark beige brick walls, broad flat weathered gray roof with rectangular ventilation boxes. Two closed loading roller doors on BOTTOM wall, side service access. Small patches of chipped paint, restrained yellow industrial trim. No vehicles or exterior clutter.

### assets/districts/lab_research.png

Single isolated building sprite for a top-down 2D zombie survival game. RGBA PNG with ACTUAL TRANSPARENT background, alpha zero outside object; no painted checkerboard or background. Muted hand-painted realistic game art. Orthographic camera from SOUTH elevation 60 degrees. Roof dominates upper 70 percent, SOUTH wall clearly visible along BOTTOM 30 percent. All footprint edges horizontal/vertical, NO diamond isometric angle, NO camera roll. A low rectangular structure footprint ratio 280:220, no tall towers. Light upper-left, tiny tight contact shadow only, no surrounding street, lawn, people, lettering or glow. Entire structure inside image with modest margins. Low sealed research laboratory module in an abandoned cold research campus. Cool off-white rectangular metal and concrete walls, flat slate blue roof with two small square ventilation panels. Bottom wall has dark cyan observation windows and a sealed double door; side access doors. Very restrained turquoise pipe accents, light frost on roof edge only. Grounded and functional, no science fiction glowing neon.

### assets/districts/lab_cooling.png

Single isolated building sprite for a top-down 2D zombie survival game. RGBA PNG with ACTUAL TRANSPARENT background, alpha zero outside object; no painted checkerboard or background. Muted hand-painted realistic game art. Orthographic camera from SOUTH elevation 60 degrees. Roof dominates upper 70 percent, SOUTH wall clearly visible along BOTTOM 30 percent. All footprint edges horizontal/vertical, NO diamond isometric angle, NO camera roll. A low rectangular structure footprint ratio 280:220, no tall towers. Light upper-left, tiny tight contact shadow only, no surrounding street, lawn, people, lettering or glow. Entire structure inside image with modest margins. Low rectangular industrial cooling plant building in a cold research campus. Blue-gray metal walls, flat charcoal roof carrying two broad shallow circular fan grilles flush inside roof, small attached pipes entirely within footprint. Bottom wall has horizontal ventilation slats and a sealed service door, side service access. Worn pale paint and faint frost, very small muted yellow warning patches. No tall tanks or towers.
