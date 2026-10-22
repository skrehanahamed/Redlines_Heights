class_name Blast
extends RefCounted
## Explosions and fire for thrown weapons: damage to pedestrians, cars and the player, plus the visual and sound effects.

static func _hurt_around(tree: SceneTree, at: Vector3, radius: float, dmg: float) -> void:
	for p in tree.get_nodes_in_group("peds"):
		var d := (p as Node3D).global_position - at
		var dist := d.length()
		if dist < radius and p.has_method("hit"):
			p.hit(dmg * (1.0 - dist / radius), d.normalized() + Vector3(0, 0.5, 0), true)
	for c in tree.get_nodes_in_group("cars"):
		var dist := ((c as Node3D).global_position - at).length()
		if dist < radius * 1.2 and "hp" in c:
			c.hp -= dmg * 0.8 * (1.0 - dist / (radius * 1.2))
	var pl := Game.player as Node3D
	if pl != null and is_instance_valid(pl):
		var dp := pl.global_position.distance_to(at)
		if dp < radius:
			Game.health -= dmg * 0.45 * (1.0 - dp / radius)

static func _sound(par: Node, at: Vector3, path: String, vol: float, pitch: float, unit := 30.0) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = load(path) as AudioStream
	a.max_distance = 500.0
	a.unit_size = unit
	a.volume_db = vol
	a.pitch_scale = pitch
	par.add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)

static func _tex(name: String) -> Texture2D:
	return load("res://assets/vfx/%s.png" % name) as Texture2D

## One animated billboard sprite: grows from s0 to s1 (metres across), drifts up by `rise`, fades out in the second half of `life`.
static func _puff(par: Node, tex_name: String, at: Vector3, s0: float, s1: float, life: float, delay: float, rise: float, tint: Color, additive := false) -> void:
	var tex := _tex(tex_name)
	if tex == null: return
	var aspect := float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	if additive: mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.material = mat
	mi.mesh = qm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	par.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3(s0 * aspect, s0, s0)
	var tw := mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: mi.visible = true)
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(s1 * aspect, s1, s1), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position:y", at.y + rise, life)
	tw.tween_property(mat, "albedo_color:a", 0.0, life * 0.5).set_delay(life * 0.5)
	tw.chain().tween_callback(mi.queue_free)

static func _scorch(par: Node, at: Vector3, size: float, secs: float) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex("scorch_01")
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = mat
	mi.mesh = qm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = at + Vector3(0, 0.04, 0)
	mi.rotation.y = randf() * TAU
	var tw := mi.create_tween()
	tw.tween_interval(secs * 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, secs * 0.4)
	tw.tween_callback(mi.queue_free)

static func _rnd_in(radius: float) -> Vector3:
	var v := Vector3(randf_range(-1, 1), randf_range(0.0, 1.0), randf_range(-1, 1))
	return v.normalized() * radius * randf() if v.length() > 0.01 else Vector3.ZERO

## A grenade blast: flash, a rolling fireball made of explosion sprites, a column of black smoke, sparks, a scorch mark and debris.
static func explode(par: Node, at: Vector3, radius := 8.0, dmg := 120.0) -> void:
	var tree := par.get_tree()
	_sound(par, at, "res://assets/audio/guns_and_gameplay/explosion_rocket_01.ogg", 4.0, 1.1)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.7, 0.35)
	fl.light_energy = 18.0
	fl.omni_range = radius * 2.8
	par.add_child(fl)
	fl.global_position = at + Vector3(0, 1.5, 0)
	var lt := fl.create_tween()
	lt.tween_property(fl, "light_energy", 0.0, 0.7)
	lt.tween_callback(fl.queue_free)
	var c0 := at + Vector3(0, 0.8, 0)
	_puff(par, "flash01", c0 + Vector3(0, 0.6, 0), 1.0, radius * 1.1, 0.22, 0.0, 0.5, Color(1, 0.95, 0.8, 1), true)
	_puff(par, "flash00", c0 + Vector3(0, 0.4, 0), 1.0, radius * 0.8, 0.3, 0.02, 0.5, Color(1, 0.85, 0.5, 1), true)
	for k in 16:
		var n := "explosion%02d" % (randi() % 9)
		var p := c0 + _rnd_in(radius * 0.28)
		_puff(par, n, p, radius * 0.12, radius * randf_range(0.42, 0.7), randf_range(0.55, 0.9), randf() * 0.22, randf_range(1.2, 3.5), Color(1, 1, 1, 1))
	for k in 12:
		var n := "blackSmoke%02d" % [[2, 8, 12, 16, 20, 24][randi() % 6]]
		var p := c0 + _rnd_in(radius * 0.25)
		_puff(par, n, p, radius * 0.2, radius * randf_range(0.55, 1.0), randf_range(2.8, 4.5), randf_range(0.15, 0.9), randf_range(5.0, 11.0), Color(1, 1, 1, 0.85))
	for k in 14:
		var d := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized() * radius * randf_range(0.7, 1.4)
		_puff(par, "spark_01" if k % 2 == 0 else "spark_02", c0, 0.5, 0.7, 0.6, 0.0, 0.0, Color(1.0, 0.8, 0.4, 1), true)
		var sp := par.get_child(par.get_child_count() - 1) as Node3D
		if sp != null:
			var tws := sp.create_tween()
			tws.tween_property(sp, "global_position", c0 + d, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scorch(par, at, radius * 1.1, 18.0)
	for k in 10:
		var ch := RigidBody3D.new()
		var cm := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3.ONE * randf_range(0.1, 0.3)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.12, 0.1, 0.09)
		cb.material = cmat
		cm.mesh = cb
		ch.add_child(cm)
		ch.collision_layer = 0
		ch.collision_mask = 1
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = cb.size
		cs.shape = bx
		ch.add_child(cs)
		par.add_child(ch)
		ch.global_position = at + Vector3(0, 0.5, 0)
		ch.linear_velocity = Vector3(randf_range(-6, 6), randf_range(4, 10), randf_range(-6, 6))
		tree.create_timer(4.0).timeout.connect(ch.queue_free)
	var pl := Game.player as Node3D
	if pl != null and is_instance_valid(pl) and pl.global_position.distance_to(at) < radius * 3.0:
		var cam := Game.camera as Camera3D
		if cam != null and cam.has_method("add_shake"): cam.call("add_shake", 1.0)
	_hurt_around(tree, at, radius, dmg)
	Game.add_wanted(2)

## A molotov: a burst of fire that settles into a burning pool of flame sprites, with smoke, for `secs`; it hurts everything standing in it.
static func fire_pool(par: Node, at: Vector3, radius := 3.2, secs := 8.0) -> void:
	var tree := par.get_tree()
	_sound(par, at, "res://assets/audio/guns_and_gameplay/fireball_impact_01.ogg", 2.0, 1.0, 15.0)
	var root := Node3D.new()
	par.add_child(root)
	root.global_position = at
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = radius * 3.5
	light.light_energy = 5.0
	light.position = Vector3(0, 1.2, 0)
	root.add_child(light)
	_scorch(par, at, radius * 2.0, secs + 12.0)
	_puff(par, "flash02", at + Vector3(0, 0.8, 0), 0.8, radius * 1.4, 0.25, 0.0, 0.6, Color(1, 0.8, 0.5, 1), true)
	for k in 8:
		_puff(par, "fire_01" if k % 2 == 0 else "fire_02", at + _rnd_in(radius * 0.6) * Vector3(1, 0.3, 1), 0.8, radius * randf_range(0.8, 1.3), randf_range(0.5, 0.9), randf() * 0.1, randf_range(1.0, 2.5), Color(1.0, 0.65, 0.3, 1), true)
	# glowing ground
	var gm := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(radius * 2.4, radius * 2.4)
	gq.orientation = PlaneMesh.FACE_Y
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = _tex("circle_05")
	gmat.albedo_color = Color(1.0, 0.45, 0.1, 0.8)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gq.material = gmat
	gm.mesh = gq
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(gm)
	gm.position = Vector3(0, 0.06, 0)
	var t := 0.0
	var tick := Timer.new()
	tick.wait_time = 0.1
	root.add_child(tick)
	tick.timeout.connect(func() -> void:
		t += 0.1
		light.light_energy = 3.5 + randf() * 3.0
		gmat.albedo_color.a = 0.55 + randf() * 0.35
		if t < secs:
			for k in 4:
				var a := randf() * TAU
				var r := sqrt(randf()) * radius
				var n := "flame_%02d" % (1 + randi() % 6)
				_puff(par, n, at + Vector3(cos(a) * r, 0.2, sin(a) * r), 1.2, randf_range(3.0, 4.6), randf_range(0.55, 0.9), 0.0, randf_range(1.0, 2.2), Color(1.0, 0.55 + randf() * 0.25, 0.15, 1), true)
			if randf() < 0.35:
				_puff(par, "blackSmoke%02d" % [[2, 8, 12][randi() % 3]], at + Vector3(randf_range(-1, 1), 1.2, randf_range(-1, 1)) * radius * 0.5, 0.8, randf_range(2.0, 3.5), randf_range(2.2, 3.2), 0.0, randf_range(3.0, 5.5), Color(1, 1, 1, 0.55))
		if fmod(t, 0.5) < 0.1 and t < secs:
			_hurt_around(tree, at, radius, 14.0)
		if t >= secs + 3.0:
			root.queue_free())
	tick.start()
	_hurt_around(tree, at, radius, 20.0)
	Game.add_wanted(1)
