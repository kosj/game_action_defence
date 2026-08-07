extends Node
## 치트/디버그 오토로드. 일시정지 메뉴의 CHEATS 하위 메뉴가 조작한다.
## autoplay: 플레이어 이동을 간단한 조종 AI 가 대신한다 — 좀비/보스로부터 반발(가까울수록 강함),
## 위협이 약할 때는 근처 경험치 젬을 주우러 간다. 레벨업 카드도 자동 선택된다(LevelUpPanel).

signal changed                     # 토글 상태 변경 — UI 라벨/표시 갱신용
signal time_skip(seconds: float)   # 경과 시간 점프 — ZombieSpawner 가 받아 난이도 시계를 당긴다

var autoplay: bool = false

const _THREAT_R := 340.0   # 좀비 위협 감지 반경
const _BOSS_R := 460.0     # 보스는 더 멀리서부터 피한다
const _GEM_R := 480.0      # 젬 수집 감지 반경

const _Gem := preload("res://scripts/Gold.gd")


func toggle_autoplay() -> void:
	autoplay = not autoplay
	changed.emit()


## 자동플레이 이동 방향(정규화, 없으면 ZERO). Player._handle_move 가 조이스틱 대신 사용한다.
func auto_move_dir(p: Node2D) -> Vector2:
	var pos := p.global_position
	var repel := Vector2.ZERO
	var danger := 0.0
	for z in Events.live_zombies():
		if not is_instance_valid(z):
			continue
		var d: Vector2 = pos - z.global_position
		var dl := d.length()
		if dl < 1.0 or dl > _THREAT_R:
			continue
		var w := 1.0 - dl / _THREAT_R
		repel += (d / dl) * w * w
		danger += w * w
	for b in p.get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b):
			continue
		var d2: Vector2 = pos - (b as Node2D).global_position
		var dl2 := d2.length()
		if dl2 >= 1.0 and dl2 < _BOSS_R:
			var w2 := (1.0 - dl2 / _BOSS_R) * 2.5
			repel += (d2 / dl2) * w2
			danger += w2
	var out := repel
	# 위협이 약할 때만 젬을 주우러 간다 — 수집 욕심에 포위당하지 않도록 위협도로 끌림을 줄인다.
	if danger < 0.9:
		var best: Node2D = null
		var best_d := _GEM_R * _GEM_R
		for g in _Gem.live_gems():
			if not is_instance_valid(g):
				continue
			var dd := pos.distance_squared_to(g.global_position)
			if dd < best_d:
				best_d = dd
				best = g
		if best != null:
			out += (best.global_position - pos).normalized() * (0.85 - danger * 0.6)
	if out.length() < 0.06:
		return Vector2.ZERO
	return out.normalized()
