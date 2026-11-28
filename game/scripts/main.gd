extends Control

const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const DAY = preload("res://assets/pixel/campsite-day-terrain.png")
const NIGHT = preload("res://assets/pixel/campsite-night-terrain.png")
const CAMPER_SHEET = preload("res://assets/pixel/camper-animations.png")
const SCENERY_SHADER = preload("res://assets/pixel/campsite.gdshader")
const UI_INPUT = preload("res://ui/ui_input.gd")
const CAMP_EDITOR = preload("res://ui/components/camp_editor_3d.gd")
const MVP_FLOW = preload("res://ui/screens/mvp_flow.tscn")
const MVP_ASSETS = preload("res://ui/components/mvp_assets.gd")
const FIRST_WEEK = preload("res://ui/screens/first_week.tscn")
const CHARACTER_SELECT = preload("res://ui/screens/character_select.tscn")
const CHARACTER_CATALOG = preload("res://ui/components/character_catalog.gd")
const HUD = preload("res://scripts/camp_hud.gd")
const CampActor = preload("res://scripts/camp_actor.gd")
var actor = CampActor.new()
var actor_message := ""
const SAVE_PATH = "user://prototype_session.cfg"
var session_save_path := SAVE_PATH
const TITLES = {"work": "주말을 기다리는 평일", "shopping": "이번 저녁엔 뭘 먹을까?", "packing": "트렁크에 주말을 담아요", "setup": "나만의 작은 캠프", "free": "잠깐, 아무것도 하지 않기", "dinner": "밖에서 먹으면 더 맛있지", "night": "불 앞에서 보내는 밤", "breakfast": "느긋한 아침 한 입", "teardown": "머문 자리를 정리해요", "settlement": "잘 쉬었다. 다음 주에도!"}
var state: Dictionary = {}
var version := 0
var token := ""
var base_url := "http://127.0.0.1:8000/api/v1/prototype/"
var busy := false
var request_kind := ""
var camp_world
var mvp_screen: Control
var heartbeat_request := false
var office_elapsed := 0.0
var queued_action: Dictionary = {}
var last_request_error := false
var migration_attempted := false
var work_screen: Control
var progress_check_required := false
var working_request := false
var character_screen: Control
var character_check_required := false
var selecting_character_request := false
var displayed_character := ""
var message := "서버에 연결하는 중이에요."
var http: HTTPRequest
var content: VBoxContainer
var hud
var real_shadows := true
var actions: GridContainer
var ground_fade: GradientTexture2D
var camper_sprite: AnimatedSprite2D
var scenery: TextureRect
var scenery_material: ShaderMaterial
var preview_mode := "auto"
var camper_position := Vector2(0.60, 0.80)
var camper_target := Vector2(0.60, 0.80)
var facing_left := false
var direct_movement := false

func _ready() -> void:
	UI_INPUT.ensure()
	actor.installation_ready.connect(func():
		if mvp_screen != null: mvp_screen.save_installation())
	focus_mode = Control.FOCUS_ALL
	preload("res://ui/ui_metrics.gd").configure_window(get_tree().root)
	get_tree().root.size_changed.connect(func():
		preload("res://ui/ui_metrics.gd").configure_window(get_tree().root))
	if OS.has_feature("web"):
		base_url = str(JavaScriptBridge.eval("window.location.origin")) + "/api/v1/prototype/"
	var theme_asset := Theme.new()
	var readable_font := FontVariation.new()
	readable_font.base_font = FONT
	readable_font.variation_opentype = {"wght": 500}
	readable_font.variation_embolden = 0.3
	theme_asset.default_font = readable_font
	theme_asset.default_font_size = 17
	theme = theme_asset
	var ground_gradient := Gradient.new()
	ground_gradient.colors=PackedColorArray([Color(0.13,0.25,0.17,0),Color(0.13,0.25,0.17,1)])
	ground_fade=GradientTexture2D.new()
	ground_fade.gradient=ground_gradient
	ground_fade.fill_from=Vector2.ZERO
	ground_fade.fill_to=Vector2(0,1)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scenery = TextureRect.new()
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode = TextureRect.STRETCH_SCALE
	scenery.z_index = -1
	scenery_material = ShaderMaterial.new()
	scenery_material.shader = SCENERY_SHADER
	scenery.material = scenery_material
	add_child(scenery)
	camper_sprite = AnimatedSprite2D.new()
	var frames := CHARACTER_CATALOG.frames("female")
	var cell := Vector2(CAMPER_SHEET.get_size()) / Vector2(4, 2)
	camper_sprite.sprite_frames = frames
	camper_sprite.offset = Vector2(0, -cell.y * 0.46)
	camper_sprite.z_index = 3
	add_child(camper_sprite)
	camper_sprite.play("idle")
	camp_world = CAMP_EDITOR.new()
	camp_world.readonly = true
	camp_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camp_world.z_index = 2
	camp_world.visible = false
	add_child(camp_world)
	hud=HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	content=hud.content
	hud.account_requested.connect(func():
		if OS.has_feature("web"):JavaScriptBridge.eval("window.location.assign('/?account=1')")
	)
	hud.reload_requested.connect(_load_state)
	hud.view_selected.connect(func(id: int):
		if id<=2:
			preview_mode=["auto","day","night"][id]
		elif id==3:
			camp_world.effects.enabled=not camp_world.effects.enabled
		elif id==4:
			real_shadows=not real_shadows
			camp_world.effects.shadows=real_shadows
		_render()
	)
	resized.connect(_layout)
	_layout()
	http = HTTPRequest.new()
	http.timeout = 10
	add_child(http)
	http.request_completed.connect(_on_response)
	var saved := ConfigFile.new()
	if saved.load(session_save_path) == OK:
		token = saved.get_value("session", "token", "")
	_render()
	_load_state()
	print("Prototype viewport: ", get_viewport_rect().size, " control: ", size, " window: ", get_tree().root.size)

func _is_night() -> bool:
	return preview_mode == "night" or (preview_mode == "auto" and (state.get("phase", "") == "night" or (state.has("mvp_version") and int(state.get("camp_minute", 960)) >= 1080 and state.get("phase", "") in ["setup", "free", "cooking", "meal_ready", "teardown"])))

func _scene_rect() -> Rect2:
	if mvp_screen != null:
		return Rect2(Vector2.ZERO, size)
	if size.x<600:
		return Rect2(Vector2.ZERO,Vector2(size.x,maxf(320,size.y*0.72)))
	return Rect2(Vector2.ZERO,size)

func _source_rect() -> Rect2:
	var area := _scene_rect()
	var dimensions := Vector2(DAY.get_size())
	var scale_factor := maxf(area.size.x / dimensions.x, area.size.y / dimensions.y)
	var visible := area.size / scale_factor
	return Rect2((dimensions - visible) * Vector2(0.78 if size.x<600 else 0.88, 0.5), visible)

func _scene_point(point: Vector2) -> Vector2:
	var source := _source_rect()
	return _scene_rect().position + (point * Vector2(DAY.get_size()) - source.position) * (_scene_rect().size.x / source.size.x)

func _layout() -> void:
	if scenery==null:return
	scenery.position=_scene_rect().position
	scenery.size=_scene_rect().size
	if hud!=null:hud.fit.call_deferred()
	queue_redraw()

func _camp_is_active() -> bool:
	return not bool(JavaScriptBridge.eval("document.hidden")) if OS.has_feature("web") else DisplayServer.window_is_focused()

func _process(delta: float) -> void:
	_tick_office(delta)
	if camp_world != null and camp_world.visible:
		var active := _camp_is_active()
		if active and not progress_check_required:
			if state.get("phase","") == "free":
				var focused := get_viewport().gui_get_focus_owner()
				var direction := Vector2.ZERO
				if focused == null or focused == self or (mvp_screen != null and mvp_screen.viewing_scenery):
					direction=Input.get_vector("camp_left","camp_right","camp_up","camp_down")
				else:
					direction=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
				var along: Vector3=camp_world.camera.global_basis.x*direction.x-camp_world.camera.global_basis.y*direction.y
				actor.direct(Vector2(along.x,along.z).normalized()*direction.length(),delta)
				if direction.length()>.1: actor_message=""
				var use_key := Input.is_action_just_pressed("ui_accept")
				if use_key and (focused == self or focused == null) and mvp_screen != null and mvp_screen.viewing_scenery: _seat_nearest()
			actor.advance(delta)
		queue_redraw()
		return
	var previous := camper_position
	direct_movement = false
	if state.get("phase", "") == "free":
		var focused := get_viewport().gui_get_focus_owner()
		var direction := Vector2.ZERO
		if focused == null or focused == self:
			direction = Input.get_vector("camp_left","camp_right","camp_up","camp_down")
		elif not focused is LineEdit:
			direction = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if direction.length()>.1:
			direct_movement = true
			camper_target = camper_position + direction.limit_length(1)*delta*.055
			camper_target.x = clampf(camper_target.x,.47,.66)
			camper_target.y = clampf(camper_target.y,.74,.92)
	camper_position = camper_position.move_toward(camper_target, delta * 0.055)
	if absf(camper_position.x - previous.x) > 0.00001:
		facing_left = camper_position.x < previous.x
	queue_redraw()

func _tick_office(delta: float) -> void:
	var remaining := int(state.get("office_remaining_ms", 0))
	if work_screen == null or not state.get("office_task", {}).get("active", false) or remaining <= 0:
		office_elapsed = 0
		return
	var active := not bool(JavaScriptBridge.eval("document.hidden")) if OS.has_feature("web") else DisplayServer.window_is_focused()
	if not active or progress_check_required:
		return
	office_elapsed = minf(2.0, office_elapsed + delta)
	var elapsed_ms := mini(remaining, int(office_elapsed * 1000))
	if not busy and (elapsed_ms >= 1000 or elapsed_ms >= remaining):
		office_elapsed = maxf(0, office_elapsed - elapsed_ms / 1000.0)
		_send("actions/", {"command":"tick", "elapsed_ms":elapsed_ms, "version":version})

func _seat_nearest() -> void:
	if not state.get("field",{}).has("chair"): return
	var chair: Dictionary=state.field.chair
	var point := Vector3(float(chair.x),float(chair.y),float(chair.z))
	if actor.position.distance_to(point)>2.5:
		actor_message="의자 가까이에서 확인 버튼을 눌러 주세요"
		return
	if not actor.seat(point,CAMP_EDITOR.rotation_of(chair)):
		actor_message="의자까지 갈 수 있는 길이 없어요"

func _gui_input(event: InputEvent) -> void:
	if character_screen != null or work_screen != null: return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or not _scene_rect().has_point(event.position): return
	if camp_world.visible:
		if state.get("phase","") != "free" or progress_check_required: return
		grab_focus()
		var item: String=camp_world.pick_item(event.position)
		if item == "chair" and state.get("field",{}).has("chair"):
			var p: Dictionary=state.field.chair
			if not actor.seat(Vector3(float(p.x),float(p.y),float(p.z)),CAMP_EDITOR.rotation_of(p)):
				actor_message="의자까지 갈 수 있는 길이 없어요"
		else:
			var at=camp_world.ground_point(event.position,0)
			if at!=null: actor.move_to(Vector3(at)+Vector3(camp_world.origin_x,0,camp_world.origin_z))
		accept_event()
		return
	grab_focus()
	var source := _source_rect()
	var uv: Vector2 = ((event.position - _scene_rect().position) / _scene_rect().size * source.size + source.position) / Vector2(DAY.get_size())
	camper_target = Vector2(clampf(uv.x, 0.47, 0.66), clampf(uv.y, 0.74, 0.92))

func _draw() -> void:
	if scenery == null:
		return
	var night := _is_night()
	if state.get("place", "") == "pine":
		scenery.texture = MVP_ASSETS.PINE_NIGHT if night else MVP_ASSETS.PINE
	else:
		scenery.texture = NIGHT if night else DAY
	scenery.modulate = Color.WHITE
	var area := _scene_rect()
	var source := _source_rect()
	if area.end.y<size.y:
		draw_rect(Rect2(0,area.end.y,size.x,size.y-area.end.y),Color(0.13,0.25,0.17,1))
		draw_texture_rect(ground_fade,Rect2(0,area.end.y-75,size.x,75),false)
	scenery_material.set_shader_parameter("source_offset", source.position / Vector2(DAY.get_size()))
	scenery_material.set_shader_parameter("source_scale", source.size / Vector2(DAY.get_size()))
	var scale_factor := area.size.x / source.size.x
	var walking := direct_movement or camper_position.distance_to(camper_target) > 0.001
	var foot := _scene_point(camper_position)
	var sprite_height := Vector2(DAY.get_size()).y * 0.22 * scale_factor
	var cell := Vector2(CAMPER_SHEET.get_size()) / Vector2(4, 2)
	var shared_3d: bool=camp_world!=null and camp_world.visible
	camper_sprite.visible=not shared_3d and state.get("phase", "") != "work"
	if shared_3d:
		var world_foot: Vector3=actor.position-Vector3(camp_world.origin_x,0,camp_world.origin_z)
		var waiting_outside: bool = state.get("phase", "") == "setup" and actor.mode not in ["approach_install", "install", "saving"]
		if waiting_outside:
			world_foot = Vector3(-camp_world.origin_x + .5, 0, camp_world.site_depth - camp_world.origin_z + .55)
		var pose: String="idle" if waiting_outside else actor.animation()
		camp_world.update_camper(camper_sprite.sprite_frames,camp_world.screen_point(world_foot),pose == "walk",actor.facing_left if actor.mode != "sit" else false,pose,.1 if actor.mode == "sit" else 0.0)
		if mvp_screen != null and mvp_screen.viewing_scenery:
			mvp_screen.scenery_hint.text=actor_message if not actor_message.is_empty() else "터치: 이동 · 의자에 앉기" if size.x < 760 or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() else "바닥/방향키: 이동 · 의자/확인: 앉기 · Esc/B: 종료"
		camp_world.effects.night=night
	camper_sprite.position=foot
	camper_sprite.scale=Vector2.ONE*sprite_height/(cell.y*.9)
	camper_sprite.flip_h=facing_left
	var animation := "walk" if walking else "idle"
	if camper_sprite.animation != animation:
		camper_sprite.play(animation)

func _label(text_value: String, font_size: int = 15) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("304b40"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)

func _button(text_value: String, command: String, choice: String = "", enabled: bool = true) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = busy or not enabled
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e5848")
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("fff3d5"))
	button.pressed.connect(func():
		if command == "reload":
			_load_state()
		else:
			_send("actions/", {"command": command, "choice": choice, "version": version})
	)
	if actions==null:
		actions=GridContainer.new()
		actions.columns=2
		actions.add_theme_constant_override("h_separation",8)
		actions.add_theme_constant_override("v_separation",8)
		content.add_child(actions)
	actions.add_child(button)
	actions.columns=mini(2,actions.get_child_count())

func _render() -> void:
	if not state.is_empty() and not state.has("mvp_version") and state.get("phase", "") in ["character", "work", "shopping", "settlement"] and not busy and not migration_attempted:
		migration_attempted = true
		_send("actions/", {"command":"upgrade_mvp", "choice":"", "version":version})
		return
	var use_mvp: bool = state.has("mvp_version") and state.get("phase", "") not in ["character", "work"]
	if not use_mvp and mvp_screen != null:
		remove_child(mvp_screen)
		mvp_screen.queue_free()
		mvp_screen = null
	var show_3d_camp: bool = state.has("mvp_version") and state.get("phase", "") in ["setup","free","cooking","meal_ready","sleep_required","teardown","return_pack"]
	camp_world.visible = show_3d_camp
	if not show_3d_camp or state.get("phase","") != "setup":
		if actor.mode in ["approach_install","install","saving"]: actor.cancel()
	if state.get("phase","") != "free" and actor.mode in ["sit","approach_seat","walk"]: actor.cancel()
	if show_3d_camp:
		camp_world.readonly = state.get("phase", "") != "setup"
		if state.get("phase", "") != "setup" or mvp_screen == null:
			camp_world.configure(state)
	var needs_character: bool = state.get("phase", "") == "character"
	hud.visible = not needs_character and state.get("phase", "") != "work" and not use_mvp
	if needs_character:
		if character_screen == null:
			character_screen = CHARACTER_SELECT.instantiate()
			character_screen.z_index = 10
			character_screen.confirm_requested.connect(func(id: String):
				_send("actions/", {"command": "select_character", "choice": id, "version": version}))
			character_screen.reload_requested.connect(_load_state)
			add_child(character_screen)
		character_screen.set_request_state(busy,
			message if busy or character_check_required else "캐릭터를 선택한 뒤 확정해 주세요.", character_check_required)
		return
	if character_screen != null:
		remove_child(character_screen)
		character_screen.queue_free()
		character_screen = null
	if state.get("phase", "") == "work":
		if work_screen == null:
			work_screen = FIRST_WEEK.instantiate()
			work_screen.z_index = 10
			work_screen.work_requested.connect(func():
				work_screen.outcome = ""
				_send("actions/", {"command": "work", "choice": "", "version": version}))
			work_screen.reload_requested.connect(_load_state)
			work_screen.office_action_requested.connect(func(command: String,choice: String,extra: Dictionary):
				var payload:=extra.duplicate()
				if command == "office_pause":
					payload["elapsed_ms"] = int(office_elapsed * 1000)
					office_elapsed = 0
				payload.merge({"command":command,"choice":choice,"version":version},true)
				_send("actions/",payload))
			work_screen.account_requested.connect(func():
				if OS.has_feature("web"):
					JavaScriptBridge.eval("window.location.assign('/?account=1')"))
			add_child(work_screen)
		work_screen.apply_state(state, busy, message, progress_check_required)
		return
	if work_screen != null:
		remove_child(work_screen)
		work_screen.queue_free()
		work_screen = null
	var character_id: String = state.get("character_id", "female")
	var outfit: String = state.get("outfit", "basic")
	if character_id + outfit != displayed_character:
		camper_sprite.sprite_frames = CHARACTER_CATALOG.frames(character_id, outfit)
		camper_sprite.play("idle")
		displayed_character = character_id + outfit
	if use_mvp:
		if mvp_screen == null:
			mvp_screen = MVP_FLOW.instantiate()
			mvp_screen.z_index = 10
			mvp_screen.action_requested.connect(func(command: String, choice: String, extra: Dictionary):
				var payload := extra.duplicate()
				payload.merge({"command":command, "choice":choice, "version":version}, true)
				_send("actions/", payload))
			mvp_screen.reload_requested.connect(_load_state)
			mvp_screen.account_requested.connect(func():
				if OS.has_feature("web"): JavaScriptBridge.eval("window.location.assign('/?account=1')"))
			add_child(mvp_screen)
			mvp_screen.use_field_editor(camp_world)
			mvp_screen.installation_requested.connect(func(id: String, point: Vector3, angle: int):
				actor.position = actor.nearest(Vector3(.5, 0, camp_world.site_depth - .25))
				if not actor.install(id,point,angle):
					mvp_screen.install_failed("장비 옆까지 갈 수 없어요 · 위치를 바꾸거나 취소해 주세요"))
			mvp_screen.installation_cancelled.connect(func(): actor.cancel())
			mvp_screen.effects_toggled.connect(func(value: bool): camp_world.effects.enabled=value)
			mvp_screen.night_preview_toggled.connect(func(value: bool):
				preview_mode="night" if value else "day"
				camp_world.effects.night=value
				queue_redraw())
		mvp_screen.effects_button.set_pressed_no_signal(camp_world.effects.enabled)
		mvp_screen.night_button.set_pressed_no_signal(_is_night())
		mvp_screen.night_button.text="밤" if _is_night() else "낮"
		mvp_screen.apply_state(state, busy and not heartbeat_request, message if last_request_error else "", progress_check_required, busy)
		if show_3d_camp: actor.configure(state,camp_world)
		queue_redraw()
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	actions=null
	hud.update_stats(state,message)
	hud.set_view(camp_world.effects.enabled,real_shadows)
	if state.is_empty():
		_label(message)
		_button("서버 다시 연결", "reload")
		return
	var phase: String = state.phase
	_label(TITLES.get(phase, phase), 21)
	match phase:
		"work":
			_label("%s요일 · 오늘의 서류를 처리하고 캠핑 비용을 모아요." % ["월", "화", "수", "목", "금"][int(state.day)])
			_button("서류 처리  ·  기본급 +10", "work")
			_button("선택 물류 알바  ·  +15 / 체력 -8", "job", "", not state.job_done)
		"shopping":
			_label("저녁 재료와 아침 커피·토스트를 함께 구매해요.")
			_button("라면 장보기  ·  20", "buy", "ramen")
			_button("꼬치구이 장보기  ·  25", "buy", "skewer")
		"packing":
			_label("필수 장비 세 개를 골라 실어 주세요. 고급 장비는 테스트용 무료 대여예요.")
			for pair in [["tent", "텐트"], ["table", "테이블"], ["chair", "의자"]]:
				_button(("✓ " if pair[0] in state.packed else "＋ ") + pair[1], "pack", pair[0])
			_button("조리·휴식 장비: " + ("기본 가스 장비" if state.gear == "basic" else "고급 숯불 장비") + "  ↔", "gear", "improved" if state.gear == "basic" else "basic")
			_button("짐 싣기 완료 → 캠핑 출발", "next", "", state.packed.size() == 3)
		"setup":
			_label("한 단계씩 캠프를 완성해요.  %d / 3" % state.setup)
			_button(["텐트 펼치기", "테이블 놓기", "의자 놓기"][int(state.setup)], "install")
		"free":
			_label("숲을 바라보며 잠시 쉬어요. 원할 때 저녁으로 넘어갈 수 있어요.")
			_button("풍경 감상  ·  휴식", "rest", "", not state.rested)
			_button("다음 → 저녁 준비", "next")
		"dinner":
			if state.meal == "skewer" and state.ingredients.size() < 3:
				_label("꼬치에 재료를 세 개 꽂아요. 고기는 힘, 버섯은 행운 회복을 더해요.")
				_label("고기 %d개 · 버섯 %d개" % [state.ingredients.count("meat"), state.ingredients.count("mushroom")])
				_button("고기 꽂기", "ingredient", "meat")
				_button("버섯 꽂기", "ingredient", "mushroom")
			else:
				var total := 2 if state.gear == "improved" else 3
				_label("%s  ·  조리 %d / %d" % ["라면" if state.meal == "ramen" else "꼬치구이", state.cooking, total])
				_button("조리하기" if state.cooking < total - 1 else "완성하고 먹기", "cook")
		"night":
			_label("저녁 레시피 기록  " + "★".repeat(int(state.stars)) + "\n불멍은 자동으로 끝나지 않아요. 원할 때 다음을 눌러 잠들어요.")
			_button("불멍 즐기기  ·  휴식", "rest", "", not state.rested)
			_button("다음 → 취침하고 아침 맞기", "next")
		"breakfast":
			_label("믹스커피 한 잔과 따뜻한 버터 토스트로 하루를 시작해요.")
			_button("커피 타고 토스트 구워 먹기", "breakfast")
		"teardown":
			_label("장비를 정리해서 차에 실어요.  %d / 3" % state.teardown)
			_button(["의자 접기", "테이블 접기", "텐트 접어 싣기"][int(state.teardown)], "pack_up")
		"settlement":
			_label("재료를 사용하고 몸과 마음을 회복했어요.\n레시피 %d종 기록 · 이번 요리 %s\n소지금과 스탯, 레시피 기록은 다음 주에도 유지돼요." % [state.recipes.size(), "★".repeat(int(state.stars))])
			_button("다음 주 시작", "next")
	hud.fit.call_deferred()
	queue_redraw()

func _load_state() -> void:
	if OS.has_feature("web"):
		_send("state/")
	elif token.is_empty():
		_send("sessions/", {})
	else:
		_send("state/")

func _send(endpoint: String, body: Variant = null) -> void:
	if busy:
		if heartbeat_request and body is Dictionary and body.get("command", "") != "tick":
			queued_action = {"endpoint":endpoint, "body":body}
		return
	busy = true
	heartbeat_request = body is Dictionary and body.get("command", "") == "tick"
	if not heartbeat_request:
		last_request_error = false
	request_kind = endpoint
	working_request = endpoint == "actions/" and body is Dictionary and body.get("command", "") in ["work","office_finish"]
	selecting_character_request = endpoint == "actions/" and body is Dictionary and body.get("command", "") == "select_character"
	if not heartbeat_request:
		message = "진행을 저장하고 있어요…" if endpoint == "actions/" else "서버에 연결하고 있어요…"
	if not heartbeat_request:
		_render()
	var headers := PackedStringArray(["Content-Type: application/json"])
	if OS.has_feature("web"):
		headers.append("X-CP-Request: 1")
	elif not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var method := HTTPClient.METHOD_GET if body == null else HTTPClient.METHOD_POST
	var error := http.request(base_url + endpoint, headers, method, "" if body == null else JSON.stringify(body))
	if error != OK:
		busy = false
		last_request_error = true
		message = "요청을 시작하지 못했어요. 서버를 확인해 주세요."
		if selecting_character_request:
			character_check_required = true
		if working_request or state.has("mvp_version"):
			progress_check_required = true
		_render()

func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var previous_state := state.duplicate(true)
	var show_work_result := false
	var parser := JSON.new()
	var parse_error := parser.parse(body.get_string_from_utf8())
	var data = parser.data if parse_error == OK else null
	if result != HTTPRequest.RESULT_SUCCESS or not data is Dictionary:
		last_request_error = true
		message = "서버에 연결하지 못했어요. 연결 후 저장된 진행을 다시 불러와 주세요."
		if selecting_character_request:
			character_check_required = true
		if working_request or state.has("mvp_version"):
			progress_check_required = true
	elif code >= 400:
		last_request_error = true
		message = data.get("error", "요청에 실패했어요.")
		if selecting_character_request:
			character_check_required = true
		if working_request or (state.has("mvp_version") and code != 400):
			progress_check_required = true
		if code == 401:
			if OS.has_feature("web"):
				JavaScriptBridge.eval("window.location.assign('/?account=1')")
			message += " 테스트 세션이 만료됐어요. 다시 연결하면 새 진행을 시작해요."
			token = ""
	elif data.has("state"):
		character_check_required = false
		progress_check_required = false
		show_work_result = working_request and work_screen != null
		state = data.state
		version = int(data.version)
		if data.has("token"):
			token = data.token
			var saved := ConfigFile.new()
			saved.set_value("session", "token", token)
			saved.save(session_save_path)
		if not heartbeat_request or not last_request_error:
			message = "서버 저장 완료  ·  기획 검증용 압축 플레이 / 임시 수치"
	if show_work_result:
		busy = true
		work_screen.show_result(previous_state, state)
		await get_tree().create_timer(0.9).timeout
		busy = false
	_render()

	if not queued_action.is_empty():
		var queued := queued_action.duplicate(true)
		queued_action.clear()
		if not last_request_error:
			if queued.body is Dictionary:
				queued.body.version = version
			_send(queued.endpoint, queued.body)
