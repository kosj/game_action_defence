# Zombie Buster (Godot 4.3 · 모바일 세로 WebGL)

탑다운 액션 디펜스(뱀파이어 서바이버 계열). 720×1280 세로, 렌더러 `gl_compatibility` 고정.

> ⚠️ 2026-08-20 현행화. 그 전 README 는 **초기 프로토타입 기준**이었다 — 좀비 6종·오토로드 2개·
> `Polygon2D` 플레이스홀더를 적고 있었고, 나열한 스프라이트 7개 중 6개는 이미 없는 파일이었다.
> 신규 기여자의 첫 진입점이므로 여기가 틀리면 없는 시스템을 전제로 작업하게 된다.

## 먼저 읽을 것

- **`CLAUDE.md`** — 작업 규약. 데이터 생성기·로케일·아틀라스·풀링·검증 목록. **필수.**
- **`HANDOFF.md`** — 살아 있는 작업 큐(§1 점유 표). 여러 세션이 병렬로 작업한다.
- `BALANCE.md`(실측) · `CONTENT_PLAN.md`(확장) · `POLISH_PLAN.md`(연출) · `ROADMAP.md`(완료 기록)

## 실행

1. Godot 4.3 으로 이 폴더(`project.godot`)를 연다.
2. F5 로 플레이. 데스크톱에선 마우스 드래그가 터치로 변환돼 조이스틱이 동작한다.
3. 헤드리스 검증·회귀 테스트 목록은 `CLAUDE.md` §3.

## 조작

- 화면을 누르고 드래그 → 가상 조이스틱으로 이동.
- 무기는 **자동 발사**된다. 사이드뷰라 총구는 좌우(이동 방향)를 향한다.

## 구조

```
Main.tscn ─ Main.gd                 # 판 진입점(풀 프리워밍·이전 판 잔재 청소)
 ├─ Background (ColorRect)          # 테마 배경색
 ├─ Ground ─ Ground.gd              # 테마별 바닥 타일(월드 고정 타일링)
 ├─ PropField ─ PropField.gd        # 미장센 프롭 배치(테마별, 일부는 장애물)
 ├─ DayNight ─ DayNightCycle.gd     # 시간대 색조
 ├─ Weather ─ WeatherSystem.gd      # 비/눈/모래(테마별 후보에서 추첨)
 ├─ Player.tscn ─ Player.gd         # CharacterBody2D. Body/Shadow=Sprite2D, Muzzle, Camera2D
 ├─ ZombieSpawner ─ ZombieSpawner.gd  # 시간 기반 스폰·엘리트·스웜·보스
 ├─ ItemPickupSpawner               # 보물상자/진화상자
 ├─ GimmickSpawner                  # 테마별 방해 기믹
 ├─ HUD.tscn ─ HUD.gd (CanvasLayer)   # 체력·골드·처치·타이머·타임라인·일시정지
 └─ LevelUpPanel                    # 레벨업/진화 카드
```

주요 씬: `Zombie.tscn`(11종을 데이터로 주입) · `Boss.tscn`(테마 보스 3종) ·
`Bullet.tscn` · `Gold.tscn` · `ItemPickup.tscn` · `MainMenu.tscn` · `TitleScreen.tscn`.

**오토로드 20개** — 목록과 역할은 `CLAUDE.md` §4 에 있다(중복해 적지 않는다).

## 콘텐츠 규모

| | 수 | 정의 위치 |
|---|---|---|
| 무기 | 30 (기본 16 + 진화 11 + 궁극기 3) | `data/item_catalog.tres` |
| 패시브 | 10 | 〃 |
| 좀비 | 11 | `data/zombies/*.tres` |
| 보스 | 3 (테마 전용) | `ZombieSpawner.THEME_BOSSES` |
| 캐릭터 | 3 | `data/character_db.tres` |
| 아레나(테마) | 3 | `data/themes.tres` |
| 위협 등급 | 20 | `data/threat_ranks.tres` |

⚠️ **`data/**.tres` 는 손으로 고치지 않는다** — 전부 `tools/gen_*.gd` 생성기의 산출물이다
(예외: `data/balance.tres`). `CLAUDE.md` §2 참고.

## 오브젝트 풀링

좀비·총알·골드·FX 는 `queue_free()` 대신 `Pool.release()` 로 트리에서 떼어내 재사용한다
(GC 스파이크 방지 → WebGL 프레임 안정). 풀 대상 스크립트는 `on_spawn()` 으로 상태를
초기화하고, `_ready()` 는 시그널 연결 같은 1회성 셋업만 담당한다.
`Main` 이 판 시작에 `Pool.prewarm()` 으로 미리 채운다.

## 물리 레이어

`1=player · 2=zombies · 3=bullets · 4=gold`

## 튜닝 포인트

전투 수치는 **인스펙터가 아니라 데이터 테이블**에 있다. 코드에 새로 하드코딩하지 않는다.

- `data/balance.tres` — 전투/보상 밸런스(손으로 조정하는 유일한 테이블)
- `data/difficulty.tres` — 시간 기반 난이도 곡선(스폰 간격·동시 상한·체력/이속 곡선·이벤트 주기)
- `data/threat_ranks.tres` — 위협 등급별 배수(기존 밸런스 **위에 곱한다**)
- `MobileJoystick` 의 `@export` — 조이스틱 감도만 인스펙터에 남아 있다

## 아트 에셋

유닛·보스·프롭·아이콘은 이 프로젝트 전용 아트이며, 아틀라스로 묶여 있다
(`assets/atlas/`). 일부 UI/발사체는 [Kenney](https://www.kenney.nl/) CC0 에셋에서 왔다.

- 유닛 스프라이트 규약: 배경 투명 · 타이트 크롭 · **높이 120px** · 사이드뷰 오른쪽 향함
- 새 스프라이트는 **반드시 아틀라스에 넣는다**(PNG 직접 참조는 배칭을 끊는다)
- 절차 생성물: `sprites/shadow.png`(소프트 그림자)
- 파이프라인 상세: `ASSET_PIPELINE.md`

## WebGL 빌드

Project > Export > Web. **pck 상한 15MB**(CI 게이트, 현재 약 12MB).
빌드·배포는 `.github/workflows/export-web.yml` 이 자동으로 돌린다.
