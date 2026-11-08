extends Control
## Чёрный экран: путь до общежития, ключ, комната и ночь.
@export_file("*.json") var story_file: String = "res://dialogue/arrival_narration.json"
@export var text_fade_duration: float = 0.65
@export var minimum_page_time: float = 0.65
var story: Dictionary
var pages: Array
var page_index: int = 0
var page_elapsed: float = 0.0
var finished: bool = false
var key_taken: bool = false
var slept: bool = false
var chapter: Label
var body: Label
var page_number: Label
var hint: Label
var next_button: Button
var menu_button: Button
var replay_button: Button
var continue_button: Button
var text_tween: Tween

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().title = "Последний трамвай — вечер в Ольховске"
	story = JSON.parse_string(FileAccess.get_file_as_string(story_file))
	pages = story["pages"]
	var black := ColorRect.new()
	black.name = "BlackScreen"
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	chapter = make_label(13,Color("a79b78"))
	chapter.text = story["chapter"]
	chapter.add_theme_constant_override("outline_size",0)
	body = make_label(25,Color("d6d1c3"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_constant_override("line_spacing",6)
	page_number = make_label(13,Color("78786d"))
	page_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint = make_label(13,Color("898a7b"))
	hint.text = "Пробел, Enter или щелчок — дальше"
	next_button = make_button("Дальше →",advance)
	menu_button = make_button("В меню",return_to_menu)
	replay_button = make_button("Прочитать снова",restart_story)
	continue_button = make_button("Выйти на смену →",continue_morning)
	get_viewport().size_changed.connect(layout_story)
	layout_story()
	show_page()

func make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",Color("bca87e"))
	button.add_theme_color_override("font_hover_color",Color("eee4cd"))
	for state in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	add_child(button)
	return button

func layout_story() -> void:
	var view: Vector2 = get_viewport_rect().size
	var width: float = minf(760.0,view.x-100.0)
	var left: float = (view.x-width)/2
	chapter.position = Vector2(left,view.y*0.20)
	chapter.size = Vector2(width,30)
	body.position = Vector2(left,view.y*0.28)
	body.size = Vector2(width,view.y*0.42)
	page_number.position = Vector2(left+width-85,view.y*0.76)
	page_number.size = Vector2(85,25)
	hint.position = Vector2(left,view.y*0.84)
	hint.size = Vector2(width-170,30)
	next_button.position = Vector2(left+width-135,view.y*0.82)
	next_button.size = Vector2(135,44)
	menu_button.position = Vector2(left,view.y*0.82)
	menu_button.size = Vector2(110,44)
	replay_button.position = Vector2(left+145,view.y*0.82)
	replay_button.size = Vector2(190,44)
	continue_button.position = Vector2(left+width-230,view.y*0.82)
	continue_button.size = Vector2(230,44)

func _process(delta: float) -> void:
	page_elapsed += delta
	next_button.disabled = page_elapsed < minimum_page_time
	hint.modulate.a = minf(1.0,maxf(0.0,(page_elapsed-0.8)/0.7))

func fade_text() -> void:
	if text_tween and text_tween.is_valid(): text_tween.kill()
	body.modulate.a = 0.0
	text_tween = create_tween()
	text_tween.tween_property(body,"modulate:a",1.0,text_fade_duration)

func show_page() -> void:
	page_elapsed = 0.0
	var page: Dictionary = pages[page_index]
	body.text = page["text"]
	page_number.text = "%02d / %02d" % [page_index+1,pages.size()]
	chapter.text = story["chapter"]
	if page.get("key_taken",false):
		key_taken = true
		get_tree().set_meta("olhovsk_key_taken",true)
	if page.get("slept",false): slept = true
	next_button.show()
	hint.show()
	menu_button.hide()
	replay_button.hide()
	continue_button.hide()
	fade_text()

func advance() -> void:
	if finished or page_elapsed < minimum_page_time: return
	if page_index+1 < pages.size():
		page_index += 1
		show_page()
	else: finish_story()

func finish_story() -> void:
	finished = true
	get_tree().set_meta("olhovsk_evening_complete",true)
	chapter.text = "УТРО / ПЕРВАЯ СМЕНА"
	body.text = "%s\n%s\n\n%s" % [story["ending"],story["time"],story["ending_note"]]
	page_number.text = ""
	next_button.hide()
	hint.hide()
	menu_button.show()
	replay_button.show()
	continue_button.show()
	fade_text()

func continue_morning() -> void:
	if not finished: return
	get_tree().change_scene_to_file("res://FirstShift.tscn")

func restart_story() -> void:
	finished = false
	page_index = 0
	key_taken = false
	slept = false
	get_tree().set_meta("olhovsk_key_taken",false)
	get_tree().set_meta("olhovsk_evening_complete",false)
	show_page()

func return_to_menu() -> void:
	get_tree().set_meta("olhovsk_key_taken",false)
	get_tree().set_meta("olhovsk_evening_complete",false)
	get_tree().change_scene_to_file("res://Apartment.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if finished: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
		advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()
