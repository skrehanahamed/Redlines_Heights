class_name Retarget
extends RefCounted
## Retargets animations from the Universal Animation Library skeleton (UAL, Z-up, 65 bones)
## onto a Mixamo-style PSX character skeleton (mixamorig_*). Works in world space so different
## bone axes and rest poses do not matter much.

const BONE_MAP := {
	"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2",
	"neck_01": "Neck", "Head": "Head",
	"clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm", "lowerarm_l": "LeftForeArm", "hand_l": "LeftHand",
	"clavicle_r": "RightShoulder", "upperarm_r": "RightArm", "lowerarm_r": "RightForeArm", "hand_r": "RightHand",
	"thigh_l": "LeftUpLeg", "calf_l": "LeftLeg", "foot_l": "LeftFoot", "ball_l": "LeftToeBase",
	"thigh_r": "RightUpLeg", "calf_r": "RightLeg", "foot_r": "RightFoot", "ball_r": "RightToeBase",
}

const CHILD := {"pelvis": "spine_01", "spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01", "neck_01": "Head",
	"clavicle_l": "upperarm_l", "upperarm_l": "lowerarm_l", "lowerarm_l": "hand_l",
	"clavicle_r": "upperarm_r", "upperarm_r": "lowerarm_r", "lowerarm_r": "hand_r",
	"thigh_l": "calf_l", "calf_l": "foot_l", "foot_l": "ball_l", "thigh_r": "calf_r", "calf_r": "foot_r", "foot_r": "ball_r"}

static func _rest_positions(sk: Skeleton3D, grest: Array) -> Array:
	var pos: Array = []
	pos.resize(sk.get_bone_count())
	for i in range(sk.get_bone_count()):
		var p := sk.get_bone_parent(i)
		var o := sk.get_bone_rest(i).origin
		pos[i] = o if p < 0 else (pos[p] as Vector3) + (grest[p] as Quaternion) * o
	return pos

static func _node_to_root_rotation(n: Node) -> Quaternion:
	# rotation (no scale) of node n relative to the scene root, for nodes not necessarily in a tree
	var q := Quaternion.IDENTITY
	var cur := n
	while cur != null:
		if cur is Node3D:
			q = (cur as Node3D).transform.basis.orthonormalized().get_rotation_quaternion() * q
		cur = cur.get_parent()
	return q

static func _global_rests(sk: Skeleton3D) -> Array:
	var g: Array = []
	g.resize(sk.get_bone_count())
	for i in range(sk.get_bone_count()):
		var p := sk.get_bone_parent(i)
		var rq := sk.get_bone_rest(i).basis.get_rotation_quaternion()
		g[i] = rq if p < 0 else (g[p] as Quaternion) * rq
	return g

## Build a map "bone name -> track index" for rotation / position tracks of an animation.
static func _tracks_by_bone(anim: Animation) -> Dictionary:
	var rot := {}; var pos := {}
	for t in range(anim.get_track_count()):
		var path := String(anim.track_get_path(t))
		var c := path.rfind(":")
		if c < 0: continue
		var bone := path.substr(c + 1)
		match anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D: rot[bone] = t
			Animation.TYPE_POSITION_3D: pos[bone] = t
	return {"rot": rot, "pos": pos}

const BONE_TARGETS := {
	"pelvis": ["pelvis", "hips"],
	"spine_01": ["spine", "spine1"],
	"spine_02": ["spine1", "spine2", "belly"],
	"spine_03": ["spine2", "spine3"],
	"neck_01": ["neck"],
	"Head": ["head"],
	"clavicle_l": ["l clavicle", "clavicle l", "l shoulder", "leftshoulder"],
	"upperarm_l": ["l upperarm", "upperarm l", "l arm", "leftarm"],
	"lowerarm_l": ["l forearm", "forearm l", "leftforearm"],
	"hand_l": ["l hand", "hand l", "lefthand"],
	"clavicle_r": ["r clavicle", "clavicle r", "r shoulder", "rightshoulder"],
	"upperarm_r": ["r upperarm", "upperarm r", "r arm", "rightarm"],
	"lowerarm_r": ["r forearm", "forearm r", "rightforearm"],
	"hand_r": ["r hand", "hand r", "righthand"],
	"thigh_l": ["l thigh", "thigh l", "l upleg", "leftupleg"],
	"calf_l": ["l calf", "calf l", "l leg", "leftleg"],
	"foot_l": ["l foot", "foot l", "leftfoot"],
	"ball_l": ["l toe", "toe0 l", "lefttoebase"],
	"thigh_r": ["r thigh", "thigh r", "r upleg", "rightupleg"],
	"calf_r": ["r calf", "calf r", "r leg", "rightleg"],
	"foot_r": ["r foot", "foot r", "rightfoot"],
	"ball_r": ["r toe", "toe0 r", "righttoebase"],
}

static func _normalize_bone(name: String) -> String:
	var s := name.to_lower()
	var rx := RegEx.create_from_string("_0?\\d+$")
	s = rx.sub(s, "")
	s = s.trim_prefix("mixamorig_").trim_prefix("mixamorig:").trim_prefix("robot ")
	s = s.replace("_", " ").strip_edges()
	return s

static func _find_matching_bone(dst_sk: Skeleton3D, sn: String) -> int:
	if BONE_MAP.has(sn):
		var target: String = BONE_MAP[sn]
		var di := dst_sk.find_bone("mixamorig_" + target)
		if di >= 0: return di
		di = dst_sk.find_bone(target)
		if di >= 0: return di
	if BONE_TARGETS.has(sn):
		var targets: Array = BONE_TARGETS[sn]
		for i in range(dst_sk.get_bone_count()):
			var nb := _normalize_bone(dst_sk.get_bone_name(i))
			for t in targets:
				if nb == t:
					return i
		for i in range(dst_sk.get_bone_count()):
			var nb := _normalize_bone(dst_sk.get_bone_name(i))
			for t in targets:
				if nb.ends_with(t) or nb.begins_with(t) or (" " + t + " ") in (" " + nb + " "):
					return i
	return -1

static func build_library(src_root: Node, dst_root: Node, wanted: PackedStringArray, fps := 30.0) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var src_sk := src_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var dst_sk := dst_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var src_ap := src_root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var Rs := _node_to_root_rotation(src_sk)
	var Rd := _node_to_root_rotation(dst_sk)
	var gs_rest := _global_rests(src_sk)
	var gd_rest := _global_rests(dst_sk)
	# map src bone index -> dst bone index
	var s2d := {}
	for i in range(src_sk.get_bone_count()):
		var sn := src_sk.get_bone_name(i)
		var di := _find_matching_bone(dst_sk, sn)
		if di >= 0: s2d[i] = di
	var d2s := {}
	for k in s2d: d2s[s2d[k]] = k
	# rest-pose alignment: rotate each dst bone so its rest direction equals the src rest direction
	var ps := _rest_positions(src_sk, gs_rest)
	var pd := _rest_positions(dst_sk, gd_rest)
	var qfix := {}   # src bone idx -> Quaternion (world)
	for si in s2d:
		var sn := src_sk.get_bone_name(si)
		var target_child: String = CHILD.get(sn, "")
		while target_child != "" and not s2d.has(src_sk.find_bone(target_child)):
			target_child = CHILD.get(target_child, "")
		if target_child != "":
			var sc := src_sk.find_bone(target_child)
			var dc: int = s2d.get(sc, -1)
			if sc >= 0 and dc >= 0:
				var ds: Vector3 = (Rs * ((ps[sc] as Vector3) - (ps[si] as Vector3))).normalized()
				var dd: Vector3 = (Rd * ((pd[dc] as Vector3) - (pd[s2d[si]] as Vector3))).normalized()
				qfix[si] = Quaternion(dd, ds)
	for si in s2d:
		if not qfix.has(si):
			var p := src_sk.get_bone_parent(si)
			while p >= 0 and not qfix.has(p): p = src_sk.get_bone_parent(p)
			qfix[si] = qfix[p] if p >= 0 else Quaternion.IDENTITY
	var dst_path := String(dst_root.get_path_to(dst_sk)) if dst_root.is_inside_tree() else _rel_path(dst_root, dst_sk)
	var hip_dst := _find_matching_bone(dst_sk, "pelvis")
	var hip_src := src_sk.find_bone("pelvis")
	var height_ratio := 1.0
	if hip_dst >= 0 and hip_src >= 0:
		var hs := (ps[hip_src] as Vector3).length()
		var hd := (pd[hip_dst] as Vector3).length()
		height_ratio = hd / maxf(hs, 0.001)
	for aname in wanted:
		if not src_ap.has_animation(aname): continue
		var sa := src_ap.get_animation(aname)
		var tb := _tracks_by_bone(sa)
		var out := Animation.new()
		out.length = sa.length
		out.loop_mode = Animation.LOOP_LINEAR if aname.begins_with(("Idle")) or aname in ["Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Crouch_Idle", "Driving", "Sitting_Idle", "Pistol_Idle", "Pistol_Aim_Neutral", "Pistol_Aim_Down", "Pistol_Aim_Up", "Dance", "Swim_Fwd", "Swim_Idle", "Pistol_Walk", "Pistol_Run"] else Animation.LOOP_NONE
		var rot_tracks := {}  # dst bone idx -> track idx
		for di in range(dst_sk.get_bone_count()):
			var t := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(t, NodePath("%s:%s" % [dst_path, dst_sk.get_bone_name(di)]))
			rot_tracks[di] = t
		var hip_track := -1
		if hip_dst >= 0:
			hip_track = out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(hip_track, NodePath("%s:%s" % [dst_path, dst_sk.get_bone_name(hip_dst)]))
		var n := int(ceil(sa.length * fps)) + 1
		var prev: Dictionary = {}
		for f in range(n):
			var t := minf(float(f) / fps, sa.length)
			# source local rotations
			var sl: Array = []
			sl.resize(src_sk.get_bone_count())
			var sg: Array = []
			sg.resize(src_sk.get_bone_count())
			for i in range(src_sk.get_bone_count()):
				var bn := src_sk.get_bone_name(i)
				var q: Quaternion = src_sk.get_bone_rest(i).basis.get_rotation_quaternion()
				if tb.rot.has(bn): q = sa.rotation_track_interpolate(tb.rot[bn], t)
				sl[i] = q
				var p := src_sk.get_bone_parent(i)
				sg[i] = q if p < 0 else (sg[p] as Quaternion) * q
			# world delta per mapped source bone
			var delta := {}
			for si in s2d:
				var wa: Quaternion = Rs * (sg[si] as Quaternion)
				var wr: Quaternion = Rs * (gs_rest[si] as Quaternion)
				delta[si] = wa * wr.inverse()
			# build destination world rotations top-down (bone order is parent-first)
			var wd: Array = []
			wd.resize(dst_sk.get_bone_count())
			for di in range(dst_sk.get_bone_count()):
				var p := dst_sk.get_bone_parent(di)
				var parent_w: Quaternion = Rd if p < 0 else (wd[p] as Quaternion)
				var wrest_d: Quaternion = Rd * (gd_rest[di] as Quaternion)
				var wanim: Quaternion
				if d2s.has(di):
					wanim = (delta[d2s[di]] as Quaternion) * (qfix[d2s[di]] as Quaternion) * wrest_d
				else:
					wanim = parent_w * dst_sk.get_bone_rest(di).basis.get_rotation_quaternion()
				wd[di] = wanim
				var local := (parent_w.inverse() * wanim).normalized()
				if prev.has(di) and (prev[di] as Quaternion).dot(local) < 0.0: local = -local
				prev[di] = local
				out.rotation_track_insert_key(rot_tracks[di], t, local)
			if hip_track >= 0 and tb.pos.has("pelvis"):
				var pa: Vector3 = sa.position_track_interpolate(tb.pos["pelvis"], t)
				var pr := src_sk.get_bone_rest(hip_src).origin
				var world_delta: Vector3 = Rs * (pa - pr) * height_ratio
				var hp := dst_sk.get_bone_rest(hip_dst).origin + Rd.inverse() * world_delta
				out.position_track_insert_key(hip_track, t, hp)
		lib.add_animation(aname, out)
	return lib

static func _rel_path(root: Node, target: Node) -> String:
	var parts: Array = []
	var cur := target
	while cur != null and cur != root:
		parts.push_front(String(cur.name))
		cur = cur.get_parent()
	return "/".join(parts)
