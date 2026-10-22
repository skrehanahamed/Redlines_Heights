class_name PoliceHeli
extends Node3D
## Police helicopter: flies in, circles above the player with a searchlight and fires down at them until they are dead.
## Appears from 4 stars; leaves when the wanted level drops.

var state := "approach"               # approach, hunt, leaving
var speed := 0.0
var vel := Vector3.ZERO
var shoot_cd := 2.0
var _rotor: Node3D
var _tail_rotor: Node3D
var _spot: SpotLight3D
var _beam: MeshInstance3D
var _snd: AudioStreamPlayer3D
var _gun: AudioStreamPlayer3D
var _orbit := 0.0
var _flash_t := 0.0
var _strobe: OmniLight3D
var _t := 0.0

func _ready() -> void:
	add_to_group("heli")
	_build()
	_orbit = randf() * TAU
	_snd = AudioStreamPlayer3D.new()
	var st := load("res://assets/audio/vehicles/helicopter_loop.ogg") as AudioStream
	if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop = true
	_snd.stream = st
	_snd.max_distance = 600.0
	_snd.unit_size = 40.0
	_snd.volume_db = 2.0
	add_child(_snd)
	_snd.play()
	_gun = AudioStreamPlayer3D.new()
	_gun.max_distance = 400.0
	_gun.unit_size = 25.0
	add_child(_gun)

const MODEL := "res://assets/vehicles/heli/md500.glb"
const SC := 1.7                       # model is ~7 m long; ~12 m in the world

static func _pivot_for(scene: Node3D, mesh_name: String) -> Node3D:
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		if String(n.name).begins_with(mesh_name):
			var mi := n as MeshInstance3D
			var c := (scene.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()).get_center()
			var pv := Node3D.new()
			scene.add_child(pv)
			pv.position = c
			mi.reparent(pv, true)
			return pv
	return null

func _build() -> void:
	var scene := (load(MODEL) as PackedScene).instantiate() as Node3D
	scene.scale = Vector3.ONE * SC
	add_child(scene)
	# police livery: the camo body becomes dark blue (the rotor / cockpit keep their own materials)
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if String(mi.name).begins_with("Helicopter_"):
			var m := mi.get_active_material(0)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_texture = null
				d.albedo_color = Color("#1c2c54")
				d.roughness = 0.45
				mi.set_surface_override_material(0, d)
	_rotor = _pivot_for(scene, "Top_rotor")
	_tail_rotor = _pivot_for(scene, "Tail_Rotor")
	_strobe = OmniLight3D.new()
	_strobe.omni_range = 22.0
	_strobe.light_energy = 2.4
	_strobe.position = Vector3(0, 4.4, -0.6)
	add_child(_strobe)
	# the searchlight is mounted under the nose and casts real, shadowed light
	_spot = SpotLight3D.new()
	_spot.spot_range = 160.0
	_spot.spot_angle = 9.0
	_spot.spot_attenuation = 0.5
	_spot.light_energy = 22.0
	_spot.light_color = Color("#fffbe8")
	_spot.shadow_enabled = true
	_spot.position = Vector3(0, 0.3, 1.9)
	add_child(_spot)
	_beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.15
	cone.bottom_radius = 7.0
	cone.height = 1.0
	cone.radial_segments = 14
	_beam.mesh = cone
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.albedo_color = Color(1.0, 0.97, 0.8, 0.09)
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = bmat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	add_child(_beam)

func leave() -> void:
	state = "leaving"

func _process(delta: float) -> void:
	_t += delta
	if _rotor != null: _rotor.rotate_y(delta * 38.0)
	if _tail_rotor != null: _tail_rotor.rotate_x(delta * 45.0)
	var ph := int(_t * 4.0) % 2
	_strobe.light_color = Color("#ff2222") if ph == 0 else Color("#2255ff")

var _aim := Vector3.ZERO
var _alt := 60.0

## Highest solid thing (ground, roof, tower) around the helicopter and a little ahead of it.
func _clearance_height() -> float:
	var space := get_world_3d().direct_space_state
	var top := 0.0
	var dirs := [Vector3.ZERO, vel.normalized() * 30.0, vel.normalized() * 60.0, Vector3(25, 0, 0), Vector3(-25, 0, 0), Vector3(0, 0, 25), Vector3(0, 0, -25)]
	for d in dirs:
		var from: Vector3 = global_position + d + Vector3(0, 400.0, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -600.0, 0), 1)
		var h := space.intersect_ray(q)
		if not h.is_empty():
			top = maxf(top, (h.position as Vector3).y)
	return top

func _physics_process(delta: float) -> void:
	var tgt := Game.get_focus_pos()
	var to := tgt - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var dist := flat.length()
	var want_alt := 26.0                      # metres above the highest roof or hill nearby
	var desired := Vector3.ZERO
	match state:
		"approach":
			desired = flat.normalized() * 34.0 if dist > 60.0 else Vector3.ZERO
			if dist < 130.0: state = "hunt"
		"hunt":
			_orbit += delta * 0.3
			var ring := tgt + Vector3(cos(_orbit) * 38.0, 0.0, sin(_orbit) * 38.0)
			var go := Vector3(ring.x - global_position.x, 0.0, ring.z - global_position.z)
			desired = go.normalized() * minf(go.length() * 0.9, 28.0)
		"leaving":
			var away := Vector3(global_position.x - tgt.x, 0.0, global_position.z - tgt.z).normalized()
			desired = away * 40.0
			want_alt = 90.0
			if dist > 520.0:
				queue_free()
				return
	vel = vel.lerp(desired, clampf(delta * 0.8, 0.0, 1.0))
	# keep above everything underneath and ahead, so it never flies into a building
	var clear := _clearance_height() + want_alt
	_alt = lerpf(_alt, clear, clampf(delta * (3.0 if clear > _alt else 0.8), 0.0, 1.0))
	vel.y = clampf((_alt - global_position.y) * 1.2, -9.0, 14.0)
	global_position += vel * delta
	var look := tgt - global_position if state == "hunt" else vel
	look.y = 0.0
	if look.length() > 0.5:
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), clampf(delta * 1.5, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, clampf(vel.length() * 0.01, 0.0, 0.25), clampf(delta * 2.0, 0.0, 1.0))
	# the searchlight swings after the player (it lags a little), and stops at the first thing in the way
	var p := tgt + Vector3(0, 0.8, 0)
	if _aim == Vector3.ZERO: _aim = p
	_aim = _aim.lerp(p, clampf(delta * 3.0, 0.0, 1.0))
	var origin := _spot.global_position
	var q := PhysicsRayQueryParameters3D.create(origin, origin + (_aim - origin) * 1.05, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := _aim if hit.is_empty() else (hit.position as Vector3)
	_spot.look_at(_aim, Vector3.UP)
	var blen := maxf(origin.distance_to(end), 1.0)
	_beam.mesh.height = blen
	_beam.global_transform = Transform3D(_beam_basis(end), (origin + end) * 0.5)
	if state == "hunt" and not Game.dead:
		shoot_cd -= delta
		var d3 := global_position.distance_to(p)
		if shoot_cd <= 0.0 and d3 < 110.0 and _clear_shot(p):
			shoot_cd = randf_range(0.14, 0.26)
			_fire(p, d3)

func _beam_basis(target: Vector3) -> Basis:
	var dir := (target - _spot.global_position).normalized()
	# a cylinder is long along Y; the narrow end (top) must sit at the helicopter
	var up := dir
	var right := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var fwd := right.cross(up).normalized()
	return Basis(right, -up, fwd)

func _clear_shot(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, p, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _fire(p: Vector3, dist: float) -> void:
	_gun.stream = load("res://assets/audio/guns/pistol_1911_0%d.mp3" % (1 + randi() % 2)) as AudioStream
	_gun.pitch_scale = randf_range(1.3, 1.6)
	_gun.volume_db = -6.0
	_gun.play()
	# muzzle flash under the nose and a tracer line
	var fl := OmniLight3D.new()
	fl.light_color = Color("#ffd080")
	fl.light_energy = 3.0
	fl.omni_range = 7.0
	get_parent().add_child(fl)
	fl.global_position = global_position + global_transform.basis.z * 2.0 + Vector3(0, -1.0, 0)
	get_tree().create_timer(0.05).timeout.connect(fl.queue_free)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var o := fl.global_position
	var hit_p := p + Vector3(randf_range(-1.6, 1.6), randf_range(-0.6, 0.6), randf_range(-1.6, 1.6))
	im.surface_add_vertex(o)
	im.surface_add_vertex(o.lerp(hit_p, 0.6))
	im.surface_end()
	var tr := MeshInstance3D.new()
	tr.mesh = im
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(1.0, 0.85, 0.4)
	tr.material_override = tm
	tr.top_level = true
	get_parent().add_child(tr)
	get_tree().create_timer(0.06).timeout.connect(tr.queue_free)
	var chance := clampf(0.5 - dist * 0.004, 0.18, 0.45)
	if randf() < chance:
		Game.health -= randf_range(2.0, 5.0)
		var cam := Game.camera as ThirdPersonCamera
		if cam != null: cam.add_shake(0.3)
	# bullets also kick up sparks near the target
	if randf() < 0.3:
		Fx.crash(get_parent(), Vector3(hit_p.x, maxf(CityData.height_at(hit_p.x, hit_p.z), 0.0) + 0.2, hit_p.z), 0.4)
