extends Control
## Главное меню поверх живой квартиры. Сюжетный таймер запускается только после «Начать».
signal start_requested
signal sound_changed(enabled: bool)

var start_button: Button
var how_button: Button
var sound_button: Button
var stage: Control
var help_panel: PanelContainer
var help_shade: ColorRect
var sound_on: bool = true
var leaving: bool = false
var title_font: SystemFont

func _flat(color: Color, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	var menu_theme := Theme.new()
	menu_theme.default_font = ui_font
	menu_theme.default_font_size = 17
	menu_theme.set_color("font_color", "Label", Color("cfcebb"))
	theme = menu_theme
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.065, 0.052, 0.32)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = PackedColorArray([Color(0.025, 0.065, 0.052, 0.87), Color(0.025, 0.065, 0.052, 0.56), Color(0.025, 0.065, 0.052, 0.13)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	var shadow := TextureRect.new()
	shadow.texture = texture
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Segoe Print", "Segoe Script", "Georgia"])
	title_font.font_weight = 700
	title_font.font_italic = true
	_label("П Р О Л О Г  /  П О Д М Е Н А", Vector2(80, 138), 13, Color("bba16e"))
	_title("Последний", Vector2(76, 177), 104, Color("e4dfbd"))
	_title("трамвай", Vector2(100, 290), 112, Color("c5a064"))
	var description := _label("Одна чужая смена. Двойная оплата.\nИ город, о котором ты никогда не слышал.", Vector2(80, 452), 18, Color("cccdb9"))
	description.add_theme_constant_override("line_spacing", 8)
	start_button = Button.new()
	start_button.text = "Начать историю →"
	start_button.position = Vector2(80, 536)
	start_button.size = Vector2(215, 54)
	start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start_button.add_theme_stylebox_override("normal", _flat(Color("b69b66"), 4))
	start_button.add_theme_stylebox_override("hover", _flat(Color("d1b77d"), 4))
	start_button.add_theme_stylebox_override("pressed", _flat(Color("a68c58"), 4))
	start_button.add_theme_color_override("font_color", Color("26382d"))
	start_button.add_theme_color_override("font_hover_color", Color("1a2b22"))
	start_button.add_theme_color_override("font_pressed_color", Color("1a2b22"))
	start_button.pressed.connect(begin)
	stage.add_child(start_button)
	_label("Атмосферная история · пролог · со звуком", Vector2(80, 608), 12, Color("8f9a87"))
	how_button = _link("Как играть", Vector2(80, 650))
	how_button.pressed.connect(func(): help_panel.show(); help_shade.show())
	sound_button = _link("Звук: вкл", Vector2(220, 650))
	sound_button.pressed.connect(_toggle_sound)
	var shift_button := _link("Первая смена →", Vector2(400,650))
	shift_button.pressed.connect(func(): get_tree().change_scene_to_file("res://FirstShift.tscn"))
	_build_help()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _label(text: String, position_at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(label)
	return label

func _title(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var label := _label(text, at, font_size, color)
	label.add_theme_font_override("font", title_font)

func _link(text: String, at: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("a7b09b"))
	button.add_theme_color_override("font_hover_color", Color("e4d5a9"))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stage.add_child(button)
	return button

func _build_help() -> void:
	help_shade = ColorRect.new()
	help_shade.color = Color(0.01, 0.025, 0.018, 0.7)
	help_shade.size = Vector2(1280, 720)
	stage.add_child(help_shade)
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(385, 210)
	help_panel.size = Vector2(510, 300)
	help_panel.add_theme_stylebox_override("panel", _flat(Color("192b23"), 6))
	stage.add_child(help_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	help_panel.add_child(content)
	var title := Label.new()
	title.text = "Как играть"
	title.add_theme_font_size_override("font_size", 25)
	content.add_child(title)
	var text := Label.new()
	text.text = "Переписка идёт сама. Выбор — только из двух ответов.\n\nE или щелчок по телефону — открыть телефон.\nМышь или 1 / 2 — выбрать ответ.\nКолесо — пролистать переписку.\nEsc — назад. E или × — убрать телефон.\nВ городе: WASD — ходьба. Мышь / стрелки — голова.\nF — предметы. Esc — курсор, пробел — осмотр."
	text.add_theme_font_size_override("font_size", 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text)
	var close := Button.new()
	close.text = "Понятно"
	close.pressed.connect(func(): help_panel.hide(); help_shade.hide())
	content.add_child(close)
	help_panel.hide()
	help_shade.hide()

func _fit() -> void:
	var available: Vector2 = get_viewport_rect().size
	var factor: float = minf(available.x / 1280.0, available.y / 720.0)
	stage.scale = Vector2.ONE * factor
	stage.position = (available - Vector2(1280, 720) * factor) * 0.5

func _toggle_sound() -> void:
	sound_on = not sound_on
	sound_button.text = "Звук: вкл" if sound_on else "Звук: выкл"
	sound_changed.emit(sound_on)

func begin() -> void:
	if leaving or help_panel.visible: return
	leaving = true
	start_button.disabled = true
	start_requested.emit()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.65)
	fade.tween_callback(queue_free)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and help_panel.visible:
		help_panel.hide()
		help_shade.hide()
	elif event.keycode == KEY_ENTER: begin()
	else: return
	get_viewport().set_input_as_handled()


