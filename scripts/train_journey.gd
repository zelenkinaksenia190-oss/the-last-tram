extends Node2D
## Бесконечная поездка: непрерывный мир за стеклом, лёгкое покачивание и SMS Павла.
@export_range(0.0, 2.0, 0.05) var shake_strength: float = 0.32
@export var sound_enabled: bool = true

@onready var stage: Node2D = $Stage
@onready var carriage: Node2D = $Stage/Carriage
@onready var artwork: Sprite2D = $Stage/Carriage/Artwork
@onready var landscape = $Stage/WorldWindowClip/Landscape
@onready var phone = $Interface/Phone
var elapsed: float = 0.0
var wheels: AudioStreamPlayer
var chapter: Label
var thought: Label
var disembark_button: Button
var departing: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().title = "Последний трамвай — В поезде"
	phone.story_active = true
	phone.sound_enabled = sound_enabled
	phone.set_phone_rect(Rect2())
	_build_interface()
	_create_audio()
	get_viewport().size_changed.connect(_fit)
	_fit()
	var opening := ColorRect.new()
	opening.color = Color("0b1510")
	opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Interface.add_child(opening)
	var fade := create_tween()
	fade.tween_property(opening, "modulate:a", 0.0, 1.1)
	fade.tween_callback(opening.queue_free)

func _create_audio() -> void:
	wheels = AudioStreamPlayer.new()
	wheels.name = "TrainWheels"
	var stream: AudioStreamWAV = load("res://assets/audio/train-interior-real.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	wheels.stream = stream
	wheels.volume_db = -12.0
	add_child(wheels)
	if sound_enabled: wheels.play()

func _build_interface() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	chapter = Label.new()
	chapter.text = "В ДОРОГЕ / 19:18"
	chapter.position = Vector2(25, 20)
	chapter.add_theme_font_override("font", font)
	chapter.add_theme_font_size_override("font_size", 14)
	chapter.add_theme_color_override("font_color", Color("d9cfaa"))
	chapter.add_theme_color_override("font_shadow_color", Color("122018"))
	chapter.add_theme_constant_override("shadow_offset_y", 2)
	$Interface.add_child(chapter)
	thought = Label.new()
	thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thought.add_theme_font_override("font", font)
	thought.add_theme_font_size_override("font_size", 19)
	thought.add_theme_color_override("font_color", Color("e4dfc8"))
	thought.add_theme_color_override("font_shadow_color", Color("142019"))
	thought.add_theme_constant_override("shadow_offset_y", 2)
	$Interface.add_child(thought)
	disembark_button = Button.new()
	disembark_button.text = "Подойти к выходу →"
	disembark_button.focus_mode = Control.FOCUS_NONE
	disembark_button.add_theme_font_override("font", font)
	disembark_button.add_theme_font_size_override("font_size", 18)
	disembark_button.add_theme_color_override("font_color", Color("d9c28b"))
	disembark_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	disembark_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	disembark_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	disembark_button.pressed.connect(disembark)
	disembark_button.hide()
	$Interface.add_child(disembark_button)

func _fit() -> void:
	var available: Vector2 = get_viewport_rect().size
	var size: Vector2 = artwork.texture.get_size()
	var factor: float = minf(available.x / size.x, available.y / size.y)
	stage.scale = Vector2.ONE * factor
	stage.position = (available - size * factor) * 0.5
	carriage.position = size * 0.5
	thought.position = Vector2(available.x * 0.16, available.y - 137)
	thought.size = Vector2(available.x * 0.68, 70)
	disembark_button.position = Vector2(35, available.y - 84)
	disembark_button.size = Vector2(270, 42)

func carriage_offset(time: float, speed: float) -> Vector2:
	var joint: float = pow(maxf(0.0, sin(time * TAU / 0.84)), 12.0) * 0.16
	return Vector2(sin(time * 1.3) * 0.9 + sin(time * 17.0) * 0.055, sin(time * 1.7) * 1.25 + sin(time * 23.0) * 0.08 + joint) * speed * shake_strength

func _process(delta: float) -> void:
	elapsed += delta
	landscape.advance(delta)
	var speed: float = landscape.speed
	carriage.position = artwork.texture.get_size() * 0.5 + carriage_offset(elapsed, speed)
	carriage.rotation = sin(elapsed * 1.2) * 0.00018 * speed * shake_strength
	_update_thought()
	disembark_button.visible = phone.finished and not phone.phone_open and not departing

func disembark() -> void:
	if departing or not phone.finished: return
	departing = true
	disembark_button.hide()
	phone.put_away()
	phone.story_active = false
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color("0b1510")
	black.modulate.a = 0.0
	$Interface.add_child(black)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(landscape, "travel_speed", 0.0, 1.8)
	fade.tween_property(black, "modulate:a", 1.0, 1.8)
	fade.tween_property(wheels, "volume_db", -38.0, 1.8)
	await fade.finished
	get_tree().change_scene_to_file("res://Arrival.tscn")

func _update_thought() -> void:
	thought.visible = not phone.phone_open
	thought.text = ""
	if elapsed > 2.0 and elapsed < 10.0:
		thought.text = "В вагоне пахло пылью и нагретым пластиком.\nНа вокзал я успел в последнюю минуту."
	elif elapsed > 34.0 and elapsed < 42.0:
		thought.text = "Город закончился быстро. Дальше — только поля."
	elif elapsed > 65.0 and elapsed < 74.0:
		thought.text = "Я ещё раз посмотрел на схему над дверью.\nОльховска на ней не было."
	elif elapsed > 155.0 and elapsed < 164.0:
		thought.text = "Сколько ещё ехать?\nЗа окном снова мелькнула знакомая водонапорная башня."

