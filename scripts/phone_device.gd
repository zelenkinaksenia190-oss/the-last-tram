extends Control
## Оболочка кнопочного телефона. Разговор остаётся отдельной моделью Backend.
const TABS: Array[String] = ["calls", "sms", "contacts"]

@onready var core = $Backend
@onready var handset = $Handset
@onready var prompt: Button = $Prompt
@onready var hotspot: Button = $PhoneHotspot
@onready var key_sound: AudioStreamPlayer = $KeySound

var phone_open: bool = false
var selected_tab: String = "calls"
var message_detail: int = -1
var contact_detail: int = -1
var selected_row: int = 0
var unread_sms: bool = false
var call_time: float = 0.0
var visible_entries: Array = []
var last_state: String = ""

func _ready() -> void:
	core.external_ui = true
	core.set_process_unhandled_key_input(false)
	core.conversation_finished.connect(_call_finished)
	handset.command.connect(_command)
	prompt.pressed.connect(open_phone)
	hotspot.pressed.connect(open_phone)
	get_viewport().size_changed.connect(_layout)
	_layout()
	handset.hide()
	$Dim.hide()
	_update_prompt()

func set_phone_rect(rect: Rect2) -> void:
	hotspot.position = rect.position
	hotspot.size = rect.size

func _layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var factor: float = minf(1.0, minf((viewport_size.y - 28.0) / 660.0, (viewport_size.x - 30.0) / 440.0))
	handset.scale = Vector2.ONE * factor
	handset.position = Vector2(viewport_size.x - 440.0 * factor + 16.0, (viewport_size.y - 660.0 * factor) * 0.5)

func _process(delta: float) -> void:
	if core.mode == core.Mode.TALKING:
		call_time += delta
	var state: String = str(core.mode) + "|" + core.current_id + "|" + str(core.is_typing())
	if state != last_state:
		last_state = state
		_update_prompt()
		_render()
	if phone_open:
		handset.status.text = "ВИКТОР " + _duration() + "     [|||]" if core.mode == core.Mode.TALKING else "ВИКТОР ЗВОНИТ     [|||]" if core.mode == core.Mode.RINGING else "СЕТЬ |||  16:42   [|||]"
		if selected_tab == "calls" and core.mode == core.Mode.TALKING:
			handset.body.visible_characters = core.body.visible_characters

func _duration() -> String:
	return "%02d:%02d" % [int(call_time) / 60, int(call_time) % 60]

func _update_prompt() -> void:
	prompt.visible = not phone_open
	prompt.text = "Телефон звонит  ·  E" if core.mode == core.Mode.RINGING else "Виктор на линии  ·  E" if core.mode == core.Mode.TALKING else "Телефон  ·  E"

func open_phone() -> void:
	phone_open = true
	handset.show()
	$Dim.show()
	_update_prompt()
	_render()

func put_away() -> void:
	phone_open = false
	handset.hide()
	$Dim.hide()
	_update_prompt()

func answer() -> void:
	if core.mode != core.Mode.RINGING:
		return
	core.answer()
	call_time = 0.0
	selected_tab = "calls"
	open_phone()

func switch_tab(tab: String) -> void:
	if not TABS.has(tab):
		return
	selected_tab = tab
	selected_row = 0
	if selected_tab == "sms" and message_detail == 0:
		unread_sms = false
	_render()

func open_message(index: int) -> void:
	if index < 0 or index > 1:
		return
	message_detail = index
	if index == 0:
		unread_sms = false
	_render()

func _call_finished(_accepted: bool) -> void:
	unread_sms = true
	_render()

func _render() -> void:
	if not phone_open:
		return
	handset.set_tabs(TABS.find(selected_tab), unread_sms, core.mode == core.Mode.RINGING)
	visible_entries = []
	if selected_tab == "calls":
		if core.mode == core.Mode.WAITING:
			handset.set_screen("ЗВОНКИ", "Активных звонков нет.\n\nВиктор — в контактах.", [], "Контакты")
		elif core.mode == core.Mode.RINGING:
			handset.set_screen("ВИКТОР", "Входящий звонок…\n\nЗелёная клавиша — ответить.", [], "Принять / OK")
		elif core.mode == core.Mode.TALKING:
			var choices: Array = core.current.get("choices", [])
			if not core.is_typing():
				for index in range(choices.size()):
					visible_entries.append(str(index + 1) + ". " + str(choices[index]["text"]))
			var action: String = "Читать / OK" if core.is_typing() else "Выбрать / OK" if not choices.is_empty() else "Завершить / OK" if core.current.get("end", false) else "Дальше / OK"
			handset.set_screen(str(core.current["speaker"]).to_upper(), str(core.current["text"]), visible_entries, action, selected_row)
			handset.body.visible_characters = core.body.visible_characters
		else:
			visible_entries = ["Повторить разговор"]
			handset.set_screen("ЗВОНОК ЗАВЕРШЁН", "Виктор · " + _duration() + "\n\nПришло SMS с адресом.", visible_entries, "Читать SMS", selected_row)
	elif selected_tab == "sms":
		if message_detail < 0:
			visible_entries = ["Виктор · НОВОЕ" if unread_sms else "Виктор", "Депо"]
			handset.set_screen("СООБЩЕНИЯ", "Входящие / 2", visible_entries, "Открыть / OK", selected_row)
		elif message_detail == 0:
			var message: String = str(core.story.get("sms_text", core.story["result"])) if core.mode == core.Mode.FINISHED else "Сегодня\n\nЕсть дело. Наберу тебя чуть позже.\n\n— Виктор"
			handset.set_screen("SMS / ВИКТОР", message, [], "К списку")
		else:
			handset.set_screen("SMS / ДЕПО", "График на неделю\n\nЗавтра у тебя выходной. Следующая смена — по расписанию.\n\nДиспетчерская", [], "К списку")
	else:
		if contact_detail < 0:
			visible_entries = ["Виктор", "Депо"]
			if core.mode == core.Mode.FINISHED:
				visible_entries.append("Павел · Ольховск")
			handset.set_screen("ТЕЛЕФОННАЯ КНИГА", "Контакты на SIM", visible_entries, "Открыть / OK", selected_row)
		elif contact_detail == 0:
			handset.set_screen("ВИКТОР", "Водитель\nНаше депо", [], "Сообщения")
		elif contact_detail == 1:
			handset.set_screen("ДЕПО", "Диспетчерская\nНаш город\n\nГрафик твоих смен.", [], "Сообщения")
		else:
			handset.set_screen("ПАВЕЛ", "Диспетчер Ольховска\n\nЗавтра в 06:40 у ворот депо.\n\nКонтакт передал Виктор.", [], "Назад")

func _primary() -> void:
	if selected_tab == "calls":
		if core.mode == core.Mode.RINGING: answer()
		elif core.mode == core.Mode.WAITING: switch_tab("contacts")
		elif core.mode == core.Mode.TALKING:
			if not core.is_typing() and core.current.has("choices"):
				core.select_choice(selected_row)
			else:
				core.advance()
			_render()
		else:
			switch_tab("sms")
			open_message(0)
	elif selected_tab == "sms":
		if message_detail < 0: open_message(selected_row)
		else: _back()
	else:
		if contact_detail < 0: _row(selected_row)
		elif contact_detail < 2:
			message_detail = contact_detail
			switch_tab("sms")
			if message_detail == 0: unread_sms = false
			_render()
		else: _back()

func _row(index: int) -> void:
	if index < 0 or index >= visible_entries.size(): return
	selected_row = index
	if selected_tab == "calls":
		if core.mode == core.Mode.TALKING:
			core.select_choice(index)
		elif core.mode == core.Mode.FINISHED:
			core.replay()
			unread_sms = false
			call_time = 0.0
		_render()
	elif selected_tab == "sms": open_message(index)
	else:
		contact_detail = index
		_render()

func _back() -> void:
	if selected_tab == "sms" and message_detail >= 0:
		message_detail = -1
		_render()
	elif selected_tab == "contacts" and contact_detail >= 0:
		contact_detail = -1
		_render()
	else: put_away()

func _move_selection(direction: int) -> void:
	if not visible_entries.is_empty():
		selected_row = clampi(selected_row + direction, 0, visible_entries.size() - 1)
		_render()
		handset.reveal_selected.call_deferred(selected_row)
	else:
		var scroll: ScrollContainer = handset.screen.get_node("MainColumn/ScreenScroll")
		scroll.scroll_vertical += direction * 35

func _command(action: String, value: int) -> void:
	if core.sound_enabled: key_sound.play()
	match action:
		"tab": switch_tab(TABS[clampi(value, 0, 2)])
		"next_tab", "menu": switch_tab(TABS[(TABS.find(selected_tab) + 1) % 3])
		"previous_tab": switch_tab(TABS[(TABS.find(selected_tab) + 2) % 3])
		"close": put_away()
		"back": _back()
		"primary": _primary()
		"green":
			if core.mode == core.Mode.RINGING: answer()
			elif selected_tab != "calls": switch_tab("calls")
			else: _primary()
		"row": _row(value)
		"up": _move_selection(-1)
		"down": _move_selection(1)
		"digit":
			var number: int = value + 1 if value < 9 else 0
			if selected_tab == "calls" and core.mode == core.Mode.TALKING and core.current.has("choices") and number in [1, 2]:
				core.select_choice(number - 1)
				_render()
			elif number == 5: _primary()
			elif number == 4: switch_tab(TABS[(TABS.find(selected_tab) + 2) % 3])
			elif number == 6: switch_tab(TABS[(TABS.find(selected_tab) + 1) % 3])
			elif number == 2: _move_selection(-1)
			elif number == 8: _move_selection(1)
			elif value == 9: _back()
			elif value == 11: switch_tab(TABS[(TABS.find(selected_tab) + 1) % 3])

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_E, KEY_P]:
		if not phone_open: open_phone()
		elif core.mode == core.Mode.RINGING: answer()
		else: put_away()
	elif not phone_open: return
	elif event.keycode == KEY_ESCAPE: _back()
	elif event.keycode in [KEY_ENTER, KEY_SPACE]: _primary()
	elif event.keycode in [KEY_RIGHT, KEY_TAB]: _command("next_tab", 0)
	elif event.keycode == KEY_LEFT: _command("previous_tab", 0)
	elif event.keycode == KEY_UP: _move_selection(-1)
	elif event.keycode == KEY_DOWN: _move_selection(1)
	elif event.keycode in [KEY_1, KEY_2] and selected_tab == "calls":
		core.select_choice(0 if event.keycode == KEY_1 else 1)
		_render()
	else: return
	get_viewport().set_input_as_handled()
