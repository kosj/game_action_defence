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

# 좀비 체력 배수: 선형(분당) + 2차 가속(분²당). 플레이어 파워는 무기·패시브가 곱연산으로 쌓여
# 대략 지수적으로 커지므로, 선형 체력만으로는 후반에 적이 녹아 "갈수록 쉬워진다". 2차 항으로
# 후반 체력을 초반은 거의 그대로 두고 급격히 끌어올려 난이도가 계속 상승하게 한다.
#   mult = 1 + hp_per_min*m + hp_accel_per_min2*m²   (m = 경과 분)
@export var hp_per_min: float = 0.16
@export var hp_accel_per_min2: float = 0.020
@export var speed_per_min: float = 0.025
@export var speed_cap: float = 1.85

# 보스 체력 시간 스케일: 좀비 체력 곡선(_hp_mult)의 세기를 이 비율로 반영해 보스도 후반까지
# 위협적으로 유지한다. 0=시간 무관(회차 스케일만), 1=좀비와 동일 곡선.
@export var boss_curve_scale: float = 0.5

# 클리어(30분) 이후 무한 하드모드 — 분당 추가 체력 배수
@export var overtime_hp_per_min: float = 0.5

# 이벤트 주기(초)
@export var tier_seconds: float = 60.0           # 1분마다 좀비 조합 티어 +1
@export var elite_seconds: float = 300.0         # 5분마다 엘리트 팩
@export var boss_seconds: float = 600.0          # 10분마다 보스
