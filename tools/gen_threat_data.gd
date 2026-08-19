extends SceneTree
## 위협 등급 데이터 생성 (HANDOFF P1-12).
##   godot --headless --path . --script res://tools/gen_threat_data.gd
##
## 규칙 사다리를 **한 등급에 하나씩 누적**해 20칸을 접는다. 초안은 CONTENT_PLAN §2 Phase A 의
## 표(2~7등급)이고, 8등급부터는 같은 손잡이를 다시 돌린다 — 새 규칙을 계속 발명하면 각각이
## 검증 대상이 되어 20칸을 채우는 비용이 콘텐츠를 새로 만드는 것과 다를 바 없어진다.
## 이 방식은 손잡이 6개만 검증하면 20칸 전부가 검증된다.
##
## ⚠️ 등급 1은 반드시 항등원이어야 한다(배수 1.0 / 증감 0). 지금까지의 실측이 기준선으로
## 남는 유일한 조건이다 — scenes/ThreatTest.tscn 이 이걸 검사한다.

const OUT := "res://data/threat_ranks.tres"
const MAX_RANK := 20

## 등급마다 붙는 규칙 하나. [손잡이, 값, 로케일 키, 표시 수치]
## 손잡이 이름은 ThreatRankData 의 필드명과 같다.
const LADDER := [
	{"knob": "enemy_hp_mult",        "value": 1.10, "key": "threat_rule_enemy_hp",   "amount": "+10%"},
	{"knob": "chest_interval_mult",  "value": 1.25, "key": "threat_rule_chest",      "amount": "+25%"},
	{"knob": "boss_heal_charges_add","value": 1,    "key": "threat_rule_boss_heal",  "amount": "+1"},
	{"knob": "start_health_add",     "value": -1,   "key": "threat_rule_start_hp",   "amount": "-1"},
	{"knob": "elite_interval_mult",  "value": 0.80, "key": "threat_rule_elite",      "amount": "-20%"},
	{"knob": "enemy_speed_mult",     "value": 1.05, "key": "threat_rule_enemy_speed","amount": "+5%"},
	{"knob": "enemy_hp_mult",        "value": 1.10, "key": "threat_rule_enemy_hp",   "amount": "+10%"},
	{"knob": "boss_hp_mult",         "value": 1.15, "key": "threat_rule_boss_hp",    "amount": "+15%"},
	{"knob": "chest_interval_mult",  "value": 1.25, "key": "threat_rule_chest",      "amount": "+25%"},
	{"knob": "start_health_add",     "value": -1,   "key": "threat_rule_start_hp",   "amount": "-1"},
	{"knob": "enemy_speed_mult",     "value": 1.05, "key": "threat_rule_enemy_speed","amount": "+5%"},
	{"knob": "elite_interval_mult",  "value": 0.80, "key": "threat_rule_elite",      "amount": "-20%"},
	{"knob": "enemy_hp_mult",        "value": 1.15, "key": "threat_rule_enemy_hp",   "amount": "+15%"},
	{"knob": "boss_heal_charges_add","value": 1,    "key": "threat_rule_boss_heal",  "amount": "+1"},
	{"knob": "boss_hp_mult",         "value": 1.15, "key": "threat_rule_boss_hp",    "amount": "+15%"},
	{"knob": "enemy_speed_mult",     "value": 1.05, "key": "threat_rule_enemy_speed","amount": "+5%"},
	{"knob": "chest_interval_mult",  "value": 1.25, "key": "threat_rule_chest",      "amount": "+25%"},
	{"knob": "enemy_hp_mult",        "value": 1.15, "key": "threat_rule_enemy_hp",   "amount": "+15%"},
	{"knob": "start_health_add",     "value": -1,   "key": "threat_rule_start_hp",   "amount": "-1"},
]

const MULT_KNOBS := ["enemy_hp_mult", "enemy_speed_mult", "boss_hp_mult",
	"chest_interval_mult", "elite_interval_mult"]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var db := ThreatRankDB.new()
	var acc := {}   # 누적 상태
	for i in range(MAX_RANK):
		var d := ThreatRankData.new()
		d.rank = i + 1
		if i > 0:
			var step: Dictionary = LADDER[mini(i - 1, LADDER.size() - 1)]
			var knob: String = step["knob"]
			if MULT_KNOBS.has(knob):
				acc[knob] = float(acc.get(knob, 1.0)) * float(step["value"])
			else:
				acc[knob] = int(acc.get(knob, 0)) + int(step["value"])
			d.rule_key = step["key"]
			d.rule_amount = step["amount"]
		for knob in MULT_KNOBS:
			d.set(knob, float(acc.get(knob, 1.0)))
		d.boss_heal_charges_add = int(acc.get("boss_heal_charges_add", 0))
		d.start_health_add = int(acc.get("start_health_add", 0))
		db.ranks.append(d)
	var err := ResourceSaver.save(db, OUT)
	print("gen_threat_data: %d 등급 저장 err=%d" % [db.ranks.size(), err])
	for d in db.ranks:
		print("  R%-2d hp=%.3f spd=%.3f bosshp=%.3f chest=%.3f elite=%.3f heal=%+d hp0=%+d  %s %s"
			% [d.rank, d.enemy_hp_mult, d.enemy_speed_mult, d.boss_hp_mult,
				d.chest_interval_mult, d.elite_interval_mult, d.boss_heal_charges_add,
				d.start_health_add, d.rule_key, d.rule_amount])
	quit()
