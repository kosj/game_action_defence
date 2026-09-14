extends SceneTree
## 캐릭터 궁극기의 피해 반경과 연출 범위가 같은 화면 기하를 쓰는지 검증한다.

const ULTIMATE_PATH := "res://scripts/Ultimate.gd"

var _fails := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		push_error("%s%s" % [label, (" — " + detail) if not detail.is_empty() else ""])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cls: GDScript = load(ULTIMATE_PATH)
	var ult = cls.new()
	root.add_child(ult)
	await process_frame

	var vp_size := root.get_visible_rect().size
	var expected_radius := vp_size.length() * 0.5
	_check("피해·연출 공용 반경은 현재 화면 대각 반경",
		is_equal_approx(float(ult._effect_radius), expected_radius),
		"actual=%.2f expected=%.2f" % [ult._effect_radius, expected_radius])

	# 넓은 가로 화면을 가정해 착탄 후보가 중앙 고정 영역을 넘어 실제 화면 끝까지 퍼지는지 본다.
	ult._field_half_extents = Vector2(1000.0, 500.0)
	var max_x := 0.0
	var max_y := 0.0
	var in_bounds := true
	for i in 500:
		var p: Vector2 = ult._field_point(i * 29, i * 47 + 3)
		max_x = maxf(max_x, absf(p.x))
		max_y = maxf(max_y, absf(p.y))
		in_bounds = in_bounds and absf(p.x) <= 960.01 and absf(p.y) <= 480.01
	_check("화살·궤도 착탄이 화면 가로 끝까지 분포", max_x > 900.0, "max_x=%.1f" % max_x)
	_check("화살·궤도 착탄이 화면 세로 끝까지 분포", max_y > 450.0, "max_y=%.1f" % max_y)
	_check("착탄 중심은 화면 여백 안쪽", in_bounds)

	ult._effect_radius = 1100.0
	ult._build_quake_cracks()
	var shortest_tip := INF
	for crack in ult._cracks:
		var points: PackedVector2Array = crack
		shortest_tip = minf(shortest_tip, points[points.size() - 1].length())
	_check("모든 지진 균열이 피해 반경까지 도달", shortest_tip >= ult._effect_radius,
		"shortest_tip=%.1f radius=%.1f" % [shortest_tip, ult._effect_radius])

	var source := FileAccess.get_file_as_string(ULTIMATE_PATH)
	_check("피해 판정이 공용 반경을 사용", source.contains("r_sq := _effect_radius * _effect_radius"))
	_check("발동 파동이 공용 반경을 사용",
		source.contains("_data.color, _effect_radius, 0.62"))
	_check("구형 고정 착탄 범위가 없음",
		not source.contains("1.8 * 640.0") and not source.contains("1.7 * 520.0"))

	ult.queue_free()
	await process_frame
	print("ULTIMATE AREA failures=", _fails)
	quit(_fails)
