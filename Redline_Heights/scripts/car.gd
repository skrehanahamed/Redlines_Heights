class_name Car
extends VehicleBody3D
## A drivable (or parked) car built from a PSX model. Rear-wheel drive, heavy, a bit loose.

const DEFS := {
	"wagon": {"name": "Wagon", "dir": "car01/", "obj": "Car.obj", "tex": ["car", "car_blue", "car_gray", "car_red"], "len": 4.9, "mass": 1600.0, "power": 0.9, "rear": true},
	"saloon": {"name": "Saloon", "dir": "car02/", "obj": "Car2.obj", "tex": ["car2", "car2_black", "car2_red"], "len": 4.6, "mass": 1450.0, "power": 1.0, "rear": true},
	"hatch": {"name": "Hatchback", "dir": "car03/", "obj": "Car3.obj", "tex": ["car3", "car3_red", "car3_yellow"], "len": 4.0, "mass": 1200.0, "power": 1.05},
	"van": {"name": "Van", "dir": "car04/", "obj": "Car4.obj", "tex": ["car4", "car4_grey", "car4_lightgrey", "car4_lightorange"], "len": 5.2, "mass": 2000.0, "power": 0.85, "seat_dy": 0.32, "seat_dz": 0.35},
	"taxi": {"name": "Taxi", "dir": "car05/", "obj": "Car5_Taxi.obj", "tex": ["car5_taxi"], "len": 4.7, "mass": 1500.0, "power": 1.0, "rear": true},
	"police": {"name": "Police", "cruiser": true, "emerg": true, "tex": ["crown"], "len": 4.95, "mass": 1650.0, "power": 1.3, "rear": true, "seat_dy": -0.22, "seat_dz": -0.43, "door_z": 0.3},
	"old": {"name": "Old Timer", "dir": "car07/", "obj": "Car7.obj", "tex": ["car7", "car7_black", "car7_brown", "car7_green", "car7_grey", "car7_red"], "len": 4.2, "mass": 1100.0, "power": 0.8, "rear": true},
	"fumi": {"name": "Fumi SC", "drv_x": -1.0, "karoq": true, "fumi": true, "tex": ["fumi"], "len": 4.7, "mass": 1400.0, "power": 2.4, "rear": false, "seat_dy": -0.1, "seat_dz": -0.3},
	"karoq": {"name": "Karoq SUV", "karoq": true, "tex": ["karoq"], "len": 4.5, "mass": 1700.0, "power": 1.2, "rear": true, "seat_dy": -0.38, "seat_dz": 0.45},
	"factory_gt": {"name": "Factory GT", "gt": true, "tex": ["gt"], "len": 4.5, "mass": 1400.0, "power": 2.2, "rear": false, "seat_dy": -0.3, "seat_dz": -0.1, "door_z": 0.1},
	"ambulance": {"name": "Ambulance", "amb": true, "emerg": true, "len": 5.8, "mass": 2300.0, "power": 1.5, "seat_dy": 0.5, "seat_dz": 0.79, "door_z": 1.45},
	"firetruck": {"name": "Fire Truck", "ftruck": true, "len": 9.6, "mass": 5200.0, "power": 2.6, "top": 26.0, "seat_dy": 0.55, "seat_dz": 1.6},
	"golfcart": {"name": "Golf Cart", "cart": true, "tex": ["cart"], "len": 3.0, "mass": 520.0, "power": 0.5, "top": 9.0, "seat_dy": 0.28, "seat_dz": 0.2, "open": true},
	"box": {"name": "Box Truck", "dir": "car08/", "obj": "Car8.obj", "tex": ["Car8", "Car8_grey", "Car8_mail", "Car8_purple"], "len": 6.2, "mass": 3000.0, "power": 0.7, "seat_dy": 0.65, "seat_dz": 0.3},
}
## Older kind names used around the game map onto the PSX cars.
const ALIASES := {"sedan": "saloon", "sedan_rusted": "saloon", "pickup": "van", "coupe": "hatch"}
const ASSET := "res://assets/vehicles/psx_cars/"

static func pick_texture(kind_id: String, rng: RandomNumberGenerator) -> String:
	kind_id = ALIASES.get(kind_id, kind_id)
	var t: Array = DEFS[kind_id].tex
	return t[rng.randi() % t.size()]

# --- tuning ---
const ENGINE_FORCE := 4600.0
const TOP_SPEED := 56.0
const BRAKE_FORCE := 60.0
const HANDBRAKE_FORCE := 40.0
const STEER_LOW := 0.55
const STEER_HIGH := 0.10
const STEER_SPEED := 4.5
const WHEEL_R := 0.34
const RIDE := 0.60               # distance from body origin down to the ground when settled

var kind := "saloon"
var def: Dictionary
var model_len := 4.65
var model_w := 1.85
var model_h := 1.40
var hp := 100.0
var driver: Node = null
var player_controlled := false
var speed_ms := 0.0
var lights_on := false
var lights_pending := false       # set when someone gets in; the weather system then switches the lights on if it is dark
var braking_now := false
var scripted := false           # test harness input
var s_throttle := 0.0
var s_brake := 0.0
var s_steer := 0.0
var s_hand := false
var parked := false
var wheels: Array[VehicleWheel3D] = []
var head_lamps: Array[MeshInstance3D] = []
var tail_lamps: Array[MeshInstance3D] = []
var spots: Array[SpotLight3D] = []
var head_mat: StandardMaterial3D
var tail_mat: StandardMaterial3D
var body_mat: StandardMaterial3D
var _head_fill: OmniLight3D = null
var _tail_omni: OmniLight3D = null
var _engine_idle: AudioStreamPlayer3D
var _engine_mid: AudioStreamPlayer3D
var _skid: AudioStreamPlayer3D
var _last_speed := 0.0
var _crash_cd := 0.0
var ai_chase := false
var _stuck_t := 0.0
var _rev_t := 0.0
var _siren: AudioStreamPlayer3D
var _flash: OmniLight3D
var _flash_t := 0.0
var siren_on := false
var _amb_bar_mat: StandardMaterial3D
var _amb_lights: Array = []       # [red OmniLight3D, blue OmniLight3D] over the roof light bar
var cops_out: Array = []          # officers that got out of this patrol car
var _cop_cd := 0.0

var wheel_info: Dictionary = {}
var drv_x := 1.0                   # which side of the car (local X) the steering wheel is on
var door_fl: Node3D = null
var door_fr: Node3D = null
var door_rl: Node3D = null
var door_rr: Node3D = null
var hood_node: Node3D = null
var trunk_node: Node3D = null
var doors_open := false
var _door_tween: Tween = null
var _door_sound: AudioStreamPlayer3D = null

## Only the supplied car models exist: any other kind becomes the Karoq until more are added.
static func resolve_kind(k: String) -> String:
	if k == "firetruck":
		return "firetruck" if ResourceLoader.exists(FTRUCK_FILE) else "fumi"
	k = ALIASES.get(k, k)
	if not DEFS.has(k) or DEFS[k].has("obj") or DEFS[k].has("fbx") or k == "karoq":
		return "fumi"
	return k

func setup(kind_id: String, tex_name := "", is_parked := false) -> void:
	add_to_group("cars")
	kind_id = resolve_kind(kind_id)
	kind = kind_id
	def = DEFS[kind_id]
	drv_x = float(def.get("drv_x", 1.0))
	parked = is_parked
	if def.has("ftruck"):
		_setup_ftruck()
		if parked:
			_settle_then_freeze()
			_freeze_after_settling()
		else:
			_wake()
		return
	if def.has("cart"):
		_setup_cart()
		if parked:
			_settle_then_freeze()
			_freeze_after_settling()      # a parked cart costs no physics until someone gets in (enter() wakes it)
		else:
			_wake()
		return
	if def.has("gt"):
		_setup_gt()
		if parked:
			_settle_then_freeze()
		else:
			_wake()
		return
	if def.has("cruiser"):
		_setup_cruiser()
		if parked:
			_settle_then_freeze()
		else:
			_wake()
		return
	if def.has("crown"):
		_setup_crown()
		if parked:
			_settle_then_freeze()
		else:
			_wake()
		return
	if def.has("karoq"):
		_setup_karoq()
		if parked:
			_settle_then_freeze()
		else:
			_wake()
		return
	if def.has("amb"):
		_setup_ambulance()
		if parked:
			_settle_then_freeze()
		else:
			_wake()
		return
	if def.has("fbx"):
		_setup_fbx()
		if parked:
			_settle_then_freeze()
		else:
			_wake()
		return
	if tex_name == "" or not ResourceLoader.exists(ASSET + def.dir + tex_name + ".png"):
		tex_name = def.tex[0]

	var mesh := load(ASSET + def.dir + def.obj) as Mesh
	var bb := mesh.get_aabb()
	var s: float = def.len / bb.size.z
	model_len = def.len
	model_w = bb.size.x * s
	model_h = bb.size.y * s
	mass = def.mass
	collision_layer = 4          # vehicles
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.4, 0)
	linear_damp = 0.02
	angular_damp = 1.4
	contact_monitor = true
	max_contacts_reported = 4
	# model: paint texture with see-through glass
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_texture = load(ASSET + def.dir + tex_name + ".png") as Texture2D
	body_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	body_mat.roughness = 0.75
	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.mesh = mesh
	mi.material_override = _shell_material(body_mat.albedo_texture)
	mi.scale = Vector3.ONE * s
	var c := bb.get_center()
	mi.position = Vector3(-c.x * s, -RIDE - bb.position.y * s, -c.z * s)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	# the four wheels are separate islands in the mesh: cut them out so they spin and steer
	var body_src: Mesh = mesh
	wheel_info = WheelSlicer.extract(mesh)
	if not wheel_info.is_empty():
		body_src = wheel_info.body
		mi.mesh = body_src
	_make_doors(mi, body_src, bb, s)
	# collision
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(model_w * 0.96, model_h * 0.62, model_len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, -RIDE + model_h * 0.28 + 0.3, 0)
	add_child(cs)
	_make_wheels(s)
	_make_lights()
	_make_audio()
	if parked:
		_settle_then_freeze()
	else:
		_wake()

static func _xf_rel(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

## A vehicle loaded from a model that has its four wheels as separate meshes (ambulance, fire truck): the wheels are
## moved onto the physics wheels so they spin and steer, the windows are made translucent.
func _setup_fbx() -> void:
	var inst := (load(def.fbx) as PackedScene).instantiate() as Node3D
	var parts: Array = []
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := _xf_rel(mi, inst)
		parts.append({"mi": mi, "xf": xf, "bb": xf * (mi as MeshInstance3D).get_aabb(), "wheel": "wheel" in String(mi.name).to_lower()})
	var body_bb := AABB()
	var first := true
	var wheel_bottom := 1e9
	for p in parts:
		if p.wheel:
			wheel_bottom = minf(wheel_bottom, (p.bb as AABB).position.y)
		else:
			body_bb = p.bb if first else body_bb.merge(p.bb)
			first = false
	var s: float = def.len / body_bb.size.z
	model_len = def.len
	model_w = body_bb.size.x * s
	model_h = (body_bb.end.y - wheel_bottom) * s
	mass = def.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.4, 0)
	linear_damp = 0.02
	angular_damp = 1.4
	contact_monitor = true
	max_contacts_reported = 4
	var cx := body_bb.get_center().x
	var cz := body_bb.get_center().z
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-cx * s, -RIDE - wheel_bottom * s, -cz * s)
	add_child(inst)
	# translucent windows on the body
	for p in parts:
		if p.wheel: continue
		var bmi := p.mi as MeshInstance3D
		for i in range(bmi.mesh.get_surface_count()):
			var m0 := bmi.get_active_material(i)
			if m0 is StandardMaterial3D and "window" in String(m0.resource_name).to_lower():
				var gm := (m0 as StandardMaterial3D).duplicate() as StandardMaterial3D
				gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				gm.albedo_color = Color(0.05, 0.1, 0.14, 0.5)
				bmi.set_surface_override_material(i, gm)
	# collision box
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(model_w * 0.96, model_h * 0.62, model_len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, -RIDE + model_h * 0.34 + 0.3, 0)
	add_child(cs)
	# physics wheels carry the wheel meshes
	var wparts: Array = parts.filter(func(p): return p.wheel)
	wparts.sort_custom(func(a, b): return (a.bb as AABB).get_center().z > (b.bb as AABB).get_center().z)
	for i in range(wparts.size()):
		var p: Dictionary = wparts[i]
		var wb: AABB = p.bb
		var c := wb.get_center()
		var wheel_r := maxf(wb.size.y, wb.size.z) * 0.5 * s
		var front := i < 2
		var w := VehicleWheel3D.new()
		w.position = Vector3((c.x - cx) * s, -0.46 + wheel_r, (c.z - cz) * s)
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = wheel_r
		w.wheel_rest_length = 0.24
		w.suspension_travel = 0.26
		w.suspension_stiffness = 38.0
		w.suspension_max_force = 18000.0 * (mass / 1500.0)
		w.damping_compression = 2.3
		w.damping_relaxation = 2.9
		w.wheel_friction_slip = 3.6 if front else 3.4
		w.wheel_roll_influence = 0.25
		add_child(w)
		wheels.append(w)
		var wmi := p.mi as MeshInstance3D
		wmi.get_parent().remove_child(wmi)
		w.add_child(wmi)
		var b := Basis.from_scale(Vector3.ONE * s) * (p.xf as Transform3D).basis
		var mc := wmi.mesh.get_aabb().get_center()
		wmi.transform = Transform3D(b, -(b * mc))
	_make_lights()
	_make_audio()

## The police cruiser: one rigged model whose wheels are separate meshes. They go onto the physics wheels.
func _setup_crown() -> void:
	var inst := (load("res://assets/vehicles/main/police_crown.glb") as PackedScene).instantiate() as Node3D
	add_child(inst)                                   # in the tree so the rig's bone attachments report their positions
	var inv := inst.global_transform.affine_inverse()
	var groups := {"Ft_L": [], "Ft_R": [], "Bk_L": [], "Bk_R": []}
	var tot := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var rel: Transform3D = inv * m.global_transform
		var bb: AABB = rel * m.get_aabb()
		var key := ""
		var nm := String(m.name)
		if "Wheel" in nm:
			for k in groups:
				if k in nm: key = k
		if key != "":
			(groups[key] as Array).append({"mi": m, "rel": rel, "bb": bb})
		if not (key == "" and false):
			tot = bb if first else tot.merge(bb)
			first = false
	var centers := {}
	for k in groups:
		var gb := AABB()
		var gf := true
		for e in groups[k]:
			gb = e.bb if gf else gb.merge(e.bb)
			gf = false
		centers[k] = gb.get_center()
		centers[k + "_r"] = maxf(gb.size.y, gb.size.z) * 0.5
	var fwd: Vector3 = ((centers["Ft_L"] + centers["Ft_R"]) * 0.5 - (centers["Bk_L"] + centers["Bk_R"]) * 0.5)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var yaw := atan2(-fwd.x, fwd.z)
	var rot := Basis(Vector3.UP, yaw)
	var rtot := tot
	# size along the driving direction after turning
	var corners := PackedVector3Array()
	for ix in [0, 1]:
		for iz in [0, 1]:
			corners.append(rot * Vector3(tot.position.x + tot.size.x * ix, 0, tot.position.z + tot.size.z * iz))
	var zmin := 1e9
	var zmax := -1e9
	var xmin := 1e9
	var xmax := -1e9
	for c in corners:
		zmin = minf(zmin, c.z); zmax = maxf(zmax, c.z); xmin = minf(xmin, c.x); xmax = maxf(xmax, c.x)
	var s: float = float(def.len) / (zmax - zmin)
	model_len = def.len
	model_w = (xmax - xmin) * s
	model_h = tot.size.y * s
	mass = def.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.4, 0)
	linear_damp = 0.02
	angular_damp = 1.4
	contact_monitor = true
	max_contacts_reported = 4
	var model_xf := Transform3D(rot * Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
	var mid := rot * Vector3(tot.get_center().x, 0, tot.get_center().z) * s
	model_xf.origin = Vector3(-mid.x, -RIDE - tot.position.y * s, -mid.z)
	var order := ["Ft_L", "Ft_R", "Bk_L", "Bk_R"]
	var wdata := {}
	for k in order:
		wdata[k] = {"center": model_xf * centers[k], "r": centers[k + "_r"] * s, "items": []}
		for e in groups[k]:
			(wdata[k].items as Array).append({"mi": e.mi, "rel": e.rel})
			(e.mi as Node).get_parent().remove_child(e.mi)
	inst.transform = model_xf
	for k in order:
		var wd: Dictionary = wdata[k]
		var c: Vector3 = wd.center
		var front: bool = String(k).begins_with("Ft")
		var w := VehicleWheel3D.new()
		w.position = c + Vector3(0, 0.14, 0)
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = wd.r
		w.wheel_rest_length = 0.24
		w.suspension_travel = 0.26
		w.suspension_stiffness = 38.0
		w.suspension_max_force = 18000.0
		w.damping_compression = 2.3
		w.damping_relaxation = 2.9
		w.wheel_friction_slip = 3.6 if front else 3.4
		w.wheel_roll_influence = 0.25
		add_child(w)
		wheels.append(w)
		for it in wd.items:
			var mm: MeshInstance3D = it.mi
			w.add_child(mm)
			mm.transform = Transform3D(Basis(), -c) * model_xf * (it.rel as Transform3D)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(model_w * 0.9, model_h * 0.62, model_len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, -RIDE + model_h * 0.34 + 0.3, 0)
	add_child(cs)
	_make_lights()
	_make_audio()

## The main car: a detailed SUV with separate doors and wheel groups. Wheels go onto the physics wheels (they spin and
## steer), each door gets a vertical hinge pivot so it swings open.
func _setup_karoq() -> void:
	var inst: Node3D
	if def.has("fumi"):
		inst = _prepare_fumi()
	else:
		inst = (load("res://assets/vehicles/main/karoq.glb") as PackedScene).instantiate() as Node3D
		for n in inst.find_children("*", "", true, false):
			n.owner = null
		inst.owner = null
	# overall size from every mesh
	var tot := AABB()
	var first := true
	var wheel_groups: Array = []
	for nm in ["wheel", "wheel_001", "wheel_002", "wheel_003"]:
		var gnode := inst.find_child(nm, true, false) as Node3D
		if gnode != null: wheel_groups.append(gnode)
	var wheel_meshes := {}
	for gnode in wheel_groups:
		for mi in gnode.find_children("*", "MeshInstance3D", true, false):
			wheel_meshes[mi] = gnode
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = _xf_rel(mi, inst) * (mi as MeshInstance3D).get_aabb()
		tot = bb if first else tot.merge(bb)
		first = false
	var s: float = float(def.len) / tot.size.z
	model_len = def.len
	model_w = tot.size.x * s
	model_h = tot.size.y * s
	mass = def.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.4, 0)
	linear_damp = 0.02
	angular_damp = 1.4
	contact_monitor = true
	max_contacts_reported = 4
	var cx := tot.get_center().x
	var cz := tot.get_center().z
	# the model faces -Z; turn it round so the car drives along +Z, and put the tyres on the ground
	var base_y := tot.position.y
	var model_xf := Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
	model_xf.origin = Basis(Vector3.UP, PI) * Vector3(-cx * s, 0, -cz * s) + Vector3(0, -RIDE - base_y * s, 0)
	# --- wheels: each wheel group becomes a physics wheel carrying its meshes
	var wdata: Array = []
	for gnode in wheel_groups:
		var gb := AABB()
		var gfirst := true
		var meshes: Array = []
		for mi in gnode.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
			var bb2: AABB = _xf_rel(mi, inst) * (mi as MeshInstance3D).get_aabb()
			gb = bb2 if gfirst else gb.merge(bb2)
			gfirst = false
		var c_car := model_xf * gb.get_center()
		var rel_list: Array = []
		for mi in meshes:
			rel_list.append(_xf_rel(mi, inst))
			mi.get_parent().remove_child(mi)
		wdata.append({"center": c_car, "meshes": meshes, "rels": rel_list, "r": maxf(gb.size.y, gb.size.z) * 0.5 * s})
	for gnode in wheel_groups:
		gnode.get_parent().remove_child(gnode)
		gnode.free()
	inst.transform = model_xf
	add_child(inst)
	var wheel_src: Array = wdata.duplicate()
	wheel_src.sort_custom(func(a, b): return a.center.z > b.center.z)       # front pair first
	for i in range(wheel_src.size()):
		var wd: Dictionary = wheel_src[i]
		var c: Vector3 = wd.center
		var front := i < 2
		var w := VehicleWheel3D.new()
		w.position = c + Vector3(0, 0.14, 0)         # hub mount sits above the wheel centre by the spring compression
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = wd.r
		w.wheel_rest_length = 0.24
		w.suspension_travel = 0.26
		w.suspension_stiffness = 38.0
		w.suspension_max_force = 18000.0
		w.damping_compression = 2.3
		w.damping_relaxation = 2.9
		w.wheel_friction_slip = 3.6 if front else 3.4
		w.wheel_roll_influence = 0.25
		add_child(w)
		wheels.append(w)
		for k in range(wd.meshes.size()):
			var m: MeshInstance3D = wd.meshes[k]
			w.add_child(m)
			m.transform = Transform3D(Basis(), -c) * model_xf * (wd.rels[k] as Transform3D)
	# --- doors: a vertical hinge pivot at each door's origin
	var door_names := {"door_lf_dummy": "fl", "door_rf_dummy": "fr", "door_lr_dummy": "rl", "door_rr_dummy": "rr"}
	for dn in door_names:
		var dnode := inst.find_child(dn, true, false) as Node3D
		if dnode == null: continue
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.global_position = dnode.global_position
		dnode.reparent(pivot, true)
		match door_names[dn]:
			"fl": door_fl = pivot
			"fr": door_fr = pivot
			"rl": door_rl = pivot
			"rr": door_rr = pivot
	# --- collision box
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(model_w * 0.92, model_h * 0.62, model_len * 0.96)
	cs.shape = box
	cs.position = Vector3(0, -RIDE + model_h * 0.34 + 0.3, 0)
	add_child(cs)
	_make_lights()
	_make_audio()

## The golf cart (open, roof only): the model's four tyre + rim pairs become physics wheels that spin and steer, everything else is the body.
const FTRUCK_FILE := "res://assets/vehicles/service/fire_truck.glb"

## The fire engine (downloaded glb): nose +Z, four separate wheel meshes that spin (rear pair drives, front pair steers). Its nodes carry odd
## rotations, so every mesh is placed through its real transform relative to the model root.
func _setup_ftruck() -> void:
	var inst := (load(FTRUCK_FILE) as PackedScene).instantiate() as Node3D
	var wheel_meshes: Array = []
	var body_meshes: Array = []
	var tot := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := _xf_rel(mi, inst)
		var bb: AABB = xf * (mi as MeshInstance3D).get_aabb()
		var is_wheel: bool = String(mi.get_parent().name).begins_with("mesh_4_20") or String(mi.get_parent().name).begins_with("mesh_4_19") or String(mi.get_parent().name).begins_with("mesh_4_18") or String(mi.get_parent().name).begins_with("mesh_4_17")
		if is_wheel:
			wheel_meshes.append({"mi": mi, "xf": xf, "bb": bb})
		else:
			body_meshes.append(mi)
			tot = bb if first else tot.merge(bb)
			first = false
	var s: float = float(def.len) / tot.size.z
	model_len = def.len
	model_w = tot.size.x * s
	model_h = tot.size.y * s
	mass = def.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.5, 0)
	linear_damp = 0.02
	angular_damp = 1.6
	contact_monitor = true
	max_contacts_reported = 4
	var ctr := tot.get_center()
	var base_y := 1e9
	for wm in wheel_meshes: base_y = minf(base_y, (wm.bb as AABB).position.y)
	var model_xf := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-ctr.x * s, -RIDE - base_y * s, -ctr.z * s))
	var wdata: Array = []
	for wm in wheel_meshes:
		var wb: AABB = wm.bb
		var mi2: MeshInstance3D = wm.mi
		mi2.get_parent().remove_child(mi2)
		wdata.append({"mi": mi2, "rel": wm.xf, "center": model_xf * wb.get_center(), "r": maxf(wb.size.y, wb.size.z) * 0.5 * s})
	inst.transform = model_xf
	add_child(inst)
	wdata.sort_custom(func(a, b): return a.center.z > b.center.z)
	for i in range(wdata.size()):
		var wd: Dictionary = wdata[i]
		var c: Vector3 = wd.center
		var front := i < 2
		var w := VehicleWheel3D.new()
		w.position = c + Vector3(0, 0.12, 0)
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = wd.r
		w.wheel_rest_length = 0.26
		w.suspension_travel = 0.3
		w.suspension_stiffness = 42.0
		w.suspension_max_force = 18000.0 * (mass / 1500.0)
		w.damping_compression = 3.0
		w.damping_relaxation = 3.6
		w.wheel_friction_slip = 3.4
		w.wheel_roll_influence = 0.12
		add_child(w)
		wheels.append(w)
		var m: MeshInstance3D = wd.mi
		w.add_child(m)
		m.transform = Transform3D(Basis(), -c) * model_xf * (wd.rel as Transform3D)
	var cs := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(model_w * 0.95, model_h * 0.55, model_len * 0.97)
	cs.shape = cbox
	cs.position = Vector3(0, -RIDE + model_h * 0.40 + 0.25, 0)
	add_child(cs)
	_make_lights()
	_make_audio()

const CART_FILE := "res://assets/miami/golf_cart.glb"

func _setup_cart() -> void:
	var inst := (load(CART_FILE) as PackedScene).instantiate() as Node3D
	var tot := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = _xf_rel(mi, inst) * (mi as MeshInstance3D).get_aabb()
		tot = bb if first else tot.merge(bb)
		first = false
	var s: float = float(def.len) / tot.size.z
	model_len = def.len
	model_w = tot.size.x * s
	model_h = tot.size.y * s
	mass = def.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0)
	linear_damp = 0.02
	angular_damp = 1.6
	contact_monitor = true
	max_contacts_reported = 4
	var ctr := tot.get_center()
	# the model's nose is +Z already
	var model_xf := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-ctr.x * s, -RIDE - tot.position.y * s, -ctr.z * s))
	var wdata: Array = []
	for nm in ["Frontal", "Rear"]:
		for suf in ["", "_001"]:
			var meshes: Array = []
			for part in ["tire", "rim"]:
				var gnode := inst.find_child("%s %s%s" % [nm, part, suf], true, false) as Node3D
				if gnode == null: continue
				for mi in gnode.find_children("*", "MeshInstance3D", true, false): meshes.append(mi)
			if meshes.is_empty(): continue
			var gb := AABB()
			var gfirst := true
			var rels: Array = []
			for mi in meshes:
				var rel := _xf_rel(mi, inst)
				rels.append(rel)
				var bb2: AABB = rel * (mi as MeshInstance3D).get_aabb()
				gb = bb2 if gfirst else gb.merge(bb2)
				gfirst = false
			for mi in meshes: mi.get_parent().remove_child(mi)
			wdata.append({"center": model_xf * gb.get_center(), "meshes": meshes, "rels": rels, "r": maxf(gb.size.y, gb.size.z) * 0.5 * s})
	inst.transform = model_xf
	add_child(inst)
	wdata.sort_custom(func(a, b): return a.center.z > b.center.z)       # front pair first
	for i in range(wdata.size()):
		var wd: Dictionary = wdata[i]
		var c: Vector3 = wd.center
		var front := i < 2
		var w := VehicleWheel3D.new()
		w.position = c + Vector3(0, 0.1, 0)
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = wd.r
		w.wheel_rest_length = 0.18
		w.suspension_travel = 0.2
		w.suspension_stiffness = 16.0
		w.suspension_max_force = 6000.0
		w.damping_compression = 1.6
		w.damping_relaxation = 2.0
		w.wheel_friction_slip = 3.2
		w.wheel_roll_influence = 0.2
		add_child(w)
		wheels.append(w)
		for k in range(wd.meshes.size()):
			var m: MeshInstance3D = wd.meshes[k]
			w.add_child(m)
			m.transform = Transform3D(Basis(), -c) * model_xf * (wd.rels[k] as Transform3D)
	var cs := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(model_w * 0.92, 0.9, model_len * 0.96)
	cs.shape = cbox
	cs.position = Vector3(0, -RIDE + 0.62, 0)
	add_child(cs)
	_make_lights()
	_make_audio()

## The orange GT sports car. Model in metres, nose +Z, four separate wheel meshes, separate front / rear light strips,
## doors baked into the two body meshes (clipped out like the cruiser's).
const GT_FILE := "res://assets/vehicles/service/factory_gt.glb"

func _setup_gt() -> void:
	var inst := (load(GT_FILE) as PackedScene).instantiate() as Node3D
	var tot := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = _xf_rel(mi, inst) * (mi as MeshInstance3D).get_aabb()
		tot = bb if first else tot.merge(bb)
		first = false
	var s: float = float(def.len) / tot.size.z
	model_len = def.len
	model_w = 2.0 * s
	model_h = 1.1 * s
	mass = def.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.45, 0)
	linear_damp = 0.02
	angular_damp = 1.6
	contact_monitor = true
	max_contacts_reported = 4
	var ctr := tot.get_center()
	var model_xf := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-ctr.x * s, -RIDE - tot.position.y * s, -ctr.z * s))
	# wheels
	var wdata: Array = []
	for nm in ["mesh_4_64_nr", "mesh_4_66_nr", "mesh_4_68_nr", "mesh_4_70_nr"]:
		var wm := inst.find_child(nm, true, false) as MeshInstance3D
		if wm == null: continue
		var rel := _xf_rel(wm, inst)
		var wb: AABB = rel * wm.get_aabb()
		wm.get_parent().remove_child(wm)
		wdata.append({"mi": wm, "rel": rel, "center": model_xf * wb.get_center(), "r": maxf(wb.size.y, wb.size.z) * 0.5 * s})
	# doors: both body meshes and the glass, clipped in a frame where the car's length runs along x
	var turn := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	var box := {"x0": -0.98, "x1": 0.095, "y0": 0.23, "y1": 0.99, "cz": -ctr.x, "zt": 0.55}
	var door_parts := {-1.0: [], 1.0: []}
	for nm in ["mesh_4_55_nr", "mesh_4_56_nr", "mesh_4_57_nr"]:
		var src := inst.find_child(nm, true, false) as MeshInstance3D
		if src == null: continue
		var srel := _xf_rel(src, inst)
		var cut := _cut_cab_doors(src, turn * srel, box)
		for sd in [-1.0, 1.0]:
			if cut[sd] != null: door_parts[sd].append({"mesh": cut[sd], "rel": srel})
	var gt_head: StandardMaterial3D = null     # the round headlamps are painted into the body: only the front light strip glows
	# the light strips glow (front white, rear red)
	for pair in [["mesh_4_61_nr", "head"], ["mesh_4_60_nr", "tail"]]:
		var lmi := inst.find_child(pair[0], true, false) as MeshInstance3D
		if lmi == null: continue
		var lm0 := lmi.get_active_material(0) as StandardMaterial3D
		if lm0 == null: continue
		var lm := lm0.duplicate() as StandardMaterial3D
		lm.emission_enabled = true
		lm.emission_texture = lm.albedo_texture
		lm.emission_energy_multiplier = 0.0
		if pair[1] == "head":
			lm.emission = Color(1.0, 0.95, 0.8)
			head_mat = gt_head if gt_head != null else lm
			if gt_head != null: lm = gt_head
		else:
			lm.emission = Color(0.45, 0.03, 0.02)
			tail_mat = lm
		lmi.material_override = lm
	if head_mat == null: head_mat = gt_head if gt_head != null else StandardMaterial3D.new()
	if tail_mat == null: tail_mat = StandardMaterial3D.new()
	inst.transform = model_xf
	add_child(inst)
	wdata.sort_custom(func(a, b): return a.center.z > b.center.z)
	for i in range(wdata.size()):
		var wd: Dictionary = wdata[i]
		var c: Vector3 = wd.center
		var front := i < 2
		var w := VehicleWheel3D.new()
		w.position = c + Vector3(0, 0.08, 0)
		w.use_as_steering = front
		w.use_as_traction = true
		w.wheel_radius = wd.r
		w.wheel_rest_length = 0.2
		w.suspension_travel = 0.22
		w.suspension_stiffness = 48.0
		w.suspension_max_force = 15000.0
		w.damping_compression = 3.2
		w.damping_relaxation = 4.0
		w.wheel_friction_slip = 4.2
		w.wheel_roll_influence = 0.8
		add_child(w)
		wheels.append(w)
		var m: MeshInstance3D = wd.mi
		w.add_child(m)
		m.transform = Transform3D(Basis(), -c) * model_xf * (wd.rel as Transform3D)
	for sd in [-1.0, 1.0]:
		if door_parts[sd].is_empty(): continue
		# model +X (the driver's side, the car's +X) is cut as sd < 0 in the turned frame
		var skin_x: float = ctr.x + (-float(sd)) * 1.02
		var pp: Vector3 = model_xf * Vector3(skin_x, 0.6, float(box.x1))
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = pp
		for dp in door_parts[sd]:
			var dmi := MeshInstance3D.new()
			dmi.mesh = dp.mesh
			pivot.add_child(dmi)
			dmi.transform = Transform3D(Basis(), -pp) * model_xf * (dp.rel as Transform3D)
		if sd < 0.0: door_fl = pivot
		else: door_fr = pivot
	var cs := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(model_w * 0.95, model_h * 0.62, model_len * 0.97)
	cs.shape = cbox
	cs.position = Vector3(0, -RIDE + model_h * 0.36 + 0.2, 0)
	add_child(cs)
	for sd in [-1.0, 1.0]:
		var sl := SpotLight3D.new()
		sl.position = model_xf * Vector3(ctr.x + sd * 0.55, 0.6, 1.0)
		sl.rotation = Vector3(-0.06, PI, 0.0)
		sl.spot_range = 46.0
		sl.spot_angle = 34.0
		sl.spot_attenuation = 0.72
		sl.light_energy = 5.5
		sl.light_color = Color("#fff4dc")
		sl.shadow_enabled = false
		sl.visible = false
		add_child(sl)
		spots.append(sl)
	_make_audio()

## The Fairheaven '80 police cruiser: wheels become physics wheels, both front doors are clipped out of the body (with their
## glass and window trim) and hinge at their front edge, the lamps glow from the car's own light meshes, and the light bar
## flashes with the siren. The model is in metres, nose on +X, the driver on its -Z side.
const CRUISER_FILE := "res://assets/vehicles/service/fairheaven_lt_80_cop_cruiser_-_low_poly_model.glb"
const CRUISER_BODY_HALF := 0.88

func _setup_cruiser() -> void:
	var inst := (load(CRUISER_FILE) as PackedScene).instantiate() as Node3D
	var tot := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = _xf_rel(mi, inst) * (mi as MeshInstance3D).get_aabb()
		tot = bb if first else tot.merge(bb)
		first = false
	var s: float = float(def.len) / tot.size.x
	model_len = def.len
	model_w = 1.77 * s
	model_h = 1.4 * s
	mass = def.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.5, 0)
	linear_damp = 0.02
	angular_damp = 1.8
	contact_monitor = true
	max_contacts_reported = 4
	var cx := tot.get_center().x
	var cz := tot.get_center().z
	var base_y := tot.position.y
	# model +X (nose) -> car +Z, model -Z (driver) -> car +X
	var rot := Basis(Vector3.UP, -PI * 0.5)
	var model_xf := Transform3D(rot * Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
	model_xf.origin = rot * Vector3(-cx * s, 0, -cz * s) + Vector3(0, -RIDE - base_y * s, 0)
	# --- wheels
	var wheel_groups: Array = []
	for gnode in inst.find_children("Fairheaven_LT80_WheelStamp_*", "Node3D", true, false):
		if gnode is MeshInstance3D: continue
		wheel_groups.append(gnode)
	var wdata: Array = []
	for gnode in wheel_groups:
		var gb := AABB()
		var gfirst := true
		var meshes: Array = []
		for mi in gnode.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
			var bb2: AABB = _xf_rel(mi, inst) * (mi as MeshInstance3D).get_aabb()
			gb = bb2 if gfirst else gb.merge(bb2)
			gfirst = false
		if meshes.is_empty(): continue
		var rel_list: Array = []
		for mi in meshes:
			rel_list.append(_xf_rel(mi, inst))
			mi.get_parent().remove_child(mi)
		wdata.append({"center": model_xf * gb.get_center(), "meshes": meshes, "rels": rel_list, "r": maxf(gb.size.x, gb.size.y) * 0.5 * s})
	for gnode in wheel_groups:
		gnode.get_parent().remove_child(gnode)
		gnode.free()
	# --- front doors: body and window trim clipped to the door outline, the door glass moves whole
	var box := {"x0": -0.07, "x1": 0.87, "y0": 0.29, "y1": 1.30, "cz": cz, "zt": 0.5}
	var door_parts := {-1.0: [], 1.0: []}
	for src_name in ["Fairheaven_LT80_body001_*", "Fairheaven_LT80_Trim_*"]:
		var src := inst.find_child(src_name, true, false) as MeshInstance3D
		if src == null: continue
		var srel := _xf_rel(src, inst)
		var cut := _cut_cab_doors(src, srel, box)
		for sd in [-1.0, 1.0]:
			if cut[sd] != null: door_parts[sd].append({"mesh": cut[sd], "rel": srel})
	var door_glass := {-1.0: [], 1.0: []}
	for gk in [[-1.0, "Fairheaven_LT80_Glass_Driver002_*"], [1.0, "Fairheaven_LT80_Glass_Passanger002_*"]]:
		var gmi := inst.find_child(gk[1], true, false) as MeshInstance3D
		if gmi == null: continue
		door_glass[gk[0]].append({"mi": gmi, "rel": _xf_rel(gmi, inst)})
		gmi.get_parent().remove_child(gmi)
	# --- lamps: the car's own light meshes glow (headlights white, brake lights red)
	head_mat = null
	for pair in [["Fairheaven_LT80_Headlights001_*", "head"], ["Fairheaven_LT80_Brakelights001_*", "tail"]]:
		var lmi := inst.find_child(pair[0], true, false) as MeshInstance3D
		if lmi == null: continue
		var lm0 := lmi.get_active_material(0) as StandardMaterial3D
		if lm0 == null: continue
		var lm := lm0.duplicate() as StandardMaterial3D
		lm.emission_enabled = true
		lm.emission_texture = lm.albedo_texture
		lm.emission_energy_multiplier = 0.0
		if pair[1] == "head":
			lm.emission = Color(1.0, 0.95, 0.8)
			head_mat = lm
		else:
			lm.emission = Color(0.45, 0.03, 0.02)
			tail_mat = lm
		lmi.material_override = lm
	if head_mat == null: head_mat = StandardMaterial3D.new()
	if tail_mat == null: tail_mat = StandardMaterial3D.new()
	var bar := inst.find_child("Fairheaven_LT80_Lightbar_UCB_*", true, false) as MeshInstance3D
	if bar != null: _amb_meshes.append(bar)
	inst.transform = model_xf
	add_child(inst)
	# --- physics wheels
	wdata.sort_custom(func(a, b): return a.center.z > b.center.z)
	for i in range(wdata.size()):
		var wd: Dictionary = wdata[i]
		var c: Vector3 = wd.center
		var front := i < 2
		var w := VehicleWheel3D.new()
		w.position = c + Vector3(0, 0.1, 0)
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = wd.r
		w.wheel_rest_length = 0.22
		w.suspension_travel = 0.24
		w.suspension_stiffness = 42.0
		w.suspension_max_force = 16000.0
		w.damping_compression = 3.0
		w.damping_relaxation = 3.8
		w.wheel_friction_slip = 3.6
		w.wheel_roll_influence = 0.7
		add_child(w)
		wheels.append(w)
		for k in range(wd.meshes.size()):
			var m: MeshInstance3D = wd.meshes[k]
			w.add_child(m)
			m.transform = Transform3D(Basis(), -c) * model_xf * (wd.rels[k] as Transform3D)
	# --- door pivots (the driver, on model -Z, is the car's +X side: door_fl)
	for sd in [-1.0, 1.0]:
		if door_parts[sd].is_empty(): continue
		var pp: Vector3 = model_xf * Vector3(float(box.x1), 0.8, cz + sd * CRUISER_BODY_HALF)
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = pp
		for dp in door_parts[sd]:
			var dmi := MeshInstance3D.new()
			dmi.mesh = dp.mesh
			pivot.add_child(dmi)
			dmi.transform = Transform3D(Basis(), -pp) * model_xf * (dp.rel as Transform3D)
		for g in door_glass[sd]:
			var gm2: MeshInstance3D = g.mi
			pivot.add_child(gm2)
			gm2.transform = Transform3D(Basis(), -pp) * model_xf * (g.rel as Transform3D)
		if sd < 0.0: door_fl = pivot
		else: door_fr = pivot
	var cs := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(model_w * 0.95, model_h * 0.66, model_len * 0.97)
	cs.shape = cbox
	cs.position = Vector3(0, -RIDE + model_h * 0.36 + 0.3, 0)
	add_child(cs)
	# --- headlight beams start at the headlights, fill light under the bumper
	for sd in [-1.0, 1.0]:
		var sl := SpotLight3D.new()
		sl.position = model_xf * Vector3(1.95, 0.66, cz + sd * 0.55)
		sl.rotation = Vector3(-0.07, 0.0, 0.0)
		sl.spot_range = 46.0
		sl.spot_angle = 34.0
		sl.spot_attenuation = 0.72
		sl.light_energy = 5.5
		sl.light_color = Color("#fff4dc")
		sl.shadow_enabled = false
		sl.visible = false
		add_child(sl)
		spots.append(sl)
	_head_fill = OmniLight3D.new()
	_head_fill.position = model_xf * Vector3(1.9, 0.5, cz)
	_head_fill.omni_range = 4.5
	_head_fill.light_energy = 1.2
	_head_fill.light_color = Color("#fff8e7")
	_head_fill.visible = false
	add_child(_head_fill)
	_make_audio()
	# --- emergency lights and siren
	_amb_bar_mat = StandardMaterial3D.new()
	_amb_bar_mat.albedo_color = Color(0.3, 0.05, 0.05)
	_amb_bar_mat.emission_enabled = true
	_amb_bar_mat.emission = Color(1.0, 0.1, 0.08)
	_amb_bar_mat.emission_energy_multiplier = 0.0
	for k in range(2):
		var ol := OmniLight3D.new()
		ol.omni_range = 13.0
		ol.light_energy = 4.0
		ol.light_color = Color(1.0, 0.1, 0.08) if k == 0 else Color(0.1, 0.3, 1.0)
		ol.position = model_xf * Vector3(-0.24, 1.75, cz + (-0.35 if k == 0 else 0.35))
		ol.visible = false
		ol.shadow_enabled = false
		add_child(ol)
		_amb_lights.append(ol)
	_siren = AudioStreamPlayer3D.new()
	var st := load("res://assets/audio/oga/sirens-and-alarm-noise/siren.mp3") as AudioStream
	if st is AudioStreamMP3: (st as AudioStreamMP3).loop = true
	_siren.stream = st
	_siren.max_distance = 140.0
	_siren.unit_size = 14.0
	_siren.volume_db = -4.0
	add_child(_siren)

## The Sprinter ambulance (Rettungswagen). Wheels become physics wheels; the two cab doors are clipped out of the body (with
## their glass) and hinge at their front edge; the rear leaves and the small side door are the model's own parts. The roof
## lights flash with the siren, and the head and tail lamps are lenses set into the body, so the light comes from the van.
## The model is in centimetres, nose on -X, steering wheel on its +Z side (which becomes the car's +X).
const AMB_FILE := "res://assets/town/rettungswagen__krankenwagen___ambulance.glb"
const AMB_DOOR_X0 := -243.0
const AMB_DOOR_X1 := -127.0
const AMB_DOOR_Y0 := 37.0
const AMB_DOOR_Y1 := 213.0
const AMB_BODY_HALF := 131.0

var _rear_doors: Array = []        # [{pivot, dir}] the two rear leaves and the small side door
var _rear_open := false
var _amb_lamp_mat: StandardMaterial3D = null   # the shell's own tail-lamp triangles, glowing in their painted colours
var _amb_meshes: Array = []        # roof / corner lamp meshes that flash with the siren

func _setup_ambulance() -> void:
	var inst := (load(AMB_FILE) as PackedScene).instantiate() as Node3D
	var tot := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = _xf_rel(mi, inst) * (mi as MeshInstance3D).get_aabb()
		tot = bb if first else tot.merge(bb)
		first = false
	var s: float = float(def.len) / tot.size.x
	model_len = def.len
	model_w = AMB_BODY_HALF * 2.0 * s
	model_h = tot.size.y * s
	mass = def.mass
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.85, 0)
	linear_damp = 0.02
	angular_damp = 3.0
	contact_monitor = true
	max_contacts_reported = 4
	var cx := tot.get_center().x
	var base_y := tot.position.y
	# model -X (nose) -> car +Z, model +Z (driver) -> car +X; the tyres on the ground
	var rot := Basis(Vector3.UP, PI * 0.5)
	var model_xf := Transform3D(rot * Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
	model_xf.origin = rot * Vector3(-cx * s, 0, 0) + Vector3(0, -RIDE - base_y * s, 0)
	# --- wheels: each axle is one mesh, split into its left and right tyre
	var wdata: Array = []
	for nm in ["Sprinter_413_Wheel_Front_*", "Sprinter_413_Wheel_Rear_*"]:
		var wmi := inst.find_child(nm, true, false) as MeshInstance3D
		if wmi == null: continue
		var rel := _xf_rel(wmi, inst)
		var halves := _split_mesh(wmi.mesh, rel, 2)
		wmi.get_parent().remove_child(wmi)
		for h in halves:
			if (h as ArrayMesh).get_surface_count() == 0: continue
			var wb: AABB = rel * (h as ArrayMesh).get_aabb()
			wdata.append({"mesh": h, "rel": rel, "center": model_xf * wb.get_center(), "r": maxf(wb.size.x, wb.size.y) * 0.5 * s})
	# --- cab doors (body and glass clipped to the door outline)
	var door_parts := {-1.0: [], 1.0: []}
	for src_name in ["Front_Body_*", "Glass_Glass_Mat_0"]:
		var src := inst.find_child(src_name, true, false) as MeshInstance3D
		if src == null: continue
		var srel := _xf_rel(src, inst)
		var cut := _cut_cab_doors(src, srel)
		for sd in [-1.0, 1.0]:
			if cut[sd] != null: door_parts[sd].append({"mesh": cut[sd], "rel": srel})
	# --- headlights: the lamp housings in the front body get their own glowing surface
	var fb := inst.find_child("Front_Body_*", true, false) as MeshInstance3D
	if fb != null:
		head_mat = _glow_surface(fb, _xf_rel(fb, inst), [AABB(Vector3(-345, 68, 58), Vector3(29, 37, 44)), AABB(Vector3(-345, 68, -102), Vector3(29, 37, 44))], 14.0, Color(1.0, 0.95, 0.8))
	# --- the painted rear doors on the body shell are cut away, and a plain cargo bay sits behind them
	var shell := inst.find_child("Body_Back2_*", true, false) as MeshInstance3D
	if shell != null:
		_carve_rear_opening(shell, _xf_rel(shell, inst))
		var bay := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(390.0, 180.0, 248.0)
		bay.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.78, 0.8, 0.82)
		bmat.emission_enabled = true
		bmat.emission = Color(0.5, 0.52, 0.55)
		bmat.emission_energy_multiplier = 0.35
		bmat.cull_mode = BaseMaterial3D.CULL_FRONT
		bay.material_override = bmat
		bay.position = Vector3(95.0, 176.0, 0.0)
		bay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.add_child(bay)
	# --- rear leaves and the small left door: real separate parts, hinged on their outer / front edge
	var rear_src := [
		{"node": "DooorBack", "hinge": Vector3(293.5, 0.0, -112.5), "dir": 1.0},
		{"node": "DooorBack1", "hinge": Vector3(293.5, 0.0, 112.5), "dir": -1.0},
		{"node": "Door", "hinge": Vector3(188.0, 0.0, -134.0), "dir": 1.0},
		{"node": "Door_Large", "hinge": Vector3(-21.0, 0.0, -133.0), "dir": 0.0, "slide": Vector3(137.0, 0.0, -9.0)},
	]
	var rear_data: Array = []
	for rs in rear_src:
		var rn := inst.find_child(rs.node, true, false)
		if rn == null: continue
		var items: Array = []
		for mi in rn.find_children("*", "MeshInstance3D", true, false):
			items.append({"mi": mi, "rel": _xf_rel(mi, inst)})
			mi.get_parent().remove_child(mi)
		# the rear windows and handles are separate pieces on the shell: they ride on the leaf on their side
		if rs.node != "Door":
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				if not (String(mi.name).begins_with("Window_") or String(mi.name).begins_with("Opener_")): continue
				var rl := _xf_rel(mi, inst)
				var cb: Vector3 = rl * (mi as MeshInstance3D).get_aabb().get_center()
				var mine := false
				if rs.node == "Door_Large": mine = cb.x > -95.0 and cb.x < 50.0 and cb.z < -120.0
				else: mine = cb.x > 280.0 and (cb.z < 0.0) == (float(rs.dir) > 0.0)
				if mine:
					items.append({"mi": mi, "rel": rl})
					mi.get_parent().remove_child(mi)
		rear_data.append({"items": items, "hinge": rs.hinge, "dir": rs.dir, "slide": rs.get("slide", Vector3.ZERO)})
	# --- lamps that flash with the siren
	for pat in ["TopLight_*", "BackSirene_*", "pCube16_*"]:
		for mi in inst.find_children(pat, "MeshInstance3D", true, false):
			_amb_meshes.append(mi)
	# --- tail lamps: the two lamp plates on the rear are separate meshes; they glow in their own painted colours
	for pat in ["pCube45_*", "pCube40_*"]:
		for mi in inst.find_children(pat, "MeshInstance3D", true, false):
			var bm0 := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
			if bm0 == null: continue
			if _amb_lamp_mat == null:
				_amb_lamp_mat = bm0.duplicate() as StandardMaterial3D
				_amb_lamp_mat.emission_enabled = true
				_amb_lamp_mat.emission = Color(0.4, 0.03, 0.02)
				_amb_lamp_mat.emission_texture = _amb_lamp_mat.albedo_texture
				_amb_lamp_mat.emission_energy_multiplier = 0.0
			(mi as MeshInstance3D).material_override = _amb_lamp_mat
	inst.transform = model_xf
	add_child(inst)
	# --- physics wheels
	wdata.sort_custom(func(a, b): return a.center.z > b.center.z)
	for i in range(wdata.size()):
		var wd: Dictionary = wdata[i]
		var c: Vector3 = wd.center
		var front := i < 2
		var w := VehicleWheel3D.new()
		w.position = c + Vector3(0, 0.14, 0)
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = wd.r
		w.wheel_rest_length = 0.26
		w.suspension_travel = 0.28
		w.suspension_stiffness = 55.0
		w.suspension_max_force = 20000.0
		w.damping_compression = 4.0
		w.damping_relaxation = 5.0
		w.wheel_friction_slip = 3.4
		w.wheel_roll_influence = 1.0
		add_child(w)
		wheels.append(w)
		var m := MeshInstance3D.new()
		m.mesh = wd.mesh
		w.add_child(m)
		m.transform = Transform3D(Basis(), -c) * model_xf * (wd.rel as Transform3D)
	# --- cab door pivots (hinge on the front edge, at the outer skin)
	for sd in [-1.0, 1.0]:
		if door_parts[sd].is_empty(): continue
		var pp: Vector3 = model_xf * Vector3(AMB_DOOR_X0, 120.0, sd * AMB_BODY_HALF)
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = pp
		for dp in door_parts[sd]:
			var dmi := MeshInstance3D.new()
			dmi.mesh = dp.mesh
			pivot.add_child(dmi)
			dmi.transform = Transform3D(Basis(), -pp) * model_xf * (dp.rel as Transform3D)
		if sd > 0.0: door_fl = pivot
		else: door_fr = pivot
	for rd in rear_data:
		var rp: Vector3 = model_xf * (rd.hinge as Vector3)
		var rpivot := Node3D.new()
		add_child(rpivot)
		rpivot.position = rp
		for it in rd.items:
			var rmi: MeshInstance3D = it.mi
			rpivot.add_child(rmi)
			rmi.transform = Transform3D(Basis(), -rp) * model_xf * (it.rel as Transform3D)
		_rear_doors.append({"pivot": rpivot, "dir": rd.dir, "base": rpivot.position, "slide": model_xf.basis * (rd.slide as Vector3)})
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(model_w * 0.92, model_h * 0.66, model_len * 0.97)
	cs.shape = box
	cs.position = Vector3(0, -RIDE + model_h * 0.36 + 0.3, 0)
	add_child(cs)
	_make_amb_lamps(model_xf)
	_make_audio()
	# --- emergency lights and siren
	_amb_bar_mat = StandardMaterial3D.new()
	_amb_bar_mat.albedo_color = Color(0.3, 0.05, 0.05)
	_amb_bar_mat.emission_enabled = true
	_amb_bar_mat.emission = Color(1.0, 0.1, 0.08)
	_amb_bar_mat.emission_energy_multiplier = 0.0
	for k in range(4):
		var ol := OmniLight3D.new()
		ol.omni_range = 14.0
		ol.light_energy = 4.5
		ol.light_color = Color(1.0, 0.1, 0.08) if k % 2 == 0 else Color(0.1, 0.3, 1.0)
		var mp := Vector3(-121.0, 305.0, (-45.0 if k % 2 == 0 else 45.0)) if k < 2 else Vector3(303.0, 305.0, (-119.0 if k % 2 == 0 else 119.0))
		ol.position = model_xf * mp
		ol.visible = false
		ol.shadow_enabled = false
		add_child(ol)
		_amb_lights.append(ol)
	_siren = AudioStreamPlayer3D.new()
	var st := load("res://assets/audio/oga/sirens-and-alarm-noise/siren.mp3") as AudioStream
	if st is AudioStreamMP3: (st as AudioStreamMP3).loop = true
	_siren.stream = st
	_siren.max_distance = 160.0
	_siren.unit_size = 16.0
	_siren.volume_db = -3.0
	add_child(_siren)

## Head and tail lamps for the ambulance: thin lenses sitting flush in the headlight / taillight positions of the body, with the
## spotlights starting at the headlights and the red glow at the tail, like the base car. Positions are in model cm.
func _make_amb_lamps(model_xf: Transform3D) -> void:
	if head_mat == null:
		head_mat = StandardMaterial3D.new()
	tail_mat = _amb_lamp_mat
	if tail_mat == null:
		tail_mat = StandardMaterial3D.new()
	for sd in [-1.0, 1.0]:
		var hp: Vector3 = model_xf * Vector3(-333.0, 90.0, sd * 78.0)
		var sl := SpotLight3D.new()
		sl.position = hp - Vector3(0, 0, 0.3)
		sl.rotation = Vector3(-0.07, PI, 0)
		sl.spot_range = 46.0
		sl.spot_angle = 34.0
		sl.spot_attenuation = 0.72
		sl.light_energy = 5.5
		sl.light_color = Color("#fff4dc")
		sl.shadow_enabled = false
		sl.visible = false
		add_child(sl)
		spots.append(sl)
	_head_fill = OmniLight3D.new()
	_head_fill.position = model_xf * Vector3(-300.0, 60.0, 0.0)
	_head_fill.omni_range = 4.5
	_head_fill.omni_attenuation = 1.0
	_head_fill.light_energy = 1.2
	_head_fill.light_color = Color("#fff8e7")
	_head_fill.visible = false
	add_child(_head_fill)
	# no red wash light: the tail lamps on the body glow on their own

## Opens / closes the two rear leaves and the small left door (Y while driving the ambulance).
func toggle_rear_doors() -> void:
	_rear_open = not _rear_open
	for rd in _rear_doors:
		var tw := create_tween()
		if (rd.slide as Vector3) != Vector3.ZERO:
			tw.tween_property(rd.pivot, "position", (rd.base as Vector3) + (rd.slide as Vector3) if _rear_open else rd.base, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(rd.pivot, "rotation:y", float(rd.dir) * 1.75 if _rear_open else 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_play_door_sound("res://assets/audio/vehicles/door_open_01.ogg" if _rear_open else "res://assets/audio/vehicles/door_close_01.ogg")

## Splits a mesh into two (centroid on either side of zero along axis, after xf into model space). Vertices stay in the mesh's own space.
static func _split_mesh(mesh: Mesh, xf: Transform3D, axis: int) -> Array:
	var outs: Array = [ArrayMesh.new(), ArrayMesh.new()]
	for si in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn = arr[Mesh.ARRAY_NORMAL]
		var uu = arr[Mesh.ARRAY_TEX_UV]
		var ids: PackedInt32Array = PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			ids = arr[Mesh.ARRAY_INDEX]
		else:
			ids.resize(v.size())
			for i in range(v.size()): ids[i] = i
		var parts: Array = [DoorSlicer._new_out(), DoorSlicer._new_out()]
		for t in range(ids.size() / 3):
			var cen := Vector3.ZERO
			for k in range(3): cen += xf * v[ids[t * 3 + k]]
			var o: Dictionary = parts[0 if cen[axis] < 0.0 else 1]
			for k in range(3):
				var i := ids[t * 3 + k]
				(o.v as Array).append(v[i])
				(o.n as Array).append(nn[i] if nn != null else Vector3.UP)
				(o.uv as Array).append(uu[i] if uu != null else Vector2.ZERO)
		for k in range(2):
			var o2: Dictionary = parts[k]
			if (o2.v as Array).is_empty(): continue
			var a2 := []
			a2.resize(Mesh.ARRAY_MAX)
			a2[Mesh.ARRAY_VERTEX] = PackedVector3Array(o2.v)
			a2[Mesh.ARRAY_NORMAL] = PackedVector3Array(o2.n)
			a2[Mesh.ARRAY_TEX_UV] = PackedVector2Array(o2.uv)
			var target: ArrayMesh = outs[k]
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			target.surface_set_material(target.get_surface_count() - 1, mesh.surface_get_material(si))
	return outs

## Gives the small triangles of a mesh that lie inside the given boxes (model space) a surface of their own, with a copy of the
## material that can glow (its texture is used as the emission, so the lamp keeps its painted look). Returns that material.
func _glow_surface(body: MeshInstance3D, xf: Transform3D, boxes: Array, max_size: float, tint: Color, reuse: StandardMaterial3D = null) -> StandardMaterial3D:
	var inv := xf.affine_inverse()
	var remainder := ArrayMesh.new()
	var glow_mat: StandardMaterial3D = null
	for si in range(body.mesh.get_surface_count()):
		var arr: Array = body.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn = arr[Mesh.ARRAY_NORMAL]
		var uu = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		else:
			idx.resize(v.size())
			for i in range(v.size()): idx[i] = i
		var o := DoorSlicer._new_out()
		var og := DoorSlicer._new_out()
		for t in range(idx.size() / 3):
			var poly: Array = []
			var cen := Vector3.ZERO
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := Vector3(-1e9, -1e9, -1e9)
			for k in range(3):
				var i := idx[t * 3 + k]
				var pm := xf * v[i]
				cen += pm
				lo = lo.min(pm)
				hi = hi.max(pm)
				poly.append({"p": pm, "uv": (uu[i] if uu != null else Vector2.ZERO), "n": (nn[i] if nn != null else Vector3.UP)})
			cen /= 3.0
			var glow := false
			if (hi - lo).length() < max_size:
				for bx in boxes:
					if (bx as AABB).has_point(cen): glow = true
			DoorSlicer._emit(poly, og if glow else o)
		var mat := body.mesh.surface_get_material(si)
		for part in [o, og]:
			if (part.v as Array).is_empty(): continue
			var vs := PackedVector3Array(part.v)
			for i in range(vs.size()): vs[i] = inv * vs[i]
			var a2 := []
			a2.resize(Mesh.ARRAY_MAX)
			a2[Mesh.ARRAY_VERTEX] = vs
			a2[Mesh.ARRAY_NORMAL] = PackedVector3Array(part.n)
			a2[Mesh.ARRAY_TEX_UV] = PackedVector2Array(part.uv)
			remainder.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			if part == og and mat is StandardMaterial3D:
				if reuse != null:
					glow_mat = reuse
				else:
					glow_mat = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					glow_mat.emission_enabled = true
					glow_mat.emission = tint
					glow_mat.emission_texture = glow_mat.albedo_texture
					glow_mat.emission_energy_multiplier = 0.0
				remainder.surface_set_material(remainder.get_surface_count() - 1, glow_mat)
			else:
				remainder.surface_set_material(remainder.get_surface_count() - 1, mat)
	body.mesh = remainder
	return glow_mat

## Removes the door areas painted on the shell (rear doors, the sliding door and the small door on the left side), so the opened
## doors show the cargo bay instead of the same door again. Each region: the face it is on and the box (clip planes) to cut out.
func _carve_rear_opening(body: MeshInstance3D, xf: Transform3D) -> void:
	var inv := xf.affine_inverse()
	var regions := [
		{"face": 0, "sgn": 1.0, "at": 284.0, "planes": [[2, -111.5, 1.0], [2, 111.5, -1.0], [1, 86.0, 1.0], [1, 272.0, -1.0]]},
		{"face": 2, "sgn": -1.0, "at": 123.0, "planes": [[0, -90.0, 1.0], [0, 47.0, -1.0], [1, 86.0, 1.0], [1, 272.0, -1.0]]},
		{"face": 2, "sgn": -1.0, "at": 123.0, "planes": [[0, 188.0, 1.0], [0, 272.0, -1.0], [1, 86.0, 1.0], [1, 272.0, -1.0]]},
	]
	var remainder := ArrayMesh.new()
	for si in range(body.mesh.get_surface_count()):
		var arr: Array = body.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn = arr[Mesh.ARRAY_NORMAL]
		var uu = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		else:
			idx.resize(v.size())
			for i in range(v.size()): idx[i] = i
		var o := DoorSlicer._new_out()
		for t in range(idx.size() / 3):
			var poly: Array = []
			for k in range(3):
				var i := idx[t * 3 + k]
				poly.append({"p": xf * v[i], "uv": (uu[i] if uu != null else Vector2.ZERO), "n": (nn[i] if nn != null else Vector3.UP)})
			var pieces: Array = [poly]
			for rg in regions:
				var next: Array = []
				for pc in pieces:
					var near := true
					for vv in pc:
						var pv: float = (vv.p as Vector3)[rg.face]
						if (float(rg.sgn) > 0.0 and pv < float(rg.at)) or (float(rg.sgn) < 0.0 and pv > -float(rg.at)): near = false
					if not near:
						next.append(pc)
						continue
					var cur: Array = pc
					for plane in rg.planes:
						if cur.size() < 3: break
						var sp: Array = DoorSlicer._split(cur, plane[0], plane[1], plane[2])
						if (sp[1] as Array).size() >= 3: next.append(sp[1])
						cur = sp[0]
				pieces = next
			for pc in pieces:
				DoorSlicer._emit(pc, o)
		if (o.v as Array).is_empty(): continue
		var vs := PackedVector3Array(o.v)
		for i in range(vs.size()): vs[i] = inv * vs[i]
		var a2 := []
		a2.resize(Mesh.ARRAY_MAX)
		a2[Mesh.ARRAY_VERTEX] = vs
		a2[Mesh.ARRAY_NORMAL] = PackedVector3Array(o.n)
		a2[Mesh.ARRAY_TEX_UV] = PackedVector2Array(o.uv)
		remainder.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		remainder.surface_set_material(remainder.get_surface_count() - 1, body.mesh.surface_get_material(si))
	body.mesh = remainder

## Clips the cab doors out of a body / glass mesh. Side-panel triangles are cut to the door outline (UVs and normals
## interpolated, so the texture lines up) and the mesh keeps the rest. Returns {-1.0: door mesh or null, 1.0: ...} in the
## mesh's own space; the sign is the model-z side. xf is the mesh's transform into the model's space.
func _cut_cab_doors(body: MeshInstance3D, xf: Transform3D, box := {}) -> Dictionary:
	var bx0: float = float(box.get("x0", AMB_DOOR_X0))
	var bx1: float = float(box.get("x1", AMB_DOOR_X1))
	var by0: float = float(box.get("y0", AMB_DOOR_Y0))
	var by1: float = float(box.get("y1", AMB_DOOR_Y1))
	var bcz: float = float(box.get("cz", 0.0))
	var bzt: float = float(box.get("zt", 90.0))
	var inv := xf.affine_inverse()
	var out := {-1.0: null, 1.0: null}
	var remainder := ArrayMesh.new()
	var door_meshes := {-1.0: ArrayMesh.new(), 1.0: ArrayMesh.new()}
	for si in range(body.mesh.get_surface_count()):
		var arr: Array = body.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn = arr[Mesh.ARRAY_NORMAL]
		var uu = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		else:
			idx.resize(v.size())
			for i in range(v.size()): idx[i] = i
		var outs := {0.0: DoorSlicer._new_out(), -1.0: DoorSlicer._new_out(), 1.0: DoorSlicer._new_out()}
		for t in range(idx.size() / 3):
			var poly: Array = []
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := Vector3(-1e9, -1e9, -1e9)
			var zmin := 1e9
			var zmax := -1e9
			for k in range(3):
				var i := idx[t * 3 + k]
				var pm := xf * v[i]
				lo = lo.min(pm)
				hi = hi.max(pm)
				zmin = minf(zmin, pm.z)
				zmax = maxf(zmax, pm.z)
				poly.append({"p": pm, "uv": (uu[i] if uu != null else Vector2.ZERO), "n": (nn[i] if nn != null else Vector3.UP)})
			var sd := 0.0
			var on_side := (zmin - bcz > bzt) or (zmax - bcz < -bzt)
			if on_side and hi.x > bx0 and lo.x < bx1 and hi.y > by0 and lo.y < by1:
				sd = 1.0 if zmin - bcz > bzt else -1.0
			if sd == 0.0:
				DoorSlicer._emit(poly, outs[0.0])
				continue
			var cur: Array = poly
			for plane in [[0, bx0, 1.0], [0, bx1, -1.0], [1, by0, 1.0], [1, by1, -1.0]]:
				if cur.size() < 3: break
				var sp: Array = DoorSlicer._split(cur, plane[0], plane[1], plane[2])
				DoorSlicer._emit(sp[1], outs[0.0])
				cur = sp[0]
			if cur.size() >= 3:
				DoorSlicer._emit(cur, outs[sd])
		var mat := body.mesh.surface_get_material(si)
		for key in [0.0, -1.0, 1.0]:
			var o: Dictionary = outs[key]
			if (o.v as Array).is_empty(): continue
			var vs := PackedVector3Array(o.v)
			for i in range(vs.size()): vs[i] = inv * vs[i]
			var a2 := []
			a2.resize(Mesh.ARRAY_MAX)
			a2[Mesh.ARRAY_VERTEX] = vs
			a2[Mesh.ARRAY_NORMAL] = PackedVector3Array(o.n)
			a2[Mesh.ARRAY_TEX_UV] = PackedVector2Array(o.uv)
			var target: ArrayMesh = remainder if key == 0.0 else door_meshes[key]
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			target.surface_set_material(target.get_surface_count() - 1, mat)
	body.mesh = remainder
	for sd in [-1.0, 1.0]:
		var dm: ArrayMesh = door_meshes[sd]
		out[sd] = dm if dm.get_surface_count() > 0 else null
	return out

## The Fumi comes with its four tyres and rims merged into a few meshes. Cut those by quadrant into four wheel groups
## named like the Karoq's so the same wheel rig applies; the model's own nose is -Z, same as the Karoq.
func _prepare_fumi() -> Node3D:
	var inst := (load("res://assets/vehicles/main/fumi.glb") as PackedScene).instantiate() as Node3D
	for n in inst.find_children("*", "", true, false):
		n.owner = null
	inst.owner = null
	var groups: Array = []
	for i in range(4):
		var g := Node3D.new()
		g.name = ["wheel", "wheel_001", "wheel_002", "wheel_003"][i]
		groups.append(g)
	var to_free: Array = []
	# 1) the four wheel centres, from the tyre meshes alone (the rim/brake meshes carry stray parts)
	var tsum := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var tcnt := [0, 0, 0, 0]
	var tb := AABB()
	var tfirst := true
	var wheel_meshes: Array = []
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nm := (String(m.name) + String(m.get_parent().name)).to_lower()
		if not ("wheel" in nm or "tire" in nm): continue
		var bb: AABB = _xf_rel(m, inst) * m.get_aabb()
		if bb.size.z < 2.5 or bb.size.y > 0.9: continue
		wheel_meshes.append(m)
		if "tire" in nm:
			tb = bb if tfirst else tb.merge(bb)
			tfirst = false
	var tctr := tb.get_center()
	for m in wheel_meshes:
		var nm2 := (String(m.name) + String(m.get_parent().name)).to_lower()
		if not "tire" in nm2: continue
		var xf2 := _xf_rel(m, inst)
		var arr2: Array = (m as MeshInstance3D).mesh.surface_get_arrays(0)
		var v2: PackedVector3Array = arr2[Mesh.ARRAY_VERTEX]
		for i in range(0, v2.size(), 3):
			var c2 := xf2 * v2[i]
			var q2 := (0 if c2.x < tctr.x else 1) + (0 if c2.z < tctr.z else 2)
			tsum[q2] += c2
			tcnt[q2] += 1
	var centers: Array = []
	for q in range(4):
		centers.append(tsum[q] / maxf(tcnt[q], 1))
	# 2) every wheel-related triangle goes to the nearest wheel; strays stay on the body
	var rest_parts: Array = []
	for m in wheel_meshes:
		var xf := _xf_rel(m, inst)
		for si in range(m.mesh.get_surface_count()):
			var arr: Array = m.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in range(v.size()): idx[i] = i
			var parts: Array = [[], [], [], [], []]
			for t in range(idx.size() / 3):
				var c := (xf * v[idx[t * 3]] + xf * v[idx[t * 3 + 1]] + xf * v[idx[t * 3 + 2]]) / 3.0
				var best := 4
				var bd := 0.55
				for q in range(4):
					var d: float = (c - (centers[q] as Vector3)).length()
					if d < bd:
						bd = d
						best = q
				for k in range(3): (parts[best] as Array).append(idx[t * 3 + k])
			var nb := PackedVector3Array()
			nb.resize(v.size())
			for i in range(v.size()): nb[i] = xf * v[i]
			var src_uv = arr[Mesh.ARRAY_TEX_UV]
			var src_n = arr[Mesh.ARRAY_NORMAL]
			for q in range(5):
				var plist: Array = parts[q]
				if plist.is_empty(): continue
				var remap := {}
				var pv := PackedVector3Array()
				var pu := PackedVector2Array()
				var pn := PackedVector3Array()
				var pi := PackedInt32Array()
				for old in plist:
					if not remap.has(old):
						remap[old] = pv.size()
						pv.append(nb[old])
						if src_uv != null: pu.append((src_uv as PackedVector2Array)[old])
						if src_n != null: pn.append((xf.basis * (src_n as PackedVector3Array)[old]).normalized())
					pi.append(remap[old])
				var a := []
				a.resize(Mesh.ARRAY_MAX)
				a[Mesh.ARRAY_VERTEX] = pv
				if src_uv != null: a[Mesh.ARRAY_TEX_UV] = pu
				if src_n != null: a[Mesh.ARRAY_NORMAL] = pn
				a[Mesh.ARRAY_INDEX] = pi
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
				am.surface_set_material(0, m.mesh.surface_get_material(si))
				var ni := MeshInstance3D.new()
				ni.mesh = am
				if q < 4: (groups[q] as Node3D).add_child(ni)
				else: inst.add_child(ni)
		to_free.append(m)
	for m in to_free:
		m.get_parent().remove_child(m)
		m.free()
	for g in groups: inst.add_child(g)
	# doors: the model splits its door parts by kind, not by side; gather each side's parts under a hinge at the
	# door's front edge (the model's left is -X, its nose -Z)
	var side_parts := {"lf": [], "rf": []}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var pn := String(m.get_parent().name).to_lower()
		if not pn.begins_with("door") or "window" in pn: continue
		var b: AABB = _xf_rel(m, inst) * m.get_aabb()
		if absf(b.get_center().x) < 0.3 or b.size.z > 2.0: continue
		side_parts["lf" if b.get_center().x > 0.0 else "rf"].append(m)
	for key in side_parts:
		var list: Array = side_parts[key]
		if list.is_empty(): continue
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for m in list:
			var b2: AABB = _xf_rel(m, inst) * (m as MeshInstance3D).get_aabb()
			lo = lo.min(b2.position); hi = hi.max(b2.end)
		var hinge := Vector3(lo.x if key == "rf" else hi.x, (lo.y + hi.y) * 0.5, hi.z)
		hinge.x = (lo.x + hi.x) * 0.5
		var dummy := Node3D.new()
		dummy.name = "door_%s_dummy" % key
		inst.add_child(dummy)
		dummy.position = hinge
		for m in list:
			var rel := _xf_rel(m, inst)
			m.get_parent().remove_child(m)
			m.owner = null
			dummy.add_child(m)
			m.transform = Transform3D(Basis(), -hinge) * rel
	# this model's nose points +Z; the rig expects -Z (like the Karoq), so turn the whole body round once
	var fix := Node3D.new()
	fix.rotation.y = PI
	for ch in inst.get_children():
		inst.remove_child(ch)
		ch.owner = null
		fix.add_child(ch)
	inst.add_child(fix)
	return inst

## Parked cars rest on their suspension with the brake held and go to sleep by themselves. They are never frozen:
## unfreezing a VehicleBody3D that was frozen after simulating corrupts its wheel state (NaN) when the player gets in.
func _settle_then_freeze() -> void:
	brake = HANDBRAKE_FORCE


## Cuts hinged doors out of the single-mesh body (front pair, plus a rear pair on four-door cars)
## and builds a simple dark interior so the open doorway is not see-through.
func _apply_glb_shell(inst: Node3D) -> void:
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var sm := (mi as MeshInstance3D).get_active_material(0)
		if sm is BaseMaterial3D and (sm as BaseMaterial3D).albedo_texture != null:
			_apply_shell(inst, (sm as BaseMaterial3D).albedo_texture)
			return

## A wing mirror in metres: arm, housing and a reflective glass plate, angled outward and back.
## side is +1 for the left (+X) mirror, -1 for the right.
static func make_mirror(side: float) -> Node3D:
	var root := Node3D.new()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	dark.roughness = 0.6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.82, 0.88, 0.95)
	glass.metallic = 0.35
	glass.roughness = 0.12
	glass.emission_enabled = true
	glass.emission = Color(0.55, 0.65, 0.78)
	glass.emission_energy_multiplier = 0.9
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.14, 0.03, 0.035)
	arm.mesh = am
	arm.material_override = dark
	arm.position = Vector3(side * 0.07, 0.0, 0.0)
	root.add_child(arm)
	# the head is tilted: turned out about 25 degrees and leaned back about 12
	var head := Node3D.new()
	head.position = Vector3(side * 0.15, 0.02, 0.0)
	head.rotation = Vector3(deg_to_rad(-12.0), side * deg_to_rad(25.0), 0.0)
	root.add_child(head)
	var housing := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.035, 0.12, 0.2)
	housing.mesh = hm
	housing.material_override = dark
	head.add_child(housing)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.01, 0.1, 0.17)
	plate.mesh = pm
	plate.material_override = glass
	plate.position = Vector3(-side * 0.02, 0.0, 0.0)
	head.add_child(plate)
	for mi in [arm, housing, plate]:
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

func _shell_material(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/car_body.gdshader") as Shader
	m.set_shader_parameter("albedo_tex", tex)
	return m

## Swap the baked-in glass on a body part for see-through windows (wheels keep their normal material).
func _apply_shell(root: Node, tex: Texture2D) -> void:
	var m := _shell_material(tex)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if "wheel" in String(mi.name).to_lower(): continue
		(mi as MeshInstance3D).material_override = m

func _make_doors(mi: MeshInstance3D, mesh: Mesh, bb: AABB, s: float) -> void:
	var c := bb.get_center()
	var zf := model_len * 0.31
	var zr := -model_len * 0.30
	if def.get("wheel", false):
		zf = 1.29 * s
		zr = -1.12 * s
	var z_h := zf - 0.55
	var z_b := maxf(zr + 0.55, z_h - 1.25)
	var specs: Array = [[z_h, z_b, "f"]]
	if def.get("rear", false):
		var z_h2 := z_b - 0.04
		specs.append([z_h2, maxf(zr + 0.2, z_h2 - 1.0), "r"])
	var y_min_l := bb.position.y + bb.size.y * 0.33
	var x_min_l := bb.size.x * 0.5 * 0.5
	var src: Mesh = mesh
	var cut := false
	for sp in specs:
		var zh_l: float = float(sp[0]) / s + c.z          # car space -> mesh space
		var zb_l: float = float(sp[1]) / s + c.z
		for side in [1.0, -1.0]:
			var r := DoorSlicer.slice(src, side, zh_l, zb_l, y_min_l, x_min_l)
			var door_mesh: ArrayMesh = r.door
			if door_mesh.get_surface_count() == 0:
				continue
			src = r.body
			cut = true
			var pivot := Node3D.new()
			pivot.position = r.pivot
			var dm := MeshInstance3D.new()
			dm.mesh = door_mesh
			dm.material_override = mi.material_override
			pivot.add_child(dm)
			mi.add_child(pivot)
			if sp[2] == "f":
				# tilted wing mirror, riding on the door
				var mir := Car.make_mirror(side)
				mir.scale = Vector3.ONE / s
				mir.position = Vector3(side * 0.03 / s, bb.position.y + bb.size.y * 0.64, -0.12 / s)
				pivot.add_child(mir)
				if side > 0.0: door_fl = pivot
				else: door_fr = pivot
			else:
				if side > 0.0: door_rl = pivot
				else: door_rr = pivot
	if not cut:
		return
	mi.mesh = src
	var zl: float = zf - 0.55 + 0.4
	var z_front_l := zl / s + c.z
	var z_rear_l := (zr + 0.2) / s + c.z
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.09, 0.10)
	dark.roughness = 1.0
	var seat_mat := StandardMaterial3D.new()
	seat_mat.albedo_color = Color(0.20, 0.17, 0.14)
	seat_mat.roughness = 1.0
	var w := bb.size.x
	var floor_y := bb.position.y + bb.size.y * 0.30
	_cab_box(mi, dark, Vector3(w * 0.80, bb.size.y * 0.02, z_front_l - z_rear_l), Vector3(c.x, floor_y, (z_front_l + z_rear_l) * 0.5))
	var seat_z := (z_h - 0.15) / s + c.z - 0.35 / s
	for sx in [-1.0, 1.0]:
		_cab_box(mi, seat_mat, Vector3(w * 0.26, bb.size.y * 0.06, 0.55 / s), Vector3(c.x + sx * w * 0.2, floor_y + bb.size.y * 0.07, seat_z))
		_cab_box(mi, seat_mat, Vector3(w * 0.26, bb.size.y * 0.26, 0.12 / s), Vector3(c.x + sx * w * 0.2, floor_y + bb.size.y * 0.2, seat_z - 0.3 / s))
	if def.get("rear", false):
		_cab_box(mi, seat_mat, Vector3(w * 0.7, bb.size.y * 0.06, 0.55 / s), Vector3(c.x, floor_y + bb.size.y * 0.07, seat_z - 1.25 / s))
		_cab_box(mi, seat_mat, Vector3(w * 0.7, bb.size.y * 0.24, 0.12 / s), Vector3(c.x, floor_y + bb.size.y * 0.19, seat_z - 1.55 / s))
	_cab_box(mi, dark, Vector3(w * 0.8, bb.size.y * 0.12, 0.3 / s), Vector3(c.x, floor_y + bb.size.y * 0.14, z_front_l - 0.1 / s))

func _cab_box(mi: MeshInstance3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(m)

func _make_wheels_glb(inst: Node3D) -> void:
	var wheel_src: MeshInstance3D = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var n: String = mi.name.to_lower()
		if "wheel" in n or "roda" in n:
			wheel_src = mi as MeshInstance3D
			break
	if wheel_src != null:
		wheel_src.visible = false

	var xs := 0.82
	var zf := 1.40
	var zr := -1.35
	for i in range(4):
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var w := VehicleWheel3D.new()
		w.position = Vector3(side * xs, -0.12, zf if front else zr)
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = WHEEL_R
		w.wheel_rest_length = 0.24
		w.suspension_travel = 0.26
		w.suspension_stiffness = 38.0
		w.suspension_max_force = 18000.0
		w.damping_compression = 2.3
		w.damping_relaxation = 2.9
		w.wheel_friction_slip = 3.6 if front else 3.4
		w.wheel_roll_influence = 0.25
		add_child(w)
		wheels.append(w)

		if wheel_src != null and wheel_src.mesh != null:
			var wm := MeshInstance3D.new()
			wm.mesh = wheel_src.mesh
			if wheel_src.material_override != null:
				wm.material_override = wheel_src.material_override
			if side > 0.0:
				wm.rotation.y = PI
			w.add_child(wm)
		else:
			var wm := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = WHEEL_R
			cyl.bottom_radius = WHEEL_R
			cyl.height = 0.22
			wm.mesh = cyl
			wm.rotation.z = PI / 2.0
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.12, 0.12, 0.14)
			mat.roughness = 0.8
			wm.material_override = mat
			w.add_child(wm)

func _make_wheels(s: float) -> void:
	var xs := model_w * 0.5 - 0.22
	var zf := model_len * 0.31
	var zr := -model_len * 0.30
	if def.get("wheel", false):
		zf = 1.29 * s
		zr = -1.12 * s
		xs = 0.74 * s
	var bb := (load(ASSET + def.dir + def.obj) as Mesh).get_aabb()
	var bc := bb.get_center()
	for i in range(4):
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var w := VehicleWheel3D.new()
		w.position = Vector3(side * xs, -0.12, zf if front else zr)
		# line the axle up with the wheel baked into the model, and pick that wheel's mesh
		var baked: Dictionary = {}
		for wd in wheel_info.get("wheels", []):
			var c: Vector3 = wd.center
			if (c.x - bc.x) * side > 0.0 and (c.z - bc.z > 0.0) == front:
				baked = wd
		if not baked.is_empty():
			var c2: Vector3 = baked.center
			w.position = Vector3((c2.x - bc.x) * s, -0.12, (c2.z - bc.z) * s)
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = WHEEL_R
		w.wheel_rest_length = 0.24
		w.suspension_travel = 0.26
		w.suspension_stiffness = 38.0
		w.suspension_max_force = 18000.0
		w.damping_compression = 2.3
		w.damping_relaxation = 2.9
		w.wheel_friction_slip = 3.6 if front else 3.4
		w.wheel_roll_influence = 0.25
		add_child(w)
		wheels.append(w)
		if not baked.is_empty():
			var wmi := MeshInstance3D.new()
			wmi.mesh = baked.mesh
			wmi.material_override = body_mat
			wmi.scale = Vector3.ONE * (WHEEL_R / float(baked.radius))
			w.add_child(wmi)
		if def.get("wheel", false):
			var wm := (load(ASSET + "coupe/wheel.glb") as PackedScene).instantiate()
			wm.scale = Vector3.ONE * s
			if side < 0.0:
				wm.rotation.y = PI
			w.add_child(wm)

func _make_lights() -> void:
	head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color("#ffffff")
	head_mat.emission_enabled = true
	head_mat.emission = Color("#fff8ea")
	head_mat.emission_energy_multiplier = 0.0
	head_mat.roughness = 0.15

	tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = Color("#7a0b0b")
	tail_mat.emission_enabled = true
	tail_mat.emission = Color("#ff1010")
	tail_mat.emission_energy_multiplier = 0.0
	tail_mat.roughness = 0.25

	if def.has("fumi"):
		# 1) Connect Fumi's actual car light meshes so the headlights and neon tail bar glow natively
		var f_drl := find_child("light_frontDRLS_lights_0", true, false) as MeshInstance3D
		if f_drl != null:
			f_drl.material_override = head_mat
		var r_neon := find_child("light_rearneons_lights_0", true, false) as MeshInstance3D
		if r_neon != null:
			r_neon.material_override = tail_mat

		for side in [-1.0, 1.0]:
			# Spotlights originating directly from the front headlight glass
			var sl := SpotLight3D.new()
			sl.position = Vector3(side * 0.65, -0.015, 1.88)
			sl.rotation = Vector3(-0.07, PI + side * -0.02, 0)
			sl.spot_range = 48.0
			sl.spot_angle = 36.0
			sl.spot_attenuation = 0.72
			sl.light_energy = 5.5
			sl.light_color = Color("#fff8e7")
			sl.shadow_enabled = false
			sl.visible = false
			add_child(sl)
			spots.append(sl)

		# Forward ambient illumination under front bumper
		_head_fill = OmniLight3D.new()
		_head_fill.position = Vector3(0, -0.05, 1.8)
		_head_fill.omni_range = 4.5
		_head_fill.omni_attenuation = 1.0
		_head_fill.light_energy = 1.2
		_head_fill.light_color = Color("#fff8e7")
		_head_fill.visible = false
		add_child(_head_fill)

		# Rear red ambient glow on road and bumper
		_tail_omni = OmniLight3D.new()
		_tail_omni.position = Vector3(0, 0.16, -2.24)
		_tail_omni.omni_range = 4.0
		_tail_omni.omni_attenuation = 1.2
		_tail_omni.light_color = Color("#ff1e1e")
		_tail_omni.light_energy = 0.0
		_tail_omni.visible = false
		add_child(_tail_omni)
	else:
		var y := -RIDE + model_h * 0.42
		for side in [-1.0, 1.0]:
			var sl := SpotLight3D.new()
			sl.position = Vector3(side * model_w * 0.3, y, model_len * 0.5 - 0.28)
			sl.rotation = Vector3(-0.06, PI, 0)
			sl.spot_range = 40.0
			sl.spot_angle = 32.0
			sl.spot_attenuation = 0.7
			sl.light_energy = 5.0
			sl.light_color = Color("#fff1cf")
			sl.shadow_enabled = false
			sl.visible = false
			add_child(sl)
			spots.append(sl)

		_tail_omni = OmniLight3D.new()
		_tail_omni.position = Vector3(0, y + 0.05, -model_len * 0.5 - 0.05)
		_tail_omni.omni_range = 3.5
		_tail_omni.light_color = Color("#ff1e1e")
		_tail_omni.light_energy = 0.0
		_tail_omni.visible = false
		add_child(_tail_omni)

func _make_audio() -> void:
	_engine_idle = _loop_player("res://assets/audio/vehicles/car_idle_loop.ogg", -8.0)
	_engine_mid = _loop_player("res://assets/audio/vehicles/car_mid_loop.ogg", -80.0)
	_skid = AudioStreamPlayer3D.new()
	_skid.stream = load("res://assets/audio/vehicles/skid_long_01.ogg") as AudioStream
	_skid.volume_db = -4.0
	_skid.max_distance = 60.0
	add_child(_skid)

func _loop_player(path: String, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var st := load(path) as AudioStream
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	p.stream = st
	p.volume_db = db
	p.max_distance = 70.0
	p.unit_size = 8.0
	add_child(p)
	return p

func make_police() -> void:
	ai_chase = true
	remove_from_group("cars")
	add_to_group("police")
	if def.has("emerg"):
		_set_siren(true, false)          # the cruiser's own light bar and siren
		start_engine()
		return
	_siren = AudioStreamPlayer3D.new()
	var st := load("res://assets/audio/oga/sirens-and-alarm-noise/siren.mp3") as AudioStream
	if st is AudioStreamMP3: (st as AudioStreamMP3).loop = true
	_siren.stream = st
	_siren.max_distance = 140.0
	_siren.unit_size = 14.0
	_siren.volume_db = -4.0
	add_child(_siren)
	_siren.play()
	_flash = OmniLight3D.new()
	_flash.omni_range = 12.0
	_flash.light_energy = 3.0
	_flash.position = Vector3(0, -RIDE + model_h + 0.3, 0)
	add_child(_flash)
	start_engine()

func _process(delta: float) -> void:
	if _amb_bar_mat != null:
		_flash_t += delta
		var ph := int(_flash_t * 4.5) % 2
		if siren_on:
			_amb_bar_mat.emission = Color(1.0, 0.1, 0.08) if ph == 0 else Color(0.1, 0.3, 1.0)
			_amb_bar_mat.emission_energy_multiplier = 6.0
			for i in range(_amb_lights.size()): (_amb_lights[i] as OmniLight3D).visible = (i % 2) == ph
		else:
			_amb_bar_mat.emission_energy_multiplier = 0.0
			for l in _amb_lights: (l as OmniLight3D).visible = false
	if _flash != null:
		_flash_t += delta
		var phase := int(_flash_t * 5.0) % 2
		_flash.light_color = Color("#ff2020") if phase == 0 else Color("#2050ff")

func _police_close_and_player_slow() -> bool:
	if Game.dead or Game.wanted == 0 or Game.cop_pool.is_empty(): return false
	var d := global_position.distance_to(Game.get_focus_pos())
	var slow := Game.in_car == null or absf((Game.in_car as Car).speed_ms) < 5.0
	return d < 16.0 and slow and absf(speed_ms) < 9.0

## The patrol car stops and two officers climb out to shoot the player.
func _deploy_cops() -> void:
	ai_chase = false
	engine_force = 0.0
	brake = 40.0
	cops_out.clear()
	if not doors_open: toggle_doors()
	for side in [-1.0, 1.0]:
		var cop := Cop.new()
		get_parent().add_child(cop)
		cop.setup_cop(Game.cop_pool[randi() % Game.cop_pool.size()], self, side)
		cops_out.append(cop)
	_play_door_sound("res://assets/audio/vehicles/door_open_01.ogg")

## While the officers are out: if they are all down, or the player got far away, the car takes up the chase again.
func _cop_watch(delta: float) -> void:
	brake = 40.0
	engine_force = 0.0
	_cop_cd += delta
	if _cop_cd < 2.0: return
	_cop_cd = 0.0
	var alive := 0
	var near := false
	var fp := Game.get_focus_pos()
	for c in cops_out:
		if is_instance_valid(c) and (c as Cop).state != "dead":
			alive += 1
			if (c as Node3D).global_position.distance_to(fp) < 70.0: near = true
	if alive == 0 or not near:
		for c in cops_out:
			if is_instance_valid(c) and (c as Cop).state != "dead": c.queue_free()
		cops_out.clear()
		if doors_open: toggle_doors()
		ai_chase = true

func _freeze_after_settling() -> void:
	await get_tree().create_timer(2.0).timeout
	if parked and not player_controlled:
		sleeping = true

func _wake() -> void:
	freeze = false
	sleeping = false

func forward_dir() -> Vector3:
	return global_transform.basis.z

func set_lights(on: bool) -> void:
	lights_on = on
	for l in head_lamps: l.visible = on
	for s in spots: s.visible = on
	if _head_fill != null: _head_fill.visible = on
	for t in tail_lamps: t.visible = on or braking_now
	if head_mat != null:
		head_mat.emission_energy_multiplier = 4.5 if on else 0.0
	if tail_mat != null:
		tail_mat.emission_energy_multiplier = (7.5 if braking_now else 2.2) if (on or braking_now) else 0.0
	if _tail_omni != null:
		_tail_omni.visible = on or braking_now
		_tail_omni.light_energy = 3.5 if braking_now else (0.9 if on else 0.0)

## Emergency lights and siren (the X key while driving an ambulance).
func toggle_siren() -> void:
	_set_siren(not siren_on, true)

func _set_siren(on: bool, announce: bool) -> void:
	siren_on = on
	for m in _amb_meshes: (m as MeshInstance3D).material_override = _amb_bar_mat if siren_on else null
	if _siren != null:
		if siren_on: _siren.play()
		else: _siren.stop()
	if announce: Game.message.emit("Siren on" if siren_on else "Siren off")

func start_engine() -> void:
	if _engine_idle != null and not _engine_idle.playing: _engine_idle.play()
	if _engine_mid != null and not _engine_mid.playing: _engine_mid.play()

func stop_engine() -> void:
	if _engine_idle != null: _engine_idle.stop()
	if _engine_mid != null: _engine_mid.stop()

func _physics_process(delta: float) -> void:
	if def.is_empty() or tail_mat == null or _engine_idle == null:
		return
	if freeze:
		return
	if is_in_group("police") and not cops_out.is_empty() and not ai_chase and not player_controlled:
		_cop_watch(delta)
		return
	if parked and not player_controlled and not scripted and not ai_chase:
		if sleeping: return
		brake = HANDBRAKE_FORCE
		engine_force = 0.0
		return
	var throttle := 0.0
	var brake_in := 0.0
	var steer_in := 0.0
	var hand := false
	if scripted:
		throttle = s_throttle; brake_in = s_brake; steer_in = s_steer; hand = s_hand
	elif ai_chase:
		if _police_close_and_player_slow():
			_deploy_cops()
			return
		var tp := Game.get_focus_pos()
		var local := to_local(tp)
		var ang := atan2(local.x, local.z)
		var dist := local.length()
		steer_in = clampf(ang * 2.2, -1.0, 1.0)
		throttle = 1.0 if (absf(ang) < 1.4 or dist > 25.0) else 0.45
		if dist < 7.0 and absf(speed_ms) > 7.0:
			throttle = 0.0
			brake_in = 0.6
		if absf(speed_ms) < 1.0 and dist > 6.0:
			_stuck_t += delta
		else:
			_stuck_t = 0.0
		if _stuck_t > 1.4:
			_rev_t = 1.3
			_stuck_t = 0.0
		if _rev_t > 0.0:
			_rev_t -= delta
			throttle = 0.0
			brake_in = 1.0
			steer_in = -steer_in
	elif player_controlled:
		throttle = Input.get_action_strength("move_forward")
		brake_in = Input.get_action_strength("move_back")
		steer_in = Input.get_axis("move_right", "move_left")
		hand = Input.is_action_pressed("handbrake")
		if Input.is_action_just_pressed("toggle_lights"):
			set_lights(not lights_on)
		if Input.is_action_just_pressed("horn"):
			_honk()
		if Input.is_action_just_pressed("siren") and def.has("emerg"):
			toggle_siren()
		if Input.is_action_just_pressed("rear_doors") and def.has("amb"):
			toggle_rear_doors()
	drive(throttle, brake_in, steer_in, hand, delta)
	_crash_check(delta)
	_engine_sound()

func drive(throttle: float, brake_in: float, steer_in: float, hand: bool, delta: float) -> void:
	var v := linear_velocity
	speed_ms = forward_dir().dot(v)
	var engine := 0.0
	var brake_f := 0.0
	var braking := false
	var power: float = def.power
	if throttle > 0.0 and brake_in == 0.0:
		if speed_ms < -1.5:
			brake_f = BRAKE_FORCE * throttle
			braking = true
		else:
			var top_v: float = float(def.get("top", TOP_SPEED * (0.8 + 0.2 * power)))
			engine = ENGINE_FORCE * power * throttle * (1.0 - pow(clampf(speed_ms / top_v, 0.0, 1.0), 3.0))
	elif brake_in > 0.0 and throttle == 0.0:
		if speed_ms > 1.5:
			brake_f = BRAKE_FORCE * brake_in
			braking = true
		elif speed_ms > -9.0:
			engine = -4000.0 * brake_in
	elif throttle == 0.0 and brake_in == 0.0 and not hand:
		brake_f = 1.2
	engine_force = engine
	for i in range(wheels.size()):
		var front := i < 2
		var base := 3.6 if front else 3.4
		wheels[i].wheel_friction_slip = 1.0 if (hand and not front) else base
	brake = brake_f + (HANDBRAKE_FORCE if hand else 0.0)
	braking = braking or hand
	var spd := absf(speed_ms)
	var max_steer := lerpf(STEER_LOW, STEER_HIGH, clampf(spd / 38.0, 0.0, 1.0))
	steering = move_toward(steering, steer_in * max_steer, STEER_SPEED * delta)
	apply_central_force(-v * v.length() * 0.22 + Vector3.DOWN * v.length_squared() * 0.3)
	braking_now = braking
	for t in tail_lamps:
		t.visible = braking or lights_on
	if tail_mat != null:
		if braking:
			tail_mat.emission_energy_multiplier = 7.5
		elif lights_on:
			tail_mat.emission_energy_multiplier = 2.2
		else:
			tail_mat.emission_energy_multiplier = 0.0
	if _tail_omni != null:
		_tail_omni.visible = braking or lights_on
		_tail_omni.light_energy = 3.5 if braking else (0.9 if lights_on else 0.0)
	# skid sound when sliding sideways at speed
	var side_slip := absf(global_transform.basis.x.dot(v))
	if (hand and spd > 8.0) or side_slip > 6.0:
		if _skid != null and not _skid.playing: _skid.play()
	elif _skid != null and _skid.playing and side_slip < 3.0 and not hand:
		_skid.stop()

func _engine_sound() -> void:
	if _engine_idle == null or not _engine_idle.playing or _engine_mid == null:
		return
	var spd := absf(speed_ms)
	var t := clampf(spd / 30.0, 0.0, 1.0)
	_engine_idle.pitch_scale = 0.9 + spd * 0.02
	_engine_idle.volume_db = lerpf(-6.0, -22.0, t)
	_engine_mid.pitch_scale = 0.8 + spd * 0.025
	_engine_mid.volume_db = lerpf(-30.0, -6.0, clampf(spd / 14.0, 0.0, 1.0))

func _crash_check(delta: float) -> void:
	_crash_cd = maxf(0.0, _crash_cd - delta)
	var dv := absf(_last_speed - speed_ms)
	if dv > 7.0 and _crash_cd == 0.0:
		_crash_cd = 0.6
		var p := AudioStreamPlayer3D.new()
		p.stream = load("res://assets/audio/vehicles/crash_car_01.ogg") as AudioStream
		p.max_distance = 90.0
		p.volume_db = minf(0.0, -14.0 + dv)
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		hp -= dv * 1.2
		# impact point: the end of the car that was moving, in the direction of travel
		var dir_sign := 1.0 if _last_speed >= 0.0 else -1.0
		var impact := global_position + forward_dir() * dir_sign * model_len * 0.5 + Vector3(0, 0.5, 0)
		Fx.crash(get_parent(), impact, clampf(dv / 10.0, 0.7, 2.2))
		if self == Game.in_car:
			Game.health -= dv * 0.25
			var cam := Game.camera as ThirdPersonCamera
			if cam != null: cam.add_shake(clampf(dv / 18.0, 0.3, 1.0))
			if dv > 12.0:
				Fx.blood(get_parent(), get_driver_seat_pos() + Vector3(0, 1.1, 0), forward_dir() * dir_sign, 1.0)
	_last_speed = speed_ms

func _honk() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = load("res://assets/audio/vehicles/car_horn_short_01.ogg") as AudioStream
	p.max_distance = 100.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func enter(who: Node) -> void:
	driver = who
	player_controlled = true
	lights_pending = true
	if freeze: _wake()
	sleeping = false
	parked = false
	start_engine()
	Game.in_car = self

## The front door on a side (side <= 0 is the driver's, wherever the wheel is).
func _door_on(side: float) -> Node3D:
	var x := drv_x if side <= 0.0 else -drv_x
	return door_fl if x > 0.0 else door_fr

func open_door(side: float = -1.0, duration: float = 0.45, angle: float = 1.15) -> void:
	doors_open = true
	var d := _door_on(side)
	if d:
		if _door_tween and _door_tween.is_valid(): _door_tween.kill()
		_door_tween = create_tween()
		var target_y := -angle if d == door_fl else angle
		_door_tween.tween_property(d, "rotation:y", target_y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_play_door_sound("res://assets/audio/vehicles/door_open_01.ogg")

func close_door(side: float = -1.0, duration: float = 0.35) -> void:
	doors_open = false
	var d := _door_on(side)
	if d:
		if _door_tween and _door_tween.is_valid(): _door_tween.kill()
		_door_tween = create_tween()
		_door_tween.tween_property(d, "rotation:y", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_play_door_sound("res://assets/audio/vehicles/door_close_01.ogg")

func toggle_doors() -> void:
	var opening := not doors_open
	if opening: open_door(-1.0)
	else: close_door(-1.0)
	var angle := 1.15 if opening else 0.0
	var dur := 0.45 if opening else 0.35
	var driver_door := _door_on(-1.0)
	for d in [door_fl, door_fr, door_rl, door_rr]:
		if d == null or d == driver_door: continue
		var tw := create_tween()
		var a: float = -angle if (d == door_fl or d == door_rl) else angle
		tw.tween_property(d, "rotation:y", a, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	if opening and door_fl and door_rl:
		pass

func _play_door_sound(path: String) -> void:
	if not _door_sound:
		_door_sound = AudioStreamPlayer3D.new()
		_door_sound.max_distance = 30.0
		add_child(_door_sound)
	_door_sound.stream = load(path) as AudioStream
	_door_sound.play()

## Character origin (feet level) for the seated driver. The Driving clip keeps the hips ~0.93 m above the origin,
## so the origin sits well below the car centre to put the hips on the seat cushion.
const SEAT_DROP := -0.82

## Extra seat lowering so the driver's head stays under the roof: the seated head tops out ~0.8 m above the car origin.
func _seat_dy() -> float:
	return Car.seat_dy_for(def, model_h)

static func seat_dy_for(d: Dictionary, h: float) -> float:
	if d.has("seat_dy"):
		return float(d.seat_dy)
	var roof := h - RIDE - 0.1
	return clampf(roof - 0.12 - 0.8 - 0.2, -0.4, 0.0)

## Seat position (character origin). side <= 0 is the driver's seat (left, +X), otherwise the front passenger seat.
func get_seat_pos(side: float = -1.0) -> Vector3:
	var x := model_w * 0.22 * (drv_x if side <= 0.0 else -drv_x)
	return to_global(Vector3(x, SEAT_DROP + _seat_dy(), model_len * 0.31 - 1.15 + float(def.get("seat_dz", 0.0))))

func get_driver_seat_pos() -> Vector3:
	return get_seat_pos(-1.0)

## Standing spot beside the driver's door (side <= 0 is the left / driver side, +X).
func get_door_pos(side: float = -1.0) -> Vector3:
	var s := drv_x if side <= 0.0 else -drv_x
	var z := float(def.door_z) if def.has("door_z") else (0.45 if def.get("is_glb", false) else model_len * 0.31 - 1.0)
	var x := 1.35 if def.get("is_glb", false) else model_w * 0.5 + 0.8
	return to_global(Vector3(s * x, -RIDE + 0.1, z))

## Way in / out for the driver, in world space: [standing spot beside the door, the doorway (sill), the seat on that
## side, the driver's seat]. Everything is lined up with the seat so the body slides straight through the open door
## (which is swung wide, 83 degrees, so its panel stays forward of the opening).
const DOOR_WIDE := 1.45

func entry_path(side: float = -1.0) -> Array[Vector3]:
	var s := drv_x if side <= 0.0 else -drv_x
	var drv := to_local(get_driver_seat_pos())
	var own := to_local(get_seat_pos(side))
	var gy := -RIDE + 0.05
	var hw := model_w * 0.5
	var stand := Vector3(s * (hw + 0.55), gy, own.z - 0.32)
	var sill := Vector3(s * (hw - 0.05), gy + 0.1, own.z - 0.14)
	return [to_global(stand), to_global(sill), to_global(own), to_global(drv)]

func exit_car(side: float = -1.0) -> Vector3:
	player_controlled = false
	driver = null
	lights_pending = false
	set_lights(false)
	Game.in_car = null
	engine_force = 0.0
	brake = 20.0
	return get_door_pos(side) + Vector3.UP * 0.3

func reset_upright() -> void:
	var yaw := atan2(forward_dir().x, forward_dir().z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 1.2)
