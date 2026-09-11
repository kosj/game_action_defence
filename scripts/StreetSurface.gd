class_name StreetSurface
extends RefCounted
## Retained, engine-triangulated surfaces share continuous world UVs. Curves are
## visual only; the existing open navigation corridors and solids stay intact.
static func offset(x: float, variant: int) -> float:
	return signf(x)*320.0*(1.0-absf(x)/1280.0) if variant>=2 else 0.0

static func rounded(poly: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in poly.size():
		var p := poly[i]
		var prev := poly[(i+poly.size()-1)%poly.size()]
		var next := poly[(i+1)%poly.size()]
		# Adjacent chunks must retain identical, straight edge sockets.
		if absf(p.x)>=1279.9 or absf(p.y)>=1279.9:
			result.append(p)
			continue
		var distance := minf(radius,minf(p.distance_to(prev),p.distance_to(next))*0.45)
		var a := p.move_toward(prev,distance)
		var b := p.move_toward(next,distance)
		for step in 9:
			var t := step/8.0
			result.append(a.lerp(p,t).lerp(p.lerp(b,t),t))
	return result

static func rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func outline(variant: int, sidewalk: bool, suburb: bool = false) -> PackedVector2Array:
	# Forty-unit pavements leave a gap between parallel streets at chunk edges;
	# wider bands merely touched there and produced a sharp triangular sliver.
	var width := 280.0 if sidewalk else 240.0
	var local_width := 200.0 if sidewalk else 160.0
	var vertical := PackedVector2Array()
	var horizontal := PackedVector2Array()
	for x in range(-1280,1281,320):
		horizontal.append(Vector2(x,offset(x,variant)-width))
		vertical.append(Vector2(40.0*sin(x/1280.0*PI)*float(variant%2)-width,x))
	for x in range(1280,-1281,-320):
		horizontal.append(Vector2(x,offset(x,variant)+width))
		vertical.append(Vector2(40.0*sin(x/1280.0*PI)*float(variant%2)+width,x))
	var merged: PackedVector2Array = Geometry2D.merge_polygons(horizontal,vertical)[0]
	for side in [-1,1]:
		merged = Geometry2D.merge_polygons(merged,rectangle(Rect2(-1280,side*SuburbLayout.LOCAL_STREET_Y-local_width,2560,local_width*2)))[0]
	var lots: Array[Rect2] = [Rect2(-640,-320,1280,640)]
	if suburb:
		lots = [Rect2(-640,-280,320,560),Rect2(320,-280,320,560),Rect2(-420,-90,840,180)]
	for lot in lots:
		merged = Geometry2D.merge_polygons(merged,rectangle(lot.grow(14 if sidewalk else 0)))[0]
	return rounded(merged,64.0)

static func draw(canvas: Node2D, variant: int, asphalt: Texture2D, pavement: Color, tint: Color, suburb: bool) -> void:
	canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	canvas.draw_colored_polygon(outline(variant,true,suburb),pavement)
	var road := outline(variant,false,suburb)
	var uv := PackedVector2Array()
	for p in road:
		uv.append(p/asphalt.get_size())
	canvas.draw_colored_polygon(road,tint,uv,asphalt)

static func rounded_rect(canvas: Node2D, rect: Rect2, color: Color, radius: int = 24) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.corner_detail = 8
	canvas.draw_style_box(style,rect)

static func lane_segments() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for span in [Vector2(-1280,-340),Vector2(340,1280)]:
		for x in range(-1280,1280,160):
			var start := maxf(x,span.x)
			var end := minf(x+110,span.y)
			if end>start:
				result.append(Vector2(start,end))
	return result
