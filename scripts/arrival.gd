extends Node2D
## Прогулка по непрерывной локации. Рисованные спрайты в пространстве с коллизиями.
signal location_changed(index: int)
@export var sound_enabled: bool = true
@export var walk_speed: float = 2.8
@export var mouse_sensitivity: float = 0.0024
@export var city_entry_z: float = -31.5
@export var story_fade_duration: float = 1.2
@onready var phone = $Interface/Phone
var world
var world_view: SubViewport
var screen: TextureRect
var location_index: int = 0
var elapsed: float = 0.0
var location_elapsed: float = 0.0
var key_taken: bool = false
var clock_inspected: bool = false
var notice: String = ""
var notice_until: float = 0.0
var wind: AudioStreamPlayer
var thought: Label
var chapter: Label
var inventory: Label
var controls: Label
var interaction: Label
var crosshair: Label
var fade: ColorRect
var look_button: Button
var pitch: float = -0.025
var step_time: float = 0.0
var was_phone_open: bool = false
var look_active: bool = false
var story_transitioning: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().title = "Последний трамвай — прогулка по Ольховску"
	world_view = SubViewport.new()
	world_view.name = "PaintedWorld"
	world_view.size = Vector2i(960,540)
	world_view.own_world_3d = true
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_view)
	world = load("res://CityApproach.tscn").instantiate()
	world_view.add_child(world)
	# A few steps toward the town, then the evening continues as first-person narration.
	world.player.position = Vector3(0,0.08,-12)
	world.player.rotation.y = 0.0
	screen = TextureRect.new()
	screen.name = "WorldImage"
	screen.texture = world_view.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	move_child(screen,0)
	phone.story_active = true
	phone.sound_enabled = sound_enabled
	phone.set_phone_rect(Rect2())
	_build_interface()
	_create_audio()
	get_viewport().size_changed.connect(_fit)
	_fit()
	fade.modulate.a = 1.0
	create_tween().tween_property(fade,"modulate:a",0.0,0.9)
	capture_look.call_deferred()

func _loop(path: String, volume: float, node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	var stream: AudioStreamWAV = load(path).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	if sound_enabled: player.play()
	return player

func _create_audio() -> void:
	wind = _loop("res://assets/audio/autumn-platform-wind.wav",-16.0,"AutumnWind")

func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0.015,0.025,0.02,0.9))
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Interface.add_child(label)
	return label

func _build_interface() -> void:
	chapter = _label(13,Color("d1c6a5"))
	chapter.position = Vector2(25,20)
	inventory = _label(14,Color("d5bd82"))
	inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	thought = _label(18,Color("e1dac3"))
	thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls = _label(13,Color("b2b8a3"))
	look_button = Button.new()
	look_button.text = "Осмотреться мышью"
	look_button.focus_mode = Control.FOCUS_NONE
	look_button.add_theme_font_size_override("font_size",14)
	look_button.pressed.connect(capture_look)
	$Interface.add_child(look_button)
	interaction = _label(17,Color("e4ce93"))
	interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair = _label(14,Color(0.9,0.88,0.74,0.5))
	crosshair.text = "·"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	$Interface.add_child(fade)

func _fit() -> void:
	var view: Vector2 = get_viewport_rect().size
	screen.size = view
	thought.position = Vector2(view.x*0.16,view.y-132)
	thought.size = Vector2(view.x*0.68,70)
	controls.position = Vector2(25,view.y-35)
	controls.size = Vector2(view.x-50,26)
	interaction.position = Vector2(view.x*0.2,view.y*0.55)
	interaction.size = Vector2(view.x*0.6,36)
	crosshair.position = view*0.5-Vector2(8,12)
	crosshair.size = Vector2(16,24)
	inventory.position = Vector2(view.x-300,21)
	inventory.size = Vector2(275,28)
	look_button.position = Vector2(view.x-235,55)
	look_button.size = Vector2(210,34)

func _process(delta: float) -> void:
	if story_transitioning: return
	elapsed += delta
	location_elapsed += delta
	if phone.phone_open != was_phone_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if phone.phone_open or not look_active else Input.MOUSE_MODE_CAPTURED
		was_phone_open = phone.phone_open
	var index: int = world.location_for_position(world.player.position)
	if index != location_index:
		location_index = index
		location_elapsed = 0.0
		location_changed.emit(index)
	_update_interface()
	if world.player.position.z <= city_entry_z and not phone.phone_open:
		begin_evening_story()

func movement_vector() -> Vector2:
	if phone.phone_open or story_transitioning: return Vector2.ZERO
	return Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).limit_length()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.player): return
	if story_transitioning:
		world.player.velocity = Vector3.ZERO
		return
	if not phone.phone_open:
		var turn := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		apply_look(turn*delta*540.0)
	var input: Vector2 = movement_vector()
	var direction: Vector3 = world.player.basis * Vector3(input.x,0,input.y)
	var speed: float = walk_speed * (1.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	var weight: float = 1.0-exp(-delta*14.0)
	world.player.velocity.x = lerpf(world.player.velocity.x,direction.x*speed,weight)
	world.player.velocity.z = lerpf(world.player.velocity.z,direction.z*speed,weight)
	world.player.velocity.y -= 12.0*delta
	world.player.move_and_slide()
	var walking: bool = Vector2(world.player.velocity.x,world.player.velocity.z).length()>0.1
	if walking: step_time += delta*8.0
	world.camera.position.y = lerpf(world.camera.position.y,1.68+(sin(step_time)*0.012 if walking else sin(elapsed*1.1)*0.003),weight)
	world.camera.rotation.x = pitch

func _update_interface() -> void:
	var free: bool = not phone.phone_open and not story_transitioning
	chapter.text = "ОЛЬХОВСК / ВОКЗАЛ"
	inventory.text = "Ключ · комната № 4" if key_taken else ""
	controls.visible = free
	controls.text = "WASD — идти   ·   Мышь / стрелки — голова   ·   Shift — быстрее   ·   E — телефон   ·   Esc — курсор"
	look_button.visible = free and not look_active
	crosshair.visible = free and look_active
	interaction.visible = free
	var target: String = world.target_nearby()
	interaction.text = {"clock":"F · Осмотреть часы","key":"F · Взять ключ от комнаты № 4","door":"F · Осмотреть дверь"}.get(target,"")
	thought.visible = free
	thought.text = ""
	if elapsed < notice_until: thought.text = notice
	elif location_index == 0:
		if elapsed < 5.0: thought.text = "Я сошёл на перрон. Поезд уже ушёл."
		elif elapsed < 11.0: thought.text = "Впереди, за зданием вокзала, начиналась городская улица."
		elif elapsed < 18.0: thought.text = "Павел сказал идти к площади. Где-то там должно быть общежитие."
	elif location_index == 1 and location_elapsed < 7.0:
		thought.text = "Собор, торговые ряды, закрытая аптека.\nОбычный город. Только ни одного человека."
	elif location_index == 2 and location_elapsed < 7.0:
		thought.text = "За окнами темно. Собственные шаги звучат слишком громко."
	elif location_index == 3 and location_elapsed < 7.0:
		thought.text = "За сквером темнели ворота депо.\nСправа, кажется, горел свет."
	elif location_index == 4 and location_elapsed < 7.0:
		thought.text = "На вахте никого.\nКлюч лежал на полке — как будто меня ждали."

func show_notice(text: String) -> void:
	notice = text
	notice_until = elapsed+7.0
	_update_interface()

func interact() -> void:
	if phone.phone_open or story_transitioning: return
	match world.target_nearby():
		"clock": inspect_clock()
		"key": take_key()
		"door": inspect_door()

func inspect_clock() -> void:
	clock_inspected = true
	show_notice("Часы стояли. Секундная стрелка не двигалась.\nНа телефоне было уже другое время.")

func take_key() -> void:
	if key_taken: return
	key_taken = true
	world.get_node("RoomKey").hide()
	show_notice("На брелоке — четвёрка. Ключ ледяной.\nУберу в карман, пока не потерял.")

func inspect_door() -> void:
	if not key_taken: show_notice("Дверь приоткрыта. Сначала заберу ключ с полки справа.")
	else: show_notice("За дверью пахло сыростью и старой краской.\nЧетвёртая комната. Надо хотя бы немного поспать.")

func capture_look() -> void:
	if phone.phone_open or story_transitioning: return
	look_active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(look_button): look_button.release_focus()

func apply_look(pixels: Vector2) -> void:
	world.player.rotation.y = wrapf(world.player.rotation.y-pixels.x*mouse_sensitivity,-PI,PI)
	pitch = clampf(pitch-pixels.y*mouse_sensitivity,-deg_to_rad(85),deg_to_rad(85))
	world.camera.rotation.x = pitch

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not phone.phone_open and not story_transitioning and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var pixels: Vector2 = event.screen_relative if not event.screen_relative.is_zero_approx() else event.relative
		apply_look(pixels)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if phone.phone_open or story_transitioning: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		capture_look()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			look_active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_F: interact()
		elif event.keycode == KEY_SPACE: capture_look()
		elif event.keycode == KEY_HOME: pitch = 0.0
		else: return
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		look_active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func begin_evening_story() -> void:
	if story_transitioning: return
	story_transitioning = true
	world.player.velocity = Vector3.ZERO
	look_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	phone.story_active = false
	phone.put_away()
	phone.hide()
	for element in [chapter,inventory,thought,controls,look_button,interaction,crosshair]: element.hide()
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var transition := create_tween().set_parallel(true)
	transition.tween_property(fade,"modulate:a",1.0,story_fade_duration)
	transition.tween_property(wind,"volume_db",-55.0,story_fade_duration)
	await transition.finished
	get_tree().change_scene_to_file("res://NightArrival.tscn")
