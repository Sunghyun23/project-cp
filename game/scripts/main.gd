extends Control

const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
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
var outer_margin: MarginContainer

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
	var margin := MarginContainer.new()
	outer_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 13)
	scroll.add_child(content)
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

func _layout() -> void:
	if outer_margin == null:
		return
	var edge := 18 if size.x < 500 else 30
	outer_margin.add_theme_constant_override("margin_left", edge)
	outer_margin.add_theme_constant_override("margin_right", maxi(edge, int(size.x) - 660))
	outer_margin.add_theme_constant_override("margin_top", edge)
	outer_margin.add_theme_constant_override("margin_bottom", edge)
	queue_redraw()

func _draw() -> void:
	var night: bool = state.get("phase", "") == "night"
	draw_rect(Rect2(Vector2.ZERO, size), Color("102a30") if night else Color("cadbd1"))
	draw_circle(Vector2(size.x * 0.84, size.y * 0.22), 46, Color("f7dc9b"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * 0.7), Vector2(size.x * 0.25, size.y * 0.29), Vector2(size.x * 0.58, size.y * 0.8), Vector2(size.x, size.y * 0.4), size, Vector2(0, size.y)]), Color("6c9389"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * 0.85), Vector2(size.x * 0.5, size.y * 0.63), Vector2(size.x, size.y * 0.83), size, Vector2(0, size.y)]), Color("315b51"))
	var camp := Vector2(size.x * 0.81, size.y * 0.86)
	draw_colored_polygon(PackedVector2Array([camp + Vector2(-100, 0), camp + Vector2(0, -118), camp + Vector2(115, 0)]), Color("dfa760"))
	draw_colored_polygon(PackedVector2Array([camp + Vector2(-37, 0), camp + Vector2(0, -86), camp + Vector2(40, 0)]), Color("244940"))
	for i in range(4):
		var tree := Vector2(size.x * (0.62 + i * 0.105), size.y * 0.64)
		draw_rect(Rect2(tree, Vector2(7, 65)), Color("476450"))
		draw_colored_polygon(PackedVector2Array([tree + Vector2(-28, 22), tree + Vector2(3, -55), tree + Vector2(35, 22)]), Color("234b42"))
	if night:
		for i in range(20):
			draw_circle(Vector2(fmod(i * 139.0 + 40, size.x), 25 + fmod(i * 71.0, size.y * 0.35)), 2, Color("fff0c2"))
		draw_circle(camp + Vector2(-120, 0), 15, Color("f69c54"))
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.055, 0.14, 0.13, 0.95)
	backdrop.set_corner_radius_all(20)
	draw_style_box(backdrop, Rect2(18, 18, minf(size.x - 36, 690), size.y - 36))

func _label(text_value: String, font_size: int = 17) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff5df"))
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
	style.bg_color = Color("f0d6a3")
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("203f39"))
	button.pressed.connect(func():
		if command == "reload":
			_load_state()
		else:
			_send("actions/", {"command": command, "choice": choice, "version": version})
	)
	content.add_child(button)

func _render() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_label("WEEKEND NOTES  /  CAMPING", 15)
	_label("이번 주말은 캠핑", 34)
	if state.is_empty():
		_label(message)
		_button("서버 다시 연결", "reload")
		return
	var phase: String = state.phase
	_label("%d주 차   ·   소지금 %d   ·   힘 %d   행운 %d   체력 %d" % [state.week, state.money, state.strength, state.luck, state.stamina], 18)
	_label(TITLES.get(phase, phase), 27)
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
	_label(message, 14)
	_button("저장된 진행 다시 불러오기", "reload")
	queue_redraw()

func _load_state() -> void:
	if token.is_empty():
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
	if not token.is_empty():
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
