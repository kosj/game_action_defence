extends StaticBody2D

static var _bounds: Dictionary = {}

var footprint_size := SuburbLayout.HOUSE_SIZE
var _sprite: Sprite2D
var _check := 0.0

func configure(texture: Texture2D, tint: Color) -> void:
	add_to_group("suburb_houses")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = footprint_size
	shape.shape = rect
	shape.position.y = -footprint_size.y * 0.5
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	if not _bounds.has(texture.resource_path):
		_bounds[texture.resource_path] = texture.get_image().get_used_rect()
	var used: Rect2i = _bounds[texture.resource_path]
	_sprite.region_enabled = true
	_sprite.region_rect = used
	# Keep the foundation at the collision body's foot while the visible wall
	# rises above it. Roof overhang does not change the walkable footprint.
	_sprite.position.y = -140
	_sprite.scale = Vector2(320,280) / Vector2(used.size)
	_sprite.modulate = tint
	add_child(_sprite)

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0 or _sprite == null:
		return
	_check = 0.15
	var obscures := false
	var area := Rect2(global_position + Vector2(-170,-290), Vector2(340,180))
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null and area.has_point(p.global_position):
		obscures = true
	if not obscures:
		for z in Events.zombies_near(global_position + Vector2(0,-190)):
			if is_instance_valid(z) and area.has_point(z.global_position):
				obscures = true
				break
	_sprite.modulate.a = 0.38 if obscures else 1.0
