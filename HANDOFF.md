# 작업 인계 — 기획 리뷰 (2026-08-18)

> **이 문서는 다른 에이전트에게 전달하는 작업 지시서다.**
> 시니어 기획자 관점에서 구현물을 코드/데이터 기준으로 대조한 결과, **추가·보완이 필요한 항목**만 모았다.
> 이미 잘 된 것은 적지 않았다.
>
> ### 사용 규칙 (작업 에이전트용)
> 1. 한 번에 **한 항목(P#-n)**만 처리한다. 여러 항목을 묶어 커밋하지 않는다.
> 2. 각 항목의 **[결정 필요]** 표시는 임의로 고르지 말고 사용자 확인을 받는다. 나머지는 바로 착수해도 된다.
> 3. 착수 전 항목의 **근거(파일:줄)** 를 직접 열어 현재도 유효한지 재확인한다 — 이 문서는 스냅샷이다.
> 4. 완료하면 이 문서의 해당 항목에 `✅ 완료 (커밋 sha)` 를 달고, 관련 계획 문서(P3)도 같이 갱신한다.
> 5. 검증은 각 항목의 **검증** 절을 그대로 실행한다. 헤드리스 실행 기준:
>    `godot --headless --path . --import` / `godot --headless --path . <씬 또는 스크립트>`

---

## 0. 한 줄 진단

시스템은 **거의 다 만들어져 있다**(무기 28·패시브 10·진화 12·보스 5아키타입·테마 3·메타/과제/퀘스트/랭킹).
지금 문제는 "모자란 것"이 아니라 **만든 것이 플레이어에게 닿지 않는 것**이다.
아래 P1 네 항목이 그 문제이고, P0 는 그 앞에 놓인 무결성 결함이다.

| 등급 | 성격 | 항목 수 |
|---|---|---|
| **P0** | 출시 차단 · 데이터 무결성 | 3 |
| **P1** | 설계 결함 — 제작된 콘텐츠가 플레이에 노출되지 않음 | 5 |
| **P2** | 완성도 · 구조 부채 | 6 |
| **P3** | 문서 정합성 (다음 에이전트가 틀린 스펙을 읽는 것을 막기 위함) | 6 |

---

# P0 — 출시 차단 / 무결성

## P0-1. 치트 메뉴가 프로덕션 빌드에 그대로 노출된다 🔴

**근거** — `scripts/HUD.gd:1259~1285`. 일시정지 메뉴에 `CHEATS` 버튼이 **무조건** 생성된다.
빌드 종류(`OS.is_debug_build()`)나 export feature 태그로 걸러지지 않는다.

노출되는 기능: `AUTO-PLAY`(AI 대리 플레이) · `TIME +5 MIN` · `SPAWN TO CAP` · `SPAWN BOSS` ·
`GOLD +500` · `LEVEL UP +1` · `PERF HUD` · `DAY/NIGHT` · `WEATHER`.

**영향** — 점수/랭킹(`RankingManager`), 도전과제(`AchievementManager`: 레벨 20/40·생존 시간),
퀘스트 티어(`QuestManager`), 메타 골드 경제가 전부 오염된다. 특히 `AUTO-PLAY` 는 방치 파밍을
허용해 리더보드를 무의미하게 만든다. **온라인 랭킹(LAUNCH_CHECKLIST C)을 붙이는 순간 치명적이다.**

**작업**
- `HUD._build_pause_menu` 의 치트 블록 전체를 게이트로 감싼다.
  판정은 `OS.is_debug_build() or OS.has_feature("cheats")` 를 권장 — 에디터/개발 빌드에선 그대로 쓰고,
  웹 릴리스 프리셋에선 `cheats` feature 를 빼서 사라지게 한다.
- `export_presets.cfg` 의 릴리스 프리셋에 custom feature 를 넣지 않는 것으로 기본 차단.
- `Cheats` 오토로드 자체는 남겨도 되지만, `autoplay`/`time_skip`/`spawn_boss` 는
  게이트가 꺼져 있으면 신호를 무시하도록 방어선을 하나 더 둔다(UI 우회 대비).

**수용 기준** — 릴리스 export 로 만든 웹 빌드의 일시정지 메뉴에 `CHEATS` 가 없고,
에디터 실행(F5)에서는 기존과 동일하게 보인다.

**검증** — `godot --headless --path . --export-release "Web" build/index.html` 후
산출물에서 문자열 `AUTO-PLAY` 가 나오지 않는지 확인. 에디터 실행으로 치트 정상 동작 회귀 확인.

---

## P0-2. `wave_complete` 시그널을 아무도 emit 하지 않는다 — 퀘스트 1/3이 영구히 잠겨 있다 🔴

**근거**
- 선언: `scripts/Events.gd:59` `signal wave_complete(wave: int)`
- **emit 하는 곳: 없음.** (`grep -rn "wave_complete.emit" scripts/` → 0건)
- 구독하는 곳: `QuestManager.gd:32,33` · `AchievementManager.gd:19` · `Player.gd:116` ·
  `HUD.gd:151,909` · `ShopPanel.gd:53`

이 게임은 웨이브제(처치 수 기반)에서 **시간 기반 디렉터**로 갈아탔는데(MASTER_PLAN Phase 1),
웨이브 시그널만 남고 발신자가 사라졌다.

**영향 — 4개가 동시에 죽어 있다**
1. **퀘스트 "Wave Rider" 트랙이 영구 `0 / 8`.** 메인 메뉴 퀘스트 패널에 3개 중 1개가
   *절대 진행되지 않는 항목*으로 상시 표시된다. 유저 눈엔 버그로 보인다. (`QuestManager.gd:17`)
2. **퀘스트·도전과제의 주기 저장(`_flush`)이 동작하지 않는다.** 저장 시점이 `player_died` 하나뿐이라,
   웹에서 탭을 닫거나 새로고침하면 그 판의 퀘스트/과제 진행이 통째로 날아간다. (모바일 웹에서 흔한 종료 경로)
3. `Player._autosave` 의 웨이브 훅이 죽어 체크포인트 저장 빈도가 설계보다 낮다. (`Player.gd:116`)
4. `HUD._on_wave_complete`(72줄) + `sfx_wave_clear.ogg` + 로케일 `wave_clear_fmt` 가 전부 도달 불가.

**작업 [결정 필요 — 아래 A/B 중 택1]**
- **A (권장) 웨이브 개념을 버리고 시간 기반으로 재정의**
  - `QuestManager.TRACKS` 의 `waves` 트랙을 **`survive`(누적 생존 분)** 또는 **`clears`(30분 클리어 횟수)** 로 교체.
    지표는 이미 있는 `Events.elapsed_changed` / `run_cleared` 로 잡는다.
  - `_flush()` 주기 저장을 `Events.run_progress`(또는 60초 타이머)에 물린다 — **웹 이탈 저장 유실이 이 항목의 핵심.**
  - `Events.wave_complete` 시그널과 `HUD._on_wave_complete`·`wave_clear_fmt`·`sfx_wave_clear` 를 제거.
    (사운드 파일은 보스 처치 스팅어로 재활용 가능)
- **B 보스 처치를 "웨이브 완료"로 재정의** — `ZombieSpawner._on_boss_died` 에서 `wave_complete.emit(_boss_count)`.
  기존 코드는 살아나지만 "Wave" 라는 이름이 게임 어디에도 없는 개념이라 UI 문구를 전부 손봐야 한다.

**수용 기준** — 메뉴 퀘스트 패널의 3개 트랙이 전부 실제로 진행되고, 런 도중 강제 종료 후
재진입해도 퀘스트/과제 진행이 남아 있다.

**검증** — `godot --headless --path . res://scenes/ContinueSaveTest.tscn` 회귀 통과 +
런 중 `QuestManager.active_quests()` 프로브로 3트랙 current 증가 확인.

---

## P0-3. `ShopPanel` 400줄이 완전한 사문(死文)이다

**근거** — `scenes/ShopPanel.tscn` 을 **인스턴스화하는 코드가 0건**
(`grep -rn "ShopPanel.tscn" --include=*.gd .` → 없음). 따라서 유일한 `shop_closed` 발신자
(`ShopPanel.gd:387`)도 실행되지 않고, 이를 구독하는 `Player.gd:112`(`apply_upgrades`)·
`Player.gd:114`(`_autosave`)도 죽어 있다.

**영향** — 실해는 없지만, 다음 작업자가 "상점이 있다"고 오인해 밸런스를 상점 기준으로 잡는다.
실제로 `BALANCE.md` 는 **이미 있지도 않은 상점 비용 곡선을 밸런스의 중심 손잡이로 서술하고 있다**(P3-1 참조).

**작업 [결정 필요]** — 인게임 상점을 (a) 폐기 확정 → `ShopPanel.gd`/`.tscn`/`Events.shop_closed`/
`Player` 구독 삭제, (b) 되살릴 계획 → `HANDOFF` 에 복구 스펙을 적고 `TODO` 주석 명시.
현재 성장 루프(레벨업 카드 + 보물상자 + 메타 강화)가 이미 3중이라 **(a) 폐기를 권장**한다.

**수용 기준** — 선택한 방향이 코드와 문서 양쪽에 반영되어, `shop` 검색 결과가 일관된다.

---

# P1 — 설계 결함: 만든 콘텐츠가 플레이어에게 닿지 않는다

## P1-1. 보스 아키타입 5종 중 **2종은 게임에서 절대 등장하지 않는다** ⭐ 최우선

**근거** — `scripts/ZombieSpawner.gd:343~347` `_theme_boss()` → `_spawn_boss():358~360`.
선택 테마에 `boss_key` 가 있으면 **그 판의 모든 보스**를 테마 보스로 덮어쓴다.
그리고 `data/themes.tres` 의 세 테마가 **전부** `boss_key` 를 갖고 있다
(suburb=`mutant_dog`/berserk, city=`wrecker`/bomber, lab=`mutation`/summoner).

결과:
- `BOSS_SEQUENCE`(brute→gunner→summoner→bomber→berserk)와 `BOSS_TYPES` 는 **도달 불가 코드**다.
- **`melee`(BRUTE)·`gunner`(GUNNER) 아키타입은 어떤 경로로도 플레이어가 만날 수 없다.**
  GUNNER 는 BOSS_PLAN §8 에서 *사용자가 최우선 구현을 요청한 보스*다.
- 한 판(30분)에서 보스는 **같은 보스 2~3회 반복**이다. 아키타입별 텔레그래프·패턴·페이즈에 들인
  작업량 대비 플레이어가 체감하는 다양성은 1/5 수준.

**작업 [결정 필요 — 배분 규칙]** 제안:
- 테마 보스는 **그 아레나의 "간판" 보스**로 두되 독점하지 않는다.
  예: `_boss_count` 1회차 = 테마 보스(첫인상), 2회차 = 아키타입 순환, 3회차 = 테마 보스(피날레), 이후 순환.
- 또는 `ThemeData` 에 `boss_pool: PackedStringArray` 를 추가해 테마별 보스 2~3종을 데이터로 정의
  (교외=hound/brute, 도심=wrecker/gunner, 연구소=mutation/berserk). **데이터 주도라 이 쪽이 확장에 낫다.**
- 어느 쪽이든 `BOSS_TYPES`/`BOSS_SEQUENCE` 하드코딩은 이 기회에 `BossData`(.tres) 로 이관한다
  (MASTER_PLAN Phase 0 이 "남은 이관 대상"으로 남겨둔 마지막 항목).

**수용 기준** — 한 아레나 30분 런에서 서로 다른 보스가 **최소 2종** 등장하고,
5개 아키타입 전부가 어떤 경로로든 도달 가능하다.

**검증** — 치트 `SPAWN BOSS` 를 5회 눌러 아키타입이 순환하는지 확인 +
`godot --headless --path . --script res://tools/verify_boss_arena.gd` 회귀.

---

## P1-2. 프롭(미장센) 시스템이 **모든 테마에서 꺼져 있다** — 아트 15장이 화면에 안 나온다

**근거**
- `scripts/PropField.gd:71` — `for k in t.prop_keys:` 로 표시할 프롭을 정한다.
- `data/themes.tres:20,38,56` — **세 테마 전부 `prop_keys = PackedStringArray()`(빈 배열).**
- 생성기 `tools/gen_theme_data.gd:36~45` 가 `prop_keys` 를 아예 채우지 않는다.
- 그런데 아트는 다 있다: `assets/sprites/props/{suburb,city,lab}` **15종** + 테마별 아틀라스
  (`assets/atlas/props/*` — 커밋 `bc6650a` 에서 테마별로 분리까지 해둔 상태).
- `PropField` 는 `scenes/Main.tscn:31` 에 배선되어 있고, `_props` 가 비면 `_process` 가 즉시 반환한다.

**영향** — 필드가 **완전한 빈 바닥**이다. 장애물(`solid=true` 인 fence/hydrant/barrier 등)이
없으니 지형을 이용한 카이팅·차폐 같은 공간 플레이도 성립하지 않는다.
아트·아틀라스·충돌 로직을 다 만들어 놓고 **데이터 한 줄이 없어 전부 잠겨 있는 상태**다.
가장 적은 비용으로 화면 완성도가 가장 크게 오르는 항목이다.

**작업**
- `tools/gen_theme_data.gd` 의 세 테마에 `prop_keys` 를 채우고 `.tres` 재생성:
  - suburb: `fence, mailbox, bush, forsale, hydrant`
  - city: `wreck_car, barrier, dumpster, barrel, rubble, tank`
  - lab: `console, drum, pod, server`
- `PropField.DENSITY`(현 30) 와 `solid` 프롭 비율은 **실플레이 후 조정** — 장애물이 많으면
  물량 게임의 도주로가 막혀 난이도가 급등한다. 초기값은 solid 를 셀당 1/3 이하로 잡기를 권한다.
- 보스 격리 구역(`BossArena`, 반경 400~480) 안에 solid 프롭이 겹쳐 플레이어가 끼는 경우가 없는지 확인.

**수용 기준** — 세 아레나 각각에서 필드에 프롭이 보이고, solid 프롭에 플레이어가 막히며,
좀비 200마리 상황에서 프레임 회귀가 없다.

**검증** — `PERF HUD` 치트로 드로우콜·프레임타임 비교(적용 전/후), `--import` 무오류.

---

## P1-3. 입문 아레나(Suburb)가 비어 있다 — 신규 유저가 보는 첫 화면이 가장 밋밋하다

**근거** — `data/themes.tres:18,19` suburb 는 `gimmick_key=""` · `gimmick_keys=()`.
city 는 기믹 4종, lab 은 3종. 즉 **무료·기본 선택 아레나에만 필드 이벤트가 하나도 없다.**
`tools/gen_theme_data.gd:25` 주석상 "#180 이후 입문 아레나는 방해물 미배치"로 **의도된 결정**이지만,
그 결과 `scripts/GasCan.gd`(교외용 가스통, Phase 6-B 산출물)는 **어떤 테마도 참조하지 않는 고아 콘텐츠**가 됐다
(`GimmickSpawner.gd:7` 에 preload 만 남아 있음).

**영향** — 첫인상 구간이 가장 심심하다. 유저가 "이 게임 필드에 뭔가 있다"는 걸 배우기 전에
아레나를 해금해야 하는 순서라, 도심(400골드)까지 못 간 유저는 기믹의 존재를 모른 채 이탈한다.

**작업 [결정 필요]** — 아래 중 택1:
- **(권장) 가스통만 되살린다.** 가스통은 *방해물이 아니라 플레이어가 쓰는 도구*(유인 후 폭발)라
  "입문 아레나에 방해물 없음" 원칙과 충돌하지 않는다. suburb `gimmick_keys = ["gas_can"]`.
- 원칙을 유지하고 `GasCan.gd` 와 preload 를 삭제한다(고아 콘텐츠 정리).

**수용 기준** — 결정이 데이터·코드·주석에 일관되게 반영된다(고아 스크립트가 남지 않는다).

---

## P1-4. "다음에 무엇이 오는가"를 알려주는 UI가 없다

**근거** — MASTER_PLAN Phase 1 이 **"남은 작업"으로 명시**한 항목이 그대로 남아 있다.
`ZombieSpawner` 는 `_next_boss_at`(600초 주기)·`_next_elite_at`(300초 주기)를 알고 있지만
(`ZombieSpawner.gd:89,90`), HUD 에 노출하지 않는다.
현재 예고는 **스웜 배너(등장 1초 전)** 하나뿐이다(`Events.swarm_incoming`).

**영향** — 30분 런에서 마일스톤은 엘리트 5회 + 보스 2~3회뿐인데, 그 리듬이 **플레이어에게 보이지 않는다.**
"버티는 것 말고 할 일이 없다"는 체감의 직접적 원인이고, 이건 이미 `GOALS.md` 가
*P0 저비용 핵심*으로 지목했던 문제다(문서만 있고 미구현).

**작업**
- HUD 상단 시간바에 **다음 이벤트 마커**를 얹는다: 엘리트=주황 눈금, 보스=붉은 해골 눈금, 30:00=골드 깃발.
  진행바가 이미 시간 기반이라(`HUD._on_run_progress`) 눈금 위치 계산은 상수 나눗셈이면 된다.
- 보스 60초 전 / 엘리트 20초 전 **카운트다운 배너** 1줄(기존 스웜 배너 컴포넌트 재사용).
- 문구는 반드시 `Locale`(en/ko/ja) 키로. CI 폰트 커버리지 검사가 있으므로 일본어 신규 한자 주의.

**수용 기준** — 플레이 중 아무 때나 화면만 보고 "다음 보스까지 몇 분"을 말할 수 있다.

**검증** — `TIME +5 MIN` 치트로 마커·카운트다운이 정확한 시각에 뜨는지 확인 +
`godot --headless --script res://tools/check_font_coverage.gd`.

---

## P1-5. 후반 적 이동속도가 플레이어를 추월한다 (밸런스 검증 필요)

**근거**
- `data/difficulty.tres` — `speed_per_min=0.03`, `speed_cap=2.0` → **33분에 2.0배 상한 도달**.
- `data/zombies/sprinter.tres` speed **150** → 후반 **300**, `screamer.tres` **145** → **290**.
- `scripts/Player.gd:4,525` — 기본 `move_speed=220`, `+30 × upgrade_speed`.

즉 이속 강화를 **3레벨 이상 찍지 않으면(310)** 20분 이후 스프린터/스크리머로부터 도망칠 수 없다.

**영향** — 빌드 다양성이 죽는다. "운동화(이속 패시브) 필수" 가 되어 레벨업 선택의 의미가 줄고,
이속을 안 찍은 판은 회피 불가 피격으로 끝나 **플레이어가 자기 실수로 죽었다고 느끼지 못한다**.

**작업 [실측 선행]**
1. 먼저 측정한다 — `AUTO-PLAY` + `TIME +5 MIN` 로 20/25/30분 구간에서 피격 원인을 관찰.
2. 조정 손잡이는 두 개다: `speed_cap`(2.0 → 1.6~1.7 권장 검토) 또는
   빠른 종(sprinter/screamer)에만 별도 상한을 두기.
3. 대안 설계: 속도 대신 **밀도**로 압박한다(`max_z_cap` 320 은 이미 높다) — 이쪽이 뱀서식 문법에 가깝다.

**수용 기준** — 이속 강화를 하나도 찍지 않은 빌드로도 25분 시점에 "도망칠 수는 있다"가 성립한다.

---

# P2 — 완성도 · 구조 부채

## P2-1. 공통 팝업 셸(`UIPopup`)이 미착수 — `MainMenu.gd` 1521줄에 팝업 조립이 8번 복붙돼 있다
**근거** — `POPUP_UI_PLAN.md` Phase 2 미구현. `scripts/UIPopup.gd` **없음**.
현재 `MainMenu.gd` 안에 `ColorRect.new()` 8 · `PanelContainer.new()` 8 · `MarginContainer.new()` 9 ·
`HSeparator.new()` 10 회. Phase 1(`UIListRow.gd`)·Phase 3(로케일)은 완료됐으므로 **Phase 2만 남았다.**
**작업** — 계획 문서 §3 Phase 2 그대로. 한 번에 8개를 옮기지 말고 **패널 하나씩** 이관한다.

## P2-2. 메뉴 버튼 플레이트가 1종뿐 — 위계 아트가 없다
**근거** — `MENU_UI_PLAN.md` Phase 2 는 `btn_plate_steel/blood/dark` 3종을 요구하는데
`assets/ui/frames/` 에는 `btn_plate_metal.png` 1종뿐이고 `UIStyle.gd:14` 가 그것만 preload 한다.
→ 1차 CTA(새 게임)를 색이 아닌 **재질**로 구분하는 계획이 반쪽이다.
**작업** — `tools/gen_menu_plates.py` 를 3종 산출로 확장 + `UIStyle.plate(kind)` 헬퍼 추가.
`apply_button_style` 시그니처는 유지(상점·레벨업 회귀 방지).

## P2-3. 로케일 누락 — 인게임 최다 노출 문구가 영어 하드코딩
| 위치 | 문자열 | 비고 |
|---|---|---|
| `LevelUpPanel.gd:159` | `"LEVEL %d  ·  CHOOSE AN UPGRADE"` | **레벨업마다 뜨는 모달** — 가장 자주 보인다 |
| `MainMenu.gd:575,1026,1214,1300` | `"Gold: %d"` | 4곳 중복 |
| `ChestRewardPanel.gd:453` | `"tap to continue"` | |
| `HUD.gd:377` | `"HP %d / %d"` | 숫자 포맷이라 우선순위 낮음 |
**작업** — `Locale.gd` 키 추가(en/ko/ja) 후 치환. 추가 후 반드시 폰트 커버리지 검사 실행.

## P2-4. 폰트 서브셋 회피용 아스키 대체가 UI 품질을 깎는다
`MainMenu.gd:590,1236` 잠금 표시 `"[-]"` · `UIListRow.gd:235` 체크 `"v"`.
**작업** — `assets/ui/icons`(47종 보유) 또는 `UIIcon` 절차 드로잉으로 자물쇠/체크 아이콘 승격.
신규 아트 없이 해결 가능.

## P2-5. CI가 회귀 테스트를 하나도 돌리지 않는다
**근거** — `.github/workflows/export-web.yml` 은 `check_font_coverage.gd`·`check_atlas.gd` 만 실행한다.
정작 만들어 둔 회귀 씬 4종이 방치돼 있다:
`scenes/{ContactSeparationTest,ContinueSaveTest,FxLeakTest,PauseWatchdogTest}.tscn` +
`tools/{verify_boss_arena,verify_boss_heal,verify_environment,verify_character_sheets}.gd`.
전부 헤드리스 실행 가능하다. 다만 판정 출력 형식이 두 갈래다 — 씬 4종은 `RESULT ok=n/m` 한 줄로
끝나고, `verify_*.gd` 는 `ok`/`FAIL` 줄을 흘릴 뿐 **종료 코드를 세팅하지 않는다.**
**작업** — export 스텝 앞에 실행 스텝을 추가한다. 씬 4종은 `RESULT` 라인 파싱으로,
`verify_*.gd` 는 `FAIL` 문자열 검출로 게이트를 걸거나(간단), 각 스크립트가 `quit(1)` 을
반환하도록 고친다(정석 — 이쪽을 권장).
**이 항목은 P0/P1 작업을 시작하기 전에 넣는 것이 좋다** — 그래야 이후 변경의 회귀를 CI 가 잡는다.

## P2-6. 웨이브 시대의 데드 API가 `Events` 에 남아 있다
`Events.wave_pressure_mult()` · `wave_speed_pressure()` · `diff_spawn_mult()` · `diff_total_mult()` ·
`difficulty_name()` — **호출처 0건**. `current_wave` 는 항상 1 인데 `SaveManager.gd:81,135` 가
저장·복원하고 있다.
**작업** — 삭제. 남겨야 한다면 `## DEPRECATED` 주석으로 이유를 명시한다.
(다음 작업자가 `wave_pressure_mult` 를 보고 "무한 스케일링이 있다"고 오인한다 — 실제 스케일링은
`ZombieSpawner._hp_mult()` 의 2차 곡선이다.)

---

# P3 — 문서 정합성 (**작업 착수 전 반드시 읽을 것**)

> 계획 문서 상당수가 **현재 구현과 어긋나 있다.** 이대로 두면 다음 에이전트가 없는 시스템을 전제로
> 작업한다. 각 항목은 "고쳐 쓰기"가 아니라 **현행 기준 재작성**이 필요하다.

| # | 문서 | 어긋난 내용 | 조치 |
|---|---|---|---|
| P3-1 | `BALANCE.md` | **문서 전체가 폐기된 시스템 기준.** Easy/Normal/Hard 난이도 3종(현재 단일 모드), 웨이브별 킬 목표(현재 시간 기반), **상점 비용 곡선을 "밸런스의 중심 손잡이"로 서술**(상점은 P0-3 사문). | 전면 재작성. 새 중심 손잡이는 `difficulty.tres`(hp_per_min·hp_accel_per_min2·speed_cap·max_z_cap)와 `balance.tres` |
| P3-2 | `GOALS.md` | "난이도별 목표 웨이브 8/10/12 · STAGE CLEAR · 클리어 배지" 전제. 실제는 **단일 모드 30분 생존 클리어 + 오버타임**. 단, **미구현으로 남은 P0 3건(목표 배너·보스 예고·목표 대비 피드백)은 여전히 유효** → P1-4 로 승계 | 현행 기준 재작성, 유효 항목은 P1-4 참조로 정리 |
| P3-3 | `BOSS_PLAN.md` §9 | "W5 브루트 · W10 거너 · W15 서머너…" 웨이브 표기. 실제는 **600초 주기 + 테마 보스가 전부 덮어씀**(P1-1) | 등장 규칙을 P1-1 결정 후 갱신. `[ ] P5 밸런스 패스`는 계속 열린 항목 |
| P3-4 | `POLISH_PLAN.md` | "좀비 11종 스프라이트 🔴 미착수" · "초상 썸네일 미착수" 로 적혀 있으나 **실제로는 존재**(`assets/sprites/zombie_*.png` 11종, `assets/ui/portraits` 3종, `assets/ui/thumbs` 3종, `chest_*.png`). 반대로 "프롭 배치 안 됨"은 **여전히 유효**(P1-2) | 완료 항목 체크 + 프롭 항목을 P1-2 로 승계 |
| P3-5 | `ROADMAP.md` | 4번이 "진행 중"이나 아틀라스·바닥 타일은 완료(커밋 `5bbea14`,`bc6650a`). 실제로 남은 건 `AnimatedSprite2D` 뿐이고, 그마저 `Zombie._animate_walk`(절차적 sin 보행)로 **대체 결정**된 상태 | 완료 반영 + 절차적 애니메이션을 대체안으로 명시 |
| P3-6 | `README.md` | 씬 구조·좀비 6종·튜닝 포인트가 **초기 프로토타입 기준**. 현재는 좀비 11종·무기 28·오토로드 17개 | 현행 구조로 갱신(신규 기여자의 첫 진입점이다) |

---

## 부록 — 착수 순서 권장

```
P2-5 (CI 회귀 게이트)          ← 먼저 깔아야 이후 변경이 안전하다
  └─ P0-1 (치트 게이팅)        ← 단독·저위험, 즉시 가능
       └─ P0-2 (wave_complete) ← 결정 필요, 저장 유실이 걸려 있어 급하다
            └─ P1-2 (프롭 활성화)  ← 데이터 한 줄, 체감 최대
                 └─ P1-4 (이벤트 예고 UI)
                      └─ P1-1 (보스 배분)   ← 설계 결정 필요, 볼륨 큼
                           └─ P1-5 (이속 밸런스)  ← 실측 데이터 필요
P3 문서 정리는 각 항목 완료 시점에 함께 처리한다(별도 PR 금지 — 코드와 같이 가야 안 밀린다).
P0-3 · P1-3 · P2-* 는 위 흐름과 독립이라 병렬 처리 가능.
```
