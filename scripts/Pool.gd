extends Node
## 제너릭 오브젝트 풀 (Autoload "Pool")
## instantiate()/queue_free() 의 잦은 호출로 생기는 GC 스파이크를 막는다.
##
## 사용법:
##   var n := Pool.acquire(SCENE, get_tree().current_scene)  # 꺼내기(없으면 생성)
##   Pool.release(n)                                          # 반납(= queue_free 대체)
##
## 동작 원리:
##   - release 는 노드를 트리에서 "떼어내" 보관한다. 트리 밖 노드는 _process/_physics_process,
##     충돌, 렌더가 전부 멈추므로 별도 비활성화 처리가 필요 없다.
##   - acquire 는 다시 트리에 붙이고 on_spawn() 으로 상태만 초기화한다(_ready 는 최초 1회만 실행).
##
## 풀 대상 스크립트 규약:
##   - on_spawn():   재사용 시 상태 초기화 (체력/타이머/플래그 등). 필수 권장.
##   - on_despawn(): 반납 직전 정리. 선택.
##   - _ready():     시그널 연결·그룹 등록 같은 "1회성" 셋업.

var _free: Dictionary = {}   # scene_path(String) -> Array[Node]


func acquire(scene: PackedScene, parent: Node) -> Node:
	var key := scene.resource_path
	var node: Node
	var bucket: Array = _free.get(key, [])
	if bucket.size() > 0:
		node = bucket.pop_back()
	else:
		node = scene.instantiate()
		node.set_meta("_pool_key", key)

	if node.get_parent() != parent:
		parent.add_child(node)   # 최초 추가 시 _ready 1회 실행
	if node.has_method("on_spawn"):
		node.on_spawn()
	return node


func release(node: Node) -> void:
	# 같은 프레임 중복 반납 방지 (실제 분리는 물리 콜백 밖에서 안전하게 수행)
	if node.get_meta("_pool_released", false):
		return
	node.set_meta("_pool_released", true)
	call_deferred("_do_release", node)


func _do_release(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("on_despawn"):
		node.on_despawn()
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.set_meta("_pool_released", false)

	var key: String = node.get_meta("_pool_key", "")
	if key == "":
		node.queue_free()   # 풀 소속이 아니면 그냥 해제
		return
	if not _free.has(key):
		_free[key] = []
	_free[key].append(node)


## 첫 웨이브에서 한꺼번에 생성되며 끊기는 것을 막기 위해 미리 만들어 둔다.
func prewarm(scene: PackedScene, count: int) -> void:
	var key := scene.resource_path
	if not _free.has(key):
		_free[key] = []
	for i in count:
		var n := scene.instantiate()
		n.set_meta("_pool_key", key)
		_free[key].append(n)


## 씬 전환 등에서 보관 중인 노드를 완전히 해제.
func clear() -> void:
	for key in _free.keys():
		for n in _free[key]:
			if is_instance_valid(n):
				n.queue_free()
	_free.clear()
