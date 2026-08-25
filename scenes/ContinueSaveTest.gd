extends Node
## 이어하기(체크포인트 세이브) 회귀 테스트.
##
## 실행:
##   godot --headless --path . res://scenes/ContinueSaveTest.tscn
## 마지막 줄의 "RESULT ok=<통과>/<전체>" 가 전부 통과가 아니면 회귀다.
##
## 검사 항목
##   T1 저장 당시의 캐릭터로 이어진다(메뉴에서 다른 캐릭터를 골라둔 뒤에도)
##   T2 캐릭터 보너스 스탯이 저장 당시 캐릭터 기준으로 재계산된다
##   T3 저장 당시의 아레나(테마)로 이어진다
##   T4 사망하면 체크포인트가 삭제된다(메타 골드 중복 적립 방지)
##   T5 캐릭터 id 가 없는 구버전 세이브도 크래시 없이 이어진다
##   T6 저장된 캐릭터가 잠겨 있거나 없는 id 면 폴백하고 이어하기를 막지 않는다
##   T7 카탈로그에서 삭제된 아이템(성수 등)은 이어하기 때 인벤토리에서 걷어낸다

## save_game() 이 읽는 필드만 가진 최소 스텁 — 실제 Player 씬 없이 세이브를 만든다.
class FakePlayer extends Node:
	var health: int = 7
	var current_weapon: Dictionary = {"id": "pistol", "tier_id": "rare"}

var _ok: int = 0
var _total: int = 0


func _ready() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


## 잠금 캐릭터/테마를 테스트용으로 강제 해금(구매 상태를 직접 세팅).
func _unlock_char(id: String) -> void:
	CharacterManager._bought[id] = true


func _snapshot_bonus() -> Array:
	return [Events.upgrade_max_health, Events.upgrade_bullet_damage,
		Events.upgrade_crit, Events.upgrade_greed]


func _run() -> void:
	var fake := FakePlayer.new()
	add_child(fake)
	SaveManager.delete_save()

	_unlock_char("hunter")
	_check("사전조건: hunter 선택 가능", CharacterManager.select("hunter"))
	Events.reset()
	var hunter_bonus := _snapshot_bonus()

	_check("사전조건: veteran 선택 가능", CharacterManager.select("veteran"))
	Events.reset()
	var veteran_bonus := _snapshot_bonus()
	_check("사전조건: 두 캐릭터의 보너스 스탯이 다름", hunter_bonus != veteran_bonus)

	# --- T1/T2: hunter 로 저장한 뒤 메뉴에서 veteran 을 골라둔 상태로 이어하기 ---
	CharacterManager.select("hunter")
	Events.reset()
	Events.total_gold = 123
	Events.level = 9
	SaveManager.save_game(fake)
	CharacterManager.select("veteran")   # 새 게임 흐름에서 캐릭터만 눌러보고 나온 상황
	SaveManager.apply_to_events(SaveManager.load_save())
	_check("T1 저장 당시 캐릭터로 이어짐", CharacterManager.selected_id() == "hunter")
	_check("T2 캐릭터 보너스 스탯이 저장 캐릭터 기준", _snapshot_bonus() == hunter_bonus)
	_check("T2 진행 데이터도 함께 복원", Events.total_gold == 123 and Events.level == 9)

	# --- T3: 테마 복원 ---
	var themes: Array = []
	for t in GameData.themes:
		if t != null and ThemeManager.is_unlocked(t):
			themes.append(t.id)
	if themes.size() < 2:
		_check("T3 아레나 복원 (해금 테마 2개 미만이라 건너뜀)", true)
	else:
		ThemeManager.select(themes[1])
		SaveManager.save_game(fake)
		ThemeManager.select(themes[0])
		SaveManager.apply_to_events(SaveManager.load_save())
		_check("T3 저장 당시 아레나로 이어짐", ThemeManager.selected_id() == themes[1])

	# --- T4: 사망하면 체크포인트 폐기 ---
	SaveManager.save_game(fake)
	_check("T4 사전조건: 세이브 존재", SaveManager.has_save())
	Events.player_died.emit()
	_check("T4 사망 시 체크포인트 삭제", not SaveManager.has_save())

	# --- T5: character_id 가 없는 구버전 세이브 ---
	CharacterManager.select("veteran")
	_write_raw({"total_gold": 50, "level": 3, "player_health": 4,
		"weapons": {"gun": 2}, "passives": {}})
	SaveManager.apply_to_events(SaveManager.load_save())
	_check("T5 구버전 세이브도 이어짐(현재 선택 유지)",
		CharacterManager.selected_id() == "veteran" and Events.total_gold == 50)

	# --- T6: 알 수 없는/잠긴 캐릭터 id ---
	_write_raw({"character_id": "does_not_exist", "total_gold": 77, "level": 2,
		"player_health": 4, "weapons": {"gun": 1}, "passives": {}})
	SaveManager.apply_to_events(SaveManager.load_save())
	_check("T6 알 수 없는 캐릭터 id 는 폴백하고 진행은 유지",
		CharacterManager.selected_id() != "" and Events.total_gold == 77)

	# --- T7: 삭제된 아이템 id 가 슬롯을 차지한 채 살아남지 않는가 ---
	_write_raw({"character_id": "veteran", "total_gold": 10, "level": 2, "player_health": 4,
		"weapons": {"gun": 2, "holy": 5, "crucifix": 3}, "passives": {"armor": 1, "no_such": 2}})
	SaveManager.apply_to_events(SaveManager.load_save())
	_check("T7 삭제된 아이템은 인벤토리에서 제거됨",
		not Events.weapons.has("holy") and not Events.weapons.has("crucifix")
		and not Events.passives.has("no_such"))
	_check("T7 살아있는 아이템은 그대로 유지됨",
		int(Events.weapons.get("gun", 0)) == 2 and int(Events.passives.get("armor", 0)) == 1)

	SaveManager.delete_save()
	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)


func _write_raw(d: Dictionary) -> void:
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
