extends Node2D
## 성수(무기): 주기적으로 플레이어 주변 무작위 지점에 성수병을 던진다. 병은 포물선을 그리며
## 날아가 바닥에 떨어지고, 깨지면서 유리 파편이 튀고 성광 웅덩이가 퍼져 광역 피해를 준다.
## 레벨(upgrade_holy)로 동시 투척 수·피해가 커진다.
## 연출은 전용 셀프 드로우 — 공용 FXBurst 풀은 난전 중 동시표시 상한(48)에 걸려 성수
## 착탄이 조용히 생략되는 일이 있었다(사운드만 나고 아무것도 안 보이는 원인). 여기서는
## 비행 → 파쇄 → 확산 → 잔류를 직접 그려 항상 보이게 한다.

const INTERVAL := 3.4       # 투척 주기(초)
const ZONE_RADIUS := 74.0   # 착탄 광역 반경
const CAST_MIN := 40.0
const CAST_MAX := 230.0     # 플레이어로부터 착탄 거리 범위
const ZONE_LIFE := 1.35     # 웅덩이 연출 지속(초) — 피해는 착탄 순간 1회(기존 밸런스 유지)
const THROW_TIME := 0.40    # 병이 날아가는 시간(초)
const THROW_ARC := 86.0     # 포물선 최고점 높이(px)
const SPREAD_TIME := 0.20   # 착탄 후 웅덩이가 최대 반경까지 퍼지는 시간
const SHARD_LIFE := 0.5     # 유리 파편 비산 지속
const SHARDS := 9           # 파편 수

const _GLASS := Color(0.72, 0.93, 1.0)   # 병 유리색
const _LIQUID := Color(0.45, 0.80, 1.0)  # 성수 색

var _t: float = INTERVAL - 0.8   # 획득 직후 빠르게 첫 투척
## 비행 중인 병: { from, to, age, dmg, r, seed, spin, lead(첫 병만 사운드) }
var _bottles: Array = []
## 착탄 후 웅덩이: { pos, age, r, seed }
var _zones: Array = []
## 파쇄 파편: { pos, age, seed }
var _shards: Array = []


func _ready() -> void:
	z_index = 1   # 유닛 발밑 이펙트지만 바닥 타일에 묻히지 않게


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= INTERVAL:
		_t = 0.0
		_cast()
	# 비행 중인 병 진행 — 도착하면 파쇄(피해·웅덩이·파편 생성)
	# 만료 항목은 역방향 인덱스 + remove_at 으로 제자리에서 걷어낸다. filter() + 인라인 람다는
	# 호출마다 새 Array 와 새 Callable 을 만들어, 효과가 살아있는 동안 매 물리 프레임 할당이
	# 발생했다(파편은 착탄 1회에 9개씩 쌓여 배열이 길다).
	if not _bottles.is_empty():
		var landed: Array = []
		for i in range(_bottles.size() - 1, -1, -1):
			var b: Dictionary = _bottles[i]
			b["age"] += delta
			if b["age"] >= THROW_TIME:
				landed.append(b)
				_bottles.remove_at(i)
		for b in landed:
			_shatter(b)   # 웅덩이·파편을 새로 추가한다 — 아래 나이 누적에 함께 포함된다(기존과 동일)
	for i in range(_zones.size() - 1, -1, -1):
		_zones[i]["age"] += delta
		if _zones[i]["age"] >= ZONE_LIFE:
			_zones.remove_at(i)
	for i in range(_shards.size() - 1, -1, -1):
		_shards[i]["age"] += delta
		if _shards[i]["age"] >= SHARD_LIFE:
			_shards.remove_at(i)
	if not (_bottles.is_empty() and _zones.is_empty() and _shards.is_empty()):
		queue_redraw()


## 투척 — 병을 목표 지점으로 날려 보낸다(피해는 착탄 시점에 적용).
func _cast() -> void:
	var lv := maxi(1, Events.upgrade_holy)
	var count := 1 + int(lv / 2)      # 레벨이 오르면 동시에 여러 곳에 투척
	var dmg := 2 + int(lv / 2)
	var zone_r := ZONE_RADIUS * Events.area_mult()   # 패시브 '배터리' 반경 보정
	for i in range(count):
		var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(CAST_MIN, CAST_MAX)
		_bottles.append({
			"from": global_position, "to": pos, "age": 0.0,
			"dmg": dmg, "r": zone_r, "seed": randf() * TAU,
			"spin": randf_range(-1.0, 1.0),
			"lead": i == 0,   # 동시 투척이어도 파쇄음은 한 번만
		})
	queue_redraw()


## 파쇄 — 병이 바닥에 닿는 순간. 유리 파편이 튀고 웅덩이가 퍼지며 광역 피해가 들어간다.
func _shatter(b: Dictionary) -> void:
	var pos: Vector2 = b["to"]
	var r: float = b["r"]
	if b["lead"]:
		SoundManager.play("holy_splash", 0.1, 1.0)   # 유리 깨지는 소리는 착탄 순간에
	_zones.append({"pos": pos, "age": 0.0, "r": r, "seed": b["seed"]})
	for i in range(SHARDS):
		_shards.append({"pos": pos, "age": 0.0, "seed": b["seed"] + float(i) * 1.37})
	var r_sq := r * r
	for z in Events.live_zombies():
		if is_instance_valid(z) and z.is_in_group("zombies") \
				and pos.distance_squared_to(z.global_position) < r_sq:
			z.take_damage(b["dmg"])
	queue_redraw()


func _draw() -> void:
	_draw_zones()
	_draw_shards()
	_draw_bottles()   # 병은 웅덩이 위로


## 성광 웅덩이 — 착탄 직후 빠르게 퍼진 뒤(SPREAD_TIME) 은은히 빛나며 사라진다.
func _draw_zones() -> void:
	for zn in _zones:
		var p: Vector2 = to_local(zn["pos"])
		var t: float = zn["age"] / ZONE_LIFE
		var fade := 1.0 - t
		# 확산: 0 → 최대 반경까지 감속 곡선으로 퍼진다(깨진 병에서 물이 번지는 느낌).
		var grow := clampf(zn["age"] / SPREAD_TIME, 0.0, 1.0)
		var r: float = zn["r"] * (1.0 - pow(1.0 - grow, 3.0))
		if r < 1.0:
			continue
		# ── 피해 영역(웅덩이): 채움 + 성스러운 하늘빛 테두리 ─────────────────
		draw_circle(p, r, Color(0.45, 0.75, 1.0, 0.20 * fade))
		draw_circle(p, r * 0.55, Color(0.75, 0.92, 1.0, 0.13 * fade))
		draw_arc(p, r, 0.0, TAU, 40, Color(0.65, 0.90, 1.0, 0.85 * fade), 3.0, true)
		draw_arc(p, r * (0.80 + 0.06 * sin(zn["age"] * 9.0)), 0.0, TAU, 32,
				Color(0.9, 0.97, 1.0, 0.35 * fade), 1.6, true)
		# ── 확산 충격파 + 튀는 물방울(초반) ──────────────────────────────
		if grow < 1.0:
			draw_arc(p, r * 1.12, 0.0, TAU, 30,
					Color(1.0, 1.0, 1.0, (1.0 - grow) * 0.9), 3.5, true)
		if t < 0.3:
			var st: float = t / 0.3
			for i in range(8):
				var a: float = zn["seed"] + TAU * float(i) / 8.0
				var dp: Vector2 = p + Vector2.from_angle(a) * zn["r"] * (0.2 + 0.75 * st)
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


## 유리 파편 — 착탄점에서 사방으로 튀어 나가며 회전·감속하다 사라진다.
func _draw_shards() -> void:
	for sh in _shards:
		var t: float = sh["age"] / SHARD_LIFE
		var seed: float = sh["seed"]
		var a: float = seed
		var dist: float = (26.0 + 42.0 * fmod(seed, 1.0)) * (1.0 - pow(1.0 - t, 2.0))
		var p: Vector2 = to_local(sh["pos"]) + Vector2.from_angle(a) * dist
		p.y -= sin(minf(t, 1.0) * PI) * 16.0   # 튀어 올랐다 떨어지는 포물선
		var spin := a + t * 9.0
		var size: float = 4.5 * (1.0 - t * 0.45)
		var col := Color(_GLASS.r, _GLASS.g, _GLASS.b, (1.0 - t) * 0.95)
		# 얇은 삼각 파편(유리 조각) — 회전하며 반짝인다.
		var p1 := p + Vector2.from_angle(spin) * size
		var p2 := p + Vector2.from_angle(spin + 2.3) * size * 0.7
		var p3 := p + Vector2.from_angle(spin - 2.3) * size * 0.7
		draw_colored_polygon(PackedVector2Array([p1, p2, p3]), col)
		draw_line(p1, p2, Color(1, 1, 1, (1.0 - t) * 0.8), 1.0, true)


## 비행 중인 성수병 — 포물선을 그리며 회전하고, 뒤로 성수 방울을 흘린다.
func _draw_bottles() -> void:
	for b in _bottles:
		var t: float = clampf(b["age"] / THROW_TIME, 0.0, 1.0)
		var from: Vector2 = to_local(b["from"])
		var to: Vector2 = to_local(b["to"])
		var flat: Vector2 = from.lerp(to, t)
		var h: float = sin(t * PI) * THROW_ARC          # 포물선 높이
		var p: Vector2 = flat - Vector2(0.0, h)
		# 착탄 지점 표식 — 어디에 떨어질지 미리 보이게(가독성).
		var mark := Color(0.6, 0.9, 1.0, 0.30 + 0.25 * t)
		draw_arc(to, b["r"] * (0.28 + 0.10 * sin(b["age"] * 12.0)), 0.0, TAU, 24, mark, 2.0, true)
		# 흘리는 성수 방울(궤적)
		for i in range(3):
			var tt: float = maxf(0.0, t - 0.06 * float(i + 1))
			var dp: Vector2 = from.lerp(to, tt) - Vector2(0.0, sin(tt * PI) * THROW_ARC)
			draw_circle(dp, 2.2 - 0.5 * float(i), Color(_LIQUID.r, _LIQUID.g, _LIQUID.b, 0.45 - 0.12 * float(i)))
		# 병 — 회전하는 몸통 + 목 + 코르크. 굵은 외곽선 카툰 톤에 맞춘 단순 실루엣.
		var rot: float = b["seed"] + b["spin"] * t * 10.0
		var up := Vector2.from_angle(rot - PI * 0.5)
		var right := Vector2.from_angle(rot)
		var body_h := 9.0
		var body_w := 4.6
		var quad := PackedVector2Array([
			p - right * body_w - up * body_h * 0.4,
			p + right * body_w - up * body_h * 0.4,
			p + right * body_w * 0.85 + up * body_h * 0.6,
			p - right * body_w * 0.85 + up * body_h * 0.6,
		])
		draw_colored_polygon(quad, Color(_LIQUID.r, _LIQUID.g, _LIQUID.b, 0.95))
		draw_polyline(PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]),
				Color(0.13, 0.17, 0.22, 0.95), 1.6, true)
		# 병목 + 코르크
		var neck0: Vector2 = p + up * body_h * 0.6
		var neck1: Vector2 = p + up * body_h * 1.05
		draw_line(neck0, neck1, Color(_GLASS.r, _GLASS.g, _GLASS.b, 0.95), 3.4, true)
		draw_circle(neck1, 2.4, Color(0.85, 0.65, 0.35, 1.0))
		# 유리 하이라이트
		draw_line(p - right * body_w * 0.45 - up * body_h * 0.2,
				p - right * body_w * 0.45 + up * body_h * 0.4,
				Color(1, 1, 1, 0.75), 1.4, true)
