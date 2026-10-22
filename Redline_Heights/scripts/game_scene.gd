extends Node3D
## The playable scene: builds the world, player, vehicles, pedestrians, HUD.

var world: World
var player: Player
var cam: ThirdPersonCamera
var hud: HUD
var audio: AudioManager
var rng := RandomNumberGenerator.new()
var test_car: Car

func _go_windowed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == Vector2i(1280, 720): return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var sz := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((sz - Vector2i(1280, 720)) / 2)

func _ready() -> void:
	# tests run in a normal window in the middle of the screen (the project itself starts fullscreen)
	if "--windowed" in OS.get_cmdline_user_args():
		_go_windowed()
		for dly in [0.5, 1.5, 3.0, 5.0]:
			get_tree().create_timer(dly).timeout.connect(_go_windowed)
	Game.reset_state()
	rng.seed = 777
	var args := OS.get_cmdline_user_args()
	var overlay := _loading_overlay()
	await get_tree().process_frame
	await get_tree().process_frame
	world = World.new()
	world.name = "World"
	add_child(world)
	Game.world = world
	world.progress.connect(_on_load_progress)
	await world.build()
	_on_load_progress(0.98, "Starting")
	await get_tree().process_frame
	_spawn_player()
	hud = HUD.new()
	add_child(hud)
	# NPC cars and people are switched off for now; run with --npcs to bring them back
	if "--npcs" in args:
		if not "--nopeds" in args: add_child(PedManager.new())
		if not "--notraffic" in args: add_child(TrafficManager.new())
		add_child(PoliceManager.new())
		if not "--nopop" in args: add_child(Population.new())
	var wx := Weather.new()
	add_child(wx)
	Game.weather = wx
	add_child(DevMode.new())
	if not "--nonight" in args: add_child(NightLights.new())
	var rules := Rules.new()
	rules.hud = hud
	rules.respawn_point = world.hospital_spawn
	add_child(rules)
	audio = AudioManager.new()
	add_child(audio)
	var tex := load("res://assets/map/city_map.png") as Texture2D
	hud.set_map(tex, World.MAP_HALF, load("res://assets/map/city_minimap.png") as Texture2D)
	hud.set_pois(world.pois)
	if "--mapshot" in OS.get_cmdline_user_args():
		await _wait(1.5)
		DirAccess.make_dir_recursive_absolute("/tmp/rh")
		tex.get_image().save_png("/tmp/rh/map.png")
		get_tree().quit()
		return
	await get_tree().process_frame
	await get_tree().process_frame
	overlay.queue_free()
	for a in args:
		if a.begins_with("--at="):
			var av := a.substr(5).split(",")
			player.global_position = Vector3(float(av[0]), 1.0, float(av[1]))
		if a.begins_with("--cam="):
			var v := a.substr(6).split(",")
			var cc := Camera3D.new()
			add_child(cc)
			cc.far = 5000.0
			cc.fov = 70.0
			cc.look_at_from_position(Vector3(float(v[0]), float(v[1]), float(v[2])), Vector3(float(v[3]), float(v[4]), float(v[5])), Vector3.UP)
			cc.current = true
	if "--overview" in args:
		var oc := Camera3D.new()
		add_child(oc)
		oc.far = 3000.0
		oc.look_at_from_position(Vector3(-190, 150, 330), Vector3(0, 10, 0), Vector3.UP)
		oc.current = true
	if "--drivetest" in args:
		_drive_test()
	if "--livetest" in args:
		_live_test()
	if "--pistoltest" in args:
		player.weapon = 1
		player.force_aim = true
		player.pistol_node.visible = true
		cam.yaw = PI + 0.5
	if "--driveshot" in args:
		_drive_demo()
	if "--hudtest" in args:
		await _wait(1.0)
		var mmn := hud.find_child("Minimap", true, false) as Control
		print("TEST minimap rect: ", mmn.get_global_rect(), " viewport: ", get_viewport().get_visible_rect().size)
		for ch in mmn.get_children():
			print("TEST   child ", ch.name, " ", (ch as Control).get_global_rect())
		get_tree().quit()
	if "--rulestest" in args:
		_rules_test()
	if "--entertest" in args:
		_enter_test()
	if "--entershots" in args:
		_enter_shots()
	if "--animtest" in args:
		_anim_test()
	if "--radiotest" in args:
		_radio_test()
	if "--ambtest" in args:
		_amb_test()
	if "--ambbrake" in args:
		_amb_brake()
	if "--npcs" in args:
		_npc_lineup()
	if "--lights" in args:
		_lights_test()
	if "--station" in args:
		_station_view()
	if "--metro" in args:
		_metro_view()
	if "--shop" in args:
		_shop_view()
	if "--throwtest" in args:
		_throw_test()
	if "--boattest" in args:
		_boat_test()
	if "--raintest" in args:
		await _wait(2.0)
		var wxr := Game.weather as Weather
		wxr.state = "storm"
		wxr.rain = 1.0
		wxr.storm = 0.6
		var cc4 := Camera3D.new()
		add_child(cc4)
		cc4.far = 3000.0
		cc4.look_at_from_position(Vector3(-690.0, 3.0, 2200.0), Vector3(-720.0, -0.5, 2200.0), Vector3.UP)
		cc4.make_current()
		await _wait(2.0)
		await _shot("rain_sea")
		cc4.look_at_from_position(Vector3(-715.0, 14.0, 2200.0), Vector3(-722.0, -0.5, 2200.0), Vector3.UP)
		await _wait(0.5)
		await _shot("rain_sea_top")
		get_tree().quit()
	if "--wadetest" in args:
		await _wait(2.5)
		player.global_position = Vector3(-684.0, 0.3, 2200.0)
		cam.yaw = PI * 0.5
		Input.action_press("move_forward")
		await _wait(2.0)
		print("WADE swimming=", player.swimming, " anim=", player.cur_anim, " pos=", player.global_position)
		await _shot("wade")
		await _wait(4.0)
		await _shot("swim_fx")
		print("SWIMFX swimming=", player.swimming, " anim=", player.cur_anim)
		Input.action_release("move_forward")
		get_tree().quit()
	if "--swimtest" in args:
		await _wait(2.5)
		player.global_position = Vector3(-690.0, 0.3, 2200.0)
		await _wait(1.5)
		var cc5 := Camera3D.new()
		add_child(cc5)
		cc5.far = 2000.0
		cc5.make_current()
		for state in ["idle", "swim", "dive"]:
			Input.action_release("move_forward")
			Input.action_release("walk_slow")
			if state != "idle": Input.action_press("move_forward")
			if state == "dive": Input.action_press("walk_slow")
			cam.yaw = PI * 0.5
			await _wait(2.5)
			var pp := player.global_position
			var f := Vector3(sin(player.face), 0, cos(player.face))
			var r := Vector3(f.z, 0, -f.x)
			for v in [["front", f * 3.2 + Vector3(0, 1.2, 0)], ["back", -f * 3.2 + Vector3(0, 1.4, 0)], ["left", -r * 3.2 + Vector3(0, 0.9, 0)], ["right", r * 3.2 + Vector3(0, 0.9, 0)], ["top", Vector3(0, 4.2, 0.05)]]:
				var cpos: Vector3 = pp + v[1]
				if state != "dive": cpos.y = maxf(cpos.y, -0.2)
				cc5.look_at_from_position(cpos, Vector3(pp.x, maxf(pp.y + 0.9, -0.5), pp.z), Vector3.UP if v[0] != "top" else Vector3(0, 0, -1))
				await _wait(0.15)
				await _shot("sw_%s_%s" % [state, v[0]])
			print("SWIM ", state, ": swimming=", player.swimming, " diving=", player.diving, " anim=", player.cur_anim, " y=", snappedf(player.global_position.y, 0.01))
		Input.action_release("move_forward")
		Input.action_release("walk_slow")
		get_tree().quit()
	if "--floatcheck" in args:
		await _wait(3.5)
		var space := get_viewport().world_3d.direct_space_state
		var stats := {}
		var worst := []
		for e in BeachLife.put_log:
			var n: Node3D = e.node
			if not is_instance_valid(n): continue
			var excl: Array[RID] = []
			for b in n.find_children("*", "CollisionObject3D", true, false): excl.append((b as CollisionObject3D).get_rid())
			var low := 1e9
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				low = minf(low, bb.position.y)
			var q := PhysicsRayQueryParameters3D.create(n.global_position + Vector3(0, 6, 0), n.global_position + Vector3(0, -8, 0), 1)
			q.exclude = excl
			var hit := space.intersect_ray(q)
			if hit.is_empty(): continue
			var gap: float = low - float(hit.position.y)
			var k := String(e.kind)
			if not stats.has(k): stats[k] = []
			(stats[k] as Array).append(gap)
			worst.append([gap, k, n.global_position])
		worst.sort_custom(func(a, b): return absf(a[0]) > absf(b[0]))
		for k in stats:
			var arr: Array = stats[k]
			var mn := 1e9
			var mx := -1e9
			var avg := 0.0
			for g in arr:
				mn = minf(mn, g)
				mx = maxf(mx, g)
				avg += g
			print("FLOAT ", k, " n=", arr.size(), " gap min ", snappedf(mn, 0.01), " avg ", snappedf(avg / arr.size(), 0.01), " max ", snappedf(mx, 0.01))
		for i in mini(6, worst.size()): print("FLOATWORST ", worst[i][1], " gap ", snappedf(worst[i][0], 0.01), " at ", worst[i][2])
		for e in BeachLife.put_log:
			if String(e.kind).begins_with("palm_tree_pack"):
				var n2: Node3D = e.node
				print("PALMPACK node y ", n2.global_position.y, " scale ", n2.scale, " rot ", n2.rotation)
				for mi in n2.find_children("*", "MeshInstance3D", true, false):
					var bb2: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
					print("PALMPACK   ", mi.name, " y ", snappedf(bb2.position.y, 0.1), "..", snappedf(bb2.end.y, 0.1), " x ", snappedf(bb2.position.x, 0.1), "..", snappedf(bb2.end.x, 0.1), " is_queued ", mi.is_queued_for_deletion())
				break
		get_tree().quit()
	if "--propshots" in args:
		await _wait(3.5)
		var cc6 := Camera3D.new()
		add_child(cc6)
		cc6.far = 2500.0
		cc6.make_current()
		var want := ["lambis_shell", "seashell", "beachwood", "dead_tree", "palm_tree_pack", "coconut_palm", "pelican", "crab", "fern", "grass_medium"]
		var done := {}
		for e in BeachLife.put_log:
			var k := String(e.kind)
			var key := ""
			for wk in want:
				if k.begins_with(wk): key = wk
			if key == "" or done.has(key): continue
			done[key] = true
			var nn: Node3D = e.node
			var bbp := AABB()
			var first := true
			for mi in nn.find_children("*", "MeshInstance3D", true, false):
				var bq: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				bbp = bq if first else bbp.merge(bq)
				first = false
			var ctr := bbp.get_center()
			var rr := maxf(bbp.size.length() * 1.1, 1.0)
			cc6.look_at_from_position(ctr + Vector3(rr * 0.9, rr * 0.35, rr * 0.9), ctr, Vector3.UP)
			await _wait(0.25)
			await _shot("prop_%s" % key)
			print("PROP ", key, " size ", bbp.size.snapped(Vector3(0.01, 0.01, 0.01)), " low ", snappedf(bbp.position.y, 0.01))
		get_tree().quit()
	if "--ualtest" in args:
		await _wait(3.0)
		player.global_position = Vector3(-60.0, 0.6, 2426.0)
		var cc7 := Camera3D.new()
		add_child(cc7)
		cc7.make_current()
		for nm in ["UAL_Idle", "UAL_Walk", "Swim_Fwd", "Swim_Idle"]:
			player.set_physics_process(false)
			player.anim.play(nm)
			player.anim.speed_scale = 0.0
			player.anim.seek(0.5, true)
			await _wait(0.3)
			var pp := player.global_position
			cc7.look_at_from_position(pp + Vector3(sin(player.face), 0.0, cos(player.face)) * 3.5 + Vector3(0, 1.0, 0), pp + Vector3(0, 0.9, 0), Vector3.UP)
			await _wait(0.2)
			await _shot("ual_" + nm)
			cc7.look_at_from_position(pp + Vector3(cos(player.face), 0.0, -sin(player.face)) * 3.5 + Vector3(0, 1.0, 0), pp + Vector3(0, 0.9, 0), Vector3.UP)
			await _wait(0.2)
			await _shot("ual_side_" + nm)
		get_tree().quit()
	if "--lifetest" in args:
		await _wait(3.0)
		var bad := 0
		var inside := 0
		var total := 0
		for step in 600:
			for c in Game.world.static_root.get_children():
				if not (c is SeaCreature): continue
				var sc := c as SeaCreature
				sc._process(0.5)
				if sc.base_y > 5.0: continue                  # birds
				var q := sc.global_position
				total += 1
				if sc.ground:
					if q.y < Coast.height_at(q.x, q.z) - 0.05 or Coast.is_water(q.x, q.z): bad += 1
				else:
					if not Coast.is_water(q.x, q.z): bad += 1
					elif q.y < Coast.height_at(q.x, q.z) + 0.3: inside += 1        # swimming inside the seabed
		print("LIFE steps checked ", total, " out of place ", bad, " inside seabed ", inside)
		var cc := Camera3D.new()
		add_child(cc)
		cc.far = 3000.0
		cc.make_current()
		var seen := {}
		for c in Game.world.static_root.get_children():
			if c is SeaCreature and (c as SeaCreature).base_y < 5.0:
				var sc2 := c as SeaCreature
				var key := ("horse" if sc2.ground else "") + str(sc2.model.get_child_count()) + str(int(sc2.speed * 10.0))
				if seen.has(key): continue
				seen[key] = true
				var pos := sc2.global_position
				var f := Vector3(sin(sc2.yaw), 0, cos(sc2.yaw))
				cc.look_at_from_position(pos + f * -7.0 + Vector3(f.z, 0, -f.x) * 4.0 + Vector3(0, 2.5, 0), pos, Vector3.UP)
				await _wait(0.5)
				await _shot("life_%d" % seen.size())
		print("LIFE shots ", seen.size())
		get_tree().quit()
	if "--spawntest" in args:
		await _wait(2.5)
		print("SPAWN player at ", player.global_position, " floor ", player.is_on_floor(), " ground ", Coast.height_at(player.global_position.x, player.global_position.z))
		get_tree().quit()
	if "--islwalk" in args:
		_isl_walk()
	if "--islview" in args:
		_isl_view()
	if "--gripedit" in args:
		_grip_edit_test()
	if "--weapons" in args:
		_weapons_view()
	if "--shopwalk" in args:
		_shop_walk()
	if "--gunmenu" in args:
		_gunmenu_shots()
	if "--boards" in args:
		_board_view()
	if "--trainlamps" in args:
		_train_lamps()
	if "--floods" in args:
		_flood_view()
	if "--fair" in args:
		_fair_view()
	if "--nightview" in args:
		_night_view()
	if "--ait" in args:
		_ait_view()
	if "--gt" in args:
		_cruiser_views("factory_gt", "gt")
	if "--cruiser" in args:
		_cruiser_views()
	if "--ambviews" in args:
		_amb_views()
	if "--exitfast" in args:
		_exit_fast_test()
	if "--exitwall" in args:
		_exit_wall_test()
	if "--housedrive" in args:
		_houses_drive()
	if "--trainhit" in args:
		_train_hit()
	if "--trackdrive" in args:
		_track_drive()
	if "--camdrive" in args:
		_cam_drive()
	if "--planecam" in args:
		_plane_cam()
	if "--planetest" in args:
		_plane_test()
	if "--heliride" in args:
		_heli_ride()
	if "--perf" in args:
		_perf()
	if "--golftest" in args:
		_golf_test()
	if "--a2test" in args:
		_a2_test()
	if "--b2test" in args:
		_b2_test()
	if "--planebail" in args:
		_plane_bail()
	if "--chute" in args:
		_chute_fit()
	if "--bailout" in args:
		_bailout_test()
	if "--helitest" in args:
		_heli_test()
	if "--combat" in args:
		_combat()
	if "--shots" in args:
		_shots()
	if "--mapui" in args:
		await _wait(2.0)
		hud._toggle_map()
		print("MAPDBG open=", hud.map_open, " vis=", hud.map_panel.visible, " paused=", get_tree().paused, " tex=", hud.map_texture)
		await _wait(0.6)
		await _shot("mapui")
		get_tree().quit()
	if "--hurtshot" in args:
		await _wait(2.0)
		var car0: Car = test_car
		Fx.crash(self, player.global_position + Vector3(1.5, 0.5, 2.5), 1.6)
		Fx.blood(self, player.global_position + Vector3(0, 1.2, 1.0), Vector3.FORWARD, 1.5)
		Game.health -= 22.0
		await _wait(0.35)
		await _shot("hurt")
		get_tree().quit()
	if "--coptest" in args:
		_cop_test()
	if "--swimtest" in args:
		await _wait(2.0)
		var spot := Vector3.ZERO
		var found := false
		for r in range(60, 1100, 20):
			for a in range(24):
				var q := Vector2.from_angle(a * TAU / 24.0) * r
				if CityData.zone_at(q.x, q.y) == CityData.Z_SEA and CityData.height_at(q.x, q.y) < -3.0:
					spot = Vector3(q.x, 0.5, q.y)
					found = true
					break
			if found: break
		print("TEST swim pre: state=%d in_car=%s" % [player.state, Game.in_car])
		player.global_position = spot
		cam.yaw = 0.6
		cam.pitch = 0.35
		await _wait(2.5)
		print("TEST swim: spot=%s swimming=%s anim=%s y=%.2f" % [spot, player.swimming, player.cur_anim, player.global_position.y])
		Input.action_press("move_forward")
		await _wait(1.5)
		print("TEST swim moving: anim=%s pos=%s" % [player.cur_anim, player.global_position])
		await _shot("swim")
		Input.action_release("move_forward")
		get_tree().quit()
	if "--jacktest" in args:
		_jack_test()
	if "--groundtest" in args:
		_ground_test()
	if "--runovertest" in args:
		_runover_test()
	if "--snapshot" in args:
		await _wait(6.0 if "--late" in args else 1.5)
		var img := get_viewport().get_texture().get_image()
		if img:
			DirAccess.make_dir_recursive_absolute("/tmp/rh")
			img.save_png("/tmp/rh/in_game_shot.png")
			print("SHOT window mode=", get_window().mode, " size=", get_window().size, " image=", img.get_size(), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " fps=", Performance.get_monitor(Performance.TIME_FPS))
		get_tree().quit()

var _load_bar: ProgressBar
var _load_text: Label

func _on_load_progress(frac: float, text: String) -> void:
	if _load_bar != null and is_instance_valid(_load_bar):
		_load_bar.value = frac * 100.0
	if _load_text != null and is_instance_valid(_load_text):
		_load_text.text = text.to_upper() + "..."

func _loading_overlay() -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = 100
	var tr := TextureRect.new()
	tr.texture = load("res://assets/ui/loading_0%d.png" % (1 + rng.randi() % 5)) as Texture2D
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cl.add_child(tr)
	var l := Label.new()
	l.text = "LOADING..."
	l.add_theme_font_override("font", load("res://assets/ui/fonts/BebasNeue-Regular.ttf"))
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.position = Vector2(-240, -80)
	cl.add_child(l)
	# a progress bar along the bottom with what is being built under it
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 80.0
	bar.offset_right = -80.0
	bar.offset_top = -46.0
	bar.offset_bottom = -30.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(8)
	bg.set_border_width_all(2)
	bg.border_color = Color("#e8d9a0")
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#ffd84a")
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	cl.add_child(bar)
	_load_bar = bar
	var what := Label.new()
	what.text = "STARTING..."
	what.add_theme_font_override("font", load("res://assets/ui/fonts/BebasNeue-Regular.ttf"))
	what.add_theme_font_size_override("font_size", 26)
	what.add_theme_color_override("font_outline_color", Color.BLACK)
	what.add_theme_constant_override("outline_size", 6)
	what.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	what.position = Vector2(84, -86)
	cl.add_child(what)
	_load_text = what
	add_child(cl)
	return cl

## Where the player starts: on the street in front of the central metro entrance (beside the Atlanta office).
const START_POS := Vector3(-60.0, 0.6, 2426.0)         # Redline Island, beside the metro entrance

func _spawn_player() -> void:
	player = Player.new()
	player.position = START_POS
	add_child(player)
	cam = ThirdPersonCamera.new()
	cam.player = player
	add_child(cam)
	player.cam = cam
	cam.yaw = PI                                 # looking south, at the metro entrance
	if not ("--freemouse" in OS.get_cmdline_user_args()):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Starter car: parked right at the curb next to the player
	var c := Car.new()
	c.position = START_POS + Vector3(-3.5, 0.2, 0.0)
	c.rotation.y = PI * 0.5                      # along the east-west street, nose east
	add_child(c)
	c.setup("fumi", "", false)
	c.scripted = false
	test_car = c
	# a GT sports car parked behind it
	var gt := Car.new()
	gt.position = START_POS + Vector3(-12.0, 0.2, 0.0)
	gt.rotation.y = PI * 0.5
	add_child(gt)
	gt.setup("factory_gt", "", false)



func _spawn_homie(char_id: String, pos: Vector3, rot_y: float, anim_name: String) -> Node3D:
	var homie := Game.load_character(char_id)
	homie.position = pos
	homie.rotation.y = rot_y
	add_child(homie)
	var ap := AnimationPlayer.new()
	homie.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Game.get_anim_library(char_id))
	if ap.has_animation(anim_name): ap.play(anim_name)
	return homie

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout

func _combat() -> void:
	await _wait(2.0)
	var peds_before := get_tree().get_nodes_in_group("peds").size()
	# line up three peds in front of the hero and shoot them
	var f := Vector3(sin(player.face), 0, cos(player.face))
	for i in range(3):
		var ped := Ped.new()
		add_child(ped)
		ped.global_position = player.global_position + f * (5.0 + i * 1.5) + Vector3(0, 0.3, 0)
		ped.setup("Male/Character_12", [ped.global_position], 0, 1)
	player.weapon = 1
	Input.action_press("aim")
	player.force_aim = true
	cam.yaw = atan2(-f.x, -f.z) + PI
	cam.pitch = 0.2
	await _wait(0.5)
	Input.action_press("attack")
	for k in range(30):
		await _wait(0.2)
	Input.action_release("attack")
	Input.action_release("aim")
	player.force_aim = false
	var dead := get_tree().get_nodes_in_group("bodies").size()
	print("TEST combat: peds before=%d bodies=%d ammo=%d wanted=%d" % [peds_before, dead, player.ammo, Game.wanted])
	get_tree().quit()

func _jack_test() -> void:
	await _wait(6.0)
	var tcs := get_tree().get_nodes_in_group("traffic")
	var tc: TrafficCar = null
	var best := 1e9
	for t in tcs:
		var d := (t as Node3D).global_position.distance_to(player.global_position)
		if d < best:
			best = d
			tc = t
	print("TEST jack: %d traffic cars, using %s %s at %.0f m" % [tcs.size(), tc.kind, tc.paint, best])
	# stand beside the car's driver door while it is moving: it must stop
	# step into the road ahead of the car: it must brake and stop
	var fwd := Vector3(sin(tc.rotation.y), 0, cos(tc.rotation.y))
	player.global_position = tc.global_position + fwd * 10.0
	await _wait(2.5)
	# then walk to the driver's door
	player.global_position = tc.global_position + tc.global_transform.basis.x * 2.0
	var p0 := tc.global_position
	for k in range(5):
		await _wait(0.5)
		print("TEST jack dbg: dist=%.1f speed=%.1f player=%s tc=%s in_car=%s gp=%s" % [tc.global_position.distance_to(player.global_position), tc.speed, player.global_position, tc.global_position, Game.in_car, Game.player == player])
	print("TEST jack: traffic car held, moved %.1f m, speed %.1f" % [tc.global_position.distance_to(p0), tc.speed])
	var peds_before := get_tree().get_nodes_in_group("peds").size()
	player._try_enter_car()
	if "--jackshots" in OS.get_cmdline_user_args():
		cam.yaw = atan2(-(player.global_position.x - tc.global_position.x), -(player.global_position.z - tc.global_position.z)) + 0.9
		for k in range(9):
			await _wait(0.3)
			await _shot("jack_%d" % k)
	await _wait(0.3)
	print("TEST jack: state=%d active_car=%s traffic left=%d peds %d -> %d wanted=%d" % [player.state, player.active_car.kind if player.active_car else "none", get_tree().get_nodes_in_group("traffic").size(), peds_before, get_tree().get_nodes_in_group("peds").size(), Game.wanted])
	await _wait(2.5)
	print("TEST jack: state=%d in_car=%s" % [player.state, Game.in_car != null])
	if Game.in_car != null:
		var c := Game.in_car as Car
		c.scripted = true
		c.s_throttle = 1.0
		await _wait(2.0)
		print("TEST jack: driving the stolen car at %.1f km/h" % (absf(c.speed_ms) * 3.6))
	get_tree().quit()

func _cop_test() -> void:
	await _wait(2.0)
	Game.wanted = 2
	var f := Vector3(sin(player.face), 0, cos(player.face))
	var car := Car.new()
	add_child(car)
	var dist_to_car := 6.5 if "--copexit" in OS.get_cmdline_user_args() else 14.0
	car.global_position = player.global_position + f * dist_to_car + Vector3(0, 0.8, 0)
	car.rotation.y = player.face + PI * 0.5
	car.setup("police", "", false)
	car.make_police()
	var hp0 := Game.health
	if "--copexit" in OS.get_cmdline_user_args():
		cam.yaw = player.face + PI + 0.35
		cam.pitch = 0.1
		for k in range(8):
			await _wait(0.2)
			await _shot("copexit_%d" % k)
		get_tree().quit()
		return
	for k in range(30):
		await _wait(0.5)
		var cops := get_tree().get_nodes_in_group("cops")
		if k % 2 == 0 or Game.dead:
			print("TEST cop t=%.1f cops=%d health=%.0f wanted=%d dead=%s car_chase=%s" % [(k + 1) * 0.5, cops.size(), Game.health, Game.wanted, Game.dead, car.ai_chase])
		if k == 7 and "--copshot" in OS.get_cmdline_user_args():
			cam.yaw = player.face + PI
			await _wait(0.4)
			await _shot("cops")
		if Game.dead: break
	print("TEST cop result: health %.0f -> %.0f, dead=%s, busted-state never used" % [hp0, Game.health, Game.dead])
	get_tree().quit()

func _heli_test() -> void:
	await _wait(2.0)
	Game.wanted = 5
	var hp0 := Game.health
	for k in range(150):
		await _wait(0.5)
		var helis := get_tree().get_nodes_in_group("heli")
		if k % 4 == 0 or Game.dead:
			var d := -1.0
			if not helis.is_empty():
				d = ((helis[0] as Node3D).global_position - player.global_position).length()
			print("TEST heli t=%.1f helis=%d dist=%.0f health=%.0f dead=%s" % [(k + 1) * 0.5, helis.size(), d, Game.health, Game.dead])
		if k == 14 and "--heliscreen" in OS.get_cmdline_user_args() and not helis.is_empty():
			var hc := Camera3D.new()
			add_child(hc)
			var hp := (helis[0] as Node3D).global_position
			hc.look_at_from_position(hp + Vector3(16, -4, 22), hp, Vector3.UP)
			hc.current = true
			await _wait(0.3)
			await _shot("heli")
			hc.queue_free()
		if Game.dead: break
	Game.wanted = 0
	await _wait(8.0)
	print("TEST heli after stars cleared: %d" % get_tree().get_nodes_in_group("heli").size())
	get_tree().quit()

func _heli_ride() -> void:
	await _wait(2.0)
	var sp := world.heli_spawn
	player.global_position = sp + Vector3(5.0, 0.0, 0.0)
	await _wait(0.5)
	print("TEST ride: heli at %s, near=%s" % [sp, player.nearest_heli(7.0) != null])
	var h := player.nearest_heli(7.0)
	h.enter(player)
	print("TEST ride: entered=%s visible=%s" % [Game.in_heli != null, player.visible])
	Input.action_press("jump")
	await _wait(6.0)
	print("TEST ride: climbing alt=%.1f engine=%.2f" % [h.height_above_ground(), h.engine])
	Input.action_release("jump")
	Input.action_press("move_forward")
	await _wait(5.0)
	var moved := h.global_position.distance_to(sp)
	print("TEST ride: forward moved=%.0f m speed=%.0f alt=%.1f fps=%d draw=%d" % [moved, h.vel.length(), h.height_above_ground(), Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	if "--rideshot" in OS.get_cmdline_user_args():
		await _shot("ride")
	Input.action_release("move_forward")
	Input.action_press("walk_slow")
	await _wait(9.0)
	Input.action_release("walk_slow")
	print("TEST ride: descending alt=%.1f" % h.height_above_ground())
	var ok := h.try_exit()
	print("TEST ride: exit=%s state in_heli=%s visible=%s" % [ok, Game.in_heli != null, player.visible])
	get_tree().quit()

## Dev: block 3 (Redline Golf Club) - carts, clubhouse door, staff, then rides a golf cart (pictures golf_*). Pass --golfnight for the lights.
func _golf_test() -> void:
	await _wait(3.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.fov = 65.0
	var views := [
		["n_carts", Vector3(60.0, 3.0, 2340.0), Vector3(57.0, 0.8, 2326.5)],
		["n_course", Vector3(40.0, 6.0, 2300.0), Vector3(110.0, 1.0, 2345.0)],
		["n_front", Vector3(98.0, 3.0, 2300.0), Vector3(98.0, 3.0, 2334.0)],
		["n_tower", Vector3(60.0, 4.0, 2262.0), Vector3(15.0, 15.0, 2262.0)],
		["sofa_game", Vector3(92.5, 3.2, 2334.0), Vector3(89.0, 0.4, 2337.5)],
		["sofa_top", Vector3(89.0, 5.0, 2336.65), Vector3(89.0, 0.0, 2336.6)],
		["sofa_a", Vector3(94.0, 2.2, 2333.0), Vector3(89.0, 0.8, 2336.6)],
		["sofa_b", Vector3(86.0, 2.0, 2341.0), Vector3(89.0, 0.7, 2336.0)],
		["talk", Vector3(99.0, 2.0, 2339.0), Vector3(95.0, 1.0, 2342.7)],
		["recep", Vector3(102.2, 1.6, 2329.2), Vector3(102.2, 0.9, 2332.0)],
		["talk2", Vector3(95.0, 2.0, 2335.0), Vector3(91.8, 1.0, 2331.6)],
		["bar", Vector3(103.0, 2.2, 2333.0), Vector3(107.4, 1.2, 2337.4)],
		["gate", Vector3(94.0, 2.4, 2203.5), Vector3(101.0, 1.4, 2221.0)],
	]
	for v in views:
		cc.look_at_from_position(v[1], v[2], Vector3.UP)
		cc.make_current()
		if v[0] == "door_open":
			pass
		await _wait(0.8)
		await _shot("golf_%s" % v[0])
	# door open: the player walks to the doorway
	player.global_position = Vector3(97.0, 0.6, 2322.0)
	if "--sofaonly" in OS.get_cmdline_user_args():
		get_tree().quit()
	cc.look_at_from_position(Vector3(98.0, 2.2, 2310.0), Vector3(97.0, 2.0, 2327.7), Vector3.UP)
	await _wait(2.5)
	await _shot("golf_door_open")
	# ride a cart
	player.global_position = Vector3(46.0 + 4.4 * 2.5 + 1.8, 0.6, 2326.5)
	await _wait(0.5)
	var c := player.nearest_car(6.0)
	print("GOLF nearest car ", c, " kind ", c.kind if c else "-")
	player._try_enter_car()
	for i in range(8):
		await _wait(0.5)
		if i == 2 or i == 5:
			cc.look_at_from_position(c.global_position + Vector3(2.4, 0.9, 0.5) if i == 2 else c.global_position + Vector3(-2.4, 0.9, -0.5), c.global_position + Vector3(0, 0.8, 0), Vector3.UP)
			cc.make_current()
			await _shot("golf_ride_%d" % i)
	print("GOLF state ", player.state, " in_car ", Game.in_car)
	(Game.camera as Camera3D).make_current()
	Input.action_press("move_forward")
	await _wait(3.5)
	await _shot("golf_drive")
	Input.action_press("move_left")
	await _wait(2.0)
	print("GOLF speed ", c.speed_ms, " pos ", c.global_position, " wheel rot ", c.wheels[2].rotation_degrees, " steer ", c.steering)
	await _shot("golf_drive_turn")
	Input.action_release("move_left")
	await _wait(1.5)
	await _shot("golf_drive2")
	print("GOLF speed ", c.speed_ms)
	get_tree().quit()

## Dev: block A2 (Medical District) from the air and the street (pictures a2_*).
func _a2_test() -> void:
	await _wait(3.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 3000.0
	cc.fov = 65.0
	var views := [
		["top", Vector3(300.0, 360.0, 2325.0), Vector3(300.0, 0.0, 2325.1)],
		["north_row", Vector3(260.0, 12.0, 2190.0), Vector3(260.0, 3.0, 2225.0)],
		["north_row2", Vector3(340.0, 5.0, 2203.0), Vector3(330.0, 4.0, 2225.0)],
		["avenue", Vector3(300.0, 8.0, 2214.0), Vector3(300.0, 4.0, 2340.0)],
		["bay", Vector3(300.0, 7.0, 2335.0), Vector3(285.0, 2.5, 2370.0)],
		["bay2", Vector3(270.0, 1.8, 2358.0), Vector3(280.0, 0.6, 2371.0)],
		["bay3", Vector3(292.0, 1.5, 2380.0), Vector3(276.0, 0.5, 2370.0)],
		["helipad", Vector3(330.0, 9.0, 2350.0), Vector3(358.0, 2.0, 2372.0)],
		["tower_w", Vector3(290.0, 12.0, 2340.0), Vector3(244.0, 15.0, 2392.0)],
		["tower_e", Vector3(310.0, 30.0, 2350.0), Vector3(362.0, 40.0, 2420.0)],
		["park", Vector3(250.0, 6.0, 2234.0), Vector3(250.0, 1.5, 2290.0)],
		["plaza", Vector3(318.0, 5.0, 2268.0), Vector3(300.0, 1.5, 2292.0)],
	]
	for v in views:
		cc.look_at_from_position(v[1], v[2], Vector3.UP)
		cc.make_current()
		await _wait(0.9)
		await _shot("a2_%s" % v[0])
	print("A2 ground heights ", Coast.height_at(300.0, 2300.0), " ", Coast.height_at(220.0, 2220.0), " ", Coast.height_at(380.0, 2420.0))
	get_tree().quit()

## Dev: block B2 (police + fire) from the air and the street (pictures b2_*).
func _b2_test() -> void:
	await _wait(3.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 3000.0
	cc.fov = 65.0
	var views := [
		["top", Vector3(300.0, 330.0, 2075.0), Vector3(300.0, 0.0, 2075.1)],
		["south", Vector3(300.0, 10.0, 2230.0), Vector3(300.0, 4.0, 2160.0)],
		["gate_p", Vector3(254.0, 4.0, 2214.0), Vector3(254.0, 2.0, 2170.0)],
		["gate_f", Vector3(346.0, 4.0, 2214.0), Vector3(346.0, 2.0, 2170.0)],
		["roads", Vector3(298.0, 30.0, 2110.0), Vector3(298.0, 0.0, 2070.0)],
		["inside_p", Vector3(236.0, 3.0, 2176.0), Vector3(250.0, 4.0, 2130.0)],
		["q_p", Vector3(262.0, 8.0, 2150.0), Vector3(280.0, 4.0, 2122.0)],
		["q_f", Vector3(335.0, 8.0, 2160.0), Vector3(318.0, 4.0, 2128.0)],
		["hydrant", Vector3(405.0, 2.0, 2118.0), Vector3(392.6, 0.5, 2124.6)],
		["lotw", Vector3(252.0, 14.0, 1962.0), Vector3(252.0, 0.5, 1995.0)],
		["lote", Vector3(369.0, 12.0, 1962.0), Vector3(369.0, 0.5, 1995.0)],
		["park", Vector3(350.0, 8.0, 2118.0), Vector3(349.0, 0.5, 2092.0)],
		["trucks", Vector3(343.0, 3.5, 2200.0), Vector3(343.0, 2.0, 2165.0)],
		["truck_side", Vector3(322.0, 2.0, 2163.0), Vector3(332.0, 1.5, 2163.0)],
		["fighters", Vector3(345.0, 2.2, 2196.0), Vector3(345.0, 1.3, 2176.0)],
		["pcars", Vector3(250.0, 5.0, 2198.0), Vector3(245.0, 2.0, 2172.0)],
		["inside_f", Vector3(325.0, 3.5, 2184.0), Vector3(346.0, 3.0, 2142.0)],
		["north", Vector3(300.0, 14.0, 1935.0), Vector3(300.0, 5.0, 1985.0)],
		["main", Vector3(215.0, 4.0, 2060.0), Vector3(300.0, 4.0, 2066.0)],
		["shops", Vector3(260.0, 9.0, 2046.0), Vector3(262.0, 5.0, 1976.0)],
		["plaza", Vector3(300.0, 5.0, 2052.0), Vector3(300.0, 5.0, 2024.0)],
		["towers", Vector3(300.0, 10.0, 2068.0), Vector3(300.0, 25.0, 2038.0)],
	]
	if "--probe2" in OS.get_cmdline_user_args():
		var space := get_world_3d().direct_space_state
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.7
		for z in range(2205, 2108, -2):
			var row := "%d " % z
			for x in range(300, 400, 2):
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = cap
				q.transform = Transform3D(Basis.IDENTITY, Vector3(x, 1.2, z))
				q.collision_mask = 1
				row += "#" if not space.intersect_shape(q, 1).is_empty() else "."
			print("PROBE ", row)
	if "--drivefire" in OS.get_cmdline_user_args():
		var ft := Car.new()
		ft.position = Vector3(215.0, 1.0, 2066.0)
		ft.rotation.y = PI * 0.5
		add_child(ft)
		ft.setup("firetruck", "", false)
		ft.scripted = true
		await _wait(1.0)
		ft.s_throttle = 1.0
		var r0 := ft.wheels[2].rotation.x
		var tw := 0.0
		await _wait(4.0)
		cc.look_at_from_position(ft.global_position + Vector3(-9.0, 3.0, 6.0), ft.global_position, Vector3.UP)
		cc.make_current()
		await _wait(0.3)
		await _shot("b2_drivefire")
		print("FIRETRUCK speed ", ft.speed_ms, " x ", ft.global_position.x, " rear wheel spin ", ft.wheels[2].rotation.x - r0, " wheels ", ft.wheels.size())
		get_tree().quit()
		return
	for v in views:
		cc.look_at_from_position(v[1], v[2], Vector3.UP)
		cc.make_current()
		await _wait(0.9)
		await _shot("b2_%s" % v[0])
	get_tree().quit()

func _perf() -> void:
	await _wait(4.0)
	for k in range(6):
		await _wait(1.0)
		print("PERF fps=%d draw=%d objects=%d prims=%dk lights=%d mem=%dMB nodes=%d" % [Engine.get_frames_per_second(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) / 1000, 0,
			int(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
		print("PERF   process=%.1fms physics=%.1fms navigation=%.1f" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0])
	get_tree().quit()

func _shot(name: String) -> void:
	for i in range(6):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh")
	get_viewport().get_texture().get_image().save_png("/tmp/rh/%s.png" % name)

func _shots() -> void:
	await _wait(2.0)
	# aim + fire on foot
	Input.action_press("aim")
	player.force_aim = true
	await _wait(0.6)
	Input.action_press("attack")
	await _wait(0.12)
	await _shot("shot_aim")
	cam.yaw += PI + 0.5
	await _wait(0.5)
	await _shot("shot_aim_front")
	cam.yaw -= PI + 0.5
	Input.action_release("attack")
	Input.action_release("aim")
	player.force_aim = false
	# enter the car
	var starter: Car = test_car
	if starter == null:
		starter = player.nearest_car()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kind="):
			var want := a.substr(7)
			var best := 1e9
			for c in get_tree().get_nodes_in_group("cars"):
				if (c as Car).kind == want and (c as Car).global_position.distance_to(player.global_position) < best:
					best = (c as Car).global_position.distance_to(player.global_position)
					starter = c
			print("TEST using car kind=%s at %.0f m" % [starter.kind, best])
	player.global_position = starter.get_door_pos(-1.0)
	player._try_enter_car()
	for k in range(40):
		await _wait(0.25)
		print("TEST t=%.2f state=%d in_car=%s anim=%s" % [(k + 1) * 0.25, player.state, Game.in_car != null, player.cur_anim])
		if k == 2: await _shot("shot_enter_mid")
	await _shot("shot_in_car")
	print("TEST shots done state=%s" % player.state)
	get_tree().quit()

func _ground_gap(n: Node3D, from_off := 1.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(n.global_position + Vector3.UP * from_off, n.global_position + Vector3.DOWN * 4.0, 1)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return INF if h.is_empty() else n.global_position.y - h.position.y

func _ground_test() -> void:
	await _wait(8.0)
	var worst := {}
	for grp in ["peds", "cars", "traffic", "police"]:
		var gaps: Array = []
		for n in get_tree().get_nodes_in_group(grp):
			var off := 1.0 if grp == "peds" else 3.0
			gaps.append(snappedf(_ground_gap(n as Node3D, off), 0.01))
		if grp == "peds":
			for n in get_tree().get_nodes_in_group("peds"):
				print("TEST ped %s pos=%s gap=%s" % [(n as Ped).char_id, (n as Node3D).global_position, _ground_gap(n as Node3D, 1.0)])
		gaps.sort()
		print("TEST ground gap [%s] n=%d min=%s max=%s sample=%s" % [grp, gaps.size(), gaps[0] if gaps.size() else "-", gaps[-1] if gaps.size() else "-", gaps.slice(0, 6)])
	print("TEST player gap: %s  y=%.2f" % [_ground_gap(player), player.global_position.y])
	get_tree().quit()

func _runover_test() -> void:
	await _wait(1.5)
	var starter: Car = test_car
	if starter == null:
		starter = player.nearest_car()
	player.global_position = starter.get_door_pos(-1.0)
	player._try_enter_car()
	await _wait(2.0)
	var ped := Ped.new()
	add_child(ped)
	var ahead := starter.global_position + starter.forward_dir() * 14.0
	ped.global_position = Vector3(ahead.x, 0.3, ahead.z)
	var civ := "Male/Character_12"
	ped.setup(civ, [ped.global_position], 0, 1)
	starter.scripted = true
	starter.s_throttle = 1.0
	var money0 := Game.money
	var t := 0.0
	while t < 5.0 and ped.state != "dead":
		await _wait(0.1)
		t += 0.1
	if "--hitshots" in OS.get_cmdline_user_args():
		for k in range(5):
			await _shot("hit_%d" % k)
			await _wait(0.22)
	print("TEST runover: ped state=%s after %.1fs speed=%.1f km/h wanted=%d" % [ped.state, t, absf(starter.speed_ms) * 3.6, Game.wanted])
	await _wait(0.3)
	var cash := get_children().filter(func(n): return n is CashPickup)
	print("TEST cash drops: %d" % cash.size())
	starter.s_throttle = 0.0
	starter.s_brake = 1.0
	await _wait(4.0)
	starter.scripted = false
	player._exit_car()
	await _wait(2.0)
	var left := get_children().filter(func(n): return n is CashPickup)
	if not left.is_empty():
		player.global_position = (left[0] as Node3D).global_position - Vector3(0, 0.45, 0)
		await _wait(0.5)
	print("TEST money %d -> %d" % [money0, Game.money])
	get_tree().quit()

func _enter_shots() -> void:
	await _wait(1.5)
	var c: Car = test_car
	var cc := Camera3D.new()
	add_child(cc)
	cc.fov = 55.0
	var side := c.drv_x
	for a in OS.get_cmdline_user_args():
		if a == "--rhs": side = -c.drv_x
	cc.look_at_from_position(c.to_global(Vector3(0.0, 9.0, 6.0)) if side * c.drv_x < 0.0 else c.to_global(Vector3(6.5 * side, 1.5, 0.3)), c.to_global(Vector3(0, 0.7, 0.0)), Vector3.UP)
	cc.current = true
	print("CARDBG len=%.2f w=%.2f h=%.2f seat=%s door=%s hinge=%s doorbox=%s" % [c.model_len, c.model_w, c.model_h, c.to_local(c.get_driver_seat_pos()), c.to_local(c.get_door_pos(-1.0)), c.to_local(c.door_fl.global_position), c.door_fl.get_children().size()])
	player.global_position = c.to_global(Vector3(3.2 * side, 0.2, -0.6))
	await _wait(0.5)
	player._try_enter_car()
	Engine.time_scale = 0.5
	for i in range(24):
		await _wait(0.3)
		await _shot("en_%02d" % i)
		print("ENT t=%.2f origin_y_above_ground=%.2f" % [player.car_anim_t, player.global_position.y - (c.global_position.y - Car.RIDE)])
	Engine.time_scale = 1.0
	await _wait(1.5)
	await _shot("en_seated")
	c.set_body_ghost() if c.has_method("set_body_ghost") else null
	cc.look_at_from_position(c.to_global(Vector3(2.6 * side, 1.0, 0.4)), c.to_global(Vector3(0.45, 0.0, 0.4)), Vector3.UP)
	c.open_door(-1.0, 0.1, Car.DOOR_WIDE)
	await _wait(0.5)
	await _shot("en_seated_open")
	player._exit_car()
	print("EXITDBG state=", player.state, " in_car=", Game.in_car != null, " active=", player.active_car != null)
	Engine.time_scale = 0.5
	for i in range(24):
		await _wait(0.3)
		await _shot("ex_%02d" % i)
		print("EXT t=%.2f origin_y_above_ground=%.2f" % [player.car_anim_t, player.global_position.y - (c.global_position.y - Car.RIDE)])
	Engine.time_scale = 1.0
	get_tree().quit()

func _enter_test() -> void:
	await _wait(1.5)
	var starter: Car = null
	for c in get_tree().get_nodes_in_group("cars"):
		if Vector2((c as Node3D).global_position.x + 3.5, (c as Node3D).global_position.z - 20.0).length() < 3.0: starter = c
	print("TEST starter car: ", starter != null)
	player.global_position = starter.global_position + Vector3(3.0, 0, 0)
	await _wait(0.3)
	print("TEST nearest car dist < 4.5: ", player.nearest_car() == starter)
	player._try_enter_car()
	await _wait(0.5)
	print("TEST in car: ", Game.in_car == starter, " player visible: ", player.visible)
	starter.scripted = true
	starter.s_throttle = 1.0
	await _wait(3.0)
	print("TEST speed after 3 s: %.1f km/h  moved: %.1f m" % [absf(starter.speed_ms) * 3.6, starter.global_position.distance_to(Vector3(-3.5, 1.0, 20.0))])
	starter.s_throttle = 0.0
	starter.s_brake = 1.0
	await _wait(4.0)
	starter.scripted = false
	player._exit_car()
	await _wait(0.4)
	print("TEST exited: ", Game.in_car == null, " player visible: ", player.visible)
	get_tree().quit()

func _drive_test() -> void:
	await _wait(1.0)
	test_car = Car.new()
	test_car.position = Vector3(-3.0, 1.0, -300.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dpos="):
			var v := a.substr(7).split(",")
			test_car.position = Vector3(float(v[0]), 1.0, float(v[1]))
			test_car.rotation.y = float(v[2])
	add_child(test_car)
	test_car.setup("fumi", "")
	test_car.scripted = true
	await _wait(2.0)
	print("TEST settled origin height above ground: %.3f (RIDE const = %.2f)" % [test_car.global_position.y, Car.RIDE])
	test_car.s_throttle = 1.0
	var t100 := -1.0
	var t := 0.0
	for i in range(12 * 60):
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var kmh: float = test_car.linear_velocity.length() * 3.6
		if t100 < 0.0 and kmh >= 100.0: t100 = t
		if i % 120 == 0: print("TEST drive z=%.0f x=%.1f y=%.2f kmh=%.0f" % [test_car.global_position.z, test_car.global_position.x, test_car.global_position.y, kmh])
		if test_car.global_position.z > 350.0 or t > 20.0: break
	print("TEST 0-100 km/h: %s" % ("%.1f s" % t100 if t100 > 0 else "not reached"))
	get_tree().quit()

func _live_test() -> void:
	await _wait(6.0)
	print("TEST peds: ", get_tree().get_nodes_in_group("peds").size(), "  traffic: ", get_tree().get_nodes_in_group("traffic").size())
	Game.wanted = 3
	await _wait(8.0)
	print("TEST police cars with wanted 3: ", get_tree().get_nodes_in_group("police").size())
	var tr := get_tree().get_nodes_in_group("traffic")
	for i in range(mini(3, tr.size())):
		var t0 := tr[i] as TrafficCar
		print("TEST traffic[%d] kind=%s axis=%d sgn=%.0f speed=%.1f pos=%s" % [i, t0.kind, t0.axis, t0.sgn, t0.speed, str(t0.global_position.snappedf(0.1))])
	if tr.size() > 0:
		var first: Vector3 = (tr[0] as Node3D).global_position
		await _wait(5.0)
		print("TEST traffic car moved: ", first.distance_to((tr[0] as Node3D).global_position) > 3.0)
	# shoot test
	player.weapon = 1
	player.pistol_node.visible = true
	print("TEST fps: ", Engine.get_frames_per_second())
	get_tree().quit()

func _rules_test() -> void:
	await _wait(3.0)
	var peds := get_tree().get_nodes_in_group("peds")
	print("TEST peds before: ", peds.size())
	if peds.size() > 0:
		(peds[0] as Ped).hit(100.0, Vector3.FORWARD, true)
		await _wait(0.5)
		print("TEST wanted after killing a ped: ", Game.wanted, "  money: ", Game.money)
	Game.health = 0.0
	await _wait(1.0)
	print("TEST dead flag: ", Game.dead)
	await _wait(5.0)
	print("TEST respawned: dead=", Game.dead, " health=", Game.health, " wanted=", Game.wanted, " money=", Game.money, " pos=", str(player.global_position.snappedf(0.1)))
	get_tree().quit()

func _drive_demo() -> void:
	await _wait(1.2)
	var starter: Car = null
	for c in get_tree().get_nodes_in_group("cars"):
		if Vector2((c as Node3D).global_position.x + 3.5, (c as Node3D).global_position.z - 20.0).length() < 3.0: starter = c
	player.global_position = starter.global_position + Vector3(3.0, 0, 0)
	await _wait(0.2)
	player._try_enter_car()
	starter.set_lights(true)
	starter.scripted = true
	starter.s_throttle = 0.9
	cam.yaw = PI

func _anim_test() -> void:
	await _wait(1.5)
	print("--- BEGIN ANIMATION TESTS ---")

	# 1. Weapon Equip & Aim Poses
	player.weapon = 1
	player.force_aim = true
	player.pistol_node.visible = true
	await _wait(0.2)
	print("TEST weapon equip: weapon=%d aiming=%s" % [player.weapon, player.aiming])

	# Aim Down (pitch > 0.45)
	cam.pitch = 0.55
	await _wait(0.2)
	print("TEST aim down anim: %s" % player.cur_anim)

	# Aim Level (pitch ~ 0.32)
	cam.pitch = 0.32
	await _wait(0.2)
	print("TEST aim neutral anim: %s" % player.cur_anim)

	# Aim Up (pitch < 0.20)
	cam.pitch = 0.12
	await _wait(0.2)
	print("TEST aim up anim: %s" % player.cur_anim)

	# 2. Shooting & Recoil & Casings
	var ammo_before := player.ammo
	player._shoot()
	await _wait(0.05)
	var casing_count := 0
	for ch in get_children():
		if ch is Player.ShellCasing:
			casing_count += 1
	var pistol_anim: String = String(player.pistol_anim_player.current_animation) if player.pistol_anim_player != null else "none"
	print("TEST shoot: anim=%s gun_anim=%s ammo=%d->%d casings=%d" % [player.cur_anim, pistol_anim, ammo_before, player.ammo, casing_count])

	# 3. Reloading
	await _wait(0.35)
	player.reload_t = 1.3
	player.play("Pistol_Reload", 1.25, 0.1)
	if player.pistol_anim_player != null:
		player.pistol_anim_player.play("reload", -1, 1.2)
	await _wait(0.1)
	var reload_pistol_anim: String = String(player.pistol_anim_player.current_animation) if player.pistol_anim_player != null else "none"
	print("TEST reload: anim=%s gun_anim=%s" % [player.cur_anim, reload_pistol_anim])

	# 4. Car Enter Animation & Door Opening
	await _wait(1.3)
	player.force_aim = false
	var starter: Car = test_car
	if starter == null and player != null:
		starter = player.nearest_car()
	player.global_position = starter.global_position + Vector3(2.5, 0, 0)
	await _wait(0.2)
	print("TEST car door toggle before enter: doors_open=%s" % starter.doors_open)
	starter.toggle_doors()
	print("TEST car door toggle open: doors_open=%s" % starter.doors_open)
	starter.toggle_doors()
	print("TEST car door toggle close: doors_open=%s" % starter.doors_open)
	player._try_enter_car()
	await _wait(0.2)
	print("TEST entering car: state=%s anim=%s doors_open=%s" % [player.state, player.cur_anim, starter.doors_open])
	await _wait(1.2)
	print("TEST inside car: state=%s anim=%s visible=%s doors_open=%s" % [player.state, player.cur_anim, player.visible, starter.doors_open])

	# 5. Car Exit Animation & Door Opening
	player._exit_car()
	await _wait(0.2)
	print("TEST exiting car: state=%s anim=%s doors_open=%s" % [player.state, player.cur_anim, starter.doors_open])
	await _wait(1.4)
	print("TEST exited car: state=%s anim=%s doors_open=%s" % [player.state, player.cur_anim, starter.doors_open])

	print("--- ALL ANIMATION TESTS COMPLETED ---")
	get_tree().quit()



func _radio_test() -> void:
	await _wait(1.5)
	var c: Car = test_car
	player.global_position = c.to_global(Vector3(-3.0, 0.2, 0.0))
	player._try_enter_car()
	await _wait(6.5)
	var r: Radio = audio.radio
	print("RADIOTEST ffmpeg=", r._ffmpeg, " idx=", r.idx, " on=", r.on, " pid=", r._pid, " got_audio=", r._got_audio, " title=", r.title, " urls=", (r._urls[r.idx] as Array).size())
	await _shot("radio_banner")
	for k in [8, 10]:
		r.tune(k)
		await _wait(7.0)
		print("RADIOTEST ch=", Radio.CHANNELS[k].name, " got_audio=", r._got_audio, " title=", r.title, " urls=", (r._urls[k] as Array).size())
	Input.action_press("radio")
	await _wait(1.2)
	await _shot("radio_wheel")
	Input.action_release("radio")
	await _wait(0.5)
	print("RADIOTEST after wheel idx=", r.idx)
	get_tree().quit()

func _train_hit() -> void:
	await _wait(3.0)
	var tr := get_tree().get_nodes_in_group("trains")[0] as Train
	var c: Car = test_car
	var d := Vector3(tr.global_transform.basis.z)
	c.global_position = tr.global_position + Vector3(0, 1.2, 0) + Vector3(0, 0, 0)
	var side := tr.global_transform.basis.z.normalized()
	c.global_position = tr.global_position + side * 12.0 + Vector3(0, 1.0, 0)
	c.rotation.y = atan2(-side.x, -side.z)
	await _wait(1.5)
	player.global_position = c.to_global(Vector3(3.0, 0.2, 0.0))
	player._try_enter_car()
	await _wait(2.6)
	c.scripted = true
	c.s_throttle = 0.6
	for i in range(12):
		await _wait(0.4)
		print("TRAINHIT dist=%.1f speed=%.1f" % [c.global_position.distance_to(tr.global_position), c.speed_ms])
	get_tree().quit()

func _track_drive() -> void:
	await _wait(1.5)
	var c: Car = test_car
	c.global_position = Vector3(600.0, 1.2, 452.0)
	c.rotation.y = 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tpos="):
			var tv := a.substr(7).split(",")
			c.global_position = Vector3(float(tv[0]), 1.2, float(tv[1]))
			c.rotation.y = float(tv[2])
	c.linear_velocity = Vector3.ZERO
	await _wait(1.5)
	player.global_position = c.to_global(Vector3(3.0, 0.2, 0.0))
	await _wait(0.3)
	player._try_enter_car()
	await _wait(2.6)
	var cc := Camera3D.new()
	add_child(cc)
	cc.fov = 50.0
	cc.current = true
	c.scripted = true
	c.s_throttle = 0.45
	var steps := 14
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tsteps="): steps = int(a.substr(9))
	c.s_throttle = 1.0
	for i in range(steps):
		await _wait(0.25)
		cc.look_at_from_position(c.global_position + Vector3(7.0, 1.0, 0.5), c.global_position + Vector3(0, 0.1, 0), Vector3.UP)
		await _shot("td_%02d" % i)
		print("TRACKDRIVE z=%.1f y=%.2f speed=%.1f" % [c.global_position.z, c.global_position.y, c.speed_ms])
	get_tree().quit()

func _cam_drive() -> void:
	await _wait(1.5)
	var c: Car = test_car
	player.global_position = c.to_global(Vector3(3.0, 0.2, 0.0))
	await _wait(0.3)
	player._try_enter_car()
	await _wait(2.6)
	c.scripted = true
	c.s_throttle = 1.0
	await _wait(1.5)
	await _shot("cd_slow")
	await _wait(4.0)
	print("CAMDRIVE speed km/h: ", absf(c.speed_ms) * 3.6)
	await _shot("cd_fast")
	get_tree().quit()

func _plane_cam() -> void:
	await _wait(2.0)
	var planes := get_tree().get_nodes_in_group("player_heli").filter(func(n): return n is Airplane)
	var pl := planes[0] as Airplane
	for cand in planes:
		if (cand as Airplane).kind == "passenger": pl = cand
	player.global_position = pl.global_position + Vector3(0, 0, 8)
	await _wait(0.3)
	pl.enter(player)
	await _wait(1.0)
	var i := 0
	for yp in [[0.0, -0.1], [1.57, 0.1], [3.14, 0.5], [4.7, 1.1], [0.8, -0.1], [2.4, 0.9]]:
		cam.yaw = yp[0]
		cam.pitch = yp[1]
		cam.idle_t = 0.0
		await _wait(0.6)
		await _shot("pc_%d" % i)
		i += 1
	get_tree().quit()

func _plane_test() -> void:
	await _wait(2.0)
	var planes := get_tree().get_nodes_in_group("player_heli").filter(func(n): return n is Airplane)
	print("TEST plane: found ", planes.size())
	var pl := planes[0] as Airplane
	for cand in planes:
		if (cand as Airplane).kind == "private": pl = cand
	# put it on the runway heading east, then drive it
	pl.global_position = Vector3(660.0, 0.2, -982.0)
	pl.yaw = PI * 0.5
	pl.rotation.y = PI * 0.5
	player.global_position = pl.global_position + Vector3(0, 0, 8)
	await _wait(0.5)
	print("TEST plane: near=", player.nearest_heli(7.0) != null)
	pl.enter(player)
	Input.action_press("move_forward")
	var t := 0.0
	var pulled := false
	for i in range(40 * 60):
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if not pulled and pl.speed > pl.SPECS.private.rot + 6.0:
			Input.action_press("jump")
			pulled = true
		if i % 120 == 0:
			print("TEST plane t=%.0f speed=%.0f alt=%.1f x=%.0f pitch=%.2f" % [t, pl.speed, pl.height_above_ground(), pl.global_position.x, pl.pitch])
		if pl.height_above_ground() > 60.0: break
	Input.action_release("jump")
	print("TEST plane: airborne alt=%.0f at x=%.0f" % [pl.height_above_ground(), pl.global_position.x])
	Input.action_release("move_forward")
	Input.action_press("move_back")
	for i in range(30 * 60):
		await get_tree().physics_frame
	print("TEST plane after: alt=%.0f" % pl.height_above_ground())
	get_tree().quit()

## Dev: drives the player's car into a Renowood type A garden and back out, printing where it gets stuck.
func _houses_drive() -> void:
	await _wait(2.0)
	var pads: Array = Renowood.pads
	var pd: Dictionary = {}
	for p in pads:
		if int(p.which) == 0:
			pd = p
			break
	if pd.is_empty(): print("HDRIVE no type A pad"); get_tree().quit(); return
	var c: Vector2 = pd.c
	var dirv := Vector2(sin(float(pd.yaw)), cos(float(pd.yaw)))      # from the house towards the road
	var start: Vector2 = c + dirv * 42.0
	var yaw_in := atan2(-dirv.x, -dirv.y)                                # facing the house
	var cr: Car = test_car
	cr.global_position = Vector3(start.x, float(pd.road_h) + 1.4, start.y)
	cr.rotation.y = yaw_in
	cr.linear_velocity = Vector3.ZERO
	cr.angular_velocity = Vector3.ZERO
	await _wait(1.5)
	player.global_position = cr.to_global(Vector3(3.0, 0.2, 0.0))
	player._try_enter_car()
	await _wait(5.0)
	cr.scripted = true
	cr.s_steer = 0.0
	cr.s_throttle = 0.5
	var t := 0.0
	var last := cr.global_position
	while t < 9.0:
		await _wait(0.5)
		t += 0.5
		var dd := Vector2(cr.global_position.x - c.x, cr.global_position.z - c.y).length()
		print("HDRIVE in  t=%.1f dist_to_house=%.1f speed=%.1f y=%.2f" % [t, dd, cr.speed_ms, cr.global_position.y])
	cr.s_throttle = 0.0
	cr.s_brake = 1.0
	await _wait(2.0)
	cr.s_brake = 0.0
	cr.s_throttle = -0.6
	t = 0.0
	while t < 9.0:
		await _wait(0.5)
		t += 0.5
		var dd2 := Vector2(cr.global_position.x - c.x, cr.global_position.z - c.y).length()
		print("HDRIVE out t=%.1f dist_to_house=%.1f speed=%.1f y=%.2f" % [t, dd2, cr.speed_ms, cr.global_position.y])
	await _shot("hdrive_end")
	get_tree().quit()

## Dev: parks the car with its driver's door against a building wall, gets out, and prints where the player ends up.
func _exit_wall_test() -> void:
	await _wait(2.5)
	var b: Dictionary = {}
	for e in CityBuild.layout.buildings:
		if e.k in ["r1", "soviet"] and absf(float(e.yaw)) < 0.01:
			b = e
			break
	if b.is_empty(): print("EXITWALL no building"); get_tree().quit(); return
	var front_z: float = float(b.z) + float(b.d) * 0.5
	var cr: Car = test_car
	cr.global_position = Vector3(float(b.x), 1.2, front_z + 1.5)
	cr.rotation.y = -PI * 0.5
	cr.linear_velocity = Vector3.ZERO
	await _wait(1.5)
	player.global_position = cr.global_position + Vector3(0, 0.2, 3.0)
	player._try_enter_car()
	await _wait(6.5)
	print("EXITWALL in car: ", Game.in_car != null)
	player._exit_car()
	await _wait(3.0)
	var pp := player.global_position
	print("EXITWALL player at ", pp, " blocked=", player._blocked_at(pp, [player.get_rid()]), " building z range ", float(b.z) - float(b.d) * 0.5, "..", front_z, " x ", float(b.x) - float(b.w) * 0.5, "..", float(b.x) + float(b.w) * 0.5)
	await _shot("exitwall")
	get_tree().quit()

## Dev: drives the car fast down the main street, gets out, and prints the player's position every 0.2 s.
func _exit_fast_test() -> void:
	await _wait(2.5)
	var cr: Car = test_car
	cr.global_position = Vector3(0.0, 1.2, 330.0)
	cr.rotation.y = PI
	cr.linear_velocity = Vector3.ZERO
	await _wait(1.5)
	player.global_position = cr.to_global(Vector3(-3.0, 0.2, 0.0))
	player._try_enter_car()
	await _wait(6.5)
	cr.scripted = true
	cr.s_throttle = 1.0
	await _wait(5.0)
	print("EXITFAST speed %.1f m/s car at %s" % [absf(cr.speed_ms), cr.global_position])
	player._exit_car()
	for i in range(18):
		await _wait(0.2)
		print("EXITFAST t=%.1f player=%s state=%d vel=%s cam=%s" % [(i + 1) * 0.2, player.global_position, player.state, player.velocity, cam.global_position])
	await _shot("exitfast")
	get_tree().quit()

## Dev: the police and hospital compounds from the gate and from above (pictures stn_*).
func _station_view() -> void:
	await _wait(3.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 700.0
	for k in ["police", "hospital"]:
		var ppos := Vector3.ZERO
		for pn in Game.world.pois:
			if String(pn.kind) == k: ppos = pn.pos
		var best := Vector3(ppos.x, 0.0, ppos.z)
		print("STN ", k, " ", best)
		var sg := 1.0 if k == "police" else -1.0
		player.global_position = best + Vector3(0, 1.0, 34.0 * sg)
		for v in [["gate", Vector3(0, 5.0, 24.0 * sg)], ["side", Vector3(-30.0, 3.5, 20.0 * sg)], ["top", Vector3(0, 110.0, 0.1)], ["back", Vector3(0, 12.0, -62.0 * sg)]]:
			cc.look_at_from_position(best + v[1], best + Vector3(0, 0.5, 0), Vector3.UP if v[0] != "top" else Vector3(0, 0, -1))
			cc.make_current()
			await _wait(0.8)
			await _shot("stn_%s_%s" % [k, v[0]])
	get_tree().quit()

## Dev: the new office building on its own, seen from the front at the current hour (pictures ait_*).
func _ait_view() -> void:
	await _wait(2.5)
	var hits: Array = []
	for b in CityBuild.layout.buildings:
		if b.k == ("hirise" if "--hirise" in OS.get_cmdline_user_args() else "ait"): hits.append(b)
	print("AIT placed: ", hits.size())
	if hits.is_empty():
		get_tree().quit()
		return
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 700.0
	var n := 0
	for b in hits.slice(0, 3):
		var basis := Basis(Vector3.UP, float(b.yaw))
		var centre := Vector3(float(b.x), 14.0, float(b.z))
		for side in [1.0, -1.0]:
			var hgt := 14.0 if not ("--hirise" in OS.get_cmdline_user_args()) else 70.0
			centre.y = hgt
			var cam_pos := centre + basis * Vector3(6.0, 0.0, side * (float(b.d) * 0.5 + (30.0 if hgt < 20.0 else 90.0))) + Vector3(0, -hgt + 6.0, 0)
			cc.look_at_from_position(cam_pos, centre, Vector3.UP)
			cc.make_current()
			await _wait(0.4)
			await _shot("ait_%d_%s" % [n, "front" if side > 0.0 else "back"])
		n += 1
	get_tree().quit()

## Dev: the metro. Street entrance, walking down the stairs, the station platforms with a train, the tunnel (pictures mt_*).
func _metro_view() -> void:
	await _wait(3.0)
	var A: Dictionary = Metro.L.b if "--b" in OS.get_cmdline_user_args() else Metro.L.a
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 500.0
	var e := Vector3(Metro.XM, float(A.gy), float(A.zs))
	var dd: float = float(A.dir)
	cc.look_at_from_position(e + Vector3(4.0, 2.6, -9.0 * dd), e + Vector3(0, 0.5, 1.0 * dd), Vector3.UP)
	cc.make_current()
	await _wait(0.6)
	await _shot("mt_a")
	cc.look_at_from_position(e + Vector3(0, 7.0, -1.0), e + Vector3(0, 0, 2.2), Vector3.UP)
	await _wait(0.4)
	await _shot("mt_b")
	if "--board" in OS.get_cmdline_user_args():
		var oa2: Vector3 = Metro.L.a.o
		var tn: MetroTrain = Metro.trains[0]               # train 0 starts standing at the town station's platform: hold it there
		tn._wait = 120.0
		player.global_position = tn.global_position + Vector3(3.6, 1.9, 8.0)
		await _wait(5.0)
		print("MT train at ", tn.global_position, " open ", tn._open, " parked ", tn._cur)
		var tp := tn.global_position
		for pxx in [2.0, 1.5, 1.2, 0.9, 0.5, 0.0]:
			var sq := PhysicsShapeQueryParameters3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.34
			cap.height = 1.8
			sq.shape = cap
			sq.transform = Transform3D(Basis(), tn.global_position + Vector3(pxx, 2.1, 3.15))
			var names := []
			for r in get_world_3d().direct_space_state.intersect_shape(sq, 8):
				var cs2 := (r.collider as CollisionObject3D)
				var oid := cs2.shape_find_owner(int(r.shape))
				var sh2 := cs2.shape_owner_get_shape(oid, 0)
				names.append(str(cs2.name, " ", ((sh2 as BoxShape3D).size if sh2 is BoxShape3D else "mesh"), " @", (cs2.shape_owner_get_owner(oid) as Node3D).position))
			print("MT cap x=", pxx, " ", names)
		var tb := tn.get_node("TrainBody") as AnimatableBody3D
		print("MT trainbody pos ", tb.global_position, " layer ", tb.collision_layer, " shapes ", tb.get_child_count(), " first ", (tb.get_child(0) as CollisionShape3D).global_position, " disabled ", (tb.get_child(0) as CollisionShape3D).disabled, " train pos ", tn.global_position)
		var spc := get_world_3d().direct_space_state
		for dxp in [0.0, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 7.0]:
			var rq := PhysicsRayQueryParameters3D.create(tp + Vector3(dxp, 4.0, 3.06), tp + Vector3(dxp, -2.0, 3.06), 0xFFFFFFFF)
			var rh := spc.intersect_ray(rq)
			print("MT ray dx=", dxp, " hit y rel=", (snappedf(rh.position.y - tp.y, 0.01) if not rh.is_empty() else "none"), " ", (rh.collider.name if not rh.is_empty() else ""))
		for v in [["b0", tp + Vector3(5.0, 2.2, 5.0), tp + Vector3(1.4, 2.2, 3.06)], ["b1", tp + Vector3(3.5, 2.0, -1.0), tp + Vector3(0.5, 1.8, -4.0)], ["b2", tp + Vector3(4.4, 2.2, 20.0), tp + Vector3(0.5, 2.0, 5.0)]]:
			cc.look_at_from_position(v[1], v[2], Vector3.UP)
			cc.make_current()
			await _wait(0.5)
			await _shot("mt_%s" % v[0])
		cam.make_current()
		player.global_position = tp + Vector3(3.6, 1.9, 3.06)
		cam.yaw = PI * 0.5
		await _wait(1.0)
		Input.action_press("move_forward")
		for k in range(6):
			await _wait(1.0)
			print("MT board t=", k, " player=", player.global_position - tp, " floor=", player.is_on_floor())
			await _shot("mt_p%d" % k)
		Input.action_release("move_forward")
		get_tree().quit()
		return
	if "--blimp" in OS.get_cmdline_user_args():
		var bl: Blimp = null
		for ch in Game.world.get_children():
			if ch is Blimp: bl = ch
		bl.set_process(false)
		var cc2 := Camera3D.new()
		add_child(cc2)
		cc2.far = 3000.0
		var bp := bl.global_position
		var rot := bl.global_transform.basis
		for v in [["l", Vector3(95, 6, 0)], ["r", Vector3(-95, 6, 0)], ["f", Vector3(70, 14, 70)]]:
			cc2.look_at_from_position(bp + rot * v[1], bp, Vector3.UP)
			cc2.make_current()
			await _wait(1.0)
			await _shot("bl_%s" % v[0])
		get_tree().quit()
		return
	if "--shop_old" in OS.get_cmdline_user_args():
		var it0: Dictionary = GunShop.items[0]
		var door := Vector3((it0.pos as Vector3).x + 3.0, 0.0, (it0.pos as Vector3).z)
		var cc3 := Camera3D.new()
		add_child(cc3)
		cc3.far = 600.0
		var shop_x: float = door.x
		var shop_z1: float = (it0.pos as Vector3).z + GunShop.D - 0.5
		for v in [["out", Vector3(shop_x, 3.5, shop_z1 + 14.0), Vector3(shop_x, 2.0, shop_z1 - 5.0)], ["in", Vector3(shop_x, 2.0, shop_z1 - 1.0), Vector3(shop_x, 1.6, shop_z1 - 10.0)],
				["wall", Vector3(shop_x, 1.7, shop_z1 - 5.5), Vector3(shop_x, 1.6, shop_z1 - 11.0)], ["wallL", Vector3(shop_x - 5.0, 1.8, shop_z1 - 6.0), Vector3(shop_x - 5.5, 1.6, shop_z1 - 11.0)]]:
			cc3.look_at_from_position(v[1], v[2], Vector3.UP)
			cc3.make_current()
			await _wait(1.0)
			await _shot("sh_%s" % v[0])
		cam.make_current()
		player.global_position = GunShop.keeper_pos + Vector3(0, 0.4, 1.6)
		await _wait(0.6)
		print("SHOP at counter: ", GunShop.near_counter(player.global_position), " money ", Game.money)
		GunMenu.toggle_for(self)
		await _wait(0.8)
		await _shot("sh_menu")
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.pressed = true
		Input.parse_input_event(ev)
		await _wait(0.5)
		print("SHOP after buy: money ", Game.money, " owned ", Game.guns_owned)
		await _shot("sh_menu2")
		get_tree().quit()
		return
	if "--kerb" in OS.get_cmdline_user_args():
		# walk from the road onto the pavement (north towards the Atlanta Court entrance) without jumping
		cam.make_current()
		cam.yaw = PI
		player.global_position = Vector3(-60.0, 0.6, -2.0)
		await _wait(1.0)
		Input.action_press("move_forward")
		for k in range(8):
			await _wait(0.7)
			print("MT kerb t=", k, " player=", player.global_position, " floor=", player.is_on_floor())
		Input.action_release("move_forward")
		get_tree().quit()
		return
	if "--carry" in OS.get_cmdline_user_args():
		var trc: MetroTrain = Metro.trains[0]
		trc._wait = 0.5
		await _wait(1.0)
		cam.make_current()
		player.global_position = trc.global_position + Vector3(0.2, 1.4, 1.0)
		Input.action_press("move_back")
		for k in range(16):
			await _wait(1.0)
			if k in [29, 30, 31, 32, 33]:
				var sq2 := PhysicsShapeQueryParameters3D.new()
				var cp2 := CapsuleShape3D.new()
				cp2.radius = 0.36
				cp2.height = 1.84
				sq2.shape = cp2
				sq2.transform = Transform3D(Basis(), player.global_position + Vector3(0, 0.92, 0))
				sq2.exclude = [player.get_rid()]
				for r2 in get_world_3d().direct_space_state.intersect_shape(sq2, 8):
					var co := r2.collider as CollisionObject3D
					var oid2 := co.shape_find_owner(int(r2.shape))
					var sh3 := co.shape_owner_get_shape(oid2, 0)
					print("MT   overlap k=", k, " ", co.name, " ", ((sh3 as BoxShape3D).size if sh3 is BoxShape3D else "mesh"), " @", (co.shape_owner_get_owner(oid2) as Node3D).global_position, " player ", player.global_position)
			if k in [6, 12, 15]: await _shot("mt_c%d" % k)
			var lpl := trc.to_local(player.global_position)
			print("MT carry t=", k, " train z=", snappedf(trc.global_position.z, 0.1), " v=", snappedf(trc._v, 0.1), " wait=", snappedf(trc._wait, 0.1), " player local=", lpl.snapped(Vector3.ONE * 0.01), " riding=", MetroTrain.riding != null, " floor=", player.is_on_floor())
		get_tree().quit()
		return
	if "--fit" in OS.get_cmdline_user_args():
		for st in [["a", Metro.L.a.o, 0], ["b", Metro.L.b.o, 1]]:
			var o5: Vector3 = st[1]
			var tn5: MetroTrain = Metro.trains[st[2]]
			tn5._wait = 120.0
			await _wait(5.0)
			print("MT fit ", st[0], " train z ", snappedf(tn5.global_position.z - 33.5, 0.1), " .. ", snappedf(tn5.global_position.z + 33.5, 0.1), " station z ", snappedf(o5.z - 47.8 - (Metro.EXT if st[0] == "a" else 0.0), 0.1), " .. ", snappedf(o5.z + 16.4 + (Metro.EXT if st[0] == "b" else 0.0), 0.1))
			var dz := -1.0 if st[0] == "a" else 1.0                  # which way the last-stop end lies
			var zt := o5.z + (14.5 if st[0] == "a" else -45.5)
			cc.look_at_from_position(Vector3(o5.x + 6.9, o5.y + 2.4, zt), Vector3(o5.x + 6.9, o5.y + 1.8, zt + dz * 40.0), Vector3.UP)
			cc.make_current()
			await _wait(1.0)
			await _shot("mt_f%s" % st[0])
			cc.look_at_from_position(Vector3(o5.x + 6.9, o5.y + 2.0, zt + dz * 62.0), Vector3(o5.x + 6.9, o5.y + 1.8, zt + dz * 100.0), Vector3.UP)
			await _wait(0.6)
			await _shot("mt_g%s" % st[0])
			cc.look_at_from_position(Vector3(o5.x + 6.9, o5.y + 2.2, zt + dz * 20.0), Vector3(o5.x + 6.9, o5.y + 1.8, zt + dz * 60.0), Vector3.UP)
			await _wait(0.6)
			await _shot("mt_h%s" % st[0])
		get_tree().quit()
		return
	if "--ride" in OS.get_cmdline_user_args():
		var tr: MetroTrain = Metro.trains[0]
		tr._wait = 120.0
		await _wait(5.0)
		cam.make_current()
		player.global_position = tr.global_position + Vector3(0.0, 1.5, 3.06)
		await _wait(1.5)
		print("MT ride before: riding=", MetroTrain.riding != null, " open=", tr._open)
		await _shot("mt_r0")
		tr._wait = 1.0                                   # doors shut, then it pulls away
		for k in range(1, 5):
			await _wait(2.0)
			cam.yaw += 1.0                               # try to turn the camera: it must not move
			print("MT ride k=", k, " riding=", MetroTrain.riding != null, " open=", snappedf(tr._open, 0.01), " train z=", snappedf(tr.global_position.z, 0.1), " cam=", cam.global_position - tr.global_position)
			await _shot("mt_r%d" % k)
		get_tree().quit()
		return
	if "--signs" in OS.get_cmdline_user_args():
		var oa4: Vector3 = Metro.L.a.o
		var ob4: Vector3 = Metro.L.b.o
		for v in [["s0", oa4 + Vector3(5.0, 1.6, -6.0), oa4 + Vector3(5.0, 3.7, -34.0)], ["s1", ob4 + Vector3(5.0, 1.6, -6.0), ob4 + Vector3(5.0, 3.7, -34.0)], ["s2", oa4 + Vector3(5.0, 2.0, 10.0), oa4 + Vector3(5.0, 3.0, -10.0)]]:
			cc.look_at_from_position(v[1], v[2], Vector3.UP)
			cc.make_current()
			await _wait(1.0)
			await _shot("mt_%s" % v[0])
		var tr0: MetroTrain = Metro.trains[0]
		var trk: Array = []
		for k in range(150):
			await _wait(1.0)
			trk.append("%s z=%.0f v=%.1f wait=%.1f cur=%d open=%.1f" % ["T0", tr0.global_position.z, tr0._v, tr0._wait, tr0._cur, tr0._open])
			if k % 10 == 9: print("MT track ", trk[k], " rot=", snappedf(rad_to_deg(tr0.rotation.y), 1))
		print("MT audio: A pa=", Metro.pa[0] != null, " B pa=", Metro.pa[1] != null)
		get_tree().quit()
		return
	if "--islandshot" in OS.get_cmdline_user_args():
		var ob3: Vector3 = Metro.L.b.o
		var zt := ob3.z - 47.1
		for v in [["i0", ob3 + Vector3(0.17, 2.0, -47.1 - 45.0), ob3 + Vector3(0.17, 2.2, -47.1 - 5.0)], ["i1", ob3 + Vector3(13.59, 2.0, -47.1 - 45.0), ob3 + Vector3(13.59, 2.2, -47.1 - 5.0)],
				["i2", ob3 + Vector3(6.9, 2.6, -40.0), ob3 + Vector3(6.9, 1.8, -20.0)], ["i3", ob3 + Vector3(6.9, 2.6, 8.0), ob3 + Vector3(6.9, 1.8, 15.0)], ["i4", ob3 + Vector3(3.0, 2.4, -2.0), ob3 + Vector3(0.17, 1.5, -22.0)]]:
			cc.look_at_from_position(v[1], v[2], Vector3.UP)
			cc.make_current()
			await _wait(1.0)
			await _shot("mt_%s" % v[0])
		get_tree().quit()
		return
	if "--tunnelshot" in OS.get_cmdline_user_args():
		var oa3: Vector3 = Metro.L.a.o
		for v in [["u0", oa3 + Vector3(0.17, 2.0, 45.0), oa3 + Vector3(0.17, 2.2, 15.0)], ["u1", oa3 + Vector3(13.59, 2.0, 45.0), oa3 + Vector3(13.59, 2.2, 15.0)], ["u2", oa3 + Vector3(3.0, 3.6, 38.0), oa3 + Vector3(0.17, 3.0, 15.8)]]:
			cc.look_at_from_position(v[1], v[2], Vector3.UP)
			cc.make_current()
			await _wait(1.0)
			await _shot("mt_%s" % v[0])
		get_tree().quit()
		return
	if "--terminus" in OS.get_cmdline_user_args():
		var oa: Vector3 = Metro.L.a.o
		var ob: Vector3 = Metro.L.b.o
		var views := [["ta", oa + Vector3(6.9, 2.4, -24.0), oa + Vector3(6.9, 1.5, -47.0)], ["tb", oa + Vector3(6.9, 2.2, 8.0), oa + Vector3(6.9, 1.5, -20.0)],
			["tc", ob + Vector3(6.9, 2.4, -4.0), ob + Vector3(6.9, 1.5, 15.0)], ["td", oa + Vector3(3.0, 2.0, -30.0), oa + Vector3(3.0, 1.5, -47.0)],
			["te", oa + Vector3(6.9, 2.6, 0.0), oa + Vector3(6.9, 1.6, 15.8)], ["tf", oa + Vector3(0.17, 2.2, 60.0), oa + Vector3(0.17, 2.0, 15.0)], ["tg", oa + Vector3(0.17, 1.8, 30.0), oa + Vector3(0.17, 1.8, 300.0)],
			["th", oa + Vector3(13.59, 1.8, 24.0), oa + Vector3(13.59, 1.8, 300.0)], ["ti", oa + Vector3(0.17, 2.4, 900.0), oa + Vector3(0.17, 1.6, 1100.0)], ["tj", oa + Vector3(1.0, 1.3, 60.0), oa + Vector3(0.17, 0.2, 66.0)]]
		for v in views:
			cc.look_at_from_position(v[1], v[2], Vector3.UP)
			cc.make_current()
			await _wait(1.0)
			await _shot("mt_%s" % v[0])
		get_tree().quit()
		return
	if "--camspin" in OS.get_cmdline_user_args():
		cam.make_current()
		cam.yaw = PI if dd > 0.0 else 0.0
		player.global_position = e + Vector3(0, 0.4, -2.0 * dd)
		await _wait(1.0)
		var k := 0
		for phase in ["move_forward", "move_back"]:
			Input.action_press(phase)
			for t in range(5):
				await _wait(0.9)
				# try to swing the camera round with the mouse while walking
				cam.yaw += 1.2
				await _wait(0.3)
				var inside := absf(cam.global_position.x - Metro.XM) < 1.3
				print("MT camspin ", phase, " t=", t, " player=", player.global_position, " cam=", cam.global_position, " camdist=", snappedf(cam.global_position.distance_to(player.global_position + Vector3(0, 1.45, 0)), 0.01), " inside=", inside)
				await _shot("mt_s%d" % k)
				k += 1
			Input.action_release(phase)
		get_tree().quit()
		return
	if "--rayb" in OS.get_cmdline_user_args():
		var spb := get_world_3d().direct_space_state
		print("MT B gy ", A.gy, " n ", A.n, " rise ", A.rise, " zs ", A.zs, " floor ", Metro.L.floor)
		for zq in [2441.0, 2440.0, 2439.0, 2438.4, 2438.0, 2437.0, 2436.0, 2435.0, 2433.0, 2431.0, 2429.0]:
			var rq := PhysicsRayQueryParameters3D.create(Vector3(Metro.XM, float(A.gy) + 3.0, zq), Vector3(Metro.XM, -20.0, zq), 0xFFFFFFFF)
			var rh := spb.intersect_ray(rq)
			print("MT B ray z=", zq, " hit y=", (snappedf(rh.position.y, 0.01) if not rh.is_empty() else "none"), " ", (rh.collider.name if not rh.is_empty() else ""))
		get_tree().quit()
		return
	if "--walk" in OS.get_cmdline_user_args():
		cam.make_current()
		cam.yaw = PI if dd > 0.0 else 0.0
		player.face = 0.0 if dd > 0.0 else PI              # facing the way down
		player.global_position = e + Vector3(0, 0.4, -2.0 * dd)
		await _wait(1.0)
		Input.action_press("move_forward")
		for k in range(7):
			await _wait(1.5)
			print("MT walk t=", k, " player=", player.global_position, " floor=", player.is_on_floor())
			await _shot("mt_w%d" % k)
		Input.action_release("move_forward")
		get_tree().quit()
		return
	if "--probe" in OS.get_cmdline_user_args():
		var sp := get_world_3d().direct_space_state
		for pz in [20.0, 21.4, 22.5, 24.0]:
			var pos := Vector3(Metro.XM, -10.19 if pz < 22.0 else -11.0, e.z + pz - 7.1 + 7.1 - 0.0)
			pos.z = pz
			var sq := PhysicsShapeQueryParameters3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.4
			cap.height = 1.8
			sq.shape = cap
			sq.transform = Transform3D(Basis(), pos + Vector3(0, 0.9, 0))
			sq.collision_mask = 0xFFFFFFFF
			for r in sp.intersect_shape(sq, 16):
				var body := r.collider as CollisionObject3D
				var oid := body.shape_find_owner(int(r.shape))
				var node := body.shape_owner_get_owner(oid) as Node3D
				var shp := body.shape_owner_get_shape(oid, 0)
				var info := ""
				if shp is BoxShape3D: info = "box " + str((shp as BoxShape3D).size)
				elif shp is ConcavePolygonShape3D: info = "trimesh faces " + str((shp as ConcavePolygonShape3D).get_faces().size() / 3)
				print("MT probe z=", pz, " y=", pos.y, " hits ", body.name, " at ", node.global_position, " ", info)
		get_tree().quit()
		return
	cc.look_at_from_position(e + Vector3(1.5, 1.7, -4.0 * dd), e + Vector3(0, 0.0, 2.0 * dd), Vector3.UP)
	await _wait(0.4)
	await _shot("mt_c")
	cc.look_at_from_position(e + Vector3(0, 1.8, -3.0), e + Vector3(0, -1.5, 6.0), Vector3.UP)
	await _wait(0.4)
	await _shot("mt_d")
	cc.look_at_from_position(e + Vector3(-6.0, 3.0, 14.0), e + Vector3(0, 0.0, 6.0), Vector3.UP)
	await _wait(0.4)
	await _shot("mt_e")
	get_tree().quit()

## Dev: views of the gun shop and its parking lot
func _shop_view() -> void:
	await _wait(2.0)
	if cam: cam.current = false
	var cc3 := Camera3D.new()
	add_child(cc3)
	cc3.far = 600.0
	cc3.current = true
	var dc := GunShop.keeper_pos.x + 2.3
	var gy := GunShop.keeper_pos.y
	var z1 := GunShop.keeper_pos.z + 6.2
	var z0 := z1 - GunShop.D
	if player:
		player.global_position = Vector3(dc, gy + 0.1, z1 + 1.2)
	await _wait(0.8)
	for v in [
		["doors", Vector3(dc, gy + 1.6, z1 + 4.2), Vector3(dc, gy + 1.4, z1 - 2.5)],
		["counter", Vector3(dc, gy + 1.45, z1 - 3.0), Vector3(dc, gy + 1.35, z1 - 6.2)],
		["interior_side", Vector3(dc + 3.8, gy + 1.6, z1 - 2.2), Vector3(dc - 4.2, gy + 1.4, z1 - 3.6)],
		["rightwall", Vector3(dc - 2.0, gy + 1.6, z1 - 5.0), Vector3(dc + 6.5, gy + 1.5, z1 - 3.0)],
		["leftwall", Vector3(dc + 2.0, gy + 1.6, z1 - 5.0), Vector3(dc - 6.5, gy + 1.5, z1 - 3.0)],
		["melee_close", Vector3(dc - 3.0, gy + 1.6, z1 - 8.2), Vector3(dc - 7.0, gy + 1.5, z1 - 8.2)],
		["thrown_close", Vector3(dc + 3.0, gy + 1.5, z1 - 7.1), Vector3(dc + 7.0, gy + 1.2, z1 - 7.1)],
		["gunwall", Vector3(dc, gy + 1.6, z1 - 4.8), Vector3(dc, gy + 1.7, z0 + 0.06)],
		["front", Vector3(dc, gy + 2.6, z1 + 9.5), Vector3(dc, gy + 1.8, z1)],
		["parking", Vector3(dc + 14.0, gy + 5.0, z1 + 8.0), Vector3(dc + 5.0, gy + 1.5, z1 - 5.0)],
		["back", Vector3(dc + 4.0, gy + 6.5, z0 - 14.0), Vector3(dc + 4.0, gy + 1.2, z0 - 2.0)],
		["overhead", Vector3(dc + 4.0, gy + 20.0, z1 + 4.0), Vector3(dc + 4.0, gy + 1.0, z1 - 6.0)]
	]:
		cc3.look_at_from_position(v[1], v[2], Vector3.UP)
		cc3.make_current()
		await _wait(0.5)
		var is_nt := Game.weather != null and (Game.weather as Weather).is_night()
		var pfx := "shop_night" if is_nt else "shop"
		await _shot("%s_%s" % [pfx, v[0]])
	get_tree().quit()

## Dev: throw a grenade and a molotov and watch them go off (pictures th_*).
func _throw_test() -> void:
	await _wait(2.5)
	Game.guns_owned["x_grenade"] = 2
	Game.guns_owned["x_molotov"] = 2
	for id in ["x_grenade", "x_molotov"]:
		player.equip(id)
		await _wait(0.5)
		await _shot("th_%s_hand" % id)
		player._throw()
		await _wait(0.9)
		await _shot("th_%s_air" % id)
		await _wait(1.95 if id == "x_grenade" else 1.5)
		await _shot("th_%s_boom" % id)
		await _wait(0.4)
		await _shot("th_%s_after" % id)
		print("THROW ", id, " left ", Game.guns_owned.get(id, 0), " wanted ", Game.wanted)
		await _wait(1.0)
	get_tree().quit()

## Dev: watch every boat for 100 s: report any that leaves the water, and the lift bridge's opening as boats pass.
func _boat_test() -> void:
	await _wait(3.0)
	var bad := {}
	var maxopen := 0.0
	var open_steps := 0
	var worst := {}
	for i in 1200:                                         # 10 minutes of boating, stepped by hand
		for b in get_tree().get_nodes_in_group("boats"):
			(b as Boat)._process(0.5)
		if MiamiParks.bridge != null:
			MiamiParks.bridge._process(0.5)
			maxopen = maxf(maxopen, MiamiParks.bridge.open_t)
			if MiamiParks.bridge.open_t > 0.9: open_steps += 1
		for b in get_tree().get_nodes_in_group("boats"):
			var p := (b as Node3D).global_position
			if not Coast.is_water(p.x, p.z):
				bad[str((b as Node).get_instance_id())] = [snappedf(p.x, 0.1), snappedf(p.z, 0.1), i]
	print("BOAT offwater: ", bad, " bridge max open ", maxopen, " steps fully open ", open_steps, " of 1200 boats ", get_tree().get_nodes_in_group("boats").size())
	get_tree().quit()

## Dev: walk into a Miami shop through its sliding door (printed z / y / floor state), then out again.
func _isl_walk() -> void:
	await _wait(2.5)
	player.global_position = Vector3(63.5, 0.6, 1978.0)
	cam.yaw = 0.0
	await _wait(1.0)
	Input.action_press("move_forward")
	for i in 36:
		await _wait(0.15)
		print("IWALK z=%.2f y=%.2f floor=%s anim=%s" % [player.global_position.z, player.global_position.y, player.is_on_floor(), player.cur_anim])
	Input.action_release("move_forward")
	get_tree().quit()

## Dev: Redline Island from the air and from the street (pictures isl_*). `--islat=x,z,h,yaw` adds one custom view.
func _isl_view() -> void:
	await _wait(2.0)
	if "--nohud" in OS.get_cmdline_user_args() and hud != null:
		hud.visible = false
	player.global_position = Vector3(200, 3.0, 2200)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 4000.0
	cc.fov = 65.0
	await _wait(3.0)
	var views: Array = [
		["marina_parking", Vector3(150.0, 18.0, 1885.0), Vector3(150.0, 1.0, 1938.0)],
		["island_police", Vector3(250.0, 24.0, 2225.0), Vector3(250.0, 2.0, 2160.0)],
		["island_fire", Vector3(345.0, 24.0, 2225.0), Vector3(345.0, 2.0, 2160.0)],
		["island_hospital", Vector3(265.0, 26.0, 2175.0), Vector3(265.0, 2.0, 2245.0)],
		["emergency_avenue", Vector3(290.0, 70.0, 2200.0), Vector3(290.0, 0.0, 2200.0)],
		["sea_clean", Vector3(1050.0, 25.0, 2200.0), Vector3(1350.0, 0.0, 2200.0)]
	]
	if "--probe" in OS.get_cmdline_user_args():
		for z in [2000.0, 2200.0, 2400.0]:
			var row := "PROBE z=%d " % int(z)
			for x in range(-720, -380, 20):
				row += "[%d d%d h%.1f] " % [x, int(Coast.inland(x, z)), Coast.height_at(x, z)]
			print(row)
			row = "PROBE z=%d " % int(z)
			for x in range(800, 1160, 20):
				row += "[%d d%d h%.1f] " % [x, int(Coast.inland(x, z)), Coast.height_at(x, z)]
			print(row)
	var custom: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--islat="):
			var q := a.substr(8).split(",")
			var yaw := deg_to_rad(float(q[3]))
			var pos := Vector3(float(q[0]), float(q[2]), float(q[1]))
			var pitch := float(q[4]) if q.size() > 4 else -0.1
			custom.append(["c%d" % custom.size(), pos, pos + Vector3(sin(yaw), pitch, cos(yaw)) * 50.0])
	if not custom.is_empty(): views = custom
	for v in views:
		cc.look_at_from_position(v[1], v[2], Vector3.UP)
		cc.make_current()
		await _wait(1.5)
		await _shot("isl_%s" % v[0])
	get_tree().quit()

## Dev: open the grip editor, nudge and save a grip, reload it (picture grip_*).
func _grip_edit_test() -> void:
	await _wait(2.5)
	var ge := GripEditor.new()
	ge.name = "GripEditorNode"
	add_child(ge)
	await _wait(0.5)
	ge.idx = ge.ids.find("x_knife")
	ge._apply()
	await _wait(0.5)
	ge._nudge(Vector3(0, 0.05, 0))
	ge._rotate(Vector3.UP, 0.5)
	await _wait(0.3)
	await _shot("grip_editor")
	Weapons.set_grip("x_knife", "idle", player.grip_off)
	Weapons.save_grips()
	print("GRIPFILE ", FileAccess.get_file_as_string(Weapons.GRIP_FILE))
	get_tree().quit()

## Dev: every weapon class in the hand, idle and aiming, from the front-right (pictures wp_*).
func _weapons_view() -> void:
	await _wait(2.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 300.0
	cc.fov = 45.0
	var ids: Array = [] 
	var wanted: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="): wanted = a.substr(6)
	ids = wanted.split(",") if wanted != "" else ["", "Deagle", "Uzi", "AK47", "Spas_12", "L115_Awp", "x_bat", "x_axe", "x_knife"]
	Game.ammo_reserve = 500
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--maxis="): Weapons.melee_axis = int(a.substr(8))
		if a.begins_with("--msign="): Weapons.melee_sign = float(a.substr(8))
	for id in ids:
		if id != "": Game.guns_owned[id] = 50
		player.equip(id)
		await _wait(0.6)
		for aimed in [false, true]:
			player.force_aim = aimed and player.weapon == 1
			await _wait(0.5)
			var f := Vector3(sin(player.face), 0, cos(player.face))
			var r := Vector3(f.z, 0, -f.x)
			var at := player.global_position + Vector3(0, 1.1, 0)
			cc.look_at_from_position(at + r * 3.0 + Vector3(0, 0.3, 0), at, Vector3.UP)
			cc.make_current()
			await _wait(0.3)
			if aimed and player.weapon == 1:
				var rounds0: int = int(Game.guns_owned.get(id, 0))
				player._shoot()
				await _wait(0.12)
				print("FIRE ", id, " rounds ", rounds0, "->", int(Game.guns_owned.get(id, 0)), " reserve ", Game.ammo_reserve, " clip=", player.cur_anim)
			print("WEAPON ", id, " aim=", aimed, " anim=", player.cur_anim, " weapon=", player.weapon)
			await _shot("wp_%s_%s" % [id if id != "" else "pistol", "aim" if aimed else "idle"])
			cc.look_at_from_position(at + f * 2.8 + r * 0.9 + Vector3(0, 0.3, 0), at, Vector3.UP)
			await _wait(0.2)
			await _shot("wp_%s_%s_front" % [id if id != "" else "pistol", "aim" if aimed else "idle"])
			cc.look_at_from_position(at + r * 2.2 + Vector3(0, 0.1, 0), at, Vector3.UP)
			await _wait(0.2)
			await _shot("wp_%s_%s_side" % [id if id != "" else "pistol", "aim" if aimed else "idle"])
			cc.look_at_from_position(at + Vector3(0, 2.6, 0) - f * 0.3, at, Vector3.RIGHT)
			await _wait(0.2)
			await _shot("wp_%s_%s_top" % [id if id != "" else "pistol", "aim" if aimed else "idle"])
			if player.weapon == 2 and not aimed:
				cc.look_at_from_position(player.global_position + Vector3(0, 1.0, 0) + f * 1.3 + r * 0.7, player.global_position + Vector3(0, 0.95, 0) + f * 0.2, Vector3.UP)
				await _wait(0.2)
				await _shot("wp_%s_hand" % id)
		if player.weapon == 1 and bool(player.held_info.get("scope", false)):
			player.force_aim = false
			Input.action_press("aim")
			await _wait(1.2)
			cc.current = false
			cam.make_current()
			await _wait(0.4)
			await _shot("wp_%s_scope" % id)
			Input.action_release("aim")
			await _wait(0.3)
		if player.weapon == 2:
			player.force_aim = false
			player._melee_attack()
			await _wait(0.35)
			print("WEAPON ", id, " swing anim=", player.cur_anim)
			await _shot("wp_%s_swing" % id)
	player.force_aim = false
	get_tree().quit()

## Dev: walk from the pavement through the shop door and print the animation / floor state each step.
func _shop_walk() -> void:
	await _wait(2.0)
	var dc := GunShop.keeper_pos.x + 2.3
	var z1 := GunShop.keeper_pos.z + 6.2
	player.global_position = Vector3(dc, 0.5, z1 + 5.0)
	cam.yaw = 0.0
	await _wait(0.8)
	Input.action_press("move_forward")
	for i in 40:
		await _wait(0.1)
		print("WALK z=%.2f y=%.2f floor=%s anim=%s vy=%.2f" % [player.global_position.z - z1, player.global_position.y, player.is_on_floor(), player.cur_anim, player.velocity.y])
	Input.action_release("move_forward")
	get_tree().quit()

## Dev: test shots of the Redline Ammo weapon catalog interface
func _gunmenu_shots() -> void:
	await _wait(2.0)
	GunMenu.toggle_for(self)
	await _wait(1.0)
	await _shot("gunmenu_pistols")
	var gm: GunMenu = null
	for ch in get_children():
		if ch is GunMenu:
			gm = ch as GunMenu
			break
	if gm:
		gm._shift_cat(3) # Switch to Shotguns category
		await _wait(0.8)
		await _shot("gunmenu_shotguns")
		gm._shift_cat(-1) # Switch to Rifles category
		await _wait(0.8)
		await _shot("gunmenu_rifles")
		gm._shift_cat(4) # Melee
		await _wait(1.5)
		await _shot("gunmenu_melee")
		gm._shift_cat(1) # Thrown
		await _wait(1.5)
		await _shot("gunmenu_thrown")
		gm._move(1)
		await _wait(1.0)
		await _shot("gunmenu_molotov")
	get_tree().quit()



## Dev: the live "next train" boards at both stations, close up (pictures bd_*). Needs the full build.
func _board_view() -> void:
	await _wait(4.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 600.0
	cc.fov = 55.0
	var n := 0
	for st in Game.world.static_root.get_children():
		if st.name != "TrainStation": continue
		var root := st as Node3D
		for ch in root.get_children():
			if ch is StationBoards:
				var lab: Label3D = (ch as StationBoards).labels[0][0]
				var holder := lab.get_parent() as Node3D
				var gp := holder.global_position
				var nrm := holder.global_transform.basis.z
				cc.look_at_from_position(gp + nrm * 4.5 + Vector3(0, 0.2, 0), gp, Vector3.UP)
				cc.make_current()
				await _wait(1.6)
				await _shot("bd_%d" % n)
				n += 1
	get_tree().quit()

## Dev: the train seen from in front, from the side and from behind at the current hour (pictures tl_*). Needs the full build.
func _train_lamps() -> void:
	await _wait(3.0)
	var tr: Train = null
	for t in get_tree().get_nodes_in_group("trains"):
		tr = t as Train
		break
	var fwd := tr.global_transform.basis.x
	var side := tr.global_transform.basis.z
	var pos := tr.global_position
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 900.0
	cc.fov = 60.0
	for v in [["front", pos, pos + fwd * 17.0 + Vector3(0, 0.8, 0)], ["side", pos, pos + fwd * 17.0 + Vector3(0, 1.0, 0)], ["back", pos - fwd * 20.0 + side * 6.0 + Vector3(0, 2.5, 0), pos - fwd * 8.0 + Vector3(0, 1.5, 0)]]:
		var from: Vector3 = v[1] if v[0] != "side" else v[1]
		if v[0] == "front": from = pos + fwd * 50.0 + side * 2.0 + Vector3(0, 2.2, 0)
		if v[0] == "side": from = pos + fwd * 30.0 + side * 9.0 + Vector3(0, 3.0, 0)
		if v[0] == "back": from = pos - fwd * 28.0 + side * 8.0 + Vector3(0, 2.5, 0)
		cc.look_at_from_position(from, v[2], Vector3.UP)
		cc.make_current()
		await _wait(0.5)
		await _shot("tl_%s" % v[0])
	get_tree().quit()

## Dev: floodlights at both stations and the airport apron (pictures fl_*). Needs the full build.
func _flood_view() -> void:
	await _wait(3.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 1500.0
	var views: Array = []
	for i in range(2):
		var a := Rail.at(Rail.station_s[i] + Rail.PLATFORM_Z)
		var p: Vector2 = a[0]
		views.append(["st%d_top" % i, Vector3(p.x, 120, p.y + 1), Vector3(p.x, 0, p.y), true])
		views.append(["st%d_side" % i, Vector3(p.x - 40, 8, p.y + 60), Vector3(p.x, 8, p.y), false])
	views.append(["air_top", Vector3(880, 230, -910), Vector3(880, 0, -915), true])
	views.append(["air_ground", Vector3(880, 14, -850), Vector3(880, 8, -930), false])
	for v in views:
		cc.look_at_from_position(v[1], v[2], Vector3(0, 0, -1) if v[3] else Vector3.UP)
		cc.make_current()
		await _wait(0.9)
		await _shot("fl_%s" % v[0])
	get_tree().quit()

## Dev: the carnival at the current hour from three places (pictures fair_*).
func _fair_view() -> void:
	await _wait(3.0)
	var o := Vector3(-286.5, 0.0, 95.5)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 700.0
	for v in [["wide", Vector3(-10, 38, 150), Vector3(0, 4, 0)], ["tower", Vector3(-30, 6, 100), Vector3(-80, 17, 80)], ["top", Vector3(0, 200, 1), Vector3(0, 0, 0)]]:
		cc.look_at_from_position(o + v[1], o + v[2], Vector3.UP if v[0] != "top" else Vector3(0, 0, -1))
		cc.make_current()
		await _wait(0.8)
		await _shot("fair_%s" % v[0])
	get_tree().quit()

## Dev: one picture per building type, from the street (pictures nv_<key>).
func _night_view() -> void:
	await _wait(2.5)
	var keys: Array = ["r1", "r2a", "r2b", "r2c", "fire", "police", "bordeaux"] if "--real" in OS.get_cmdline_user_args() else ["soviet", "atl", "york", "asian", "hospital", "boc", "wtc", "ait", "hirise"]
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("--only="): keys = Array(a2.substr(7).split(","))
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 900.0
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.12, 0.13, 0.15)
	for i in range(keys.size()):
		var key: String = keys[i]
		var sp: Dictionary = CityBuild.specs[key]
		var sz: Vector3 = sp.size
		var at := Vector3(0.0, 600.0, 400.0 + i * 140.0)
		var gr := MeshInstance3D.new()
		var gb := BoxMesh.new()
		gb.size = Vector3(160, 1, 120)
		gr.mesh = gb
		gr.material_override = gmat
		add_child(gr)
		gr.global_position = at + Vector3(0, -0.5, 0)
		var mi := MeshInstance3D.new()
		mi.mesh = sp.mesh
		add_child(mi)
		if "--nowin" in OS.get_cmdline_user_args():
			# hide the transparent window / glass / blind surfaces to see the building without its window layer
			var hide_mat := StandardMaterial3D.new()
			hide_mat.albedo_color = Color(1, 1, 1, 0.0)
			hide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for si in range((sp.mesh as Mesh).get_surface_count()):
				var sm0 := (sp.mesh as Mesh).surface_get_material(si)
				if sm0 is BaseMaterial3D and (sm0 as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					mi.set_surface_override_material(si, hide_mat)
		mi.global_position = at
		mi.rotation.y = float(sp.yaw0) if key != "police" else 0.0
		var d := maxf(sz.y * 1.6, maxf(sz.x, sz.z) * 1.2)
		cc.look_at_from_position(at + Vector3(d * 0.35, sz.y * 0.35, d), at + Vector3(0, sz.y * 0.45, 0), Vector3.UP)
		if key == "hirise": cc.look_at_from_position(at + Vector3(30, 55, 75), at + Vector3(0, 55, 0), Vector3.UP)
		cc.make_current()
		await _wait(0.5)
		await _shot("nv_%s" % key)
	get_tree().quit()

## Dev: the station staff in a line in front of the player (pictures npc_*).
func _npc_lineup() -> void:
	await _wait(2.5)
	var base := player.global_position + Vector3(0, 0, 0)
	var ids := ["npc_police", "npc_doctor", "npc_nurse"]
	var x := -3.0
	for id in ids:
		var ped := Ped.new()
		add_child(ped)
		ped.global_position = base + Vector3(x, 0.6, 6.0)
		var pts: Array[Vector3] = [ped.global_position, ped.global_position + Vector3(0, 0, 3.0)]
		ped.setup(id, pts, 0, 1)
		x += 1.5
	var fig: Node3D = Game.load_static_figure("res://assets/npc/character_type_fire_fighter.glb", 1.82)
	add_child(fig)
	fig.global_position = base + Vector3(x, 0.0, 6.0)
	fig.rotation.y = PI
	await _wait(2.0)
	var cc := Camera3D.new()
	add_child(cc)
	for k in [["a", Vector3(1.0, 1.4, 0.0)], ["b", Vector3(1.0, 1.4, 12.0)]]:
		cc.look_at_from_position(base + k[1], base + Vector3(0.8, 1.0, 6.0), Vector3.UP)
		cc.make_current()
		await _wait(0.6)
		await _shot("npc_%s" % k[0])
	get_tree().quit()

## Dev: every vehicle type in a row with lights on and braking, seen from the front and the rear (pictures lit_*).
func _lights_test() -> void:
	await _wait(2.5)
	var kinds := ["hatch", "taxi", "fumi", "police", "ambulance", "firetruck"]
	var cars: Array = []
	for i in range(kinds.size()):
		var a := Car.new()
		a.position = Vector3(8.0 + i * 5.0, 1.2, 40.0)
		add_child(a)
		a.setup(kinds[i], "", false)
		cars.append(a)
	await _wait(2.5)
	for a in cars:
		a.set_lights(true)
		a.scripted = true
		a.s_hand = true
	var cc := Camera3D.new()
	add_child(cc)
	for k in [["front", Vector3(20.0, 1.3, 50.0), Vector3(20.0, 0.9, 40.0)], ["rear", Vector3(20.0, 1.6, 30.0), Vector3(20.0, 0.9, 40.0)]]:
		cc.look_at_from_position(k[1], k[2], Vector3.UP)
		cc.make_current()
		await _wait(0.5)
		await _shot("lit_%s" % k[0])
	get_tree().quit()

## Dev: police cruiser from several sides, doors shut then open, lights and siren on (pictures cru_*).
func _cruiser_views(kind := "police", prefix := "cru") -> void:
	await _wait(2.5)
	var a := Car.new()
	a.position = Vector3(8.0, 1.2, 40.0)
	add_child(a)
	a.setup(kind, "", false)
	await _wait(2.0)
	print("CRU pos ", a.global_position, " wheels ", a.wheels.size(), " door_fl ", a.door_fl != null, " door_fr ", a.door_fr != null, " len ", a.model_len)
	a.set_lights(true)
	var cc := Camera3D.new()
	add_child(cc)
	cc.current = true
	var views := {
		"front": [Vector3(2.0, 1.1, 5.5), Vector3(0, 0.7, 2.4)],
		"rear": [Vector3(-1.5, 1.2, -5.5), Vector3(0, 0.8, -2.2)],
		"driver": [Vector3(5.0, 1.2, 0.2), Vector3(0, 0.8, 0.2)],
		"pass": [Vector3(-5.0, 1.2, 0.2), Vector3(0, 0.8, 0.2)],
	}
	for k in views:
		cc.look_at_from_position(a.to_global(views[k][0]), a.to_global(views[k][1]), Vector3.UP)
		cc.make_current()
		await _wait(0.3)
		await _shot(prefix + "_%s_closed" % k)
	a.toggle_siren()
	a.open_door(-1.0, 0.1, Car.DOOR_WIDE)
	a.door_fr.rotation.y = 1.3
	await _wait(1.0)
	for k in views:
		cc.look_at_from_position(a.to_global(views[k][0]), a.to_global(views[k][1]), Vector3.UP)
		cc.make_current()
		await _wait(0.3)
		await _shot(prefix + "_%s_open" % k)
	player.global_position = a.to_global(Vector3(2.4, 0.2, 0.3))
	player._try_enter_car()
	await _wait(6.0)
	a.open_door(-1.0, 0.1, Car.DOOR_WIDE)
	cc.look_at_from_position(a.to_global(Vector3(3.0, 1.0, 0.6)), a.to_global(Vector3(0.4, 0.8, 0.0)), Vector3.UP)
	await _wait(0.8)
	await _shot(prefix + "_seat")
	get_tree().quit()

## Dev: bail out of a flying aeroplane; it flies on and crashes (pictures pb_*).
func _plane_bail() -> void:
	await _wait(2.5)
	var pl := Airplane.new()
	pl.kind = "passenger"
	add_child(pl)
	pl.global_position = player.global_position + Vector3(0, 150.0, 40.0)
	pl.speed = 70.0
	pl.engine = 1.0
	await _wait(0.5)
	pl.enter(player)
	await _wait(1.5)
	pl.try_exit()
	cam.make_current()
	for k in range(8):
		await _wait(1.0)
		print("PB t=", k, " mode=", player.air_mode, " py=", snappedf(player.global_position.y, 0.1), " plane_alive=", is_instance_valid(pl), " plane=", (pl.global_position if is_instance_valid(pl) else Vector3.ZERO), " speed=", (snappedf(pl.speed, 0.1) if is_instance_valid(pl) else 0))
		await _shot("pb_%d" % k)
	await _wait(10.0)
	print("PB end mode=", player.air_mode, " alive=", is_instance_valid(pl))
	await _shot("pb_end")
	get_tree().quit()

## Dev: the player hanging under the parachute, held still, seen from the side, behind and in front (pictures chute_*).
func _chute_fit() -> void:
	await _wait(2.5)
	player.global_position = player.global_position + Vector3(0, 12.0, 0)
	player.set_physics_process(false)
	player._add_pack()
	player._chute = player._make_chute()
	player.add_child(player._chute)
	player.play("Floating", 1.0, 0.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.far = 500.0
	var c := player.global_position + Vector3(0, 4.0, 0)
	for k in [["side", Vector3(16, 0, 0)], ["back", Vector3(0, 0, -16)], ["front", Vector3(0, 0, 16)], ["close", Vector3(3.2, -1.2, -3.0)], ["closeside", Vector3(4.0, -1.5, 0.0)]]:
		cc.look_at_from_position(c + k[1], c + (Vector3(0, -1.5, 0) if k[0] == "close" else Vector3.ZERO), Vector3.UP)
		cc.make_current()
		await _wait(0.5)
		await _shot("chute_%s" % k[0])
	get_tree().quit()

## Dev: board a helicopter, climb, bail out; pictures bail_* (fall, parachute, blast, landing).
func _bailout_test() -> void:
	await _wait(2.5)
	var h := Chopper.new()
	add_child(h)
	h.global_position = player.global_position + Vector3(12, 1.0, 0)
	await _wait(0.5)
	h.enter(player)
	var cc := Camera3D.new()
	add_child(cc)
	h.engine = 1.0
	h.global_position.y += 70.0
	await _wait(0.5)
	h.bail_out()
	print("BAIL anims: ", player.anim.has_animation("Falling Idle"), player.anim.has_animation("Floating"), player.anim.has_animation("Falling To Landing"), player.anim.has_animation("Hard Landing"))
	cam.make_current()
	for k in range(6):
		await _wait(1.0)
		if player._chute != null:
			var cn := player._chute.get_meta("canopy") as Node3D
			var bb := AABB(); var fi := true
			for mi in cn.find_children("*", "MeshInstance3D", true, false):
				var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				bb = b if fi else bb.merge(b); fi = false
			print("BAIL chute aabb ", bb.position, bb.size, " player ", player.global_position, " cam ", cam.global_position)
		print("BAIL t=", k, " mode=", player.air_mode, " y=", snappedf(player.global_position.y, 0.1), " heli_alive=", is_instance_valid(h))
		await _shot("bail_%d" % k)
	await _wait(8.0)
	print("BAIL end mode=", player.air_mode, " y=", player.global_position.y, " heli_alive=", is_instance_valid(h))
	await _shot("bail_end")
	get_tree().quit()

## Dev: ambulance tail lights with lights off, then braking (pictures amb_brake_*).
func _amb_brake() -> void:
	await _wait(2.5)
	var a := Car.new()
	a.position = Vector3(8.0, 1.2, 40.0)
	add_child(a)
	a.setup("ambulance", "", false)
	await _wait(2.0)
	var cc := Camera3D.new()
	add_child(cc)
	cc.current = true
	var spots := {"close": [Vector3(0.9, 1.0, -4.3), Vector3(0, 1.0, -2.9)], "wide": [Vector3(2.5, 1.5, -7.0), Vector3(0, 1.0, -2.9)]}
	for k in spots:
		cc.look_at_from_position(a.to_global(spots[k][0]), a.to_global(spots[k][1]), Vector3.UP)
		await _wait(0.3)
		await _shot("amb_brake_off_%s" % k)
	a.scripted = true
	a.s_hand = true
	await _wait(0.5)
	for k in spots:
		cc.look_at_from_position(a.to_global(spots[k][0]), a.to_global(spots[k][1]), Vector3.UP)
		await _wait(0.3)
		await _shot("amb_brake_on_%s" % k)
	get_tree().quit()

## Dev: ambulance from several sides with lights on, doors shut and then open (pictures amv_*).
func _amb_views() -> void:
	await _wait(2.5)
	var a := Car.new()
	a.position = Vector3(8.0, 1.2, 40.0)
	add_child(a)
	a.setup("ambulance", "", false)
	await _wait(2.0)
	a.set_lights(true)
	var cc := Camera3D.new()
	add_child(cc)
	cc.current = true
	var views := {
		"rear": [Vector3(0.0, 1.2, -5.0), Vector3(0, 1.0, -2.9)],
		"rear_l": [Vector3(-3.6, 1.6, -4.6), Vector3(0, 1.0, -2.6)],
		"rear_r": [Vector3(3.6, 1.6, -4.6), Vector3(0, 1.0, -2.6)],
		"left": [Vector3(-6.5, 1.7, 0.0), Vector3(0, 1.3, 0.0)],
		"front": [Vector3(2.5, 1.4, 6.5), Vector3(0, 0.9, 2.6)],
		"front_close": [Vector3(1.4, 0.9, 5.0), Vector3(0, 0.8, 3.0)],
		"rear_close": [Vector3(0.9, 1.0, -4.3), Vector3(0, 1.0, -2.9)],
	}
	for k in views:
		cc.look_at_from_position(a.to_global(views[k][0]), a.to_global(views[k][1]), Vector3.UP)
		await _wait(0.3)
		await _shot("amv_%s_closed" % k)
	a.toggle_rear_doors()
	a.open_door(-1.0, 0.1, Car.DOOR_WIDE)
	await _wait(1.2)
	for k in views:
		cc.look_at_from_position(a.to_global(views[k][0]), a.to_global(views[k][1]), Vector3.UP)
		await _wait(0.3)
		await _shot("amv_%s_open" % k)
	get_tree().quit()

## Dev: spawns an ambulance beside the player, opens its driver's door and starts the siren, and takes pictures.
func _amb_test() -> void:
	await _wait(2.5)
	var a := Car.new()
	a.position = Vector3(8.0, 1.2, 40.0)
	add_child(a)
	a.setup("ambulance", "", false)
	await _wait(2.0)
	a.open_door(-1.0, 0.1, Car.DOOR_WIDE)
	a.door_fr.rotation.y = 1.4
	a.toggle_siren()
	a.set_lights(true)
	a.toggle_rear_doors()
	var cc := Camera3D.new()
	add_child(cc)
	cc.look_at_from_position(a.to_global(Vector3(6.0, 2.2, 4.0)), a.to_global(Vector3(0, 1.0, 0.5)), Vector3.UP)
	cc.current = true
	print("AMBTEST wheels=", a.wheels.size(), " door_fl=", a.door_fl != null, " door_fr=", a.door_fr != null, " drv_x=", a.drv_x)
	await _wait(0.4)
	await _shot("amb_a")
	await _wait(0.12)
	await _shot("amb_b")
	cc.look_at_from_position(a.to_global(Vector3(1.6, 1.5, -3.6)), a.to_global(Vector3(0, 1.2, -2.2)), Vector3.UP)
	await _wait(0.3)
	await _shot("amb_rear")
	player.global_position = a.to_global(Vector3(3.5, 0.2, 0.9))
	cc.look_at_from_position(a.to_global(Vector3(5.0, 1.6, -4.0)), a.to_global(Vector3(0, 1.0, 0.5)), Vector3.UP)
	player._try_enter_car()
	await _wait(6.0)
	print("AMBTEST in car: ", Game.in_car == a)
	a.open_door(-1.0, 0.1, Car.DOOR_WIDE)
	cc.look_at_from_position(a.to_global(Vector3(3.2, 1.3, 1.5)), a.to_global(Vector3(0.4, 1.0, 1.5)), Vector3.UP)
	await _wait(0.8)
	await _shot("amb_seat_side")
	cc.look_at_from_position(a.to_global(Vector3(0.5, 1.6, -0.6)), a.to_global(Vector3(0.5, 1.0, 1.5)), Vector3.UP)
	await _wait(0.3)
	await _shot("amb_seat_back")
	a.scripted = true
	a.s_throttle = 1.0
	await _wait(3.0)
	print("AMBTEST speed %.1f m/s" % absf(a.speed_ms))
	cc.current = false
	cam.make_current()
	await _wait(1.0)
	await _shot("amb_c")
	get_tree().quit()
