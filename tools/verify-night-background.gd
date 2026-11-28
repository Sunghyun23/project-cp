extends SceneTree

class OfflineMain extends "res://scripts/main.gd":
	func _ready() -> void:
		size=get_viewport_rect().size
		super._ready()
	func _load_state() -> void:
		pass

var game
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): printerr("FAIL night background timeout");quit(1))
	root.size=Vector2i(390,844)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var dimensions := arg.trim_prefix("--size=").split("x")
			root.size=Vector2i(int(dimensions[0]),int(dimensions[1]))
	game=OfflineMain.new()
	game.session_save_path="/tmp/cp-night-no-session.cfg"
	root.add_child(game)
	game.set_process(false)
	# CI에는 개인 기기의 임시 API 캡처가 없으므로 독립적인 최소 상태도 지원한다.
	var fixture: Dictionary={"mvp_version":1,"phase":"free","week":1,"day":5,"money":20,"stamina":100,"character_id":"male","outfit":"basic","camp_day":0,"camp_minute":1079,"owned":[],"cargo":{},"field":{},"item_catalog":[],"weather":[],"meal_owned":false,"cooked":false,"rested":false}
	if not "--minimal-fixture" in OS.get_cmdline_user_args() and FileAccess.file_exists("/tmp/cp-mvp-fixtures.json"):
		fixture=JSON.parse_string(FileAccess.get_file_as_string("/tmp/cp-mvp-fixtures.json")).free
	for place in ["pine","lake"]:
		game.state=fixture.duplicate(true)
		game.state.place=place;game.state.erase("placement_site")
		game.state.camp_minute=1079;game.preview_mode="auto"
		game._render();game.mvp_screen.set_process(false)
		var day: Image=await frame()
		var day_texture: Texture2D=game.scenery.texture
		var day_light:=luminance(day)
		game.state.camp_minute=1080;game._render()
		var night: Image=await frame()
		assert(game._is_night() and game.camp_world.effects.night)
		assert(game.scenery.texture != day_texture, "%s: night must use a separate image"%place)
		assert(game.scenery.modulate == Color.WHITE, "Night art must not receive the old tint")
		assert(game.scenery.texture.get_size() == day_texture.get_size(), "Day/night canvases must align")
		assert(luminance(night)<day_light*.8,"%s: background did not turn dark"%place)
		day.save_png("/tmp/cp-%s-day.png"%place);night.save_png("/tmp/cp-%s-night.png"%place)
		if place == "pine":
			night.save_png("/tmp/cp-pine-night-%dx%d.png"%[root.size.x,root.size.y])
		game.state.camp_minute=900;game._render()
		var restored: Image=await frame()
		assert(absf(luminance(restored)-day_light)<.015)
		assert(game.scenery.texture == day_texture)
		game.mvp_screen.night_button.button_pressed=true
		var manual: Image=await frame()
		assert(game._is_night() and luminance(manual)<day_light*.8 and game.state.camp_minute==900)
		game.state.camp_minute=901;game._render()
		var after_tick: Image=await frame()
		assert(luminance(after_tick)<day_light*.8)
		game.mvp_screen.night_button.button_pressed=false
		var manual_day: Image=await frame()
		assert(not game._is_night() and absf(luminance(manual_day)-day_light)<.015)
		print("PASS rendered background ",place,": day=",day_light," night=",luminance(night)," / clock threshold / manual / saved refresh / restore")
	game.queue_free()
	await process_frame
	quit()

func frame() -> Image:
	game.queue_redraw()
	for i in range(4): await process_frame
	RenderingServer.force_draw()
	return root.get_texture().get_image()

func luminance(frame_image: Image) -> float:
	# HUD·장비가 겹치지 않는 실제 배경 구역을 비교한다.
	var total:=0.0
	for y in range(280,330,5):
		for x in range(24,204,5):
			var c:=frame_image.get_pixel(int(x*frame_image.get_width()/390.0),int(y*frame_image.get_height()/844.0))
			total+=c.r*.2126+c.g*.7152+c.b*.0722
	return total/360.0
