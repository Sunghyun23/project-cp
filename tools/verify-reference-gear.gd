extends SceneTree
const Assets=preload("res://ui/components/mvp_assets.gd")
class OfflineMain extends "res://scripts/main.gd":
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		super._ready()
	func _load_state() -> void: pass
	func _send(_endpoint: String, _body: Variant=null) -> void: pass
var game
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(45).timeout.connect(func():printerr("FAIL reference gear timeout");quit(1))
	root.size=Vector2i(820,920)
	game=OfflineMain.new();game.session_save_path="/tmp/cp-reference-no-session.cfg";root.add_child(game);game.set_process(false)
	game.state={"mvp_version":1,"phase":"setup","place":"lake","week":1,"day":5,"money":100,"stamina":100,"character_id":"female","outfit":"basic","camp_day":0,"camp_minute":1000,"owned":["tent","sleeping_bag"],"cargo":{"tent":{},"sleeping_bag":{}},"field":{"tent":{"x":4,"y":0,"z":3,"rotation_degrees":0},"sleeping_bag":{"x":4,"y":0,"z":3,"rotation_degrees":0}},"gear_upgrades":["sleeping_bag"],"item_catalog":[{"id":"tent","name":"낡은 돔 텐트"},{"id":"sleeping_bag","name":"업그레이드 침낭"}],"weather":[],"meal_owned":false,"rested":true}
	game._render();game.mvp_screen.set_process(false)
	for angle in [0,90,180,270]:
		game.state.field.tent.rotation_degrees=angle
		game.state.field.sleeping_bag.rotation_degrees=angle
		game.mvp_screen.selected_item="sleeping_bag";game.mvp_screen.field_initialized_for="";game.mvp_screen.field_rotation=angle
		game._render()
		for id in ["tent","sleeping_bag"]:
			var upgraded: bool=id=="sleeping_bag"
			var texture: AtlasTexture=Assets.field_texture(id,angle,upgraded)
			var expected: Texture2D=Assets.WORN_TENT if id=="tent" else Assets.UPGRADED_SLEEPING_BAG
			assert(texture.atlas == expected)
			var turn: int=angle/90
			assert(texture.region == Rect2(Vector2(turn%2,turn/2)*627,Vector2(627,627)))
			var pivot: Vector2=Assets.field_pivot(id,angle,upgraded)
			assert(pivot.x>0 and pivot.x<1 and pivot.y>0 and pivot.y<1)
		for i in range(8): await process_frame
		game.queue_redraw();RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/cp-reference-gear-%d.png"%angle)
	game.state=game.state.duplicate(true)
	game.state.phase="free"
	game.state.field.tent.rotation_degrees=0
	game.state.field.sleeping_bag.rotation_degrees=0
	game._render()
	for i in range(8): await process_frame
	game.queue_redraw();RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/cp-reference-gear-installed.png")
	for dimensions in [Vector2i(390,844),Vector2i(1280,900)]:
		root.size=dimensions
		for i in range(8): await process_frame
		game.queue_redraw();RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/cp-reference-gear-%dx%d.png"%[dimensions.x,dimensions.y])
	assert(Assets.item_texture("tent").atlas==Assets.WORN_TENT)
	assert(Assets.item_texture("sleeping_bag",true).atlas==Assets.UPGRADED_SLEEPING_BAG)
	print("PASS reference gear: starter dome tent / upgraded mummy bag / four rotations / pixel pivots / inventory icons / phone-fold-PC render")
	game.queue_free();await process_frame;quit()
