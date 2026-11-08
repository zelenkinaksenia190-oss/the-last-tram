extends Control
## SMS-пролог: история сообщений, варианты ответа и адрес от Виктора.
signal conversation_finished(accepted: bool)

@export_file("*.json") var dialogue_file: String = "res://dialogue/viktor_sms.json"
@export var first_message_delay: float = 11.0
@export var hint_delay: float = 6.0
@export var reply_delay: float = 3.2
@export var sound_enabled: bool = true

@onready var handset = $Handset
@onready var prompt: Button = $Prompt
@onready var hotspot: Button = $PhoneHotspot
@onready var key_sound: AudioStreamPlayer = $KeySound
@onready var sms_sound: AudioStreamPlayer = $SmsSound

var phone_open: bool = false
var selected_tab: int = 0
var selected_row: int = 0
var story: Dictionary = {}
var nodes: Dictionary = {}
var history: Array[Dictionary] = []
var visited: Array[String] = []
var unread_sms: bool = false
var accepted: bool = false
var finished: bool = false
var started: bool = false
var elapsed: float = 0.0
var receive_timer: float = 0.0
var pending_receive: String = ""
var pending_reply: String = ""
var composing: bool = false
var visible_entries: Array = []
var story_active: bool = false
var contact_name: String = "Виктор"
var phone_time: String = "16:42"
var secondary_name: String = "Депо"

func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dialogue_file))
	if not parsed is Dictionary or not parsed.has("nodes"):
		push_error("Не удалось прочитать SMS-сценарий: " + dialogue_file)
		set_process(false)
		return
	story = parsed
	nodes = story["nodes"]
	contact_name = str(story.get("contact", "Виктор"))
	phone_time = str(story.get("clock", "16:42"))
	secondary_name = str(story.get("secondary_name", "Депо"))
	handset.contact_name = contact_name
	handset.secondary_name = secondary_name
	handset.phone_time = phone_time
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
	if not story_active: return
	if started: elapsed += delta
	if not started:
		elapsed += delta
		if elapsed >= first_message_delay: start_messages()
	elif not pending_receive.is_empty():
		var next_is_own: bool = str(nodes[pending_receive]["speaker"]).begins_with("Вы")
		var can_advance: bool = not unread_sms and (not next_is_own or (phone_open and selected_tab == 1))
		if can_advance:
			receive_timer -= delta
			if receive_timer <= 0.0:
				var id: String = pending_receive
				pending_receive = ""
				_receive_until_reply(id)
	_update_prompt()
	if prompt.visible:
		prompt.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin((elapsed - hint_delay) * TAU / 3.1))

func start_messages() -> void:
	if started: return
	started = true
	_receive_until_reply(str(story["start"]))

func _receive_until_reply(id: String) -> void:
	if not nodes.has(id):
		push_error("Не найдено SMS: " + id)
		return
	var message: Dictionary = nodes[id]
	var own: bool = str(message["speaker"]).begins_with("Вы")
	if own and message.get("choices", []).size() >= 2:
		pending_reply = id
		composing = true
		selected_row = 0
		_render()
		return
	visited.append(id)
	history.append({"sender": "Вы" if own else contact_name, "text": str(message["text"]), "time": phone_time})
	if message.get("accept", false): accepted = true
	if not own:
		unread_sms = not (phone_open and selected_tab == 1)
		if sound_enabled: sms_sound.play()
	if message.get("end", false):
		finished = true
		pending_receive = ""
		conversation_finished.emit(accepted)
	else:
		pending_receive = str(message.get("next", ""))
		receive_timer = minf(6.0, maxf(reply_delay, str(message["text"]).length() / 24.0))
	_update_prompt()
	_render()

func send_reply(index: int = 0) -> void:
	if pending_reply.is_empty() or not pending_receive.is_empty(): return
	var message: Dictionary = nodes[pending_reply]
	var choices: Array = message.get("choices", [])
	if choices.size() < 2: return
	var outgoing: String = str(message["text"])
	var next_id: String = str(message.get("next", ""))
	if not choices.is_empty():
		if index < 0 or index >= choices.size(): return
		outgoing = str(choices[index]["text"])
		next_id = str(choices[index]["next"])
	visited.append(pending_reply)
	history.append({"sender": "Вы", "text": outgoing, "time": phone_time})
	if message.get("accept", false): accepted = true
	pending_reply = ""
	composing = false
	pending_receive = next_id
	receive_timer = reply_delay
	selected_row = 0
	_render()

func open_phone() -> void:
	if not story_active: return
	phone_open = true
	handset.show()
	$Dim.show()
	if selected_tab == 1: unread_sms = false
	_update_prompt()
	_render()

func put_away() -> void:
	phone_open = false
	handset.hide()
	$Dim.hide()
	_update_prompt()

func switch_tab(index: int) -> void:
	selected_tab = clampi(index, 0, 2)
	selected_row = 0
	if selected_tab == 1: unread_sms = false
	_update_prompt()
	_render()

func _update_prompt() -> void:
	prompt.visible = story_active and elapsed >= hint_delay and not phone_open
	prompt.text = "Телефон E"
	hotspot.disabled = not story_active

func _transcript() -> String:
	var text: String = ""
	for message in history:
		text += "[b]" + str(message["sender"]) + " · " + phone_time + "[/b]\n" + str(message["text"]) + "\n\n"
	return text.strip_edges()

func _render() -> void:
	if not phone_open: return
	handset.set_tabs(selected_tab, unread_sms)
	handset.status.text = "SMS  " + phone_time + "      [|||]"
	visible_entries = []
	if selected_tab == 0:
		visible_entries = [contact_name + " · НОВОЕ" if unread_sms else contact_name, secondary_name]
		var preview: String = "Входящие / 2"
		if not history.is_empty(): preview = str(history[-1]["sender"]) + ": " + str(history[-1]["text"]).left(48) + "…"
		handset.set_screen("СООБЩЕНИЯ", preview, visible_entries, "Открыть", selected_row)
	elif selected_tab == 1:
		var text: String = _transcript()
		if text.is_empty(): text = "Сообщений пока нет."
		if not pending_receive.is_empty(): text += "\n\n[i]Ожидание ответа…[/i]"
		if composing and not pending_reply.is_empty():
			text = ""
			var draft: Dictionary = nodes[pending_reply]
			var choices: Array = draft.get("choices", [])
			if choices.size() >= 2:
				for index in range(choices.size()):
					visible_entries.append(str(index + 1) + ". " + str(choices[index]["text"]))
		var action: String = "К входящим" if finished else ""
		handset.set_screen("ВЫБЕРИТЕ ОТВЕТ" if composing else "SMS / " + contact_name.to_upper(), text, visible_entries, action, selected_row)
		if not composing: handset.set_messages(history, not pending_receive.is_empty())
		if not composing: handset.scroll_to_latest.call_deferred()
	else:
		var secondary_text: String = str(story.get("secondary_text", "[b]Депо · вчера[/b]\n\nГрафик на неделю\n\nЗавтра у тебя выходной. Следующая смена — по расписанию.\n\nДиспетчерская"))
		handset.set_screen("SMS / " + secondary_name.to_upper(), secondary_text, [], "К входящим")

func _primary() -> void:
	if selected_tab == 0: switch_tab(selected_row + 1)
	elif selected_tab == 1 and not pending_reply.is_empty():
		send_reply(selected_row)
	elif selected_tab == 2 or finished: switch_tab(0)

func _row(index: int) -> void:
	if index < 0 or index >= visible_entries.size(): return
	selected_row = index
	_primary()

func _move_selection(direction: int) -> void:
	if not visible_entries.is_empty():
		selected_row = clampi(selected_row + direction, 0, visible_entries.size() - 1)
		_render()
		handset.reveal_selected.call_deferred(selected_row)
	else:
		var scroll: ScrollContainer = handset.screen.get_node("MainColumn/ScreenScroll")
		scroll.scroll_vertical += direction * 35

func _back() -> void:
	if selected_tab != 0: switch_tab(0)
	else: put_away()

func _command(action: String, value: int) -> void:
	if sound_enabled: key_sound.play()
	match action:
		"tab": switch_tab(value)
		"menu": switch_tab(0)
		"next_tab": switch_tab((selected_tab + 1) % 3)
		"previous_tab": switch_tab((selected_tab + 2) % 3)
		"close": put_away()
		"back": _back()
		"primary", "green": _primary()
		"row": _row(value)
		"up": _move_selection(-1)
		"down": _move_selection(1)
		"digit":
			if value in [0, 1] and selected_tab == 1 and composing: send_reply(value)
			elif value == 4: _primary()
			elif value == 3: switch_tab((selected_tab + 2) % 3)
			elif value == 5: switch_tab((selected_tab + 1) % 3)
			elif value == 7: _move_selection(1)
			elif value == 9: _back()
			elif value == 11: switch_tab((selected_tab + 1) % 3)

func _unhandled_key_input(event: InputEvent) -> void:
	if not story_active: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_E, KEY_P]:
		if phone_open: put_away()
		else: open_phone()
	elif not phone_open: return
	elif event.keycode == KEY_ESCAPE: _back()
	elif event.keycode in [KEY_ENTER, KEY_SPACE]: _primary()
	elif event.keycode in [KEY_RIGHT, KEY_TAB]: _command("next_tab", 0)
	elif event.keycode == KEY_LEFT: _command("previous_tab", 0)
	elif event.keycode == KEY_UP: _move_selection(-1)
	elif event.keycode == KEY_DOWN: _move_selection(1)
	elif event.keycode in [KEY_1, KEY_2] and selected_tab == 1 and composing: send_reply(0 if event.keycode == KEY_1 else 1)
	else: return
	get_viewport().set_input_as_handled()

