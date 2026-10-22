class_name Fx
extends RefCounted
## Blood and cash effects for peds that get shot, punched or run over.

static func blood(parent: Node, pos: Vector3, dir: Vector3, amount := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = int(18 * amount)
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = (dir.normalized() + Vector3.UP * 0.6)
	p.spread = 55.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5 + amount
	p.gravity = Vector3(0, -12, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.02, 0.02)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	p.mesh = sm
	parent.add_child(p)
	p.global_position = pos
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)

## A flat blood pool on the ground that spreads out, then fades away.
static func pool(parent: Node, ground_pos: Vector3, size := 1.0) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	m.mesh = q
	var mat := StandardMaterial3D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 0.9, 1.0])
	grad.colors = PackedColorArray([Color(0.35, 0, 0, 0.95), Color(0.4, 0, 0, 0.85), Color(0.3, 0, 0, 0.35), Color(0.3, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	mat.albedo_texture = gt
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3(0.2, 1, 0.2)
	parent.add_child(m)
	m.global_position = Vector3(ground_pos.x, ground_pos.y + 0.03, ground_pos.z)
	m.rotation.y = randf() * TAU
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(1.3 * size, 1, 1.0 * size), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(18.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 4.0)
	tw.tween_callback(m.queue_free)

## Floating "+$25" text.
static func popup(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.6, 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

static func drop_cash(parent: Node, pos: Vector3, value: int) -> void:
	var c := CashPickup.new()
	c.value = value
	parent.add_child(c)
	c.global_position = Vector3(pos.x, pos.y + 0.45, pos.z)

## Crash: sparks, flying glass and a dust puff at the point of impact.
static func crash(parent: Node, pos: Vector3, intensity := 1.0) -> void:
	var sp := CPUParticles3D.new()
	sp.one_shot = true
	sp.emitting = true
	sp.amount = int(24 * intensity)
	sp.lifetime = 0.55
	sp.explosiveness = 1.0
	sp.direction = Vector3.UP
	sp.spread = 75.0
	sp.initial_velocity_min = 3.0
	sp.initial_velocity_max = 8.0 + 3.0 * intensity
	sp.gravity = Vector3(0, -14, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.7, 0.2)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.55, 0.1)
	smat.emission_energy_multiplier = 3.0
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = smat
	sp.mesh = bm
	parent.add_child(sp)
	sp.global_position = pos
	var gl := CPUParticles3D.new()
	gl.one_shot = true
	gl.emitting = true
	gl.amount = int(20 * intensity)
	gl.lifetime = 1.3
	gl.explosiveness = 1.0
	gl.direction = Vector3.UP
	gl.spread = 80.0
	gl.initial_velocity_min = 2.0
	gl.initial_velocity_max = 6.0
	gl.gravity = Vector3(0, -10, 0)
	gl.angular_velocity_min = -540.0
	gl.angular_velocity_max = 540.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.8, 0.92, 1.0, 0.85)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = gmat
	gl.mesh = qm
	parent.add_child(gl)
	gl.global_position = pos + Vector3(0, 0.4, 0)
	var du := CPUParticles3D.new()
	du.one_shot = true
	du.emitting = true
	du.amount = 6
	du.lifetime = 1.6
	du.explosiveness = 0.9
	du.direction = Vector3.UP
	du.spread = 40.0
	du.initial_velocity_min = 0.6
	du.initial_velocity_max = 1.6
	du.gravity = Vector3(0, 0.3, 0)
	du.scale_amount_min = 0.3
	du.scale_amount_max = 0.7
	var dm := SphereMesh.new()
	dm.radius = 0.3
	dm.height = 0.6
	dm.radial_segments = 8
	dm.rings = 4
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.5, 0.5, 0.48, 0.28)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.material = dmat
	du.mesh = dm
	parent.add_child(du)
	du.global_position = pos + Vector3(0, 0.5, 0)
	parent.get_tree().create_timer(2.2).timeout.connect(func():
		for n in [sp, gl, du]:
			if is_instance_valid(n): n.queue_free())

## Water splash: a burst of droplets and a ring that spreads over the surface.
static func splash(parent: Node, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 30
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -12, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	p.mesh = sm
	parent.add_child(p)
	p.global_position = pos
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.6
	tm.rings = 16
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1, 1, 1, 0.7)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.scale = Vector3(1, 0.15, 1)
	parent.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.05, 0)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(4.5, 0.15, 4.5), 1.0)
	tw.tween_property(rm, "albedo_color:a", 0.0, 1.0)
	tw.chain().tween_callback(ring.queue_free)
	parent.get_tree().create_timer(1.3).timeout.connect(p.queue_free)
