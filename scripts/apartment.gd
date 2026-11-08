extends Node2D
## Начальная сцена. Комната и анимация дыма — отдельные слои.

## Кончик сигареты в долях ширины и высоты исходного рисунка.
@export var cigarette_tip: Vector2 = Vector2(0.369, 0.775)
@export var show_menu_on_start: bool = true
@export_range(0.0, 8.0, 0.1) var breathing_strength: float = 4.5
@export var clock_enabled: bool = true
@export_range(-40.0, 0.0, 1.0) var clock_volume_db: float = -20.0
@export var departure_delay: float = 9.0

@onready var room_frame: Node2D = $RoomFrame
@onready var artwork: Sprite2D = $RoomFrame/ApartmentArtwork
@onready var smoke: Node2D = $RoomFrame/CigaretteSmoke
@onready var window_wind: Node2D = $RoomFrame/WindowWind
@onready var phone_call: Control = $Interface/PhoneConversation
var story_started: bool = false
var breath_time: float = 0.0
var clock: AudioStreamPlayer
var main_menu: Control
var departure_timer: float = -1.0
var departing: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().title = "Последний трамвай — Квартира"
	get_viewport().size_changed.connect(_fit_room)
	_fit_room()
	_create_clock()
	phone_call.conversation_finished.connect(_prepare_departure)
	$Interface/Chapter.hide()
	if show_menu_on_start:
		main_menu = load("res://MainMenu.tscn").instantiate()
		$Interface.add_child(main_menu)
		main_menu.start_requested.connect(start_story)
		main_menu.sound_changed.connect(_set_sound)
	else: start_story()

func _process(delta: float) -> void:
	breath_time += delta
	var material: ShaderMaterial = artwork.material as ShaderMaterial
	material.set_shader_parameter("breath_time", breath_time)
	material.set_shader_parameter("breath_strength", breathing_strength)
	if departure_timer >= 0.0 and not departing and not phone_call.unread_sms:
		departure_timer -= delta
		if departure_timer <= 0.0: _depart_for_train()

func _prepare_departure(accepted: bool) -> void:
	if accepted: departure_timer = departure_delay

func _depart_for_train() -> void:
	if departing: return
	departing = true
	phone_call.put_away()
	phone_call.story_active = false
	var fade := ColorRect.new()
	fade.name = "DepartureFade"
	fade.color = Color("0a120e")
	fade.modulate.a = 0.0
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Interface.add_child(fade)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade, "modulate:a", 1.0, 1.0)
	tween.tween_property(clock, "volume_db", -45.0, 1.0)
	await tween.finished
	var words := Label.new()
	words.text = "Сумка. Документы. До вокзала — двадцать минут.\n\nЗа двойную ставку один день потерплю."
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	words.add_theme_font_size_override("font_size", 22)
	words.add_theme_color_override("font_color", Color("d5cbaa"))
	fade.add_child(words)
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file("res://Train.tscn")

func _create_clock() -> void:
	clock = AudioStreamPlayer.new()
	clock.name = "RoomClock"
	var stream: AudioStreamWAV = load("res://assets/audio/clock-tick-tock.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	clock.stream = stream
	clock.volume_db = clock_volume_db
	add_child(clock)

func start_story() -> void:
	if story_started: return
	story_started = true
	phone_call.story_active = true
	phone_call.elapsed = 0.0
	phone_call._update_prompt()
	$Interface/Chapter.show()
	if clock_enabled: clock.play()

func _set_sound(enabled: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not enabled)

func _fit_room() -> void:
	if artwork.texture == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var image_size: Vector2 = artwork.texture.get_size()
	var image_scale: float = minf(viewport_size.x / image_size.x, viewport_size.y / image_size.y)
	room_frame.scale = Vector2.ONE * image_scale
	room_frame.position = (viewport_size - image_size * image_scale) * 0.5
	# Дым движется вместе с рисунком и остаётся у сигареты при смене размера окна.
	smoke.position = cigarette_tip * image_size
	window_wind.image_size = image_size
	# Кликабельная область совпадает с телефоном на столе при любом размере окна.
	var phone_rect := Rect2(Vector2(0.437, 0.686) * image_size, Vector2(0.065, 0.10) * image_size)
	phone_call.set_phone_rect(Rect2(room_frame.position + phone_rect.position * image_scale, phone_rect.size * image_scale))
