extends Node3D
## 픽셀 장비와 같은 World3D 안에서 렌더링하는 조명/발광 메시/입자.
const Radiance = preload("res://effects/radiance.gdshader")
const Catcher = preload("res://effects/shadow_catcher.gdshader")
var enabled := true
var shadows := true
var night := false
var active := true
var clock := 0.0
var frozen := false
var camera: Camera3D
var environment: Environment
var sunlight: DirectionalLight3D
var lantern: OmniLight3D
var stove: OmniLight3D
var ground: MeshInstance3D
var lantern_halo: MeshInstance3D
var stove_halo: MeshInstance3D
var lantern_pool: MeshInstance3D
var stove_pool: MeshInstance3D
var shafts: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var motes: Array[MeshInstance3D] = []
var drops: Array[MeshInstance3D] = []
var scene_state: Dictionary = {}
var lantern_at := Vector3.ZERO
var stove_at := Vector3.ZERO
var has_lantern := false
var has_stove := false
var sprites_root: Node3D
var avatar: AnimatedSprite3D
var applied_enabled = null

func initialize(view: Camera3D, env: Environment, sun: DirectionalLight3D, items: Node3D, camper: AnimatedSprite3D) -> void:
	camera=view; environment=env; sunlight=sun; sprites_root=items; avatar=camper
	lantern=light(Color("ffcc73"),5.5)
	stove=light(Color("ff9d48"),4.8)
	ground=MeshInstance3D.new()
	ground.mesh=PlaneMesh.new()
	var shadow_material:=ShaderMaterial.new(); shadow_material.shader=Catcher
	ground.material_override=shadow_material
	ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	lantern_halo=glow(Color(1,.65,.2,.32)); stove_halo=glow(Color(.3,.65,1,.40))
	lantern_pool=glow(Color(1,.55,.1,.28),true); stove_pool=glow(Color(1,.32,.05,.20),true)
	lantern_halo.material_override.set_shader_parameter("energy",1.2)
	stove_halo.material_override.set_shader_parameter("energy",.8)
	lantern_pool.material_override.set_shader_parameter("energy",.18)
	stove_pool.material_override.set_shader_parameter("energy",.12)
	for i in range(3):
		var ray:=glow(Color(1,.85,.45,.085))
		ray.material_override=ray.material_override.duplicate()
		ray.material_override.set_shader_parameter("shaft",true)
		ray.material_override.set_shader_parameter("energy",3.0)
		shafts.append(ray)
	for i in range(24): sparks.append(glow(Color(1,.47,.1,.85)))
	for i in range(20): motes.append(glow(Color(.65,1,.45,.8)))
	for i in range(40): drops.append(glow(Color(.56,.73,1,.26)))
	for node in sparks: node.material_override.set_shader_parameter("energy",3.0)
	for node in motes: node.material_override.set_shader_parameter("energy",4.0)

func light(color: Color, reach: float) -> OmniLight3D:
	var node:=OmniLight3D.new()
	node.light_color=color; node.omni_range=reach; node.omni_attenuation=1.2
	node.shadow_enabled=true; node.shadow_bias=.045
	add_child(node)
	return node

func glow(color: Color, floor_quad: bool = false) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var shape:=QuadMesh.new(); shape.size=Vector2.ONE
	node.mesh=shape
	var surface:=ShaderMaterial.new(); surface.shader=Radiance; surface.set_shader_parameter("tint",color)
	node.material_override=surface
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if floor_quad: node.rotation.x=-PI/2
	add_child(node)
	return node

func configure(value: Dictionary, width: float, depth: float) -> void:
	scene_state=value
	night=int(value.get("camp_minute",960))>=1080
	ground.mesh.size=Vector2(width,depth)
	ground.position.y=.012

func update_sources(items: Dictionary) -> void:
	has_lantern=items.has("lantern"); has_stove=items.has("stove")
	if has_lantern: lantern_at=items.lantern+Vector3(0,.55,0)
	if has_stove: stove_at=items.stove+Vector3(0,.75,0)

func billboard(node: MeshInstance3D, at: Vector3, extent: Vector2, angle: float = 0.0) -> void:
	node.position=at
	node.basis=camera.global_basis.rotated(camera.global_basis.z,angle)
	node.scale=Vector3(extent.x,extent.y,1)

func _process(delta: float) -> void:
	if camera==null: return
	var show:=enabled and active and is_visible_in_tree()
	if show and not frozen: clock+=minf(delta,.05)
	if applied_enabled!=show:
		applied_enabled=show
		for child in get_children():
			if child is VisualInstance3D or child is Light3D: child.visible=show
	# 화면 전체 bloom은 픽셀 윤곽을 씻어내므로 광원 주변 메시만 발광시킨다.
	environment.glow_enabled=false
	environment.glow_intensity=.9
	environment.glow_bloom=0.0
	environment.glow_hdr_threshold=.8
	environment.ambient_light_energy=(.4 if night else .65) if show else 1.0
	environment.ambient_light_color=Color("9eb6e1") if night else Color("e9efd9")
	sunlight.light_energy=(.18 if night else .45) if show else 0.0
	sunlight.light_color=Color("8eb4ff") if night else Color("ffe1a2")
	sunlight.shadow_enabled=show and shadows
	avatar.shaded=show
	avatar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if show and shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for item in sprites_root.get_children():
		item.get_child(0).shaded=show
		item.get_child(0).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if show and shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.visible=show and shadows
	if not show: return
	var flicker:=.88+.07*sin(clock*8.3)+.05*sin(clock*17.1)
	lantern.visible=has_lantern; stove.visible=has_stove
	lantern.position=lantern_at+Vector3(sin(clock*2)*.025,0,0)
	stove.position=stove_at
	lantern.light_energy=(.18 if night else .10)*flicker
	stove.light_energy=(.15 if night else .08)*flicker
	lantern.shadow_enabled=shadows; stove.shadow_enabled=shadows
	lantern_halo.visible=has_lantern; lantern_pool.visible=has_lantern
	stove_halo.visible=has_stove; stove_pool.visible=has_stove
	billboard(lantern_halo,lantern_at,Vector2.ONE*(1.7 if night else .9)*flicker)
	billboard(stove_halo,stove_at,Vector2.ONE*.65*flicker)
	lantern_pool.position=Vector3(lantern_at.x,.035,lantern_at.z); lantern_pool.scale=Vector3.ONE*4.5
	stove_pool.position=Vector3(stove_at.x,.04,stove_at.z); stove_pool.scale=Vector3.ONE*3.0
	for i in range(shafts.size()):
		var ray:=shafts[i]
		billboard(ray,Vector3(-3+i*2.2,2.4,-1.2),Vector2(.7,7.5),-.42)
		ray.material_override.set_shader_parameter("tint",Color(.38,.62,1,.025) if night else Color(1,.87,.47,.03))
	for i in range(sparks.size()):
		var node:=sparks[i]; node.visible=has_stove
		var life:=fmod(clock*(.32+(i%3)*.07)+i*.137,1.0)
		var at:=stove_at+Vector3(sin(i*3+life*5)*life*.6,life*2.0,cos(i*7+life*4)*life*.5)
		billboard(node,at,Vector2.ONE*(.045+.075*(1-life)))
	for i in range(motes.size()):
		var at:=Vector3(sin(i*13.7)*4, .3+fmod(i*.17+clock*.08,1.8),cos(i*8.2)*3)
		at+=Vector3(sin(clock*.7+i)*.22,cos(clock*.9+i)*.12,0)
		billboard(motes[i],at,Vector2.ONE*((.11 if night else .055)+.025*sin(clock*1.6+i)))
	var rainy:=false
	var weather: Array=scene_state.get("weather",[])
	if weather.size()>=7: rainy=weather[5+int(scene_state.get("camp_day",0))].weather=="rain"
	for i in range(drops.size()):
		drops[i].visible=rainy
		var at:=Vector3(sin(i*17.1)*5,4-fmod(clock*4+i*.29,4.0),cos(i*9.3)*4)
		billboard(drops[i],at,Vector2(.013,.22),-.12)
