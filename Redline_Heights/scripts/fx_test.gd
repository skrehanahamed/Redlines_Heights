extends Node
## Dev tool: renders blood, pool and cash to /tmp/rh/fx.png
func _ready() -> void:
	await get_tree().process_frame
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.3, 0.32)
	g.material_override = gm
	add_child(g)
	var model: Node3D = Game.load_character(Game.HERO)
	add_child(model)
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Game.get_anim_library())
	ap.play("Death01")
	ap.seek(ap.get_animation("Death01").length, true)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.5, 0.35, 3.2)
	cam.look_at(Vector3(0, 0.15, 0))
	var l := DirectionalLight3D.new()
	add_child(l)
	l.rotation_degrees = Vector3(-50, 30, 0)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.5, 0.6, 0.7)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(we)
	Fx.pool(self, Vector3.ZERO, 1.5)
	Fx.blood(self, Vector3(0, 0.6, 0), Vector3(1, 0, 0), 1.8)
	Fx.drop_cash(self, Vector3(1.0, 0, 0.5), 25)
	await get_tree().create_timer(0.25).timeout
	Fx.popup(self, Vector3(1.0, 1.2, 0.5), "+$25", Color(0.4, 1, 0.45))
	await get_tree().create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute("/tmp/rh")
	get_viewport().get_texture().get_image().save_png("/tmp/rh/fx.png")
	get_tree().quit()
