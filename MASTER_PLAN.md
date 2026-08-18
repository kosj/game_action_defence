# Zombie Buster — 구현 마스터 플랜 (스펙 대비 갭 & 단계별 계획)

> 목적: 첨부 스펙(핵심 루프 / 캐릭터 3종 / 성장 3레이어 / 무기·진화 / 테마 3종 / 기술요구)을
> 현재 코드베이스와 대조해, **이미 된 것은 제외**하고 남은 작업을 단계로 나눈 계획.

---

## 0. 현재 상태 요약 (스펙 항목별)

| 스펙 항목 | 상태 | 메모 |
|---|---|---|
| 좀비 처치 → 경험치 젬 | ✅ 완료 | `Gold.gd` = XP 젬, 골드는 보물상자 |
| 레벨업 → 4중 1택 | ✅ 완료 | `LevelUpPanel.gd` |
| 빌드 완성 + 진화 | ✅ 완료 | **Phase 3-B** — 진화 12종, 상자 게이팅 발동 |
| **난이도 = 경과 시간** | ✅ 완료 | **Phase 1** — `DifficultyData`(.tres) + `ZombieSpawner` 시간 구동 |
| 30분 생존 = 클리어 + 이후 무한 | ✅ 완료 | **Phase 1** — `clear_seconds` 도달 시 `run_cleared`, 이후 오버타임 하드모드 |
| **캐릭터 3종** | ✅ 완료 | **Phase 4** — 베테랑·사냥꾼·엔지니어(시작무기+시그니처패시브+스탯보정+선택 UI+조건부 트레잇) |
| A. 인게임 공통 스탯 | 🟡 부분 | 핵심 스탯 존재(`Events.upgrade_*`). 관통/행운/투사체수 일부 없음 |
| A. 무기 12종 | ✅ 완료 | 스펙 12 동작 계열 전부 구현(배치1~4). 산탄총·기관총·석궁·화염방사기·화염병·지뢰·못배트·체인소·**터렛·드론·테슬라** + 기존 gun·orb·lightning·garlic·holy. 남은 건 스펙 이름 재매핑(gun→리볼버 등, "기존 흡수" 단계) |
| A. 패시브 10종 | ✅ 완료 | **Phase 3-A** — 데이터 구동 효과(PassiveData.effect/per_level). 방탄조끼·운동화·에너지드링크·조준경·자석·응급키트 + 신규 탄약벨트·화약·배터리·토끼발 |
| B. 캐릭터 차별화 데이터 | ✅ 완료 | **Phase 4** — `CharacterData`(시작무기/시그니처패시브/스탯보정/`trait_key`) + 조건부 트레잇 런타임 로직 |
| C. 메타 영구 강화 | ✅ 완료 | **Phase 5-A** — 10종(위력·체력·이속·탐욕·성장 + 행운·재생·공속·범위·**부활**). recompute 순서 정정으로 체력/이속 실효화 |
| C. 해금(캐릭터/무기/테마) | 🟡 부분 | **Phase 5-C** — 캐릭터 해금(재화 구매/도전과제 게이팅) 완료. 무기/테마 해금은 후속 |
| C. 도전과제 | ✅ 완료 | **Phase 5-B** — `AchievementData` 10종 + `AchievementManager`(추적·저장·메타골드 보상) + HUD 토스트 + 메뉴 목록 |
| 무기 진화표(12종, 보물상자 발동) | ✅ 완료 | **Phase 3-B** — 진화 12종, 엘리트/보스 드롭 진화 상자 개봉 시 선택 |
| **테마 3종(오브젝트/기믹/보스)** | ✅ 완료 | **Phase 6** — 비주얼셋+선택/해금 + 테마 기믹(낙석·독가스 등, 교외는 미배치) + 테마 보스(사냥개·견인체·프라임 변이체) |
| 난이도 뼈대(1분/5분/10분/30분) | ✅ 완료 | **Phase 1** — `tier_seconds`60·`elite_seconds`300·`boss_seconds`600·`clear_seconds`1800 |
| 세이브(로컬) | ✅ 완료 | `SaveManager`·`MetaManager`·`RankingManager` |
| 수익화 훅(부활/2배/스킨) | 🟡 부분 | `AdManager` 부활 훅 O. 2배 보상·스킨 자리 X |
| 오브젝트 풀링 | ✅ 완료 | `Pool.gd` |
| **이펙트 동시표시 상한** | ✅ 완료 | **Phase 7-A** — FXBurst 동시/프레임당 캡 + 데미지숫자 프레임 캡(기존) + 화면흔들림 상한(기존) |
| **데이터 = Resource 분리(하드코딩 금지)** | 🟡 부분 | **Phase 0/2** — 좀비·메타·난이도·**무기/패시브/진화 카탈로그** `.tres` 완료. 캐릭터/테마/과제 남음 |

범례: ✅ 완료 · 🟡 부분 · ❌ 없음

---

## 1. 설계 원칙 (스펙에서 도출)

- **데이터 우선(Data-first):** 무기·좀비·캐릭터·테마·메타·도전과제 = **Godot `Resource`(.tres)**.
  코드는 "동작", 수치는 "데이터". 사용자가 `.tres`만 고쳐 밸런싱.
- **모듈형 무기:** 무기 = 데이터(Resource) + 동작 모듈(behavior). 12종을 소수의 동작 패턴
  (발사체/근접원호/설치물/장판/오라/체인)으로 구현하고 파라미터로 변주.
- **디렉터 기반 난이도:** 스폰/스탯을 **경과 시간**으로 구동하는 `DifficultyDirector` 리소스(타임라인).
- **점진적·검증 가능:** 각 단계는 독립적으로 빌드·플레이 검증(로컬 Godot 헤드리스) 후 머지.

---

## 2. 단계별 계획

각 단계 = 1개 이상의 PR. ⬛=기반, 🟩=콘텐츠, 🟦=시스템.

### Phase 0 ⬛ — 데이터 기반(Resource) 전환 *(모든 것의 전제)*
스펙 "하드코딩 금지"를 만족시키고 이후 단계를 데이터로 확장 가능하게 하는 기반.
- `Resource` 서브클래스 정의: `WeaponData`, `PassiveData`, `EvolutionData`, `ZombieData`,
  `CharacterData`, `ThemeData`, `BossData`, `MetaUpgradeData`, `AchievementData`.
- `res://data/` 폴더 + `.tres` 에셋. `GameData`(autoload)가 폴더를 로드해 id→리소스 맵 제공.
- 기존 하드코딩 이관: `ItemDB` 카탈로그 → Weapon/Passive/Evolution `.tres`,
  `ZombieSpawner.ZOMBIE_TYPES` → Zombie `.tres`, `MetaManager` 업그레이드 → MetaUpgrade `.tres`.
- 기존 동작 코드(Bullet/Orb/…)는 유지하되 수치를 리소스에서 읽도록 배선.
- **산출물:** 데이터 폴더 + 로더. 게임 동작은 이전과 동일(회귀 없음)해야 함.
- **리스크:** 큰 리팩터. → 이관은 "값 동일"을 원칙으로 하고 헤드리스 회귀 검증.

### Phase 1 🟦 — 시간 기반 난이도 디렉터 + 30분 클리어
- `DifficultyDirector`: 경과 시간 t로 **스폰 간격·동시수·좀비 HP/속도 배수·종 조합**을 구동.
  `DifficultyTimeline`(Resource)로 곡선/구간 정의.
- 이벤트 뼈대: **1분마다 좀비 조합 변경 · 5분마다 엘리트 · 10분마다 보스**.
- **30분 = 클리어**(승리 연출/집계) → 이후 **좀비 스탯 배수 무한 증가**(하드모드).
- HUD: 상단에 **경과 시간 = 진행바**, 다음 이벤트(엘리트/보스) 예고.
- 현재 처치-수 기반 로직 대체(스폰/보스 트리거 재작성).

### Phase 2 🟩 — 무기 12종 (데이터 + 동작 모듈)
동작 패턴으로 분류해 구현(파라미터 변주):
- **직선 발사체:** 리볼버(관통), 석궁(관통), 기관총(고연사), 산탄총(확산·넉백).
- **장판/투척:** 화염방사기(원뿔 장판), 화염병(투척 장판), 지뢰(설치 폭발).
- **근접 원호:** 못 박은 배트, 체인소(지속 근접).
- **설치물(자동):** 자동 터렛, 드론(추적 자동사격), 테슬라 코일(연쇄 번개).
- 각 무기 8레벨 강화 곡선 = `WeaponData`. 기존 gun/orb/lightning/garlic/holy는
  스펙 무기로 재매핑 또는 흡수(예: lightning→tesla, gun→revolver/기관총).
- **주의:** 12종은 큰 콘텐츠. 서브단계로 3~4종씩 나눠 PR.

### Phase 3 🟦 — 패시브 10종 + 진화표 12종(상자 게이팅)
- 패시브 10종(방탄조끼/탄약벨트/조준경/운동화/에너지드링크/자석/응급키트/화약/배터리/토끼발)
  → 핵심 스탯 보정 데이터.
- 진화 발동 규칙 스펙대로: **① 베이스 만렙 ② 짝꿍 패시브 보유 ③ 엘리트/보스 드롭 보물상자 개봉**.
  → 현재 "레벨업 카드로 진화"를 **상자 개봉 시 진화 선택**으로 변경.
- 진화 12종 데이터 + 과장 효과. **역할 비겹침 원칙**(장판/단일고뎀/자동전방위 등) 명시.

### Phase 4 🟦 — 캐릭터 3종
- `CharacterData` = 시작무기 + 스탯보정 + 고유패시브 + 시그니처 진화.
- 베테랑(근접 탱커)/사냥꾼(원거리 딜러)/엔지니어(설치 디펜스).
- 고유 패시브 로직: 저체력 공격력↑·근접 처치 회복 / 정지 시 치명타↑ / 설치물 강화·재화↑.
- 캐릭터 선택 UI(메인메뉴) + 해금 연동(Phase 5).

### Phase 5 🟦 — 메타 확장 + 해금 + 도전과제 + 수익화 자리
- 메타 스탯 확장: 부활 횟수·행운·재생 등 `MetaUpgradeData`로.
- 해금 시스템: 캐릭터/무기/테마 = 재화 + 도전과제 게이팅.
- 도전과제: 추적기 + 해금 훅("리볼버 15분 생존", "누적 10만 처치" 등) = `AchievementData`.
- 수익화 자리: 부활/**2배 보상** 광고 접점, 코스메틱 **스킨 슬롯**(SDK 연동은 나중).

### Phase 6 🟩 — 테마 3종 (오브젝트/기믹/보스) *(최대 콘텐츠)*
- `ThemeData` = 비주얼셋 + 오브젝트셋 + 기믹셋 + 좀비조합 + 테마보스.
- 테마1 교외(입문): 차량경보(유인)·나무울타리·주유소 가스통·스프링클러 감속. 보스=변이 거대 개.
- 테마2 도심(중급): 지하철 스폰·낙석·감전 웅덩이·가스연쇄·순간암전. 보스=버스 견인 변이체/자폭소환형.
- 테마3 연구소(최종): 독가스/방사능 웅덩이·배양탱크 부화·알람 트리거·포자·천장 산성액.
  보스=다단계 변이(체력 구간별 패턴), 무한 구간 반복 강화.
- 테마 = **난이도순 해금 맵**. 기믹은 각각 소기능이라 서브단계로 분할.

### Phase 7 🟦 — 성능 상한 + 최종 폴리시
- **이펙트 동시표시 상한:** 폭발/넉백/화면흔들림/데미지숫자 동시 개수 캡(프레임 방어).
- 수백 마리 스트레스 테스트, 풀 예열 튜닝.
- 밸런스 패스(무기 역할 비겹침·30분 곡선), 사운드/피드백 마감.

---

## 3. 의존성 & 권장 순서

```
Phase 0 (데이터 기반)  ← 필수 선행
   ├─ Phase 1 (시간 난이도)      ← 독립, 조기 착수 권장
   ├─ Phase 2 (무기 12종)        ← 데이터 기반 위에서 확장
   │     └─ Phase 3 (패시브/진화)  ← 무기 위에 얹힘
   │            └─ Phase 4 (캐릭터) ← 무기/패시브/진화 필요
   ├─ Phase 5 (메타/해금/과제)    ← 캐릭터/무기 존재 시 의미
   └─ Phase 6 (테마)             ← 최대 볼륨, 병렬 가능
Phase 7 (성능/폴리시)  ← 상시 + 마지막 마감
```

권장 착수: **Phase 0 → Phase 1**(플레이 감각을 스펙의 "시간=난이도, 30분 클리어"로 먼저 맞춤)
→ 이후 Phase 2/3(무기·진화 볼륨) → Phase 4(캐릭터) → Phase 5(메타/해금) → Phase 6(테마) → Phase 7.

## 4. 규모 & 검증

- 이것은 프로토타입 → **정식 VS류 완성**에 해당하는 대형 작업(수십 PR).
- 각 PR: 헤드리스 Godot 4.3 `--import`(파싱) + `Main.tscn` 실행(런타임) 검증 후 머지.
- 데이터 리소스는 사용자가 직접 수치 조정 가능(스펙 요구).

## 5. 열린 결정 사항 (착수 전 확인 필요)
1. **착수 범위:** 전체를 순차로 갈지, 특정 Phase만 우선할지.
2. **기존 무기 처리:** gun/orb/lightning/garlic/holy를 스펙 12종에 흡수/재매핑 vs 폐기 후 신규.
3. **시간 밸런스:** 30분 클리어 기준의 대략적 난이도 곡선(입문/중급/최종 테마별).
4. **아트:** 신규 무기/오브젝트/테마 비주얼을 절차적 생성으로 갈지, 사용자가 에셋 제공할지.

---

## 6. 진행 로그 (완료 / 남은 작업)

> 착수 순서대로 실제 구현 상태를 기록. 다음 세션이 이어받을 수 있도록 **남은 작업**을 함께 명시.

### ✅ Phase 0 — 데이터 기반(Resource) 전환 *(완료)*
- **정의된 Resource 클래스:** `ZombieData`/`ZombieDB`, `MetaUpgradeData`/`MetaUpgradeDB`, `DifficultyData`.
- **생성기(일회성 SceneTree 툴):** `tools/gen_zombie_data.gd`, `gen_meta_data.gd`, `gen_difficulty_data.gd`
  → `godot --headless --path . --script res://tools/gen_*.gd` 로 `.tres` 산출.
- **데이터 에셋:** `data/zombies.tres`(+`data/zombies/*` 11종), `data/meta_upgrades.tres`(+`data/meta/*` 5종),
  `data/difficulty.tres`.
- **로더:** `GameData`(autoload) — `zombie_list`/`meta_upgrades`/`difficulty` 제공. 웹 호환 위해 폴더 스캔 대신
  단일 인덱스 리소스를 `load()`.
- **배선:** `ZombieSpawner.ZOMBIE_TYPES`(← `GameData.zombie_list`), `MetaManager`(← `GameData.meta_upgrades`).
  값은 이전 하드코딩과 **동일**(회귀 없음, 헤드리스 검증).
- **남은 데이터 이관(후속 Phase에서):** 무기(`ItemDB` 카탈로그)→`WeaponData`, 패시브→`PassiveData`,
  진화→`EvolutionData`, 캐릭터→`CharacterData`, 테마→`ThemeData`, 보스 스탯→`BossData`(현재 `ZombieSpawner.BOSS_TYPES`
  딕셔너리 하드코딩), 도전과제→`AchievementData`. **Phase 2에서 `WeaponData`부터 이어감.**

### ✅ Phase 1 — 시간 기반 난이도 디렉터 + 30분 클리어 *(완료)*
- **`DifficultyData`(.tres):** 모든 곡선 수치를 데이터로 노출 — `clear_seconds`(1800), 스폰 간격
  `spawn_interval_base/min/full_at`, 동시수 `max_z_base/cap/full_at`, `hp_per_min`/`speed_per_min`/`speed_cap`,
  `overtime_hp_per_min`(클리어 후 하드모드), 이벤트 주기 `tier/elite/boss_seconds`.
- **`ZombieSpawner` 재작성:** 처치 수 기반 → **경과 시간(`_elapsed`) 기반**.
  - `_tier()`=`_elapsed/tier_seconds`, `_spawn_interval()`/`_max_z()`=시간에 따른 lerp,
    `_hp_mult()`/`_speed_mult()`=분당 선형(+오버타임 추가 체력).
  - 보스: `_next_boss_at`(초) 마다 등장·아키타입 순환, 시간 스케일 강화.
  - 엘리트 팩: `_next_elite_at`(초) 마다 강제 엘리트 스웜(`_trigger_swarm(true)`). 랜덤 스웜은 유지.
  - **30분 생존 = 클리어:** `run_cleared` 1회 emit + `Events.did_clear` 세팅. 승리 아님 → 이후 오버타임 무한 하드모드.
- **`Events`:** `run_progress(elapsed, clear)`/`run_cleared` 시그널 + `did_clear` 상태(+reset).
- **HUD:** 상단 진행바를 **시간 진행바**로 전환(`_on_run_progress`) — 남은 시간 `mm:ss`/`OVERTIME` 표시,
  오버타임엔 보라색. `run_cleared` 시 클리어 배너(웨이브 배너 재사용). 목표 힌트 = "SURVIVE 30:00 → CLEAR".
  로케일 `run_cleared` 추가(en/ko/ja).
- **검증:** 헤드리스 `--import`(파싱 무오류) + `Main.tscn` 런타임(정상) + **타임라인 축소본(clear 8s)**으로
  보스/엘리트/클리어/오버타임 경로 실행 무오류 확인.
- **남은 작업(후속):**
  - 다음 **보스/엘리트까지 남은 시간 예고 UI**(스펙 "다음 이벤트 예고")는 미구현 — 현재는 스웜 임박 배너만 있음.
  - `BOSS_TYPES` 딕셔너리는 아직 코드 하드코딩 → Phase 5 전후로 `BossData`(.tres) 이관 대상.
  - 게임오버/클리어 집계에 `did_clear`를 랭킹/보상에 반영하는 로직은 미배선(향후 Phase 5 메타/과제와 함께).

### 🟡 Phase 2 — 무기 12종 (데이터 + 동작 모듈) *(진행 중)*
**결정(사용자 확인):** ① 로스터 = **기존 5종 흡수·재매핑**(id 매핑 테이블로 세이브 호환) ② 첫 PR = **데이터 기반부터**.

- **[완료] 2-A 카탈로그 데이터 이관(회귀 없음):**
  - Resource: `WeaponData`(id/display/desc/color/max_level/evolved), `PassiveData`, `EvolutionData`(base/passive/into),
    인덱스 `ItemCatalogDB`(weapons/passives/evolutions).
  - `data/item_catalog.tres`(무기 10=일반 5+진화 5, 패시브 6, 진화 5) — 값은 기존 `ItemDB` 하드코딩과 **동일**.
  - 생성기 `tools/gen_item_catalog.gd`. `GameData`가 로드해 `weapon_defs`/`passive_defs`/`evolution_defs` 제공.
  - `ItemDB`는 이제 **어댑터** — `weapons()`/`passives()`/`evolutions()`/`meta()`/`is_weapon()`가 `GameData`에서 읽어
    기존 dict 형태로 제공(다운스트림 `LevelUpPanel`/`HUD` 무변경). `recompute()` 스탯 곡선은 아직 코드(동작 레이어).
  - 검증: `--import` 파싱 무오류, `Main.tscn` 런타임 정상, `item_catalog.tres` 로드/필드값 회귀 확인.
- **[남음] 2-B 스탯 곡선 데이터화:** `recompute()`의 per-무기 레벨→스탯 공식(예: railgun `10+rg*2`)을 `WeaponData`
  필드(8레벨 곡선)로 이관. 지금은 코드에 있음.
- **[진행] 2-C 신규 무기(재매핑 + 확장):** 스펙 12종으로 확장.
  - **[완료] 배치 1 — 직선 발사체 3종(산탄총·기관총·석궁):**
    - **재사용 모듈** `scripts/ProjectileWeapon.gd` — Player 자식으로 붙어 자기 `WeaponData`
      파라미터로 최근접 적 자동 조준·독립 발사. 카탈로그에 `module:"projectile"` 무기를 추가하면
      **코드 수정 없이** Player 가 생성/유지(`_update_projectile_modules`).
    - `WeaponData` 에 발사체 파라미터 필드 추가(fire_interval/pellets/spread/pierce/knockback/
      proj_speed/proj_damage/dmg_per_level/proj_scale). 레벨→데미지·발사속도·탄수·관통은 모듈이 스케일.
    - `Bullet` 에 **관통(pierce)** + 커스텀 넉백 지원(기본값 0 → 기존 무기 동작 불변, 회귀 없음).
    - 산탄총(넓은 확산+강넉백), 기관총(초고연사·저댐), 석궁(관통·고댐) — `data/item_catalog.tres`(무기 13).
    - 검증: `--import` 무오류, 발사체 무기를 임시 지급한 12초 런타임에서 모듈 생성·전투 발사 무오류.
  - **[완료] 배치 2 — 장판/투척 3종(화염방사기·화염병·지뢰):**
    - **공통 베이스** `scripts/WeaponModule.gd`(class_name) — setup/_level/_nearest_zombie/_aim_dir 공유.
      배치 3~4 신규 모듈도 이걸 상속.
    - Player 모듈 관리 일반화 — `_MODULE_CLASSES`(module 문자열→스크립트) 맵 + `_update_weapon_modules`.
      이제 **모듈맵 한 줄 + 카탈로그 항목**만 추가하면 새 무기가 붙는다.
    - `WeaponData` 에 `area_radius`/`area_duration` 추가.
    - 화염방사기: 조준 방향 콘 지속 피해(`Flamethrower`, 투사체 없음).
    - 화염병: 최근접 무리에 투척 → 지속 장판(`Molotov`→월드 노드 `GroundHazard` DoT).
    - 지뢰: 주변 바닥에 설치(`MineLayer`→월드 노드 `LandMine`), 근접/수명에 폭발 + 넉백. 동시 설치 상한.
    - `data/item_catalog.tres`(무기 16). 검증: `--import` 무오류, 3종 임시 지급 14초 런타임에서 콘 틱/
      장판 생성/지뢰 폭발 무오류(use-after-free 없음).
  - **[완료] 배치 3 — 근접 원호 2종(못배트·체인소):** WeaponData 스키마 변경 없이 기존 필드 재사용
    (spread=원호 반각, area_radius=사거리). `MeleeArc`(주기 강타 스윕+강넉백, 원호 1회 타격),
    `Chainsaw`(밀착 짧은 원호·초고연사 그라인더·약넉백, 회전 톱날 연출). 둘 다 `WeaponModule` 상속.
    `data/item_catalog.tres`(무기 18). 검증: `--import` 무오류, 2종 임시 지급 13초 런타임 무오류.
  - **[완료] 배치 4 — 설치물 3종(터렛·드론·테슬라):**
    - 터렛: `Turret` 배치기 → 월드 노드 `TurretUnit`(수명 동안 자동 사격, 동시 설치 상한).
    - 드론: `Drone` 모듈이 편대(레벨로 수 증가)를 공전시키며 각자 최근접 적 자동 사격(별도 노드 없이 모듈이 편대 관리).
    - 테슬라: `Tesla` 연쇄 번개 — 최근접 적 타격 후 근처 적으로 체인(레벨로 연쇄 수 증가), 아크 잔상 연출.
    - `data/item_catalog.tres`(무기 21). 검증: `--import` 무오류, 3종 임시 지급 14초 런타임에서
      터렛 사격·드론 공전 사격·테슬라 연쇄 무오류.
  - **[남음] 기존 흡수·재매핑:** gun/orb/garlic/holy/lightning 을 스펙 이름(리볼버 등)으로 재매핑하고
    기존 id→스펙 id 매핑 테이블로 세이브 호환. (신규 무기들은 신규 id라 세이브 충돌 없음 — 매핑은 이 단계에서.)

### 🟡 Phase 3 — 패시브 10종 + 진화표 12종(상자 게이팅) *(진행 중)*
- **[완료] 3-A — 패시브 10종(데이터 구동 효과):**
  - `PassiveData` 에 `effect`/`per_level` 추가 → `ItemDB.recompute` 가 effect별 per_level×레벨을 합산해
    `upgrade_*` 에 반영(id 하드코딩 제거). 기존 6종은 **id 유지**(진화 짝꿍·세이브 호환), 표시명만 스펙 플레이버로.
  - 신규 4종 + 새 효과 knob: 탄약벨트(multishot)·화약(bullet_damage)·**배터리(area)**·**토끼발(greed)**.
    `Events.upgrade_area`/`upgrade_greed` + `Events.area_mult()`(광역/오라 무기 반경 배수) + greed는
    add_gold/add_xp 에 인게임 골드·경험치 배수로 반영. area_mult 배선: garlic/holy/flamethrower/molotov/
    mine/tesla/turret.
  - 기존 6종은 per_level=1로 **동일 동작 보존**(회귀 없음). `item_catalog.tres`(패시브 10).
  - **알려진 선반영 이슈(비회귀, 별도 수정 대상):** 메타 `vitality`(max_health)·`swiftness`(move_speed)는
    recompute 의 패시브 SET 로 여전히 덮어써짐 — 기존 동작 그대로 보존함. 메타 밸런스 패스(Phase 5)에서 정리.
  - 검증: `--import` 무오류, 신규 패시브+광역 무기 임시 지급 12초 런타임 무오류, 패시브 데이터 필드 확인.
- **[완료] 3-B — 진화표 12종 + 상자 게이팅:**
  - **발동 방식 변경:** 진화는 이제 **레벨업 카드가 아니라 "진화 보물상자" 개봉**으로만. `LevelUpPanel._draw_choices`
    에서 진화 제거, `Events.evolution_offer` 시그널 → 진화 전용 선택 패널(`_evo_mode`).
  - **드롭:** 보스 처치(`boss_died`) + 예약 엘리트 팩(`elite_pack`, 신규 시그널) → `ItemPickupSpawner._drop_evochest`
    가 보라색 진화 상자(`ItemPickup` kind "evochest") 드롭(상시 상한 무관, 보상 보장).
  - **개봉:** 진화 가능 무기(`Events.available_evolutions`: 베이스 만렙 + 짝꿍 패시브 보유 + 미진화)가 있으면
    진화 선택 패널, 없으면 무료 레벨업 + 골드로 보상.
  - **진화 12종(데이터):** 기존 5종(railgun/sawstorm/thunderstorm/sanctuary/crucifix, recompute 오버라이드 유지)
    + 신규 7종 **모듈 진화체**(dragonsbreath/gatling/ballista/inferno/napalm/claymore/stormcoil) — 모듈 무기라
    강화 파라미터만 다른 새 WeaponData, **recompute 오버라이드 불필요**(모듈이 자기 데이터로 동작).
  - `item_catalog.tres`(무기 28=일반16+진화12, 진화규칙 12). 검증: `--import` 무오류, 진화체 임시 지급 +
    축소 타임라인(엘리트/보스 조기 발동) 16초 런타임에서 진화 모듈 동작·상자 드롭 무오류, 진화 짝꿍/진화체 데이터 확인.

### 🟡 Phase 4 — 캐릭터 3종 *(진행 중)*
- **[완료] 4-A — 캐릭터 데이터 + 선택 + 정체성:**
  - `CharacterData`(id/display/desc/color/start_weapon/signature_passive/bonus_*(스탯보정)/trait_key) +
    인덱스 `CharacterDB`, 생성기 `tools/gen_character_data.gd`, `data/character_db.tres`(3종).
    ※ `trait` 는 GDScript 예약어 → 필드명 `trait_key` 사용.
  - `GameData` 가 캐릭터 카탈로그 로드(`characters`/`character(id)`).
  - **`CharacterManager`(신규 autoload)** — 선택 id 를 `user://character.save` 에 보존, `selected()`/`select()`,
    `add_bonuses()`(recompute 말미 += 로 시작 스탯 보정 적용 — 패시브 SET 이후라 정상 반영).
  - `Events.reset()` 가 선택 캐릭터의 **시작 무기 + 시그니처 패시브**를 초기 인벤토리에 주입(기본 gun 위에).
  - **메인메뉴 캐릭터 선택 오버레이**(`_build_character_panel`) — 3종 카드, 선택 강조·보존, 버튼에 현재 캐릭터 표시.
  - 3종: **베테랑**(못배트+방탄조끼, +체력), **사냥꾼**(석궁+조준경, +피해/치명타), **엔지니어**(터렛+배터리, +효과범위).
  - 검증: `--import` 무오류, `character_db.tres`(3종) 생성, 런 시작 프로브로 시작 무기/패시브/스탯보정 반영 확인
    (베테랑 → weapons{gun,spikedbat}·passives{armor}·maxhp+4), MainMenu 씬 빌드 무오류.
- **[완료] 4-B — 조건부 고유 트레잇(`trait_key` 런타임 로직):**
  - **중앙화 훅:** `Events.trait_damage_mult`(나가는 피해 배수)를 **수신측**(Zombie/Boss.take_damage)에서 일괄 곱함
    → 모든 무기 소스에 한 곳으로 반영. `Events.crit_chance()`(치명타 = 조준경 + `trait_crit_bonus`)로 발사 코드 공유
    (Player/ProjectileWeapon). Player 가 매 프레임 `_update_trait_mods` 로 상태 갱신.
  - **베테랑:** 체력 절반 이하부터 나가는 피해 상승(빈사 +60%) + 8처치마다 1 회복(근접 지속력).
  - **사냥꾼:** 정지 1.2초에 최대 +30% 치명타(이동 시 리셋).
  - **엔지니어:** `bonus_greed`(재화↑) + `CharacterManager.install_boost()`(터렛/드론/지뢰 설치 수 ×1.5·상한↑).
  - 검증: `--import` 무오류, 트레잇 수식 프로브(베테랑 1/10체력 ×1.48·풀피 ×1.0, 사냥꾼 정지 crit 0.30), 씬 런타임 무오류.

### 🟡 Phase 5 — 메타 확장 + 해금 + 도전과제 *(진행 중)*
- **[완료] 5-A — 메타 영구 강화 확장 + recompute 순서 정정:**
  - 신규 메타 5종(데이터): 행운(crit)·재생(regen)·아드레날린(atk_speed)·리치(area)·**세컨드 윈드(revive, 런당 무료 부활)**.
    `MetaManager.add_bonuses` 를 crit/regen/atk_speed/area 까지 확장, `revive_count()` + `Events.revives_left`.
  - **순서 버그 정정:** `MetaManager.add_bonuses()` 를 recompute 중간→**말미(패시브 SET 이후)**로 이동.
    이로써 그동안 패시브 SET 에 덮여 실효 없던 메타 **체력(vitality)·이속(swift)** 이 정상 반영. swift `per` 30→1 정정
    (Player 가 `move_speed=base+30*upgrade_speed` 로 반영하므로 레벨당 +30 이속).
  - **무료 부활:** 사망 시 `Events.revives_left>0` 이면 광고 없이 `Player._free_revive`(체력 회복 + iframe).
  - 검증: `--import` 무오류, 메타 레벨 강제 프로브(vitality3·swift2·luck2·revive1·power2 → maxhp+7·speed+3·crit+2·dmg+2·revives1),
    무료 부활 프로브(사망 대신 회복·부활 1 소비) 통과, 씬 런타임 무오류.
- **[완료] 5-B — 도전과제:**
  - `AchievementData`(id/display/desc/metric/threshold/reward_gold) + 인덱스 `AchievementDB`, 생성기,
    `data/achievements.tres`(10종: 누적 처치 100/1k/10k, 보스 5/25, 생존 5/15/30분, 레벨 20/40).
  - **`AchievementManager`(신규 autoload)** — Events 시그널(zombie_killed/boss_died/elapsed_changed/level_up)로
    지표 갱신(누적 total_kills·boss_kills / 최고 best_time·best_level), 임계 도달 시 해금 → `MetaManager.reward_gold`
    보상 + `achievement_unlocked` 알림. 진행/해금을 `user://achievements.save` 에 보존(해금 즉시 저장, 그 외 사망 시 플러시).
  - **HUD 토스트**(달성 시 화면 상단 🏆 알림) + **메인메뉴 도전과제 목록 오버레이**(진행도/✓ 표시).
  - 검증: `--import` 무오류, 추적 프로브(100처치·300초·레벨20 → kills_100/survive_5/level_20 해금, 미달 kills_1k 잠금,
    메타골드 +230=50+80+100), MainMenu 오버레이 빌드 무오류.
- **[완료] 5-C — 캐릭터 해금(재화 + 도전과제 게이팅):**
  - `CharacterData` 에 `unlock_cost`(메타 골드 구매)·`unlock_achievement`(도전과제 자동 해금) 추가.
    해금 판정: 게이트 없음(무료) ∨ 짝꿍 도전과제 달성 ∨ 구매함.
  - `CharacterManager` — `is_unlocked`/`try_buy`(메타 골드 차감)/`_bought` 보존, `select()` 는 해금분만 허용,
    `selected()` 는 잠긴 선택을 **해금된 캐릭터로 폴백**(런 안정성). `MetaManager.spend_meta` 추가.
  - **게이트:** 베테랑=무료, 사냥꾼=메타 골드 300 구매, 엔지니어='Boss Hunter'(보스 5처치) 달성.
  - **메뉴 UI:** 캐릭터 오버레이에 🔒/해금 조건/골드 잔액 표시, 잠긴 카드 탭 시 구매 시도(도전과제 게이트는 안내만).
  - 검증: `--import` 무오류, 해금 프로브(vet 무료·hunter 300구매→잔액200·engineer 도전과제 해금·잠긴 선택 폴백), MainMenu 빌드 무오류.
- **[남음] 무기/테마 해금:** 무기는 레벨업 풀 필터로, 테마는 Phase 6 과 함께.
- **[남음] 수익화 자리:** 2배 보상 광고 접점, 코스메틱 스킨 슬롯(SDK 연동은 이후).

### 🟡 Phase 6 — 테마 3종 *(진행 중)*
- **[완료] 6-A — 테마 비주얼셋 + 선택 + 해금:**
  - `ThemeData`(비주얼: bg/tile_a/tile_b/mark + detail_style, 해금: unlock_cost/achievement, 예약: gimmick_key/boss_key)
    + 인덱스 `ArenaThemeDB`(※ `ThemeDB` 는 엔진 싱글톤과 충돌 → `ArenaThemeDB`), 생성기, `data/themes.tres`(3종).
  - **`ThemeManager`(신규 autoload)** — 캐릭터와 동일 해금 규칙(무료/구매/도전과제) + 선택 보존 + 잠긴 선택 폴백.
  - `Ground.gd` 가 랜덤 대신 **선택 테마**를 읽어 바닥/배경을 그린다(데이터 없으면 기존 랜덤 폴백).
  - **메뉴 테마 오버레이**(🔒/해금 조건/골드) — 교외(무료)·도심(400골드)·연구소('Hardened' 15분 생존 달성).
  - 검증: `--import` 무오류, 해금 프로브(교외 무료·도심 400구매 잔액100·연구소 도전과제·기본 선택 suburb),
    Main/ MainMenu 씬 빌드 무오류.
- **[완료] 6-B — 테마 기믹(필드 위험물):**
  - **`GimmickSpawner`**(Main.tscn 노드) — 선택 테마 `gimmick_key` → 해당 위험물을 주기적 스폰(초반 유예·동시 상한).
  - ~~**가스통(교외, `GasCan`)**~~ · ~~**진창(교외, `MudField`)**~~ — **2026-08 삭제.** `#180` 에서
    입문 아레나에 기믹을 두지 않기로 정하면서, 교외 전용이던 이 둘은 어느 테마도 참조하지 않는
    고아 코드가 됐다(HANDOFF P1-3 · P2-7). 되살리지 말 것 — 위 103줄의 교외 기믹 구상
    (가스통·스프링클러 감속)은 그 결정 이전의 원안이다.
  - **낙석(도심, `FallingDebris`)** — 예고 표식 후 착탄, 범위 내 좀비+플레이어 피해(회피 요소).
  - **독가스 웅덩이(연구소, `ToxicPool`)** — 지속 장판 DoT, 안에 든 좀비+플레이어 피해(지역 통제). 플레이어 피해는 `take_hit`.
  - 검증: `--import` 무오류(ToxicPool `abs`→`absf` 추론 이슈 로컬 수정), 3종 동시 스폰 프로브 + 기본 가스통 런타임 무오류(use-after-free 없음).
- **[완료] 6-C — 테마 보스:**
  - `ZombieSpawner.THEME_BOSSES`(boss_key → 보스 정의) + `_theme_boss()` — 선택 테마에 전용 보스가 있으면
    그 아레나의 **모든 보스**로 사용(없으면 기존 아키타입 순환). 기존 행동 아키타입 재사용 → Boss.gd 무변경.
  - 교외=**변이 사냥개**(berserk, 빠른 광폭 근접) / 도심=**더 레커**(bomber, 폭파형 탱커) /
    연구소=**프라임 변이체**(summoner, 소환형). 이름/색/스탯만 테마화.
  - 검증: `--import` 무오류, 축소 타임라인 런타임에서 도심 선택→'THE WRECKER' 보스 스폰·전투 무오류.
  - **참고(후속 폴리시):** 스펙의 "다단계(체력 구간별 패턴)"는 summoner 근사로 대체 — 진짜 페이즈 전환은 Phase 7 폴리시에서.

### 🟡 Phase 7 — 성능 상한 + 최종 폴리시 *(진행 중)*
- **[완료] 7-A — 이펙트 동시표시 상한(프레임 방어):**
  - `FXBurst` 에 **동시 활성 상한**(`MAX_ACTIVE` 48) + **프레임당 신규 상한**(`MAX_PER_FRAME` 20) 추가 —
    대량 난전에서 폭발 FX 가 프레임당 수백 개 생겨 그리기·노드 비용이 폭증하던 것을 방어. 초과분은 조용히 생략
    (피해/게임플레이 무영향). 풀 반납 시 카운터 감소, `clear_pool` 에서 리셋.
  - 데미지 숫자는 이미 프레임당 상한(`MAX_PER_FRAME` 14, 보스/크리티컬은 예외), 화면 흔들림은 `SHAKE_MAX` 상한 존재.
  - 검증: `--import` 무오류, 스트레스 프로브(한 프레임 500회 스폰 → 활성 20 캡, 초과 생략), 씬 런타임 회귀 없음.
- **[완료] 7-B — 다단계 보스(체력 구간 페이즈):**
  - 기존 단일 격노(50%)를 **2단계 전환**으로 확장 — `Boss._phase`(0/1/2), 66%/33% 임계.
    `_cd_mult()`(1.0/0.6/0.45)·`_extra_count()`(0/+2/+4)로 공격 격화를 단계별로. 2단계는 방사 탄막↑(9→13),
    대시 속도↑, 즉시 호위 소환 파동, 핏빛 오라 + 전환 섬광/흔들림. 모든 아키타입 공통 적용(연구소 프라임 변이체 포함).
  - 검증: `--import` 무오류, 지연 프로브(보스 생성 후 피해 → 66% 1단계·33% 2단계 전환·치사 처리) 통과, 씬 런타임 무오류.
- **[완료] 7-C — 정합성 + 피드백 마감:**
  - **데미지 정합성:** 총기 계열 모듈 무기(ProjectileWeapon/Turret/Drone)가 `upgrade_bullet_damage` 를 반영하도록 수정.
    그동안 '화약'(패시브)·'위력'(메타) 강화가 기본 gun 에만 적용되고 산탄총/기관총/석궁/터렛/드론엔 무효였던 정합성 공백을 해소
    (장판·근접·번개는 자체 스케일 유지 — '탄환' 강화 대상 아님). 검증: 기관총 base1 + bullet_damage5 = 6 확인.
  - **피드백:** 보스 페이즈 전환 저음 포효(1/2단계 피치 차등), 도전과제 달성 하이톤 차임 추가.
  - 검증: `--import` 무오류, 데미지 정합성 프로브, 씬 런타임 무오류.
- **[남음/선택] 30분 곡선·무기 미세 밸런스:** 실제 플레이 데이터 기반 반복 튜닝 영역(요청 시 `.tres` 수치 조정으로 지원).

### ▶ 스펙 로드맵(Phase 0~7) 전 구현 완료. 이후는 실제 플레이 기반 반복 밸런싱.
