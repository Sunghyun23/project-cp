extends SubViewportContainer

var viewport_3d: SubViewport
var world: Node3D
var camera: Camera3D
var environment: Environment
var fire_light: OmniLight3D
var lantern_light: OmniLight3D
var moon: DirectionalLight3D
var camper: Sprite3D
var flames: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var clock := 0.0
var night := true
var shadows := true
var flame_material: StandardMaterial3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	viewport_3d = SubViewport.new()
	viewport_3d.own_world_3d = true
	viewport_3d.size = Vector2i(960, 720)
	viewport_3d.positional_shadow_atlas_size = 2048
	viewport_3d.msaa_3d = Viewport.MSAA_2X
	add_child(viewport_3d)
	world = Node3D.new()
	viewport_3d.add_child(world)
	var env_node := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b31")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("90a6cf")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.0
	env_node.environment = environment
	world.add_child(env_node)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.position = Vector3(7, 6.2, 10)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.current = true
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -35, 0)
	moon.light_color = Color("9bbdff")
	moon.light_energy = 0.3
	world.add_child(moon)
	var base := CylinderMesh.new()
	base.top_radius = 5.4
	base.bottom_radius = 5.6
	base.height = 0.3
	base.radial_segments = 48
	mesh(base, Vector3(0,-0.17,0), material(Color("263e32")))
	var ground := CylinderMesh.new()
	ground.top_radius = 4.8
	ground.bottom_radius = 4.9
	ground.height = 0.08
	ground.radial_segments = 48
	mesh(ground, Vector3(0,0.01,0), material(Color("63765a")))
	# A real tent mesh receives the moving fire light and casts real 3D shadows.
	var tent := PrismMesh.new()
	tent.size = Vector3(2.8,2.1,2.6)
	mesh(tent, Vector3(1.7,1.1,-1.4), material(Color("daa35f")))
	var opening := SurfaceTool.new()
	opening.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(-0.8,0,0),Vector3(0.8,0,0),Vector3(0,1.65,0)]:
		opening.add_vertex(vertex)
	opening.generate_normals()
	var opening_mesh := mesh(opening.commit(),Vector3(1.7,0.08,-0.085),material(Color("463126")))
	opening_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(Vector3(2.0,0.08,0.6),Vector3(1.7,0.12,0.22),Color("ae7352"))
	# Table, toast, cup and furniture are actual geometry, not painted shadow overlays.
	box(Vector3(1.6,0.12,0.85),Vector3(-1.7,1,-0.6),Color("a8794c"))
	for x in [-2.3,-1.1]:
		for z in [-0.9,-0.3]:
			box(Vector3(0.1,0.92,0.1),Vector3(x,0.52,z),Color("795437"))
	box(Vector3(0.35,0.08,0.3),Vector3(-1.4,1.1,-0.6),Color("e9c997"))
	var cup := CylinderMesh.new()
	cup.top_radius=0.12;cup.bottom_radius=0.10;cup.height=0.22
	mesh(cup,Vector3(-1.95,1.18,-0.55),material(Color("e4e5d8")))
	box(Vector3(0.8,0.12,0.7),Vector3(-2.7,0.65,0.8),Color("b5aa81"))
	box(Vector3(0.8,0.7,0.1),Vector3(-2.7,1.0,0.48),Color("b5aa81"))
	for x in [-2.98,-2.42]:
		for z in [0.55,1.05]:
			box(Vector3(0.07,0.65,0.07),Vector3(x,0.3,z),Color("7f5438"))
	for i in range(11):
		var a := i * TAU / 11.0
		var rock := SphereMesh.new()
		rock.radius=0.19;rock.height=0.25;rock.radial_segments=8;rock.rings=4
		mesh(rock,Vector3(cos(a)*0.75,0.14,1.2+sin(a)*0.75),material(Color("8b8b83")))
	for i in range(4):
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius=0.11;log_mesh.bottom_radius=0.13;log_mesh.height=1.1;log_mesh.radial_segments=8
		var log_node := mesh(log_mesh,Vector3(0,0.25+i*0.03,1.2),material(Color("5c3525")))
		log_node.rotation=Vector3(PI/2,0,i*0.9)
	fire_light = OmniLight3D.new()
	fire_light.position=Vector3(0,0.9,1.2)
	fire_light.light_color=Color("ffb24e")
	fire_light.light_energy=4.5
	fire_light.omni_range=8.5
	fire_light.omni_attenuation=1.2
	fire_light.shadow_enabled=true
	fire_light.shadow_bias=0.035
	world.add_child(fire_light)
	flame_material=material(Color("ff8c28"),true)
	flame_material.emission_enabled=true
	flame_material.emission=Color("ff7418")
	flame_material.emission_energy_multiplier=2.0
	for i in range(7):
		var flame := CylinderMesh.new()
		flame.top_radius=0.0;flame.bottom_radius=0.20;flame.height=0.95;flame.radial_segments=9
		var node := mesh(flame,Vector3.ZERO,flame_material)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(node)
	for i in range(22):
		var spark := SphereMesh.new()
		spark.radius=0.017+(i%3)*0.008;spark.height=spark.radius*2;spark.radial_segments=6;spark.rings=3
		var node := mesh(spark,Vector3.ZERO,flame_material)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sparks.append(node)
	# A second independent point light makes the contrast visible around the table.
	box(Vector3(0.06,1.9,0.06),Vector3(-2.4,0.95,-1.15),Color("473a31"))
	var lantern_mesh := SphereMesh.new()
	lantern_mesh.radius=0.13;lantern_mesh.height=0.28
	mesh(lantern_mesh,Vector3(-2.4,1.85,-1.15),flame_material)
	lantern_light=OmniLight3D.new()
	lantern_light.position=Vector3(-2.4,1.7,-1.15)
	lantern_light.light_color=Color("ffdc8c")
	lantern_light.light_energy=1.8
	lantern_light.omni_range=4.5
	lantern_light.shadow_enabled=true
	world.add_child(lantern_light)
	# Alpha-tested Sprite3D receives light and casts the camper silhouette onto the ground.
	camper=Sprite3D.new()
	camper.texture=preload("res://assets/pixel/camper-animations.png")
	camper.hframes=4;camper.vframes=2
	camper.pixel_size=0.0042
	camper.position=Vector3(-1.4,1.02,1.7)
	camper.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	camper.shaded=true
	camper.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	camper.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	world.add_child(camper)
	for i in range(8):
		var a := 2.8 + i * 0.50
		var at := Vector3(cos(a)*4.3,0,sin(a)*4.3)
		var trunk := CylinderMesh.new()
		trunk.top_radius=0.10;trunk.bottom_radius=0.14;trunk.height=1.7;trunk.radial_segments=7
		mesh(trunk,at+Vector3(0,0.85,0),material(Color("70533a")))
		for layer in range(3):
			var foliage := CylinderMesh.new()
			foliage.top_radius=0;foliage.bottom_radius=0.9-layer*0.19;foliage.height=1.25;foliage.radial_segments=7
			mesh(foliage,at+Vector3(0,1.5+layer*0.55,0),material(Color("345a43")))

func material(color: Color, unshaded := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color
	result.roughness=0.85
	result.cull_mode=BaseMaterial3D.CULL_DISABLED
	if unshaded: result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func mesh(shape: Mesh, at: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=shape;node.material_override=surface;node.position=at
	world.add_child(node)
	return node

func box(dimensions: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size=dimensions
	return mesh(shape,at,material(color))

func _process(delta: float) -> void:
	if not visible or fire_light==null: return
	clock+=delta
	var flicker := 0.84+0.09*sin(clock*9.1)+0.07*sin(clock*15.7)
	fire_light.light_energy=(3.1 if night else 1.0)*flicker
	fire_light.position=Vector3(sin(clock*2.7)*0.12,0.83+sin(clock*4.1)*0.08,1.2+cos(clock*3.0)*0.08)
	fire_light.shadow_enabled=shadows
	lantern_light.shadow_enabled=shadows
	moon.light_energy=0.10 if night else 1.5
	environment.background_color=Color(0.002,0.004,0.012) if night else Color("91bbc4")
	environment.ambient_light_energy=0.08 if night else 0.65
	for i in range(flames.size()):
		var node := flames[i]
		var angle := i*TAU/7.0
		node.position=Vector3(cos(angle)*0.20,0.66+sin(clock*7+i)*0.10,1.2+sin(angle)*0.20)
		node.scale=Vector3(0.75+sin(clock*5+i)*0.16,0.8+sin(clock*8+i)*0.25,0.75)
	for i in range(sparks.size()):
		var rise := fmod(clock*(0.32+(i%3)*0.08)+i*0.13,1.0)
		sparks[i].position=Vector3(sin(i*7.0+rise*4)*rise*0.7,0.5+rise*2.4,1.2+cos(i*4.1+rise*3)*rise*0.5)
		sparks[i].scale=Vector3.ONE*(1.0-rise*0.8)
	var phase := fmod(clock,3.22)
	camper.frame=0 if phase<2.2 else (1 if phase<2.65 else (2 if phase<2.77 else 3))
