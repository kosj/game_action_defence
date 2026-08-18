# HUD 개선 계획 — 가독성 · 레이아웃 · 비주얼

> 대상: 인게임 HUD (`scenes/HUD.tscn` + `scripts/HUD.gd`).
> 목표: **① 정보 위계 정리(가독성)** **② 화면 점유 최소화(레이아웃)** **③ 투박한 플랫 스타일 → 기존
> 강철+골드 프레임 톤으로 통일(비주얼)**. 필요한 신규 이미지는 VARCO MCP 로 생성한다.

---

## 1. 현황 진단 (스크린샷 + 코드 기준)

| # | 문제 | 근거 |
|---|---|---|
| P1 | **시간 표시가 3중**: 경과 `16:28`(시계 아이콘) + 남은 시간 `13:32`(ProgressLabel) + 하단 `SURVIVE 30:00 → CLEAR` 힌트. 어떤 숫자가 목표인지 즉시 안 읽힘 | `HUD.gd` `_on_elapsed_changed` / `_on_run_progress` / `_build_goal_hint` |
| P2 | **좌하단 로드아웃이 텍스트 리스트**(아이콘24px+이름+레벨 세로 나열). 후반엔 16줄+ 로 화면 좌측 1/3을 덮어 전투 시야를 가리고, 항목마다 다른 원색 텍스트라 난잡함 | `_build_loadout` / `_add_loadout_lines` |
| P3 | **상단바(TopBg 132px)가 크고 밋밋함**: 단색 반투명 패널, 요소(골드/HP/레벨/처치/시간)가 좌·중·우로 흩어져 묶임(grouping)이 없음 | `HUD.tscn` TopBg, `_UIStyle.bottom_bar` |
| P4 | **Lv 라벨과 XP바가 분리**: 최상단 5px 라인과 중앙 `Lv.46` 라벨이 시각적으로 연결 안 됨 | `_build_xp_bar` |
| P5 | **게이지가 StyleBoxFlat 단색**: HP/보스/XP 모두 플랫 사각형+둥근 모서리뿐. 메뉴는 이미 VARCO 나인패치(강철+골드)로 리치한데 HUD만 프로토타입 톤 | `_style_bars` vs `UIStyle.panel/button_box` |
| P6 | **일시정지 버튼이 미완성 느낌**: 회색 사각 플레이트에 코드로 그린 막대 2개, 위치도 상단바 밖(y150)에 어정쩡하게 떠 있음 | `_build_pause_menu` |
| P7 | **언어 혼용**: `2852 처치`(Locale) 옆에 `SURVIVE 30:00 → CLEAR`, `!! SWARM`, `OVERTIME`, `PAUSED` 등 영어 하드코딩 | `_build_goal_hint`, `_on_swarm_incoming`, `_on_run_progress`, `_build_pause_menu` |
| P8 | **고정 픽셀 레이아웃**: HP바 204px, 라벨 오프셋 하드코딩 → 해상도/세이프에어리어(노치) 대응 취약 | `HUD.tscn` 오프셋들, `HP_BAR_W` 상수 |

---

## 2. 목표 레이아웃 (와이어프레임)

```
┌──────────────────────────────────────────────┐
│ ‹XP바: 전폭 8px, 좌측 끝에 [Lv 46] 뱃지›            │  ← 레벨+경험치 한 덩어리
│ ♥ ██████████░░ 14/15        ☠ 2852   [ ⏸ ]   │  ← 좌: 생존(HP)  우: 전과(처치)+일시정지
│ ◉ 992                        ⏱ 13:32          │  ← 좌: 재화     우: 남은시간(메인 타이머)
├──────── 보스 바 (등장 시, 중앙 오버레이) ────────┤
│                                              │
│                  (전 장)                      │
│                                              │
│ [🔫][🔫][🔫][🔫][🔫][🔫]                        │  ← 무기 6슬롯 (아이콘+레벨 뱃지)
│ [⚙][⚙][⚙][⚙][⚙][⚙]                          │  ← 패시브 6슬롯
└──────────────────────────────────────────────┘
```

핵심 결정:

1. **타이머 1개로 통합** — 남은 시간(카운트다운)을 우측 상단 메인 타이머로 승격.
   카운트다운 자체가 "30분 생존" 목표를 전달하므로 하단 goal 힌트는 **게임 시작 후 ~8초만
   보여주고 페이드 아웃**. 경과 시간은 일시정지 패널/게임오버 통계로 이동. OVERTIME 진입
   시 타이머가 금색 `OVERTIME +MM:SS` 카운트업으로 전환.
2. **로드아웃 = 아이콘 슬롯 그리드** — 텍스트 제거. 무기 1줄 + 패시브 1줄(슬롯 40px,
   6칸), 슬롯 우하단에 레벨 숫자 뱃지. 위치는 **좌하단 유지하되 가로 그리드**(조이스틱은
   전역 드래그라 간섭 없음, 상단은 이미 포화). 새 획득/레벨업 시 해당 슬롯 펄스.
3. **상단바 2단 압축(≈96px)** — 좌측 "내 상태"(HP·골드) / 우측 "런 상태"(처치·남은시간)
   로 의미 단위 묶음. 일시정지 버튼은 상단바 우측 끝에 정착.
4. **Lv 뱃지를 XP바에 부착** — 바 좌측 끝 원형 뱃지 안에 `46`. 레벨업 시 뱃지 펄스+바 플래시.

---

## 3. 단계별 작업

### Phase 1 — 레이아웃 재구성 (코드만, 에셋 불필요)

| 작업 | 파일 | 내용 |
|---|---|---|
| 1-1 타이머 통합 | `HUD.gd`, `HUD.tscn` | `TimeLabel` 을 메인 카운트다운으로(26px, 시계 아이콘 유지), `ProgressLabel` 제거. OVERTIME 전환 처리. 경과시간은 일시정지/게임오버로 이동 |
| 1-2 goal 힌트 자동 소멸 | `HUD.gd` | `_build_goal_hint` 에 8초 후 페이드 아웃 트윈 추가 |
| 1-3 로드아웃 그리드화 | `HUD.gd` | `_build_loadout`/`_add_loadout_lines` 재작성: `GridContainer`(6열) + `UIStyle.make_item_slot` 재사용 + 레벨 뱃지 라벨. `inventory_changed` 에서 diff 감지해 신규/업그레이드 슬롯 펄스 |
| 1-4 상단바 재배치 | `HUD.tscn`, `HUD.gd` | TopBg 132→96px, 좌(HP·골드)/우(처치·시간) 묶음 정렬, `_right_stat_icon` 정리. HP바를 화면폭 비례(`anchor` 기반, 좌측 45%)로 |
| 1-5 Lv 뱃지+XP바 결합 | `HUD.gd` | `_build_xp_bar` 재작성: 바 좌단 원형 뱃지(레벨 숫자), 레벨업 펄스 |
| 1-6 일시정지 버튼 정착 | `HUD.gd` | 상단바 우측 상단 44px, Phase 2 원형 플레이트 적용 전까지 현 스타일 유지 |
| 1-7 문자열 로케일화 | `Locale.gd`, `HUD.gd` | `SURVIVE …`, `OVERTIME`, `!! SWARM`, `!! ELITE PACK`, `PAUSED`, `AUTO`, 게임오버 `VICTORY!` 등 키 추가(en/ko/ja) |
| 1-8 세이프에어리어 | `HUD.gd` | `DisplayServer.get_display_safe_area()` 기반 상단 오프셋 보정(웹/모바일 노치) |

### Phase 2 — 비주얼 (VARCO 에셋 + 스타일 교체)

기존 `assets/ui/frames/`(panel_frame·button_plate·item_slot, 강철+골드 베벨)와 같은 톤으로
아래 6종을 생성해 `assets/ui/hud/` 에 추가:

| 파일 | 용도 | 크기/형식 | 프롬프트 주제(스타일 베이스는 §5) |
|---|---|---|---|
| `hud_top_bar.png` | 상단바 나인패치 | 640×160, margin 40 | dark brushed-steel HUD top bar plate, thin gold hairline along the bottom edge, rounded bottom corners, subtle top-down gradient |
| `hud_gauge_frame.png` | HP/보스/XP 공용 게이지 프레임 | 512×64 나인패치, margin 24 | slim metal gauge frame, recessed dark inner channel, thin gold bevel rim |
| `hud_gauge_fill.png` | 게이지 필(무채색→틴트) | 512×48, margin 20 | glossy neutral-white energy bar fill strip, soft top highlight, straight edges |
| `hud_slot_small.png` | 로드아웃 미니 슬롯 | 128×128 | small square item slot, thin steel rim, dark recessed center, minimal ornament (기존 item_slot 보다 단순) |
| `hud_btn_round.png` | 일시정지 등 원형 버튼 플레이트 | 96×96 | round brushed-steel button plate, gold rim, subtle center glow |
| `hud_badge_level.png` | 레벨 뱃지 | 64×64 | small circular metal badge plate, gold trim, empty center |

코드 작업:

| 작업 | 파일 | 내용 |
|---|---|---|
| 2-1 게이지 헬퍼 | `UIStyle.gd` | `gauge_frame()` / `gauge_fill(tint)` 추가 — StyleBoxTexture 쌍 반환, `modulate_color` 로 HP초록/보스빨강/XP시안 틴트 |
| 2-2 게이지 교체 | `HUD.gd` | `_style_bars()` 를 텍스처 기반으로. HP 색상 보간(`_hp_color`)은 `modulate_color` 갱신으로 유지 |
| 2-3 상단바 교체 | `HUD.gd` | `bottom_bar` StyleBoxFlat → `hud_top_bar` StyleBoxTexture |
| 2-4 슬롯/뱃지/버튼 적용 | `HUD.gd`, `UIStyle.gd` | 로드아웃 슬롯 `hud_slot_small`, Lv 뱃지, 원형 일시정지 버튼(막대 아이콘은 유지 — 폰트 글리프 이슈 회피) |
| 2-5 아이콘 정리 | `UIIcon.gd` | 벡터 폴백 중 실제 노출되는 것(hp 하트 등)만 텍스처 승격 여부 판단 — skull/clock/coin 은 이미 텍스처 |

### Phase 3 — 폴리시 (선택, 여력 시)

1. **HP 잔상 게이지**: 피해 시 밝은 잔량 바가 0.4s 늦게 따라 줄어드는 "damage ghost".
2. **골드 롤링 카운터**: 숫자가 촤르륵 올라가는 트윈(현재는 스케일 펄스만).
3. **XP 획득 반짝임**: 바 끝단 스파클, 레벨업 시 뱃지 펄스 + 바 플래시.
4. **상단 배너 스택 매니저**: 보스/스웜/토스트가 같은 y 대역에서 겹치지 않게 큐 처리.
5. **숫자 정렬**: 타이머/처치/골드 라벨에 고정폭 숫자(서브셋 폰트가 지원하면 `font_features`
   tnum, 아니면 `%02d` 자릿수 고정 유지).

---

## 4. 변경 파일 요약

- `scenes/HUD.tscn` — 상단바 축소·노드 재배치, ProgressLabel 제거, 앵커 기반 레이아웃
- `scripts/HUD.gd` — 로드아웃 그리드, 타이머 통합, XP+Lv 뱃지, 게이지/바 텍스처 스타일
- `scripts/UIStyle.gd` — `gauge_frame()/gauge_fill()/round_button()` 헬퍼
- `scripts/Locale.gd` — HUD 하드코딩 문자열 키 추가 (en/ko/ja)
- `assets/ui/hud/` — 신규 VARCO 에셋 6종

## 5. VARCO 생성 절차 메모

- 브라우저에서 **커스텀 워크플로를 연 상태**여야 MCP 가 동작한다(`list_workflow_sessions` 로 확인).
- 공통 스타일 베이스(기존 프레임과 톤 일치, `ICON_PROMPTS.md` 계승):
  ```
  game UI element, dark brushed steel with subtle gold bevel trim, soft top-left
  lighting, clean vector shading, subtle inner shadow, no text, no watermark,
  isolated on transparent background, crisp edges, nine-patch friendly straight
  stretchable edges
  ```
- 네거티브: `text, letters, watermark, ornate filigree, photo, blurry, background scenery, cropped`
- 생성 → `get_output_downloads` 로 PNG 확보 → `assets/ui/hud/` 배치 → Godot 재임포트.
- 나인패치 margin 은 실제 생성물 보고 확정(위 표 값은 초기치).

## 6. 검증

1. 각 Phase 후 데스크톱 실행(F5)으로 720×1280 기준 확인 + 초반/후반(로드아웃 16종) 스냅샷 비교.
2. 체크리스트: 타이머 1개만 보이는가 / 로드아웃이 2줄 그리드로 유지되는가 / OVERTIME 전환 /
   보스바·스웜 배너·토스트 겹침 없음 / 부활·게임오버 시 로드아웃·일시정지 버튼 숨김 동작 유지 /
   ko·ja 로케일에서 하드코딩 영어 잔존 없음.
3. 웹 빌드에서 CJK 폰트·나인패치 텍스처 필터링 확인(기존 서브셋 폰트 이슈 코멘트 참고).

## 7. 작업 순서 제안

Phase 1(반나절, 순수 코드) → 스크린샷 리뷰 → Phase 2 에셋 생성·적용(에셋 대기 시간 포함 반나절)
→ Phase 3 은 리뷰 후 선별. Phase 1 만으로도 P1·P2·P4·P7(가독성/레이아웃 문제 대부분)이 해소되고,
Phase 2 가 "투박함"(P3·P5·P6)을 해결한다.
