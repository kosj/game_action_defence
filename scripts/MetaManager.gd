extends Node
## 메타 성장(런 간 영구 강화) 매니저 (Autoload "MetaManager").
## 런에서 번 골드를 종료 시 은행(meta_gold)에 적립하고, 메인 메뉴에서 영구 강화를 구매한다.
## 영구 강화는 매 런 시작 시 자동 적용된다(시작 스탯 보정 + 골드/경험치 획득 배수).
## 디스크(user://meta.save)에 골드·강화 레벨을 보존한다.

const SAVE_PATH := "user://meta.save"

## 영구 강화 카탈로그는 데이터 에셋(res://data/meta_upgrades.tres, GameData)에서 로드한다.
## cost(level) = base_cost * cost_mul^level.

## 변조 허들(P2-29): 은행 잔액은 금고에 두고 프로퍼티로 드나든다(Events.total_gold 와 같은 방식).
var _vault := TamperVault.new()
var meta_gold: int:
	get: return _vault.get_int(&"meta_gold")
	set(value): _vault.set_int(&"meta_gold", value)
var _levels: Dictionary = {}   # id -> level


func _ready() -> void:
	_load()


func level(id: String) -> int:
	return int(_levels.get(id, 0))


func _meta(id: String) -> MetaUpgradeData:
	for u in GameData.meta_upgrades:
		if u.id == id:
			return u
	return null


## 파워업 패널(MainMenu)용 — 데이터 카탈로그를 dict 배열로 반환(표시 순서 유지).
func upgrades() -> Array:
	var out: Array = []
	for u in GameData.meta_upgrades:
		out.append({"id": u.id, "name": u.name, "desc": u.desc, "max": u.max_level,
			"base_cost": u.base_cost, "cost_mul": u.cost_mul, "kind": u.effect_kind})
	return out


## 다음 레벨 비용. 만렙이면 -1.
func cost(id: String) -> int:
	var m := _meta(id)
	if m == null:
		return -1
	var lv := level(id)
	if lv >= m.max_level:
		return -1
	return int(round(float(m.base_cost) * pow(m.cost_mul, float(lv))))


func buy(id: String) -> bool:
	var c := cost(id)
	if c < 0 or meta_gold < c:
		return false
	meta_gold -= c
	_levels[id] = level(id) + 1
	_save()
	return true


## 메타 골드 지출(해금 등). 잔액이 부족하면 false.
func spend_meta(amount: int) -> bool:
	if amount <= 0 or meta_gold < amount:
		return false
	meta_gold -= amount
	_save()
	return true


## 도전과제 보상 등으로 메타 골드를 즉시 적립(은행).
func reward_gold(amount: int) -> void:
	if amount <= 0:
		return
	meta_gold += amount
	_save()


## 런 종료 시(게임오버 → 재시작/메뉴) 이번 판에서 번 골드를 은행에 적립.
func bank(run_gold: int) -> void:
	if run_gold <= 0:
		return
	# 변조가 감지된 판의 골드는 적립하지 않는다(P2-29). 은행 잔액이 곧 영구 진행이라 여기가 관문이다.
	if Events.tamper_detected() or _vault.tampered:
		push_warning("[MetaManager] 변조가 감지된 판 — 골드 %d 적립을 건너뛴다" % run_gold)
		return
	meta_gold += run_gold
	_save()


## 런 시작 시(Events.reset) 호출 — 골드/경험치 배수 + 런당 무료 부활 횟수를 영구 강화로 설정(데이터 기반).
func apply_run_start() -> void:
	Events.gold_mult = 1.0 + _sum_effect("gold_mult")
	Events.xp_mult = 1.0 + _sum_effect("xp_mult")
	Events.revives_left = revive_count()


## 런당 무료 부활 횟수(메타 'revive' 효과 합).
func revive_count() -> int:
	return int(round(_sum_effect("revive")))


## ItemDB.recompute 말미에 호출 — 시작 스탯 보정을 upgrade_* 에 더한다(인벤토리/패시브 위에 얹힘).
func add_bonuses() -> void:
	Events.upgrade_bullet_damage += int(round(_sum_effect("bullet_damage")))
	Events.upgrade_max_health += int(round(_sum_effect("max_health")))
	Events.upgrade_speed += int(round(_sum_effect("move_speed")))
	Events.upgrade_atk_speed += int(round(_sum_effect("atk_speed")))
	Events.upgrade_crit += int(round(_sum_effect("crit")))
	Events.upgrade_regen += int(round(_sum_effect("regen")))
	Events.upgrade_area += int(round(_sum_effect("area")))


## 특정 효과종류(effect_kind)의 총 효과량 = Σ(per_level × 현재레벨). 데이터로 정의된 강화만 합산.
func _sum_effect(kind: String) -> float:
	var total := 0.0
	for u in GameData.meta_upgrades:
		if u.effect_kind == kind:
			total += u.effect_per_level * float(level(u.id))
	return total


func _load() -> void:
	var r := SaveGuard.read_json(SAVE_PATH)   # 서명 검증(P2-29) — 불일치 파일은 없는 것으로 본다
	var parsed = r["data"]
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	meta_gold = int(parsed.get("gold", 0))
	var lv = parsed.get("levels", {})
	if typeof(lv) == TYPE_DICTIONARY:
		for k in lv.keys():
			_levels[str(k)] = int(lv[k])
	if r["status"] == SaveGuard.Status.UNSIGNED:
		_save()   # 구버전 평문 파일 → 첫 실행에 서명본으로 이관


func _save() -> void:
	# 은행 잔액이 메모리에서 변조된 세션은 디스크에 내리지 않는다 — 내리면 변조된 잔액이 정상 서명을
	# 달고 세탁된다(buy·spend·reward 경로가 전부 여기로 온다). 다음 실행은 마지막 정상 서명본으로 돌아간다.
	if _vault.tampered:
		push_warning("[MetaManager] 은행 잔액 변조 감지 — meta.save 를 쓰지 않는다")
		return
	SaveGuard.write_json(SAVE_PATH, {"gold": meta_gold, "levels": _levels})
