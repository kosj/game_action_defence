# DeadLine — 구현 마스터 플랜 (스펙 대비 갭 & 단계별 계획)

> 목적: 첨부 스펙(핵심 루프 / 캐릭터 3종 / 성장 3레이어 / 무기·진화 / 테마 3종 / 기술요구)을
> 현재 코드베이스와 대조해, **이미 된 것은 제외**하고 남은 작업을 단계로 나눈 계획.

---

## 0. 현재 상태 요약 (스펙 항목별)

| 스펙 항목 | 상태 | 메모 |
|---|---|---|
| 좀비 처치 → 경험치 젬 | ✅ 완료 | `Gold.gd` = XP 젬, 골드는 보물상자 |
| 레벨업 → 4중 1택 | ✅ 완료 | `LevelUpPanel.gd` |
| 빌드 완성 + 진화 | 🟡 부분 | `ItemDB.gd` 진화 5종. 로스터/발동조건이 스펙과 다름 |
| **난이도 = 경과 시간** | ✅ 완료 | **Phase 1** — `DifficultyData`(.tres) + `ZombieSpawner` 시간 구동 |
| 30분 생존 = 클리어 + 이후 무한 | ✅ 완료 | **Phase 1** — `clear_seconds` 도달 시 `run_cleared`, 이후 오버타임 하드모드 |
| **캐릭터 3종** | ❌ 없음 | 단일 캐릭터 |
| A. 인게임 공통 스탯 | 🟡 부분 | 핵심 스탯 존재(`Events.upgrade_*`). 관통/행운/투사체수 일부 없음 |
| A. 무기 12종 | ✅ 완료 | 스펙 12 동작 계열 전부 구현(배치1~4). 산탄총·기관총·석궁·화염방사기·화염병·지뢰·못배트·체인소·**터렛·드론·테슬라** + 기존 gun·orb·lightning·garlic·holy. 남은 건 스펙 이름 재매핑(gun→리볼버 등, "기존 흡수" 단계) |
| A. 패시브 10종 | ✅ 완료 | **Phase 3-A** — 데이터 구동 효과(PassiveData.effect/per_level). 방탄조끼·운동화·에너지드링크·조준경·자석·응급키트 + 신규 탄약벨트·화약·배터리·토끼발 |
| B. 캐릭터 차별화 데이터 | ❌ 없음 | |
| C. 메타 영구 강화 | 🟡 부분 | `MetaManager` 5종. 부활·행운·재생 등 추가 필요 |
| C. 해금(캐릭터/무기/테마) | ❌ 없음 | |
| C. 도전과제 | ❌ 없음 | |
| 무기 진화표(12종, 보물상자 발동) | 🟡 부분 | 진화 메커니즘 O, 상자-게이팅 X, 로스터 다름 |
| **테마 3종(오브젝트/기믹/보스)** | ❌ 없음 | 단일 아레나 |
| 난이도 뼈대(1분/5분/10분/30분) | ✅ 완료 | **Phase 1** — `tier_seconds`60·`elite_seconds`300·`boss_seconds`600·`clear_seconds`1800 |
| 세이브(로컬) | ✅ 완료 | `SaveManager`·`MetaManager`·`RankingManager` |
| 수익화 훅(부활/2배/스킨) | 🟡 부분 | `AdManager` 부활 훅 O. 2배 보상·스킨 자리 X |
| 오브젝트 풀링 | ✅ 완료 | `Pool.gd` |
| **이펙트 동시표시 상한** | 🟡 부분 | 사운드 스로틀·FX 풀 O. 폭발/넉백/흔들림 동시 상한 X |
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
- **[남음] 3-B — 진화표 12종 + 상자 게이팅:** 진화 규칙을 "레벨업 카드"에서 **엘리트/보스 드롭 보물상자
  개봉 시 진화 선택"으로 변경, 진화 12종 데이터 + 과장 효과(역할 비겹침). 신규 무기(산탄총~테슬라)의
  진화 짝꿍/진화체 정의 포함.

### ▶ 다음: Phase 3-B(진화표 12종 + 상자 게이팅), 이후 Phase 4(캐릭터 3종)
