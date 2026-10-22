extends SceneTree
## Dev tool: estimates each locomotion clip's natural ground speed (planted-foot speed) to tune playback speeds.
## Run: godot --path . -s res://scripts/anim_speed_test.gd
func _initialize() -> void:
	await process_frame
	var game := root.get_node("Game")
	var model: Node3D = game.load_character("hero")
	root.add_child(model)
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", game.get_anim_library("hero"))
	var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var lf := sk.find_bone("mixamorig_LeftFoot")
	var rf := sk.find_bone("mixamorig_RightFoot")
	for name in ["Walk", "Pistol_Walk", "Jog_Fwd", "Pistol_Run", "Sprint"]:
		if not ap.has_animation(name):
			print(name, ": missing")
			continue
		ap.play(name)
		ap.pause()
		var len := ap.get_animation(name).length
		var n := 120
		var ys: Array[float] = []
		var zs: Array[float] = []
		var xs: Array[float] = []
		for i in range(n):
			ap.seek(len * i / n, true)
			ap.advance(0.0)
			sk.force_update_all_bone_transforms()
			var p: Vector3 = (sk.global_transform * sk.get_bone_global_pose(lf)).origin
			ys.append(p.y)
			zs.append(p.z)
			xs.append(p.x)
		var ymin: float = ys.min()
		var dt := len / n
		var sum := 0.0
		var sumx := 0.0
		var cnt := 0
		for i in range(n):
			var j := (i + 1) % n
			if ys[i] < ymin + 0.04 and ys[j] < ymin + 0.04:
				sum += (zs[j] - zs[i]) / dt
				sumx += (xs[j] - xs[i]) / dt
				cnt += 1
		print("%s: length %.2fs  planted-foot velocity z %.2f x %.2f m/s (samples %d)" % [name, len, -sum / maxf(cnt, 1), -sumx / maxf(cnt, 1), cnt])
	# where do the arms point in the pistol stances?
	var names := ["Pistol_Aim_Neutral", "Pistol_Aim_Up", "Pistol_Aim_Down", "Pistol_Walk", "Pistol_Run"]
	for name in names:
		if not ap.has_animation(name): continue
		ap.play(name)
		ap.pause()
		for t in [0.0, 0.2, 0.4]:
			ap.seek(t, true)
			ap.advance(0.0)
			sk.force_update_all_bone_transforms()
			var rh: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand"))).origin
			var lh: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftHand"))).origin
			var nk: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_Neck"))).origin
			var hd: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_Head"))).origin
			var mid := (rh + lh) * 0.5
			var d := mid - nk
			print("%s t=%.1f  arms yaw %.1f deg (x %.2f z %.2f)  rh %s lh %s  head %s" % [name, t, rad_to_deg(atan2(d.x, d.z)), mid.x - nk.x, mid.z - nk.z, rh, lh, hd])
	# gun versus hands
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_RightHand"
	sk.add_child(ba)
	var gun := HandGun.make()
	ba.add_child(gun)
	for name in ["Pistol_Aim_Neutral", "Pistol_Walk", "Pistol_Run"]:
		ap.play(name)
		ap.pause()
		ap.seek(0.2, true)
		ap.advance(0.0)
		await process_frame
		await process_frame
		HandGun.hold(gun)
		await process_frame
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for mi in gun.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var bb := m.get_aabb()
			for c in 8:
				var corner := bb.position + bb.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1)
				var w := m.global_transform * corner
				lo = lo.min(w)
				hi = hi.max(w)
		var rh: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand"))).origin
		var lh: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftHand"))).origin
		print("GUN %s: centre x %.3f y %.3f z %.3f (size %.2f %.2f %.2f)  hands mid x %.3f  rh x %.3f lh x %.3f" % [name, (lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, (rh.x + lh.x) * 0.5, rh.x, lh.x])
	quit()
