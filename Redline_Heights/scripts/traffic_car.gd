class_name TrafficCar
extends AnimatableBody3D
## An AI car that drives along the road grid, turns at junctions and stops for obstacles.

var kind := "saloon"
var driver_id := ""
var driver_model: Node3D = null
var paint := ""               # texture name, so a carjacked car keeps its colour
var node_a := -1                # the node the car is leaving
var node_b := -1                # the node it is driving to
var s := 0.0                    # distance driven along the edge
var edge_len := 1.0
var lane := 3.0                 # offset to the right of the road centre line (right-hand traffic)
var cruise := 11.0
var speed := 0.0
var half_len := 2.3
var yaw := 0.0
var _edge_kind := 0
var _on_water := false
var _lamps: Array[MeshInstance3D] = []

func setup(kind_id: String, tex_name: String) -> void:
	kind = kind_id
	add_to_group("traffic")
	collision_layer = 16
	collision_mask = 0
	sync_to_physics = false
	kind_id = Car.ALIASES.get(kind_id, kind_id)
	if not Car.DEFS.has(kind_id):
		kind_id = "saloon"
	kind_id = Car.resolve_kind(kind_id)
	if Car.DEFS[kind_id].has("cruiser") or Car.DEFS[kind_id].has("amb") or Car.DEFS[kind_id].has("ftruck"):
		kind_id = "saloon"                  # NPC traffic only uses the plain PSX / glb cars
	var def: Dictionary = Car.DEFS[kind_id]
	if def.has("karoq") or def.has("crown"):
		var glb := "res://assets/vehicles/main/%s.glb" % ("fumi" if def.has("fumi") else "karoq" if def.has("karoq") else "police_crown")
		_setup_fbx_visual({"fbx": glb, "len": def.len})
		return
	if def.has("fbx"):
		_setup_fbx_visual(def)
		return
	if tex_name == "" or not ResourceLoader.exists(Car.ASSET + def.dir + tex_name + ".png"):
		tex_name = def.tex[randi() % def.tex.size()]
	paint = tex_name
	var mesh := load(Car.ASSET + def.dir + def.obj) as Mesh
	var bb := mesh.get_aabb()
	var sc: float = def.len / bb.size.z
	half_len = def.len * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/car_body.gdshader") as Shader
	mat.set_shader_parameter("albedo_tex", load(Car.ASSET + def.dir + tex_name + ".png") as Texture2D)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.scale = Vector3.ONE * sc
	var c := bb.get_center()
	inst.position = Vector3(-c.x * sc, -bb.position.y * sc, -c.z * sc)
	add_child(inst)
	# a driver sits behind the (tinted) glass
	var pool := Game.civ_pool
	driver_id = pool[randi() % pool.size()] if not pool.is_empty() else "Male/Character_12"
	driver_model = Game.load_character(driver_id)
	add_child(driver_model)
	driver_model.position = Vector3(bb.size.x * sc * 0.22, Car.RIDE + Car.SEAT_DROP + Car.seat_dy_for(def, bb.size.y * sc), def.len * 0.31 - 1.15 + float(def.get("seat_dz", 0.0)))
	var dap := AnimationPlayer.new()
	driver_model.add_child(dap)
	dap.root_node = NodePath("..")
	dap.add_animation_library("", Game.get_anim_library())
	dap.play("Driving")
	var dsk := driver_model.find_children("*", "Skeleton3D", true, false)
	if not dsk.is_empty():
		for n in ["mixamorig_LeftLeg", "mixamorig_RightLeg"]:
			var bi := (dsk[0] as Skeleton3D).find_bone(n)
			if bi >= 0: (dsk[0] as Skeleton3D).set_bone_pose_scale(bi, Vector3.ONE * 0.001)
	for side in [1.0, -1.0]:
		var mir := Car.make_mirror(side)
		mir.position = Vector3(side * (bb.size.x * sc * 0.5 + 0.01), bb.size.y * sc * 0.6, def.len * 0.31 - 0.65)
		add_child(mir)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.85 * 0.96, 1.4 * 0.65, def.len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)
	cruise = randf_range(8.5, 14.0)
	var tl := StandardMaterial3D.new()
	tl.albedo_color = Color("#ff2a2a")
	tl.emission_enabled = true
	tl.emission = Color("#ff1010")
	for side in [-1.0, 1.0]:
		var l := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.14, 0.06)
		l.mesh = bm
		l.material_override = tl
		l.position = Vector3(side * 1.85 * 0.33, 0.7, -def.len * 0.5 + 0.02)
		l.visible = false
		add_child(l)
		_lamps.append(l)

## Visual for models with separate wheels (ambulance, fire truck): static, wheels stay where they are.
func _setup_fbx_visual(def: Dictionary) -> void:
	var inst := (load(def.fbx) as PackedScene).instantiate() as Node3D
	var body_bb := AABB()
	var first := true
	var wheel_bottom := 1e9
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := Car._xf_rel(mi, inst)
		var bb: AABB = xf * (mi as MeshInstance3D).get_aabb()
		if "wheel" in String(mi.name).to_lower():
			wheel_bottom = minf(wheel_bottom, bb.position.y)
		else:
			body_bb = bb if first else body_bb.merge(bb)
			first = false
	var sc: float = def.len / body_bb.size.z
	half_len = def.len * 0.5
	inst.scale = Vector3.ONE * sc
	inst.position = Vector3(-body_bb.get_center().x * sc, -wheel_bottom * sc, -body_bb.get_center().z * sc)
	add_child(inst)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(body_bb.size.x * sc * 0.96, 1.8, def.len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, 1.1, 0)
	add_child(cs)
	cruise = randf_range(8.0, 12.0)

## Put the car on the road: from node a towards node b, `dist` metres along.
func place_on(a: int, b: int, dist: float) -> void:
	node_a = a
	node_b = b
	s = dist
	_load_edge()
	_apply()

func _edge_between(a: int, b: int) -> int:
	for ad in CityData.adj[a]:
		if ad.n == b: return ad.e
	return -1

func _load_edge() -> void:
	var pa := CityData.nodes[node_a]
	var pb := CityData.nodes[node_b]
	edge_len = maxf(pa.distance_to(pb), 0.1)
	var ei := _edge_between(node_a, node_b)
	_edge_kind = int(CityData.edges[ei][2]) if ei >= 0 else 0
	var mid := (pa + pb) * 0.5
	_on_water = CityData.is_water(mid.x, mid.y)

func _dir() -> Vector2:
	return (CityData.nodes[node_b] - CityData.nodes[node_a]).normalized()

func _apply() -> void:
	var pa := CityData.nodes[node_a]
	var d := _dir()
	var right := Vector2(-d.y, d.x)
	var p := pa + d * s + right * lane
	var y := (CityRoads.bridge_h(p) + 0.1) if (_on_water or CityData.is_water(p.x, p.y)) else maxf(CityData.height_at(p.x, p.y), 0.0) + 0.04
	global_position = Vector3(p.x, y, p.y)
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.y), 0.3)

func _physics_process(delta: float) -> void:
	if node_a < 0: return
	# obstacle check straight ahead
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var from := global_position + Vector3(0, 0.7, 0) + fwd * half_len
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 11.0, 2 | 4 | 8 | 16)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var target := cruise * (1.5 if _edge_kind == 1 else (1.25 if _edge_kind == 3 else 1.0))
	var braking := false
	if not hit.is_empty():
		var dd: float = from.distance_to(hit.position)
		target = clampf((dd - 3.0) * 1.4, 0.0, target)
		braking = target < speed - 0.5
	# stay put while the player stands next to the car (so it can be carjacked)
	var pl := Game.player as Node3D
	if pl != null and is_instance_valid(pl) and Game.in_car == null:
		var to_pl := pl.global_position - global_position
		to_pl.y = 0.0
		var ahead := to_pl.dot(fwd)
		var side := absf(to_pl.dot(fwd.cross(Vector3.UP)))
		# beside the car, or coming up in front of it close enough that it must start braking now
		if to_pl.length() < 4.5 or (ahead > 0.0 and ahead < 9.0 and side < 3.2):
			target = 0.0
			braking = speed > 0.5
	# slow for the next junction
	var remaining := edge_len - s
	if remaining < 12.0:
		target = minf(target, 6.0 + remaining * 0.5)
	speed = move_toward(speed, target, (14.0 if target < speed else 3.5) * delta)
	for l in _lamps:
		l.visible = braking
	s += speed * delta
	while s >= edge_len:
		s -= edge_len
		_arrive()
	_apply()

## At a node: mostly carry straight on, sometimes turn, turn around only at a dead end.
func _arrive() -> void:
	var here := node_b
	var d_in := _dir()
	var options: Array = []
	for ad in CityData.adj[here]:
		if ad.n == node_a: continue
		var d_out := (CityData.nodes[ad.n] - CityData.nodes[here]).normalized()
		var turn := d_in.dot(d_out)
		options.append({"n": ad.n, "w": 4.0 if turn > 0.9 else (1.0 if turn > -0.3 else 0.0)})
	var chosen := node_a             # dead end: go back
	var total := 0.0
	for o in options: total += o.w
	if total > 0.0:
		var r := randf() * total
		for o in options:
			r -= o.w
			if r <= 0.0:
				chosen = o.n
				break
	node_a = here
	node_b = chosen
	_load_edge()
