class_name IslandBeach
extends RefCounted
## Scanned beach pieces on Redline Island's sand: rippled dune patches (beach_001) and shoreline stretches (beach_smple). The
## scans are heavy, so only a few are placed and each fades out with distance. Pieces stay off the bridge road, the metro and the sea.

const DUNE := "res://assets/beach/beach_001.glb"
const SHORE := "res://assets/beach/beach_smple.glb"
const DUNE_SCALE := 14.0           # the patch is 1.2 x 1.6 m: this makes it about 17 x 22 m
const SHORE_SCALE := 1.1

static func _ok(p: Vector2, margin: float) -> bool:
	var d := Coast.inland(p.x, p.y)
	if d < 18.0 or d > 78.0: return false                     # on the sand band only
	if absf(p.x) < 40.0 and p.y < 1960.0: return false          # the bridge approach
	if Coast.near_pool(p.x, p.y, margin): return false
	return true

static var _fade := {}

## The scan's own material, feathered at its edges (radial fade over the mesh's footprint).
static func _feathered(mi: MeshInstance3D, mesh_box: AABB, warm := 0.0) -> void:
	for si in range(mi.mesh.get_surface_count()):
		var bm := mi.mesh.surface_get_material(si) as BaseMaterial3D
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/beach_scan.gdshader") as Shader
		if bm != null and bm.albedo_texture != null: sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
		sm.set_shader_parameter("centre", Vector2(mesh_box.get_center().x, mesh_box.get_center().z))
		sm.set_shader_parameter("radius", Vector2(mesh_box.size.x, mesh_box.size.z) * 0.5)
		sm.set_shader_parameter("tint_k", warm)
		sm.set_shader_parameter("tint", Color(0.93, 0.8, 0.6))
		mi.set_surface_override_material(si, sm)

static func _place(w: World, path: String, p: Vector2, yaw: float, scale: float, sink: float, vis: float) -> void:
	var ps := load(path) as PackedScene
	if ps == null: return
	var inst := ps.instantiate() as Node3D
	inst.position = Vector3(p.x, Coast.height_at(p.x, p.y) - sink, p.y)
	inst.rotation.y = yaw
	inst.scale = Vector3.ONE * scale
	# Global transforms are needed for the common feather radius.  Put the
	# instance in the tree first; querying them before this produced an empty
	# transform and made the real scanned beach pieces fade incorrectly.
	w.static_root.add_child(inst)
	var whole := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		whole = bb if first else whole.merge(bb)
		first = false
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		_feathered(mi as MeshInstance3D, whole, 0.8 if path == DUNE else 0.0)
		(mi as GeometryInstance3D).visibility_range_end = vis
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func build(w: World) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var ctr := Vector2(200.0, 2200.0)
	var n_dune := 0
	var n_shore := 0
	# walk round the island's coast and pick dry sand points
	for k in range(120):
		var a := TAU * float(k) / 120.0 + rng.randf() * 0.02
		var dir := Vector2(cos(a) * 800.0, sin(a) * 480.0)          # same ellipse as the island
		var pt := ctr + dir * 0.0
		# march in from beyond the coast until the sand starts
		var found := false
		for r in range(120, 0, -1):
			var q := ctr + Vector2(cos(a) * 800.0, sin(a) * 480.0) * (float(r) / 100.0)
			var d := Coast.inland(q.x, q.y)
			if d > 40.0 and d < 56.0:
				pt = q
				found = true
				break
		if not found or not _ok(pt, 6.0): continue
		if k % 6 == 0 and n_dune < 14:
			_place(w, DUNE, pt, rng.randf() * TAU, DUNE_SCALE, -0.76, 700.0)
			n_dune += 1
		elif k % 30 == 15 and n_shore < 4:
			_place(w, SHORE, pt, a + PI * 0.5, SHORE_SCALE, 0.32, 900.0)
			n_shore += 1
	print("island beach: %d dune patches, %d shore pieces" % [n_dune, n_shore])
