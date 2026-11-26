extends Control

const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const DAY = preload("res://assets/pixel/campsite-day.png")
const NIGHT = preload("res://assets/pixel/campsite-night.png")
const CAMPER_SHEET = preload("res://assets/pixel/camper-animations.png")
const SCENERY_SHADER = preload("res://assets/pixel/campsite.gdshader")
const HUD = preload("res://scripts/camp_hud.gd")
const LIGHTING_3D = preload("res://scripts/camp_lighting_3d.gd")
const SAVE_PATH = "user://prototype_session.cfg"
const TITLES = {"work": "주말을 기다리는 평일", "shopping": "이번 저녁엔 뭘 먹을까?", "packing": "트렁크에 주말을 담아요", "setup": "나만의 작은 캠프", "free": "잠깐, 아무것도 하지 않기", "dinner": "밖에서 먹으면 더 맛있지", "night": "불 앞에서 보내는 밤", "breakfast": "느긋한 아침 한 입", "teardown": "머문 자리를 정리해요", "settlement": "잘 쉬었다. 다음 주에도!"}
var state: Dictionary = {}
var version := 0
var token := ""
var base_url := "http://127.0.0.1:8000/api/v1/prototype/"
var busy := false
var request_kind := ""
var message := "서버에 연결하는 중이에요."
var http: HTTPRequest
var content: VBoxContainer
var hud
var lighting_3d
var real_3d := false
var real_shadows := true
var actions: GridContainer
var ground_fade: GradientTexture2D
var camper_sprite: AnimatedSprite2D
var scenery: TextureRect
var scenery_material: ShaderMaterial
var visual_time := 0.0
var preview_mode := "auto"
var camper_position := Vector2(0.60, 0.80)
var camper_target := Vector2(0.60, 0.80)
var facing_left := false
var depth_enabled := true
var camera_focus := Vector2.ZERO

func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
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
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var cell := Vector2(CAMPER_SHEET.get_size()) / Vector2(4, 2)
	for row in range(2):
		var animation := "idle" if row == 0 else "walk"
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 1.0 if row == 0 else 7.0)
		for column in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = CAMPER_SHEET
			atlas.region = Rect2(Vector2(column, row) * cell, cell)
			frames.add_frame(animation, atlas, [2.2, 0.45, 0.12, 0.45][column] if row == 0 else 1.0)
	camper_sprite.sprite_frames = frames
	camper_sprite.offset = Vector2(0, -cell.y * 0.46)
	camper_sprite.z_index = 1
	add_child(camper_sprite)
	camper_sprite.play("idle")
	lighting_3d=LIGHTING_3D.new()
	lighting_3d.z_index=-1
	lighting_3d.visible=false
	add_child(lighting_3d)
	hud=HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	content=hud.content
	hud.account_requested.connect(func():
		if OS.has_feature("web"):JavaScriptBridge.eval("window.location.assign('/')")
	)
	hud.reload_requested.connect(_load_state)
	hud.view_selected.connect(func(id: int):
		if id<=2:
			preview_mode=["auto","day","night"][id]
		elif id==3:
			real_3d=not real_3d
			if real_3d:preview_mode="night"
		elif id==4:
			real_shadows=not real_shadows
		_render()
	)
	resized.connect(_layout)
	_layout()
	http = HTTPRequest.new()
	http.timeout = 10
	add_child(http)
	http.request_completed.connect(_on_response)
	var saved := ConfigFile.new()
	if saved.load(SAVE_PATH) == OK:
		token = saved.get_value("session", "token", "")
	_render()
	_load_state()
	print("Prototype viewport: ", get_viewport_rect().size, " control: ", size, " window: ", get_tree().root.size)

func _is_night() -> bool:
	return preview_mode == "night" or (preview_mode == "auto" and state.get("phase", "") == "night")

func _scene_rect() -> Rect2:
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
	if lighting_3d!=null:
		lighting_3d.position=Vector2.ZERO
		lighting_3d.size=size
	if hud!=null:hud.fit.call_deferred()
	queue_redraw()

func _process(delta: float) -> void:
	visual_time += delta
	var target_focus := Vector2.ZERO
	if depth_enabled and _scene_rect().has_point(get_local_mouse_position()):
		target_focus = (get_local_mouse_position() - _scene_rect().get_center()) / _scene_rect().size * 2.0
	camera_focus = camera_focus.lerp(target_focus, minf(1.0, delta * 3.0))
	var previous := camper_position
	camper_position = camper_position.move_toward(camper_target, delta * 0.055)
	if absf(camper_position.x - previous.x) > 0.00001:
		facing_left = camper_position.x < previous.x
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if not pressed or not _scene_rect().has_point(event.position):
		return
	var source := _source_rect()
	var uv: Vector2 = ((event.position - _scene_rect().position) / _scene_rect().size * source.size + source.position) / Vector2(DAY.get_size())
	camper_target = Vector2(clampf(uv.x, 0.47, 0.66), clampf(uv.y, 0.74, 0.92))

func _draw() -> void:
	if scenery == null:
		return
	var night := _is_night()
	scenery.visible=not real_3d
	lighting_3d.visible=real_3d
	camper_sprite.visible=not real_3d
	if real_3d:
		lighting_3d.night=night
		lighting_3d.shadows=real_shadows
		return
	scenery.texture = NIGHT if night else DAY
	scenery_material.set_shader_parameter("night", night)
	scenery_material.set_shader_parameter("depth_enabled", depth_enabled)
	scenery_material.set_shader_parameter("parallax", camera_focus)
	var area := _scene_rect()
	var source := _source_rect()
	if area.end.y<size.y:
		draw_rect(Rect2(0,area.end.y,size.x,size.y-area.end.y),Color(0.13,0.25,0.17,1))
		draw_texture_rect(ground_fade,Rect2(0,area.end.y-75,size.x,75),false)
	scenery_material.set_shader_parameter("source_offset", source.position / Vector2(DAY.get_size()))
	scenery_material.set_shader_parameter("source_scale", source.size / Vector2(DAY.get_size()))
	var scale_factor := area.size.x / source.size.x
	var walking := camper_position.distance_to(camper_target) > 0.001
	var foot := _scene_point(camper_position) + camera_focus * Vector2(7, 3) * scale_factor
	var sprite_height := Vector2(DAY.get_size()).y * 0.22 * scale_factor
	var cell := Vector2(CAMPER_SHEET.get_size()) / Vector2(4, 2)
	var shadow_offset := Vector2(3, 2) if depth_enabled else Vector2.ZERO
	draw_set_transform(foot + shadow_offset, 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, sprite_height * 0.21, Color(0.02, 0.05, 0.08, 0.30))
	draw_set_transform(Vector2.ZERO)
	camper_sprite.position = foot
	camper_sprite.scale = Vector2.ONE * sprite_height / (cell.y * 0.9)
	camper_sprite.flip_h = facing_left
	camper_sprite.modulate = Color("ccd5ee") if night else Color.WHITE
	if night and depth_enabled:
		var warmth := clampf(1.0 - camper_position.distance_to(Vector2(0.738, 0.755)) * 4.0, 0.0, 1.0)
		camper_sprite.modulate = camper_sprite.modulate.lerp(Color("ffe0b3"), warmth * 0.45)
	var animation := "walk" if walking else "idle"
	if camper_sprite.animation != animation:
		camper_sprite.play(animation)
	if night:
		var fire := _scene_point(Vector2(0.738, 0.735))
		for i in range(9):
			var life := fmod(visual_time * 0.45 + i * 0.13, 1.0)
			var spark := fire + Vector2(sin(i * 4.0 + life * 5.0) * 18, -life * 100) * scale_factor
			var spark_depth := 0.65 + (i % 3) * 0.4 if depth_enabled else 1.0
			draw_rect(Rect2(spark, Vector2.ONE * maxf(2, scale_factor * 3 * spark_depth)), Color(1, 0.65, 0.24, (1.0 - life) / spark_depth))
	if depth_enabled:
		_draw_atmosphere(area, scale_factor, night)

func _draw_atmosphere(area: Rect2, scale_factor: float, night: bool) -> void:
	# A few particles move at different depths; every effect stays inside the scenery.
	for i in range(24):
		var depth := 0.5 + (i % 3) * 0.55
		var x := fmod(i * 107.0 + visual_time * 3.5 * depth, area.size.x)
		var y := area.size.y * (0.38 + fmod(i * 0.173, 0.56)) + sin(visual_time * 0.6 + i) * 5
		var point := area.position + Vector2(x, y) + camera_focus * depth * 3
		var alpha := (0.09 + 0.08 * sin(visual_time + i)) if night else (0.13 + 0.06 * sin(visual_time * 0.7 + i))
		var tint := Color(0.9, 0.84, 0.55, alpha) if night else Color(1, 0.96, 0.77, alpha)
		if area.has_point(point):
			draw_rect(Rect2(point, Vector2.ONE * maxf(1, depth * 2 * scale_factor)), tint)

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
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	actions=null
	hud.update_stats(state,message)
	hud.set_view(real_3d,real_shadows)
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
		return
	busy = true
	request_kind = endpoint
	message = "진행을 저장하고 있어요…" if endpoint == "actions/" else "서버에 연결하고 있어요…"
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
		message = "요청을 시작하지 못했어요. 서버를 확인해 주세요."
		_render()

func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var parser := JSON.new()
	var parse_error := parser.parse(body.get_string_from_utf8())
	var data = parser.data if parse_error == OK else null
	if result != HTTPRequest.RESULT_SUCCESS or not data is Dictionary:
		message = "서버에 연결하지 못했어요. 연결 후 저장된 진행을 다시 불러와 주세요."
	elif code >= 400:
		message = data.get("error", "요청에 실패했어요.")
		if code == 401:
			if OS.has_feature("web"):
				JavaScriptBridge.eval("window.location.assign('/')")
			message += " 테스트 세션이 만료됐어요. 다시 연결하면 새 진행을 시작해요."
			token = ""
	elif data.has("state"):
		state = data.state
		version = int(data.version)
		if data.has("token"):
			token = data.token
			var saved := ConfigFile.new()
			saved.set_value("session", "token", token)
			saved.save(SAVE_PATH)
		message = "서버 저장 완료  ·  기획 검증용 압축 플레이 / 임시 수치"
	_render()
