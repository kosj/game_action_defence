class_name ZombieData
extends Resource
## 좀비 종류 데이터 에셋. 수치는 이 리소스(.tres)에서만 조정한다(하드코딩 금지).
## behavior: chase(추격) | weaver(지그재그) | spitter(원거리) | bomber(자폭).

@export var id: String = ""
@export var speed: float = 65.0
@export var max_health: int = 3
@export var modulate: Color = Color.WHITE   # 사망 FX·투사체·피격 잔광 색(스프라이트는 원본색)
@export var score: int = 10
@export var scale: float = 1.0
@export var contact: int = 1
@export_enum("chase", "weaver", "spitter", "bomber") var behavior: String = "chase"
@export var texture: Texture2D
