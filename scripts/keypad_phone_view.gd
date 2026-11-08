extends Control
## Рисунок кнопочного телефона. Перепиской управляет phone_sms.gd.

signal command(action: String, value: int)

var body: RichTextLabel
var heading: Label
var status: Label
var rows: VBoxContainer
var primary: Button
var tab_buttons: Array[Button] = []
var screen: PanelContainer
var base_size := Vector2(440.0, 660.0)

func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _ready() -> void:
	size = base_size
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", Color("26351f"))
	theme.set_color("font_color", "Button", Color("26351f"))
	theme.set_color("font_hover_color", "Button", Color("101e0c"))
	theme.set_stylebox("normal", "Button", _style(Color("a5b18b")))
	theme.set_stylebox("hover", "Button", _style(Color("bbc59c")))
	theme.set_stylebox("pressed", "Button", _style(Color("8f9e78")))
	theme.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, Color("4d6039")))
	self.theme = theme
	var art := TextureRect.new()
	art.name = "PhoneArtwork"
	art.texture = load("res://assets/keypad-handset.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = base_size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	screen = PanelContainer.new()
	screen.name = "LCD"
	screen.position = Vector2(104, 92)
	screen.size = Vector2(230, 224)
	screen.add_theme_stylebox_override("panel", _style(Color("a5b18b"), Color("35472b")))
	add_child(screen)
	var column := VBoxContainer.new()
	column.name = "MainColumn"
	column.add_theme_constant_override("separation", 3)
	screen.add_child(column)
	status = Label.new()
	status.name = "Status"
	status.add_theme_font_size_override("font_size", 11)
	status.text = "СЕТЬ |||                 [|||]"
	column.add_child(status)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 1)
	column.add_child(tabs)
	for index in range(3):
		var tab := Button.new()
		tab.text = ["SMS", "Виктор", "Депо"][index]
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 12)
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(func(): command.emit("tab", index))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 15)
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.name = "ScreenScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)
	body = RichTextLabel.new()
	body.name = "Text"
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_color_override("default_color", Color("26351f"))
	body.add_theme_font_override("normal_font", font)
	body.add_theme_font_size_override("normal_font_size", 15)
	content.add_child(body)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	content.add_child(rows)
	primary = Button.new()
	primary.name = "SoftAction"
	primary.custom_minimum_size.y = 25.0
	primary.add_theme_font_size_override("font_size", 12)
	primary.focus_mode = Control.FOCUS_NONE
	primary.pressed.connect(func(): command.emit("primary", 0))
	column.add_child(primary)
	# Физические клавиши поверх отдельных нарисованных колпачков.
	_key(Rect2(102, 344, 64, 34), "SMS", "menu", 0, 11)
	_key(Rect2(275, 344, 64, 34), "Назад", "back", 0, 11)
	_key(Rect2(102, 392, 64, 30), "Читать", "green", 0, 12, Color("a4bf8c"))
	_key(Rect2(275, 392, 64, 30), "Убрать", "close", 0, 12, Color("c59273"))
	_key(Rect2(196, 344, 47, 22), "▲", "up", 0, 12)
	_key(Rect2(197, 411, 47, 17), "▼", "down", 0, 12)
	_key(Rect2(181, 366, 19, 39), "◀", "previous_tab", 0, 12)
	_key(Rect2(243, 366, 19, 39), "▶", "next_tab", 0, 12)
	_key(Rect2(201, 374, 39, 34), "OK", "primary", 0, 12)
	var keys: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
	for index in range(12):
		_key(Rect2(103 + (index % 3) * 85, 442 + (index / 3) * 40, 64, 32), keys[index], "digit", index, 17)

func _key(rect: Rect2, text: String, action: String, value: int, font_size: int, color: Color = Color("dbd6b8")) -> void:
	var button := Button.new()
	button.name = "Key_" + action + "_" + str(value)
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color("fff0c2"))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _style(Color(0.8, 0.85, 0.65, 0.12)))
	button.add_theme_stylebox_override("pressed", _style(Color(0.1, 0.13, 0.08, 0.3)))
	button.pressed.connect(func(): command.emit(action, value))
	add_child(button)

func set_tabs(selected: int, unread: bool) -> void:
	for index in range(3):
		var tab: Button = tab_buttons[index]
		tab.text = ["SMS •" if unread else "SMS", "Виктор", "Депо"][index]
		tab.add_theme_stylebox_override("normal", _style(Color("34472b") if index == selected else Color("a5b18b")))
		tab.add_theme_color_override("font_color", Color("e0e5c4") if index == selected else Color("26351f"))

func set_screen(title: String, text: String, entries: Array, action_text: String, selected: int = 0) -> void:
	heading.text = title
	body.text = text
	body.visible_characters = -1
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for index in range(entries.size()):
		var button := Button.new()
		button.custom_minimum_size.y = maxf(40.0, 18.0 * ceilf(str(entries[index]).length() / 25.0) + 12.0)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", _style(Color("c0c8a0") if index == selected else Color("a0ac86")))
		var caption := Label.new()
		caption.text = str(entries[index])
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", 13)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left = 6.0
		caption.offset_right = -6.0
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(caption)
		button.pressed.connect(func(): command.emit("row", index))
		rows.add_child(button)
	primary.text = action_text
	primary.visible = not action_text.is_empty()
	screen.get_node("MainColumn/ScreenScroll").scroll_vertical = 0

func reveal_selected(index: int) -> void:
	await get_tree().process_frame
	if index >= 0 and index < rows.get_child_count():
		screen.get_node("MainColumn/ScreenScroll").ensure_control_visible(rows.get_child(index))

func scroll_to_latest() -> void:
	await get_tree().process_frame
	if rows.get_child_count() > 0: return
	var scroll: ScrollContainer = screen.get_node("MainColumn/ScreenScroll")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


