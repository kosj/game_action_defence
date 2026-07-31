class_name MetaUpgradeData
extends Resource
## 메타(런 간 영구) 강화 데이터. 비용/효과/최대레벨을 이 리소스(.tres)에서 조정한다.
## cost(level) = base_cost * cost_mul^level.
## effect_kind = 이 강화가 건드리는 스탯. effect_per_level = 레벨당 효과량.
##   가산형(add): bullet_damage, max_health, move_speed  (upgrade_* 에 더함)
##   배수형(mult): gold_mult, xp_mult                     (1 + per_level*level)

@export var id: String = ""
@export var name: String = ""
@export var desc: String = ""
@export var max_level: int = 8
@export var base_cost: int = 100
@export var cost_mul: float = 1.6
@export_enum("bullet_damage", "max_health", "move_speed", "gold_mult", "xp_mult") var effect_kind: String = "bullet_damage"
@export var effect_per_level: float = 1.0
