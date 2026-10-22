extends Node
## Dev tool: prints the lowest foot/toe height over each animation cycle (should be ~0 when planted).
func _ready() -> void:
	await get_tree().process_frame
	var model: Node3D = Game.load_character(Game.HERO)
	add_child(model)
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Game.get_anim_library())
	var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var names := ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]
	var rest_low := 99.0
	sk.reset_bone_poses()
	for n in names:
		var i := sk.find_bone(n)
		rest_low = minf(rest_low, (sk.global_transform * sk.get_bone_global_pose(i)).origin.y)
	print("FOOT rest lowest bone y=%.3f" % rest_low)
	for a in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Jump", "Pistol_Idle"]:
		ap.play(a)
		ap.pause()
		var lo := 99.0
		var hi := -99.0
		var hips_lo := 99.0
		var hips_hi := -99.0
		var len := ap.get_animation(a).length
		for k in range(24):
			ap.seek(len * k / 24.0, true)
			sk.force_update_all_bone_transforms() if sk.has_method("force_update_all_bone_transforms") else null
			var m := 99.0
			for n in names:
				var i := sk.find_bone(n)
				m = minf(m, (sk.global_transform * sk.get_bone_global_pose(i)).origin.y)
			lo = minf(lo, m)
			hi = maxf(hi, m)
			var hy := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips"))).origin.y
			hips_lo = minf(hips_lo, hy)
			hips_hi = maxf(hips_hi, hy)
		print("FOOT %-12s lowest foot/toe min=%.3f max=%.3f  hips %.3f..%.3f (len %.2fs)" % [a, lo, hi, hips_lo, hips_hi, len])
	get_tree().quit()
