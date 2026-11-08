extends Node3D
## Пространство из рисованных фасадов и спрайтов. Метры, коллизии и единая камера.
var player: CharacterBody3D
var camera: Camera3D
var elapsed: float = 0.0
var foliage: Array[MeshInstance3D] = []
var points := {"clock": Vector3(7.8,5.4,-1.0), "key": Vector3(29.5,1.1,-125), "door": Vector3(24,1.4,-126.5)}
var surfaces: Texture2D
var facades: Texture2D
var sprites: Texture2D
var city_facades: Texture2D
var heritage: Texture2D
var urban_props: Texture2D
var urban_regions: Array = []
const ZONE_NAMES = ["ОЛЬХОВСК / ВОКЗАЛ", "СОБОРНАЯ ПЛОЩАДЬ", "ТОРГОВАЯ УЛИЦА", "СКВЕР У ДЕПО", "ОБЩЕЖИТИЕ / КОМНАТА № 4"]
const MATERIAL = preload("res://shaders/walk_surface.gdshader")

func _ready() -> void:
	surfaces = load("res://assets/walk/surfaces.png")
	facades = load("res://assets/walk/facades.png")
	sprites = load("res://assets/walk/trees.png")
	city_facades = load("res://assets/walk/city-facades.png")
	heritage = load("res://assets/walk/heritage-facades.png")
	urban_props = load("res://assets/walk/urban-props.png")
	urban_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/walk/urban-regions.json"))
	if has_node("Walker"):
		player = get_node("Walker")
		camera = player.get_node("Camera3D")
		for node in find_children("*", "MeshInstance3D", true, false):
			if node.has_meta("wind_tree") or node.has_meta("face_viewer"): foliage.append(node)
	else: _build()

func material(texture: Texture2D, cell: int = -1, cutout: bool = false, sway: float = 0.0, tint: Color = Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MATERIAL
	m.set_shader_parameter("artwork", texture)
	m.set_shader_parameter("cutout", cutout)
	m.set_shader_parameter("wind", sway)
	m.set_shader_parameter("phase", randf() * TAU)
	m.set_shader_parameter("tint", tint)
	if cell >= 0: m.set_shader_parameter("region", Vector4((cell % 2) * 0.5, floori(cell / 2.0) * 0.5, 0.5, 0.5))
	if texture == sprites and cell >= 0:
		m.set_shader_parameter("region", [Vector4(0,0,0.53,0.616),Vector4(0.53,0,0.47,0.616),Vector4(0,0.616,0.64,0.384),Vector4(0.70,0.616,0.24,0.384)][cell])
	return m

func panel(at: Vector3, size: Vector2, m: Material, yaw: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = m
	node.position = at
	node.rotation.y = yaw
	add_child(node)
	return node

func box(at: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.srgb_to_linear()
	node.material_override = m
	node.position = at
	add_child(node)
	if solid: collision(at, size)
	return node

func collision(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	add_child(body)
	return body

func ground(at: Vector3, size: Vector2, cell: int, tiles: Vector2) -> void:
	var m := material(surfaces, cell)
	m.set_shader_parameter("tiling", tiles)
	var node := panel(at, size, m)
	node.rotation.x = -PI / 2.0

func facade_material(cell: int) -> ShaderMaterial:
	if cell >= 8:
		var m := material(heritage)
		var row: float = 502.0/941.0 if cell >= 10 else 0.0
		var height: float = 439.0/941.0 if cell >= 10 else 500.0/941.0
		m.set_shader_parameter("region",Vector4((cell%2)*0.5,row,0.5,height))
		return m
	return material(city_facades,cell-4) if cell >= 4 else material(facades,cell)

func adopt(node: Node3D, parent: Node3D) -> void:
	remove_child(node)
	parent.add_child(node)

func building(at: Vector3, width: float, height: float, depth: float, cell: int, yaw: float = 0.0, title: String = "House") -> void:
	var house := Node3D.new()
	house.name = title
	add_child(house)
	house.position = at
	house.rotation.y = yaw
	var m := facade_material(cell)
	var is_arch: bool = cell == 6
	if is_arch:
		# Open central passage; the painted arch never conceals an invisible solid wall.
		for x in [-width*0.30,width*0.30]:
			adopt(box(Vector3(x,height/2,-depth/2),Vector3(width*0.4,height,depth),Color("433b2e")),house)
			adopt(collision(Vector3(x,height/2,-depth/2),Vector3(width*0.4,height,depth)),house)
		adopt(box(Vector3(0,height*0.775,-depth/2),Vector3(width*0.2,height*0.45,depth),Color("433b2e")),house)
		adopt(collision(Vector3(0,height*0.775,-depth/2),Vector3(width*0.2,height*0.45,depth)),house)
		for z in [0.03,-depth-0.03]:
			for section in [Rect2(0,0,1,0.55),Rect2(0,0.55,0.4,0.45),Rect2(0.6,0.55,0.4,0.45)]:
				var cropped: ShaderMaterial = m.duplicate()
				var region: Vector4 = cropped.get_shader_parameter("region")
				cropped.set_shader_parameter("region",Vector4(region.x+section.position.x*region.z,region.y+section.position.y*region.w,region.z*section.size.x,region.w*section.size.y))
				adopt(panel(Vector3((section.position.x+section.size.x/2-0.5)*width,(1-section.position.y-section.size.y/2)*height,z),Vector2(width*section.size.x,height*section.size.y),cropped),house)
	else:
		var shell := box(Vector3(0,height/2,-depth/2),Vector3(width,height,depth),Color("544731"))
		shell.material_override = material(surfaces,3,false,0.0,Color(0.65,0.63,0.57))
		adopt(shell,house)
		adopt(collision(Vector3(0,height/2,-depth/2),Vector3(width,height,depth)),house)
		adopt(panel(Vector3(0,height/2,0.03),Vector2(width,height),m),house)
		adopt(panel(Vector3(0,height/2,-depth-0.03),Vector2(width,height),facade_material(3),PI),house)
	for side in [-1,1]:
		adopt(panel(Vector3(side*(width/2+0.03),height/2,-depth/2),Vector2(depth,height),facade_material(3),side*PI/2),house)
	adopt(box(Vector3(0,height+0.08,-depth/2),Vector3(width+0.35,0.16,depth+0.35),Color("272b23")),house)

func tree(at: Vector3, cell: int, height: float, phase: float) -> void:
	var width: float = height * (0.68 if cell == 0 else 0.60)
	var m := material(sprites,cell,true,0.17 if cell == 0 else 0.085)
	m.set_shader_parameter("phase",phase)
	var leaf := panel(at + Vector3(0,height/2.0,0),Vector2(width,height),m)
	leaf.mesh.subdivide_depth = 12
	leaf.mesh.subdivide_width = 4
	leaf.set_meta("wind_tree",true)
	foliage.append(leaf)
	# A narrow trunk collider leaves the canopy free.
	collision(at+Vector3(0,0.9,0),Vector3(0.25,1.8,0.25))

func lamp(at: Vector3, green: bool = false) -> void:
	panel(at+Vector3(0,2.35,0),Vector2(2.1,4.7),material(sprites,3,true,0.0,Color(0.4,1.0,0.6) if green else Color.WHITE))
	var light := OmniLight3D.new()
	light.position = at + Vector3(0,3.5,0)
	light.light_color = Color("c6d8a5") if green else Color("efae53")
	light.light_energy = 1.2
	light.omni_range = 6.0
	add_child(light)
	# Warm painted pool on paving (unlit materials retain their authored colors).
	var glow := ShaderMaterial.new()
	glow.shader = load("res://shaders/walk_lamp.gdshader")
	glow.set_shader_parameter("light_color", Color("80956d") if green else Color("c68135"))
	var pool := panel(at+Vector3(0,0.035,0),Vector2(5.0,6.0),glow)
	pool.rotation.x = -PI/2.0
	collision(at+Vector3(0,1.0,0),Vector3(0.18,2,0.18))

func collect_nodes(first: int, title: String) -> void:
	var nodes: Array[Node] = get_children().slice(first)
	var group := Node3D.new()
	group.name = title
	add_child(group)
	for node in nodes:
		remove_child(node)
		group.add_child(node)

func bench(at: Vector3, yaw: float = 0.0) -> void:
	var seat := Node3D.new()
	seat.name = "Bench"
	add_child(seat)
	seat.position = at
	seat.rotation.y = yaw
	for z in [-0.2,0.0,0.2]:
		var board := box(Vector3(0,0.55,z),Vector3(2.2,0.10,0.17),Color("5a4228"))
		board.material_override = material(surfaces,2)
		adopt(board,seat)
	for y in [0.85,1.12]:
		var board := box(Vector3(0,y,-0.28),Vector3(2.2,0.19,0.08),Color("5a4228"))
		board.material_override = material(surfaces,2)
		adopt(board,seat)
	for x in [-0.82,0.82]: adopt(box(Vector3(x,0.28,0),Vector3(0.09,0.55,0.5),Color("252b24")),seat)
	adopt(collision(Vector3(0,0.6,0),Vector3(2.2,1.2,0.7)),seat)

func paved(rect: Rect2, height: float = 0.02) -> void:
	ground(Vector3(rect.get_center().x,height,rect.get_center().y),rect.size,0,rect.size/3.4)

func road(rect: Rect2, vertical: bool = true) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/city_asphalt.gdshader")
	var surface := panel(Vector3(rect.get_center().x,0.031,rect.get_center().y),rect.size,m)
	surface.rotation.x = -PI/2
	var length: float = rect.size.y if vertical else rect.size.x
	for side in [-1,1]:
		if vertical: box(Vector3(rect.get_center().x+side*rect.size.x/2,0.07,rect.get_center().y),Vector3(0.13,0.12,length),Color("797565"))
		else: box(Vector3(rect.get_center().x,0.07,rect.get_center().y+side*rect.size.y/2),Vector3(length,0.12,0.13),Color("797565"))
	for i in range(int(length/5)):
		var at: Vector3 = Vector3(rect.get_center().x,0.037,rect.position.y+2+i*5) if vertical else Vector3(rect.position.x+2+i*5,0.037,rect.get_center().y)
		box(at,Vector3(0.07,0.005,1.6) if vertical else Vector3(1.6,0.005,0.07),Color("999176"))

func crossing(at: Vector3, across_z: bool, span: float = 7.0) -> void:
	for i in 7:
		var offset: float = (i-3)*0.85
		var p: Vector3 = at+Vector3(offset,0.045,0) if across_z else at+Vector3(0,0.045,offset)
		box(p,Vector3(0.5,0.008,span) if across_z else Vector3(span,0.008,0.5),Color("b2aa91"))

func planter(at: Vector3) -> void:
	var pot := box(at+Vector3(0,0.25,0),Vector3(1.5,0.5,1.1),Color("665b42"),true)
	pot.material_override = material(surfaces,3,false,0,Color(0.65,0.65,0.55))
	panel(at+Vector3(0,0.78,0),Vector2(1.7,1.0),material(sprites,2,true,0.06))

func lawn(rect: Rect2) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/city_grass.gdshader")
	var patch := panel(Vector3(rect.get_center().x,0.027,rect.get_center().y),rect.size,m)
	patch.rotation.x = -PI/2

func urban_prop(cell: int, at: Vector3, height: float, yaw: float, title: String) -> void:
	var region: Array = urban_regions[cell]
	var aspect: float = float(region[2])/float(region[3]) * urban_props.get_width()/float(urban_props.get_height())
	var width: float = height*aspect
	var m := material(urban_props,-1,true)
	m.set_shader_parameter("region",Vector4(region[0],region[1],region[2],region[3]))
	var sprite := panel(at+Vector3(0,height/2,0),Vector2(width,height),m,yaw)
	sprite.name = title
	if cell < 2:
		sprite.set_meta("face_viewer",true)
		foliage.append(sprite)
	collision(at+Vector3(0,height*0.35,0),Vector3(maxf(0.5,width*0.65),height*0.7,0.8 if cell > 1 else 1.6))

func cathedral(at: Vector3) -> void:
	var group := Node3D.new()
	group.name = "Cathedral"
	add_child(group)
	group.position = at
	var art := material(load("res://assets/walk/church.png"),-1,true)
	var crop: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/walk/church-region.json"))
	art.set_shader_parameter("region",Vector4(crop[0],crop[1],crop[2],crop[3]))
	adopt(panel(Vector3(0,8,0.05),Vector2(26,16),art),group)
	adopt(panel(Vector3(0,8,-22.05),Vector2(26,16),art,PI),group)
	var body := box(Vector3(0,3.4,-11),Vector3(23,6.8,22),Color("77796d"))
	body.material_override = material(surfaces,3,false,0,Color(0.9,0.9,0.82))
	adopt(body,group)
	adopt(collision(Vector3(0,3.4,-11),Vector3(23,6.8,22)),group)
	for side in [-1,1]:
		adopt(panel(Vector3(side*11.53,3.4,-11),Vector2(22,6.8),facade_material(9),side*PI/2),group)
	adopt(box(Vector3(0,6.9,-11),Vector3(23.3,0.2,22.3),Color("3f4c3e")),group)

func water_tower(at: Vector3) -> void:
	var node := panel(at+Vector3(0,8.5,0),Vector2(6,17),facade_material(11))
	node.name = "WaterTower"
	collision(at+Vector3(0,8.5,-2.0),Vector3(6,17,4))
	var backing := box(at+Vector3(0,8.5,-2.0),Vector3(6,17,4),Color("62482f"))
	backing.material_override = facade_material(11)

func fence(a: Vector3, b: Vector3) -> void:
	var length: float = a.distance_to(b)
	var steps: int = ceili(length/3)
	var yaw: float = atan2(-(b.x-a.x),-(b.z-a.z))
	for i in steps:
		var p: Vector3 = a.lerp(b,i/float(steps))
		box(p+Vector3(0,0.85,0),Vector3(0.12,1.7,0.12),Color("353a2c"))
		var rail := box(a.lerp(b,(i+0.5)/float(steps))+Vector3(0,0.8,0),Vector3(0.09,0.08,length/steps),Color("414735"))
		rail.rotation.y = yaw
	var size := Vector3(absf(b.x-a.x)+0.15,2,absf(b.z-a.z)+0.15)
	collision((a+b)/2+Vector3(0,1,0),size)

func _build() -> void:
	seed(48197)
	var env_node := WorldEnvironment.new()
	env_node.name = "AutumnSky"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/walk_sky.gdshader")
	sky_material.set_shader_parameter("cloud_painting",load("res://assets/train-horizon-v2.png"))
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9a187")
	env.ambient_light_energy = 0.7
	env_node.environment = env
	add_child(env_node)
	var first: int = get_child_count()
	ground(Vector3(0,-0.04,-56),Vector2(130,190),1,Vector2(30,43))
	collision(Vector3(0,-0.25,-56),Vector3(130,0.4,190))
	for rect in [Rect2(-2,-24,10,44),Rect2(-6,-38,14,22),Rect2(-38,-58,71,30),Rect2(13,-109,22,61),Rect2(-29,-109,17,57),Rect2(-43,-110,82,16),Rect2(4,-132,38,24),Rect2(31,-70,24,14),Rect2(-38,-88,13,30)]: paved(rect)
	road(Rect2(24,-109,7,56))
	road(Rect2(-23.5,-109,5.5,56))
	road(Rect2(-43,-105,82,6),false)
	road(Rect2(31,-67,24,6),false)
	crossing(Vector3(19,0,-102),true,6.0)
	crossing(Vector3(27.5,0,-56),false)
	crossing(Vector3(-21,0,-56),false,5.5)
	lawn(Rect2(6,-122,8,11))
	lawn(Rect2(25,-119,8,7))
	box(Vector3(-1.6,0.12,-2),Vector3(0.18,0.24,36),Color("90836b"),true)
	collect_nodes(first,"StreetsAndSidewalks")
	first = get_child_count()
	building(Vector3(8,0,-5),13,7,7,0,-PI/2,"Station")
	building(Vector3(-12,0,-9),12,6,8,3,PI/2,"StationStorehouse")
	building(Vector3(17,0,-30),17,8.5,10,4,-PI/2,"OldPharmacy")
	building(Vector3(-44,0,-56),17,8,9,5,0,"ClosedGrocery")
	cathedral(Vector3(-1.5,0,-60))
	building(Vector3(35,0,-71),25,8.5,12,8,-PI/2,"MerchantStreet")
	building(Vector3(35,0,-101),20,10,12,3,-PI/2,"CornerHouse")
	building(Vector3(-33,0,-71),20,10,13,6,0,"ArchPassage")
	building(Vector3(-36,0,-102),20,7,9,10,0,"WoodenCourtyardHouse")
	building(Vector3(-50,0,-37),24,9,8,3,PI/2,"ParkHouse")
	building(Vector3(-8,0,-124),20,8,13,2,0,"TramDepot")
	building(Vector3(-32,0,-128),18,6,10,2,0,"DepotWorkshop")
	building(Vector3(24,0,-127),18,11,10,1,0,"Hostel")
	building(Vector3(-40,0,-42),15,7,10,8,PI/2,"WesternTradingArcade")
	building(Vector3(-34,0,-28),18,7.5,10,9,PI,"PostOffice")
	building(Vector3(35,0,-49),15,7,10,8,-PI/2,"EasternTradingArcade")
	building(Vector3(35,0,-119),12,6,10,10,-PI/2,"GardenHouse")
	building(Vector3(-44,0,-115),13,5,8,10,0,"CarvedTimberHouse")
	building(Vector3(-25,0,16),14,6,10,10,PI,"StationResidentialHouse")
	building(Vector3(33,0,12),14,7,9,7,PI,"StationCornerHouse")
	building(Vector3(-28,0,-120),12,3,5,2,0,"CourtyardGarages")
	water_tower(Vector3(-18,0,-115))
	collect_nodes(first,"Buildings")
	first = get_child_count()
	for at in [Vector3(6,0,8),Vector3(6,0,-12),Vector3(6.5,0,-28),Vector3(-22,0,-36),Vector3(20,0,-47),Vector3(23,0,-65),Vector3(23,0,-87),Vector3(-16,0,-57),Vector3(-16,0,-89),Vector3(4,0,-98),Vector3(31,0,-113),Vector3(33,0,-122)]:
		lamp(at,at == Vector3(20,0,-47))
	for at in [Vector3(-23,0,-44),Vector3(-31,0,-38),Vector3(8,0,-47),Vector3(31,0,-115),Vector3(16,0,-65),Vector3(16,0,-84),Vector3(12,0,-113),Vector3(-31,0,-91)]: bench(at)
	bench(Vector3(-27,0,-48),PI/2)
	for at in [Vector3(15,0,-56),Vector3(15,0,-73),Vector3(15,0,-91),Vector3(11,0,-110),Vector3(29,0,-119),Vector3(-29,0,-33),Vector3(9,0,-46)]: planter(at)
	urban_prop(2,Vector3(-29,0,-34),2.8,0,"NewspaperKiosk")
	urban_prop(3,Vector3(30,0,-41),2.8,0,"CentreBusStop")
	urban_prop(4,Vector3(8,0,-30),2.3,0,"PublicTelephone")
	urban_prop(5,Vector3(-29,0,-94),2.7,0,"CourtyardSwings")
	for at in [Vector3(-8,0,-19),Vector3(29,0,-72),Vector3(-20,0,-75),Vector3(35,0,-104),Vector3(-41,0,-92),Vector3(40,0,-111)]:
		urban_prop(0,at,1.55,0,"ParkedCar")
	urban_prop(1,Vector3(-47,0,-51),2.2,0,"MarketDeliveryVan")
	urban_prop(1,Vector3(28,0,-92),2.2,0,"ParkedVan")
	# Low garden fences and bollards frame public spaces without closing the footpath.
	for z in [-112,-115,-118]:
		for x in [9,34]: box(Vector3(x,0.6,z),Vector3(0.1,1.2,0.12),Color("3c4436"))
	for x in [-5,-2,2,5,8,11]: box(Vector3(x,0.4,-29),Vector3(0.14,0.8,0.14),Color("34392f"),true)
	# Dry fountain, rubbish bins and old crates give the square a human scale.
	var fountain := MeshInstance3D.new()
	var bowl := CylinderMesh.new()
	bowl.top_radius = 2.1
	bowl.bottom_radius = 2.3
	bowl.height = 0.45
	bowl.radial_segments = 16
	fountain.mesh = bowl
	fountain.material_override = material(surfaces,3,false,0,Color(0.45,0.45,0.39))
	fountain.position = Vector3(-12,0.23,-43)
	fountain.name = "DryFountain"
	add_child(fountain)
	collision(Vector3(-12,0.4,-43),Vector3(4.3,0.8,4.3))
	box(Vector3(-12,1.0,-43),Vector3(0.45,1.7,0.45),Color("55523f"))
	for at in [Vector3(7,0.5,-12),Vector3(-31,0.5,-39),Vector3(30,0.5,-86),Vector3(33,0.5,-121)]:
		var bin := box(at,Vector3(0.65,1,0.65),Color("344035"),true)
		bin.name = "LitterBin"
	for i in 5:
		var crate := box(Vector3(-21+i*1.1,0.4,-119),Vector3(0.9,0.8,0.8),Color("4c3c28"),true)
		crate.material_override = material(surfaces,2)
	collect_nodes(first,"StreetFurniture")
	first = get_child_count()
	for i in 84:
		var z: float = 24-i*2.0
		for side in [-1,1]:
			var x: float = side*randf_range(48,58)
			tree(Vector3(x,0,z),i%2,randf_range(10,16),randf()*TAU)
	for at in [Vector3(-20,0,-36),Vector3(-28,0,-40),Vector3(-33,0,-47),Vector3(12,0,-48),Vector3(15,0,-88),Vector3(-28,0,-91),Vector3(-30,0,-95),Vector3(9,0,-106),Vector3(40,0,-117),Vector3(-44,0,-114)]:
		tree(at,0,randf_range(8,12),randf()*TAU)
	for at in [Vector3(9,0,-116),Vector3(27,0,-115)]: tree(at,0,9,randf()*TAU)
	for i in 42:
		var z: float = 15-i*3.5
		var x: float = -42 if i%2==0 else 45
		panel(Vector3(x,0.8,z),Vector2(3.6,1.6),material(sprites,2,true,0.07))
	collect_nodes(first,"TreesAndBushes")
	first = get_child_count()
	fence(Vector3(-57,0,23),Vector3(57,0,23))
	fence(Vector3(-57,0,-142),Vector3(57,0,-142))
	fence(Vector3(-57,0,-142),Vector3(-57,0,23))
	fence(Vector3(57,0,-142),Vector3(57,0,23))
	collect_nodes(first,"TownBoundary")
	player = CharacterBody3D.new()
	player.name = "Walker"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.72
	collider.shape = capsule
	collider.position.y = 0.86
	player.add_child(collider)
	add_child(player)
	player.position = Vector3(0,0.08,6)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.68
	camera.fov = 68
	camera.far = 180
	camera.near = 0.08
	player.add_child(camera)
	camera.current = true
	_make_key()

func _make_key() -> void:
	box(Vector3(29.5,0.9,-125),Vector3(1.1,0.12,0.8),Color("4d3824"),true)
	var key := Node3D.new()
	key.name = "RoomKey"
	key.position = points["key"]
	add_child(key)
	var stem := box(Vector3.ZERO,Vector3(0.2,0.025,0.04),Color("c3984b"))
	adopt(stem,key)
	var fob := box(Vector3(0.14,0,0),Vector3(0.12,0.025,0.16),Color("232b27"))
	adopt(fob,key)

func _process(delta: float) -> void:
	elapsed += delta
	if not is_instance_valid(camera): return
	for leaf in foliage:
		var difference: Vector3 = camera.global_position-leaf.global_position
		leaf.rotation.y = atan2(difference.x,difference.z)

func location_for_position(at: Vector3) -> int:
	if at.z < -111 and at.x > 4: return 4
	if at.z < -94: return 3
	if at.z < -54: return 2
	if at.z < -24: return 1
	return 0

func target_nearby() -> String:
	var best: String = ""
	var distance: float = 2.6
	for id in points:
		if id == "key" and not get_node("RoomKey").visible: continue
		var p: Vector3 = points[id]
		var d: float = Vector2(player.position.x-p.x,player.position.z-p.z).length()
		var direction: Vector3 = (p-camera.global_position).normalized()
		if d < distance and direction.dot(-camera.global_basis.z) > 0.25:
			distance = d
			best = id
	return best
