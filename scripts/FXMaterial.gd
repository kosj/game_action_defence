extends RefCounted
## 이펙트 공용 머티리얼.
##
## 가산 블렌드(ADD)를 쓰는 이펙트가 각자 CanvasItemMaterial.new() 를 만들면, 설정이 같아도
## **객체가 다르면 Godot 이 별도 드로우 배치로 처리한다**. 번개·오라·궁극기가 동시에 떠 있으면
## 그만큼 배치가 쪼개진다. 파라미터가 인스턴스별로 다르지 않으므로 하나를 공유한다.
##
## 사용:  material = preload("res://scripts/FXMaterial.gd").additive()

static var _add: CanvasItemMaterial = null


## 가산 혼합 머티리얼(공유 인스턴스). 겹칠수록 밝아지는 발광 표현에 쓴다.
static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add
