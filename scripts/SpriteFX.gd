extends Sprite2D
## 텍스처 기반 원샷 FX(머즐 플래시·피격 스파크·폭발·연기). FXBurst 처럼 정적 풀로 재사용하고
## 동시표시/프레임당 상한으로 난전 성능을 보호한다. 호출부는 SpriteFX.spawn(...) 만 쓴다.
## 스케일 팝(빠르게 커졌다) + 페이드아웃 + (옵션) 회전.

static var _pool: Array = []
const MAX_ACTIVE := 40
const MAX_PER_FRAME := 16
static var _active: int = 0
static var _frame: int = -1
static var _spawned: int = 0

var _t: float = 0.0
var _dur: float = 0.3
var _bscale: float = 1.0     # 표시 크기 기준 스케일(size_px / 텍스처폭)
var _spin: float = 0.0
var _flag: bool = false


## parent 에 붙여 pos 에서 재생. size_px=표시 폭(px), col=틴트(글로우 텍스처를 물들임).
static func spawn(parent: Node, pos: Vector2, tex: Texture2D, size_px: float, dur: float,
		col: Color = Color(1, 1, 1), ang: float = 0.0, spin: float = 0.0) -> void:
	if tex == null:
		return
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_spawned = 0
	if _active >= MAX_ACTIVE or _spawned >= MAX_PER_FRAME:
		return
	_spawned += 1
	_active += 1
	var fx: Sprite2D = _pool.pop_back() if _pool.size() > 0 else (load("res://scripts/SpriteFX.gd") as GDScript).new()
	fx.texture = tex
	fx.centered = true
	fx.z_index = 3
	fx.modulate = col
	fx.rotation = ang
	fx._dur = dur
	fx._bscale = size_px / float(maxi(1, int(tex.get_size().x)))
	fx.scale = Vector2(fx._bscale * 0.5, fx._bscale * 0.5)
	fx._spin = spin
	fx._t = 0.0
	fx._flag = true
	fx.visible = true
	if fx.get_parent() != parent:
		if fx.get_parent() != null:
			fx.get_parent().remove_child(fx)
		parent.add_child(fx)
	fx.global_position = pos


func _process(delta: float) -> void:
	if not _flag:
		return
	_t += delta
	var p := _t / _dur
	if p >= 1.0:
		_recycle()
		return
	rotation += _spin * delta
	var s := _bscale * (0.5 + 0.7 * minf(p * 2.5, 1.0))   # 빠르게 커졌다 유지
	scale = Vector2(s, s)
	modulate.a = 1.0 - p * p                               # 이징 페이드아웃


func _recycle() -> void:
	_flag = false
	visible = false
	_active -= 1
	_pool.append(self)
