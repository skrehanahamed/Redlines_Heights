class_name Districts
extends RefCounted
## Everything that is not a plain street block: ocean, vegetation by zone, beach, piers and boats, stadium, airport,
## harbour and the special blocks (police / hospital / fire / gas / park). Spawn points for service vehicles and NPCs
## are recorded in World.spawns, map markers in World.pois.

const WOOD := "res://assets/textures/y2k_ground.png"
const SHOP := "res://assets/buildings/shopblock/Buildings/Models/Buildings.glb"
const HOUSE := "res://assets/buildings/houses/retro_house_pack/models/glb/%s.glb"
const NATURE := "res://assets/nature/%s.fbx"
const SHIP := "res://assets/ships/%s.fbx"
const UMBRELLA_COLORS := [Color("#e8321c"), Color("#f2b81c"), Color("#2e8fe0"), Color("#ffffff"), Color("#2ec27e"), Color("#e86ab0")]
const CONTAINER_COLORS := [Color("#b83a2a"), Color("#2c5f9e"), Color("#d8a21c"), Color("#3f7f4a"), Color("#8a8a8a"), Color("#6a3a8a")]

static func build(w: World) -> void:
	_airport(w)
	_register_pois(w)

# ------------------------------------------------------------------ small helpers
static func _front_yaw(w: World, facing_south := true) -> float:
	var y := 0.0 if facing_south else PI
	if w.front_sign < 0.0: y += PI
	return y

static func _sign(w: World, text: String, pos: Vector3, yaw: float, size := 120, color := Color.WHITE, parent: Node = null) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.02
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 1)
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = true
	(parent if parent != null else w.static_root).add_child(l)

static func _cyl(w: World, pos: Vector3, r: float, h: float, mat: Material, collide := false) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = mat
	body.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = r
		sh.height = h
		cs.shape = sh
		body.add_child(cs)
	w.static_root.add_child(body)

static func _wall(w: World, pos: Vector3, size: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	w.static_root.add_child(body)

static func _tree(w: World, pos: Vector3, height: float) -> void:
	var name: String = World.TREES[w.rng.randi() % World.TREES.size()]
	w.place("res://assets/buildings/trees/Trees/Trees.fbx", name, pos, w.rng.randf() * TAU, 1.0, -1.0, height, false)

static func _xf(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)

## Random points of a zone: `step` metres apart on a jittered lattice.
static func _zone_points(w: World, zones: Array, step: float, keep := 1.0) -> Array:
	var out: Array = []
	var half := CityData.half
	var x := -half + step * 0.5
	while x < half:
		var z := -half + step * 0.5
		while z < half:
			var px := x + w.rng.randf_range(-step * 0.45, step * 0.45)
			var pz := z + w.rng.randf_range(-step * 0.45, step * 0.45)
			if zones.has(CityData.zone_at(px, pz)) and w.rng.randf() < keep:
				out.append(Vector2(px, pz))
			z += step
		x += step
	return out

# ------------------------------------------------------------------ ocean
static func _ocean(w: World) -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_always;
uniform sampler2D shore_tex : repeat_disable, filter_linear;
uniform float half_size = 1200.0;
uniform vec3 deep = vec3(0.02, 0.2, 0.36);
uniform vec3 mid = vec3(0.05, 0.42, 0.55);
uniform vec3 shallow = vec3(0.35, 0.78, 0.74);
varying vec3 wpos;
varying float shore;

float wave(vec2 p, vec2 d, float freq, float speed, float t) {
	return sin(dot(p, d) * freq + t * speed);
}
float height(vec2 p, float t) {
	float h = 0.0;
	h += wave(p, normalize(vec2(1.0, 0.3)), 0.11, 1.1, t) * 0.2;
	h += wave(p, normalize(vec2(-0.4, 1.0)), 0.17, 1.4, t) * 0.12;
	h += wave(p, normalize(vec2(0.8, -0.7)), 0.31, 1.9, t) * 0.06;
	h += wave(p, normalize(vec2(-1.0, -0.2)), 0.53, 2.6, t) * 0.03;
	return h;
}
float vnoise_like(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(12.9898, 78.233))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float shore_at(vec2 p) {
	vec2 uv = (p + vec2(half_size)) / (half_size * 2.0);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 1.0;
	return texture(shore_tex, uv).r;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore = shore_at(wpos.xz);
	// waves calm down in the shallows and the surface laps up and down the beach
	float calm = mix(0.35, 1.0, smoothstep(0.0, 0.5, shore));
	VERTEX.y += height(wpos.xz, TIME) * calm + sin(shore * 40.0 - TIME * 2.2) * 0.05 * (1.0 - smoothstep(0.0, 0.5, shore));
}
void fragment() {
	float t = TIME;
	vec2 p = wpos.xz;
	float e = 0.6;
	float hx = height(p + vec2(e, 0.0), t) - height(p - vec2(e, 0.0), t);
	float hz = height(p + vec2(0.0, e), t) - height(p - vec2(0.0, e), t);
	vec3 n = normalize(vec3(-hx, 2.0 * e, -hz));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float sh = shore_at(p);
	// colour: turquoise shallows -> deep blue
	vec3 col = mix(shallow, mid, smoothstep(0.0, 0.3, sh));
	col = mix(col, deep, smoothstep(0.25, 1.0, sh));
	// rolling foam lines that travel towards the beach and break at the edge
	float roll = sh * 38.0 - t * 1.7;
	float band = smoothstep(0.55, 1.0, sin(roll)) * (1.0 - smoothstep(0.1, 0.55, sh));
	float edge = (1.0 - smoothstep(0.0, 0.06, sh)) * (0.7 + 0.3 * sin(p.x * 0.6 + p.y * 0.8 + t * 2.0));
	float chop = smoothstep(0.72, 0.8, vnoise_like(p * 0.5 + t * 0.15)) * (smoothstep(0.3, 0.9, sh)) * 0.12;
	float foam = clamp(band * 0.7 + edge, 0.0, 1.0);
	ALBEDO = mix(col, vec3(0.96, 0.99, 1.0), foam);
	ROUGHNESS = mix(0.08, 0.7, foam);
	SPECULAR = 0.75;
	// see-through at the shore, so the sand shows, solid in deep water
	ALPHA = mix(0.35, 0.95, smoothstep(0.0, 0.35, sh));
	ALPHA = max(ALPHA, foam * 0.9);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("shore_tex", CityData.build_shore_texture())
	mat.set_shader_parameter("half_size", CityData.half)
	# detailed surface that follows the player (waves are computed from world position, so it never swims against the world)
	var near := MeshInstance3D.new()
	near.name = "OceanNear"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1600, 1600)
	pm.subdivide_width = 190
	pm.subdivide_depth = 190
	near.mesh = pm
	near.material_override = mat
	near.position = Vector3(0, -0.55, 0)
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	near.custom_aabb = AABB(Vector3(-800, -4, -800), Vector3(1600, 8, 1600))
	w.static_root.add_child(near)
	var follower := OceanFollower.new()
	follower.target = near
	w.add_child(follower)
	# a flat, cheaper sea out to the horizon underneath
	var far := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(9000, 9000)
	far.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.03, 0.24, 0.4)
	fmat.roughness = 0.2
	far.material_override = fmat
	far.position = Vector3(0, -0.9, 0)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(far)

# ------------------------------------------------------------------ vegetation by zone (one draw call per model)
static func _vegetation(w: World) -> void:
	# parks: trees
	var park := _zone_points(w, [CityData.Z_PARK], 22.0, 0.8)
	var tree_models := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "PineTree_1"]
	var groups := {}
	for p in park:
		var n: String = tree_models[w.rng.randi() % tree_models.size()]
		if not groups.has(n): groups[n] = []
		groups[n].append(_xf(Vector3(p.x, CityData.height_at(p.x, p.y), p.y), w.rng.randf() * TAU))
	for n in groups:
		w.multi_place(NATURE % n, "", groups[n], w.rng.randf_range(8.0, 11.0))
	for bush in ["Bush_1", "Bush_2"]:
		var xs: Array = []
		for p in _zone_points(w, [CityData.Z_PARK], 14.0, 0.5):
			xs.append(_xf(Vector3(p.x, CityData.height_at(p.x, p.y), p.y), w.rng.randf() * TAU))
		w.multi_place(NATURE % bush, "", xs, 1.4)
	# beach: palms
	var palms := _zone_points(w, [CityData.Z_BEACH], 26.0, 0.55)
	groups = {}
	for p in palms:
		var n2: String = "PalmTree_%d" % (1 + w.rng.randi() % 4)
		if not groups.has(n2): groups[n2] = []
		groups[n2].append(_xf(Vector3(p.x, CityData.height_at(p.x, p.y), p.y), w.rng.randf() * TAU))
	for n in groups:
		w.multi_place(NATURE % n, "", groups[n], w.rng.randf_range(7.0, 10.0))
	# desert: cacti and rocks
	groups = {}
	for p in _zone_points(w, [CityData.Z_DESERT], 38.0, 0.7):
		var n3: String = "Cactus_%d" % (1 + w.rng.randi() % 4)
		if not groups.has(n3): groups[n3] = []
		groups[n3].append(_xf(Vector3(p.x, CityData.height_at(p.x, p.y), p.y), w.rng.randf() * TAU))
	for n in groups:
		w.multi_place(NATURE % n, "", groups[n], w.rng.randf_range(2.5, 4.5))
	var rocks: Array = []
	for p in _zone_points(w, [CityData.Z_DESERT], 60.0, 0.7):
		rocks.append(_xf(Vector3(p.x, CityData.height_at(p.x, p.y) - 0.3, p.y), w.rng.randf() * TAU))
	w.multi_place(NATURE % "Rock_3", "", rocks, 3.5)
	# mountains: big rocks and pines on the slopes
	var big: Array = []
	var pines: Array = []
	for p in _zone_points(w, [CityData.Z_MOUNTAIN], 30.0, 0.8):
		var h := CityData.height_at(p.x, p.y)
		if h > 22.0:
			big.append(_xf(Vector3(p.x, h - 1.0, p.y), w.rng.randf() * TAU))
		elif h > 1.0:
			pines.append(_xf(Vector3(p.x, h, p.y), w.rng.randf() * TAU))
	w.multi_place(NATURE % "Rock_5", "", big, 14.0)
	w.multi_place(NATURE % "PineTree_2", "", pines, 10.0)
	# the odd tree in the city's open ground
	var misc: Array = []
	for p in _zone_points(w, [CityData.Z_URBAN, CityData.Z_INDUSTRIAL], 70.0, 0.25):
		misc.append(_xf(Vector3(p.x, maxf(CityData.height_at(p.x, p.y), 0.0), p.y), w.rng.randf() * TAU))
	w.multi_place(NATURE % "CommonTree_2", "", misc, 8.0)

# ------------------------------------------------------------------ beach props (umbrellas, towels, balls)
static func _beach_props(w: World) -> void:
	var spots := _zone_points(w, [CityData.Z_BEACH], 34.0, 0.35)
	if spots.is_empty(): return
	var pole := CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.04
	pole.height = 2.4
	pole.radial_segments = 6
	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.05
	canopy.bottom_radius = 1.5
	canopy.height = 0.55
	canopy.radial_segments = 8
	var towel := BoxMesh.new()
	towel.size = Vector3(1.6, 0.04, 0.8)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	for item in [[pole, 1.2, Color("#eeeeee"), false], [canopy, 2.55, Color.WHITE, true], [towel, 0.03, Color.WHITE, true]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = item[0]
		mm.instance_count = spots.size()
		for i in range(spots.size()):
			var p: Vector2 = spots[i]
			var y := CityData.height_at(p.x, p.y)
			var off := Vector3.ZERO
			if item[1] == 0.03: off = Vector3(1.4, 0, 1.1)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(i)), Vector3(p.x, y + item[1], p.y) + off))
			var col: Color = item[2]
			if item[3]:
				col = UMBRELLA_COLORS[(i * 7 + (3 if item[1] == 0.03 else 0)) % UMBRELLA_COLORS.size()]
			mm.set_instance_color(i, col)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mmi)

# ------------------------------------------------------------------ piers
static func _piers(w: World) -> void:
	var wood := w._mat(WOOD, 0.4, Color(1.0, 0.85, 0.7))
	var post_mat := w._flat(Color("#4a3a2a"))
	for pr in CityData.features.piers:
		var a := Vector2(pr[0][0], pr[0][1])
		var b := Vector2(pr[1][0], pr[1][1])
		var dir := b - a
		var length := dir.length()
		if length < 5.0: continue
		var mid := (a + b) * 0.5
		var ang := atan2(dir.x, dir.y)
		var width := 8.0
		var body := StaticBody3D.new()
		body.position = Vector3(mid.x, 0.3, mid.y)
		body.rotation.y = ang
		body.collision_layer = 1
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, 0.5, length)
		mi.mesh = bm
		mi.material_override = wood
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(width, 0.5, length)
		cs.shape = bs
		body.add_child(cs)
		# posts under the deck
		var steps := int(length / 7.0)
		for k in range(steps + 1):
			for side in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = 0.22
				pm.bottom_radius = 0.22
				pm.height = 4.0
				pm.radial_segments = 6
				post.mesh = pm
				post.material_override = post_mat
				post.position = Vector3(side * (width * 0.5 - 0.3), -2.0, -length * 0.5 + k * (length / maxf(steps, 1)))
				body.add_child(post)
		w.static_root.add_child(body)
		if length > 40.0:
			for k in range(0, steps, 2):
				var p := a + dir.normalized() * (k * 7.0 + 3.0)
				w.place("res://assets/props/street/lamp_cobra.glb", "", Vector3(p.x + 3.4, 0.55, p.y), 0.0, 1.0, -1.0, 6.0, false)

# ------------------------------------------------------------------ boats in the bays and at the piers
static func _boats(w: World) -> void:
	var kinds := [["boat", 9.0], ["boatwsail", 13.0], ["sail_ship", 22.0], ["viking_boat", 12.0], ["lifeboat", 8.0]]
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 400:
		tries += 1
		var p := Vector2(w.rng.randf_range(-CityData.half + 80.0, CityData.half - 80.0), w.rng.randf_range(-CityData.half + 80.0, CityData.half - 80.0))
		if CityData.zone_at(p.x, p.y) != CityData.Z_SEA: continue
		if CityData.height_at(p.x, p.y) > -3.0 or CityData.height_at(p.x, p.y) < -9.0: continue
		var k: Array = kinds[w.rng.randi() % kinds.size()]
		var holder := w.place(SHIP % k[0], "", Vector3(p.x, -0.55, p.y), w.rng.randf() * TAU, 1.0, k[1], -1.0, false)
		# gentle bobbing
		var tw := holder.create_tween().set_loops()
		var y0 := holder.position.y
		tw.tween_property(holder, "position:y", y0 + 0.18, 1.6 + w.rng.randf()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(holder, "position:y", y0 - 0.08, 1.6 + w.rng.randf()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		placed += 1
	# a cruise ship far offshore to the south
	var ship := w.place(SHIP % "cruiseship", "", Vector3(500.0, -0.55, 1020.0), 0.4, 1.0, 70.0, -1.0, false)

# ------------------------------------------------------------------ the stadium
static func _ring(w: World, center: Vector2, rx0: float, rz0: float, rx1: float, rz1: float, y0: float, y1: float, color: Color, skip_gaps := true) -> void:
	var seg := 48
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in range(seg):
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var am := (a0 + a1) * 0.5
		if skip_gaps and (absf(sin(am)) < 0.12 and cos(am) > 0.0 or (absf(cos(am)) < 0.09 and sin(am) < 0.0)): continue   # entrances
		var base := verts.size()
		var pts := [
			Vector3(center.x + cos(a0) * rx0, y0, center.y + sin(a0) * rz0), Vector3(center.x + cos(a1) * rx0, y0, center.y + sin(a1) * rz0),
			Vector3(center.x + cos(a0) * rx1, y1, center.y + sin(a0) * rz1), Vector3(center.x + cos(a1) * rx1, y1, center.y + sin(a1) * rz1)]
		for pnt in pts:
			verts.append(pnt)
			cols.append(color)
			norms.append(Vector3(cos(am), 0.4, sin(am)).normalized() * (1.0 if rx1 >= rx0 else -1.0))
		idx.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))   # double sided
	if verts.is_empty(): return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	w.static_root.add_child(body)

static func _stadium(w: World) -> void:
	var f: Array = CityData.features.stadium
	var c := Vector2(f[0], f[1])
	var r: float = f[2]
	var rx := r * 1.0
	var rz := r * 0.78
	# stands in stepped tiers (red lower, blue upper), a tall outer wall and a roof rim
	_ring(w, c, rx * 0.62, rz * 0.62, rx * 0.74, rz * 0.74, 0.0, 6.0, Color("#b8322a"))
	_ring(w, c, rx * 0.74, rz * 0.74, rx * 0.86, rz * 0.86, 6.0, 12.0, Color("#2c4f9e"))
	_ring(w, c, rx * 0.86, rz * 0.86, rx * 0.98, rz * 0.98, 12.0, 18.0, Color("#b8322a"))
	_ring(w, c, rx * 0.98, rz * 0.98, rx * 1.02, rz * 1.02, 0.0, 18.0, Color("#8e8c84"))
	_ring(w, c, rx * 1.02, rz * 1.02, rx * 0.62, rz * 0.62, 18.0, 18.5, Color("#6a6a68"), false)
	var y := maxf(CityData.height_at(c.x, c.y), 0.0)
	# pitch with markings
	var grass := w._mat("res://assets/textures/y2k_grass.png", 0.3, Color(0.7, 1.0, 0.65))
	w._box_body(Vector3(c.x, y + 0.08, c.y), Vector3(rx * 1.1, 0.16, rz * 1.12), grass, w.static_root, false)
	var white := w._flat(Color("#f2f2f2"))
	w._box_body(Vector3(c.x, y + 0.2, c.y), Vector3(0.3, 0.02, rz * 1.1), white, w.static_root, false)
	w._box_body(Vector3(c.x, y + 0.2, c.y - rz * 0.55), Vector3(rx * 1.08, 0.02, 0.3), white, w.static_root, false)
	w._box_body(Vector3(c.x, y + 0.2, c.y + rz * 0.55), Vector3(rx * 1.08, 0.02, 0.3), white, w.static_root, false)
	_cyl(w, Vector3(c.x, y + 0.2, c.y), 9.0, 0.03, white)
	_cyl(w, Vector3(c.x, y + 0.24, c.y), 8.6, 0.03, grass)
	for side in [-1.0, 1.0]:
		w._box_body(Vector3(c.x + side * rx * 0.54, y + 1.3, c.y), Vector3(0.3, 2.4, 7.0), white, w.static_root, false)
	# floodlight towers
	for k in range(4):
		var a := PI * 0.25 + k * PI * 0.5
		var tp := Vector3(c.x + cos(a) * rx * 1.12, y, c.y + sin(a) * rz * 1.12)
		w._box_body(tp + Vector3(0, 14.0, 0), Vector3(1.0, 28.0, 1.0), w._flat(Color("#9a9a98")), w.static_root)
		w._box_body(tp + Vector3(0, 28.4, 0), Vector3(6.0, 2.0, 1.2), w._flat(Color("#f6f2d8"), 1.5), w.static_root, false)
		var lamp := OmniLight3D.new()
		lamp.position = tp + Vector3(0, 28.0, 0)
		lamp.omni_range = 60.0
		lamp.light_energy = 0.6
		w.static_root.add_child(lamp)
	# entrance gate signs and car park slabs
	_sign(w, "REDLINE STADIUM", Vector3(c.x + rx * 1.03, 9.0, c.y), -PI * 0.5, 160, Color("#ffd84a"))
	var lot := w._mat("res://assets/textures/y2k_stone.png", 0.2, Color(0.8, 0.8, 0.85))
	w._box_body(Vector3(c.x + rx * 1.7, 0.03, c.y), Vector3(rx * 0.8, 0.06, rz * 1.4), lot, w.static_root, false)
	for k in range(4):
		w.spawns.append({"type": "npc", "who": "civ", "pos": Vector3(c.x + rx * 1.35, 0.0, c.y + (k - 1.5) * 12.0), "yaw": 0.0, "wander": 14.0})

# ------------------------------------------------------------------ the airport
static func _oriented(w: World, pos: Vector3, size: Vector3, ang: float, mat: Material, collide := true) -> StaticBody3D:
	var b := w._box_body(pos, size, mat, w.static_root, collide)
	b.rotation.y = ang
	return b

## A runway (or taxiway) strip between two ground points, with edge lines, a dashed centre line, threshold bars,
## numbers and edge lights that glow at night.
static func _strip(w: World, a: Vector2, b: Vector2, width: float, runway: bool, lamp_mat: StandardMaterial3D) -> void:
	var dir := b - a
	var length := dir.length()
	var d := dir / length
	var n := Vector2(-d.y, d.x)
	var ang := atan2(d.x, d.y)
	var mid := (a + b) * 0.5
	var asphalt := w._mat("res://assets/textures/y2k_road_without_lines.png", 0.22, Color(0.85, 0.85, 0.9))
	var white := w._flat(Color("#f0f0e8"))
	var yellow := w._flat(Color("#e8c030"))
	var y0 := maxf(CityData.height_at(mid.x, mid.y), 0.0)
	_oriented(w, Vector3(mid.x, y0 + 0.08, mid.y), Vector3(width, 0.16, length), ang, asphalt)
	var top := y0 + 0.19
	if runway:
		for side in [-1.0, 1.0]:
			var e: Vector2 = mid + n * float(side) * (width * 0.5 - 1.2)
			_oriented(w, Vector3(e.x, top, e.y), Vector3(0.5, 0.03, length - 4.0), ang, white, false)
		var k := 12.0
		while k < length - 12.0:
			var c := a + d * (k + 7.0)
			_oriented(w, Vector3(c.x, top, c.y), Vector3(1.0, 0.03, 14.0), ang, white, false)
			k += 34.0
		for end in [0, 1]:
			var base := a + d * 6.0 if end == 0 else b - d * 6.0
			for i in range(-4, 5):
				var c2 := base + n * (i * (width / 10.0))
				_oriented(w, Vector3(c2.x, top, c2.y), Vector3(1.3, 0.03, 9.0), ang, white, false)
		var num := "09" if d.x > 0 else "27"
		_sign(w, num, Vector3(a.x + d.x * 26.0, top + 0.05, a.y + d.y * 26.0), ang, 340, Color("#f0f0e8"))
		(w.static_root.get_child(w.static_root.get_child_count() - 1) as Label3D).rotation_degrees.x = -90.0
		(w.static_root.get_child(w.static_root.get_child_count() - 1) as Label3D).rotation.y = ang + PI
	else:
		_oriented(w, Vector3(mid.x, top, mid.y), Vector3(0.35, 0.03, length), ang, yellow, false)
	# edge lights: tiny emissive posts shared across the whole airport
	var k2 := 10.0
	var pts := PackedVector3Array()
	while k2 < length - 5.0:
		for side in [-1.0, 1.0]:
			var lp: Vector2 = a + d * k2 + n * float(side) * (width * 0.5 + 0.8)
			pts.append(Vector3(lp.x, y0 + 0.35, lp.y))
		k2 += 24.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.5, 0.35)
	mm.mesh = bm
	mm.instance_count = pts.size()
	for i in range(pts.size()):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = lamp_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 380.0
	w.static_root.add_child(mmi)

## ================================================================== the airport (matches tools/gen_world.py)
## Compound x 550..1125, z -1100..-750 (north = -z). Landside (south): gate, parking, drop-off road, terminal.
## Airside (north): apron, hangars, taxiway, runway.
const AP_RECT := [550.0, -1100.0, 1125.0, -750.0]
const AP_GATE := Vector2(700.0, -750.0)

static func _gy(x: float, z: float) -> float:
	return maxf(CityData.height_at(x, z), 0.0)

## The airport model "low poly airport" (pilotcandle5470, CC BY 4.0) is placed as the airside of the compound: its long axis
## runs east-west, the runway is on the north side and the terminal faces the road on the south side.
const AIR_MODEL := "res://assets/airport/airport.glb"
const AIR_SCALE := 13.0
const AIR_X0 := 785.3        # world x of model z = 0 (model +Z runs towards -X)
const AIR_Z0 := -966.8       # world z of model x = 0 (model +X runs towards +Z)
const AIR_GROUND := 1.98     # model y of the ground plate

static func _airport(w: World) -> void:
	var ay := _gy(850.0, -930.0)
	var scene := (load(AIR_MODEL) as PackedScene).instantiate() as Node3D
	var root := Node3D.new()
	root.name = "AirportModel"
	root.rotation.y = -PI * 0.5
	root.scale = Vector3.ONE * AIR_SCALE
	root.position = Vector3(AIR_X0, ay + 0.08 - AIR_GROUND * AIR_SCALE, AIR_Z0)
	root.add_child(scene)
	w.static_root.add_child(root)
	# real textures instead of flat colours (world-space mapping, so the scale is the same everywhere)
	var tex_for := {
		"ground": w._mat("res://assets/airport/tex/Grass004.jpg", 0.2, Color(0.85, 0.95, 0.8)),
		"material": w._mat("res://assets/airport/tex/Asphalt025C.jpg", 0.25, Color(1.1, 1.1, 1.15)),
		"wall": w._mat("res://assets/airport/tex/Plaster001.jpg", 0.3, Color(0.88, 0.84, 0.76)),
		"ceiling": w._mat("res://assets/airport/tex/Concrete034.jpg", 0.2, Color(0.62, 0.66, 0.72)),
		"column": w._mat("res://assets/airport/tex/Concrete042A.jpg", 0.3, Color(0.85, 0.85, 0.85)),
	}
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m0 := mi as MeshInstance3D
		for i in range(m0.mesh.get_surface_count()):
			var mat0 := m0.get_active_material(i)
			if mat0 != null and tex_for.has(String(mat0.resource_name)):
				m0.set_surface_override_material(i, tex_for[String(mat0.resource_name)])
			elif mat0 is StandardMaterial3D and String(mat0.resource_name) == "glass":
				var gm := (mat0 as StandardMaterial3D).duplicate() as StandardMaterial3D
				gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				gm.albedo_color = Color(0.2, 0.5, 0.62, 0.55)
				gm.roughness = 0.08
				m0.set_surface_override_material(i, gm)
	# solid ground under the whole airport (runways, aprons, taxiways) at the height of the painted surfaces
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape3D.new()
	var fbx := BoxShape3D.new()
	fbx.size = Vector3(AP_RECT[2] - AP_RECT[0] + 30.0, 1.0, AP_RECT[3] - AP_RECT[1] + 30.0)
	fcs.shape = fbx
	fcs.position = Vector3((AP_RECT[0] + AP_RECT[2]) * 0.5, ay + 0.1 - 0.5, (AP_RECT[1] + AP_RECT[3]) * 0.5)
	floor_body.add_child(fcs)
	w.static_root.add_child(floor_body)
	# glow at night: the model's own emissive materials (runway lights, signs) follow the time of day
	var glow := {}
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.visibility_range_end = 900.0
		for i in range(m.mesh.get_surface_count()):
			var mat := m.get_active_material(i)
			if mat is StandardMaterial3D:
				var nm := String(mat.resource_name)
				if ("emission" in nm or nm == "lighting") and not glow.has(mat):
					glow[mat] = true
					(mat as StandardMaterial3D).emission_enabled = true
					(mat as StandardMaterial3D).emission_energy_multiplier = 0.2
					w.night_mats.append({"mat": mat, "gain": 3.0})
	# collision for everything taller than ~2 m (terminal, hangars, tower, jet bridges); the ground is the terrain
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = m.get_aabb()
		var nm := String(m.get_parent().name)
		if bb.size.y * AIR_SCALE < 2.0 or nm.begins_with("ground") or nm.begins_with("runway") or "sign" in nm or "glass" in nm: continue
		var cs := CollisionShape3D.new()
		cs.shape = m.mesh.create_trimesh_shape()
		cs.transform = body.global_transform.affine_inverse() * m.global_transform if body.is_inside_tree() else Transform3D.IDENTITY
		body.add_child(cs)
	_landside(w, ay)
	_planes(w, ay)
	_airport_gate(w)
	_india_flag(w, Vector3(712.0, _gy(712.0, -872.0), -872.0))
	_tower_parking(w)
	_sub_gate(w, AP_RECT[0], CityData.RING_C.y, -1.0)
	_sub_gate(w, AP_RECT[2], CityData.RING_C.y, 1.0)
	_airport_fence(w)
	w.add_poi("airport", "REDLINE AIRPORT", Vector3(840, 0, -940))

## Everything on the road side of the terminal: parking lot, lamps, palms, the helipad with the player's helicopter, people.
static func _landside(w: World, ay: float) -> void:
	_parking(w)
	# helipad
	var hp2 := Vector2(1068.0, -790.0)
	var pad_y := _gy(hp2.x, hp2.y) + 0.1
	var pad := StaticBody3D.new()
	pad.position = Vector3(hp2.x, pad_y, hp2.y)
	pad.collision_layer = 1
	var pm := MeshInstance3D.new()
	var pcm := CylinderMesh.new()
	pcm.top_radius = 9.0
	pcm.bottom_radius = 9.0
	pcm.height = 0.2
	pcm.radial_segments = 28
	pm.mesh = pcm
	pm.material_override = w._flat(Color("#3e4048"))
	pad.add_child(pm)
	var pcs := CollisionShape3D.new()
	var psh := CylinderShape3D.new()
	psh.radius = 9.0
	psh.height = 0.2
	pcs.shape = psh
	pad.add_child(pcs)
	w.static_root.add_child(pad)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 7.4
	tm.outer_radius = 7.9
	ring.mesh = tm
	ring.scale = Vector3(1, 0.05, 1)
	ring.material_override = w._flat(Color("#f2f2e8"))
	ring.position = Vector3(hp2.x, pad_y + 0.12, hp2.y)
	w.static_root.add_child(ring)
	_sign(w, "H", Vector3(hp2.x, pad_y + 0.14, hp2.y), 0.0, 520, Color("#f2f2e8"))
	(w.static_root.get_child(w.static_root.get_child_count() - 1) as Label3D).rotation_degrees.x = -90.0
	for k in range(12):
		var aa := k * TAU / 12.0
		_glow_box(w, Vector3(hp2.x + cos(aa) * 8.4, pad_y + 0.15, hp2.y + sin(aa) * 8.4), Vector3(0.45, 0.3, 0.45), Color("#ffb020"), 2.6)
	_night_light(w, Vector3(hp2.x, pad_y + 6.0, hp2.y), Color("#fff0cc"), 24.0, 1.8)
	if ResourceLoader.exists("res://assets/vehicles/heli/md500.glb"):
		var heli := Chopper.new()
		w.add_child(heli)
		heli.global_position = Vector3(hp2.x, pad_y + 0.13, hp2.y)
		heli.rotation.y = PI
		w.heli_spawn = heli.global_position
	w.add_poi("heli", "HELIPAD", Vector3(hp2.x, 0, hp2.y))
	for i in range(8):
		w.spawns.append({"type": "npc", "who": "civ", "pos": Vector3(740.0 + i * 30.0, ay, -850), "yaw": 0.0, "wander": 9.0})
	w.spawns.append({"type": "npc", "who": "cop", "pos": Vector3(720.0, ay, -758), "yaw": 0.0, "wander": 3.0})
	w.spawns.append({"type": "npc", "who": "cop", "pos": Vector3(680.0, ay, -758), "yaw": 0.0, "wander": 3.0})

## The entrance: brick pillars with an arch sign, guard booths either side of the road, a raised barrier and kerbs.
static func _airport_gate(w: World) -> void:
	var gx := AP_GATE.x
	var gz := AP_GATE.y
	var gy := _gy(gx, gz)
	var brick := w._mat("res://assets/textures/y2k_brick.png", 0.3, Color(1.0, 0.9, 0.85))
	for sx in [-14.0, 14.0]:
		w._box_body(Vector3(gx + sx, gy + 4.0, gz), Vector3(3.0, 8.0, 3.0), brick, w.static_root)
		w._box_body(Vector3(gx + sx, gy + 8.3, gz), Vector3(3.6, 0.6, 3.6), w._flat(Color("#c8c8c4")), w.static_root, false)
	w._box_body(Vector3(gx, gy + 8.0, gz), Vector3(28.0, 3.4, 1.2), w._flat(Color("#1b3c78")), w.static_root, false)
	_glow_box(w, Vector3(gx, gy + 8.0, gz + 0.65), Vector3(27.0, 2.8, 0.1), Color("#2a64d8"), 1.2)
	_sign(w, "REDLINE AIRPORT", Vector3(gx, gy + 8.0, gz + 0.8), 0.0, 130, Color("#ffffff"))
	for sx in [-11.0, 11.0]:
		w._box_body(Vector3(gx + sx, gy + 1.6, gz + 5.0), Vector3(3.0, 3.2, 3.0), w._flat(Color("#e8e8ec")), w.static_root)
		_glow_box(w, Vector3(gx + sx, gy + 3.45, gz + 5.0), Vector3(3.6, 0.3, 3.6), Color("#2a64ff"), 2.0)
		w._box_body(Vector3(gx + sx, gy + 0.15, gz + 2.0), Vector3(3.0, 0.3, 14.0), w._flat(Color("#9a9a98")), w.static_root, false)
	# barrier arm, swung up beside the road
	var arm := w._box_body(Vector3(gx + 9.0, gy + 3.5, gz + 5.0), Vector3(0.2, 6.0, 0.2), w._flat(Color("#e8321c")), w.static_root, false)
	_night_light(w, Vector3(gx, gy + 6.0, gz + 3.0), Color("#fff0d0"), 22.0, 2.0)

## Chain-link fence all round the compound, with a gap for the entrance road.
static func _airport_fence(w: World) -> void:
	var x0: float = AP_RECT[0]
	var z0: float = AP_RECT[1]
	var x1: float = AP_RECT[2]
	var z1: float = AP_RECT[3]
	# the perimeter as runs; the south side is open at the gate
	var runs: Array = [
		[Vector2(x0, z0), Vector2(x1, z0)],
		[Vector2(x1, z0), Vector2(x1, CityData.RING_C.y - 12.0)],
		[Vector2(x1, CityData.RING_C.y + 12.0), Vector2(x1, z1)],
		[Vector2(x0, z1), Vector2(AP_GATE.x - 16.0, z1)],
		[Vector2(AP_GATE.x + 16.0, z1), Vector2(x1, z1)],
		[Vector2(x0, z0), Vector2(x0, CityData.RING_C.y - 12.0)],
		[Vector2(x0, CityData.RING_C.y + 12.0), Vector2(x0, z1)],
	]
	# chain-link: a diamond lattice drawn into a small alpha texture, tiled along the run
	var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
	for py in range(64):
		for px in range(64):
			var d1 := absi(((px + py) % 32) - 16)
			var d2 := absi((((px - py) % 32) + 32) % 32 - 16)
			img.set_pixel(px, py, Color(0.62, 0.66, 0.7, 1.0) if (d1 < 2 or d2 < 2) else Color(0, 0, 0, 0))
	img.generate_mipmaps()
	var link_mat := StandardMaterial3D.new()
	link_mat.albedo_texture = ImageTexture.create_from_image(img)
	link_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	link_mat.alpha_scissor_threshold = 0.5
	link_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	link_mat.metallic = 0.5
	link_mat.roughness = 0.5
	link_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var steel := w._flat(Color("#5b6068"))
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.06
	post_mesh.bottom_radius = 0.07
	post_mesh.height = 2.7
	post_mesh.radial_segments = 6
	var posts: Array = []
	var body := StaticBody3D.new()
	body.name = "AirportFence"
	body.collision_layer = 1
	w.static_root.add_child(body)
	for run in runs:
		var a2: Vector2 = run[0]
		var b2: Vector2 = run[1]
		var seg := b2 - a2
		var len := seg.length()
		var dir := seg / len
		var yaw := atan2(dir.x, dir.y)
		var mid := (a2 + b2) * 0.5
		var gy := _gy(mid.x, mid.y)
		# the wire mesh (two metres high, a hand above the ground), with a taller rail on top and a bottom rail
		var panel := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(len, 2.2)
		panel.mesh = qm
		var pmat := link_mat.duplicate() as StandardMaterial3D
		pmat.uv1_scale = Vector3(len / 2.0, 1.1, 1.0)
		panel.material_override = pmat
		panel.position = Vector3(mid.x, gy + 1.35, mid.y)
		panel.rotation.y = yaw + PI * 0.5
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panel.visibility_range_end = 450.0
		w.static_root.add_child(panel)
		for ry in [0.22, 2.46, 2.68]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.07, 0.07, len)
			rail.mesh = rm
			rail.material_override = steel
			rail.position = Vector3(mid.x, gy + ry, mid.y)
			rail.rotation.y = yaw
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rail.visibility_range_end = 450.0
			w.static_root.add_child(rail)
		var n := int(ceil(len / 3.0))
		for k in range(n + 1):
			var pp := a2 + seg * (float(k) / n)
			posts.append(Transform3D(Basis.IDENTITY, Vector3(pp.x, _gy(pp.x, pp.y) + 1.35, pp.y)))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.2, 2.6, len)
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, gy + 1.3, mid.y))
		body.add_child(cs)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post_mesh
	mm.instance_count = posts.size()
	for i in range(posts.size()):
		mm.set_instance_transform(i, posts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = steel
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 450.0
	w.static_root.add_child(mmi)

static func _plane(w: World, pos: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, 2.6, 0)
	body.rotation.y = yaw
	body.collision_layer = 1
	var white := w._flat(Color("#f2f2f0"))
	var blue := w._flat(Color("#2c5f9e"))
	var fus := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.8
	cm.bottom_radius = 1.8
	cm.height = 26.0
	cm.radial_segments = 10
	fus.mesh = cm
	fus.rotation.x = PI * 0.5
	fus.material_override = white
	body.add_child(fus)
	var nose := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.8
	sm.height = 3.6
	nose.mesh = sm
	nose.position = Vector3(0, 0, 13.0)
	nose.material_override = white
	body.add_child(nose)
	var wing := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(32.0, 0.35, 5.0)
	wing.mesh = wm
	wing.position = Vector3(0, -0.5, 1.5)
	wing.material_override = white
	body.add_child(wing)
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.35, 5.0, 3.5)
	tail.mesh = tm
	tail.position = Vector3(0, 3.4, -11.5)
	tail.material_override = blue
	body.add_child(tail)
	var stab := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(10.0, 0.3, 2.4)
	stab.mesh = stm
	stab.position = Vector3(0, 1.0, -11.8)
	stab.material_override = white
	body.add_child(stab)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(30.0, 3.6, 28.0)
	cs.shape = bs
	body.add_child(cs)
	w.static_root.add_child(body)

# ------------------------------------------------------------------ harbour: cranes on the west quay, containers in industrial blocks
static func _harbour_cranes(w: World) -> void:
	var red := w._flat(Color("#c8321c"))
	for cz in [-250.0, -120.0, 10.0]:
		var cx := -1070.0
		for dz in [-6.0, 6.0]:
			for dx in [-5.0, 5.0]:
				w._box_body(Vector3(cx + dx, 11.0, cz + dz), Vector3(0.9, 22.0, 0.9), red, w.static_root)
		w._box_body(Vector3(cx - 18.0, 22.5, cz), Vector3(46.0, 1.6, 2.0), red, w.static_root, false)
		w._box_body(Vector3(cx, 22.0, cz), Vector3(12.0, 1.0, 14.0), red, w.static_root, false)

static func industrial_cell(w: World, base: Vector3) -> void:
	w._box_body(base + Vector3(0, 0.03, 0), Vector3(World.BLOCK - 4.0, 0.06, World.BLOCK - 4.0), w._mat("res://assets/textures/y2k_concrete.png", 0.2, Color(1.05, 1.0, 0.95)), w.static_root, false)
	var name: String = World.SHOPS[w.rng.randi() % World.SHOPS.size()]
	w.place(SHOP, name, base + Vector3(0, 0, -16.0), _front_yaw(w, true), 1.0, 34.0)
	var dims := Vector3(6.0, 2.6, 2.4)
	for row in range(2):
		for col in range(3):
			if w.rng.randf() < 0.2: continue
			var stack := 1 + w.rng.randi() % 3
			var cp := base + Vector3(-14.0 + col * 14.0, 0, 12.0 + row * 7.0)
			for lvl in range(stack):
				var m := w._flat(CONTAINER_COLORS[w.rng.randi() % CONTAINER_COLORS.size()])
				w._box_body(cp + Vector3(0, dims.y * (lvl + 0.5), 0), dims, m, w.static_root)
	if w.rng.randf() < 0.35:
		w.spawns.append({"type": "npc", "who": "civ", "pos": base + Vector3(0, 0, 4.0), "yaw": 0.0, "wander": 10.0})

# ------------------------------------------------------------------ map markers and crowds
static func _register_pois(w: World) -> void:
	for p in CityData.pois:
		w.add_poi(p.kind, p.name, Vector3(p.pos[0], 0, p.pos[1]))

static func _crowds(w: World) -> void:
	# beach-goers, park strollers, harbour workers, desert hikers
	var beach := _zone_points(w, [CityData.Z_BEACH], 90.0, 0.35)
	for p in beach:
		w.spawns.append({"type": "npc", "who": "civ", "pos": Vector3(p.x, 0.0, p.y), "yaw": w.rng.randf() * TAU, "wander": 18.0})
	for p in _zone_points(w, [CityData.Z_PARK], 70.0, 0.4):
		w.spawns.append({"type": "npc", "who": "civ", "pos": Vector3(p.x, 0.0, p.y), "yaw": w.rng.randf() * TAU, "wander": 12.0})
	for p in _zone_points(w, [CityData.Z_INDUSTRIAL], 100.0, 0.3):
		w.spawns.append({"type": "npc", "who": "civ", "pos": Vector3(p.x, 0.0, p.y), "yaw": w.rng.randf() * TAU, "wander": 10.0})

# ================================================================== special blocks inside the grid
static func special_block(w: World, kind: String, base: Vector3) -> void:
	match kind:
		"police": _police(w, base)
		"hospital": _hospital(w, base)
		"fire": _fire(w, base)
		"gas": _gas(w, base)
		"park": _park(w, base)

static func _lot(w: World, base: Vector3, tint: Color) -> void:
	w._box_body(base + Vector3(0, 0.03, 0), Vector3(World.BLOCK - 8.0, 0.06, World.BLOCK - 8.0), w._mat("res://assets/textures/y2k_stone.png", 0.2, tint), w.static_root, false)

static func _parking_lines(w: World, base: Vector3, z: float, xs: Array) -> void:
	for x in xs:
		w._box_body(base + Vector3(x, 0.08, z), Vector3(0.12, 0.02, 5.0), w._flat(Color("#e8e4d4")), w.static_root, false)

## ------------------------------------------------------------------ civic building helpers
static func _tint(node: Node, w: World, color: Color, tex := "res://assets/textures/y2k_concrete.png", tiling := 0.12) -> void:
	var m := w._mat(tex, tiling, color, 0.9)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m

## An emissive board / strip that glows at night.
static func _glow_box(w: World, pos: Vector3, size: Vector3, color: Color, gain := 1.4, yaw := 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.3)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.2
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	w.night_mats.append({"mat": mat, "gain": gain})

static func _night_light(w: World, pos: Vector3, color: Color, rng_m := 22.0, gain := 1.6) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = rng_m
	l.light_energy = 0.0
	l.visible = false
	l.set_meta("gain", gain)
	w.static_root.add_child(l)
	w.night_lights.append(l)

static func _fence(w: World, base: Vector3, x0: float, x1: float, z: float, col := Color("#6a6e76")) -> void:
	var m := w._flat(col)
	w._box_body(base + Vector3((x0 + x1) * 0.5, 0.9, z), Vector3(absf(x1 - x0), 1.8, 0.12), m, w.static_root)
	var n := int(absf(x1 - x0) / 4.0)
	for k in range(n + 1):
		w._box_body(base + Vector3(minf(x0, x1) + k * 4.0, 1.1, z), Vector3(0.3, 2.2, 0.3), m, w.static_root, false)

static func _flag(w: World, pos: Vector3, c1: Color, c2: Color) -> void:
	_cyl(w, pos + Vector3(0, 5.0, 0), 0.08, 10.0, w._flat(Color("#d8d8d8")))
	w._box_body(pos + Vector3(0.9, 9.0, 0), Vector3(1.8, 1.1, 0.04), w._flat(c1), w.static_root, false)
	w._box_body(pos + Vector3(0.9, 8.4, 0), Vector3(1.8, 0.1, 0.05), w._flat(c2), w.static_root, false)

static func _parking_row(w: World, base: Vector3, z: float, xs: Array) -> void:
	for x in xs:
		w._box_body(base + Vector3(x, 0.08, z), Vector3(0.14, 0.02, 5.2), w._flat(Color("#e8e4d4")), w.static_root, false)

## ------------------------------------------------------------------ police station (columned HQ, flag, blue beacon)
static func _police(w: World, base: Vector3) -> void:
	_lot(w, base, Color(0.8, 0.86, 1.05))
	var yaw := _front_yaw(w, true)
	var hq := w.place("res://assets/buildings/lp/Bank.fbx", "", base + Vector3(0, 0, -14.0), yaw, 1.0, 32.0)
	_tint(hq, w, Color(0.72, 0.8, 1.05), "res://assets/textures/y2k_brick.png", 0.3)
	# wings built from the brick kit, either side of the columned hall
	for sx in [-1.0, 1.0]:
		var wing := w.place("res://assets/buildings/downtown/Building_Small_1.gltf", "", base + Vector3(sx * 24.0, 0, -16.0), yaw, 1.0, 14.0)
		wing.set_meta("night", "building")
	# the sign over the entrance and a blue beacon on top
	_glow_box(w, base + Vector3(0, 11.5, -1.6), Vector3(18.0, 2.2, 0.4), Color("#1f55d8"), 1.6)
	_sign(w, "POLICE", base + Vector3(0, 11.5, -1.3), 0.0, 150, Color("#ffffff"))
	_glow_box(w, base + Vector3(0, 16.5, -14.0), Vector3(2.2, 1.0, 2.2), Color("#2a64ff"), 3.0)
	_night_light(w, base + Vector3(0, 15.0, -8.0), Color("#3a70ff"), 30.0, 3.0)
	_flag(w, base + Vector3(-22.0, 0, 6.0), Color("#1e3a8a"), Color("#d8d8e0"))
	_parking_row(w, base, 16.0, [-20, -12, -4, 4, 12, 20])
	_fence(w, base, -26.0, 26.0, 27.0)
	for k in range(5):
		w.spawns.append({"type": "car", "kind": "police", "pos": base + Vector3(-16.0 + k * 8.0, 0.0, 16.0), "yaw": 0.0})
	for k in range(4):
		w.spawns.append({"type": "npc", "who": "cop", "pos": base + Vector3(-9.0 + k * 6.0, 0.0, 5.0), "yaw": 0.0, "wander": 5.0})
	_night_light(w, base + Vector3(0, 7.0, 8.0), Color("#ffe2b0"), 28.0, 1.8)
	w.add_poi("police", "POLICE STATION", base + Vector3(0, 0, 4.0))

## ------------------------------------------------------------------ hospital (4-storey block, entrance canopy, red cross, helipad)
static func _hospital(w: World, base: Vector3) -> void:
	_lot(w, base, Color(1.1, 1.1, 1.1))
	var yaw := _front_yaw(w, true)
	var h := w.place("res://assets/buildings/lp/Hospital.fbx", "", base + Vector3(-4.0, 0, -14.0), yaw, 1.0, 34.0)
	_tint(h, w, Color(1.1, 1.12, 1.15), "res://assets/textures/y2k_tile.png", 0.35)
	# a long window band on every floor so the facade does not read as a blank block
	var glass := Color("#9ad0ff")
	for fl in range(4):
		_glow_box(w, base + Vector3(-4.0, 3.6 + fl * 4.4, -1.15), Vector3(24.0, 1.4, 0.12), glass, 1.2)
	# big red cross panel and sign
	var red := w._flat(Color("#e02020"), 0.5)
	w._box_body(base + Vector3(-4.0, 19.5, -0.9), Vector3(1.6, 5.2, 0.3), red, w.static_root, false)
	w._box_body(base + Vector3(-4.0, 19.5, -0.9), Vector3(5.2, 1.6, 0.3), red, w.static_root, false)
	_sign(w, "HOSPITAL", base + Vector3(-4.0, 14.5, -0.7), 0.0, 130, Color("#ffffff"))
	_glow_box(w, base + Vector3(-4.0, 14.5, -0.95), Vector3(15.0, 2.0, 0.3), Color("#1b5ca8"), 1.3)
	# emergency entrance with a canopy and ambulance bay
	w._box_body(base + Vector3(18.0, 4.6, 3.0), Vector3(9.0, 0.4, 8.0), w._flat(Color("#e8e8ec")), w.static_root, false)
	for sx in [14.0, 22.0]:
		w._box_body(base + Vector3(sx, 2.3, 6.5), Vector3(0.4, 4.6, 0.4), w._flat(Color("#c8c8cc")), w.static_root)
	_glow_box(w, base + Vector3(18.0, 4.0, 6.9), Vector3(8.0, 0.8, 0.2), Color("#e02020"), 1.8)
	_sign(w, "EMERGENCY", base + Vector3(18.0, 4.0, 7.1), 0.0, 70, Color("#ffffff"))
	_parking_row(w, base, 16.0, [-6, 2, 10, 18, 26])
	for k in range(3):
		w.spawns.append({"type": "car", "kind": "ambulance", "pos": base + Vector3(10.0 + k * 8.0, 0.0, 16.0), "yaw": 0.0})
	# helipad on the lawn
	var pad := StaticBody3D.new()
	pad.position = base + Vector3(-22.0, 0.1, 18.0)
	var pm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 6.5
	cm.bottom_radius = 6.5
	cm.height = 0.12
	cm.radial_segments = 24
	pm.mesh = cm
	pm.material_override = w._flat(Color("#4a4a52"))
	pad.add_child(pm)
	w.static_root.add_child(pad)
	_sign(w, "H", base + Vector3(-22.0, 0.25, 18.0), 0.0, 380, Color("#ffffff"))
	for ang in range(8):
		var a := ang * TAU / 8.0
		_glow_box(w, base + Vector3(-22.0 + cos(a) * 6.6, 0.2, 18.0 + sin(a) * 6.6), Vector3(0.4, 0.3, 0.4), Color("#ffb020"), 2.0)
	for k in range(6):
		w.spawns.append({"type": "npc", "who": "doctor", "pos": base + Vector3(-12.0 + k * 5.0, 0.0, 7.0), "yaw": 0.0, "wander": 5.0})
	_night_light(w, base + Vector3(-4.0, 6.0, 4.0), Color("#dff0ff"), 30.0, 1.8)
	_night_light(w, base + Vector3(18.0, 3.5, 4.5), Color("#ff6a5a"), 14.0, 1.6)
	_fence(w, base, -26.0, 26.0, 27.0)
	w.hospital_spawn = base + Vector3(0, 0.7, 12.0)
	w.add_poi("hospital", "HOSPITAL", base + Vector3(0, 0, 4.0))

## ------------------------------------------------------------------ fire station (brick, three red engine doors, hose tower)
static func _fire(w: World, base: Vector3) -> void:
	_lot(w, base, Color(1.05, 0.95, 0.9))
	var yaw := _front_yaw(w, true)
	var st := w.place("res://assets/buildings/downtown/Building_Medium_2_001.gltf", "", base + Vector3(-6.0, 0, -16.0), yaw, 1.0, 30.0)
	st.set_meta("night", "building")
	# engine doors across the front at ground level
	var red := w._mat("res://assets/textures/y2k_brick2.png", 0.3, Color(1.25, 0.55, 0.45))
	var door_z := -16.0 + 6.2
	for k in range(3):
		w.place("res://assets/buildings/downtown/Door_1.gltf", "", base + Vector3(-17.0 + k * 11.0, 0, door_z), yaw, 1.0) if false else null
		w._box_body(base + Vector3(-17.0 + k * 9.6, 2.5, -9.4), Vector3(7.4, 5.0, 0.35), red, w.static_root, false)
		for sl in range(5):
			w._box_body(base + Vector3(-17.0 + k * 9.6, 0.7 + sl * 0.9, -9.2), Vector3(7.0, 0.07, 0.1), w._flat(Color("#8c2112")), w.static_root, false)
	# hose tower and signs
	w._box_body(base + Vector3(14.0, 11.0, -20.0), Vector3(4.0, 22.0, 4.0), w._mat("res://assets/textures/y2k_brick2.png", 0.3, Color(1.2, 0.7, 0.55)), w.static_root)
	w._box_body(base + Vector3(14.0, 22.4, -20.0), Vector3(4.8, 0.8, 4.8), w._flat(Color("#5a1e12")), w.static_root, false)
	_glow_box(w, base + Vector3(-6.0, 12.0, -9.2), Vector3(16.0, 2.2, 0.3), Color("#c8321c"), 1.6)
	_sign(w, "FIRE STATION", base + Vector3(-6.0, 12.0, -8.95), 0.0, 120, Color("#fff2c0"))
	_glow_box(w, base + Vector3(-6.0, 7.0, -9.3), Vector3(2.0, 1.0, 0.2), Color("#ff3a2a"), 3.0)
	_night_light(w, base + Vector3(-6.0, 7.0, -6.0), Color("#ff7a4a"), 26.0, 2.0)
	_parking_row(w, base, 14.0, [-18, -9, 0, 9])
	for k in range(3):
		w.spawns.append({"type": "car", "kind": "firetruck", "pos": base + Vector3(-17.0 + k * 9.6, 0.0, 6.0), "yaw": 0.0})
	for k in range(4):
		w.spawns.append({"type": "npc", "who": "fire", "pos": base + Vector3(-12.0 + k * 6.0, 0.0, 14.0), "yaw": 0.0, "wander": 5.0})
	_fence(w, base, -26.0, 26.0, 27.0, Color("#7a4a40"))
	w.add_poi("fire", "FIRE STATION", base + Vector3(0, 0, 4.0))

## ------------------------------------------------------------------ gas station (shop, long canopy, pumps, price sign)
static func _gas(w: World, base: Vector3) -> void:
	_lot(w, base, Color(0.8, 0.8, 0.85))
	var yaw := _front_yaw(w, true)
	var shop := w.place("res://assets/buildings/lp/Shop.fbx", "", base + Vector3(-6.0, 0, -18.0), yaw, 1.0, 20.0)
	_tint(shop, w, Color(1.05, 0.95, 0.85), "res://assets/textures/y2k_brick2.png", 0.3)
	_glow_box(w, base + Vector3(-6.0, 6.4, -9.2), Vector3(14.0, 1.6, 0.3), Color("#e8321c"), 1.6)
	_sign(w, "24H SHOP", base + Vector3(-6.0, 6.4, -8.95), 0.0, 90, Color("#ffffff"))
	_glow_box(w, base + Vector3(-6.0, 2.6, -9.1), Vector3(10.0, 2.4, 0.15), Color("#fff2c0"), 1.3)   # lit shop window
	# canopy on four columns with a lit underside
	var white := w._flat(Color("#f2f2f2"))
	var red := w._flat(Color("#d8321c"))
	w._box_body(base + Vector3(0, 5.6, 8.0), Vector3(26.0, 0.5, 14.0), white, w.static_root, false)
	w._box_body(base + Vector3(0, 5.6, 1.1), Vector3(26.0, 1.0, 0.3), red, w.static_root, false)
	w._box_body(base + Vector3(0, 5.6, 14.9), Vector3(26.0, 1.0, 0.3), red, w.static_root, false)
	for dx in [-11.0, 11.0]:
		for dz in [3.0, 13.0]:
			w._box_body(base + Vector3(dx, 2.8, dz), Vector3(0.6, 5.6, 0.6), white, w.static_root)
	_glow_box(w, base + Vector3(0, 5.3, 8.0), Vector3(24.0, 0.1, 12.0), Color("#fff6d8"), 1.4)
	_night_light(w, base + Vector3(0, 4.8, 8.0), Color("#fff0d0"), 22.0, 2.4)
	for dx in [-6.0, 6.0]:
		for dz in [6.0, 10.0]:
			w._box_body(base + Vector3(dx, 0.95, dz), Vector3(0.9, 1.9, 0.7), red, w.static_root)
			w._box_body(base + Vector3(dx, 1.5, dz + 0.37), Vector3(0.6, 0.5, 0.05), w._flat(Color("#1a1a1a")), w.static_root, false)
	# tall price sign on a pole by the road
	_cyl(w, base + Vector3(-23.0, 6.0, 20.0), 0.25, 12.0, w._flat(Color("#9a9a98")))
	_glow_box(w, base + Vector3(-23.0, 12.5, 20.0), Vector3(3.6, 3.4, 0.4), Color("#ffd84a"), 1.8)
	_sign(w, "GAS", base + Vector3(-23.0, 13.0, 20.25), 0.0, 100, Color("#c8321c"))
	for k in range(3):
		w.place("res://assets/props/street/oil_drum.glb", "", base + Vector3(18.0 + k * 1.3, 0.0, -8.0), 0.0, 1.0, -1.0, 1.0, false)
	w.spawns.append({"type": "npc", "who": "civ", "pos": base + Vector3(-5.0, 0.0, 9.0), "yaw": 0.0, "wander": 4.0})
	w.spawns.append({"type": "car", "kind": "saloon", "pos": base + Vector3(-6.0, 0.8, 7.0), "yaw": 0.0})
	w.add_poi("gas", "GAS STATION", base + Vector3(0, 0, 6.0))

static func _park(w: World, base: Vector3) -> void:
	var lawn := w._mat("res://assets/textures/y2k_grass.png", 0.2, Color(0.75, 1.0, 0.7))
	w._box_body(base + Vector3(0, 0.05, 0), Vector3(World.BLOCK - 6.0, 0.1, World.BLOCK - 6.0), lawn, w.static_root, false)
	var path := w._mat("res://assets/textures/y2k_tile.png", 0.3, Color(1.2, 1.1, 0.95))
	w._box_body(base + Vector3(0, 0.1, 0), Vector3(3.0, 0.04, World.BLOCK - 6.0), path, w.static_root, false)
	w._box_body(base + Vector3(0, 0.1, 0), Vector3(World.BLOCK - 6.0, 0.04, 3.0), path, w.static_root, false)
	# fountain
	_cyl(w, base + Vector3(0, 0.35, 0), 4.5, 0.7, w._flat(Color("#9a9a98")), true)
	_cyl(w, base + Vector3(0, 0.72, 0), 3.8, 0.1, w._flat(Color("#3a8fd0")))
	_cyl(w, base + Vector3(0, 1.4, 0), 0.5, 2.0, w._flat(Color("#b0b0ae")))
	# pond
	_cyl(w, base + Vector3(-17.0, 0.12, -17.0), 7.0, 0.1, w._flat(Color("#3a8fd0")))
	for k in range(8):
		var a := k * TAU / 8.0
		w.place("res://assets/props/street/bench_park.glb", "", base + Vector3(cos(a) * 8.0, 0.0, sin(a) * 8.0), -a + PI * 0.5, 1.0, -1.0, 1.0, false)
	for k in range(14):
		_tree(w, base + Vector3(w.rng.randf_range(-26.0, 26.0), 0.0, w.rng.randf_range(-26.0, 26.0)), w.rng.randf_range(7.0, 11.0))
	for k in range(4):
		w.spawns.append({"type": "npc", "who": "civ", "pos": base + Vector3(w.rng.randf_range(-14, 14), 0.0, w.rng.randf_range(-14, 14)), "yaw": 0.0, "wander": 8.0})
	w.add_poi("park", "REDLINE PARK", base)


## Landside: a car park on each side of the entrance road, a forecourt road along the terminal front, kerbs, bay lines,
## lamps and parked cars. Bays are 2.6 x 5.2 m in back-to-back rows with 7 m aisles.
static func _parking(w: World) -> void:
	var asphalt := w._mat("res://assets/airport/tex/Asphalt025C.jpg", 0.25, Color(0.85, 0.85, 0.9))
	var kerb_mat := w._mat("res://assets/airport/tex/Concrete034.jpg", 0.3, Color(0.9, 0.9, 0.9))
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.12, 0.02, 5.0)
	var line_mat := w._flat(Color("#ecebe0"))
	var lines: Array = []
	var lamp_body := StaticBody3D.new()
	lamp_body.name = "AirportLamps"
	lamp_body.collision_layer = 1
	w.static_root.add_child(lamp_body)
	var rr := RandomNumberGenerator.new()
	rr.seed = 99
	# rows from the forecourt road southwards: kind "bay" (5.2 m) or "aisle" (7 m)
	var layout := [["bay", 5.2], ["aisle", 7.0], ["bay", 5.2], ["bay", 5.2], ["aisle", 7.0], ["bay", 5.2]]
	var lots := [[622.0, 689.0], [711.0, 1000.0]]
	var z_north := -796.0
	var depth := 0.0
	for r in layout: depth += float(r[1])
	for lot in lots:
		var lx0: float = lot[0]
		var lx1: float = lot[1]
		var gy := _gy((lx0 + lx1) * 0.5, z_north)
		# asphalt slab and a kerb all round
		w._box_body(Vector3((lx0 + lx1) * 0.5, gy + 0.05, z_north + depth * 0.5), Vector3(lx1 - lx0, 0.1, depth + 2.0), asphalt, w.static_root)
		for edge in [[(lx0 + lx1) * 0.5, z_north - 1.0, lx1 - lx0 + 0.6, 0.6], [(lx0 + lx1) * 0.5, z_north + depth + 1.0, lx1 - lx0 + 0.6, 0.6]]:
			w._box_body(Vector3(edge[0], gy + 0.12, edge[1]), Vector3(edge[2], 0.24, edge[3]), kerb_mat, w.static_root, false)
		for ex in [lx0 - 0.3, lx1 + 0.3]:
			w._box_body(Vector3(ex, gy + 0.12, z_north + depth * 0.5), Vector3(0.6, 0.24, depth + 2.0), kerb_mat, w.static_root, false)
		var z := z_north
		for r in layout:
			var h: float = r[1]
			if r[0] == "bay":
				var bays := int((lx1 - lx0 - 1.0) / 2.6)
				var x_start := lx0 + 0.5
				for k in range(bays + 1):
					lines.append(Transform3D(Basis.IDENTITY, Vector3(x_start + k * 2.6, gy + 0.11, z + h * 0.5)))
			z += h
		# lamps down the middle of the lot, over the back-to-back rows
		var lx := lx0 + 10.0
		while lx < lx1 - 6.0:
			RoadKit.lamp_at(w, lamp_body, Vector2(lx, z_north + 5.2 + 7.0 + 5.2), Vector2(lx, z_north + 5.2 + 7.0 + 12.0))
			lx += 40.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = line_mesh
	mm.instance_count = lines.size()
	for i in range(lines.size()):
		mm.set_instance_transform(i, lines[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = line_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 300.0
	w.static_root.add_child(mmi)
	# the terminal front: a paved strip between the forecourt road and the building
	w._box_body(Vector3(868.0, 0.06, -852.0), Vector3(270.0, 0.12, 8.0), w._mat("res://assets/roads/pavement.png", 0.18, Color(1.05, 1.03, 1.0)), w.static_root)


## A service gate where the forecourt road crosses the fence: a canopy beam over the road with a sign, a raised boom
## barrier, striped posts, and a guard house beside the road with windows, a door, a roof and a glowing sign.
## `outward` is -1 for the west gate and +1 for the east gate (which way the road leaves the airport).
static func _sub_gate(w: World, gx: float, gz: float, outward: float) -> void:
	var gy := _gy(gx, gz)
	var yaw := outward * PI * 0.5
	var steel := w._flat(Color("#5d6470"))
	var white := w._flat(Color("#e9ecee"))
	var dark := w._flat(Color("#30343c"))
	var concrete := w._mat("res://assets/airport/tex/Concrete034.jpg", 0.3, Color(0.9, 0.9, 0.9))
	# posts and the beam across the road
	for v in [-7.4, 7.4]:
		w._box_body(Vector3(gx, gy + 3.2, gz + v), Vector3(0.6, 6.4, 0.6), steel, w.static_root)
		w._box_body(Vector3(gx, gy + 0.55, gz + v), Vector3(0.9, 1.1, 0.9), concrete, w.static_root, false)
	w._box_body(Vector3(gx, gy + 6.4, gz), Vector3(0.9, 0.9, 16.0), w._flat(Color("#1b3c78")), w.static_root, false)
	_glow_box(w, Vector3(gx + outward * 0.5, gy + 6.4, gz), Vector3(0.06, 0.7, 14.5), Color("#2a64d8"), 1.1)
	_sign(w, "SERVICE GATE", Vector3(gx + outward * 0.56, gy + 6.4, gz), yaw, 90, Color("#ffffff"))
	# guard house on the south side, just inside the beam
	var bx := gx - outward * 3.0
	var bz := gz + 9.4
	var body_h := 3.0
	w._box_body(Vector3(bx, gy + body_h * 0.5, bz), Vector3(3.4, body_h, 3.4), w._flat(Color("#e4e7ea")), w.static_root)
	w._box_body(Vector3(bx, gy + 0.18, bz), Vector3(3.6, 0.36, 3.6), concrete, w.static_root, false)
	w._box_body(Vector3(bx, gy + body_h + 0.14, bz), Vector3(4.4, 0.28, 4.4), dark, w.static_root, false)
	w._box_body(Vector3(bx, gy + 2.55, bz), Vector3(3.46, 0.3, 3.46), w._flat(Color("#1b3c78")), w.static_root, false)
	# windows: toward the road (north) and toward the outside, a lit pane in a dark frame
	w._box_body(Vector3(bx, gy + 1.65, bz - 1.72), Vector3(2.7, 1.1, 0.08), dark, w.static_root, false)
	_glow_box(w, Vector3(bx, gy + 1.65, bz - 1.77), Vector3(2.5, 0.9, 0.06), Color("#8fd0ff"), 0.9)
	w._box_body(Vector3(bx + outward * 1.72, gy + 1.65, bz), Vector3(0.08, 1.1, 2.7), dark, w.static_root, false)
	_glow_box(w, Vector3(bx + outward * 1.77, gy + 1.65, bz), Vector3(0.06, 0.9, 2.5), Color("#8fd0ff"), 0.9)
	# door on the inner side and a small air-conditioner on the roof
	w._box_body(Vector3(bx - outward * 1.72, gy + 1.05, bz + 0.2), Vector3(0.08, 2.1, 0.95), w._flat(Color("#4a5260")), w.static_root, false)
	w._box_body(Vector3(bx + 0.8, gy + body_h + 0.55, bz + 0.8), Vector3(1.0, 0.6, 0.8), w._flat(Color("#aeb4ba")), w.static_root, false)
	_sign(w, "SECURITY", Vector3(bx, gy + 2.55, bz - 1.78), 0.0, 55, Color("#ffffff"))
	_night_light(w, Vector3(bx, gy + 5.0, bz - 2.0), Color("#fff0d0"), 20.0, 1.6)
	# kerb island between the guard house and the road, striped end posts
	w._box_body(Vector3(bx, gy + 0.12, gz + 6.4), Vector3(7.0, 0.24, 1.2), concrete, w.static_root, false)
	for k in range(2):
		var pu := gx + outward * (3.2 if k == 0 else -3.2)
		w._box_body(Vector3(pu, gy + 0.6, gz + 6.4), Vector3(0.3, 1.2, 0.3), w._flat(Color("#e8c21c") if k == 0 else Color("#e8c21c")), w.static_root, false)
		w._box_body(Vector3(pu, gy + 0.9, gz + 6.4), Vector3(0.32, 0.25, 0.32), dark, w.static_root, false)
	# boom barrier, raised: base post by the island, striped arm leaning up over the road
	w._box_body(Vector3(gx, gy + 0.55, gz + 6.2), Vector3(0.5, 1.1, 0.5), w._flat(Color("#c9ced3")), w.static_root, false)
	var dir := Vector3(0.0, sin(deg_to_rad(68.0)), -cos(deg_to_rad(68.0)))
	var arm_len := 5.6
	var center := Vector3(gx, gy + 1.1, gz + 6.2) + dir * (arm_len * 0.5)
	for seg in range(4):
		var c2 := Vector3(gx, gy + 1.1, gz + 6.2) + dir * (arm_len * (seg + 0.5) / 4.0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 0.14, arm_len / 4.0)
		mi.mesh = bm
		mi.material_override = w._flat(Color("#e8321c") if seg % 2 == 0 else Color("#f2f2f2"))
		mi.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), c2)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mi)
	_night_light(w, Vector3(gx, gy + 6.0, gz), Color("#fff0d0"), 22.0, 2.0)


## A short car park just south of the H tower, opening straight onto the town road, with a paved walk up to the plaza.
static func _tower_parking(w: World) -> void:
	var asphalt := w._mat("res://assets/airport/tex/Asphalt025C.jpg", 0.25, Color(0.85, 0.85, 0.9))
	var kerb_mat := w._mat("res://assets/airport/tex/Concrete034.jpg", 0.3, Color(0.9, 0.9, 0.9))
	var pave := w._mat("res://assets/roads/pavement.png", 0.18, Color(1.05, 1.03, 1.0))
	var lx0 := 55.0
	var lx1 := 135.0
	var z_north := 164.0
	var layout := [["bay", 5.2], ["aisle", 7.0], ["bay", 5.2], ["bay", 5.2]]
	var depth := 0.0
	for r in layout: depth += float(r[1])
	var cx := (lx0 + lx1) * 0.5
	w._box_body(Vector3(cx, 0.05, z_north + depth * 0.5), Vector3(lx1 - lx0, 0.1, depth), asphalt, w.static_root)
	# kerbs on the north and the two short sides; the south side is open to the road
	w._box_body(Vector3(cx, 0.12, z_north - 0.3), Vector3(lx1 - lx0 + 0.6, 0.24, 0.6), kerb_mat, w.static_root, false)
	for ex in [lx0 - 0.3, lx1 + 0.3]:
		w._box_body(Vector3(ex, 0.12, z_north + depth * 0.5), Vector3(0.6, 0.24, depth), kerb_mat, w.static_root, false)
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.12, 0.02, 5.0)
	var lines: Array = []
	var rr := RandomNumberGenerator.new()
	rr.seed = 7
	var z := z_north
	for r in layout:
		var h: float = r[1]
		if r[0] == "bay":
			var bays := int((lx1 - lx0 - 1.0) / 2.6)
			for k in range(bays + 1):
				lines.append(Transform3D(Basis.IDENTITY, Vector3(lx0 + 0.5 + k * 2.6, 0.11, z + h * 0.5)))
		z += h
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = line_mesh
	mm.instance_count = lines.size()
	for i in range(lines.size()):
		mm.set_instance_transform(i, lines[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = w._flat(Color("#ecebe0"))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 300.0
	w.static_root.add_child(mmi)
	var lamp_body := StaticBody3D.new()
	lamp_body.collision_layer = 1
	w.static_root.add_child(lamp_body)
	# lamps stand on the north kerb, facing into the lot, so nothing stands in the bays
	for lx in [lx0 + 14.0, cx, lx1 - 14.0]:
		RoadKit.lamp_at(w, lamp_body, Vector2(lx, z_north - 1.4), Vector2(lx, z_north + 6.0))
	# paved walk from the lot up to the tower plaza
	w._box_body(Vector3(95.0, 0.05, (z_north + 119.0) * 0.5), Vector3(14.0, 0.1, z_north - 119.0), pave, w.static_root)


## The two flyable aeroplanes, parked nose-in on the apron: the airliner at a terminal stand, the private jet at the west end.
static func _planes(w: World, ay: float) -> void:
	for spec in [["passenger", Vector2(873.0, -930.0), 0.0], ["private", Vector2(795.0, -925.0), 0.0], ["boeing", Vector2(955.0, -930.0), 0.0]]:
		if not ResourceLoader.exists(Airplane.SPECS[spec[0]].model): continue
		var plane := Airplane.new()
		plane.kind = spec[0]
		w.add_child(plane)
		plane.global_position = Vector3(spec[1].x, ay + 0.12, spec[1].y)
		plane.yaw = spec[2]
		plane.rotation.y = spec[2]


const FLAG_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float width = 14.0;
varying float v_fold;
void vertex() {
	float k = clamp(VERTEX.x / width, 0.0, 1.0);          // 0 at the pole, 1 at the flying edge
	float t = TIME;
	float w1 = sin(VERTEX.x * 0.85 - t * 4.2);
	float w2 = sin(VERTEX.x * 0.45 + VERTEX.y * 0.55 - t * 2.6);
	VERTEX.z += (w1 * 0.85 + w2 * 0.35) * k;
	VERTEX.y += sin(VERTEX.x * 0.6 - t * 3.1) * 0.12 * k;
	VERTEX.x -= abs(w1) * 0.25 * k;                        // the cloth draws in as it ripples
	float dz = (cos(VERTEX.x * 0.85 - t * 4.2) * 0.85 * 0.85 + cos(VERTEX.x * 0.45 + VERTEX.y * 0.55 - t * 2.6) * 0.45 * 0.35) * k;
	NORMAL = normalize(vec3(-dz, 0.0, 1.0));
	v_fold = dz;
}
void fragment() {
	vec4 c = texture(tex, UV);
	float shade = 0.82 + clamp(v_fold, -1.0, 1.0) * 0.14 * (FRONT_FACING ? 1.0 : -1.0);
	ALBEDO = c.rgb * shade;
	ROUGHNESS = 0.9;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
"""

static func _flag_texture() -> ImageTexture:
	var W := 450
	var H := 300
	var img := Image.create(W, H, true, Image.FORMAT_RGB8)
	var saffron := Color("#ff9933")
	var white := Color("#ffffff")
	var green := Color("#138808")
	var navy := Color("#000080")
	var cx := W * 0.5
	var cy := H * 0.5
	var r := H / 6.0 * 0.92
	for y in range(H):
		for x in range(W):
			var c := saffron if y < H / 3 else (white if y < 2 * H / 3 else green)
			var d := Vector2(x - cx, y - cy)
			var dist := d.length()
			if dist < r and dist > r * 0.86:
				c = navy
			elif dist <= r * 0.86:
				if dist < r * 0.13:
					c = navy
				else:
					var ang := fposmod(atan2(d.y, d.x), TAU) / TAU * 24.0
					if absf(ang - round(ang)) < 0.075 and dist < r * 0.86:
						c = navy
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## A big tricolour on a tall pole, rippling in the wind (the waving is done in the vertex shader).
static func _india_flag(w: World, base: Vector3) -> void:
	var pole_h := 34.0
	var fw := 15.0
	var fh := fw * 2.0 / 3.0
	var steel := w._flat(Color("#d7d9dc"))
	w._box_body(base + Vector3(0, 0.4, 0), Vector3(4.5, 0.8, 4.5), w._mat("res://assets/airport/tex/Concrete034.jpg", 0.3, Color(0.9, 0.9, 0.9)), w.static_root)
	_cyl(w, base + Vector3(0, pole_h * 0.5, 0), 0.22, pole_h, steel, true)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.1
	ball.mesh = sm
	ball.material_override = w._flat(Color("#e6c34a"))
	ball.position = base + Vector3(0, pole_h + 0.5, 0)
	w.static_root.add_child(ball)
	# cloth grid: x along the flag from the pole, y downwards from the top
	var nx := 36
	var ny := 18
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in range(ny + 1):
		for i in range(nx + 1):
			verts.append(Vector3(fw * i / nx, -fh * j / ny, 0.0))
			uvs.append(Vector2(float(i) / nx, float(j) / ny))
	for j in range(ny):
		for i in range(nx):
			var a := j * (nx + 1) + i
			idx.append_array(PackedInt32Array([a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var cloth := ArrayMesh.new()
	cloth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	cloth.custom_aabb = AABB(Vector3(-2, -fh - 3, -3), Vector3(fw + 4, fh + 6, 6))
	var sh := Shader.new()
	sh.code = FLAG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tex", _flag_texture())
	mat.set_shader_parameter("width", fw)
	var mi := MeshInstance3D.new()
	mi.mesh = cloth
	mi.material_override = mat
	mi.position = base + Vector3(0.25, pole_h - 0.6, 0.0)
	mi.rotation.y = 0.0
	mi.visibility_range_end = 1500.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	# flood-lit at night
	_night_light(w, base + Vector3(fw * 0.5, pole_h - fh * 0.5, 7.0), Color("#fff4dc"), 38.0, 3.2)
