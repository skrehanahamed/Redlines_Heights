class_name CanalLights
extends Node
## Night lighting along the canals and channels: bollard lamps on the quays that blink in turn, and lights just under the water
## along both banks that glow and pulse in changing colours. Everything is off in daylight (it follows the night clock).

var posts: Array = []        # [{mat, phase}]
var subs: Array = []         # [{mat, phase, hue}]

static func build(w: World, rects: Array, wall_y := 0.45, water_y := -0.55) -> void:
	var node := CanalLights.new()
	w.static_root.add_child(node)
	var pm := {}
	var sm := {}
	var steel := Miami._flat(Color(0.2, 0.22, 0.26), 0.5, 0.5)
	var k := 0
	for r in rects:
		var rr: Rect2 = r
		var along_x := rr.size.x >= rr.size.y
		var length: float = rr.size.x if along_x else rr.size.y
		var width: float = rr.size.y if along_x else rr.size.x
		var n := int(length / 22.0)
		for i in range(n + 1):
			var t := 6.0 + i * ((length - 12.0) / maxf(n, 1))
			for side in [-1.0, 1.0]:
				var px: float = (rr.position.x + t) if along_x else (rr.position.x + width * 0.5 + side * (width * 0.5 + 1.4))
				var pz: float = (rr.position.y + width * 0.5 + side * (width * 0.5 + 1.4)) if along_x else (rr.position.y + t)
				# the bollard: a slim post and a lamp head whose material blinks
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.9, 0.9, 0.9)
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.25, 0.3) if (k % 2 == 0) else Color(0.2, 0.95, 0.9)
				mat.emission_energy_multiplier = 0.0
				node.posts.append({"mat": mat, "phase": k * 0.7})
				var post := MeshInstance3D.new()
				var pb := BoxMesh.new()
				pb.size = Vector3(0.14, 1.0, 0.14)
				post.mesh = pb
				post.material_override = steel
				post.position = Vector3(px, wall_y + 0.5, pz)
				node.add_child(post)
				var head := MeshInstance3D.new()
				var hb := SphereMesh.new()
				hb.radius = 0.28
				hb.height = 0.56
				head.mesh = hb
				head.material_override = mat
				head.position = Vector3(px, wall_y + 1.12, pz)
				head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(head)
				k += 1
		# the lights under the water, both banks, a metre in from the wall
		var ns := int(length / 7.0)
		for i in range(ns + 1):
			var t2 := 3.0 + i * ((length - 6.0) / maxf(ns, 1))
			for side in [-1.0, 1.0]:
				var sx: float = (rr.position.x + t2) if along_x else (rr.position.x + width * 0.5 + side * (width * 0.5 - 1.2))
				var sz: float = (rr.position.y + width * 0.5 + side * (width * 0.5 - 1.2)) if along_x else (rr.position.y + t2)
				var smat := StandardMaterial3D.new()
				smat.albedo_color = Color(0.5, 0.9, 0.95)
				smat.emission_enabled = true
				smat.emission = Color(0.2, 0.9, 1.0)
				smat.emission_energy_multiplier = 0.0
				smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				node.subs.append({"mat": smat, "phase": i * 0.45 + (0.0 if side < 0.0 else 1.7), "hue": fposmod(i * 0.07, 1.0)})
				var disc := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.7
				cm.bottom_radius = 0.7
				cm.height = 0.03
				cm.radial_segments = 10
				disc.mesh = cm
				disc.material_override = smat
				disc.position = Vector3(sx, water_y - 0.09, sz)
				disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(disc)
		# a few real lights so the water and the quay are lit
		var nl := int(length / 45.0) + 1
		for i in range(nl):
			var t3 := (i + 0.5) * length / nl
			var lx: float = (rr.position.x + t3) if along_x else (rr.position.x + width * 0.5)
			var lz: float = (rr.position.y + width * 0.5) if along_x else (rr.position.y + t3)
			var ol := OmniLight3D.new()
			ol.position = Vector3(lx, water_y + 1.2, lz)
			ol.light_color = Color(0.3, 0.85, 1.0)
			ol.omni_range = 22.0
			ol.distance_fade_enabled = true
			ol.distance_fade_begin = 70.0
			ol.distance_fade_length = 30.0
			node.add_child(ol)
			CityLights.register_light(ol, 1.6)

func _process(_dt: float) -> void:
	var wx := Game.weather as Weather
	var night := 0.0 if wx == null else clampf(wx.night_amount(), 0.0, 1.0)
	var t := Time.get_ticks_msec() * 0.001
	for p in posts:
		# each lamp flashes briefly every 2.4 s, in turn along the canal
		var ph := fposmod(t - float(p.phase) * 0.35, 2.4)
		var on := 1.0 if ph < 0.35 else 0.12
		(p.mat as StandardMaterial3D).emission_energy_multiplier = night * on * 4.0
	for s in subs:
		var pulse := 0.55 + 0.45 * sin(t * 1.6 + float(s.phase))
		var col := Color.from_hsv(fposmod(float(s.hue) * 0.25 + 0.46 + 0.1 * sin(t * 0.3 + float(s.phase)), 1.0), 0.75, 1.0)
		var m := s.mat as StandardMaterial3D
		m.emission = col
		m.emission_energy_multiplier = night * pulse * 5.0
