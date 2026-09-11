class_name SuburbWorld
extends Node2D

const HOUSE := preload("res://scenes/SuburbHouse.tscn")
const TILE := 80
var chunks: Dictionary = {}
var destination := Vector2.INF
var _textures: Dictionary = {}
var _district: DistrictScenery

static func supports(id: String) -> bool:
	return id in ["suburb","city","lab"]

var _prop_textures: Dictionary = {}
var _tiles: TileSet
var _nav: NavigationPolygon
var _player: Node2D
var _last := Vector2i(999999,999999)
var _probe: CharacterBody2D
var _params := PhysicsTestMotionParameters2D.new()
var _result := PhysicsTestMotionResult2D.new()
var _routes: Dictionary = {}
var _target_cell := Vector2i.ZERO
var _budget := 0
var _asphalt: Texture2D
var _bed_bush := preload("res://assets/atlas/props/suburb/prop_bush.tres")

func _draw_parcels(canvas: Node2D, variant: int) -> void:
	var lab := _district != null and _district.theme_id == "lab"
	var pavement := Color(0.36,0.43,0.46) if lab else Color(0.48,0.48,0.43)
	StreetSurface.draw(canvas,variant,_asphalt,pavement,Color(0.67,0.78,0.82) if lab else Color(0.78,0.80,0.82),_district == null)
	if _district != null:
		_district.draw_ground(canvas,variant,_asphalt)
		return
	# Static, collision-free landscaping. Every private driveway belongs to a lot.
	for i in SuburbLayout.LOTS.size():
		var lot: Vector2 = SuburbLayout.LOTS[i]
		var width := 440.0 if i<4 else 360.0
		var yard := Rect2(lot.x-width*0.5,740 if lot.y>0 else -1240,width,500)
		canvas.draw_rect(yard,Color(0.38,0.45,0.24,0.18) if (i+variant)%2==0 else Color(0.15,0.24,0.13,0.17))
		for stripe in range(0,8,2):
			canvas.draw_rect(Rect2(yard.position+Vector2(0,stripe*62),Vector2(width,62)),Color(0.58,0.65,0.40,0.045))
		# Short rear beds suggest a property boundary without enclosing a passage.
		canvas.draw_rect(Rect2(lot+Vector2(-108,signf(lot.y)*140),Vector2(216,18)),Color(0.23,0.20,0.14,0.8))
		for offset in [-72,0,72]:
			canvas.draw_texture_rect(_bed_bush,Rect2(lot+Vector2(offset-19,signf(lot.y)*140-12),Vector2(38,38)),false,Color(0.82,0.91,0.78))
	for street_side in [-1,1]:
		var y: float = street_side*SuburbLayout.LOCAL_STREET_Y
		for curb_side in [-1,1]:
			for span in [Vector2(-1280,-340),Vector2(340,1280)]:
				canvas.draw_line(Vector2(span.x,y+curb_side*163),Vector2(span.y,y+curb_side*163),Color(0.66,0.65,0.58),3)
		for x in range(-1280,1280,80):
			if absi(x)<320:
				continue
			for edge in [-1,1]:
				canvas.draw_line(Vector2(x,y+edge*168),Vector2(x,y+edge*198),Color(0.32,0.33,0.30,0.55),1)
	for i in SuburbLayout.LOTS.size():
		var driveway := SuburbLayout.driveway(i)
		canvas.draw_rect(driveway,Color(0.53,0.52,0.46))
		if i<4:
			var lot: Vector2 = SuburbLayout.LOTS[i]
			canvas.draw_rect(Rect2(lot+Vector2(-190 if lot.x>0 else 90,-24),Vector2(100,48)),Color(0.53,0.52,0.46))
		for y in range(int(driveway.position.y)+80,int(driveway.end.y),80):
			canvas.draw_line(Vector2(driveway.position.x,y),Vector2(driveway.end.x,y),Color(0.37,0.38,0.34,0.6),1)

func _ready() -> void:
	if not supports(ThemeManager.selected_id()):
		queue_free()
		return
	if ThemeManager.selected_id() != "suburb":
		_district = DistrictScenery.new(ThemeManager.selected_id())
	y_sort_enabled = true
	add_to_group("suburb_world")
	_player = get_tree().get_first_node_in_group("player")
	if ResourceLoader.exists("res://data/suburb_navigation.tres"):
		_nav = load("res://data/suburb_navigation.tres")
	if _district == null:
		for direction_name in ["south","north","east","west"]:
			var path := "res://assets/suburb/house_%s.png" % direction_name
			if ResourceLoader.exists(path):
				_textures[direction_name] = load(path)
		if _textures.is_empty():
			var img := Image.create(64,64,false,Image.FORMAT_RGBA8)
			img.fill(Color(0.36,0.31,0.28))
			for direction_name in ["south","north","east","west"]:
				_textures[direction_name] = ImageTexture.create_from_image(img)
	_tiles = _make_tiles()
	if _district == null:
		for key in ["mailbox","hydrant"]:
			var texture: Texture2D = load("res://assets/suburb/prop_%s_top.png" % key)
			var cropped := AtlasTexture.new()
			cropped.atlas = texture
			cropped.region = texture.get_image().get_used_rect()
			_prop_textures[key] = cropped
	_probe = CharacterBody2D.new()
	_probe.collision_layer = 0
	_probe.collision_mask = 16
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20
	shape.shape = circle
	_probe.add_child(shape)
	add_child(_probe)
	_probe.position = Vector2(0,0)
	if _player != null:
		_player.set_collision_mask_value(5,true)
		if not SaveManager.pending_suburb.is_empty():
			var pos: Array = SaveManager.pending_suburb.get("position", [0,0])
			_player.global_position = SuburbLayout.safe(Vector2(pos[0],pos[1]))
		_update_chunks()

func _physics_process(_delta: float) -> void:
	_budget = 6
	if not is_instance_valid(_player):
		return
	_update_chunks()
	var target := Vector2i(_player.global_position / 160.0)
	if target != _target_cell:
		_target_cell = target
		_routes.clear()

func _update_chunks() -> void:
	var c := SuburbLayout.cell(_player.global_position)
	if c == _last:
		return
	_last = c
	for x in range(c.x-1,c.x+2):
		for y in range(c.y-1,c.y+2):
			ensure_chunk(Vector2i(x,y))
	for key in chunks.keys():
		if absi(key.x-c.x)>1 or absi(key.y-c.y)>1:
			if destination != Vector2.INF and key == SuburbLayout.cell(destination):
				continue
			var entry: Dictionary = chunks[key]
			for house in entry.houses:
				house.queue_free()
			entry.root.queue_free()
			chunks.erase(key)
	_routes.clear()

func ensure_chunk(c: Vector2i) -> void:
	if chunks.has(c):
		return
	var node := Node2D.new()
	node.position = SuburbLayout.center(c)
	add_child(node)
	var street_variant := SuburbLayout.variant(c,Events.env_seed)
	var layer := TileMapLayer.new()
	layer.z_index = -2
	layer.tile_set = _tiles
	node.add_child(layer)
	for x in range(-16,16):
		for y in range(-16,16):
			layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	var parcels := Node2D.new()
	parcels.z_index = -2
	node.add_child(parcels)
	parcels.draw.connect(func() -> void: _draw_parcels(parcels,street_variant))
	var markings := Node2D.new()
	markings.z_index = -1
	node.add_child(markings)
	markings.draw.connect(func() -> void:
		if _district != null:
			return
		for n in range(-12,13):
			if absi(n)<4:
				continue
			if absi(n)>=7:
				markings.draw_rect(Rect2(n*100,_road_offset(n*100,street_variant)-3,48,6),Color(0.68,0.59,0.33,0.55))
			if absf(absf(n*100)-SuburbLayout.LOCAL_STREET_Y)>240:
				markings.draw_rect(Rect2(-3,n*100,6,48),Color(0.68,0.59,0.33,0.55))
		for side in [-1,1]:
			for y in [-275,-180,180,275]:
				markings.draw_line(Vector2(side*400,y),Vector2(side*600,y),Color(0.7,0.7,0.62,0.6),3)
	)
	var houses: Array = []
	var footprints: Array[Rect2] = []
	var variant := SuburbLayout.variant(c,Events.env_seed)
	for i in SuburbLayout.LOTS.size():
		footprints.append(SuburbLayout.footprint(c,i))
		var house := HOUSE.instantiate()
		add_child(house)
		house.global_position = SuburbLayout.center(c)+SuburbLayout.LOTS[i]+Vector2(0,110)
		var tint := Color(0.95,0.96,0.94) if (i+variant)%2==0 else Color(0.86,0.90,0.87)
		house.configure(_district.building(i,variant) if _district != null else _textures[SuburbLayout.frontage(i)],tint)
		houses.append(house)
		_add_props(node,i,variant)
	if _nav != null:
		var region := NavigationRegion2D.new()
		region.navigation_polygon = _nav
		node.add_child(region)
	chunks[c] = {"root":node,"houses":houses,"footprints":footprints}

func _add_props(parent: Node2D, index: int, variant: int) -> void:
	if _district != null:
		_district.add_props(parent,index,variant)
		return
	var lot: Vector2 = SuburbLayout.LOTS[index]
	var keys := ["mailbox","bush","forsale","hydrant"]
	var front := Vector2(-signf(lot.x),0) if absf(lot.x)>800 else Vector2(0,-signf(lot.y))
	var side := front.orthogonal()
	var apron := SuburbLayout.driveway(index)
	var mailbox := Vector2(apron.position.x-22,signf(lot.y)*750)
	var positions := [mailbox,lot-front*120+side*145,lot+front*180-side*100,Vector2(signf(lot.x)*280,signf(lot.y)*730)]
	for i in 4:
		if (i == 2 and (index+variant)%3 != 0) or (i == 3 and index>=4):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = _prop_textures[keys[i]] if _prop_textures.has(keys[i]) else load("res://assets/atlas/props/suburb/prop_%s.tres" % keys[i])
		sprite.position = positions[i]
		var visual_size := 54.0 if i==0 else 46.0
		sprite.scale = Vector2.ONE * (visual_size/maxf(sprite.texture.get_width(),sprite.texture.get_height()))
		sprite.z_index = -1
		parent.add_child(sprite)

func _make_tiles() -> TileSet:
	var image := Image.create(TILE*3,TILE,false,Image.FORMAT_RGBA8)
	var colors := [Color(0.24,0.29,0.19),Color(0.19,0.20,0.21),Color(0.39,0.39,0.35)]
	for k in 3:
		image.fill_rect(Rect2i(k*TILE,0,TILE,TILE),colors[k])
		for i in 80:
			var x := posmod(i*37,80)
			var y := posmod(i*53,80)
			image.set_pixel(k*TILE+x,y,colors[k].lightened(0.025))
	for entry in [["lawn",0],["asphalt",1]]:
		var path: String = "res://assets/suburb/%s.png" % entry[0]
		if ResourceLoader.exists(path):
			var texture: Texture2D = load(path)
			var tile := texture.get_image()
			tile.resize(TILE,TILE,Image.INTERPOLATE_LANCZOS)
			tile.convert(Image.FORMAT_RGBA8)
			if entry[1]==1:
				_asphalt = ImageTexture.create_from_image(tile)
			image.blit_rect(tile,Rect2i(0,0,TILE,TILE),Vector2i(int(entry[1])*TILE,0))
	if _district != null:
		var base := _district.make_floor(TILE)
		image.blit_rect(base,Rect2i(0,0,TILE,TILE),Vector2i.ZERO)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(TILE,TILE)
	for k in 3:
		atlas.create_tile(Vector2i(k,0))
	var result := TileSet.new()
	result.tile_size = Vector2i(TILE,TILE)
	result.add_source(atlas,0)
	return result

func clear_line(a: Vector2, b: Vector2, margin: float = 24) -> bool:
	var start := SuburbLayout.cell(a)
	var end := SuburbLayout.cell(b)
	var bounds := Rect2(a.min(b),(b-a).abs()).grow(margin+0.1)
	for x in range(mini(start.x,end.x),maxi(start.x,end.x)+1):
		for y in range(mini(start.y,end.y),maxi(start.y,end.y)+1):
			var cell_key := Vector2i(x,y)
			var entry: Dictionary = chunks.get(cell_key,{})
			var footprints: Array = entry.get("footprints",[])
			if footprints.is_empty():
				for i in SuburbLayout.LOTS.size():
					footprints.append(SuburbLayout.footprint(cell_key,i))
			for r: Rect2 in footprints:
				if r.intersects(bounds) and SuburbLayout.blocks_segment(a,b,r.grow(margin)):
					return false
	return true

func motion(a: Vector2,b: Vector2) -> Vector2:
	if clear_line(a,b,21):
		return b
	_params.from = Transform2D(0,SuburbLayout.safe(a,22))
	_params.motion = b-a
	_params.margin = 0.1
	if PhysicsServer2D.body_test_motion(_probe.get_rid(),_params,_result):
		var next := _params.from.origin + _result.get_travel()
		_params.motion = _result.get_remainder().slide(_result.get_collision_normal())
		_params.from.origin = next
		if PhysicsServer2D.body_test_motion(_probe.get_rid(),_params,_result):
			return SuburbLayout.safe(next+_result.get_travel(),21)
		return SuburbLayout.safe(next+_params.motion,21)
	return SuburbLayout.safe(_params.from.origin+_params.motion,21)

func direction(from: Vector2,to: Vector2) -> Vector2:
	if clear_line(from,to):
		return (to-from).normalized()
	# Crowd/weave displacement can leave an actor inside the route clearance
	# while still outside the physical wall. Recover before following corners.
	if SuburbLayout.inside(from,25):
		return (SuburbLayout.safe(from,30)-from).normalized()
	# Guidance targets an arena while enemies target the player.
	var key := Vector4i(floori(from.x/128),floori(from.y/128),floori(to.x/160),floori(to.y/160))
	var path: PackedVector2Array = _routes.get(key,PackedVector2Array())
	if path.is_empty() and _budget>0 and _nav != null:
		_budget -= 1
		path = NavigationServer2D.map_get_path(get_world_2d().navigation_map,SuburbLayout.safe(from),SuburbLayout.safe(to),true)
		_routes[key] = path
	for i in range(path.size()-1,-1,-1):
		var point := path[i]
		if from.distance_squared_to(point)>16 and clear_line(from,point):
			return (point-from).normalized()
	return Vector2.ZERO

func nearest_arena(from: Vector2) -> Vector2:
	var c := SuburbLayout.cell(from)
	var best := SuburbLayout.center(c)
	var distance := INF
	for x in range(c.x-1,c.x+2):
		for y in range(c.y-1,c.y+2):
			var target := SuburbLayout.center(Vector2i(x,y))
			var path := NavigationServer2D.map_get_path(get_world_2d().navigation_map,SuburbLayout.safe(from),target,true)
			if path.is_empty():
				continue
			var length := 0.0
			for i in range(1,path.size()):
				length += path[i-1].distance_to(path[i])
			if length<distance:
				distance = length
				best = target
	return best


func _road_offset(x: float, variant: int) -> float:
	# Alternating paired T junctions reconnect at identical chunk-edge sockets.
	return StreetSurface.offset(x,variant)
