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
