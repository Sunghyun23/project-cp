extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Control
var session_file := "/tmp/cp-character-flow-%s.cfg" % Time.get_ticks_usec()

func _initialize() -> void:
	run.call_deferred()

func require(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		quit(1)
		assert(condition, description)

func settled() -> void:
	for attempt in range(250):
		await create_timer(0.04).timeout
		if not game.busy:
			return
	require(false, "서버 응답 시간 초과")

func accept_key() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	root.size = Vector2i(1100, 900)
	game = Main.instantiate()
	game.session_save_path = session_file
	root.add_child(game)
	await settled()
	require(game.state.get("phase") == "character", "새 진행은 캐릭터 선택으로 진입해야 함")
	var screen = game.character_screen
	require(screen.confirm_button.disabled, "선택 전 확정 불가")
	await click(screen.cards[1])
	require(screen.selected_id == "female", "클릭으로 여성 선택")
	screen.cards[0].grab_focus()
	await accept_key()
	require(screen.selected_id == "male", "키보드로 남성 선택")
	var endpoint: String = game.base_url
	game.base_url = "http://127.0.0.1:1/api/v1/prototype/"
	screen.confirm_button.grab_focus()
	await accept_key()
	await settled()
	require(game.character_check_required and screen.confirm_button.disabled, "저장 불명확 시 재확정 전에 조회 요구")
	require(screen.selected_id == "male", "통신 실패 뒤 선택 보존")
	game.base_url = endpoint
	game._load_state()
	await settled()
	require(not game.character_check_required and screen.selected_id == "male", "저장 미완료 조회 뒤 선택 유지·재확정 허용")
	screen.confirm_button.grab_focus()
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settled()
	require(game.state.get("phase") == "work", "패드 확인 입력 후 첫 주 진입")
	require(game.state.get("character_id") == "male", "선택한 캐릭터 서버 저장")
	require(game.character_screen == null, "확정 후 선택 화면 제거")
	require(game.state.get("day") == 0 and game.state.get("week") == 1, "선택으로 업무/날짜 진행 금지")
	game.queue_free()
	await process_frame
	game = Main.instantiate()
	game.session_save_path = session_file
	root.add_child(game)
	await settled()
	require(game.state.get("character_id") == "male", "재접속 시 선택 복원")
	require(game.state.get("phase") == "work" and game.character_screen == null, "기존 진행에 선택 재요구 금지")
	require(game.work_screen != null, "월요일 업무 화면으로 복원")
	game.base_url = "http://127.0.0.1:1/api/v1/prototype/"
	game.work_screen.work_button.grab_focus()
	await accept_key()
	await settled()
	require(game.progress_check_required and game.work_screen.work_button.disabled, "업무 통신 실패 후 재조회 요구")
	game.base_url = endpoint
	game._load_state()
	await settled()
	require(not game.progress_check_required and int(game.state.get("day")) == 0, "업무 미저장 재조회 후 원래 날짜 유지")
	var money_before := int(game.state.get("money"))
	var stamina_before := int(game.state.get("stamina"))
	for day in range(5):
		game.work_screen.work_button.grab_focus()
		await accept_key()
		await settled()
		if day < 4:
			require(int(game.state.get("day")) == day + 1, "업무 후 다음 평일 자동 연결")
			require(not game.work_screen.outcome.is_empty(), "실제 업무 결과 표시")
	require(game.state.get("phase") == "place" and game.work_screen == null, "금요일 업무 후 장소 선택 연결")
	require(int(game.state.get("money")) == money_before + 50, "급여 중복 반영 없이 5회 저장")
	require(int(game.state.get("stamina")) == stamina_before - 30, "업무 체력 변화 저장")
	require(game.state.get("character_id") == "male", "평일 진행 중 선택 유지")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(session_file)
	print("PASS: 선택 입력·실패 복구·저장·재접속 → 월~금 수입/체력 → 장소 선택 진입")
	quit()
