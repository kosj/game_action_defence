class_name DifficultyData
extends Resource
## 난이도 곡선 데이터. "경과 시간"이 난이도를 구동한다(스펙). 모든 수치는 이 .tres 에서 조정.
## t = 런 경과 시간(초).

@export var clear_seconds: float = 1800.0        # 30분 생존 = 클리어

# 스폰 간격(초): base → min 으로 시간에 따라 감소(빨라짐)
@export var spawn_interval_base: float = 0.85
@export var spawn_interval_min: float = 0.1
@export var spawn_interval_full_at: float = 1500.0   # 이 시각에 min 도달

# 동시 출현 상한: base → cap
@export var max_z_base: int = 40
@export var max_z_cap: int = 320
@export var max_z_full_at: float = 1500.0

# 좀비 체력 배수: 선형(분당) + 2차 가속(분²당). 플레이어 파워는 무기·패시브가 곱연산으로 쌓여
# 대략 지수적으로 커지므로, 선형 체력만으로는 후반에 적이 녹아 "갈수록 쉬워진다". 2차 항으로
# 후반 체력을 초반은 거의 그대로 두고 급격히 끌어올려 난이도가 계속 상승하게 한다.
#   mult = 1 + hp_per_min*m + hp_accel_per_min2*m²   (m = 경과 분)
@export var hp_per_min: float = 0.16
@export var hp_accel_per_min2: float = 0.042
## 후반 전용 체력 가속 (P1-20). 이 시각 이후로 분당 이만큼씩 체력 배수가 더 붙는다.
##
## 왜 2차항(`hp_accel_per_min2`)을 올리지 않았나 — 그 항은 **중반에도 그대로 듣는다.**
## 15분 기준으로도 크게 올라가는데, 사람이 실제로 지루하다고 말한 구간은 20분 이후다.
## 시작 시각이 있는 선형 항이면 그 구간만 정확히 집을 수 있다(`overtime_hp_per_min` 과 같은 꼴).
@export var late_hp_start_s: float = 900.0       # 15분
@export var late_hp_per_min: float = 1.5
## 같은 시각부터 붙는 **스폰 감속** — 발사 간격에 분당 이만큼씩 곱해진다(1 + n·계수).
##
## 사람의 후반은 **DPS 제한이 아니라 스폰 제한**이다 — 동시 좀비가 22~45마리인데 상한은 320이라
## 나오는 족족 죽는다. 그래서 분당 처치(초반 110 → 35분대 760)도, 처치마다 터지는 젬·이펙트도
## 전부 **스포너의 출력**이 정한다. 체력만 올려서는 이 수가 줄지 않는다.
##
## 왜 `spawn_interval_min` 이나 `max_z_cap` 이 아닌가 — 둘 다 0분부터 효과가 시작돼 **초반 성장을
## 같이 누른다.** 상한을 320→220 으로 내렸더니 실측에서 레벨 28→23, 스폰 하한을 0.1→0.16 으로
## 올렸더니 레벨 26→22 로 눌렸다. 작은 초반 차이가 XP→레벨→화력으로 복리로 커진다.
## 시작 시각이 있는 항이면 15분 이전이 **정확히 0** 이다.
@export var late_spawn_slow_per_min: float = 0.055

@export var speed_per_min: float = 0.03
@export var speed_cap: float = 2.0

# 보스 체력 시간 스케일: 좀비 체력 곡선(_hp_mult)의 세기를 이 비율로 반영해 보스도 후반까지
# 위협적으로 유지한다. 0=시간 무관(회차 스케일만), 1=좀비와 동일 곡선.
@export var boss_curve_scale: float = 0.8

# 클리어(30분) 이후 무한 하드모드 — 분당 추가 체력 배수
@export var overtime_hp_per_min: float = 0.8

# 이벤트 주기(초)
@export var tier_seconds: float = 60.0           # 1분마다 좀비 조합 티어 +1
@export var elite_seconds: float = 300.0         # 5분마다 엘리트 팩
@export var boss_seconds: float = 600.0          # 10분마다 보스
