extends Node2D
## 성수(무기): 주기적으로 플레이어 주변 무작위 지점에 광역 피해 구역을 떨어뜨린다.
## 레벨(upgrade_holy)로 동시 투척 수·피해가 커진다.
## 연출은 전용 셀프 드로우 — 공용 FXBurst 풀은 난전 중 동시표시 상한(48)에 걸려 성수
## 착탄이 조용히 생략되는 일이 있었다(사운드만 나고 아무것도 안 보이는 원인). 여기서는
## 착탄 스플래시 + 성광 웅덩이(피해 영역)를 직접 그려 항상 보이게 한다.

const INTERVAL := 3.4       # 투척 주기(초)
const ZONE_RADIUS := 74.0   # 착탄 광역 반경
const CAST_MIN := 40.0
const CAST_MAX := 230.0     # 플레이어로부터 착탄 거리 범위
const ZONE_LIFE := 1.35     # 웅덩이 연출 지속(초) — 피해는 착탄 순간 1회(기존 밸런스 유지)

var _t: float = INTERVAL - 0.8   # 획득 직후 빠르게 첫 투척
var _zones: Array = []           # [{ "pos": Vector2, "age": float, "r": float, "seed": float }]


func _ready() -> void:
	z_index = 1   # 유닛 발밑 이펙트지만 바닥 타일에 묻히지 않게


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= INTERVAL:
		_t = 0.0
		_cast()
	if _zones.is_empty():
		return
	for zn in _zones:
		zn["age"] += delta
	_zones = _zones.filter(func(zn): return zn["age"] < ZONE_LIFE)
	queue_redraw()


func _cast() -> void:
	var lv := maxi(1, Events.upgrade_holy)
	var count := 1 + int(lv / 2)      # 레벨이 오르면 동시에 여러 곳에 투척
	var dmg := 2 + int(lv / 2)
	var zone_r := ZONE_RADIUS * Events.area_mult()   # 패시브 '배터리' 반경 보정
	var r_sq := zone_r * zone_r
	SoundManager.play("holy_splash", 0.1, 1.0)   # 투척 1회당 한 번(동시 투척이어도 겹치지 않게)
	for i in range(count):
		var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(CAST_MIN, CAST_MAX)
		_zones.append({"pos": pos, "age": 0.0, "r": zone_r, "seed": randf() * TAU})
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and pos.distance_squared_to(z.global_position) < r_sq:
				z.take_damage(dmg)
	queue_redraw()


## 성광 웅덩이 — 착탄 스플래시(물방울 튐 + 밝은 링) 후 피해 반경이 은은히 빛나며 사라진다.
func _draw() -> void:
	for zn in _zones:
		var p: Vector2 = to_local(zn["pos"])
		var r: float = zn["r"]
		var t: float = zn["age"] / ZONE_LIFE
		var fade := 1.0 - t
		# ── 피해 영역(웅덩이): 채움 + 성스러운 하늘빛 테두리 ─────────────────
		draw_circle(p, r, Color(0.45, 0.75, 1.0, 0.20 * fade))
		draw_circle(p, r * 0.55, Color(0.75, 0.92, 1.0, 0.13 * fade))
		draw_arc(p, r, 0.0, TAU, 40, Color(0.65, 0.90, 1.0, 0.85 * fade), 3.0, true)
		draw_arc(p, r * (0.80 + 0.06 * sin(zn["age"] * 9.0)), 0.0, TAU, 32,
				Color(0.9, 0.97, 1.0, 0.35 * fade), 1.6, true)
		# ── 착탄 스플래시(초반 0.3초): 확산 링 + 튀는 물방울 ────────────────
		if t < 0.3:
			var st: float = t / 0.3
			draw_arc(p, r * (0.25 + 0.85 * st), 0.0, TAU, 30,
					Color(1.0, 1.0, 1.0, (1.0 - st) * 0.9), 3.5, true)
			for i in range(8):
				var a: float = zn["seed"] + TAU * float(i) / 8.0
				var dp: Vector2 = p + Vector2.from_angle(a) * r * (0.2 + 0.75 * st)
				dp.y -= sin(st * PI) * 14.0   # 포물선으로 튀는 물방울
				draw_circle(dp, 3.0 * (1.0 - st * 0.6), Color(0.8, 0.95, 1.0, (1.0 - st)))
		# ── 성광 십자 반짝임: 웅덩이 위로 떠오르며 사라진다 ────────────────
		for i in range(4):
			var ca: float = zn["seed"] + TAU * float(i) / 4.0 + zn["age"] * 1.2
			var cp: Vector2 = p + Vector2.from_angle(ca) * r * 0.5
			cp.y -= t * 26.0   # 상승
			var cs: float = (4.5 + 1.5 * sin(zn["age"] * 7.0 + float(i))) * fade
			var cc := Color(1.0, 1.0, 0.9, 0.9 * fade)
			draw_line(cp + Vector2(-cs, 0), cp + Vector2(cs, 0), cc, 1.8, true)
			draw_line(cp + Vector2(0, -cs), cp + Vector2(0, cs), cc, 1.8, true)
