extends RefCounted

signal installation_ready
const Assets = preload("res://ui/components/mvp_assets.gd")
const Editor = preload("res://ui/components/camp_editor_3d.gd")
var position := Vector3(4,0,4)
var mode := "idle"
var facing_left := false
var direct_walking := false
var look_target := Vector3.ZERO
var view_right := Vector3.RIGHT
var seat_angle := 0
var seat_id := ""
var path: Array[Vector3] = []
var state: Dictionary = {}
var width := 8.0
var depth := 6.0
var work_remaining := 0.0
var grid: AStarGrid2D
var navigation_key := ""
const STEP := .25
const SPEED := 2.4

func configure(value: Dictionary, editor) -> void:
	state = value
	view_right=editor.camera.global_basis.x
	width = editor.site_width
	depth = editor.site_depth
	var key := JSON.stringify([width,depth,editor.placement.get("blocked",[]),state.get("field",{})])
	if key == navigation_key: return
	navigation_key = key
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0,0,int(width/STEP)+1,int(depth/STEP)+1)
	grid.cell_size = Vector2.ONE*STEP
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(grid.region.size.x):
		for z in range(grid.region.size.y):
			var at := Vector2(x*STEP,z*STEP)
			var solid := x == 0 or z == 0 or x == grid.region.size.x-1 or z == grid.region.size.y-1
			for area in editor.placement.get("blocked",[]):
				if at.x >= area.min[0]-.12 and at.x <= area.max[0]+.12 and at.y >= area.min[2]-.12 and at.y <= area.max[2]+.12: solid=true
			for id in state.get("field",{}):
				if id == "rug": continue
				var item: Dictionary=state.field[id]
				if float(item.y)>.1: continue
				var bounds := Editor.oriented_dimensions(id,Editor.rotation_of(item))
				if absf(at.x-float(item.x))<bounds.x/2+.12 and absf(at.y-float(item.z))<bounds.z/2+.12: solid=true
			grid.set_point_solid(Vector2i(x,z),solid)
	if mode == "sit" and not state.get("field",{}).has(seat_id): cancel()
	if mode in ["idle","walk"]:
		position = nearest(position)

func cell(point: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(point.x/STEP),0,grid.region.size.x-1),clampi(roundi(point.z/STEP),0,grid.region.size.y-1))

func nearest(point: Vector3) -> Vector3:
	var best := Vector3(width/2,0,depth/2)
	var distance := INF
	for x in range(1,grid.region.size.x-1):
		for z in range(1,grid.region.size.y-1):
			if grid.is_point_solid(Vector2i(x,z)): continue
			var candidate := Vector3(x*STEP,0,z*STEP)
			var d := candidate.distance_squared_to(point)
			if d<distance: best=candidate;distance=d
	return best

func route(point: Vector3) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if grid == null: return result
	var start := cell(nearest(position))
	var finish := cell(nearest(point))
	for at in grid.get_point_path(start,finish): result.append(Vector3(at.x,0,at.y))
	if result.size()>1 and result[0].distance_to(position)<.015: result.pop_front()
	return result

func move_to(point: Vector3) -> bool:
	if mode in ["approach_install","install","saving"]: return false
	if mode == "sit": position=nearest(position)
	var next := route(point)
	if next.is_empty(): return false
	seat_id=""
	path=next
	direct_walking=false
	mode="walk"
	return true

func approach(id: String, point: Vector3, angle: int, intent: String) -> bool:
	if grid == null: return false
	var bounds := Editor.oriented_dimensions(id,angle)
	var best: Array[Vector3]=[]
	var shortest := INF
	# Stand outside the item's footprint, including when it is on a table.
	var extent := Vector2(bounds.x/2+.45,bounds.z/2+.45)
	var approach_center := point
	if id == "sleeping_bag" and state.get("field", {}).has("tent"):
		var tent: Dictionary = state.field.tent
		approach_center = Vector3(float(tent.x), 0, float(tent.z))
		var tent_bounds := Editor.dimensions("tent")
		extent = Vector2(tent_bounds.x, tent_bounds.z) / 2 + Vector2.ONE * .45
	if point.y > .1: extent=Vector2(1.6,1.25)
	for offset in [Vector3(extent.x,0,0),Vector3(-extent.x,0,0),Vector3(0,0,extent.y),Vector3(0,0,-extent.y)]:
		var candidate: Vector3=approach_center+offset;candidate.y=0
		if candidate.x<.25 or candidate.x>width-.25 or candidate.z<.25 or candidate.z>depth-.25: continue
		if grid.is_point_solid(cell(candidate)): continue
		var next := route(candidate)
		if next.is_empty(): continue
		var length := position.distance_to(next[0])
		for i in range(1,next.size()): length+=next[i-1].distance_to(next[i])
		if length<shortest: best=next;shortest=length
	if best.is_empty(): return false
	seat_id=id if intent == "sit" else ""
	seat_angle=angle
	look_target=point
	path=best
	mode="approach_seat" if intent == "sit" else "approach_install"
	facing_left=view_right.dot(point-position)<0
	return true

func seat(point: Vector3, angle: int) -> bool:
	return approach("chair",point,angle,"sit")

func install(id: String, point: Vector3, angle: int) -> bool:
	return approach(id,point,angle,"install")

func cancel() -> void:
	path.clear()
	direct_walking=false
	mode="idle"
	seat_id=""
	work_remaining=0
	if grid != null: position=nearest(position)

func direct(direction: Vector2, delta: float) -> void:
	direct_walking=false
	if direction.length()<.1 or mode in ["approach_install","install","saving"]: return
	if mode == "sit": position=nearest(position)
	var movement := Vector3(direction.x,0,direction.y).limit_length(1)*SPEED*delta
	var next := position+movement
	if not grid.is_point_solid(cell(next)):
		seat_id="";path.clear();mode="idle";position=next;direct_walking=true
		if absf(view_right.dot(movement))>.001: facing_left=view_right.dot(movement)<0

func advance(delta: float) -> void:
	if mode == "install":
		work_remaining-=delta
		if work_remaining<=0:
			mode="saving"
			installation_ready.emit()
		return
	if path.is_empty(): return
	var previous := position
	position=position.move_toward(path[0],SPEED*delta)
	if absf(view_right.dot(position-previous))>.001: facing_left=view_right.dot(position-previous)<0
	if position.distance_to(path[0])<.015: path.pop_front()
	if path.is_empty():
		if mode == "approach_install":
			mode="install";work_remaining=1.0
			facing_left=view_right.dot(look_target-position)<0
		elif mode == "approach_seat":
			mode="sit"
			var p: Dictionary=state.field.get("chair",{})
			if p.is_empty(): cancel()
			else: position=Vector3(float(p.x),0,float(p.z))
		else: mode="idle"

func animation() -> String:
	if mode == "sit": return Assets.seated_animation(seat_angle)
	if mode in ["install","saving"]: return "install"
	return "walk" if direct_walking or not path.is_empty() else "idle"
