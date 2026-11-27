extends SceneTree
const World=preload("res://ui/components/camp_editor_3d.gd")
const Catalog=preload("res://ui/components/character_catalog.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	create_timer(15).timeout.connect(func(): printerr("FAIL FX timeout"); quit(1))
	root.size=Vector2i(1100,900)
	var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/cp-mvp-fixtures.json")).free.duplicate(true)
	snapshot.camp_minute=1200
	var view=World.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	view.readonly=true
	view.configure(snapshot)
	for i in range(10): await process_frame
	var fx=view.effects
	fx.active=true
	fx._process(.016)
	assert(fx.lantern.visible and fx.stove.visible and not fx.environment.glow_enabled)
	assert(view.items_root.get_child(0).get_child(0).shaded)
	var frames=Catalog.frames("male","rain")
	view.update_camper(frames,Vector2(600,600),true,true)
	assert(view.camper_3d.sprite_frames==frames and view.camper_3d.animation=="walk" and view.camper_3d.flip_h)
	assert(view.stretch_shrink==1)
	assert(view.camper_3d.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	assert(is_equal_approx(view.camper_3d.pixel_size*frames.get_frame_texture("walk",0).get_height(),2.6))
	view.readonly=false
	view.configure(snapshot,"lantern",Vector3(6,.9,4))
	fx.active=true; fx._process(.016)
	assert(fx.lantern.position.distance_to(Vector3(6-view.origin_x,1.45,4-view.origin_z))<.04)
	fx.shadows=false;fx._process(.016)
	assert(not fx.ground.visible and not fx.lantern.shadow_enabled and not fx.sunlight.shadow_enabled)
	fx.enabled=false;fx._process(.016)
	assert(not fx.environment.glow_enabled and not fx.lantern.visible and not fx.motes[0].visible)
	assert(not view.items_root.get_child(0).get_child(0).shaded)
	snapshot.field.erase("lantern")
	view.configure(snapshot)
	fx.enabled=true;fx.active=true;fx._process(.016)
	assert(not fx.lantern.visible and not fx.lantern_halo.visible and not fx.lantern_pool.visible)
	fx.active=false
	var before:float=fx.clock
	fx._process(.5)
	assert(fx.clock==before and not fx.stove.visible)
	var source=FileAccess.get_file_as_string("res://assets/pixel/campsite.gdshader")
	assert(not "TIME" in source and not "parallax" in source and not "sin(" in source)
	print("PASS 3D FX: source tracking / shaded avatar / removal / shadows / clean off / pause / static background")
	quit()
