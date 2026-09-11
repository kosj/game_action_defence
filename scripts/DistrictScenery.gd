class_name DistrictScenery
extends RefCounted
## Visual dressing shares SuburbLayout footprints and its prebuilt navigation.
## Roads, service aprons and props never add hidden collision shapes.

var theme_id: String
var buildings: Array[Texture2D] = []
var props: Dictionary = {}

func _init(id: String) -> void:
	theme_id = id
	var keys := ["shop","depot"] if id == "city" else ["research","cooling"]
	for key in keys:
		buildings.append(load("res://assets/districts/%s_%s.png" % [id,key]))
	var prop_keys := ["wreck_car","dumpster","barrel","rubble","barrier"] if id == "city" else ["console","drum"]
	for key in prop_keys:
		props[key] = load("res://assets/atlas/props/%s/prop_%s.tres" % [id,key])

func make_floor(size: int) -> Image:
	# Engine-generated concrete avoids baking road markings into each tiny tile.
	var result := Image.create(size,size,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 415
	noise.frequency = 0.18
	var base := Color(0.32,0.39,0.41) if theme_id == "lab" else Color(0.38,0.37,0.34)
	for y in size:
		for x in size:
			result.set_pixel(x,y,base.lightened(noise.get_noise_2d(x,y)*0.025))
	return result

func building(index: int, variant: int) -> Texture2D:
	return buildings[(index+index/3+variant)%buildings.size()]

func access_apron(index: int) -> Rect2:
	var lot: Vector2 = SuburbLayout.LOTS[index]
	if lot.y<0:
		return Rect2(lot.x-70,lot.y+110,140,-720-(lot.y+110))
	# Camera-facing entrances are on the south facade. Southern lots therefore
	# use a side service drive to reach that facade, rather than the rear wall.
	return Rect2(lot.x-235,720,70,lot.y+220-720)

func draw_ground(canvas: Node2D, variant: int, asphalt: Texture2D) -> void:
	var lab := theme_id == "lab"
	var pavement := Color(0.36,0.43,0.46) if lab else Color(0.45,0.43,0.39)
	var lane := Color(0.52,0.63,0.65,0.8) if lab else Color(0.77,0.71,0.51,0.75)
	# Large concrete slabs rather than a dense, high-contrast tile pattern.
	for x in range(-1280,1281,320):
		canvas.draw_line(Vector2(x,-1280),Vector2(x,1280),Color(0.14,0.20,0.21,0.15),2)
	for y in range(-1280,1281,320):
		canvas.draw_line(Vector2(-1280,y),Vector2(1280,y),Color(0.14,0.20,0.21,0.15),2)
	# Two continuous service corridors connect to the same chunk-edge sockets.
	for side in [-1,1]:
		var y: float = side*SuburbLayout.LOCAL_STREET_Y
		canvas.draw_rect(Rect2(-1280,y-200,2560,400),pavement)
		canvas.draw_texture_rect(asphalt,Rect2(-1280,y-160,2560,320),true,Color(0.67,0.78,0.82) if lab else Color(0.8,0.8,0.8))
		canvas.draw_texture_rect(asphalt,Rect2(-240,y-200,480,400),true)
		for x in range(-1280,1280,160):
			if absi(x)<320:
				continue
			canvas.draw_line(Vector2(x,y-170),Vector2(x+110,y-170),lane,3)
			canvas.draw_line(Vector2(x,y+170),Vector2(x+110,y+170),lane,3)
	# Broad central muster plaza: every solid remains outside radius 780.
	canvas.draw_rect(Rect2(-640,-320,1280,640),pavement.darkened(0.12))
	if lab:
		for x in range(-600,601,120):
			canvas.draw_line(Vector2(x,-300),Vector2(x,300),Color(0.22,0.31,0.34,0.45),2)
		for y in range(-240,241,120):
			canvas.draw_line(Vector2(-620,y),Vector2(620,y),Color(0.22,0.31,0.34,0.45),2)
		canvas.draw_rect(Rect2(-180,-100,360,200),Color(0.35,0.62,0.62,0.45),false,5)
	else:
		canvas.draw_texture_rect(asphalt,Rect2(-640,-320,1280,640),true,Color(0.85,0.85,0.85))
		for side in [-1,1]:
			for x in range(-560,561,140):
				canvas.draw_line(Vector2(x,side*180),Vector2(x,side*290),lane,3)
			# Crosswalks leave the intersection readable without new obstacles.
			for x in range(-200,201,65):
				canvas.draw_rect(Rect2(x,side*370-25,35,50),Color(0.68,0.68,0.61,0.65))
	for i in SuburbLayout.LOTS.size():
		var lot: Vector2 = SuburbLayout.LOTS[i]
		var apron := access_apron(i)
		canvas.draw_rect(Rect2(lot-Vector2(185,150),Vector2(370,320)),pavement.lightened(0.025*float((i+variant)%2)))
		canvas.draw_rect(apron,pavement)
		# Loading/service bay next to the structure, not across its entrance.
		var bay := Rect2(lot+Vector2(-180,150),Vector2(360,70))
		canvas.draw_rect(bay,pavement.darkened(0.04))
		canvas.draw_rect(bay,lane,false,3)
		if lab:
			for x in range(0,340,60):
				canvas.draw_line(bay.position+Vector2(x,8),bay.position+Vector2(x+35,60),Color(0.62,0.57,0.28,0.45),5)
		else:
			canvas.draw_line(bay.position+Vector2(120,0),bay.position+Vector2(120,70),lane,2)
			canvas.draw_line(bay.position+Vector2(240,0),bay.position+Vector2(240,70),lane,2)

func add_props(parent: Node2D, index: int, variant: int) -> void:
	# Static decorations share one retained CanvasItem per chunk. They need no
	# per-prop node, transform updates, collision, or navigation obstacle.
	var canvas := parent.get_node_or_null("DistrictProps") as Node2D
	if canvas == null:
		canvas = Node2D.new()
		canvas.name = "DistrictProps"
		canvas.z_index = -1
		parent.add_child(canvas)
	canvas.draw.connect(func() -> void: _draw_props(canvas,index,variant))

func _draw_props(canvas: Node2D, index: int, variant: int) -> void:
	var lot: Vector2 = SuburbLayout.LOTS[index]
	var keys := ["console","drum","drum"] if theme_id == "lab" else ["wreck_car","dumpster","rubble","barrel"]
	var offsets := [Vector2(-95,185),Vector2(165,45),Vector2(165,120),Vector2(-160,130)]
	for i in keys.size():
		var key: String = keys[i]
		if theme_id == "city" and i==0 and (index+variant)%3==0:
			key = "barrier"
		var texture: Texture2D = props[key]
		var size := 120.0 if key == "wreck_car" else (86.0 if key == "console" or key == "dumpster" or key == "barrier" else 48.0)
		var extent := texture.get_size()*size/maxf(texture.get_width(),texture.get_height())
		var tint := Color(0.80,0.86,0.88) if theme_id == "lab" else Color(0.85,0.82,0.77)
		canvas.draw_texture_rect(texture,Rect2(lot+offsets[i]-extent*0.5,extent),false,tint)
