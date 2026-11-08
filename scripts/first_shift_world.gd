extends "res://scripts/arrival_world.gd"
## Редактируемый маршрут: окраина, лес у больницы, старые дачи и возвращение к депо.
const STOPS = [90.0,225.0,380.0]

func _ready() -> void:
	points = {}
	super._ready()

func track_x(distance: float) -> float:
	return sin(distance*0.012)*5.0+sin(distance*0.035)*0.8

func set_distance(distance: float, look: Vector2) -> void:
	player.position=Vector3(track_x(distance),0,-distance)
	var tangent: float = (track_x(distance+0.5)-track_x(distance-0.5))
	player.rotation.y=-atan(tangent)
	camera.rotation=Vector3(look.y,-look.x,0)

func material(texture: Texture2D, cell: int = -1, cutout: bool = false, sway: float = 0.0, tint: Color = Color.WHITE) -> ShaderMaterial:
	var m := super.material(texture,cell,cutout,sway,tint)
	m.set_shader_parameter("mist_color",Vector3(0.105,0.16,0.145))
	return m

func rail_segment(a: Vector3, b: Vector3, offset: float) -> void:
	var middle: Vector3 = (a+b)*0.5
	middle.x+=offset
	var rail := box(middle,Vector3(0.065,0.10,a.distance_to(b)+0.035),Color("93917b"))
	rail.rotation.y=-atan2(b.x-a.x,a.z-b.z)

func waiting_passenger(index: int, at: Vector3) -> void:
	var tex: Texture2D=load("res://assets/tram-passengers-v1.png")
	var m := material(tex,-1,true)
	m.set_shader_parameter("region",Vector4(index/3.0,0,1.0/3.0,1))
	var passenger := panel(at+Vector3(0,0.78,0),Vector2(1.15,1.55),m)
	passenger.name="WaitingPassenger"+str(index)
	passenger.set_meta("face_viewer",true)
	foliage.append(passenger)

func board_passenger(index: int) -> void:
	var person := find_child("WaitingPassenger"+str(index),true,false)
	if person: person.hide()

func near_stop(distance: float, clearance: float = 9.0) -> bool:
	for stop in STOPS:
		if absf(distance-stop)<clearance: return true
	return false

func brush(at: Vector3, width: float, height: float, tint: Color) -> void:
	var shrub := panel(at+Vector3(0,height*0.47,0),Vector2(width,height),material(sprites,2,true,0.08,tint))
	shrub.name="Underbrush"
	shrub.mesh.subdivide_width=3
	shrub.mesh.subdivide_depth=3
	shrub.visibility_range_end=85
	shrub.set_meta("face_viewer",true)
	foliage.append(shrub)

func garden_fence(at: Vector3, length: float) -> void:
	for level in [0.35,0.85]:
		var board := box(at+Vector3(0,level,0),Vector3(0.12,0.21,length),Color("5c5841"))
		board.material_override=material(surfaces,2,false,0,Color(0.65,0.73,0.62))
	for offset in [-length/2,0,length/2]:
		box(at+Vector3(0,0.6,offset),Vector3(0.18,1.2,0.18),Color("404b39"))

func _build() -> void:
	seed(6740)
	var env_node := WorldEnvironment.new()
	env_node.name="DawnSky"
	var env := Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_m := ShaderMaterial.new()
	sky_m.shader=load("res://shaders/station_sky.gdshader")
	sky_m.set_shader_parameter("cloud_painting",load("res://assets/train-horizon-v2.png"))
	sky.sky_material=sky_m
	env.sky=sky
	env_node.environment=env
	add_child(env_node)
	var first: int=get_child_count()
	ground(Vector3(0,-0.10,-250),Vector2(85,600),1,Vector2(28,200))
	for distance in range(-24,530,4):
		var a := Vector3(track_x(float(distance)),0.04,-float(distance))
		var b := Vector3(track_x(float(distance+4)),0.04,-float(distance+4))
		var bed := panel((a+b)*0.5-Vector3(0,0.03,0),Vector2(5.8,4.1),material(surfaces,0 if distance<155 or distance>315 else 1))
		bed.rotation=Vector3(-PI/2,0,atan2(b.x-a.x,a.z-b.z))
		if distance>=155 and distance<=315:
			for side in [-1,1]:
				var grass := ShaderMaterial.new()
				grass.shader=load("res://shaders/station_grass.gdshader")
				var bank := panel((a+b)*0.5+Vector3(side*13.0,-0.015,0),Vector2(20.0,4.15),grass)
				bank.rotation=bed.rotation
		rail_segment(a,b,-0.72)
		rail_segment(a,b,0.72)
		if distance>=155 and distance<=315:
			var tie := box(a-Vector3(0,0.065,0),Vector3(2.0,0.08,0.22),Color("3a3528"))
			tie.rotation.y=-atan2(b.x-a.x,a.z-b.z)
	collect_nodes(first,"TrackAndRoad")
	first=get_child_count()
	for i in range(28):
		var distance: float=i*18.0-12
		if distance>150 and distance<320: continue
		for side in [-1,1]:
			var cell: int=10 if i%3==0 else (7 if i%3==1 else 3)
			if i==4: cell=5
			building(Vector3(track_x(distance)+side*(7.0+(i%2)),0,-distance),16.5,5.5+(i%3),7,cell,side*-PI/2,"RouteHouse"+str(i)+("L" if side<0 else "R"))
	collect_nodes(first,"TownBuildings")
	first=get_child_count()
	# Three staggered tree lines enclose the route through the forest and its approaches.
	for row in range(3):
		var spacing: float=6.0+row*1.5
		for i in range(int(234.0/spacing)+1):
			var distance: float=122.0+i*spacing+row*2.5
			for side in [-1,1]:
				if row==0 and side==1 and near_stop(distance,9): continue
				var offset: float=5.2+row*6.2+randf_range(-0.7,0.7)
				var height: float=randf_range(9.5,13.0)+row*1.6
				tree(Vector3(track_x(distance)+side*offset,-0.30,-distance),1 if (i+row)%3!=0 else 0,height,float(i+row*41+side))
	# Street trees break up the roofline without hiding the station shelters.
	for i in range(48):
		var distance: float=i*11.0-15
		if distance>120 and distance<360: continue
		var side: int=-1 if i%2==0 else 1
		tree(Vector3(track_x(distance)+side*5.2,-0.2,-distance),0,8.5+(i%3),float(i))
	collect_nodes(first,"RouteTrees")
	first=get_child_count()
	# Near undergrowth closes the bare grass strips, with clear boarding areas at stops.
	for i in range(63):
		var distance: float=112+i*4.0
		for side in [-1,1]:
			var clear: bool=side==1 and near_stop(distance,8)
			if not clear:
				brush(Vector3(track_x(distance)+side*randf_range(3.6,4.8),0,-distance),randf_range(3.3,4.8),randf_range(1.1,1.9),Color(0.64,0.80,0.64))
			brush(Vector3(track_x(distance)+side*randf_range(8.0,10.5),0,-distance-1.5),randf_range(4.8,6.8),randf_range(1.9,2.8),Color(0.48,0.67,0.57))
	collect_nodes(first,"ForestUnderbrush")
	first=get_child_count()
	for i in range(65):
		var distance: float=i*8.0-12
		if distance>135 and distance<348: continue
		for side in [-1,1]:
			if side==1 and near_stop(distance,10): continue
			brush(Vector3(track_x(distance)+side*5.4,0,-distance),3.7,1.05,Color(0.78,0.87,0.69))
			if i%2==0: garden_fence(Vector3(track_x(distance)+side*4.6,0,-distance),6.0)
	collect_nodes(first,"StreetGardens")
	first=get_child_count()
	for i in range(3):
		var d: float=STOPS[i]
		ground(Vector3(track_x(d)+4.5,0.025,-d),Vector2(4,14),0,Vector2(1.7,5.8))
		urban_prop(3,Vector3(track_x(d)+5.3,0,-d-2),2.6,-PI/2,"StopShelter"+str(i))
		waiting_passenger(i,Vector3(track_x(d)+3.6,0,-d-1))
		lamp(Vector3(track_x(d)+5.5,0,-d+4))
	collect_nodes(first,"PassengerStops")
	first=get_child_count()
	var wire_material := StandardMaterial3D.new()
	wire_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	wire_material.albedo_color=Color("263a30")
	for i in range(22):
		var d: float=i*24.0
		box(Vector3(track_x(d)-3.0,3.6,-d),Vector3(0.14,7.2,0.14),Color("3c4940"))
		box(Vector3(track_x(d)-1.5,6.6,-d),Vector3(3.0,0.10,0.10),Color("3c4940"))
		if i<21:
			var a := Vector3(track_x(d),6.5,-d)
			var b := Vector3(track_x(d+24),6.5,-d-24)
			var wire := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius=0.018
			mesh.bottom_radius=0.018
			mesh.height=a.distance_to(b)
			mesh.radial_segments=5
			wire.mesh=mesh
			wire.material_override=wire_material
			wire.position=(a+b)*0.5
			wire.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
			add_child(wire)
	collect_nodes(first,"ContactPoles")
	building(Vector3(track_x(455)+7,0,-455),15,6,9,2,-PI/2,"OldDepot")
	player=CharacterBody3D.new()
	player.name="Walker"
	add_child(player)
	camera=Camera3D.new()
	camera.name="Camera3D"
	camera.position=Vector3(0,1.65,0)
	camera.fov=75
	camera.near=0.05
	camera.far=160
	player.add_child(camera)
	camera.current=true
