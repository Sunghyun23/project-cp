extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Control
var fixtures := {}
var session_file := "/tmp/cp-full-mvp-%s.cfg" % Time.get_ticks_usec()
var failed := false

func _initialize() -> void:
	run.call_deferred()

func require(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error(description)
		quit(1)

func idle() -> void:
	for i in range(500):
		await create_timer(.025).timeout
		if not game.busy: return
	require(false,"서버 응답 시간 초과")

func remember() -> void:
	fixtures[str(game.state.get("phase"))] = game.state.duplicate(true)

func act(command: String, choice: String = "", extra: Dictionary = {}) -> void:
	var before := int(game.version)
	if game.mvp_screen != null:
		game.mvp_screen.action_requested.emit(command,choice,extra)
	elif command == "work":
		game.work_screen.work_requested.emit()
	elif command.begins_with("office_"):
		game.work_screen.office_action_requested.emit(command,choice,extra)
	elif command == "select_character":
		game.character_screen.cards[0].button_pressed = true
		game.character_screen.confirm_button.pressed.emit()
	else:
		require(false,"예상하지 못한 화면: " + command)
	await idle()
	require(int(game.version)>before,"서버 저장 실패: " + command + " / " + game.message)
	remember()

func expire() -> void:
	for i in range(23):
		await act("tick","",{"elapsed_ms":2000})

func run() -> void:
	root.size = Vector2i(1100,900)
	game = Main.instantiate()
	game.session_save_path = session_file
	if not OS.get_environment("CP_VERIFY_API_URL").is_empty():
		game.base_url = OS.get_environment("CP_VERIFY_API_URL")
	root.add_child(game)
	await idle()
	require(game.state.has("mvp_version"),"새 MVP 세션 필요")
	await act("select_character","male")
	await act("office_start")
	var starting_money:=int(game.state.money)
	var paper: Dictionary=game.state.office_case
	var right_choice: String="approve" if paper.order==paper.invoice else "revise"
	await act("office_review","revise" if right_choice=="approve" else "approve",{"case_id":paper.id})
	require(int(game.state.office_task.index)==0 and int(game.state.money)==starting_money,"서류 오답 재시도·급여 미지급")
	for i in range(6):
		paper=game.state.office_case
		await act("office_review","approve" if paper.order==paper.invoice else "revise",{"case_id":paper.id})
		if i==1:
			await act("office_pause")
			game.queue_free();await process_frame
			game=Main.instantiate();game.session_save_path=session_file
			game.base_url=OS.get_environment("CP_VERIFY_API_URL") if not OS.get_environment("CP_VERIFY_API_URL").is_empty() else "http://127.0.0.1:8000/api/v1/prototype/"
			root.add_child(game);await idle()
			require(int(game.state.office_task.index)==2,"서류 진행 재접속 복원")
			await act("office_start")
	await act("office_finish")
	require(int(game.state.day)==1 and int(game.state.money)==starting_money+10,"서류 업무 급여·다음 날 연결")
	print("PASS office API: wrong retry / six cases / resume / salary / next day")
	for i in range(4): await act("work")
	require(game.state.phase == "place","장소 선택 진입")
	await act("choose_place","lake")
	for id in ["chair","table","lantern"]: await act("buy_item",id)
	await act("shop_done")
	await act("buy_meal")
	await act("set_clothes","rain")
	await act("prepare_done")
	await act("start_pack")
	for row in [["tent",0,0],["table",0,2],["stove",3,0],["chair",3,1],["lantern",5,0],["meal",5,4]]:
		await act("place_item",row[0],{"x":row[1],"y":row[2],"rotated":false})
	await act("finish_pack")
	require(game.state.phase == "setup" and int(game.state.pack_remaining_ms)>0,"시간 전 직접 출발")
	for row in [["tent",1.5,0,1.0],["table",4.75,0,3.5],["stove",4.5,.9,3.5],["lantern",5.5,.9,3.5],["chair",2.0,0,4.0]]:
		await act("place_item",row[0],{"x":row[1],"y":row[2],"z":row[3],"rotated":false})
	require(float(game.state.field.stove.y)==.9,"3D 테이블 위 배치 저장")
	# 실제 물건 드래그 신호 → Main → HTTP 저장까지 연결 확인.
	var before_drag := int(game.version)
	var editor = game.camp_world
	var lantern_node
	for node in editor.items_root.get_children():
		if node.get_child(1).get_meta("item") == "lantern": lantern_node = node
	var press: Vector2 = editor.screen_point(lantern_node.position+Vector3(0,.45,0))
	var offset: Vector2 = press-editor.screen_point(lantern_node.position)
	editor.begin_drag(press,-1)
	editor.move_drag(editor.screen_point(Vector3(5.5-4,.9,3.75-3))+offset)
	editor.end_drag()
	await idle()
	require(int(game.version)>before_drag and is_equal_approx(float(game.state.field.lantern.z),3.75),"아이템 직접 드래그 HTTP 저장")
	await act("setup_done")
	var saved_minute:=int(game.state.camp_minute)
	game.mvp_screen.night_button.button_pressed=true
	await process_frame
	require(game._is_night() and game.camp_world.effects.night,"밤 버튼 배경/조명 전환")
	game.mvp_screen.night_button.button_pressed=false
	await process_frame
	require(not game._is_night() and not game.camp_world.effects.night and int(game.state.camp_minute)==saved_minute,"낮 복귀와 게임 시간 보존")
	game.grab_focus()
	var original_position: Vector2 = game.camper_position
	var move := InputEventKey.new()
	move.physical_keycode = KEY_D
	move.pressed = true
	Input.parse_input_event(move)
	await create_timer(.2).timeout
	move = InputEventKey.new()
	move.physical_keycode = KEY_D
	move.pressed = false
	Input.parse_input_event(move)
	require(game.camper_position.x>original_position.x,"캠핑 중 키보드 직접 이동")
	await act("cook_begin")
	for i in range(3): await act("cook")
	require(game.state.phase == "meal_ready" and game.state.meal_owned,"완성 후 직접 먹기 대기")
	await act("eat")
	require(not game.state.meal_owned and not game.state.cargo.has("meal"),"음식 실제 소모")
	await act("rest")
	await act("sleep")
	require(int(game.state.camp_day)==1,"일요일 진입")
	await act("leave_camp")
	for id in ["stove","lantern","chair","tent","table"]: await act("take_down",id)
	await act("teardown_done")
	await act("start_pack")
	for row in [["tent",0,0],["table",0,2],["stove",3,0],["lantern",5,0]]:
		await act("place_item",row[0],{"x":row[1],"y":row[2],"rotated":false})
	await act("finish_pack","",{"confirm_loss":true})
	require(game.state.phase == "settlement" and "chair" in game.state.lost,"귀가 미적재 의자 손실")
	require(not "chair" in game.state.owned,"손실 실제 반영")
	await act("next_week")
	require(game.state.phase == "work" and int(game.state.week)==2,"다음 주 연결")
	var expected_money := int(game.state.money)
	game.queue_free()
	await process_frame
	game = Main.instantiate()
	game.session_save_path = session_file
	if not OS.get_environment("CP_VERIFY_API_URL").is_empty():
		game.base_url = OS.get_environment("CP_VERIFY_API_URL")
	root.add_child(game)
	await idle()
	require(int(game.state.week)==2 and int(game.state.money)==expected_money and game.state.character_id=="male","재접속 저장 복원")
	var fixture_file := FileAccess.open("/tmp/cp-mvp-fixtures.json",FileAccess.WRITE)
	fixture_file.store_string(JSON.stringify(fixtures))
	fixture_file.close()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(session_file)
	if not failed: print("PASS: 전체 MVP · 3D 지면/테이블 배치 · 식사 소모 · 귀가 손실 · 다음 주 · 재접속")
	quit(1 if failed else 0)
