extends SceneTree
func _initialize() -> void:
	var layout = load("res://scripts/SuburbLayout.gd")
	var nav := NavigationPolygon.new()
	nav.add_outline(PackedVector2Array([Vector2(-1280,-1280),Vector2(1280,-1280),Vector2(1280,1280),Vector2(-1280,1280)]))
	for i in layout.LOTS.size():
		var r: Rect2 = layout.footprint(Vector2i.ZERO,i).grow(28)
		nav.add_outline(PackedVector2Array([r.position,Vector2(r.position.x,r.end.y),r.end,Vector2(r.end.x,r.position.y)]))
	nav.make_polygons_from_outlines()
	assert(nav.get_polygon_count()>0)
	var err := ResourceSaver.save(nav,"res://data/suburb_navigation.tres")
	print("NAV BAKE ",err," polygons=",nav.get_polygon_count())
	quit(err)
