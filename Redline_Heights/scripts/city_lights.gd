class_name CityLights
extends Node
## Night lighting for buildings: windows, glass, signs and lit facades glow once it gets dark. Materials of the building
## models are registered here (by name, or all textured ones for towers whose materials carry no names) and their
## emission follows the day / night clock. Lamp posts are lit by NightLights as before.

static var _mats: Array = []          # [{m: BaseMaterial3D, gain: float, base: float}]
static var _seen := {}
static var _lights: Array = []        # [{l: Light3D, e: float}] lamps that are on only at night
static var _shaders: Array = []         # ShaderMaterials that carry a `night` uniform
var _last := -1.0

const WINDOW_WORDS := ["window", "wins", "glass", "emmis", "emiss", "bulb", "lobby", "light", "signal", "neon", "billboard", "sign", "shop", "front", "voorkant", "vitrine"]
const WARM := Color(1.0, 0.82, 0.5)

## Register a mesh's materials. mode "names": only materials whose name looks like a window / light / sign;
## "all": every material (towers); "glass": only glass.
static func apply(mesh: Mesh, mode: String, gain := 1.0) -> void:
	if mesh == null: return
	for si in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(si) as BaseMaterial3D
		if m == null: continue
		var id := m.get_instance_id()
		if _seen.has(id): continue
		var nm := String(m.resource_name).to_lower()
		var want := false
		match mode:
			"all": want = true
			"glass": want = nm.contains("glass") or nm.contains("window")
			"emissive": want = false
			"windows_named": want = nm.contains("window")
			"only_windows":
				want = nm == "windows"
				if not want and m.emission_enabled:
					m.emission_enabled = false          # the model's other glow maps (interior floors, lobby, billboard) stay off
			_:
				for wd in WINDOW_WORDS:
					if nm.contains(wd): want = true
		if m.emission_enabled and m.emission_texture != null: want = true        # imported emissive materials follow the clock too
		if not want: continue
		_seen[id] = true
		var base_energy := 1.0
		m.emission_enabled = true
		if m.emission_texture == null:
			if m.albedo_texture != null:
				m.emission_texture = m.albedo_texture
				m.emission = WARM
			else:
				m.emission = Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b).lerp(WARM, 0.35)
		else:
			base_energy = m.emission_energy_multiplier
		m.emission_energy_multiplier = 0.0
		_mats.append({"m": m, "gain": gain, "base": base_energy})

## A material that glows at night with the given colour (a lamp lens of a model whose material is shared with other parts).
static func register_material(m: BaseMaterial3D, color: Color, energy: float) -> void:
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.0
	_mats.append({"m": m, "gain": energy, "base": 1.0})

## A real light (e.g. a floodlight's beam) that is switched on by the night clock: off in daylight, full energy when it is dark.
static func register_light(l: Light3D, energy: float) -> void:
	l.visible = false
	_lights.append({"l": l, "e": energy})

## Register a ShaderMaterial built elsewhere (it must have a `night` uniform) so it follows the clock.
static func register(sm: ShaderMaterial) -> void:
	_shaders.append(sm)

## Swap a mesh's opaque textured materials for the window shader (see building_night.gdshader): the facade keeps its
## daytime look and only its windows light up at night. params: mode, thr, gain, floor_h, cell_w, lit_frac, emit (texture path).
static func apply_shader(mesh: Mesh, params: Dictionary, mat_filter := "") -> void:
	var am := mesh as ArrayMesh
	if am == null: return
	var sh := load("res://shaders/building_night.gdshader") as Shader
	for si in range(am.get_surface_count()):
		var m := am.surface_get_material(si) as BaseMaterial3D
		if m == null or (m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and m.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS): continue
		if mat_filter != "" and not String(m.resource_name).to_lower().contains(mat_filter.to_lower()): continue
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("has_tex", m.albedo_texture != null)
		if m.albedo_texture != null: sm.set_shader_parameter("albedo_tex", m.albedo_texture)
		sm.set_shader_parameter("albedo_col", m.albedo_color)
		for k in params:
			if k == "emit": sm.set_shader_parameter("emit_tex", load(String(params[k])))
			else: sm.set_shader_parameter(k, params[k])
		am.surface_set_material(si, sm)
		_shaders.append(sm)

## The glass panes of a model that are separate geometry: the surfaces `pick` accepts are given vertex colours with one random
## value per pane (a pane is two triangles that share an edge) and the window shader in mode 4, so only whole panes glow.
static func paint_panes(mesh: Mesh, pick: Callable, lit_frac: float, gain := 1.0, seed := 3) -> int:
	var am := mesh as ArrayMesh
	if am == null: return 0
	var sh := load("res://shaders/building_night.gdshader") as Shader
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var panes := 0
	for si in range(am.get_surface_count()):
		var m := am.surface_get_material(si) as BaseMaterial3D
		if m == null or not bool(pick.call(m)): continue
		var arr := am.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn = arr[Mesh.ARRAY_NORMAL]
		var uu = arr[Mesh.ARRAY_TEX_UV]
		var ids: PackedInt32Array = PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null: ids = arr[Mesh.ARRAY_INDEX]
		else:
			ids.resize(v.size())
			for i in range(v.size()): ids[i] = i
		var nt := ids.size() / 3
		var ov := PackedVector3Array()
		var on := PackedVector3Array()
		var ou := PackedVector2Array()
		var oc := PackedColorArray()
		var t := 0
		while t < nt:
			var pair := false
			if t + 1 < nt:
				var shared := 0
				for a in range(3):
					for b in range(3):
						if v[ids[t * 3 + a]].distance_to(v[ids[(t + 1) * 3 + b]]) < 0.001: shared += 1
				pair = shared == 2
			var val := rng.randf_range(0.12, 1.0)
			var warm := rng.randf()
			var count := 2 if pair else 1
			for k in range(count):
				for c in range(3):
					var i := ids[(t + k) * 3 + c]
					ov.append(v[i])
					on.append(nn[i] if nn != null else Vector3.UP)
					ou.append(uu[i] if uu != null else Vector2.ZERO)
					oc.append(Color(val, warm, 0.0))
			panes += 1
			t += count
		var a2 := []
		a2.resize(Mesh.ARRAY_MAX)
		a2[Mesh.ARRAY_VERTEX] = ov
		a2[Mesh.ARRAY_NORMAL] = on
		a2[Mesh.ARRAY_TEX_UV] = ou
		a2[Mesh.ARRAY_COLOR] = oc
		var keep_name := m.resource_name
		am.surface_remove(si)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		# surface_remove shifts later surfaces down; move the new one back to this slot is not possible, so the new surface is last
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("has_tex", m.albedo_texture != null)
		if m.albedo_texture != null: sm.set_shader_parameter("albedo_tex", m.albedo_texture)
		sm.set_shader_parameter("albedo_col", m.albedo_color)
		sm.set_shader_parameter("metal", minf(m.metallic, 0.3))
		sm.set_shader_parameter("rough", maxf(m.roughness, 0.05))
		sm.set_shader_parameter("mode", 4)
		sm.set_shader_parameter("lit_frac", lit_frac)
		sm.set_shader_parameter("gain", gain)
		am.surface_set_material(am.get_surface_count() - 1, sm)
		am.surface_set_name(am.get_surface_count() - 1, keep_name)
		_shaders.append(sm)
		return panes + paint_panes(am, pick, lit_frac, gain, seed + 1)
	return panes

func _process(_delta: float) -> void:
	var wx := Game.weather as Weather
	if wx == null: return
	var night := clampf(wx.night_amount() + wx.storm * 0.25, 0.0, 1.0)
	if absf(night - _last) < 0.01: return
	_last = night
	for sm in _shaders:
		(sm as ShaderMaterial).set_shader_parameter("night", night)
	for e in _mats:
		(e.m as BaseMaterial3D).emission_energy_multiplier = night * float(e.gain) * float(e.base)
	for e in _lights:
		if not is_instance_valid(e.l): continue
		(e.l as Light3D).visible = night > 0.05
		(e.l as Light3D).light_energy = night * float(e.e)
