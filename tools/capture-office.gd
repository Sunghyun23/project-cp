extends SceneTree

const Work=preload("res://ui/screens/first_week.tscn")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var ui=Work.instantiate();root.add_child(ui)
	var state={"mvp_version":1,"phase":"work","week":1,"day":0,"money":80,"stamina":80,"character_id":"female",
		"office_total":6,"office_task":{"week":1,"day":0,"index":2,"mistakes":0,"active":true,"feedback":"금액이 원본과 같은지 확인해 보세요."},
		"office_case":{"id":"W1-D0-2","order":{"supplier":"솔숲상사","amount":18000,"due":12},"invoice":{"supplier":"솔숲상사","amount":19500,"due":12}}}
	ui.apply_state(state,false,"",false)
	for i in range(16): await process_frame
	RenderingServer.force_draw()
	var target:="/tmp/cp-office.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): target=arg.trim_prefix("--output=")
	root.get_texture().get_image().save_png(target)
	print("Office capture ",root.size," workspace ",ui.office_screen.get_rect()," papers ",ui.office_screen.papers.get_rect())
	quit()
