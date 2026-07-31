extends SceneTree
## 일회성: 기본 난이도 곡선 .tres 생성.  godot --headless --path . --script res://tools/gen_difficulty_data.gd

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var d := DifficultyData.new()   # 기본값(스크립트 @export 기본) 그대로 저장
	var err := ResourceSaver.save(d, "res://data/difficulty.tres")
	print("gen_difficulty_data: saved difficulty.tres err=%d" % err)
	quit()
