class_name BalanceData
extends Resource
## 전투/보상 밸런스 테이블. 시간 기반 난이도 곡선(DifficultyData)과 별개로, 코드에 흩어져
## 있던 밸런스 상수를 한곳에 모은다. 모든 수치는 res://data/balance.tres 에서 편집한다.

@export_group("Player")
@export var contact_cooldown: float = 0.25      # 피격 후 무적(= 좀비 접촉 피해 간격, 초)
@export var regen_interval_lv1: float = 16.0   # 재생 Lv1 회복 간격(초) — Lv n 은 이 값/n
@export var start_invuln: float = 5.0          # 게임 시작 무적(초)

@export_group("Spawn")
@export var spawn_budget_per_frame: int = 12   # 프레임당 좀비 스폰 상한 — 대량 스폰 프리즈/크래시 방지

@export_group("Swarm")
@export var swarm_interval_min: float = 15.0   # 랜덤 스웜 주기(초)
@export var swarm_interval_max: float = 24.0
@export var swarm_base_count: int = 12         # 초반 스웜 규모
@export var swarm_count_per_2min: int = 6      # 2분마다 스웜 규모 증가량
@export var swarm_count_max: int = 84          # 스웜 규모 상한
@export var swarm_ring_threshold: int = 28     # 이 수 이상이면 화면 둘레 링(포위) 스폰
@export var swarm_elite_chance: float = 0.35   # 랜덤 스웜이 엘리트일 확률
@export var swarm_elite_hp_mult: float = 1.7
@export var swarm_elite_scale: float = 1.35
@export var swarm_start_seconds: float = 30.0  # 이 시각 이후부터 랜덤 스웜 발동
@export var swarm_spread: float = 70.0         # 클러스터 스폰 산개 반경
@export var swarm_telegraph: float = 1.0       # 경고 → 등장 지연(초)

@export_group("Boss")
@export var boss_base_hp: int = 90             # 보스 체력 = (base + per_count*(회차-1)) × 배수들
@export var boss_hp_per_count: int = 70
@export var boss_base_speed: float = 104.0     # 보스 이속 = base + per_count×회차
@export var boss_speed_per_count: float = 9.0
@export var boss_escort_base: int = 3          # 호위 좀비 수 = base + 회차
@export var summon_alive_cap: int = 44         # 서머너 소환 시 전장 과밀 상한
@export var boss_contact_bonus: int = 1        # 보스 접촉 피해 = 타입값 + 이 값
@export var boss_bullet_damage: int = 2        # 거너 탄 1발 피해
@export var boss_bomb_damage: int = 3          # 포격 탄착 폭발 피해
@export var boss_slam_damage: int = 3          # 근접형 지면 강타 피해
## 지구전 방지: 보스가 이 시간(초)을 넘겨 생존하면 공격 주기가 점점 빨라진다(상한 boss_rage_max).
@export var boss_rage_seconds: float = 35.0
@export var boss_rage_max: float = 1.9         # 격화 상한(공격 빈도 배수)
@export var boss_summon_ring: float = 300.0    # 호위 소환 위치: 플레이어 주변 이 반경의 링
## 회복 스킬(전 아키타입 공용) — 체력이 boss_heal_trigger 이하로 떨어지면 쿨타임마다 그 자리에
## 멈춰 시전한다. 시전을 끝내면 최대 체력의 boss_heal_ratio 만큼 회복하지만, 시전 중
## boss_heal_break_ratio 만큼 피해를 누적시키면 회복을 끊을 수 있다. 시전 횟수가
## boss_heal_charges 로 제한되므로 총 회복량에 상한이 있다(저 DPS 에서도 전투가 끝난다).
@export var boss_heal_trigger: float = 0.55    # 이 체력 비율 이하에서만 발동
@export var boss_heal_ratio: float = 0.15      # 1회 회복량 = 최대 체력 × 이 값
@export var boss_heal_cooldown: float = 15.0   # 회복 시도 간격(초) — 발동 체력 이하일 때만 흐른다
@export var boss_heal_break_ratio: float = 0.07 # 시전 중 이만큼(최대 체력 비율) 주면 저지
@export var boss_heal_charges: int = 2         # 보스 1마리당 시전 횟수(저지당해도 소모)
## 보스 격리 구역 — 보스전 동안 플레이어를 가두는 원형 경계(BossArena). 월드에 벽이 없고 보스가
## 플레이어보다 항상 느려서 보스전이 "뒤로 걸으며 딜"로 끝나던 것을 막는다. 회차가 오를수록
## 좁아져(= 압박 증가) 체력 말고도 난이도가 오르는 축이 된다.
## 반경 상한은 화면이 정한다: 뷰포트 720×1280(줌 1.0)이라 플레이어 기준 세로 ±640 까지만 보인다.
## 640 을 넘기면 경계가 화면 밖이라 "갇혔다"가 전혀 안 읽힌다(620 으로 처음 넣었다가 겪었다).
## 하한은 보스가 정한다: 보스 유지 거리가 최대 340(바머)이라, 그보다 넉넉히 커야 보스가 경계
## 밖에 자리잡고 근접 무기가 안 닿는 상황이 안 생긴다.
@export var boss_arena_radius: float = 480.0        # 1회차 반경
@export var boss_arena_shrink_per_count: float = 16.0   # 회차마다 좁아지는 양
@export var boss_arena_radius_min: float = 400.0    # 이보다 좁아지지는 않는다(회피 공간 보장)
## 경계 감전. 간격을 Player.take_hit 의 자체 무적(contact_cooldown 0.25초)보다 길게 잡아야 한다 —
## 그대로 두면 초당 4대라, 최대 체력 5인 플레이어가 벽에 스치는 순간 죽는다.
@export var boss_arena_shock_damage: int = 1
@export var boss_arena_shock_interval: float = 0.6

@export_group("Chest")
@export var chest_interval_min: float = 24.0   # 필드 보물상자 스폰 주기(초)
@export var chest_interval_max: float = 40.0
@export var chest_max_active: int = 2          # 동시 미수집 상자 상한
@export var chest_gold_scale_per_min: float = 0.10   # 분당 골드 보상 증가율
@export var chest_w_legendary: float = 2.0     # 등급 가중치(+ 행운 레벨당 보너스)
@export var chest_w_legendary_luck: float = 1.0
@export var chest_w_epic: float = 11.0
@export var chest_w_epic_luck: float = 2.0
@export var chest_w_rare: float = 27.0
@export var chest_w_rare_luck: float = 3.0

@export_group("Gem")
@export var gem_live_cap: int = 140            # 필드 동시 경험치 젬 상한(초과분 자동 흡수)

@export_group("Level up")
## 강화 카드가 하나도 없을 때(보유 아이템 전부 만렙 + 슬롯 만석) 레벨업 1회당 지급하는 골드.
## 지급량 = clamp(base + per_level × 레벨, 0, max). 메타 '탐욕'·패시브 '토끼발' 배수는
## Events.add_gold 가 추가로 곱한다.
## 후반에는 레벨업이 아무 보상 없이 지나가 경험치를 모을 이유가 사라진다 — 그 구간을 메운다.
@export var maxed_level_gold_base: int = 20
@export var maxed_level_gold_per_level: float = 2.0
@export var maxed_level_gold_max: int = 80
