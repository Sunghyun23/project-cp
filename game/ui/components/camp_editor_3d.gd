extends SubViewportContainer

signal item_selected(id: String)
signal position_changed(position_value: Vector3)
signal item_dropped(id: String, point: Vector3)
signal placement_rejected(reason: String)
signal drag_state_changed
var placement: Dictionary = {}
var site: Dictionary = {}
var placement_reason := ""
var support_surfaces: Node3D
var support_config_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/item-surfaces.json"))
var footprint: Node3D
var footprint_material: StandardMaterial3D
var hit_images := {}
var fallback_catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campsites.json"))
var interaction_locked := false
var dragging_item := false
var active_pointer := -2
var press_point := Vector2.ZERO
var grab_offset := Vector2.ZERO
var moved_item := false
const Assets = preload("res://ui/components/mvp_assets.gd")
const Effects = preload("res://effects/camp_effects_3d.gd")
var effects
var camper_3d: AnimatedSprite3D
const Catalog = preload("res://ui/components/character_catalog.gd")
var viewport_3d: SubViewport
var world: Node3D
var camera: Camera3D
var sunlight: DirectionalLight3D
var environment: Environment
var items_root: Node3D
var grid_root: Node3D
var grid_key := ""
var ground: MeshInstance3D
var backdrop: Sprite3D
var player: Sprite3D
var gizmo: Node3D
var field: Dictionary = {}
var state: Dictionary = {}
var selected := ""
var proposed := Vector3(4,0,3)
var proposed_rotation := 0
var readonly := false
var scene_key := ""
var yaw := 0.0
var site_width := 8.0
var site_depth := 6.0
var origin_x := 4.0
var origin_z := 3.0
var selected_node: Node3D
var dragging_axis := ""
var drag_plane: Plane
var drag_start := Vector3.ZERO
var drag_position := Vector3.ZERO
var animation_time := 0.0
var camper_frames: SpriteFrames
var camper_key := ""
var player_target := Vector3(-2,.94,1.7)
var fire: OmniLight3D
var fire_shapes: Array[MeshInstance3D] = []
var rain_shapes: Array[MeshInstance3D] = []

static func dimensions(id: String) -> Vector3:
	return {"tent":Vector3(2.0,1.8,2.0), "table":Vector3(2.1,.9,1.4), "chair":Vector3(1,1.2,1), "stove":Vector3(1.4,.65,.7), "lantern":Vector3(.5,1,.7), "rug":Vector3(1.4,.06,2.1)}.get(id, Vector3.ONE)

static func rotation_of(value: Dictionary) -> int:
	return int(value.get("rotation_degrees",90 if value.get("rotated",false) else 0))

static func oriented_dimensions(id: String, angle: int) -> Vector3:
	var bounds := dimensions(id)
	return Vector3(bounds.z,bounds.y,bounds.x) if angle%180 != 0 else bounds

func material(color: String, glowing: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = .95
	if glowing:
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = 1.5
	return m

func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = at
	node.material_override = material(color)
	parent.add_child(node)
	return node

func box(parent: Node3D, shape_size: Vector3, at: Vector3, color: String) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = shape_size
	return mesh(parent, shape, at, color)

func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: String) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 8
	return mesh(parent, shape, at, color)

func model(id: String, angle: int = 0) -> Node3D:
	var node := Node3D.new()
	var sprite := Sprite3D.new()
	sprite.texture = Assets.field_texture(id,angle)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	node.set_meta("rotation_degrees",angle)
	var width := Assets.field_sprite_width(id)
	var pivot := Assets.field_pivot(id,angle)
	sprite.pixel_size = width/float(sprite.texture.get_width())
	var height := sprite.pixel_size*float(sprite.texture.get_height())
	# Billboard의 화면 위쪽으로 보정해 실제 발점이 배치 좌표에 고정된다.
	sprite.position = camera.global_basis.x*width*(.5-pivot.x)+camera.global_basis.y*height*(pivot.y-.5)
	node.add_child(sprite)
	# 그림은 2D이며, 보이지 않는 3D 범위로 선택·겹침·지지 여부를 판정한다.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("item",id)
	var collider := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = oriented_dimensions(id,angle)
	collider.shape = bounds
	collider.position.y = bounds.size.y/2
	body.add_child(collider)
	node.add_child(body)
	return node

func _ready() -> void:
	stretch = true
	var composite := CanvasItemMaterial.new()
	composite.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	set_material(composite)
	# 원래 화면 해상도로 그려 작은 스프라이트의 세부 픽셀을 보존한다.
	stretch_shrink = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE if readonly else Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	viewport_3d = SubViewport.new()
	viewport_3d.own_world_3d = true
	viewport_3d.transparent_bg = true
	viewport_3d.size = Vector2i(640,360)
	viewport_3d.positional_shadow_atlas_size = 1024
	add_child(viewport_3d)
	world = Node3D.new()
	viewport_3d.add_child(world)
	var env_node := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0,0,0,0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e0e8d2")
	environment.ambient_light_energy = .35
	env_node.environment = environment
	world.add_child(env_node)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.4
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.current = true
	world.add_child(camera)
	rotate_camera(0)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-50,-32,0)
	sunlight.light_color = Color("fff0ce")
	sunlight.light_energy = .65
	sunlight.shadow_enabled = true
	world.add_child(sunlight)
	grid_root = Node3D.new()
	world.add_child(grid_root)
	items_root = Node3D.new()
	world.add_child(items_root)
	gizmo = Node3D.new()
	world.add_child(gizmo)
	gizmo.visible = false
	support_surfaces = Node3D.new()
	world.add_child(support_surfaces)
	footprint = Node3D.new()
	world.add_child(footprint)
	footprint_material = material("86d7a0")
	footprint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	camper_3d=AnimatedSprite3D.new()
	camper_3d.sprite_frames=Catalog.frames("female")
	camper_3d.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	camper_3d.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	camper_3d.shaded=true
	camper_3d.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	camper_3d.visible=false
	world.add_child(camper_3d)
	effects=Effects.new()
	world.add_child(effects)
	effects.initialize(camera,environment,sunlight,items_root,camper_3d)
	resized.connect(func():
		if dragging_item: end_drag(true)
		if not state.is_empty(): configure(state,selected,proposed))

func configure(value: Dictionary, id: String = "", point: Vector3 = Vector3(4,0,3), rotation_degrees: int = 0) -> void:
	if readonly and dragging_item:
		dragging_item = false
		active_pointer = -2
	state = value
	selected = id
	proposed = point
	proposed_rotation = rotation_degrees
	if world == null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE if readonly else Control.MOUSE_FILTER_STOP
	site = to_engine_site(state.get("placement_site", fallback_catalog.sites.get(state.get("place","lake"),fallback_catalog.sites.lake)))
	placement = site.placement
	site_width = float(placement.max[0]) - float(placement.min[0])
	site_depth = float(placement.max[2]) - float(placement.min[2])
	origin_x = (float(placement.max[0])+float(placement.min[0]))/2
	origin_z = (float(placement.max[2])+float(placement.min[2]))/2
	var view: Dictionary = site.view
	yaw = deg_to_rad(45.0)
	var elevation := deg_to_rad(30.0)
	camera.position = Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*16
	camera.look_at(Vector3.ZERO)
	var projected_width := absf(cos(yaw))*site_width + absf(sin(yaw))*site_depth
	var projected_height := (absf(sin(yaw))*site_width + absf(cos(yaw))*site_depth)*sin(elevation)
	# 예전의 화면 높이 30%짜리 배치 영역보다 현장을 크게 보여 준다.
	# 지면 전체는 화면 안에 유지하며 서버의 배치 좌표/판정은 바꾸지 않는다.
	var width_ratio := maxf(float(view.width_ratio),.96)
	var height_ratio := maxf(float(view.height_ratio),.44)
	camera.size = maxf(projected_width/width_ratio,projected_height/maxf(.1,height_ratio*size.y/maxf(1,size.x)))
	camera.h_offset = camera.size*(.5-float(view.center[0]))
	camera.v_offset = camera.size*size.y/maxf(1,size.x)*(minf(float(view.center[1]),.60)-.5)
	var dimensions_key := JSON.stringify(site)
	if grid_key != dimensions_key:
		grid_key = dimensions_key
		for child in grid_root.get_children():
			grid_root.remove_child(child)
			child.queue_free()
		var allowed_material := overlay_material("f1e9cf", .26)
		var grid_ink := overlay_material("fdf4d8", .44)
		# 장애물 경계로 나눈 사각형 중 실제 배치 가능한 바닥만 칠한다.
		var xs: Array = [float(placement.min[0]),float(placement.max[0])]
		var zs: Array = [float(placement.min[2]),float(placement.max[2])]
		for blocked in placement.blocked:
			xs.append(float(blocked.min[0])); xs.append(float(blocked.max[0]))
			zs.append(float(blocked.min[2])); zs.append(float(blocked.max[2]))
		xs.sort(); zs.sort()
		for xi in range(xs.size()-1):
			for zi in range(zs.size()-1):
				var center := Vector3((xs[xi]+xs[xi+1])/2,0,(zs[zi]+zs[zi+1])/2)
				var allowed := true
				for blocked in placement.blocked:
					if center.x > blocked.min[0] and center.x < blocked.max[0] and center.z > blocked.min[2] and center.z < blocked.max[2]: allowed=false
				if allowed and xs[xi+1]>xs[xi] and zs[zi+1]>zs[zi]:
					var patch := box(grid_root,Vector3(xs[xi+1]-xs[xi],.006,zs[zi+1]-zs[zi]),Vector3(center.x-origin_x,.008,center.z-origin_z),"b5df88")
					patch.material_override=allowed_material
					patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					for x in range(ceili(xs[xi]), ceili(xs[xi+1])):
						var segment := box(grid_root,Vector3(.018,.006,zs[zi+1]-zs[zi]),Vector3(x-origin_x,.023,center.z-origin_z),"fdf4d8")
						segment.material_override=grid_ink
						segment.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					for z in range(ceili(zs[zi]), ceili(zs[zi+1])):
						var segment := box(grid_root,Vector3(xs[xi+1]-xs[xi],.006,.018),Vector3(center.x-origin_x,.023,z-origin_z),"fdf4d8")
						segment.material_override=grid_ink
						segment.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var edge_material := overlay_material("edf2c5", .9)
		dashed_boundary(grid_root,Vector3(float(placement.min[0])-origin_x,.025,float(placement.min[2])-origin_z),Vector2(site_width,site_depth),edge_material)
		for blocked in placement.blocked:
			var at := Vector3(blocked.min[0]-origin_x,.028,blocked.min[2]-origin_z)
			dashed_boundary(grid_root,at,Vector2(blocked.max[0]-blocked.min[0],blocked.max[2]-blocked.min[2]),overlay_material("e99882",.7))
	grid_root.visible = not readonly
	field = state.get("field", {})
	var key := JSON.stringify([field,selected,proposed_rotation,state.get("cargo",{}).keys(),readonly])
	if scene_key != key:
		scene_key = key
		for child in items_root.get_children():
			items_root.remove_child(child)
			child.queue_free()
		selected_node = null
		for item in field:
			var node := model(item,proposed_rotation if item == selected else rotation_of(field[item]))
			var p: Dictionary = field[item]
			node.position = Vector3(float(p.x)-origin_x,float(p.y),float(p.get("z",0))-origin_z)
			items_root.add_child(node)
			if item == selected: selected_node = node
		if not readonly:
			var index := 0
			for item in state.get("cargo", {}):
				if item == "meal": continue
				if not field.has(item):
					var node := model(item,proposed_rotation if item == selected else 0)
					var start := staging_position(index)
					node.position = Vector3(start.x-origin_x,0,start.z-origin_z)
					node.get_child(0).alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
					node.get_child(0).modulate.a = .65
					items_root.add_child(node)
					if item == selected: selected_node = node
				index += 1
	if selected_node != null:
		selected_node.position = Vector3(proposed.x-origin_x,proposed.y,proposed.z-origin_z)
	gizmo.visible = false
	update_support_surfaces()
	update_feedback()
	gizmo.position = Vector3(proposed.x-origin_x,proposed.y+.1,proposed.z-origin_z)
	effects.configure(state,site_width,site_depth)
	var sources: Dictionary={}
	for item in items_root.get_children():
		var item_id: String=item.get_child(1).get_meta("item")
		if field.has(item_id): sources[item_id]=item.position
	effects.update_sources(sources)

func update_camper(frames: SpriteFrames, screen_foot: Vector2, walking: bool, facing_left: bool) -> void:
	var at=ground_point(screen_foot,0)
	if at==null: return
	camper_3d.visible=true
	if camper_3d.sprite_frames!=frames: camper_3d.sprite_frames=frames
	var animation_name: StringName=&"walk" if walking else &"idle"
	if camper_3d.animation!=animation_name: camper_3d.play(animation_name)
	var frame: Texture2D=frames.get_frame_texture(animation_name,0)
	camper_3d.pixel_size=2.6/float(frame.get_height())
	camper_3d.position=Vector3(at)+camera.global_basis.y*2.6*.44
	camper_3d.flip_h=facing_left

func to_engine_site(source: Dictionary) -> Dictionary:
	if source.get("coordinate_system", "godot_y_up") != "z_up": return source
	var result := source.duplicate(true)
	var area: Dictionary = result.placement
	for key in ["min","max"]: area[key] = [area[key][0],area[key][2],area[key][1]]
	for region in area.blocked:
		for key in ["min","max"]: region[key] = [region[key][0],region[key][2],region[key][1]]
	area.ground_y = area.ground_z
	area.table_y = area.table_z
	result.coordinate_system = "godot_y_up"
	return result

func overlay_material(color: String, alpha: float) -> StandardMaterial3D:
	var result := material(color)
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.albedo_color.a = alpha
	return result

func dashed_boundary(parent: Node3D, at: Vector3, extent: Vector2, ink: StandardMaterial3D) -> void:
	for axis in [0,2]:
		var length := extent.x if axis == 0 else extent.y
		var count := maxi(1,ceili(length/.4))
		for side in [0,1]:
			for i in range(count):
				var p := at
				p[axis] += (i+.3)*length/count
				p[2 if axis == 0 else 0] += (extent.y if axis == 0 else extent.x)*side
				var dimensions_value := Vector3(.025,.015,.025)
				dimensions_value[axis] = length/count*.6
				var dash := box(parent,dimensions_value,p,"d4e8af")
				dash.material_override=ink
				dash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func support_info(id: String) -> Dictionary:
	for item in state.get("item_catalog",[]):
		if item.id == id and item.has("can_place_on_table"): return item
	return support_config_data.get(id,{"stackable":false})

func support_height(id: String) -> float:
	return float(field[id].y)+float(support_info(id).get("surface_height",0))

func update_support_surfaces() -> void:
	for child in support_surfaces.get_children():
		support_surfaces.remove_child(child)
		child.queue_free()
	support_surfaces.visible = not readonly and dragging_item and support_info(selected).get("can_place_on_table", false)
	if not support_surfaces.visible: return
	for id in field:
		if id == selected or not support_info(id).get("stackable",false): continue
		var bounds := oriented_dimensions(id,rotation_of(field[id]))
		var p: Dictionary=field[id]
		var patch := box(support_surfaces,Vector3(bounds.x,.008,bounds.z),Vector3(p.x-origin_x,support_height(id)+.012,p.z-origin_z),"e8da8f")
		patch.material_override=overlay_material("e8da8f",.25)

func rotate_camera(delta: float) -> void:
	yaw += delta
	camera.position = Vector3(sin(yaw)*12,3.2,cos(yaw)*12)
	camera.look_at(Vector3.ZERO)

func ray(point: Vector2) -> Dictionary:
	var p := point * Vector2(viewport_3d.size) / size
	var origin := camera.project_ray_origin(p)
	var direction := camera.project_ray_normal(p)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*100,3)
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func staging_position(index: int) -> Vector3:
	return Vector3(1.25+(index%3)*2.25,0,(2.3 if state.get("place","") == "pine" else 1.0)+(index/3)*2.3)

func screen_point(point: Vector3) -> Vector2:
	return camera.unproject_position(point) * size / Vector2(viewport_3d.size)

func item_screen_rect(node: Node3D) -> Rect2:
	var sprite: Sprite3D = node.get_child(0)
	var extent := Vector2(sprite.texture.get_width(),sprite.texture.get_height())*sprite.pixel_size*size.x/camera.size
	return Rect2(screen_point(sprite.global_position)-extent/2,extent)

func pick_item(point: Vector2) -> String:
	var best := ""
	var best_score := INF
	for node in items_root.get_children():
		var id: String = node.get_child(1).get_meta("item")
		var rect := item_screen_rect(node)
		var pixel_hit := false
		if rect.has_point(point):
			var key := id+str(node.get_meta("rotation_degrees",0))
			if not hit_images.has(key): hit_images[key] = node.get_child(0).texture.get_image()
			var bitmap: Image = hit_images[key]
			var pixel := Vector2i((point-rect.position)/rect.size*Vector2(bitmap.get_size()))
			pixel_hit = bitmap.get_pixelv(pixel).a > .2
		var center := screen_point(node.position+Vector3(0,dimensions(id).y*.45,0))
		var distance := point.distance_to(center)
		if not pixel_hit and distance > 28: continue
		var score := camera.global_position.distance_to(node.global_position) if pixel_hit else 1000+distance
		if score < best_score:
			best = id
			best_score = score
	return best

func validation_reason(id: String, point: Vector3) -> String:
	if id.is_empty(): return "장비를 선택해 주세요"
	var bounds := oriented_dimensions(id,proposed_rotation if id == selected else rotation_of(field.get(id,{})))
	if point.x-bounds.x/2 < placement.min[0]-.01 or point.x+bounds.x/2 > placement.max[0]+.01 or point.z-bounds.z/2 < placement.min[2]-.01 or point.z+bounds.z/2 > placement.max[2]+.01:
		return "배치 가능 구역 안으로 옮겨 주세요"
	for blocked in placement.blocked:
		if point.x+bounds.x/2 > blocked.min[0] and point.x-bounds.x/2 < blocked.max[0] and point.z+bounds.z/2 > blocked.min[2] and point.z-bounds.z/2 < blocked.max[2]:
			return str(blocked.name)+"에는 놓을 수 없어요"
	if point.y > .02:
		if not support_info(id).get("can_place_on_table", false): return "이 장비는 바닥에만 놓을 수 있어요"
		var supported := false
		for support in field:
			if support == id or not support_info(support).get("stackable",false): continue
			var p: Dictionary=field[support]
			var top:=oriented_dimensions(support,rotation_of(p))
			if is_equal_approx(point.y,support_height(support)) and absf(point.x-float(p.x))+bounds.x/2 <= top.x/2+.01 and absf(point.z-float(p.z))+bounds.z/2 <= top.z/2+.01: supported=true
		if not supported: return "올릴 수 있는 받침 위로 옮겨 주세요"
	if support_info(id).get("stackable",false) and field.has(id):
		for other in field:
			if other != id and float(field[other].y) > .02: return "받침 위 물건을 먼저 내려 주세요"
	for other in field:
		if other == id: continue
		var p: Dictionary = field[other]
		var q := oriented_dimensions(other,rotation_of(p))
		if absf(point.x-float(p.x)) < (bounds.x+q.x)/2-.02 and absf(point.z-float(p.z)) < (bounds.z+q.z)/2-.02 and point.y < float(p.y)+q.y-.02 and point.y+bounds.y > float(p.y)+.02:
			return "다른 장비와 겹쳐요"
	return ""

func update_feedback() -> void:
	if footprint == null: return
	footprint.visible = not readonly and not selected.is_empty()
	placement_reason = validation_reason(selected, proposed)
	footprint_material.albedo_color = Color("86d7a0") if placement_reason.is_empty() else Color("ef806e")
	for child in footprint.get_children():
		footprint.remove_child(child)
		child.queue_free()
	if selected.is_empty(): return
	var bounds := oriented_dimensions(selected,proposed_rotation)
	var fill := box(footprint,Vector3(bounds.x,.008,bounds.z),Vector3(0,.022,0),"86d7a0")
	fill.material_override=overlay_material("86d7a0" if placement_reason.is_empty() else "ef806e", .32)
	fill.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z in [-bounds.z/2,bounds.z/2]:
		var line := box(footprint,Vector3(bounds.x,.018,.035),Vector3(0,.025,z),"86d7a0")
		line.material_override = footprint_material
	for x in [-bounds.x/2,bounds.x/2]:
		var line := box(footprint,Vector3(.035,.018,bounds.z),Vector3(x,.025,0),"86d7a0")
		line.material_override = footprint_material
	footprint.position = Vector3(proposed.x-origin_x,proposed.y,proposed.z-origin_z)

func ground_point(point: Vector2, height: float) -> Variant:
	var p := point * Vector2(viewport_3d.size) / size
	return Plane(Vector3.UP,height).intersects_ray(camera.project_ray_origin(p), camera.project_ray_normal(p))

func begin_drag(point: Vector2, pointer: int) -> void:
	if readonly or interaction_locked or dragging_item: return
	var id := pick_item(point)
	if id.is_empty(): return
	active_pointer = pointer
	dragging_item = true
	moved_item = false
	press_point = point
	item_selected.emit(id)
	grab_offset = point - screen_point(selected_node.position)
	update_support_surfaces()
	drag_state_changed.emit()

func move_drag(point: Vector2) -> void:
	if not dragging_item: return
	if point.distance_to(press_point) < 4 and not moved_item: return
	moved_item = true
	var anchor := point - grab_offset
	var hit = ground_point(anchor,float(placement.ground_y))
	if hit == null: return
	var bounds := oriented_dimensions(selected,proposed_rotation)
	var value := Vector3(snappedf(hit.x+origin_x,float(placement.step)),float(placement.ground_y),snappedf(hit.z+origin_z,float(placement.step)))
	value.x = snappedf(value.x,float(placement.step))
	value.z = snappedf(value.z,float(placement.step))
	for support in field:
		if not support_info(selected).get("can_place_on_table", false) or support == selected or not support_info(support).get("stackable",false): continue
		var surface: Dictionary=field[support]
		var top_bounds:=oriented_dimensions(support,rotation_of(surface))
		if bounds.x > top_bounds.x or bounds.z > top_bounds.z: continue
		var height:=support_height(support)
		var top = ground_point(anchor,height)
		if top != null and absf(top.x+origin_x-float(surface.x)) <= top_bounds.x/2 and absf(top.z+origin_z-float(surface.z)) <= top_bounds.z/2:
			value=Vector3(clampf(snappedf(top.x+origin_x,float(placement.step)),surface.x-(top_bounds.x-bounds.x)/2,surface.x+(top_bounds.x-bounds.x)/2),height,clampf(snappedf(top.z+origin_z,float(placement.step)),surface.z-(top_bounds.z-bounds.z)/2,surface.z+(top_bounds.z-bounds.z)/2))
			break
	proposed = value
	position_changed.emit(value)

func end_drag(cancelled: bool = false) -> void:
	if not dragging_item: return
	dragging_item = false
	active_pointer = -2
	update_support_surfaces()
	drag_state_changed.emit()
	if moved_item and not cancelled:
		var reason := validation_reason(selected,proposed)
		if reason.is_empty():
			item_dropped.emit(selected, proposed)
		else:
			item_selected.emit(selected)
			placement_rejected.emit(reason)
	elif cancelled:
		item_selected.emit(selected)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		end_drag(true)

func _gui_input(event: InputEvent) -> void:
	if camera == null or readonly: return
	if event is InputEventScreenTouch:
		if event.pressed: begin_drag(event.position,event.index)
		elif active_pointer == event.index: end_drag(event.canceled)
		accept_event()
	elif event is InputEventScreenDrag and active_pointer == event.index:
		move_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and active_pointer < 0:
		if event.pressed: begin_drag(event.position,-1)
		else: end_drag()
		accept_event()
	elif event is InputEventMouseMotion and active_pointer == -1:
		move_drag(event.position)
		accept_event()

func _process(_delta: float) -> void:
	if effects == null: return
	effects.active = is_visible_in_tree() and (not bool(JavaScriptBridge.eval("document.hidden")) if OS.has_feature("web") else DisplayServer.window_is_focused())
