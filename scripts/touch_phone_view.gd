extends Control
## Сенсорный телефон: кликабельные вкладки, история SMS и пузыри сообщений.
signal command(action: String, value: int)

var body: RichTextLabel
var heading: Label
var status: Label
var rows: VBoxContainer
var primary: Button
var tab_buttons: Array[Button] = []
var screen: PanelContainer
var chat: VBoxContainer
var font: SystemFont
var base_size := Vector2(440, 660)
var contact_name: String = "Виктор"
var secondary_name: String = "Депо"
var phone_time: String = "16:42"

func _style(color: Color, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _ready() -> void:
	size = base_size
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Color("e6dfcb"))
	theme.set_color("font_color", "Button", Color("e6dfcb"))
	theme.set_color("font_hover_color", "Button", Color("fff3d6"))
	theme.set_stylebox("normal", "Button", _style(Color("38443b"), 5))
	theme.set_stylebox("hover", "Button", _style(Color("4b594b"), 5))
	theme.set_stylebox("pressed", "Button", _style(Color("5d6650"), 5))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	self.theme = theme
	var art := TextureRect.new()
	art.name = "PhoneArtwork"
	art.texture = load("res://assets/touchscreen-handset.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = base_size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	screen = PanelContainer.new()
	screen.name = "LCD"
	screen.position = Vector2(88, 80)
	screen.size = Vector2(264, 494)
	screen.add_theme_stylebox_override("panel", _style(Color("1d2824"), 4))
	add_child(screen)
	var column := VBoxContainer.new()
	column.name = "MainColumn"
	column.add_theme_constant_override("separation", 6)
	screen.add_child(column)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 11)
	column.add_child(status)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	var back := _button("‹", "back", 0)
	back.custom_minimum_size.x = 30
	toolbar.add_child(back)
	var title := Label.new()
	title.text = "Сообщения"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 17)
	toolbar.add_child(title)
	toolbar.add_child(_button("×", "close", 0))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	column.add_child(tabs)
	for index in range(3):
		var tab := _button(["SMS", "Виктор", "Депо"][index], "tab", index)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 12)
		tabs.add_child(tab)
		tab_buttons.append(tab)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color("a6b09f"))
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.name = "ScreenScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_color_override("default_color", Color("ded8c8"))
	body.add_theme_font_override("normal_font", font)
	body.add_theme_font_size_override("normal_font_size", 15)
	content.add_child(body)
	chat = VBoxContainer.new()
	chat.add_theme_constant_override("separation", 9)
	content.add_child(chat)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	content.add_child(rows)
	primary = _button("Ответить", "primary", 0)
	primary.custom_minimum_size.y = 36
	column.add_child(primary)
	var hint := Label.new()
	hint.text = "E — убрать    ·    колесо — история"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("8d988a"))
	column.add_child(hint)

func _button(text: String, action: String, index: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): command.emit(action, index))
	return button

func _clear(box: VBoxContainer) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func set_tabs(selected: int, unread: bool) -> void:
	for index in range(3):
		var tab: Button = tab_buttons[index]
		tab.text = ["SMS •" if unread else "SMS", contact_name, secondary_name][index]
		tab.add_theme_stylebox_override("normal", _style(Color("6b6448") if index == selected else Color("2b3730"), 4))

func set_screen(title: String, text: String, entries: Array, action_text: String, selected: int = 0) -> void:
	heading.text = title
	body.text = text
	body.visible = not text.is_empty()
	body.visible_characters = -1
	_clear(chat)
	_clear(rows)
	for index in range(entries.size()):
		var button := _button(str(entries[index]), "row", index)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_stylebox_override("normal", _style(Color("555b42") if index == selected else Color("344238"), 6))
		rows.add_child(button)
	primary.text = action_text
	primary.visible = not action_text.is_empty()
	screen.get_node("MainColumn/ScreenScroll").scroll_vertical = 0

func set_messages(messages: Array, waiting: bool) -> void:
	body.hide()
	_clear(chat)
	for message in messages:
		var own: bool = message["sender"] == "Вы"
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chat.add_child(line)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if own: line.add_child(spacer)
		var bubble := PanelContainer.new()
		bubble.custom_minimum_size.x = 208
		bubble.add_theme_stylebox_override("panel", _style(Color("5b6045") if own else Color("344139"), 8))
		line.add_child(bubble)
		var stack := VBoxContainer.new()
		bubble.add_child(stack)
		var caption := Label.new()
		caption.text = str(message["text"])
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", 15)
		stack.add_child(caption)
		var stamp := Label.new()
		stamp.text = str(message["sender"]) + " · " + str(message.get("time", phone_time))
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stamp.add_theme_font_size_override("font_size", 10)
		stamp.add_theme_color_override("font_color", Color("b6bdab"))
		stack.add_child(stamp)
		if not own: line.add_child(spacer)
	if waiting:
		var note := Label.new()
		note.text = "Ожидание ответа…"
		note.add_theme_font_size_override("font_size", 12)
		chat.add_child(note)

func reveal_selected(index: int) -> void:
	await get_tree().process_frame
	if index >= 0 and index < rows.get_child_count():
		screen.get_node("MainColumn/ScreenScroll").ensure_control_visible(rows.get_child(index))

func scroll_to_latest() -> void:
	await get_tree().process_frame
	if rows.get_child_count() > 0: return
	var scroll: ScrollContainer = screen.get_node("MainColumn/ScreenScroll")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
