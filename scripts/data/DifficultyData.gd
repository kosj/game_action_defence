class_name DifficultyData
extends Resource
## 난이도 곡선 데이터. "경과 시간"이 난이도를 구동한다(스펙). 모든 수치는 이 .tres 에서 조정.
## t = 런 경과 시간(초).

@export var clear_seconds: float = 1200.0        # 20분 생존 = 클리어

# 스폰 간격(초): base → min 으로 시간에 따라 감소(빨라짐)
@export var spawn_interval_base: float = 0.85
@export var spawn_interval_min: float = 0.1
@export var spawn_interval_full_at: float = 1000.0   # 16분 40초에 min 도달

# 동시 출현 상한: base → cap
@export var max_z_base: int = 40
@export var max_z_cap: int = 320
@export var max_z_full_at: float = 1000.0

# 좀비 체력 배수: 선형(분당) + 2차 가속(분²당). 플레이어 파워는 무기·패시브가 곱연산으로 쌓여
# 대략 지수적으로 커지므로, 선형 체력만으로는 후반에 적이 녹아 "갈수록 쉬워진다". 2차 항으로
# 후반 체력을 초반은 거의 그대로 두고 급격히 끌어올려 난이도가 계속 상승하게 한다.
#   mult = 1 + hp_per_min*m + hp_accel_per_min2*m²   (m = 경과 분)
@export var hp_per_min: float = 0.24
@export var hp_accel_per_min2: float = 0.0945
## 후반 전용 체력 가속 (P1-20). 이 시각 이후로 분당 이만큼씩 체력 배수가 더 붙는다.
##
## 30분 곡선을 20분에 같은 비율로 재생하므로 시작 시각과 분당 증가량도 각각 2/3, 1.5배로
## 조정한다. 2차항은 시간 배율의 제곱(2.25배)을 적용해야 같은 진행률에서 같은 값이 된다.
@export var late_hp_start_s: float = 600.0       # 10분
@export var late_hp_per_min: float = 2.25
## 같은 시각부터 붙는 **스폰 감속** — 발사 간격에 분당 이만큼씩 곱해진다(1 + n·계수).
##
## 사람의 후반은 **DPS 제한이 아니라 스폰 제한**이다 — 동시 좀비가 상한보다 훨씬 적으면
## 나오는 족족 죽고 있다는 뜻이다. 성능 보호용 감속은 남기되, 강한 빌드에서도 화면이 비지 않도록
## 값을 낮춰 중후반 유입량을 확보한다.
##
## 왜 `spawn_interval_min` 이나 `max_z_cap` 이 아닌가 — 둘 다 0분부터 효과가 시작돼 **초반 성장을
## 같이 누른다.** 상한을 320→220 으로 내렸더니 실측에서 레벨 28→23, 스폰 하한을 0.1→0.16 으로
## 올렸더니 레벨 26→22 로 눌렸다. 작은 초반 차이가 XP→레벨→화력으로 복리로 커진다.
## 시작 시각이 있는 항이면 10분 이전이 **정확히 0** 이다.
@export var late_spawn_slow_per_min: float = 0.04

@export var speed_per_min: float = 0.045
@export var speed_cap: float = 2.0

# 보스 체력 시간 스케일: 좀비 체력 곡선(_hp_mult)의 세기를 이 비율로 반영해 보스도 후반까지
# 위협적으로 유지한다. 0=시간 무관(회차 스케일만), 1=좀비와 동일 곡선.
@export var boss_curve_scale: float = 0.8

# 클리어(20분) 이후 무한 하드모드 — 분당 추가 체력 배수
@export var overtime_hp_per_min: float = 1.2

# 이벤트 주기(초)
@export var tier_seconds: float = 40.0           # 40초마다 좀비 조합 티어 +1
@export var elite_seconds: float = 200.0         # 3분 20초마다 엘리트 팩
@export var boss_seconds: float = 400.0          # 6분 40초마다 보스
