extends Control
## Сценарий хранится отдельно в dialogue/viktor_call.json.
## Этот скрипт отвечает за звонок, реплики, выбор ответа и завершение разговора.

signal conversation_finished(accepted: bool)
enum Mode { WAITING, RINGING, TALKING, FINISHED }

@export_file("*.json") var dialogue_file: String = "res://dialogue/viktor_call.json"
@export_range(10.0, 100.0, 1.0) var characters_per_second: float = 43.0
@export var ring_delay: float = 2.0
@export var sound_enabled: bool = true
@export var external_ui: bool = false

@onready var incoming: PanelContainer = $Incoming
@onready var panel: PanelContainer = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/Content/Header/Speaker
@onready var body: RichTextLabel = $DialoguePanel/Content/Body
@onready var choices_box: VBoxContainer = $DialoguePanel/Content/Choices
@onready var next_button: Button = $DialoguePanel/Content/Next
@onready var hotspot: Button = $PhoneHotspot
@onready var result_panel: PanelContainer = $Result
@onready var result_text: Label = $Result/Content/Message
@onready var ringtone: AudioStreamPlayer = $Ringtone

var mode: Mode = Mode.WAITING
var story: Dictionary = {}
var nodes: Dictionary = {}
var current_id: String = ""
var current: Dictionary = {}
var accepted: bool = false
var typed_characters: float = 0.0
var waiting_time: float = 0.0
var ringing_time: float = 0.0
var history: Array[String] = []

func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dialogue_file))
	if not parsed is Dictionary or not parsed.has("nodes"):
		push_error("Не удалось прочитать сценарий: " + dialogue_file)
		set_process(false)
		return
	story = parsed
	nodes = story["nodes"]
	$Incoming/Content/Answer.pressed.connect(answer)
	hotspot.pressed.connect(answer)
	next_button.pressed.connect(advance)
	$Result/Content/Replay.pressed.connect(replay)
	incoming.hide()
	panel.hide()
	result_panel.hide()
	hotspot.hide()

func set_phone_rect(rect: Rect2) -> void:
	hotspot.position = rect.position
	hotspot.size = rect.size

func _process(delta: float) -> void:
	if mode == Mode.WAITING:
		waiting_time += delta
		if waiting_time >= ring_delay:
			start_ringing()
	elif mode == Mode.RINGING:
		ringing_time += delta
		if ringing_time >= 6.0:
			ringing_time = 0.0
			_play_ring()
	elif mode == Mode.TALKING and is_typing():
		typed_characters += delta * characters_per_second
		body.visible_characters = mini(int(typed_characters), body.text.length())
		if not is_typing():
			reveal_line()

func start_ringing() -> void:
	if mode != Mode.WAITING:
		return
	mode = Mode.RINGING
	ringing_time = 0.0
	incoming.show()
	hotspot.show()
	_play_ring()

func _play_ring() -> void:
	if sound_enabled:
		ringtone.play()

func answer() -> void:
	if mode != Mode.RINGING:
		return
	ringtone.stop()
	incoming.hide()
	hotspot.hide()
	mode = Mode.TALKING
	panel.show()
	_go_to(str(story["start"]))
	if not external_ui:
		next_button.grab_focus()

func _go_to(id: String) -> void:
	if not nodes.has(id):
		push_error("Не найдена реплика " + id)
		return
	current_id = id
	current = nodes[id]
	history.append(id)
	if current.get("accept", false):
		accepted = true
	speaker_label.text = str(current["speaker"]).to_upper()
	body.text = str(current["text"])
	body.visible_characters = 0
	typed_characters = 0.0
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	choices_box.hide()
	next_button.show()
	next_button.text = "Показать реплику  ·  Enter"

func is_typing() -> bool:
	return body.visible_characters >= 0 and body.visible_characters < body.text.length()

func reveal_line() -> void:
	body.visible_characters = -1
	typed_characters = float(body.text.length())
	var choices: Array = current.get("choices", [])
	if not choices.is_empty():
		next_button.hide()
		choices_box.show()
		if choices_box.get_child_count() == 0:
			for index in range(choices.size()):
				var button := Button.new()
				button.text = str(index + 1) + ". " + str(choices[index]["text"])
				button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				button.custom_minimum_size.y = 40.0
				button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				button.pressed.connect(select_choice.bind(index))
				choices_box.add_child(button)
	else:
		next_button.text = "Закончить звонок  ·  Enter" if current.get("end", false) else "Дальше  →  Enter"

func advance() -> void:
	if mode != Mode.TALKING:
		return
	if is_typing():
		reveal_line()
		return
	if current.has("choices"):
		return
	if current.get("end", false):
		_finish()
	else:
		_go_to(str(current["next"]))

func select_choice(index: int) -> void:
	if mode != Mode.TALKING or is_typing():
		return
	var choices: Array = current.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	_go_to(str(choices[index]["next"]))
	if not external_ui:
		next_button.grab_focus()

func _finish() -> void:
	mode = Mode.FINISHED
	panel.hide()
	ringtone.stop()
	result_text.text = str(story["result"])
	result_panel.show()
	conversation_finished.emit(accepted)

func replay() -> void:
	if mode != Mode.FINISHED:
		return
	result_panel.hide()
	accepted = false
	history.clear()
	mode = Mode.RINGING
	answer()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if mode == Mode.RINGING and event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
		answer()
	elif mode == Mode.TALKING and event.keycode in [KEY_ENTER, KEY_SPACE]:
		advance()
	elif mode == Mode.TALKING and event.keycode in [KEY_1, KEY_2]:
		select_choice(0 if event.keycode == KEY_1 else 1)
	else:
		return
	get_viewport().set_input_as_handled()
