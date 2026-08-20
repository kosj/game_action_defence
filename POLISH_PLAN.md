# 연출 완성도 개선 계획 & 필요 이미지 리스트

> (A) 연출 개선 계획과 (B) 필요한 이미지 에셋 리스트. 우선순위: 🔴 높음 · 🟡 중간 · ⚪ 낮음.
>
> ⚠️ **2026-08-20 현행화(P3-4).** 그 전 버전은 "좀비 11종 스프라이트 미착수" · "초상 썸네일
> 미착수" · "보물상자는 절차적 드로잉" 으로 적고 있었으나 **셋 다 이미 존재한다.** 반대로
> "아키타입 4종 텍스처 유지"는 그 자산이 **삭제된 뒤에도**(P1-1) 남아 있었다.
> 아래 체크는 파일과 코드를 직접 열어 대조한 결과다.
>
> 에셋은 이제 "없어서 못 하는" 단계가 아니다 — 최소 필수 4종이 전부 확보됐다(§B 끝).
> 남은 것은 대부분 **코드로 되는 연출**(§A)이다.

---

## A. 연출 개선 계획 (juice / polish)

### A-1. 씬 전환 & 흐름 ✅ 대부분 완료
- [x] **씬 페이드 트랜지션** — `SceneFade` 오토로드(`transition_to`)로 메뉴↔게임↔재시작 전환에 적용.
- [x] **일시정지 오버레이 블러** — `HUD._set_blur()` 가 일시정지·게임오버에서 배경을 흐린다
      (`assets/shaders/gameover_blur.gdshader`).
- [ ] **게임 시작 연출** — 인트로 스토리(`IntroStory`)는 있으나 전투 진입 순간의 연출은 없다.

### A-2. 타격감 (hit feedback) 🔴
- **히트스톱 튜닝**: 여전히 **보스 사망 1곳뿐**이다(`Events.hit_stop()` 호출처 = `Boss._die`).
  큰 타격(크리티컬·엘리트 처치)에도 아주 짧게(0.03s) 적용. ⚠️ 배속을 만지므로 `Events` 워치독과
  함께 봐야 한다(`CLAUDE.md` §4).
- **넉백 먼지**: 좀비 넉백 시 발밑 먼지 퍼프(작은 파티클) — 타격 무게감.
- **데미지 숫자 개선**: 폰트 굵기·아웃라인·튀는 곡선(현재 단순 상승) + 크리티컬 강조 확대.
- **좀비 사망 연출**: 현재 FXBurst 뿐 → 잠깐 흰색 실루엣 → 파편/재로 흩어지는 파티클.

### A-3. 파티클 / 이펙트 🟡
- **머즐 플래시·트레일 다양화**: 무기별 색·모양(이미 색은 있음, 모양·잔상 추가).
- **환경 앰비언트**: 테마별 떠다니는 입자(교외=꽃가루/먼지, 도심=재, 연구소=포자). 배경에 은은하게.
- **무기 임팩트**: 화염(일렁이는 불꽃 스프라이트), 번개(이미 지그재그), 폭발(링+파편).

### A-4. 카메라 연출 🟡
- [x] **보스 등장 줌** — `Player._camera_zoom_punch(0.90, 0.55)` 가 `boss_spawned` 에 걸려 있다.
- **킬 스트릭/레벨업 펀치**: 레벨업·진화 시 줌펀치 + 시간 슬로우(0.1s). 줌 펀치 함수는 이미
  있으니 호출만 얹으면 된다.
- **저체력 경고**: 화면 가장자리 붉은 맥동 비네트(체력 20% 이하) — 긴장감.

### A-5. UI/UX 마감 🔴
- **버튼 피드백**: 눌림 애니메이션·호버 하이라이트·클릭 사운드 일관 적용.
- [x] **무기/패시브 아이콘** — 전부 실제 아이콘이다(UI 아틀라스). 색 폴백은 아이콘이 없을 때만 쓴다.
- [x] **버튼 판(plate)** — 나인패치 3종(steel/blood/dark)으로 위계를 만든다(P2-2).
- [x] **잠금/완료 표시** — 아스키 대체(`[-]`·`v`)를 아이콘으로 교체(P2-4).
- **레벨업/진화 카드 연출**: 카드 등장 stagger, 진화는 골드 광휘·파티클로 특별하게.
- **HUD 정리**: 상단 바 아이콘화(골드/처치/시간), 체력 게이지 위 숫자 가독성.
- **폰트**: 제목용 디스플레이 폰트 1종 추가(현재 본문 폰트로 제목까지 처리).

### A-6. 사운드 🟡
- **BGM 레이어링**: 평상시 → 보스전/오버타임에 강도 높은 트랙 크로스페이드.
- **SFX 다양화**: 무기별 발사음(현재 shoot/laser/boom 공유), 처치·픽업·레벨업·진화 전용음.
- **피치 변주**: 연속 처치 콤보 시 픽업/처치음 피치 상승(리듬감).

### A-7. 스프라이트 애니메이션 🟡
- 현재 캐릭터·좀비·보스는 **절차적 바운스/스쿼시**(1스프라이트). 최소 걷기 2~4프레임 시트로 교체하면 생동감 크게 상승.
- 보스는 공격/격노 프레임 별도.

### 구현 순서 제안
1. **1차(체감 큼·저비용):** 씬 페이드, 버튼 피드백, 저체력 비네트, 좀비 사망 파티클, 데미지 숫자 개선.
2. **2차:** 보스 등장 줌+배너, 레벨업/진화 카드 연출, 무기/패시브 아이콘, 앰비언트 입자.
3. **3차(에셋 필요):** 캐릭터/좀비/보스 스프라이트 시트, 무기 아이콘 세트, 전용 SFX/BGM.

> 1차 항목들은 **이미지 없이 코드/셰이더/파티클만으로** 구현 가능 — 원하면 바로 착수 가능.

---

## B. 게임 완성도를 위한 필요 이미지 리스트

> 형식: **사이드뷰(좌우), 투명 배경 PNG**. 캐릭터/적은 오른쪽을 바라보는 기준(코드가 좌우 플립).
> 대부분 현재 절차적으로 그려지므로, 아래는 "있으면 완성도가 크게 오르는" 우선순위 리스트다.

### B-1. 캐릭터 (플레이어) ✅ 완료 (idle 1프레임)
- [x] **3종 각각 구분되는 스프라이트** — 베테랑·사냥꾼·엔지니어 전용 아트 적용 완료.
  - `assets/sprites/player_{veteran,hunter,engineer}.png` (사냥꾼은 신규 후드·석궁 아트로 갱신).
  - 데이터 배선: `CharacterData.sprite_path`/`sprite_scale` → `Player._apply_character_sprite()`.
  - 남은(선택) 개선: 각 캐릭터 **walk 2~4프레임** 시트(현재 idle 1프레임 + 절차적 바운스).

### B-2. 좀비 (11종) ✅ 완료 (idle 1프레임)
- [x] 11종 전용 사이드뷰 스프라이트 — `assets/sprites/zombie_{walker,sprinter,bloater,gaunt,foreman,
      toxic,screamer,cop,soldier,longneck,suit}.png`. 아틀라스 참조는 `assets/atlas/zombie_*.tres`,
      배선은 `tools/gen_zombie_data.gd` 의 `tex` 필드 → `data/zombies/*.tres` → `Zombie.setup()`.
- 남은(선택) 개선: walk 2~4프레임 시트. 현재는 `Zombie._animate_walk` 의 절차적 바운스다
      (`ROADMAP.md` 4번의 대체 결정 참고 — 되돌리려면 pck 상한부터 다시 볼 것).

### B-3. 보스 ✅ 테마 보스 3종 완료 (아키타입 전용 아트는 폐기됨)
- [x] **테마 보스 3종 전용 스프라이트** — 변이 사냥개·더 레커·프라임 변이체 적용 완료.
  - `assets/sprites/boss_{mutant_dog,wrecker,mutation}.png` (더 레커는 좌향 원본을 우향으로 플립).
  - 데이터 배선: `THEME_BOSSES[...].sprite` → `Boss.setup()`(없으면 아키타입 기본 텍스처로 폴백).
- ~~아키타입 5종(brute/gunner/summoner/bomber/berserk) 아트~~ → **해당 없음.** 세 테마가 전부
  `boss_key` 를 갖게 되면서 아키타입 순환 경로가 죽었고, 미배치 아트 4종과 `gunner` 아키타입은
  **삭제했다**(P1-1). 지금 아키타입은 테마 보스가 쓰는 berserk/bomber/summoner 셋 + 미지정
  폴백 `melee` 뿐이고, 스프라이트는 `THEME_BOSSES[...].sprite` 로만 온다(폴백 없음 —
  `tools/verify_boss_arena.gd` 가 세 항목의 존재를 CI 에서 검사한다).
- [ ] 선택: 각 보스 격노(2단계) 컬러/포즈 변형.

### B-4. 무기 아이콘 ✅ 완료 (30/30)
- 배선 완료: `WeaponData.icon` → 레벨업 카드(`LevelUpPanel`) + 로드아웃(`HUD`)에 표시, 없으면 색상 폴백.
  파일 규칙 `assets/ui/icons/weapon_<id>.png` → `gen_item_catalog` 이 자동 연결.
- [x] **총기 계열 8종**: gun/railgun · machinegun/gatling · shotgun/dragonsbreath · crossbow/ballista
- [x] **화염 계열 4종**: flamethrower/inferno · molotov/napalm
- [x] **전기·회전 계열 6종**: lightning/thunderstorm · tesla/stormcoil · orb/sawstorm
- [x] **신성·오라 2종**: garlic/sanctuary  *(holy/crucifix 는 카탈로그에서 삭제된 무기다)*
- [x] **설치·근접 5종**: mine/claymore · chainsaw · turret · drone  *(spikedbat 도 삭제됨)*
- [x] **궁극기 3종**: ult_quake · ult_arrowstorm · ult_orbital (규약 경로로 자동 연결)
- 발사체(화살/볼트·산탄·불꽃·톱날)는 선택 — 현재 드로잉으로 충분.

### B-5. 패시브 아이콘 ✅ 완료 (10/10)
- 배선 완료: `PassiveData.icon` → `ItemDB._p_dict` → 레벨업 카드/로드아웃(무기와 동일 경로). 파일 `assets/ui/icons/passive_<id>.png` 자동 연결.
- [x] armor·swift·haste·crit·magnet·regen·ammo_belt·gunpowder·battery·rabbits_foot (10종)

### B-6. 픽업 / 오브젝트 🟡
- [x] 경험치 젬(파란 다이아) · 골드 코인(`ui_coin.png` 교체) 적용 완료.
- [x] 보물상자·진화 상자 — 전용 아트 배선 완료(`ItemPickup.CHEST_TEX_PATH`/`EVOCHEST_TEX_PATH`
      → `assets/atlas/chest_{treasure,evolution}.tres`). *폭탄 스폰은 제거됐다 — 필드 스폰은 상자뿐.*
- [x] 미장센 프롭 15종 배치 완료 — `ThemeData.prop_keys` 에 테마별 목록을 넣어 `PropField` 가 필드에 흩뿌린다
  (교외 5 · 도심 6 · 연구소 4). 아트는 `assets/sprites/props/<테마>/`, 참조는 테마별 아틀라스
  `assets/atlas/props/<테마>/`. 밀도 손잡이는 `PropField.DENSITY`(30%), 장애물 비율은 `SOLID_SHARE`(30%).

### B-7. 배경 / 타일 🟡 바닥 타일 3종 적용 완료
- [x] 테마 3종 바닥 타일 배선: `Ground._TILE_TEX`(grass=교외 · stone=도심 · frozen=연구소) → 월드 고정 타일링. (desert 는 기존 절차적 폴백)
- [ ] 패럴랙스 배경 실루엣 — 미업로드(코드에도 `Parallax*` 노드가 없다).

### B-8. UI / 기타 🟡
- [x] **타이틀 로고**("ZOMBIE BUSTER") — `TitleScreen`·`MainMenu` 텍스트를 `logo_title.png` 로 교체.
- [x] HUD 아이콘 골드/처치/시간 — `UIIcon._KIND_TEX`(coin/skull/clock) 텍스처 배선.
- [x] `hud_xp`(파란 별) — `ChestRewardPanel`·`MainMenu` 에 배선 완료.
- [x] FX 텍스처 — `fx_explosion`·`fx_muzzle`·`fx_smoke`·`fx_hitspark` 아틀라스 배선 완료
      (`Player` 머즐, `BurningCar`/`SteamVent` 폭발·연기 등).
- [x] 9-slice 프레임 — `assets/ui/frames/{panel_frame,item_slot,button_plate,btn_plate_*}.png`
      → `UIStyle.tex_box()` 의 `StyleBoxTexture`. ⚠️ 이 폴더는 **무손실 임포트가 규약**이다
      (`CLAUDE.md` §2 — 새 PNG 는 `compress/mode=0` 으로 고쳐야 한다).
- [x] 캐릭터/테마 선택 카드용 초상·썸네일 — `assets/atlas/menu/portrait_*.tres`·`theme_*.tres`
      배선 완료(캐릭터 패널·아레나 패널·도감).

### 최소 필수(가성비 우선)
1. [x] **캐릭터 3종 구분 스프라이트** — 완료(veteran/hunter/engineer).
2. [x] **무기·패시브 아이콘 세트** (UI 완성도 직결) — 무기 28/28 ✅ + 패시브 10/10 ✅ 완료.
3. [x] **테마 보스 3종 스프라이트** — 완료(mutant_dog/wrecker/mutation).
4. [x] **좀비 11종 구분 스프라이트** — 완료.

> **네 가지 모두 확보됐다.** 남은 것은 "있으면 더 좋은" 것들뿐이다 — walk 프레임 시트,
> 보스 격노 포즈, 패럴랙스 배경. 나머지는 절차적 드로잉으로 충분히 버틴다.
>
> 에셋을 추가할 때의 파이프라인은 `ASSET_PIPELINE.md` 에 있다. 요약하면 셋을 반드시 지킨다:
> ① 유닛은 `tools/make_icon.py --height 120 --black-halo` 로 정규화
> ② **아틀라스에 넣는다**(PNG 직접 참조는 그 스프라이트만 배칭이 끊긴다)
> ③ `assets/ui/frames`·`hud` 에 넣는 것은 `.import` 압축을 무손실로 고친다.
