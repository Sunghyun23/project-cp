extends SubViewportContainer

signal item_selected(id: String)
signal position_changed(position_value: Vector3)
signal item_dropped(id: String, point: Vector3)
var interaction_locked := false
var dragging_item := false
var active_pointer := -2
var press_point := Vector2.ZERO
var grab_offset := Vector2.ZERO
var moved_item := false
const Assets = preload("res://ui/components/mvp_assets.gd")
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
var readonly := false
var scene_key := ""
var yaw := 0.0
var site_width := 8.0
var site_depth := 6.0
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
	return {"tent":Vector3(2.1,1.8,1.4), "table":Vector3(2.1,.9,1.4), "chair":Vector3(1,1.2,1), "stove":Vector3(1.4,.65,.7), "lantern":Vector3(.5,1,.7), "rug":Vector3(1.4,.06,2.1)}.get(id, Vector3.ONE)

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

func model(id: String) -> Node3D:
	var node := Node3D.new()
	var sprite := Sprite3D.new()
	sprite.texture = Assets.item_texture(id)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	var width: float = {"tent":2.6,"chair":1.35,"table":2.125,"lantern":1.05,"stove":1.25,"rug":1.8}.get(id,1.5)
	var foot: float = {"tent":.888671875,"chair":.89453125,"table":.8515625,"lantern":.796875,"stove":.8828125,"rug":.76171875}.get(id,.9)
	sprite.pixel_size = width/float(sprite.texture.get_width())
	sprite.position.y = width*(foot-.5)
	node.add_child(sprite)
	# 그림은 2D이며, 보이지 않는 3D 범위로 선택·겹침·지지 여부를 판정한다.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("item",id)
	var collider := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = dimensions(id)
	collider.shape = bounds
	collider.position.y = bounds.size.y/2
	body.add_child(collider)
	node.add_child(body)
	return node

func _ready() -> void:
	stretch = true
	stretch_shrink = 2
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
	for axis in ["x","y","z"]:
		var direction: Vector3 = {"x":Vector3.RIGHT,"y":Vector3.UP,"z":Vector3.BACK}[axis]
		var color: String = {"x":"d9745f","y":"9cc96d","z":"74a9d4"}[axis]
		var stem := cylinder(gizmo,.025,1.4,direction*.7,color)
		if axis == "x": stem.rotation.z = -PI/2
		if axis == "z": stem.rotation.x = PI/2
		var tip := cylinder(gizmo,.11,.18,direction*1.48,color)
		if axis == "x": tip.rotation.z = -PI/2
		if axis == "z": tip.rotation.x = PI/2
		var handle := StaticBody3D.new()
		handle.collision_layer = 2
		handle.position = direction*1.4
		handle.set_meta("axis",axis)
		var hit := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = .28
		hit.shape = sphere
		handle.add_child(hit)
		gizmo.add_child(handle)
	gizmo.visible = false

func configure(value: Dictionary, id: String = "", point: Vector3 = Vector3(4,0,3), rotated: bool = false) -> void:
	state = value
	selected = id
	proposed = point
	if world == null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE if readonly else Control.MOUSE_FILTER_STOP
	site_width = 10 if state.get("place", "") == "pine" else 8
	site_depth = 7 if state.get("place", "") == "pine" else 6
	camera.size = site_width / (.84 if size.x < 760 else .60)
	camera.h_offset = 0 if size.x < 760 else camera.size*.13
	camera.v_offset = camera.size*size.y/maxf(1,size.x)*(.07 if size.x<760 else .15)
	var dimensions_key := str(site_width)+":"+str(site_depth)
	if grid_key != dimensions_key:
		grid_key = dimensions_key
		for child in grid_root.get_children():
			grid_root.remove_child(child)
			child.queue_free()
		var line_material := material("f6edc9")
		line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line_material.albedo_color.a = .25
		for x in range(int(site_width)+1):
			var line := box(grid_root,Vector3(.028,.006,site_depth),Vector3(x-site_width/2,.008,0),"f6edc9")
			line.material_override = line_material
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for z in range(int(site_depth)+1):
			var line := box(grid_root,Vector3(site_width,.006,.028),Vector3(0,.008,z-site_depth/2),"f6edc9")
			line.material_override = line_material
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid_root.visible = not readonly
	field = state.get("field", {})
	var key := JSON.stringify([field,selected,rotated,state.get("cargo",{}).keys(),readonly])
	if scene_key != key:
		scene_key = key
		for child in items_root.get_children():
			items_root.remove_child(child)
			child.queue_free()
		selected_node = null
		for item in field:
			var node := model(item)
			var p: Dictionary = field[item]
			node.position = Vector3(float(p.x)-site_width/2,float(p.y),float(p.get("z",0))-site_depth/2)
			node.rotation.y = PI/2 if p.get("rotated",false) else 0
			items_root.add_child(node)
			if item == selected: selected_node = node
		if not readonly:
			var index := 0
			for item in state.get("cargo", {}):
				if item == "meal": continue
				if not field.has(item):
					var node := model(item)
					var start := staging_position(index)
					node.position = Vector3(start.x-site_width/2,0,start.z-site_depth/2)
					node.get_child(0).alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
					node.get_child(0).modulate.a = .65
					items_root.add_child(node)
					if item == selected: selected_node = node
				index += 1
	if selected_node != null:
		selected_node.position = Vector3(proposed.x-site_width/2,proposed.y,proposed.z-site_depth/2)
		selected_node.rotation.y = PI/2 if rotated else 0
	gizmo.visible = false
	gizmo.position = Vector3(proposed.x-site_width/2,proposed.y+.1,proposed.z-site_depth/2)
	var night := int(state.get("camp_minute",960))>=1080
	environment.background_color = Color(0,0,0,0)
	environment.ambient_light_energy = .25 if night else .35
	sunlight.light_energy = .20 if night else .65
	sunlight.light_color = Color("a5b9e0") if night else Color("fff0ce")

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

func pick_item(point: Vector2) -> String:
	var best := ""
	var distance := INF
	for node in items_root.get_children():
		var body = node.get_child(1)
		var id: String = body.get_meta("item")
		var center := screen_point(node.position + Vector3(0, dimensions(id).y*.45,0))
		var extent := screen_point(node.position+Vector3(dimensions(id).x*.5,0,0)).distance_to(screen_point(node.position))
		var radius := maxf(28, extent)
		var d := point.distance_to(center)
		if d <= radius and d < distance:
			best = id
			distance = d
	return best

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

func move_drag(point: Vector2) -> void:
	if not dragging_item: return
	if point.distance_to(press_point) < 4 and not moved_item: return
	moved_item = true
	var anchor := point - grab_offset
	var hit = ground_point(anchor,0)
	if hit == null: return
	var bounds := dimensions(selected)
	var value := Vector3(snappedf(hit.x+site_width/2,.25),0,snappedf(hit.z+site_depth/2,.25))
	value.x = clampf(value.x,bounds.x/2,site_width-bounds.x/2)
	value.z = clampf(value.z,bounds.z/2,site_depth-bounds.z/2)
	if selected != "table" and field.has("table") and bounds.x <= 2.1 and bounds.z <= 1.4:
		var top = ground_point(anchor,.9)
		var table: Dictionary = field.table
		if top != null and absf(top.x+site_width/2-float(table.x)) <= 1.05 and absf(top.z+site_depth/2-float(table.z)) <= .7:
			value = Vector3(clampf(snappedf(top.x+site_width/2,.25),table.x-(2.1-bounds.x)/2,table.x+(2.1-bounds.x)/2),.9,clampf(snappedf(top.z+site_depth/2,.25),table.z-(1.4-bounds.z)/2,table.z+(1.4-bounds.z)/2))
	proposed = value
	position_changed.emit(value)

func end_drag(cancelled: bool = false) -> void:
	if not dragging_item: return
	dragging_item = false
	active_pointer = -2
	if moved_item and not cancelled:
		item_dropped.emit(selected, proposed)
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
