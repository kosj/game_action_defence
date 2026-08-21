# CLAUDE.md — 이 레포에서 일하는 규칙

Godot 4.3 · 모바일 세로 WebGL(720×1280, `gl_compatibility`) 탑다운 액션 디펜스.
**여러 세션이 병렬로 작업한다.** 세션끼리는 대화할 수 없고, 이 레포가 유일한 공유 메모리다.
아래는 "몰라서 사고가 났던 것"만 모았다. 게임 구조 설명은 `README.md`, 남은 작업은 `HANDOFF.md`.

---

## 1. 협업 규약 (다른 세션과 겹치지 않기)

1. **작업 단위 = `HANDOFF.md` 한 항목 = 브랜치 1개 = PR 1개.** 여러 항목을 한 PR에 묶지 않는다.
2. **착수 선언이 먼저다.** 코드를 건드리기 전에 `HANDOFF.md` §1 점유 표에서 해당 항목을
   `🔵 진행중` + 브랜치명으로 바꿔 **main 에 먼저 푸시**한다. 이걸 빠뜨리면 다른 세션이 같은 항목을 집는다.
3. **브랜치는 항상 `main` 에서 분기한다.** 다른 세션의 브랜치 위에 쌓지 않는다(머지 순서에 종속된다).
4. 시작 전 `git fetch origin main && git log --oneline origin/main -10` 으로 그 사이 머지된 것을 확인한다.
5. 완료 시 같은 PR 안에서 ① 점유 표를 `✅ (sha)` 로 ② 관련 계획 문서(`BALANCE.md` 등)를 갱신한다.
   **문서 갱신을 별도 PR로 미루지 않는다** — 그렇게 해서 지금 문서 6개가 낡았다(`HANDOFF.md` P3).

### 동시에 건드리면 반드시 충돌하는 파일
| 파일 | 규모 | 겹치는 작업 |
|---|---|---|
| `scripts/MainMenu.gd` | 1521줄 | 팝업/버튼/로케일 계열 전부 |
| `scripts/HUD.gd` | 1405줄 | 치트 게이팅·이벤트 예고·게이지 |
| `data/themes.tres` | — | 보스 배분·프롭·기믹 전부 (생성기 경유, §2 참고) |

이 셋을 건드리는 작업은 **직렬화한다**. 레인 배치는 `HANDOFF.md` 부록 참고.

### 점유 표 충돌은 정상이다 — 당황하지 말 것
`HANDOFF.md` §1 점유 표는 **모든 세션이 반드시 건드리는 단일 파일**이라 구조적으로 충돌한다.
사고가 아니라 이 방식의 비용이다. 규칙은 둘뿐이다:

1. **양쪽 상태를 합치는 방향으로 푼다.** 내 항목의 변경 + 상대 항목의 변경을 둘 다 살린다.
   **남의 행은 절대 건드리지 않는다** — 상대 세션이 방금 올린 진행 상태를 지우는 것이 유일한 실패다.
2. 완료 표시는 `✅ (실제 머지 sha)` 로 적는다. `✅ (이 PR)` 같은 자리표시자는 나중에 읽는 사람에게
   아무 정보가 아니다 — 머지된 뒤 sha 로 바꿔 둔다.

**⚠️ 충돌이 나면 CI 가 아예 붙지 않는다.** GitHub 은 머지 커밋을 만들 수 없으면 `pull_request`
워크플로를 트리거하지 않는다. 그래서 증상이 "CI 실패"가 아니라 **"체크 0개"** 로 나타나 —
CI 대기 중인 것과 구분되지 않는다.

> **PR 을 열었는데 체크가 0개면, 기다리지 말고 먼저 충돌을 의심한다.**
> `mergeable_state` 가 `dirty` 면 충돌이다. `git fetch origin main && git merge origin/main` 으로
> 풀고 푸시하면 그때 CI 가 붙는다.

---

## 2. 절대 규칙 (어기면 조용히 깨진다)

### `data/**.tres` 를 손으로 고치지 않는다
전부 `tools/gen_*.gd` 생성기의 산출물이다. **생성기를 고치고 재생성한다.**
`.tres` 를 직접 편집하면 다음 생성기 실행 때 말없이 덮어써진다.

⚠️ **이미 어긋나 있을 수 있다.** `item_catalog.tres` 는 무기 4종(부메랑·궁극기 3종)과 마늘 표기가
손으로 들어가 있었고, 규약대로 재생성하자 **그것들이 조용히 사라졌다**(P1-19 에서 발견·복구).
그러니 재생성 전후로 **반드시 목록을 대조할 것**:
```sh
git show HEAD:data/item_catalog.tres | grep -o '^id = "[a-z_]*"' | sort > /tmp/before.txt
godot --headless --path . --script res://tools/gen_item_catalog.gd
grep -o '^id = "[a-z_]*"' data/item_catalog.tres | sort | diff /tmp/before.txt -
```
`verify_bullet_budget.gd` 가 궁극기 소실만은 CI 에서 잡지만, 나머지는 이 대조가 유일한 안전망이다.
(이 게이트는 P1-25 에서 무기 30종 전부의 **동시 존재 개체 수 실측**으로 바뀌었다 — 씬을 띄우므로
`--fixed-fps 60` 이 필요하다. 13초 걸린다.)

⚠️ **`difficulty.tres` 도 같은 상태였다**(P1-20 에서 발견·수정). `gen_difficulty_data.gd` 는
`DifficultyData.new()` 의 **스크립트 @export 기본값을 그대로 저장**할 뿐인데, 커밋된 `.tres` 는
8개 필드가 달랐다(동시 상한 175 vs 320 등). 재생성하면 튜닝이 통째로 되돌아간다.
지금은 기본값을 배포 값에 맞춰 놨다 — **이 생성기를 쓸 때는 스크립트 기본값을 고치는 것이 곧
데이터를 고치는 것**이다. `.tres` 만 고치면 다음 재생성에 사라진다.

| 데이터 | 생성기 |
|---|---|
| `data/item_catalog.tres` (무기 30 = 기본 16 + 진화 11 + 궁극기 3 · 패시브 10) | `tools/gen_item_catalog.gd` |
| `data/themes.tres` | `tools/gen_theme_data.gd` |
| `data/character_db.tres` | `tools/gen_character_data.gd` |
| `data/zombies.tres` + `data/zombies/*` | `tools/gen_zombie_data.gd` |
| `data/meta_upgrades.tres` + `data/meta/*` | `tools/gen_meta_data.gd` |
| `data/achievements.tres` | `tools/gen_achievement_data.gd` |
| `data/difficulty.tres` | `tools/gen_difficulty_data.gd` |
| `data/threat_ranks.tres` (위협 등급 20) | `tools/gen_threat_data.gd` |

```sh
godot --headless --path . --script res://tools/gen_theme_data.gd
```

예외: `data/balance.tres`(BalanceData)는 **손으로 조정하는 밸런스 테이블**이다(생성기 없음).
전투 수치를 코드에 새로 하드코딩하지 말고 여기에 필드를 추가한다.

### 화면에 나오는 문자열은 전부 `Locale` 키로
지원 언어 **en/ko/ja 3종**(`Locale.SUPPORTED`). 폰트는 "실제로 쓰는 글자만" 남긴 서브셋이라,
키 없이 하드코딩하면 **없는 글자가 두부(□)로 뜬다.** 특히 일본어 신규 한자를 조심한다.
⚠️ 서브셋 이전 원본은 git 히스토리에만 있고(`subset_fonts.py` 문서 참고), **이 저장소는 얕은
클론으로 시작하므로 `git fetch --unshallow` 를 먼저 해야 그 커밋이 보인다.** 그 원본조차 1.2MB
부분 서브셋이라 없는 글자가 있다(`김`·`化` 등) — 없으면 그 글자를 피해 문구를 바꾸는 편이 빠르다.

⚠️ **`tools/font_known_absent.txt` 에 있는 글자는 쓰면 안 된다.** 원본에도 없어 되살릴 방법이
없는 글자 목록이다 — 쓰면 화면에 두부(□)가 뜬다. `check_font_coverage.gd` 가 이걸 실패로
잡는다(P1-17 에서 그렇게 바꿨다. 그 전에는 건너뛰어서, CI 는 초록인데 화면은 깨져 있었다).

⚠️ **두부는 로컬 실렌더로 못 잡는다.** 개발 컨테이너에는 시스템 CJK 폰트(wqy-zenhei)가 있어
Godot 이 `allow_system_fallback` 으로 대신 그려 준다 — 스크린샷에는 멀쩡히 나온다.
**웹 빌드에는 시스템 폰트가 없어 그 자리가 그대로 □ 가 된다**(P1-17 에서 브라우저로 확인).
그래서 폰트 문제만큼은 스크린샷이 아니라 **커버리지 검사가 유일한 안전망**이다.

문자열 추가 후 반드시:
```sh
godot --headless --path . --script res://tools/check_font_coverage.gd   # CI 게이트와 동일
python3 tools/subset_fonts.py                                           # 글자가 늘었으면 재서브셋
```

### `assets/ui/frames`·`assets/ui/hud` 에 텍스처를 추가하면 `.import` 압축을 확인한다
이 둘은 **나인패치로 늘려 쓰는 텍스처**라 무손실(`compress/mode=0`)이 규약이다 — 늘어나는
테두리에서 손실 아티팩트가 띠로 보인다. `.gitignore` 가 `*.import` 를 무시하면서 이 두 폴더만
예외로 추적하는 이유가 그것이다. **Godot 은 새 PNG 를 전역 기본값(손실)으로 임포트하므로**
추가 후 `.import` 의 `compress/mode` 를 직접 고쳐야 한다(P2-2 에서 실제로 놓쳤다).

### 새 스프라이트는 아틀라스에 넣는다
좀비·보스·투사체·FX·그림자는 아틀라스 한 장으로 묶여 있고, 코드는 `res://assets/atlas/*.tres`
(AtlasTexture)를 참조한다. **PNG 를 직접 참조하면 그 스프라이트만 배칭이 끊긴다 —
눈에는 안 보이고 프레임만 떨어진다.**
```sh
python3 tools/build_atlas.py                                  # 아틀라스 재생성
godot --headless --path . --script res://tools/check_atlas.gd # CI 게이트와 동일
```
프롭은 **테마별로 분리된 아틀라스**다(`assets/atlas/props/<테마>/`) — 한 판에 한 테마만 뜨므로
합치면 안 쓰는 두 테마가 VRAM 에 상주한다. 절차 상세는 `ASSET_PIPELINE.md`.

### 유닛 스프라이트 규약
배경 투명 · 타이트 크롭 · **높이 120px** · 사이드뷰 오른쪽 향함.
```sh
python3 tools/make_icon.py -o assets/sprites/boss_x.png --height 120 --black-halo raw/x.png
```
`--black-halo` 는 월드에 놓이는 유닛 공통(흰 프린지를 검정 외곽선으로). 세로가 아닌 `--max`
(긴 변)를 쓰면 가로로 긴 네발 보스만 혼자 작아진다.

### 사운드는 `tools/import_sfx.py` 를 거친다
라우드니스(RMS -16dBFS)·선행 무음 제거·페이드가 일괄 적용된다. 개별 세기는 파일이 아니라
`SoundManager._VOLUMES` 에서 조정한다.

---

## 3. 커밋 전 검증 (CI 와 동일 — 여기서 통과시키면 CI 도 통과한다)

```sh
python3 tools/check_gdscript.py                                            # 엔진 없이 문법 점검(빠름)
python3 tools/verify_triage.py                                             # 프리즈 판정 회귀(고정 입력)
godot --headless --path . --import                                         # 임포트/파싱
godot --headless --path . --script res://tools/check_font_coverage.gd
godot --headless --path . --script res://tools/check_atlas.gd

# 회귀 테스트 — 전부 종료 코드로 성패를 알린다(0=통과)
godot --headless --path . res://scenes/ContactSeparationTest.tscn
godot --headless --path . res://scenes/ContinueSaveTest.tscn
godot --headless --path . res://scenes/FxLeakTest.tscn
godot --headless --path . res://scenes/PauseWatchdogTest.tscn
godot --headless --path . res://scenes/TelemetryTest.tscn
godot --headless --path . res://scenes/CodexTest.tscn
godot --headless --path . res://scenes/ThreatTest.tscn
godot --headless --path . --fixed-fps 60 --script res://tools/verify_boss_arena.gd
godot --headless --path . --fixed-fps 60 --script res://tools/verify_boss_heal.gd
godot --headless --path . --fixed-fps 60 --script res://tools/verify_environment.gd
godot --headless --path . --script res://tools/verify_character_sheets.gd
godot --headless --path . --script res://tools/verify_cheat_gate.gd
godot --headless --path . --script res://tools/verify_quest_tracks.gd
godot --headless --path . --script res://tools/verify_event_forecast.gd
godot --headless --path . --script res://tools/verify_ui_icons.gd
godot --headless --path . --script res://tools/verify_late_speed.gd
godot --headless --path . --script res://tools/verify_hotpath.gd
godot --headless --path . --fixed-fps 60 --script res://tools/verify_bullet_budget.gd
godot --headless --path . --script res://tools/verify_late_hp.gd
godot --headless --path . --script res://tools/verify_pickups.gd
```

⚠️ **`main` 을 새로 받은 직후에는 `--import` 를 먼저(가능하면 두 번) 돌린다.**
다른 세션이 추가한 PNG·폰트가 로컬 `.godot` 캐시에 없으면 그 리소스를 preload 하는 스크립트가
컴파일에 실패하고, **회귀 테스트가 코드와 무관하게 무더기로 거짓 실패한다.**
실제로 이 함정에 두 번 걸려 멀쩡한 커밋을 범인으로 지목할 뻔했다 — 테스트가 갑자기 여러 개
깨지면 코드보다 캐시를 먼저 의심할 것.
```sh
godot --headless --path . --import && godot --headless --path . --import
```

UI 를 건드렸으면 추가로 `python3 tools/check_text_fit.py` (en/ko/ja 폭 초과 검사).
⚠️ **이 검사와 `build_atlas.py` 는 Pillow 가 필요하다** — 없으면 그냥 죽는다.
`pip install pillow` 를 먼저 하고, **없다고 건너뛰지 말 것.** 이 검사는 CI 에 없어서
(워크플로의 Python 잡은 `verify_triage.py` 만 돈다) 여기서 안 돌리면 아무도 안 돌린다.

프레임을 건드렸으면 **최대 부하로도** 재 본다 — 평상시 판은 오토플레이가 좀비를 계속 녹여서
최악이 재현되지 않는다(후반 동시 좀비가 상한 320 의 1/10 이다). 프레임 드랍은 최악에서 난다.
```sh
godot --headless --path . --script res://tools/bench_lategame.gd -- min=26 stress=1   # CPU
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 720x1280x24" \
  godot --path . --rendering-driver opengl3 \
  --script res://tools/bench_lategame.gd -- min=26 stress=1                            # 드로우 콜·VRAM
```
⚠️ **HUD 의 `z_index` 를 되돌리지 말 것.** 로드아웃 슬롯은 프레임·아이콘·뱃지에 z 0/1/2 를
줘 종류별로 묶여 있다(`_Z_SLOT_*`). 되돌리면 **화면은 멀쩡한 채 드로우 콜만 11개 늘어난다**.
로드아웃보다 뒤에 만들어지는 것들의 `_Z_OVERLAY` 도 짝이라 같이 유지해야 한다 — 지우면
아이콘이 일시정지 딤 위로 새어 나온다(§5-O). z 를 건드렸으면
`shot_hud_layers.gd` 로 겹침 순서를 픽셀로 확인한다.

⚠️ **드로우 콜은 `only=` 로 못 가른다** — 그것은 로직을 끄는 장치고 드로우 콜은 캔버스
아이템에서 나온다(로직을 꺼도 그려진다). 그리기만 끄는 `hide=Zombie,HUD` 를 쓴다.
실측 결과 최대 부하 177콜 중 **HUD 가 49% · FX 가 28% 고, 좀비 317마리는 0콜**이다(§5-N).

⚠️ **계통별 몫은 `only=` 격리값이 아니라 "통째로 들어낸 빌드와의 차이"다.** `only=` 는 상호작용이
빠져 과소·과대 둘 다 난다 — 실제로 `only=` 로 "여기가 제일 크다"고 지목한 계통이 절제해 보니
전체의 11% 였다(P1-22). 고치기 전에 절제부터 할 것. 자세한 것은 `OPTIMIZATION_PLAN.md` §5-M.

⚠️ **`physics_ms` 를 프레임 비용으로 읽지 말 것** — 엔진 모니터는 최근 1초의 **최댓값**이다.
평상시 비용은 하네스가 센티넬로 직접 재는 `물리 틱` 줄을 본다. 자세한 것은
`OPTIMIZATION_PLAN.md` §5-L.

**웹(WASM) 비용도 여기서 잰다** — 실기기로 넘기지 말 것. Chromium 이 깔려 있고 웹 빌드도
여기서 만든다. `tools/bench_web.sh` 가 export → 로컬 서버 → Chromium → 콘솔 수집을 한 번에 한다.
```sh
GODOT=/path/to/godot tools/bench_web.sh "min=26 measure=12 fill=0 probe=bullet:400"
```
믿을 것은 **`물리 틱`·드로우 콜**뿐이다. `_process`·fps·VRAM 은 이 환경에 GPU 가 없어
SwiftShader(소프트웨어 GL)로 도는 값이라 실기기와 무관하다.
⚠️ **"웹은 데스크톱의 3~4배"는 틀린 상수다** — 실측하면 렌더 경합이 없을 때 **0.99배**다(§5-L).
남은 미지수는 폰 CPU 의 절대 속도와 모바일 GPU fill-rate 뿐이고, 그것만 실기기가 필요하다.

**기능을 고쳤으면 해당 회귀 테스트도 같이 늘린다.** 위 20종이 이 프로젝트의 안전망 전부다.

비주얼을 건드렸으면 **실렌더 스크린샷**으로 확인한다 — 헤드리스는 `_draw` 를 부르고 오류도 안 내지만,
그려진 것이 다른 레이어에 덮였는지·좌표가 화면 밖인지는 알려주지 않는다.
`xvfb-run -a godot --path . --fixed-fps 60 --script res://tools/shot_timeline.gd` (또는 `shot_boss_arena.gd`).

---

## 4. 아키텍처에서 반드시 알아야 할 것

### 오브젝트 풀 (`Pool` autoload)
`queue_free()` 대신 `Pool.release(n)`, 생성은 `Pool.acquire(SCENE, parent)`.
풀 대상 스크립트 규약:
- `on_spawn()` — 재사용 시 상태 초기화(체력/타이머/플래그). **필수.**
- `on_despawn()` — 반납 직전 정리(그룹 해제 등). 선택.
- `_ready()` — 시그널 연결 같은 **1회성** 셋업만. 재사용 시 다시 불리지 않는다.

### 일시정지는 `Events` 가 소유권으로 관리한다
모달이 각자 `get_tree().paused` 를 만지면, 하나가 해제를 빠뜨렸을 때 **화면엔 아무것도 없는데
게임만 멈춘 상태로 영구히 갇힌다**(실제 발생한 웹 프리즈). 반드시:
```gdscript
Events.pause_push(self, "level_up")   # 모달 열 때
Events.pause_pop(self)                # 닫을 때
```
워치독이 유령 소유자와 남은 히트스톱 배속을 자동 복구한다(`PauseWatchdogTest.tscn` 이 이걸 지킨다).

### 좀비 질의는 공유 버퍼다 — 보관하지 말 것
`Events.zombies_near(pos)` / `zombies_in_radius(pos, r)` 의 반환값은 **재사용 버퍼**다.
즉시 순회용이며, 같은 함수를 순회 도중 다시 호출하면 내용이 덮인다.
풀 반납된 좀비는 인스턴스가 유효한 채 그룹만 빠지므로 호출부에서
`is_instance_valid(z) and z.is_in_group("zombies")` 확인이 계속 필요하다.

### 이펙트는 `Events.fx_layer()` 아래에 붙인다
`Main` 은 y_sort 라 이펙트가 유닛 사이에 끼면 배칭이 계속 끊긴다. FX 전용 레이어(y_sort 꺼짐)로 뺀다.

### 보스 노드의 루트를 트윈하지 않는다
루트 `CharacterBody2D` 의 scale/position 을 트윈하면 `move_and_slide` 가 깨져 보스가 얼어붙는다.
**Body 스프라이트만** 애니메이트한다.

### 물리 레이어
`1=player · 2=zombies · 3=bullets · 4=gold`

### 오토로드 20개
`Events`(이벤트 버스+런 상태+일시정지) `Pool` `GameData`(.tres 로더) `SoundManager` `SaveManager`
`MetaManager` `RewardInbox` `CharacterManager` `AchievementManager` `QuestManager` `ThemeManager`
`RankingManager` `AdManager` `Locale` `UITheme` `Cheats` `SceneFade` `Telemetry`(로컬 플레이 기록)
`CodexManager`(도감 발견 기록) `ThreatManager`(위협 등급)

---

## 5. 알려진 함정

- **웹 pck 상한 15MB** (CI 게이트). 현재 약 12MB. 에셋을 늘릴 땐 압축 설정을 같이 본다.
- **렌더러는 `gl_compatibility` 고정.** 다른 렌더러 전용 기능(2D 라이트/SDF 등)을 쓰면 웹에서 깨진다.
- **export 제외 필터는 하위 폴더까지 삼킨다** — 실제로 바닥 타일이 웹 빌드에서 통째로 사라진 적이 있다(`1137951`).
- ⛔ **지금 배포 빌드는 치트가 열려 있다 — 되돌리지 말 것**(P0-12, 2026-08-20 사용자 요청).
  최적화 측정 기간 한정이며, **사용자의 명시적인 지시가 있을 때만 닫는다.** 상세와 되돌리는
  방법은 `HANDOFF.md` P0-12. 스위치는 두 곳뿐이다 —
  `export_presets.cfg` 의 `custom_features="cheats"` 와 `verify_cheat_gate.gd` 의
  `CHEAT_ALLOWED_PRESETS`. 이 기간에는 **배포 빌드의 랭킹·도전과제·메타 골드가 오염된다**
  (텔레메트리는 `cheated` 로 표시되니 분석에서는 걸러진다).
- **치트는 `Cheats.enabled` 하나로 잠긴다**(P0-1 해결). 에디터·디버그 빌드는 열려 있고, 릴리스
  export 는 프리셋 `custom_features` 에 `cheats` 가 있을 때만 열린다.
  치트를 새로 추가하면 **UI(`HUD._build_pause_menu` 의 `if Cheats.enabled` 블록) 안에 넣고,
  상태는 `Cheats.autoplay_active()` 같은 게이트 포함 접근자로 읽는다.** 상태 변수를 직접 읽거나
  시그널을 직접 `emit` 하면 잠금을 우회하게 된다 — `verify_cheat_gate.gd` 가 이걸 검사한다.
  ⚠️ 산출물에서 `AUTO-PLAY` 같은 문자열을 grep 하는 방식으로는 확인할 수 없다. Godot 이 `.gd` 를
  `.gdc` 로 토큰화해 내보내 스크립트 리터럴이 pck 에서 평문으로 잡히지 않는다(수정 전 빌드에서도 0건).
- **이 게임에 "웨이브"는 없다.** 시간 기반 디렉터로 갈아탄 뒤 남아 있던 웨이브 시대 API
  (`wave_pressure_mult`·`current_wave`·`wave_progress_changed` 등)는 전부 삭제했다(P2-6).
  난이도 곡선은 `ZombieSpawner._hp_mult()` 의 2차 곡선과 `data/difficulty.tres` 두 곳뿐이다.
  런 안의 구간을 나누는 개념은 **보스 처치 마일스톤**(`Events.milestone_reached`, 600초 주기)이고,
  HUD 상단 우측 카운터는 웨이브가 아니라 누적 처치 수다(`Events.kills_changed`).
  `verify_quest_tracks.gd` 가 이 잔재들이 돌아오지 않는지 검사한다.

---

## 6. 커밋 / PR

- 커밋 제목은 `타입(범위): 요약` (예: `feat(env):`, `fix(build):`, `perf(atlas):`, `docs:`).
  한국어·영어 모두 쓰이지만 **한 커밋 안에서는 하나로** 통일한다.
- 본문에 **왜** 고쳤는지를 남긴다. 이 레포의 주석·커밋 문화가 그렇고, 다음 세션이 읽는 유일한 맥락이다.
- PR 은 squash merge. `main` 직접 푸시 금지(문서 점유 표 갱신은 예외).
- 모델명·세션 식별자를 커밋 메시지·코드 주석·PR 본문에 넣지 않는다.
