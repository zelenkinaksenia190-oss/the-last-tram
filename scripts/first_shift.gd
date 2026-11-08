extends Node2D
## Первый рейс: реальное движение по маршруту, остановки, двери, пассажиры и SMS.
@export var sound_enabled: bool = true
@export var maximum_speed: float = 10.0
@onready var phone = $Interface/Phone
var story: Dictionary
var world
var outside: SubViewport
var world_image: TextureRect
var cab: Sprite2D
var reflections: Array[Sprite2D] = []
var phase: String = "intro"
var progress: float = 0.0
var speed: float = 0.0
var gear: int = 1
var doors_open: bool = false
var served: int = 0
var elapsed: float = 0.0
var look_target := Vector2.ZERO
var look := Vector2.ZERO
var captured: bool = false
var focus_paused: bool = false
var mirror_empty: bool = false
var notice: String = ""
var notice_until: float = 0.0
var rolling: AudioStreamPlayer
var hud: Control
var route_label: Label
var status_label: Label
var controls: Label
var thought: Label
var door_button: Button
var dialogue_panel: PanelContainer
var speaker: Label
var speech: Label
var dialogue_next: Button
var choices: Array[Button] = []
var dialogue_queue: Array = []
var dialogue_index: int = 0
var dialogue_age: float = 0.0
var card: ColorRect
var card_chapter: Label
var card_body: Label
var card_next: Button
var card_menu: Button
var card_replay: Button
var card_index: int = 0
var card_age: float = 0.0

func _ready() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_window().title="Последний трамвай — первая смена"
	story=JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/first_shift.json"))
	outside=SubViewport.new()
	outside.name="MovingRoute"
	outside.size=Vector2i(960,540)
	outside.own_world_3d=true
	outside.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(outside)
	world=load("res://FirstShiftOutside.tscn").instantiate()
	outside.add_child(world)
	world_image=TextureRect.new()
	world_image.texture=outside.get_texture()
	world_image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	world_image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(world_image)
	cab=Sprite2D.new()
	cab.name="CabinFrame"
	cab.texture=load("res://assets/tram-cabin-cutout-v1.png")
	cab.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(cab)
	var passengers: Texture2D=load("res://assets/tram-passengers-v1.png")
	var mirror_clip := Control.new()
	mirror_clip.name="MirrorPassengers"
	mirror_clip.position=Vector2(1115,40)-cab.texture.get_size()*0.5
	mirror_clip.size=Vector2(535,185)
	mirror_clip.clip_contents=true
	mirror_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cab.add_child(mirror_clip)
	var placements=[Vector2(1240,185),Vector2(1510,162),Vector2(1310,137)]
	var heights=[140.0,100.0,76.0]
	for i in range(3):
		var passenger := Sprite2D.new()
		passenger.texture=passengers
		passenger.region_enabled=true
		passenger.region_rect=Rect2(i*passengers.get_width()/3.0,0,passengers.get_width()/3.0,passengers.get_height())
		passenger.scale=Vector2.ONE*(float(heights[i])/passengers.get_height())
		passenger.position=placements[i]-Vector2(1115,40)
		passenger.modulate=Color(0.65,0.63,0.53)
		passenger.hide()
		mirror_clip.add_child(passenger)
		reflections.append(passenger)
	# Seat backs stay in front of seated passengers and hide their lower legs.
	for patch in [Rect2(1130,186,220,44),Rect2(1450,182,200,48),Rect2(1285,162,58,18)]:
		var seat := Sprite2D.new()
		seat.texture=cab.texture
		seat.region_enabled=true
		seat.region_rect=patch
		seat.position=patch.position+patch.size*0.5-cab.texture.get_size()*0.5
		cab.add_child(seat)
	phone.story_active=false
	phone.sound_enabled=sound_enabled
	phone.set_phone_rect(Rect2())
	_build_ui()
	_build_audio()
	get_viewport().size_changed.connect(_fit)
	_fit()
	show_card()
	world.set_distance(0,Vector2.ZERO)

func label(parent: Node, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.add_theme_color_override("font_shadow_color",Color(0.01,0.02,0.015,0.9))
	result.add_theme_constant_override("shadow_offset_y",2)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func button(parent: Node, text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text=text
	result.focus_mode=Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size",16)
	result.add_theme_color_override("font_color",Color("dfc99c"))
	for state in ["normal","hover","pressed","focus"]: result.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func _build_ui() -> void:
	hud=Control.new()
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	$Interface.add_child(hud)
	route_label=label(hud,15,Color("e2d3ae"))
	status_label=label(hud,18,Color("e2d3ae"))
	status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	controls=label(hud,13,Color("cecbb4"))
	thought=label(hud,19,Color("e7dfcb"))
	thought.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	thought.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	door_button=button(hud,"F · Открыть двери",toggle_doors)
	dialogue_panel=PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.035,0.055,0.043,0.96)
	style.content_margin_left=25
	style.content_margin_right=25
	style.content_margin_top=18
	style.content_margin_bottom=14
	style.border_width_top=1
	style.border_color=Color("786344")
	dialogue_panel.add_theme_stylebox_override("panel",style)
	$Interface.add_child(dialogue_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	dialogue_panel.add_child(column)
	speaker=label(column,13,Color("b99a64"))
	speech=label(column,21,Color("ded8c5"))
	speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",25)
	column.add_child(row)
	dialogue_next=button(row,"Дальше →",advance_dialogue)
	for i in range(2):
		var choice := button(row,"",choose_reply.bind(i))
		choices.append(choice)
	dialogue_panel.hide()
	card=ColorRect.new()
	card.color=Color("070b09")
	card.mouse_filter=Control.MOUSE_FILTER_STOP
	$Interface.add_child(card)
	card_chapter=label(card,14,Color("bda16d"))
	card_body=label(card,24,Color("d7d2c2"))
	card_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	card_body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	card_next=button(card,"Дальше →",advance_card)
	card_menu=button(card,"В меню",return_to_menu)
	card_replay=button(card,"Повторить рейс",replay)

func _build_audio() -> void:
	rolling=AudioStreamPlayer.new()
	var stream: AudioStreamWAV=load("res://assets/audio/train-interior-real.wav").duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=int(stream.get_length()*stream.mix_rate)
	rolling.stream=stream
	rolling.volume_db=-60
	add_child(rolling)
	if sound_enabled: rolling.play()

func _fit() -> void:
	var view := get_viewport_rect().size
	world_image.size=view
	hud.size=view
	var image_scale: float=view.y*1.10/cab.texture.get_height()
	cab.scale=Vector2.ONE*image_scale
	route_label.position=Vector2(24,18)
	route_label.size=Vector2(view.x*0.70,30)
	status_label.position=Vector2(view.x-360,18)
	status_label.size=Vector2(335,30)
	controls.position=Vector2(24,view.y-27)
	controls.size=Vector2(view.x-48,25)
	thought.position=Vector2(view.x*0.18,view.y-170)
	thought.size=Vector2(view.x*0.64,70)
	door_button.position=Vector2(24,view.y-91)
	door_button.size=Vector2(270,45)
	dialogue_panel.position=Vector2(view.x*0.12,view.y*0.69)
	dialogue_panel.size=Vector2(view.x*0.76,0)
	card.size=view
	var width: float=minf(780,view.x-80)
	var left: float=(view.x-width)/2
	card_chapter.position=Vector2(left,view.y*0.17)
	card_chapter.size=Vector2(width,35)
	card_body.position=Vector2(left,view.y*0.26)
	card_body.size=Vector2(width,view.y*0.44)
	card_next.position=Vector2(left+width-230,view.y*0.80)
	card_next.size=Vector2(230,45)
	card_menu.position=Vector2(left,view.y*0.80)
	card_menu.size=Vector2(110,45)
	card_replay.position=Vector2(left+170,view.y*0.80)
	card_replay.size=Vector2(200,45)

func show_card() -> void:
	card_age=0
	card.show()
	hud.hide()
	phone.story_active=false
	phone.put_away()
	phone.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var pages: Array=story["intro"] if phase=="intro" else story["ending"]
	var page: Dictionary=pages[card_index]
	card_chapter.text=page["chapter"]
	card_body.text=page["text"]
	card_next.text="Начать рейс →" if phase=="intro" and card_index==pages.size()-1 else "Дальше →"
	card_next.show()
	card_menu.hide()
	card_replay.hide()
	card_body.modulate.a=0
	create_tween().tween_property(card_body,"modulate:a",1.0,0.45)

func advance_card() -> void:
	if card_age<0.6 or phase not in ["intro","ending"]: return
	var pages: Array=story["intro"] if phase=="intro" else story["ending"]
	card_index+=1
	if card_index<pages.size(): show_card()
	elif phase=="intro": start_driving()
	else:
		phase="complete"
		get_tree().set_meta("olhovsk_first_shift_complete",true)
		card_chapter.text="ПЕРВЫЙ КРУГ / КОНЕЦ ГЛАВЫ"
		card_body.text="Кто вёл этот вагон до меня?\n\nИ кого я только что привёз обратно?"
		card_next.hide()
		card_menu.show()
		card_replay.show()

func start_driving() -> void:
	phase="driving"
	card.hide()
	hud.show()
	phone.show()
	phone.story_active=true
	capture_look()

func capture_look() -> void:
	if phase!="driving" or phone.phone_open: return
	captured=true
	focus_paused=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func notify(text: String, duration: float=6.0) -> void:
	notice=text
	notice_until=elapsed+duration

func _physics_process(delta: float) -> void:
	if phase!="driving" or focus_paused: return
	if phone.phone_open:
		speed=0
		return
	if doors_open: speed=0
	elif Input.is_physical_key_pressed(KEY_SPACE): speed=move_toward(speed,0,8*delta)
	elif Input.is_physical_key_pressed(KEY_S): speed=move_toward(speed,0,3.5*delta)
	elif Input.is_physical_key_pressed(KEY_W): speed=minf(maximum_speed,speed+1.8*delta)
	else: speed=move_toward(speed,0,0.12*delta)
	progress=clampf(progress+speed*gear*delta,0,465)
	if progress<=0 or progress>=465: speed=0
	if served>=3 and progress>=455: begin_ending()

func _process(delta: float) -> void:
	elapsed+=delta
	card_age+=delta
	dialogue_age+=delta
	card_next.disabled=card_age<0.6
	dialogue_next.disabled=dialogue_age<0.45
	if phase=="driving" and not phone.phone_open and not focus_paused:
		var arrows := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		look_target+=arrows*delta*430
		clamp_look()
	look=look.lerp(look_target,1.0-exp(-delta*10))
	var view := get_viewport_rect().size
	# The painted cabin and mirror stay fixed; only the view outside follows the head.
	cab.position=view*0.5
	world.set_distance(progress,Vector2(look.x*0.0016,-look.y*0.0008))
	if phase=="driving" and served>=3 and progress>405 and not mirror_empty and (look.x>160 or progress>435):
		mirror_empty=true
		for reflection in reflections: reflection.hide()
		notify("В зеркале — пустой салон.\nНо я не открывал двери.",8)
	rolling.volume_db=lerpf(rolling.volume_db,-24.0+linear_to_db(maxf(speed/maximum_speed,0.015)) if phase=="driving" and not phone.phone_open and not focus_paused else -60.0,1.0-exp(-delta*3))
	if phase in ["driving","dialogue"]: update_hud()
	if phone.phone_open: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	elif phase=="driving" and captured and not focus_paused: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func clamp_look() -> void:
	var extent: float=maxf(0,(cab.texture.get_width()*cab.scale.x-get_viewport_rect().size.x)/2-8)
	look_target.x=clampf(look_target.x,-extent,extent)
	look_target.y=clampf(look_target.y,-38,38)

func update_hud() -> void:
	var target: Dictionary=story["stops"][served] if served<3 else {"name":"Депо","distance":455}
	var distance: float=float(target["distance"])-progress
	var proximity: String="%d м" % absi(roundi(distance))
	if distance < -12: proximity+=" позади · R — задний ход"
	route_label.text="ПЕРВАЯ СМЕНА · "+str(target["name"])+" · "+proximity
	status_label.text="%02d км/ч  ·  %s" % [roundi(speed*3.6),"ДВЕРИ ОТКРЫТЫ" if doors_open else ("ЗАДНИЙ ХОД" if gear<0 else "ДВЕРИ ЗАКРЫТЫ")]
	controls.text="W — разгон · S — тормоз · Пробел — стоп · F — двери · E — SMS · R — назад · Мышь / стрелки — осмотр · Esc — курсор"
	thought.text=notice if elapsed<notice_until else ("Щёлкните по кабине, чтобы продолжить." if focus_paused else "")
	thought.visible=phase=="driving" and not phone.phone_open
	controls.visible=phase=="driving"
	door_button.visible=phase=="driving" and not phone.phone_open and speed<0.2
	door_button.text="F · Закрыть двери" if doors_open else "F · Открыть двери"
	phone.phone_time="06:%02d" % (40+mini(17,int(progress/27)))

func toggle_doors() -> void:
	if phase!="driving" or phone.phone_open: return
	if speed>=0.2:
		notify("Сначала нужно остановить вагон.")
		return
	if doors_open:
		doors_open=false
		notify("Двери закрыты. Можно ехать.",3)
		return
	if served>=3 or absf(progress-float(story["stops"][served]["distance"]))>12:
		notify("Между остановками двери открывать не буду.")
		return
	doors_open=true
	begin_boarding()

func begin_boarding() -> void:
	phase="dialogue"
	speed=0
	phone.put_away()
	phone.story_active=false
	phone.hide()
	captured=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var stop: Dictionary=story["stops"][served]
	world.board_passenger(served)
	reflections[served].show()
	dialogue_queue=stop["lines"].duplicate(true)
	dialogue_index=0
	show_dialogue()

func show_dialogue() -> void:
	dialogue_age=0
	var line: Dictionary=dialogue_queue[dialogue_index]
	speaker.text=str(line["speaker"]).to_upper()
	speech.text=line["text"]
	var options: Array=line.get("choices",[])
	dialogue_next.visible=options.size()!=2
	for i in range(2):
		choices[i].visible=options.size()==2
		if options.size()==2: choices[i].text=str(i+1)+". "+str(options[i]["text"])
	dialogue_panel.show()
	door_button.hide()

func advance_dialogue() -> void:
	if phase!="dialogue" or dialogue_age<0.45: return
	if dialogue_queue[dialogue_index].has("choices"): return
	dialogue_index+=1
	if dialogue_index<dialogue_queue.size(): show_dialogue()
	else:
		dialogue_panel.hide()
		served+=1
		phase="driving"
		phone.show()
		phone.story_active=true
		if served==2:
			phone.pending_receive=""
			phone.pending_reply=""
			phone.finished=false
			phone._receive_until_reply("warning")
		notify("Закрою двери и продолжу маршрут.",5)
		capture_look()

func choose_reply(index: int) -> void:
	if phase!="dialogue" or dialogue_age<0.45: return
	var options: Array=dialogue_queue[dialogue_index].get("choices",[])
	if options.size()!=2 or index<0 or index>=2: return
	var choice: Dictionary=options[index]
	dialogue_queue[dialogue_index]={"speaker":"Вы","text":choice["text"]}
	dialogue_queue.insert(dialogue_index+1,{"speaker":"Пожилая женщина","text":choice["response"]})
	show_dialogue()

func begin_ending() -> void:
	phase="ending"
	speed=0
	doors_open=false
	card_index=0
	for reflection in reflections: reflection.hide()
	show_card()

func replay() -> void:
	get_tree().set_meta("olhovsk_first_shift_complete",false)
	get_tree().change_scene_to_file("res://FirstShift.tscn")

func return_to_menu() -> void:
	get_tree().set_meta("olhovsk_key_taken",false)
	get_tree().set_meta("olhovsk_evening_complete",false)
	get_tree().change_scene_to_file("res://Apartment.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and phase=="driving" and captured and not phone.phone_open and not focus_paused:
		look_target+=event.screen_relative*0.65
		clamp_look()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if phone.phone_open: return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if phase=="driving": capture_look()
		elif phase in ["intro","ending"]: advance_card()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if phase in ["intro","ending"] and event.keycode in [KEY_SPACE,KEY_ENTER]: advance_card()
		elif phase=="dialogue":
			if event.keycode in [KEY_SPACE,KEY_ENTER]: advance_dialogue()
			elif event.keycode in [KEY_1,KEY_2]: choose_reply(0 if event.keycode==KEY_1 else 1)
		elif phase=="driving":
			match event.keycode:
				KEY_F: toggle_doors()
				KEY_R:
					if speed<0.2: gear*=-1
					else: notify("Перед сменой направления нужно остановиться.")
				KEY_HOME: look_target=Vector2.ZERO
				KEY_ESCAPE:
					captured=false
					Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
				KEY_M: look_target=Vector2(260,-25)
				_: return
		else: return
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		captured=false
		focus_paused=true
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
