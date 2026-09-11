extends SceneTree
func _initialize() -> void:
	var failures := 0
	for variant in 4:
		for suburb in [false,true]:
			var road := StreetSurface.outline(variant,false,suburb)
			if Geometry2D.triangulate_polygon(road).is_empty(): failures += 1
			for side in [-1,1]:
				for edge in [-1,1]:
					for span in StreetSurface.lane_segments():
						for step in 12:
							var p := Vector2(lerpf(span.x,span.y,step/11.0),side*520+edge*140)
							# Chunk-edge endpoints are shared by the neighboring polygon.
							p.x = clampf(p.x,-1279.9,1279.9)
							if not Geometry2D.is_point_in_polygon(p,road):
								push_error("Lane outside asphalt: "+str([variant,p]))
								failures += 1
				for x in range(-160,161,60):
					for corner in StreetSurface.rectangle(Rect2(x,side*370-25,35,50)):
						if not Geometry2D.is_point_in_polygon(corner,road): failures += 1
			for point in [Vector2(-1279,0),Vector2(1279,0),Vector2(0,-1279),Vector2(0,1279)]:
				if not Geometry2D.is_point_in_polygon(point,road): failures += 1
	print("STREET SURFACE failures=",failures)
	quit(failures)
