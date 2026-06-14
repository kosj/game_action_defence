# 개발 로드맵

탑다운 액션 디펜스 (뱀파이어 서바이버 / 탕탕특공대 스타일) 진행 현황.

## ✅ 완료
- [x] **0. 프로젝트 뼈대** — Main/Player/Zombie/Bullet/Gold/HUD 씬 + 가상 조이스틱,
      자동 공격, 좀비 추적, 화면 밖 스폰, 골드 자석 수집, gl_compatibility 설정.
- [x] **1. 오브젝트 풀링** — `Pool` autoload로 좀비/총알/골드 재사용 (GC 스파이크 방지).
      `on_spawn()` 상태 초기화 + 지연 반납 + `_alive` 가드, Main 에서 prewarm.
      `on_despawn()` 정리 훅을 좀비/총알/골드에 구현(반납 직전 그룹 해제 등).
- [x] **2. 플레이어 체력 · 게임오버** — Player `max_health`/`health` + `Hurtbox`(Area2D,
      mask=zombies) 접촉 데미지(쿨다운). 체력 0 → `Events.player_died` → HUD 게임오버
      패널 + 재시작 버튼. HUD 체력바(ProgressBar). 재시작 시 `Pool.clear()` 후 씬 리로드.

## ⬜ 남은 작업

### 3. 좀비 종류 · 웨이브 난이도 곡선
- 좀비 변형: 기본/빠른(저체력 고속)/탱커(고체력 저속). `@export` 스탯 또는 별도 씬.
- 경과 시간 기반 난이도: `spawn_interval` 점감, `max_zombies` 점증, 좀비 체력 스케일.
- 웨이브/타이머 표시(HUD). 보스 웨이브(선택).
- 스포너를 데이터 주도(웨이브 테이블/Resource)로 리팩터.

### 4. 실제 스프라이트 · 애니메이션  *(진행 중)*
- [x] `Polygon2D` 플레이스홀더 → `Sprite2D` 교체(Kenney CC0 에셋, `assets/sprites/`).
      플레이어/좀비/총알이 진행·조준 방향을 바라보게 회전.
- [ ] `AnimatedSprite2D` 로 좀비 걷기/사망, 플레이어 이동, 총구 플래시, 골드 반짝임.
- [ ] 텍스처를 단일 아틀라스로 묶어 드로우콜 절감(모바일 WebGL 배칭).
- [ ] 사망 시 짧은 연출 후 풀 반납(애니메이션 finished 시그널 활용).
- [ ] 배경 ColorRect → 타일 텍스처(top-down 타일셋).

## 추가 아이디어 (백로그)
- 무기 업그레이드 / 레벨업 선택(골드 소비).
- 데미지 텍스트, 화면 흔들림, 사운드(첫 터치 이후 재생).
- 좀비 화면 밖 자동 정리(`VisibleOnScreenNotifier2D` 또는 거리 컷).
- 점수/최고기록 저장(`user://`).

---
다음 우선순위: **3번(좀비 종류·웨이브 난이도 곡선)**.
