# Zombie Buster — 최적화 리뷰 & 실행 계획

> 2026-08 전수 리뷰. 게임플레이 핫패스 / UI·FX / 에셋·익스포트 3개 축으로
> 전체 스크립트(~15k줄)·씬·에셋·CI를 조사한 결과와 단계별 실행 계획.

---

## 0. 총평

**기본기는 이미 잘 되어 있다.** 아래는 검증된 "잘 된 부분"이므로 건드리지 않는다.

- 오브젝트 풀링: `Pool.gd`(트리 분리 + `call_deferred` 중복 반납 방지 + prewarm), FX/데미지숫자 정적 풀
- 스폰 제어: 적 상한 40→320 보간, 스폰 큐 프레임당 12개 분산(`spawn_budget_per_frame`), 젬 상한 140 + 강제 흡수
- 좀비 자체: 물리 바디 미사용(직접 적분 이동), 씬 3노드로 슬림, 30Hz 애니 + 화면 밖 LOD, 그리드 기반 분리
- 공간 해시: `Events.live_zombies()` 스냅샷 + `zombies_near()` 셀 질의
- HUD: 완전 이벤트 구동(`_process` 없음), 진행 신호 초당 1회 스로틀
- SoundManager: 사운드별 최소 재생 간격 스로틀, SFX 총 680KB로 가벼움
- 렌더러 `gl_compatibility`, 부트 스플래시 off, stretch 설정 — 웹/모바일 타깃에 적절
- `Main.gd`: `_process` 없음, prewarm을 첫 프레임 이후로 지연 — 구조 양호

**그러나 두 가지 큰 구멍이 있다:**

1. **초기 로딩 30MB 중 17MB가 BGM.** 웹 pck는 전량 받아야 첫 화면이 뜨는데, 19분짜리 MP3가 통째로 들어가 있다. 코드 최적화 전부를 합친 것보다 이거 하나가 크다.
2. **런타임 병목은 적 수가 아니라 "그리기"에 있다.** 바닥 전체 재드로우(매 프레임), 데미지 숫자 동시 상한 부재(~500개 동시 텍스트 렌더 가능), 총알의 불필요한 물리 등록 등.

---

## 1. Phase A — 용량/로딩 (코드 수정 거의 없음, 효과 최대)

목표: 초기 로딩 **~30MB → ~8MB**

| # | 작업 | 절감 | 난이도 |
|---|---|---|---|
| A1 | BGM 3곡을 60~90초 심리스 루프로 재인코딩 (`bgm_game_2` 19분/8.7MB, `bgm_game_1` 9.4분/4.3MB, `bgm_title` 8.4분/3.8MB) | **-15MB** | 하 |
| A2 | `assets/fonts/NotoSansKR-Regular.ttf` / `NotoSansKR.bin` **삭제** — 둘 다 폰트가 아니라 다운로드 실패로 커밋된 **동일한 HTML 문서**(598KB). 코드 참조 0건, `export_filter="all_resources"` 탓에 웹 빌드에 포함되는 중 | -598KB | 최하 |
| A3 | 텍스처 손실 WebP 전환: `.gitignore`에서 `*.import` 제외 해제 후 커밋, 큰 파일부터(`bg_title.png` 623KB, `logo_title.png` 410KB, `thumbs/*` 3장 766KB, `prop_*` 384px 계열) | 약 -4.5MB | 중 |
| A4 | CJK 서브셋 폰트를 KR 전용으로 재생성 (현재 JP 포함 1.2MB×2 → 각 300~400KB) | -1.6MB | 중 |
| A5 | A1 완료 후 PWA 활성화 (`progressive_web_app/enabled=true`) — GitHub Pages는 캐시 헤더 제어 불가라 재방문 로딩 개선 수단이 이것뿐 | 재방문 로딩 | 하 |

**주의(A3와 한 몸):** `export_presets.cfg`가 타깃과 반대다 —
`vram_texture_compression/for_desktop=true, for_mobile=false`. 모바일 웹이 주 타깃이므로
`for_mobile=true, for_desktop=false`로 뒤집는다. VRAM 압축을 켜는 순간 이걸 안 고치면
모바일 브라우저에서 텍스처가 깨진다. (현재 PNG 138장이 무압축 RGBA8로 VRAM 26.7MB —
저사양 WebGL에서 위험 구간)

## 2. Phase B — 런타임 핫패스 (인게임 프레임)

목표: 대난전(좀비 300+) 프레임 안정화. 효과 순.

| # | 작업 | 파일 | 난이도 |
|---|---|---|---|
| B1 | **Ground 재드로우를 타일 경계 기준으로**: 현재 임계값 0.7px라 이동 중 매 프레임 화면 전체(드로우 커맨드 120~400개) 재발행. 타일 격자 스냅 + 1타일 마진, 셀이 바뀔 때만 `queue_redraw()`. 절차적 테마의 `match theme:` 문자열 비교는 int enum으로 | `Ground.gd:87-96` | 중 |
| B2 | **DamageNumber 동시 활성 상한**: `MAX_PER_FRAME 14`만 있고 `MAX_ACTIVE`가 없어 이론상 ~500개 동시 텍스트 렌더. `MAX_ACTIVE := 32` 추가(FXBurst 패턴), `MAX_PER_FRAME` 14→8, 문자열 폭 spawn 시 1회 캐시, 팝 종료 후 fsize 고정 | `DamageNumber.gd` | 하 |
| B3 | **Bullet을 Node2D로**: 명중은 스윕+공간 해시로 하는데 씬 루트가 `Area2D`+CollisionShape라 총알 수십~수백 발이 물리 broadphase에 상시 등록됨. Zombie.tscn엔 CollisionShape가 없어 시그널 경로는 보스에만 걸림(이중 피해 위험까지). `EnemyBullet.tscn`(이미 Node2D)과 동일하게 정리. Player.tscn의 죽은 `Hurtbox`도 제거 | `Bullet.tscn`, `Bullet.gd:30-31,140-144` | 하 |
| B4 | **공간 해시 할당 제거**: `zombies_near()`가 호출마다 새 Array 생성(프레임당 ~70회, 초당 4천+ 할당), 그리드 rebuild가 셀 배열을 매번 새로 만듦(프레임당 200~450회). 셀 배열 재사용(`clear()` 유지) + 조회는 멤버 버퍼 재사용 | `Events.gd:283-313`, `ZombieSpawner.gd:460-467` | 중 |
| B5 | **`zombies_in_radius(pos, r)` 헬퍼 추가 후 전수 스캔 이관**: Flamethrower/Chainsaw/TurretUnit은 조준용으로 **매 프레임** 전체 좀비 O(N) 순회(3개 동시면 ~2,000회/프레임). ProjectileWeapon·Tesla·GarlicAura·HolyWater·MeleeArc·Lightning·Ultimate·Drone·스플래시도 동일 패턴 | `WeaponModule.gd:26-36` 외 10곳 | 중 |
| B6 | **Boss 피격 연출을 Zombie 방식으로 통일**: 피격마다 Tween 생성(초당 수십 개) → `_flash` 감쇠 변수로. `bypass_cap=true` 데미지 숫자도 보스 전용 낮은 상한으로 | `Boss.gd:518-540,526` | 하 |
| B7 | **y_sort 대상 축소**: 좀비·총알·FX·숫자 전부 Main 루트(y_sort=on) 직속이라 자식 500~800개를 매 프레임 정렬. `Units`(y_sort on)/`Effects`(off) 컨테이너 분리 | `Main.tscn`, 스폰 호출부 | 중 |
| B8 | **UITheme 전역 `node_added` 훅 제거**: 모든 노드 추가(풀 재사용 포함 — 스폰마다!)에 GDScript 콜백 + `is Button` 체크. 버튼 눌림 연출은 `UIStyle.apply_button_style()`에서 연결. 중복 connect 버그도 함께 해소 | `UITheme.gd:55-67` | 하 |
| B9 | **FXLightning 풀링 + 머티리얼 공유**: 유일하게 비풀링(`new()`/`queue_free()`), 인스턴스마다 `CanvasItemMaterial.new()`로 배칭 파괴, 상한 없음. FXBurst 패턴 적용 + `Main._clean_slate()` 리셋 목록에 추가 | `FXLightning.gd`, `Lightning.gd:54-57` | 중 |
| B10 | **HUD 오버레이 alpha=0 시 `visible=false`**: FlashOverlay/LowHpOverlay/Vignette 3장이 투명한 채 상시 풀스크린 블렌딩(프레임당 ~276만 px fill-rate 낭비). Vignette는 사용 여부 확인 후 삭제 검토 | `HUD.tscn`, `HUD.gd:473-500` | 최하 |
| B11 | **HP바 트윈 kill 누락**: `_update_hp_bar`가 이전 트윈을 kill하지 않아 연속 피격 시 트윈이 누적되고 바가 튐(성능+시각 버그). 골드 카운터는 프레임당 1회 코얼레싱 | `HUD.gd:349-358,176-190` | 최하 |
| B12 | 엔진 설정: `physics/common/physics_ticks_per_second=30`(현재 기본 60 — 물리 비용 절반), `max_physics_steps_per_frame` 하향(death spiral 방지) | `project.godot` | 최하 |
| B13 | `AUTOSAVE_INTERVAL` 4→20초: 웹에선 저장이 IndexedDB 동기화라 히칭 유발. 체크포인트 저장(웨이브/상점/백그라운드 전환)이 이미 있어 손실 위험 없음 | `Player.gd:73` | 최하 |

## 3. Phase C — 마무리 (낮은 심각도, 여유 있을 때)

- HolyWater: `filter()`+람다로 프레임당 배열 3개+Callable 3개 할당 → 역방향 `remove_at()` (`HolyWater.gd:42-61`)
- GarlicAura: 매 프레임 절차 드로우(폴리곤 9개 매번 재생성) → 20Hz 스로틀 + 살(rays)은 `rotation`으로 (`GarlicAura.gd:28-63`)
- PropField: `_cell_prop()`이 호출마다 Dictionary 생성 → 3×3 캐시, 셀 경계에서만 갱신 (`PropField.gd:89-135`)
- SpriteFX `_recycle()`: 트리 분리 누락(비활성 노드의 `_process`가 계속 돎) + `_active` 음수 가드 (`SpriteFX.gd:76-80`)
- 스폰 dict `duplicate()` → 티어별 스탯 초당 1회 캐시 (`ZombieSpawner.gd:265,387`)
- 부메랑 투사체 풀링 (`BoomerangProj.gd`)
- 죽은 코드 삭제: `Player.gd:437-453`의 미사용 O(N) 타겟팅(`_get_nearest_zombie` 등)
- StyleBox 정적 캐시: `UIStyle`의 disabled/focus 싱글턴화, `UIListRow` 상태별 3종 캐시, 메뉴 리스트 행 재사용(참조 구현: `ShopPanel._refresh_buttons()`)
- HUD 로드아웃 슬롯 전체 재생성 → 변경분만 갱신 (`HUD.gd:748-763`)
- 좀비 사망 플레이어 조회: 게임오버 시 좀비 320마리가 각자 매 프레임 그룹 조회 → `player_died` 구독 (`Zombie.gd:127-129`)
- 폰트 크기 19종 → 인접 값 통합(글리프 아틀라스/래스터화 히칭 감소)

## 4. Phase D — CI/인프라

- `export-web.yml`의 임포트 스텝 `|| true` 제거 + 타임아웃 120→300s: 현재 임포트가 실패해도 조용히 export가 진행돼 산출물이 깨질 수 있음
- 빌드 산출물 크기 검증 스텝 추가(예: pck 10MB 초과 시 실패) — 용량 회귀 방지
- (배포 계획 확정 시) Android 익스포트 프리셋 추가 — 현재 Web 프리셋뿐

## 5. 별건 — 리뷰 중 발견한 동작 버그

- **관통탄이 프레임당 1마리만 타격**: `Bullet.gd` 스윕 판정이 명중 즉시 `return`이라 `pierce`가 남아도 같은 프레임의 추가 관통이 무시됨. 밀집 대열에서 석궁 계열 실 DPS가 설계보다 낮음. `return`→`continue`로 수정 (B3와 같이 처리 권장)

---

## 6. 진행 순서 요약

1. **A1+A2** (BGM 루프화 + 가짜 폰트 삭제): 하루 안에 로딩 절반 이하
2. **B10+B11+B2** (오버레이/트윈/데미지숫자): 30분 투자로 체감 큰 3건
3. **B1+B3** (Ground 재드로우 + Bullet 물리 제거): 인게임 베이스 프레임 확보
4. **B4+B5** (공간 해시 정비): Events.gd 국소 수정으로 무기 전체가 혜택
5. **A3+프리셋 뒤집기** → **A4** → **A5(PWA)**
6. 나머지 B → D → C 순
