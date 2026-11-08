extends "res://scripts/arrival_world.gd"
## Открытый перрон: пути слева, кирпичный вокзал за полосой травы справа.

func _ready() -> void:
	points = {}
	super._ready()

func location_for_position(_at: Vector3) -> int:
	return 0

func material(texture: Texture2D, cell: int = -1, cutout: bool = false, sway: float = 0.0, tint: Color = Color.WHITE) -> ShaderMaterial:
	var m := super.material(texture,cell,cutout,sway,tint)
	m.set_shader_parameter("mist_color",Vector3(0.17,0.24,0.22))
	if texture == surfaces and cell == 0:
		m.set_shader_parameter("desaturation",0.8)
	return m

func brick_station(at: Vector3) -> void:
	var station := Node3D.new()
	station.name = "Station"
	add_child(station)
	station.position = at
	station.rotation.y = -PI/2
	var art: Texture2D = load("res://assets/walk/station-brick-v1.png")
	var width: float = 20.0
	var height: float = 5.6
	var depth: float = 7.0
	var shell := box(Vector3(0,height/2,-depth/2),Vector3(width,height,depth),Color("514332"))
	adopt(shell,station)
	adopt(collision(Vector3(0,height/2,-depth/2),Vector3(width,height,depth)),station)
	var front := panel(Vector3(0,height/2,0.035),Vector2(width,height),material(art))
	front.name = "BrickFacade"
	adopt(front,station)
	adopt(panel(Vector3(0,height/2,-depth-0.035),Vector2(width,height),material(art),PI),station)
	for side in [-1,1]:
		var end_wall := material(art)
		end_wall.set_shader_parameter("region",Vector4(0.68,0,0.32,1))
		adopt(panel(Vector3(side*(width/2+0.035),height/2,-depth/2),Vector2(depth,height),end_wall,side*PI/2),station)
	adopt(box(Vector3(0,height+0.04,-depth/2),Vector3(width+0.15,0.08,depth+0.15),Color("39433a")),station)

func railway_mast(z: float) -> void:
	box(Vector3(-2.0,3.1,z),Vector3(0.22,6.2,0.22),Color("a2b0a7"),true)
	box(Vector3(-3.85,5.75,z),Vector3(3.9,0.12,0.12),Color("45594e"))
	for x in [-4.1,-5.35]:
		box(Vector3(x,5.56,z),Vector3(0.16,0.32,0.16),Color("a0aa95"))

func cable(a: Vector3, b: Vector3) -> void:
	var wire := MeshInstance3D.new()
	wire.name = "OverheadWire"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.014
	mesh.bottom_radius = 0.014
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 5
	wire.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("22271f").srgb_to_linear()
	wire.material_override = m
	wire.position = (a+b)/2
	wire.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	add_child(wire)

func gate(at: Vector3, yaw: float) -> void:
	var wood := box(at+Vector3(0,1.0,0),Vector3(1.7,2,0.12),Color("4b4935"))
	wood.material_override = material(surfaces,2,false,0,Color(0.52,0.57,0.47))
	wood.rotation.y = yaw
	collision(at+Vector3(0,1,0),Vector3(0.14,2,1.7))

func _build() -> void:
	seed(1217)
	var environment_node := WorldEnvironment.new()
	environment_node.name = "AutumnSky"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/station_sky.gdshader")
	sky_material.set_shader_parameter("cloud_painting",load("res://assets/train-horizon-v2.png"))
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a2b5ac")
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	add_child(environment_node)
	var first: int = get_child_count()
	ground(Vector3(0,-0.20,-8),Vector2(70,130),1,Vector2(23,43))
	# The platform remains open along its entire length; there are no town buildings here.
	ground(Vector3(0,0.01,-12),Vector2(3.6,100),0,Vector2(1.5,41.6))
	collision(Vector3(0,-0.25,-12),Vector3(70,0.4,130))
	ground(Vector3(-4.8,-0.10,-8),Vector2(4.4,110),1,Vector2(2.2,48))
	box(Vector3(-1.85,-0.02,-12),Vector3(0.20,0.32,100),Color("a4ad9b"),true)
	# A painted light strip marks the platform edge, without a tall fence.
	box(Vector3(-1.57,0.026,-12),Vector3(0.11,0.012,100),Color("c2c3a7"))
	for z in range(-61,46):
		var tie := box(Vector3(-4.7,-0.055,z),Vector3(2.6,0.07,0.17),Color("363429"))
		tie.material_override=material(surfaces,2,false,0,Color(0.5,0.48,0.4))
	for x in [-5.45,-3.95]: box(Vector3(x,0.0,-8),Vector3(0.06,0.10,110),Color("66756a"))
	for z in range(-54,43,12): railway_mast(z)
	for x in [-4.1,-5.35]:
		for z in range(-54,42,12):
			for step in range(6):
				var start: float = z+step*2.0
				var y0: float = 5.4-0.18*sin(step*PI/6)
				var y1: float = 5.4-0.18*sin((step+1)*PI/6)
				cable(Vector3(x,y0,start),Vector3(x,y1,start+2))
	collect_nodes(first,"PlatformAndExit")
	first = get_child_count()
	brick_station(Vector3(8.5,0,-18))
	collect_nodes(first,"Buildings")
	first = get_child_count()
	var verge_material := ShaderMaterial.new()
	verge_material.shader=load("res://shaders/station_grass.gdshader")
	var verge := panel(Vector3(5.15,0.025,-12),Vector2(6.7,100),verge_material)
	verge.name="GrassyVerge"
	verge.rotation.x=-PI/2
	var outside := panel(Vector3(-16,0.02,-12),Vector2(18,110),verge_material)
	outside.rotation.x=-PI/2
	# The station doorway and the town exit each have a modest path across the verge.
	ground(Vector3(5.15,0.035,-18),Vector2(6.7,2.2),0,Vector2(2.8,0.9))
	ground(Vector3(6.0,0.035,-34),Vector2(12,3.6),0,Vector2(5,1.5))
	for z in range(-60,38,4):
		if abs(z+18)<3 or abs(z+34)<3: continue
		var bush := panel(Vector3(4.2+float(z%3)*0.18,0.48,z),Vector2(2.0,1.05),material(sprites,2,true,0.06,Color(0.60,0.77,0.63)))
		bush.name="LowShrub"
	collect_nodes(first,"GrassAndShrubs")
	first = get_child_count()
	bench(Vector3(1.22,0,-22),-PI/2)
	for z in [-9,-25]:
		var bin := box(Vector3(1.3,0.40,z),Vector3(0.40,0.80,0.40),Color("4c6d72"),true)
		bin.name="PlatformBin"
	collect_nodes(first,"PlatformDetails")
	first = get_child_count()
	# Distant trees frame the railway beyond the open station grounds.
	for i in range(9):
		tree(Vector3(-15.0-(i%3)*3.0,-0.4,-48.0+i*10.0),1,8.0+(i%3),float(i))
	collect_nodes(first,"TreesAndBushes")
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
	player.position = Vector3(0,0.08,-12)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.68
	camera.fov = 68
	camera.far = 85
	camera.near = 0.08
	player.add_child(camera)
	camera.current = true
