class_name SuburbLayout
extends RefCounted

const SIZE := 2560.0
const CLEAR_RADIUS := 780.0
const HOUSE_SIZE := Vector2(280, 220)
const LOTS := [Vector2(-940,-940), Vector2(940,-940), Vector2(-940,940), Vector2(940,940), Vector2(-440,-1080), Vector2(440,-1080), Vector2(-440,1080), Vector2(440,1080)]
const LOCAL_STREET_Y := 520.0
const LOCAL_STREET_WIDTH := 320.0

static func frontage(index: int) -> String:
	var lot: Vector2 = LOTS[index]
	if absf(lot.x)>800:
		return "east" if lot.x<0 else "west"
	return "south" if lot.y<0 else "north"

static func driveway(index: int) -> Rect2:
	var lot: Vector2 = LOTS[index]
	var street_edge := signf(lot.y)*720.0
	if absf(lot.x)>800:
		# A private apron beside the front door, opening onto the local street.
		var x := 660.0 if lot.x>0 else -800.0
		return Rect2(Vector2(x,minf(street_edge,lot.y-60)),Vector2(140,absf(lot.y-street_edge)+60))
	var front_y := lot.y-signf(lot.y)*110.0
	return Rect2(Vector2(lot.x-70,minf(street_edge,front_y)),Vector2(140,absf(front_y-street_edge)))

static func cell(p: Vector2) -> Vector2i:
	return Vector2i(floor((p.x + SIZE * 0.5) / SIZE), floor((p.y + SIZE * 0.5) / SIZE))

static func center(c: Vector2i) -> Vector2:
	return Vector2(c) * SIZE

static func variant(c: Vector2i, seed_value: int) -> int:
	return posmod(c.x * 73856093 ^ c.y * 19349663 ^ seed_value, 4)

static func footprint(c: Vector2i, index: int) -> Rect2:
	return Rect2(center(c) + LOTS[index] - HOUSE_SIZE * 0.5, HOUSE_SIZE)

static func inside(p: Vector2, margin: float = 20.0) -> bool:
	var c := cell(p)
	for i in LOTS.size():
		if footprint(c, i).grow(margin).has_point(p):
			return true
	return false

static func safe(p: Vector2, margin: float = 24.0) -> Vector2:
	var c := cell(p)
	for i in LOTS.size():
		var r := footprint(c, i).grow(margin)
		if not r.has_point(p):
			continue
		var edges := [Vector2(r.position.x - 1,p.y), Vector2(r.end.x + 1,p.y), Vector2(p.x,r.position.y - 1), Vector2(p.x,r.end.y + 1)]
		var best: Vector2 = edges[0]
		for e in edges:
			if p.distance_squared_to(e) < p.distance_squared_to(best):
				best = e
		return best
	return p

static func blocks_segment(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var lo := 0.0
	var hi := 1.0
	for axis in 2:
		if absf(d[axis]) < 0.0001:
			if a[axis] < r.position[axis] or a[axis] > r.end[axis]:
				return false
		else:
			var x := (r.position[axis] - a[axis]) / d[axis]
			var y := (r.end[axis] - a[axis]) / d[axis]
			lo = maxf(lo, minf(x,y))
			hi = minf(hi, maxf(x,y))
			if lo > hi:
				return false
	return true
