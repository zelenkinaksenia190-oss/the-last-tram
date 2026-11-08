extends Node2D
## Первый тест: только 2D-панорама и плавный осмотр из кресла водителя.

@export_range(0.1, 2.0, 0.05) var mouse_sensitivity: float = 0.7
@export_range(2.0, 25.0, 1.0) var look_smoothing: float = 12.0
@export var keyboard_speed: float = 480.0

@onready var artwork: Sprite2D = $CabinArtwork
@onready var head: Camera2D = $Head
@onready var hint: Label = $Interface/Controls/Hint
@onready var direction: Label = $Interface/Controls/Direction
@onready var look_button: Button = $Interface/Controls/LookButton

var look_target: float = 0.0
var look_limit: float = 0.0

func _ready() -> void:
	# Подгоняем высоту картинки под экран; края остаются для осмотра.
	get_viewport().size_changed.connect(_fit_panorama)
	look_button.pressed.connect(capture_look)
	_fit_panorama()
	_refresh_hint()

func _fit_panorama() -> void:
	# Размер картинки и экрана определяет, насколько далеко можно смотреть вбок.
	if artwork.texture == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var texture_size: Vector2 = artwork.texture.get_size()
	var image_scale: float = viewport_size.y / texture_size.y
	artwork.scale = Vector2.ONE * image_scale
	look_limit = maxf(0.0, (texture_size.x * image_scale - viewport_size.x) * 0.5)
	look_target = clampf(look_target, -look_limit, look_limit)
	head.position.x = clampf(head.position.x, -look_limit, look_limit)

func capture_look() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	look_button.release_focus()
	_refresh_hint()

func release_look() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_hint()

func apply_look_delta(horizontal_pixels: float) -> void:
	# Сюда приходит движение мыши. Чувствительность переводит его в сдвиг обзора.
	look_target = clampf(look_target + horizontal_pixels * mouse_sensitivity, -look_limit, look_limit)

func reset_look() -> void:
	look_target = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# Управление: щелчок включает осмотр, мышь поворачивает взгляд,
	# Esc возвращает курсор, Home возвращает взгляд вперёд.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			capture_look()
	elif event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_look_delta(event.screen_relative.x)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			release_look()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_HOME:
			reset_look()

func _process(delta: float) -> void:
	# Вызывается каждый кадр: стрелки меняют цель, камера плавно догоняет её.
	var arrow: float = float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
	if not is_zero_approx(arrow):
		look_target = clampf(look_target + arrow * keyboard_speed * delta, -look_limit, look_limit)
	head.position.x = lerpf(head.position.x, look_target, 1.0 - exp(-look_smoothing * delta))
	var heading: String = "ВПЕРЁД"
	if head.position.x < -look_limit * 0.4:
		heading = "ЛЕВОЕ ОКНО"
	elif head.position.x > look_limit * 0.4:
		heading = "ПРАВОЕ ОКНО"
	direction.text = "ПРОБНЫЙ ОСМОТР / " + heading

func _notification(what: int) -> void:
	# При переключении на другое окно мышь сразу освобождается.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if is_node_ready():
			_refresh_hint()

func _refresh_hint() -> void:
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	look_button.text = "Осмотр включён" if captured else "Осмотреться"
	hint.text = "Мышь — смотреть  ·  Esc — курсор  ·  Home — вперёд" if captured else "Нажми «Осмотреться» или ЛКМ  ·  ← → тоже работают"
