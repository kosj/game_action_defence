class_name DifficultyData
extends Resource
## 난이도 곡선 데이터. "경과 시간"이 난이도를 구동한다(스펙). 모든 수치는 이 .tres 에서 조정.
## t = 런 경과 시간(초).

@export var clear_seconds: float = 1800.0        # 30분 생존 = 클리어

# 스폰 간격(초): base → min 으로 시간에 따라 감소(빨라짐)
@export var spawn_interval_base: float = 0.85
@export var spawn_interval_min: float = 0.16
@export var spawn_interval_full_at: float = 1500.0   # 이 시각에 min 도달

# 동시 출현 상한: base → cap
@export var max_z_base: int = 40
@export var max_z_cap: int = 175
@export var max_z_full_at: float = 1200.0

# 좀비 체력/이속 배수(분당 선형)
@export var hp_per_min: float = 0.18
@export var speed_per_min: float = 0.02
@export var speed_cap: float = 1.6

# 클리어(30분) 이후 무한 하드모드 — 분당 추가 체력 배수
@export var overtime_hp_per_min: float = 0.5

# 이벤트 주기(초)
@export var tier_seconds: float = 60.0           # 1분마다 좀비 조합 티어 +1
@export var elite_seconds: float = 300.0         # 5분마다 엘리트 팩
@export var boss_seconds: float = 600.0          # 10분마다 보스
