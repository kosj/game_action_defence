# 작업 인계 — 기획 리뷰 (2026-08-18)

> **이 문서는 다른 에이전트에게 전달하는 작업 지시서다.**
> 시니어 기획자 관점에서 구현물을 코드/데이터 기준으로 대조한 결과, **추가·보완이 필요한 항목**만 모았다.
> 이미 잘 된 것은 적지 않았다.
>
> ### 사용 규칙 (작업 에이전트용)
> 1. **§1 점유 표에서 항목을 먼저 잡는다**(`🔵 진행중` + 브랜치명을 `main` 에 푸시). 이게 1순위다 —
>    여러 세션이 병렬로 돌기 때문에, 이걸 빠뜨리면 같은 항목을 두 세션이 동시에 작업한다.
> 2. 한 번에 **한 항목(P#-n)** 만 처리한다. 항목 1개 = 브랜치 1개 = PR 1개.
> 3. 🟡 **결정대기 / [결정 필요]** 항목은 임의로 고르지 말고 사용자 확인을 받는다. 나머지는 바로 착수해도 된다.
> 4. 착수 전 항목의 **근거(파일:줄)** 를 직접 열어 현재도 유효한지 재확인한다 — 이 문서는 스냅샷이다.
> 5. 완료하면 같은 PR 안에서 점유 표를 `✅ (sha)` 로 바꾸고, 관련 계획 문서(P3)도 함께 갱신한다.
> 6. 검증은 각 항목의 **검증** 절 + `CLAUDE.md` §3 의 공통 검증 목록을 실행한다.
>
> 작업 환경 규약(데이터 생성기·로케일·아틀라스·풀링 등)은 **`CLAUDE.md`** 에 있다. 먼저 읽을 것.

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

# 1. 작업 큐 · 점유 표 ⚠️ **착수 전 여기부터 갱신할 것**

> 세션끼리는 대화할 수 없다. **이 표가 유일한 중복 착수 방지 장치다.**
> 코드를 건드리기 전에 해당 행을 `🔵 진행중` + 브랜치명으로 바꿔 **`main` 에 먼저 푸시**한다
> (이 표 갱신만은 main 직접 푸시를 허용한다). 완료 시 `✅ (sha)`.
> 상태: ⚪ 대기 · 🔵 진행중 · 🟡 결정대기(사용자 확인 필요) · ✅ 완료 · ⛔ 보류

| 항목 | 레인 | 상태 | 담당 브랜치 | 갱신일 |
|---|---|---|---|---|
| P2-5 CI 회귀 게이트 + PR 트리거 | A | ✅ (9bd1100) | claude/game-designer-task-review-wvhkiq | 2026-08-18 |
| P0-1 치트 게이팅 | A | ✅ (db7bb29) | claude/a-lane-cheat-gate | 2026-08-18 |
| P0-2 마일스톤 저장 + 퀘스트 트랙 교체 | C | ✅ (784e6c9) | claude/c-lane-milestone-save | 2026-08-18 |
| P0-3 ShopPanel 폐기 | C | ✅ (이 PR) | claude/c-lane-shop-removal | 2026-08-18 |
| P1-1 미배치 보스 리소스 삭제 | B | ✅ (defee2e) | claude/b-lane-boss-cleanup | 2026-08-18 |
| P1-2 프롭 활성화 | B | ✅ (b1ed9ab) | claude/b-lane-pending-item-dix8eg | 2026-08-18 |
| P1-3 가스통 고아 코드 삭제 | B | ✅ (2e76857) | claude/b-lane-gascan-cleanup | 2026-08-18 |
| P1-4 이벤트 예고 UI | E | ⚪ 대기 | — | — |
| P1-5 후반 이속 밸런스 | F | ⚪ 대기 | — | — |
| P1-6 밸런스 측정 하네스 + BALANCE 재작성 | F | ✅ (ee17767) | claude/f-lane-balance-harness | 2026-08-18 |
| P1-8 탐욕형 빌드 페르소나 | F | 🔵 진행중 | claude/f-lane-greedy-persona | 2026-08-18 |
| P1-7 첫 보스 난이도 계단 | F | ⚪ 대기 | — | — |
| P2-8 오토플레이 교전 이탈 수정 | F | ✅ (8b3dcb4) | claude/f-lane-autoplay-engage | 2026-08-18 |
| P2-1 공통 팝업 셸 | D | ⚪ 대기 | — | — |
| P2-2 메뉴 플레이트 3종 | D | ⚪ 대기 | — | — |
| P2-3 로케일 누락 | D | ⚪ 대기 | — | — |
| P2-4 잠금/체크 아이콘 | D | ⚪ 대기 | — | — |
| P2-6 데드 API 정리 | C | ⚪ 대기 | — | — |
| P2-7 MudField 고아 코드 삭제 | B | ✅ (5d1778c) | claude/b-lane-mudfield-cleanup | 2026-08-18 |
| P3-1~6 문서 정합성 | — | ⚪ 대기 | 각 항목 PR 에 동봉 | — |

**결정 대기 항목은 전부 해소됐다(2026-08-18).** 아래 §2 결정 로그 참고 — 이제 모든 항목이 바로 착수 가능하다.
새로 🟡 가 필요한 판단이 생기면 임의로 고르지 말고 이 표에 🟡 로 올린 뒤 사용자 확인을 받는다.

---

# 2. 결정 로그

> 무엇을 정했는지보다 **왜 그렇게 정했는지**가 다음 세션에 필요하다. 되돌리려는 사람이 읽을 곳이다.

| 날짜 | 항목 | 결정 | 근거 |
|---|---|---|---|
| 2026-08-18 | P0-2 | 보스 처치를 저장 마일스톤으로 삼고, 시그널을 `milestone_reached` 로 개명. `waves` 퀘스트 트랙은 **생존 시간**으로 교체 | 저장 유실이 급한 문제고, 보스 처치가 이 게임에 남은 유일한 자연스러운 마일스톤이다. 다만 트랙을 그대로 두면 `Boss Breaker` 와 같은 지표를 재게 되어 퀘스트 3종 중 2종이 중복된다 |
| 2026-08-18 | P0-3 | 인게임 상점 **폐기** | 성장 루프가 이미 3중(레벨업 카드·보물상자·메타 강화)이라 상점의 자리가 없다. 인스턴스화된 적도 없다 |
| 2026-08-18 | P1-1 | 보스 다양성을 늘리는 대신 **미배치 자산 삭제**(gunner·테이블·아트 4종). `melee` 폴백은 유지 | 아키타입을 늘리면 콘텐츠는 늘지만 유지 대상도 늘어난다. 테마 보스 3종으로 정체성을 굳히는 쪽을 택했다. `melee` 는 미지정 아키타입의 기본 동작이라 안전망으로 남긴다 |
| 2026-08-18 | P1-3 | 입문 아레나 **기믹 미배치 원칙 유지**, 가스통 코드 삭제 | `#180` 의 기존 결정을 존중한다. 어느 테마도 쓰지 않는 코드는 콘텐츠가 아니라 부채다 |
| 2026-08-18 | P2-7 | 진창(`MudField`)도 **삭제** — P1-3 과 같은 판단 | P1-3 은 "가스통"만 명시했지만, 결정의 실체는 "교외에 기믹을 두지 않는다"였다. 그 원칙 아래에서 교외 전용 기믹은 종류를 불문하고 갈 곳이 없다. 둘을 다르게 대우할 근거가 없어 같이 지웠고, 재발은 CI 의 고아 검사로 막는다 |

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
에디터 실행(F5)에서는 기존과 동일하게 보인다. ✅

**완료 (2026-08-18)** — 게이트는 `Cheats.enabled` 한 곳이다(`OS.is_debug_build() or
OS.has_feature("cheats")`, `_ready` 에서 1회 판정). 세 층에 같은 게이트를 건다:
1. **UI** — `HUD._build_pause_menu` 의 치트 블록 전체를 `if Cheats.enabled:` 로 감쌌다(노드를
   아예 만들지 않는다). `export_presets.cfg` 의 Web 프리셋은 `custom_features=""` 라 기본 차단.
2. **발신** — 버튼이 시그널을 직접 `emit` 하지 않고 `Cheats.request_time_skip/spawn_fill/spawn_boss`
   를 부른다. 잠긴 빌드에서는 아무 신호도 나가지 않는다.
3. **수신** — `ZombieSpawner` 의 세 핸들러가 `Cheats.enabled` 를 한 번 더 본다(우회 대비).
   상태는 `Cheats.autoplay_active()` 로만 읽는다 — `Player`·`LevelUpPanel`·`HUD` 를 전부 옮겼다.

`Cheats.enabled` 를 상수가 아니라 변수로 둔 이유는 회귀 테스트다 — 헤드리스는 항상 디버그
빌드라 "잠긴 릴리스 빌드"를 달리 재현할 방법이 없다.

**⚠️ 이 항목이 지정한 검증법은 아무것도 판별하지 못한다 (실측)**
산출물에서 `AUTO-PLAY` 문자열을 grep 하는 방법은 **수정 전 빌드에서도 0건**이다. 직접 확인했다 —
착수 시점 `main` 을 릴리스 export 해서 grep 했고 `AUTO-PLAY`·`SPAWN BOSS`·`CHEATS` 전부 0건이었다.
Godot 이 `.gd` 를 `.gdc` 로 토큰화해 내보내므로 스크립트 안의 문자열 리터럴은 pck 에서 평문으로
잡히지 않는다(같은 이유로 `MUTANT HOUND` 같은 다른 리터럴도 안 잡힌다. 반면 `.tres` 에서 온
`Suburb`·`zombie_walker` 는 잡힌다 — 리소스는 평문이다).
**그대로 CI 에 넣었다면 항상 통과하는 가짜 게이트가 됐다.**

**검증** — `tools/verify_cheat_gate.gd` 신설(CI 회귀 목록에 추가, `CLAUDE.md` §3 도 9종으로 갱신):
잠긴 빌드에서 `autoplay_active()`·`toggle_autoplay()`·`request_*` 3종이 전부 죽는지 · 열린 빌드에서는
그대로 도는지 · 소비처가 `Cheats.autoplay` 를 직접 읽지 않는지(소스 검사) ·
**어떤 export 프리셋도 `custom_features` 에 `cheats` 를 켜지 않는지**(실제 스위치. 프리셋에 한 단어만
넣으면 P0 가 통째로 되살아난다). 프리셋에 `cheats` 를 넣어 이 검사가 실패하는 것을 확인했다.
`CLAUDE.md` §3 전체 통과 + 릴리스 웹 export 성공(pck 12.06MB, 상한 15MB).

**A 레인 완료 → E 레인(P1-4) 시작 가능** — `HUD.gd` 의 잠금이 풀렸다.

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

**작업 ✅ 결정됨 (2026-08-18)** — *"보스 처치 시점에 저장한다. Wave Rider 트랙은 생존 시간으로 교체한다."*

1. **저장 시점을 되살린다** — `ZombieSpawner._on_boss_died` 에서 마일스톤 시그널을 emit 한다.
   이 게임에 "웨이브"라는 개념이 없으므로 **시그널 이름을 `milestone_reached(index: int)` 로 개명**하고
   `wave_complete` 는 제거한다(같은 C 레인의 P2-6 이 어차피 웨이브 잔재를 걷어낸다 — 함께 처리).
   구독자 5곳을 그대로 이 시그널로 옮긴다.
2. **`QuestManager` 의 `waves` 트랙을 `survive` 로 교체** — 지표는 "누적 생존 분"(`Events.elapsed_changed`
   로 적산). `Boss Breaker` 와 측정 대상이 겹치지 않게 하는 것이 이 교체의 목적이다.
   티어 곡선은 기존 형식 유지(`base_goal`/`goal_mul`/`base_reward`/`reward_mul`)로 새로 잡는다.
   트랙 id 가 바뀌므로 `user://quests.save` 의 구 `waves` 키는 **로드 시 조용히 무시**한다(마이그레이션 불필요).
3. **`HUD._on_wave_complete` 배너를 보스 처치 연출로 재활용** — 문구를 `boss_cleared` 로케일 키(en/ko/ja)로
   바꾸고 기존 `sfx_wave_clear.ogg` 를 그대로 쓴다. 죽어 있던 배너·사운드가 이걸로 되살아난다.
4. **`Player.gd:116` 의 훅은 제거한다** — 체크포인트 저장은 이미 `AUTOSAVE_INTERVAL`(20초) 주기로
   돌고 있어(`Player.gd:227~230`) 중복이다. 이 항목에서 실제로 고쳐지는 건 **퀘스트·도전과제 저장**이다.

**수용 기준** — 메뉴 퀘스트 패널의 3개 트랙이 전부 실제로 진행되고, 런 도중 강제 종료 후
재진입해도 퀘스트/과제 진행이 남아 있다. ✅

**완료 (2026-08-18)** — 결정된 4가지를 그대로 이행했다.
1. `Events.wave_complete` → **`milestone_reached(index: int)`** 개명, `ZombieSpawner._on_boss_died`
   에서 `_boss_count` 와 함께 emit. 구독자 5곳(HUD·QuestManager·AchievementManager·Player·ShopPanel)
   전부 이관.
2. `waves` 트랙 → **`survive`(누적 생존 분)**. `Survivor` / 목표 15분 / `goal_mul` 1.6 /
   보상 80 · `reward_mul` 1.5. 15분은 한 판(30분 클리어)의 절반이라 첫 티어가 한 세션 안에 닿는다.
   `elapsed_changed` 는 *그 판의* 경과 시간이라 **증가분만 적산**한다 — 값을 그대로 더하면 판마다
   폭증하고, 이어하기로 900초부터 시작하면 그 900초를 새로 세게 된다. 1분 미만 잔여(`frac`)도
   저장에 넣어 판 사이에 이어진다. 구 `waves` 키는 `_load` 가 `TRACKS` 기준으로만 읽어 자동 무시.
3. `HUD._on_wave_complete`(72줄 연출) + `sfx_wave_clear.ogg` 를 보스 처치 배너로 재활용.
   로케일 `wave_clear_fmt` → **`boss_cleared`**(en/ko/ja). 기존 글자만 써서 재서브셋 불필요.
4. `Player.gd` 의 웨이브 훅 제거 — 체크포인트 저장은 `AUTOSAVE_INTERVAL`(20초) 주기와 중복이었다.

**곁가지 한 줄** — `MainMenu._quest_icon` 의 `"waves" → flag` 를 `"survive" → clock` 으로 바꿨다.
`MainMenu.gd` 는 D 레인 독점 파일이지만, 안 고치면 새 트랙이 폴백 아이콘으로 떠 이 PR 이 만든
결함이 된다. 3줄 · 함수 하나이므로 충돌 위험이 낮다고 판단했다.

**검증** — `tools/verify_quest_tracks.gd` 신설(CI 회귀 목록 추가, `CLAUDE.md` §3 10종으로 갱신).
세 트랙이 각자의 신호로 오르는지 · 생존 적산이 증가분 기준인지(판 되감김 포함) ·
**`ZombieSpawner._on_boss_died` 가 실제로 마일스톤을 쏘는지**(P0-2 의 원인이 "선언만 있고 발신자가
없는 시그널"이었으므로 발신자를 직접 부른다) · 마일스톤에서 퀘스트·도전과제가 디스크로 내려가는지 ·
구 `waves` 키가 남은 세이브를 읽어도 깨지지 않는지. 주기 저장 연결과 보스 emit 을 각각 지워
검사가 3건 실패하는 것을 확인했다. `CLAUDE.md` §3 전체 + `check_text_fit.py` 통과.

**P2-6 에 넘기는 것** — HUD 배너 노드 이름 `wave_clear_bg`/`wave_clear_label` 은 그대로 뒀다.
클리어 연출(`run_cleared`)과 공유하는 범용 배너라 이름만 낡은 것이고, `HUD.tscn` 을 건드리면
E 레인(P1-4)과 충돌한다. `Events.wave_changed`·`wave_progress_changed` 도 P2-6 소관이다.

---

## P0-3. `ShopPanel` 400줄이 완전한 사문(死文)이다

**근거** — `scenes/ShopPanel.tscn` 을 **인스턴스화하는 코드가 0건**
(`grep -rn "ShopPanel.tscn" --include=*.gd .` → 없음). 따라서 유일한 `shop_closed` 발신자
(`ShopPanel.gd:387`)도 실행되지 않고, 이를 구독하는 `Player.gd:112`(`apply_upgrades`)·
`Player.gd:114`(`_autosave`)도 죽어 있다.

**영향** — 실해는 없지만, 다음 작업자가 "상점이 있다"고 오인해 밸런스를 상점 기준으로 잡는다.
실제로 `BALANCE.md` 는 **이미 있지도 않은 상점 비용 곡선을 밸런스의 중심 손잡이로 서술하고 있다**(P3-1 참조).

**작업 ✅ 결정됨 (2026-08-18)** — *"폐기한다."*

삭제 대상: `scripts/ShopPanel.gd` · `scenes/ShopPanel.tscn` · `Events.shop_closed` 시그널 ·
구독처 `Player.gd:112`(`apply_upgrades`) `Player.gd:114`(`_autosave`) · `ShopPanel.gd:53` 의 마일스톤 구독.

주의: `apply_upgrades()` 자체는 남긴다 — `LevelUpPanel.gd:325` 가 직접 호출하는 살아있는 경로다.
같은 PR 에서 `BALANCE.md` 의 "상점 비용 곡선" 서술도 걷어낸다(P3-1 과 겹치는 부분만).

**수용 기준** — 선택한 방향이 코드와 문서 양쪽에 반영되어, `shop` 검색 결과가 일관된다. ✅

**완료 (2026-08-18)** — 지정된 삭제 대상 외에 **함께 죽은 것들이 더 있었다.**

지정분: `scripts/ShopPanel.gd`(392줄) · `scenes/ShopPanel.tscn` · `Events.shop_closed` ·
`Player` 구독 2곳. `apply_upgrades()` 는 `LevelUpPanel` 이 직접 부르는 살아있는 경로라 유지.

**추가로 발견한 고아**
- **로케일 31키** — `sec_*` 4종 + `upg_*` 27종은 전부 `ShopPanel` 이 `Locale.t("upg_%s_name" % id)`
  로 동적 조합해 쓰던 것이고, 다른 호출처가 0건이다(`LevelUpPanel` 은 `ItemDB` 의 이름을 쓴다).
  삭제로 **표시 글자가 453자 → 392자**가 됐다. CJK 폰트 서브셋에 실리는 글리프가 그만큼 준다.
- `AdManager` 의 `"shop_gold"` placement — 이제 쓰는 값은 `"revive"` 하나뿐.
- `SETUP_ADS.md` 가 **삭제된 `scripts/ShopPanel.gd` 를 "관련 코드 위치"로 안내**하고 있었다.

**주석 15곳** — `Player`·`SaveManager`·`WeaponDB`·`LevelUpPanel`·`AdManager`·`SoundManager`·
`Events`·`HUD`·`MainMenu`·`UIStyle`·`UITheme`·`MetaUpgradeDB`·`GameData` 가 상점을 *현존하는
화면*으로 서술하고 있었다. 이 항목의 목적이 "다음 작업자가 상점이 있다고 오인하는 것"을 막는
것이므로 전부 현행 기준으로 고쳤다(전부 한 줄짜리 주석 수정). 특히 `Player`·`SaveManager` 의
"웨이브 클리어/상점 체크포인트 저장" 서술은 P0-2·P0-3 으로 **둘 다 사라져 사실과 달랐다**.

**문서 7종** — `SETUP_ADS`·`POPUP_UI_PLAN`·`OPTIMIZATION_PLAN`·`GAMEFEEL`·`MENU_UI_PLAN`·
`POLISH_PLAN`·`HUD_IMPROVEMENT_PLAN`. `BALANCE.md` 의 상점 비용 곡선 서술은 **P1-6 재작성에서
이미 해소**돼 있어 손댈 것이 없었다(P0-3 지시가 P1-6 보다 먼저 쓰였다).
`VS_SYSTEM`·`ICON_PROMPTS` 는 그대로 뒀다 — 전자는 상점 폐기를 *결정 기록*으로 서술해 이미
일관되고, 후자는 아트 프롬프트 기록이다.

**검증** — `verify_quest_tracks.gd`(C 레인 사문 검사)에 묘비 4종 추가:
`Events.shop_closed` 부재 · `ShopPanel.gd`/`.tscn` 부재 · **상점 전용 로케일 키(`shop_`/`upg_`/`sec_`)
부재**(남으면 안 쓰는 CJK 글리프가 폰트 서브셋에 계속 실려 웹 초기 로딩에 얹힌다).
`CLAUDE.md` §3 전체 + `check_text_fit.py` 통과.

**하지 않은 것** — 폰트 재서브셋. 실행하면 240KB → 230KB(-10KB)인데, 12MB pck 대비 0.08%를
얻자고 폰트 바이너리 2개를 diff 에 넣는 것은 이 PR 의 가독성을 크게 해친다. 글자가 **줄어든**
경우라 `CLAUDE.md` 의 재서브셋 규칙(늘었을 때)에도 해당하지 않는다. 다음에 글자가 늘어
재서브셋할 때 자연히 회수된다.

---

# P1 — 설계 결함: 만든 것과 플레이되는 것의 괴리

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

**작업 ✅ 결정됨 (2026-08-18)** — *"배분되지 않은 보스 리소스·코드·테이블을 삭제한다."*
보스 다양성을 늘리는 대신 **도달 불가 자산을 걷어내는** 방향으로 확정됐다. 삭제 범위는 아래로 한정한다.

**삭제**
- `ZombieSpawner.BOSS_TYPES`(5종) · `BOSS_SEQUENCE` · `_spawn_boss():358~360` 의 폴백 분기
  → 세 테마 모두 `boss_key` 를 가지므로 이 경로는 이미 실행되지 않는다.
- `Boss._behave_gunner`(`Boss.gd:287~347`) + 관련 상태 변수 → 유일하게 도달 불가한 아키타입.
- 아키타입 기본 아트 4종: `assets/sprites/boss_{brute,gunner,summoner,berserk}.png` + 아틀라스 항목.
  `python3 tools/build_atlas.py` 재생성 필수(게임플레이 시트가 그만큼 줄어든다).

**남긴다 — 지우면 안 되는 것**
- `Boss._behave_melee` 는 `Boss.gd:226` 의 `_:` **기본 폴백**이다. 아키타입 미지정 보스의 동작이므로 유지한다.
- `bomber` 는 자기 아트가 없어 `_BOSS_TEX` 에서 `boss_gunner.tres` 를 **빌려 쓰고 있다**(`Boss.gd:27`).
  아트를 지우면 이 참조가 끊기므로 함께 정리한다.

**아트를 지우면 텍스처 폴백이 사라진다 — 안전망을 데이터 층으로 옮긴다**
- `_BOSS_TEX` 와 `setup()` 의 텍스처 폴백(`Boss.gd:157`)을 제거하고, `sprite` 를 **필수**로 만든다.
- 대신 `tools/verify_boss_arena.gd` 에 검사를 추가한다:
  **"`THEME_BOSSES` 의 모든 항목이 존재하는 `sprite` 경로를 갖는다"** — 데이터 실수가 CI 에서 잡히게.
  (아트 폴백을 지우는 대가로 이 검사는 선택이 아니라 필수다)

**수용 기준** — 세 아레나 각각에서 보스가 정상 등장·전투·처치되고(아트 폴백 없이),
`grep -rn "BOSS_TYPES\|BOSS_SEQUENCE\|_behave_gunner\|_BOSS_TEX" scripts/` 결과가 0건이며,
아틀라스 재생성 후 게임플레이 시트가 줄어든다. ✅
게임플레이 시트 **859KB → 767KB**(-92KB). grep 은 앞선 항목들과 같이 **살아 있는 참조 0건**으로
읽는다 — 남은 2건은 왜 지웠는지 설명하는 묘비 주석뿐이다(`Boss.gd:130` · `ZombieSpawner.gd:15`).

**계획에 없던 참조 1건** — `scenes/Boss.tscn` 이 `boss_brute.tres` 를 Body 기본 텍스처로 물고 있어,
아트를 지우자 **씬 파싱이 깨졌다**(HANDOFF 삭제 목록에 없던 항목). 텍스처는 이제 전부 `setup()` 이
데이터에서 넣으므로 씬의 기본 텍스처 참조를 제거했다.

**함께 정리한 것** — `verify_boss_heal.gd` 의 아키타입 스윕에서 `gunner` 를 뺐다(그대로 두면
melee 폴백을 gunner 라는 이름으로 두 번 재게 된다). 같은 파일의 `setup()` 호출에도 sprite 를 넣었다.

**검증** — 수동 확인(치트 `SPAWN BOSS` ×3) 대신 `verify_boss_arena.gd` 에 검사를 넣어 CI 가 대신 본다:
① `THEME_BOSSES` 가 비어 있지 않음 ② 모든 테마의 `boss_key` 가 정의에 실재(어긋나면 그 아레나에
보스가 안 뜬다) ③ 세 보스의 `sprite` 가 존재하는 `Texture2D`
④ **실제로 세워 `Body.texture` 가 붙는지** — 데이터가 맞는 것과 보스가 보이는 것은 다르다.
sprite 를 비워 ③이 실제로 실패하는 것을 확인했다. `CLAUDE.md` §3 전체 통과.

**남은 정리(범위 밖)** — `BalanceData.boss_bullet_damage`("거너 탄 1발 피해")가 이번 삭제로
쓰이지 않게 됐다. 이 항목이 *"삭제 범위는 아래로 한정한다"* 고 못박았고 `balance.tres` 는 손으로
관리하는 밸런스 테이블이라 건드리지 않았다. 지우려면 별도 항목으로 잡을 것.

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

**작업** — ✅ 완료
- `tools/gen_theme_data.gd` 의 세 테마에 `prop_keys` 를 채우고 `.tres` 재생성:
  - suburb: `fence, mailbox, bush, forsale, hydrant`
  - city: `wreck_car, barrier, dumpster, barrel, rubble, tank`
  - lab: `console, drum, pod, server`
- 장애물 비율은 `PropField.SOLID_SHARE`(신설, 30%) 하나로 고정한다. 카탈로그를 균등 추첨하면
  테마 구성에 따라 장애물 밀도가 40%(교외)~75%(연구소)로 멋대로 튀어, 난이도가 데이터 구성의
  부산물이 된다. 장애물/장식을 따로 뽑아 비율을 상수로 분리했다. `DENSITY` 는 30 유지.
- 보스 격리 구역 끼임을 막았다 — 프롭은 바깥으로, 경계는 안쪽으로 밀어 그 사이에 낀 플레이어는
  제자리에서 떨며 감전 피해만 쌓인다(`BossArena` 가 런타임에 씬 끝에 붙어 늘 나중에 처리되므로
  경계가 항상 이겨 빠져나갈 수도 없다). 프롭 배치는 월드 해시로 고정이라 아레나를 피해 놓을 수
  없으니, 바깥면이 경계를 넘는 장애물은 그 프레임 동안 통과시킨다(`PropField._physics_process`).

**수용 기준** — 세 아레나 각각에서 필드에 프롭이 보이고, solid 프롭에 플레이어가 막히며,
좀비 200마리 상황에서 프레임 회귀가 없다.

**검증** — `tools/verify_environment.gd` 에 "── 프롭 ──" 절을 추가했다(CI 게이트에 이미 포함된
스크립트라 워크플로 수정 없이 게이트가 된다). 테마별로 ① prop_keys 가 카탈로그·아틀라스와
맞는지 ② 배치 밀도 ③ 장애물 비율 ≤ 1/3 ④ 장애물이 플레이어를 막는지 ⑤ 경계에 걸친 장애물이
플레이어를 아레나 밖으로 밀지 않는지를 검사한다. `CLAUDE.md` §3 전체 통과.

**남은 확인(실기기 필요)** — 좀비 200마리 + 프롭 동시 상황의 프레임 비교는 헤드리스(더미
렌더러)에서 측정할 수 없다. 브라우저 빌드에서 `PERF HUD` 치트로 드로우콜·프레임타임을
적용 전/후 비교할 것. 프롭은 선택 테마 아틀라스 한 장만 쓰고 그리는 범위도 뷰포트 + 한 셀로
묶여 있어(`_draw`), 화면당 프롭은 10개 안팎(≈20 드로우, 배칭됨)이다.
`DENSITY`(30) 는 실플레이 후 조정 대상으로 남긴다.

---

## P1-3. 입문 아레나(Suburb)가 비어 있다 — 신규 유저가 보는 첫 화면이 가장 밋밋하다

**근거** — `data/themes.tres:18,19` suburb 는 `gimmick_key=""` · `gimmick_keys=()`.
city 는 기믹 4종, lab 은 3종. 즉 **무료·기본 선택 아레나에만 필드 이벤트가 하나도 없다.**
`tools/gen_theme_data.gd:25` 주석상 "#180 이후 입문 아레나는 방해물 미배치"로 **의도된 결정**이지만,
그 결과 `scripts/GasCan.gd`(교외용 가스통, Phase 6-B 산출물)는 **어떤 테마도 참조하지 않는 고아 콘텐츠**가 됐다
(`GimmickSpawner.gd:7` 에 preload 만 남아 있음).

**영향** — 첫인상 구간이 가장 심심하다. 유저가 "이 게임 필드에 뭔가 있다"는 걸 배우기 전에
아레나를 해금해야 하는 순서라, 도심(400골드)까지 못 간 유저는 기믹의 존재를 모른 채 이탈한다.

**작업 ✅ 결정됨 (2026-08-18)** — *"입문 아레나 방해물 미배치 원칙을 유지하고, 고아 코드를 삭제한다."*

`#180` 의 기존 결정(입문 아레나에는 필드 오브젝트를 두지 않는다)을 그대로 유지한다.
따라서 어느 테마도 참조하지 않는 가스통은 **콘텐츠가 아니라 정리 대상**이다.

**삭제**: `scripts/GasCan.gd` · `GimmickSpawner.gd:7` 의 preload 항목 ·
가스통 전용 아트가 있다면 함께(스프라이트/아틀라스 항목 확인 후).

**함께 할 것**: `tools/gen_theme_data.gd:25` 의 주석을 갱신해 **"입문 아레나는 기믹을 두지 않는다 —
가스통도 이 원칙에 따라 제거했다(2026-08)"** 로 남긴다. 다음 세션이 "왜 교외만 비었지?" 하고
되살리는 것을 막는 것이 이 주석의 목적이다.

**수용 기준** — `grep -rn "GasCan\|gas_can" scripts/ data/ tools/` 결과가 0건이고,
세 아레나 모두 기존과 동일하게 동작한다(교외는 기믹 없음 유지).

**완료 (2026-08-18)** — `scripts/GasCan.gd` 삭제 · `GimmickSpawner._CLASSES` 의 `gas_can` 항목 삭제.
전용 아트는 없었다(절차적 `_draw`), 쓰던 사운드 `boom` 은 무기·보스 등 20곳이 공유하므로 남긴다.
주석은 `gen_theme_data.gd`(교외 블록)·`GimmickSpawner.gd` 헤더·`MASTER_PLAN.md` 6-B 세 곳에
"되살리지 말 것"으로 남겼다.

수용 기준의 grep 은 **살아 있는 참조 0건**으로 읽는다 — 위 "함께 할 것"이 요구한 묘비 주석 자체가
`가스통(GasCan)` 이라는 문자열을 포함하므로 문자 그대로의 0건과는 양립할 수 없다. 남은 2건은
`GimmickSpawner.gd:6` 과 `gen_theme_data.gd:26` 의 그 주석뿐이고, 코드 참조는 없다.

**검증** — `CLAUDE.md` §3 전체 통과. `verify_environment.gd` 에 기믹 검사 3종을 추가했다 —
① 교외 기믹 0종 유지(`#180` 원칙이 말없이 뒤집히는 것을 막는다) ② 모든 테마의 기믹 키가
`GimmickSpawner._CLASSES` 에 실재(죽은 키 방지) ③ `gas_can` 이 클래스 표·스크립트 양쪽에서 사라짐(부활 방지).

**작업 중 발견** — 같은 "교외" 블록의 `mud_field` 도 참조하는 테마가 없는 **동일한 고아**다.
한 항목 = 한 PR 규약에 따라 그 PR 에서는 손대지 않고 **P2-7** 로 큐에 올렸다(이후 삭제로 확정·완료).

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

## P1-7. 첫 보스가 난이도 계단이다 — 모든 런이 같은 지점에서 끝난다

**근거** — `tools/sim_balance.py` 실측(2026-08-18, 교전 28판, `BALANCE.md` §3 참고).
**보스를 잡은 판이 0/28.** 난이도 곡선을 절반(`hp_accel_per_min2` 0.042→0.021)으로 완화한
실험에서도 생존 중앙값만 7.8→10.3분으로 늘고 **최대 생존이 10.8분에서 멎었다** — 보스는 10:00 에 나온다.
즉 곡선을 만져도 이 벽은 안 없어진다. 벽은 램프가 아니라 **보스 조우 자체**다.

**영향** — 10분 시점 적 체력 6.46배 + 보스 실효 체력 약 770 + 호위 5마리 + **`BossArena` 가 반경
480px 로 가둬 회피를 봉쇄**한다. 세 압박이 한 순간에 겹친다. 이 게임의 유일한 목표선(30분 클리어)에
도달하려면 보스를 세 번 넘어야 하는데, 첫 관문에서 전부 멈춘다.

**⚠️ 해석 주의** — 오토플레이의 생존 수단이 "도망"인데 아레나가 그걸 뺏으므로, 0/28 은 AI 의 약점을
과대 반영한다. **"보스가 불공정하다"고 단정할 수 없다.** 다만 *같은 제약이 사람에게도 걸린다*.

**작업** — 손잡이는 `data/balance.tres` 쪽이다(곡선이 아니라). 하나씩 바꾸고 재측정한다:
`boss_base_hp`(160) · `boss_curve_scale`(0.8) · `boss_arena_radius`(480) · `boss_escort_base`(4).
**아레나 반경을 먼저 보기를 권한다** — 세 압박 중 유일하게 "플레이어의 대응 수단을 없애는" 항목이다.

**수용 기준** — 랜덤 빌드 28판 기준 보스 처치가 0 이 아니게 되고, 보스전 소요가 20~40초 구간에 든다.

**검증** — `python3 tools/sim_balance.py --runs 12 --character veteran` 로 조정 전/후 비교.

---

## P2-8. 오토플레이가 교전하지 않고 도망만 치는 판이 20~40% 나온다

**근거** — 실측에서 10분 넘게 살면서 **처치 18~232, 좀비 175마리 누적**인 판이 반복 관측됐다.

**실제 원인(작업 중 규명)** — 반발 반경이 아니라 **조준 방식**이었다. 사이드뷰 자동사격은
`Player._update_facing`/`_handle_attack` 에 따라 **이동 중인 좌우 방향으로만** 나간다.
무리에서 수평으로 도망치면 총구가 무리 반대쪽을 향해 **한 발도 맞지 않는다.**
플레이어(220)가 좀비(65~150)보다 빨라 이 상태가 무한히 지속된다.

**영향** — 측정 판의 20~40%가 버려진다(`sim_balance.py` 가 분당 처치 40 미만을 이탈로 제외).
측정 효율이 직접 깎이고, 치트로 게임을 눈으로 확인할 때도 같은 증상이 나온다.

**작업 ✅ 완료** — 축을 나눴다. **쫓기는 동안 가로(X)를 조준축**으로 써서 무리를 총구에 두고,
**회피는 세로(Y)**로 옮겼다. 사람이 이 게임을 하는 방식과 같다.
저위험 구간의 기존 동작(교전 거리 유지 + 젬 수집)은 건드리지 않았다 —
거기에 조준 유지를 걸었더니 무리로 걸어들어가 2~3분에 죽었다(실측으로 확인 후 되돌림).

**부수 수정** — `sim_balance.py` 의 이탈 판별이 **초반 사망을 오분류**하고 있었다(스폰이 적은
구간만 살면 분당 처치가 원래 낮다). 4분 미만 판은 판별 대상에서 제외하도록 고쳤다.

**결과** — 12판 기준 이탈 5판 → **0~1판**. 정상 교전 판이 분당 처치 109~155 로 촘촘해져
측정 도구로서 쓸 만해졌다. 부작용으로 캐릭터 간 격차가 드러났다(`BALANCE.md` §3-3).

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
**8종 전부 헤드리스 실행 가능하고, 전부 실패 시 0이 아닌 종료 코드를 반환한다**
(씬 4종은 `get_tree().quit(0/1)`, `verify_*.gd` 는 `quit(_fail)`). 즉 CI 에 **그냥 실행 줄만
추가하면 게이트가 완성된다** — 로그 파싱도, 스크립트 수정도 필요 없다.

더 큰 문제가 하나 더 있다: **워크플로 트리거가 `push: [main]` 뿐이라 PR 에는 어떤 검사도 걸리지 않는다.**
머지된 다음에야 회귀를 안다 — 병렬 세션 환경에서는 누가 깨뜨렸는지 추적이 불가능해진다.

**작업** — ① `pull_request` 트리거 추가 ② `deploy` 잡은 main 푸시에서만 돌도록 가드
③ import 직후에 회귀 8종 실행 스텝 추가.
**이 항목은 P0/P1 작업을 시작하기 전에 넣는 것이 좋다** — 그래야 이후 변경의 회귀를 CI 가 잡는다.

## P2-6. 웨이브 시대의 데드 API가 `Events` 에 남아 있다
`Events.wave_pressure_mult()` · `wave_speed_pressure()` · `diff_spawn_mult()` · `diff_total_mult()` ·
`difficulty_name()` — **호출처 0건**. `current_wave` 는 항상 1 인데 `SaveManager.gd:81,135` 가
저장·복원하고 있다.
**작업** — 삭제. 남겨야 한다면 `## DEPRECATED` 주석으로 이유를 명시한다.
(다음 작업자가 `wave_pressure_mult` 를 보고 "무한 스케일링이 있다"고 오인한다 — 실제 스케일링은
`ZombieSpawner._hp_mult()` 의 2차 곡선이다.)

## P2-7. `MudField` 가 가스통과 똑같은 고아 코드다 (P1-3 작업 중 발견)
**근거** — `scripts/MudField.gd`(38줄)를 참조하는 곳은 `GimmickSpawner.gd:8` 의 preload 한 줄뿐이고,
그 키(`mud_field`)를 `gimmick_keys` 에 담은 테마가 **없다**(교외는 기믹 미배치, 도심·연구소는 각자 목록).
즉 P1-3 의 가스통과 같은 이유로 실행되지 않는다. 교외용으로 만들어졌는데 `#180` 결정으로 갈 곳이 없어졌다.
**작업 ✅ 결정됨 (2026-08-18)** — *"P1-3 과 같은 판단으로 삭제한다."* (a)

**완료** — `scripts/MudField.gd` 삭제 · `GimmickSpawner._CLASSES` 의 `mud_field` 항목 삭제
(이로써 클래스 표의 `# 교외` 블록이 통째로 사라져, "교외에는 기믹이 없다"는 주석과 코드가 일치한다).
전용 아트는 없었고(절차적 `_draw`), 쓰던 `Player.slow_this_frame()` 은 `CryoVent`(연구소)도
호출하므로 남긴다. 묘비 주석은 P1-3 이 남긴 세 곳(`gen_theme_data.gd` · `GimmickSpawner.gd` ·
`MASTER_PLAN.md` 6-B)에 진창을 나란히 덧붙였다.

**재발 방지** — `verify_environment.gd` 의 기믹 검사에 **"클래스 표에 고아 기믹 없음"** 을 추가했다.
어느 테마도 담지 않은 키는 실행되지 않는 코드다. 이 레포의 실제 실패 양상은 "만들어 놓고 테마에
배선하는 것을 잊는 것"이었고(가스통·진창이 정확히 그랬다), 이제 그러면 CI 가 막는다.
이 검사는 이 PR 이전 상태에서 `mud_field` 로 실패한다.

**수용 기준** — `grep -rn "MudField\|mud_field"` 결과가 결정과 일관된다. ✅
살아 있는 참조 0건이고, 남은 2건은 위 묘비 주석뿐이다.

---

# P3 — 문서 정합성 (**작업 착수 전 반드시 읽을 것**)

> 계획 문서 상당수가 **현재 구현과 어긋나 있다.** 이대로 두면 다음 에이전트가 없는 시스템을 전제로
> 작업한다. 각 항목은 "고쳐 쓰기"가 아니라 **현행 기준 재작성**이 필요하다.

| # | 문서 | 어긋난 내용 | 조치 |
|---|---|---|---|
| P3-1 | `BALANCE.md` | ✅ **해소됨(P1-6)** — 실측 기준으로 전면 재작성했다(측정 방법·판정 기준·실측·손잡이) | — |
| P3-2 | `GOALS.md` | "난이도별 목표 웨이브 8/10/12 · STAGE CLEAR · 클리어 배지" 전제. 실제는 **단일 모드 30분 생존 클리어 + 오버타임**. 단, **미구현으로 남은 P0 3건(목표 배너·보스 예고·목표 대비 피드백)은 여전히 유효** → P1-4 로 승계 | 현행 기준 재작성, 유효 항목은 P1-4 참조로 정리 |
| P3-3 | `BOSS_PLAN.md` §9 | ~~"W5 브루트 · W10 거너…" 웨이브 표기~~ → **P1-1 PR 에서 갱신 완료** (문서 머리에 현행 상태 배너 + §9 현행 등장 규칙 + 삭제된 로스터/테이블 표시). `[ ] P5 밸런스 패스`는 계속 열린 항목 | 남은 것 없음 — P5 는 실플레이 후 밸런스 작업 |
| P3-4 | `POLISH_PLAN.md` | "좀비 11종 스프라이트 🔴 미착수" · "초상 썸네일 미착수" 로 적혀 있으나 **실제로는 존재**(`assets/sprites/zombie_*.png` 11종, `assets/ui/portraits` 3종, `assets/ui/thumbs` 3종, `chest_*.png`). "프롭 배치 안 됨"은 P1-2 에서 해소돼 이 문서에 반영됨 | 나머지 완료 항목 체크가 남아 있다 |
| P3-5 | `ROADMAP.md` | 4번이 "진행 중"이나 아틀라스·바닥 타일은 완료(커밋 `5bbea14`,`bc6650a`). 실제로 남은 건 `AnimatedSprite2D` 뿐이고, 그마저 `Zombie._animate_walk`(절차적 sin 보행)로 **대체 결정**된 상태 | 완료 반영 + 절차적 애니메이션을 대체안으로 명시 |
| P3-6 | `README.md` | 씬 구조·좀비 6종·튜닝 포인트가 **초기 프로토타입 기준**. 현재는 좀비 11종·무기 28·오토로드 17개 | 현행 구조로 갱신(신규 기여자의 첫 진입점이다) |

---

## 부록 — 레인 배치 (병렬 작업 규칙)

같은 파일을 동시에 건드리면 반드시 충돌한다. **레인 간에는 병렬, 레인 안에서는 직렬.**

| 레인 | 순서 | 독점하는 파일 |
|---|---|---|
| **A 인프라** | P2-5 ✅ → P0-1 ✅ | `.github/workflows/`, `HUD.gd`(치트 블록) — **레인 완료, E 해금됨** |
| **B 데이터** | P1-2 → P1-3 → P1-1 → P2-7 | `data/themes.tres`, `tools/gen_theme_data.gd`, `ZombieSpawner.gd` |
| **C 시스템** | P0-2 → P0-3 → P2-6 | `Events.gd`, `QuestManager.gd`, `SaveManager.gd` |
| **D UI** | P2-1 → P2-3 → P2-2 → P2-4 | `MainMenu.gd`, `UIStyle.gd`, `Locale.gd` |
| **E HUD** | P1-4 | `HUD.gd`(진행바·배너) — ~~A 의 P0-1 대기~~ **이제 착수 가능**(P0-1 완료) |
| **F 밸런스** | P1-5 | `data/difficulty.tres` — 실측 선행이라 언제든 가능 |

### 순서상의 제약
```
P2-5 (CI 게이트)  ← 가장 먼저. 안전망 없이 병렬로 커밋하면 회귀 추적이 불가능하다.
   ├─ A: P0-1 ─────────────┐
   │                       └─ E: P1-4   (HUD.gd 충돌 회피)
   ├─ B: P1-2 → P1-3 → P1-1 → P2-7
   ├─ C: P0-2 → P0-3 → P2-6
   ├─ D: P2-1 → P2-3 → P2-2 → P2-4
   └─ F: P1-5
```
- **P1-2(프롭)를 B 레인 선두에 두는 이유** — 데이터 한 줄로 체감이 가장 크고, 뒤의 P1-1(보스)이
  같은 파일을 크게 손대기 전에 끝내는 편이 충돌이 적다.
- **P3 문서 정리는 별도 레인을 만들지 않는다.** 각 항목 PR 에 동봉한다 — 분리하면 또 밀린다.

### 세션 운용
- 레인당 세션 1개. 세션 태그를 `game-defence:lane-<X>` 로 통일하면 나중에 묶어서 조회할 수 있다.
- 각 세션은 **`main` 에서 분기**한다(다른 세션 브랜치 위에 쌓지 않는다).
- PR 을 연 세션은 그 PR 을 구독해 CI 실패를 스스로 고친다 — 사람이 중계하지 않는다.
- 착수 전 `git fetch origin main && git log --oneline origin/main -10` 으로 그 사이 머지분을 확인한다.
