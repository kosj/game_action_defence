class_name PassiveData
extends Resource
## 패시브 아이템 카탈로그 데이터. 표시 정보 + 성장 상한. 수치는 이 .tres 에서 조정.
## 레벨→스탯 매핑은 ItemDB.recompute 가 처리한다.

@export var id: String = ""
@export var display: String = ""          # 카드/HUD 표시 이름
@export var desc: String = ""             # 카드 설명
@export var color: Color = Color.WHITE    # 카드 테마색
@export var max_level: int = 8            # 최대 강화 레벨
@export var icon: Texture2D               # 레벨업 카드·로드아웃 아이콘(없으면 색상 폴백)

## 효과종류(데이터 구동). ItemDB.recompute 가 effect 별로 per_level×레벨을 합산해 upgrade_* 에 반영.
##   atk_speed / crit / move_speed / max_health / regen / pickup / multishot / bullet_damage / area / greed
@export var effect: String = ""
@export var per_level: float = 1.0        # 레벨당 효과량(정수형 스탯은 합산 후 내림)
