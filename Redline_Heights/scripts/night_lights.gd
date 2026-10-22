class_name NightLights
extends Node
## Night lighting: street lamps glow (bulbs plus a pool of real lights on the nearest lamps), building windows light up
## (skyscraper window atlas; dark window panes of shops and houses turn warm), all scaled by how dark it is.

var world: World
var _bulbs: MultiMeshInstance3D
var _bulb_mat: StandardMaterial3D
var _pool: Array[OmniLight3D] = []
var _win_mats: Array = []          # [{mat, kind}]
var _t := 0.0
var _last_dark := -1.0
const POOL := 8

func _ready() -> void:
	world = Game.world
	_make_bulbs()
	for i in range(POOL):
		var l := OmniLight3D.new()
		l.light_color = Color("#ffc878")
		l.omni_range = 17.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_pool.append(l)
	_collect_window_materials()

func _make_bulbs() -> void:
	var pts := world.lamp_points
	if pts.is_empty(): return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	mm.mesh = q
	mm.instance_count = pts.size()
	for i in range(pts.size()):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i]))
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bulb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bulb_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bulb_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_bulb_mat.no_depth_test = false
	_bulb_mat.albedo_texture = _glow_texture()
	_bulb_mat.albedo_color = Color(1.0, 0.78, 0.45, 0.0)
	_bulbs = MultiMeshInstance3D.new()
	_bulbs.multimesh = mm
	_bulbs.material_override = _bulb_mat
	_bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bulbs)

func _glow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 0.95, 0.8, 0.85), Color(1, 0.8, 0.5, 0.18), Color(1, 0.7, 0.4, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

# ---- windows: every building / house gets its own copies of the window materials, so each lights up independently
var _glow_cache := {}
var _rng := RandomNumberGenerator.new()

func _collect_window_materials() -> void:
	_rng.seed = 424242
	var seen := {}
	var count := 0
	for holder in world.static_root.get_children():
		var kind := String(holder.get_meta("night", ""))
		if kind == "":
			continue
		count += 1
		_light_instance(holder, kind)
	# old skyscraper atlas: it is black with lit windows, so it is its own emission map (shared)
	_walk_skyscrapers(world.static_root, seen)
	print("night lights: %d lamps, %d lit-window materials, %d buildings" % [world.lamp_points.size(), _win_mats.size(), count])

func _light_instance(holder: Node, kind: String) -> void:
	# which of the interior variants (or how bright this house) is on, chosen per building
	var on := {}
	for i in range(1, 5):
		on[i] = _rng.randf() < 0.62
	var house_on := _rng.randf() < 0.7
	var warm := Color(1.0, 0.82, 0.55).lerp(Color(0.85, 0.92, 1.0), _rng.randf() * 0.5)
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null: continue
		for i in range(inst.mesh.get_surface_count()):
			var m := inst.get_active_material(i)
			if not (m is StandardMaterial3D): continue
			var sm := m as StandardMaterial3D
			var nm := String(sm.resource_name)
			if nm.begins_with("MI_FakeInterior") and sm.albedo_texture != null:
				var idx := int(nm.substr(nm.length() - 1)) if nm.length() > 0 and nm[nm.length() - 1].is_valid_int() else 1
				var d := sm.duplicate() as StandardMaterial3D
				d.emission_enabled = true
				d.emission_texture = sm.albedo_texture
				d.emission = warm
				d.emission_energy_multiplier = 0.0
				inst.set_surface_override_material(i, d)
				var is_lit_tex := "lit_interior" in sm.albedo_texture.resource_path
				_win_mats.append({"mat": d, "gain": 0.5 if is_lit_tex else 0.2, "on": on.get(idx, true) and (is_lit_tex or _rng.randf() < 0.35)})
			elif kind != "building" and sm.albedo_texture != null and ("shopblock" in sm.albedo_texture.resource_path or "retro_house_pack" in sm.albedo_texture.resource_path):
				var em := _glow_for(sm.albedo_texture)
				if em == null: continue
				var d2 := sm.duplicate() as StandardMaterial3D
				d2.emission_enabled = true
				d2.emission_texture = em
				d2.emission_energy_multiplier = 0.0
				inst.set_surface_override_material(i, d2)
				_win_mats.append({"mat": d2, "gain": 0.9, "on": house_on})

func _glow_for(tex: Texture2D) -> ImageTexture:
	var p := tex.resource_path
	if not _glow_cache.has(p):
		_glow_cache[p] = _dark_to_glow(tex)
	return _glow_cache[p]

func _walk_skyscrapers(n: Node, seen: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var m := mi.get_active_material(i)
				if m is StandardMaterial3D and not seen.has(m):
					seen[m] = true
					var tex := (m as StandardMaterial3D).albedo_texture
					if tex != null and "skyscraper_pack" in tex.resource_path:
						(m as StandardMaterial3D).emission_enabled = true
						(m as StandardMaterial3D).emission_texture = tex
						(m as StandardMaterial3D).emission_energy_multiplier = 0.0
						_win_mats.append({"mat": m, "gain": 1.8, "on": true, "dim": true})
	for c in n.get_children():
		_walk_skyscrapers(c, seen)

## Dark panes (windows, doors) of a photo / atlas become a warm glow; everything else emits nothing.
func _dark_to_glow(tex: Texture2D) -> ImageTexture:
	var img := tex.get_image()
	if img == null: return null
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			if lum < 0.045:
				out.set_pixel(x, y, Color(0, 0, 0, 1))
			elif lum < 0.24:
				var k := 1.0 - lum / 0.24
				out.set_pixel(x, y, Color(1.0, 0.72, 0.38) * (0.35 + 0.65 * k))
			else:
				out.set_pixel(x, y, Color(0, 0, 0, 1))
	return ImageTexture.create_from_image(out)

func _process(delta: float) -> void:
	var wx := Game.weather as Weather
	if wx == null: return
	var dark := clampf(wx.night_amount() + wx.storm * 0.35, 0.0, 1.0)
	if absf(dark - _last_dark) > 0.004:
		_last_dark = dark
		for e in _win_mats:
			(e.mat as StandardMaterial3D).emission_energy_multiplier = dark * e.gain if e.on else 0.0
			if e.has("dim"):
				var v := lerpf(1.0, 0.38, dark)
				(e.mat as StandardMaterial3D).albedo_color = Color(v, v, v * 1.05)
	for e in world.night_mats:
		(e.mat as StandardMaterial3D).emission_energy_multiplier = dark * e.gain
	for l in world.night_lights:
		if is_instance_valid(l):
			(l as OmniLight3D).visible = dark > 0.05
			(l as OmniLight3D).light_energy = (l.get_meta("gain", 1.5) as float) * dark
	if _bulb_mat != null:
		_bulb_mat.albedo_color.a = clampf(dark * 1.2, 0.0, 1.0)
		_bulbs.visible = dark > 0.05
	_t += delta
	if _t < 0.35: return
	_t = 0.0
	if dark < 0.05:
		for l in _pool: l.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var fp := cam.global_position
	var near: Array = []
	for p in world.lamp_points:
		var d := p.distance_squared_to(fp)
		if d < 120.0 * 120.0:
			near.append([d, p])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(POOL):
		var l := _pool[i]
		if i < near.size():
			l.global_position = near[i][1] - Vector3(0, 0.5, 0)
			l.light_energy = 2.4 * dark
			l.visible = true
		else:
			l.visible = false
