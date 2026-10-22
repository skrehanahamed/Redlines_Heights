extends Node
## Global game state (autoload "Game").

signal money_changed(value: int)
signal health_changed(value: float)
signal wanted_changed(stars: int)
signal message(text: String)
signal hurt(amount: float)          # health just dropped, drives the blood splatter on screen

var money := 500: set = _set_money
var guns_owned := {}                 # gun id -> rounds, bought at Redline Ammo (the player can carry them once their animations are added)
var ammo_reserve := 0
var health := 100.0: set = _set_health
var armor := 0.0
var wanted := 0: set = _set_wanted
var wanted_timer := 0.0           # seconds until one star is lost while unseen
var player: Node = null           # Player
var world: Node = null            # World
var in_car: Node = null
var in_heli: Node = null          # Chopper the player is flying           # Car the player drives, if any
var camera: Camera3D = null
var dead := false
var aiming := false
var scoped := false              # looking through a sniper scope
var weapon_text := "FISTS"
var anim_library: AnimationLibrary = null   # retargeted animations shared by all characters
const ANIM_NAMES := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Jump", "Jump_Start", "Jump_Land", "Punch_Jab", "Punch_Cross",
	"Pistol_Aim_Neutral", "Pistol_Aim_Down", "Pistol_Aim_Up", "Pistol_Idle", "Pistol_Shoot", "Pistol_Reload", "Hit_Chest", "Hit_Head", "Death01", "Roll",
	"Driving", "Sitting_Idle", "Sitting_Enter", "Sitting_Exit", "Crouch_Idle", "Crouch_Fwd", "Idle_Talking", "Dance", "Push", "Interact", "PickUp_Table", "Swim_Fwd", "Swim_Idle"]
## Extra clips from the second Universal Animation Library (same rig).
const ANIM_NAMES2 := ["Hit_Knockback", "LayToIdle", "Walk_Carry", "Melee_Hook"]
const CHAR_DIR := "res://assets/characters/psx/"

func _set_money(v: int) -> void:
	money = maxi(v, 0)
	money_changed.emit(money)

func _set_health(v: float) -> void:
	var nv := clampf(v, 0.0, 100.0)
	if nv < health: hurt.emit(health - nv)
	health = nv
	health_changed.emit(health)

func _set_wanted(v: int) -> void:
	wanted = clampi(v, 0, 6)
	if wanted > 0:
		wanted_timer = 25.0
	wanted_changed.emit(wanted)

func add_wanted(n: int) -> void:
	wanted += n

func reset_state() -> void:
	money = 500
	health = 100.0
	armor = 0.0
	wanted = 0
	dead = false
	in_car = null
	in_heli = null

var anim_libraries: Dictionary = {}
var is_night := false
var raining := false
var underground := false            # the camera is in the metro (stations, tunnel, stairwells): no weather, no street or sea sounds
var weather: Node = null
var cop_pool: Array[String] = []
const COP_MODEL := "npc_police"
## Station staff models: a Mixamo-style rig under numbered bone names (stripped on load) so the shared clips fit, scaled to a height.
const NPC_MODELS := {
	"npc_police": {"path": "res://assets/npc/police_man_from_the_u.s.a._t-pose_rig_mixamo.glb", "height": 1.82},
	"npc_doctor": {"path": "res://assets/npc/doctor_administering_cpr.glb", "height": 1.78},
	"npc_nurse": {"path": "res://assets/npc/nurse_surgical_rigged.glb", "height": 1.68},
	"npc_shopkeeper": {"path": "res://assets/npc/swat.fbx", "height": 1.84},
	"npc_guard": {"path": "res://assets/npc/golf/golf_guard.glb", "height": 1.82},
	"npc_luiz": {"path": "res://assets/npc/golf/golf_luiz.glb", "height": 1.80},
	"npc_ch21": {"path": "res://assets/npc/golf/golf_ch21.fbx", "height": 1.75},
}
var nurse_pool: Array[String] = []
var doctor_pool: Array[String] = []
var fire_pool: Array[String] = []
var beach_pool: Array[String] = []
var civ_pool: Array[String] = []   # civilian character ids, filled by PedManager (used for carjacked drivers)
const MAIN_HERO := "hero"          # the player model
const HERO := MAIN_HERO
## Clips where the feet stay on the floor; their hips are lowered so the lowest foot touches the ground.
const GROUNDED := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Pistol_Idle", "Pistol_Aim_Neutral", "Pistol_Aim_Down", "Pistol_Aim_Up",
	"Pistol_Shoot", "Pistol_Reload", "Punch_Jab", "Punch_Cross", "Rifle_Shot", "Shotgun_Shot", "Melee_Attack1", "Melee_Attack2", "Melee_Attack3", "Melee_Combo", "Rifle_Idle", "Rifle_Ready", "Rifle_Walk", "Rifle_Run", "Melee_Idle", "Melee_Walk", "Melee_Run", "Idle_Talking", "UAL_Idle_Talking", "UAL_Walk_Formal", "Interact", "Hit_Chest", "Hit_Head", "Push", "Dance"]

## Retargeted animation library, built once and shared: every PSX character uses the same Mixamo rig.
func get_anim_library(char_id: String = MAIN_HERO) -> AnimationLibrary:
	var key := char_id if NPC_MODELS.has(char_id) else MAIN_HERO
	if not anim_libraries.has(key):
		anim_libraries[key] = _build_lib(load_character(key))
	return anim_libraries[key]

## Clips whose root motion is removed (some Mixamo downloads travel across the floor).
const IN_PLACE_CLIPS := ["Swim_Fwd", "Swim_Idle", "Swim_Edge", "Rifle_Idle", "Rifle_Ready", "Rifle_Walk", "Rifle_Run", "Melee_Idle", "Melee_Walk", "Melee_Run", "Walk", "Pistol_Walk", "Pistol_Run", "Jog_Fwd", "Sprint", "Idle", "Pistol_Idle", "Roll", "Driving", "Sitting_Enter", "Sitting_Exit", "Falling Idle", "Floating", "Falling To Landing", "Hard Landing"]
const MIXAMO_DIR := "res://assets/animations/mixamo/"

static func _strip_root_motion(anim: Animation) -> void:
	for t in range(anim.get_track_count()):
		var tp := String(anim.track_get_path(t))
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and (tp.ends_with(":mixamorig_Hips") or tp.ends_with(":pelvis") or tp.ends_with("Pelvis") or tp.ends_with("Hips")):
			var keys := anim.track_get_key_count(t)
			if keys < 2: continue
			var start_pos := anim.track_get_key_value(t, 0) as Vector3
			var end_pos := anim.track_get_key_value(t, keys - 1) as Vector3
			var total_delta := end_pos - start_pos
			if Vector2(total_delta.x, total_delta.z).length() > 0.03:
				for k in range(keys):
					var time := anim.track_get_key_time(t, k)
					var factor := time / maxf(anim.length, 0.001)
					var pos := anim.track_get_key_value(t, k) as Vector3
					pos.x -= total_delta.x * factor
					pos.z -= total_delta.z * factor
					anim.track_set_key_value(t, k, pos)

func _build_lib(tmpl: Node3D) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	
	# Load Mixamo animations dropped in res://assets/animations/mixamo/
	var dir := DirAccess.open(MIXAMO_DIR)
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and (fname.ends_with(".fbx") or fname.ends_with(".glb")):
				var clip_name := fname.get_basename()
				var target_anim := clip_name
				var low := clip_name.to_lower()
				# Keep the names used by Player and Ped exactly, rather than letting a
				# broad match (for example "Rifle_Shot" -> "Pistol_Shoot") overwrite
				# a more specific downloaded clip.
				if low == "swim_fwd" or low == "swim forward" or low == "swimming":
					target_anim = "Swim_Fwd"
				elif low == "swim_idle" or low == "treading water":
					target_anim = "Swim_Idle"
				elif low == "swim_edge" or low == "swim to edge":
					target_anim = "Swim_Edge"
				elif low == "rifle idle":
					target_anim = "Rifle_Idle"
				elif low == "rifle walk":
					target_anim = "Rifle_Walk"
				elif low == "rifle run":
					target_anim = "Rifle_Run"
				elif low == "rifle shot":
					target_anim = "Rifle_Shot"
				elif low == "shotgun shot":
					target_anim = "Shotgun_Shot"
				elif low == "melee idle":
					target_anim = "Melee_Idle"
				elif low == "melee walk":
					target_anim = "Melee_Walk"
				elif low == "melee run":
					target_anim = "Melee_Run"
				elif low.begins_with("melee attack"):
					target_anim = "Melee_Attack" + low.trim_prefix("melee attack")
				elif low == "melee combo":
					target_anim = "Melee_Combo"
				elif low == "walking" or low == "walk":
					target_anim = "Walk"
				elif low == "pistol idle":
					target_anim = "Pistol_Idle"
				elif low == "idle" or low == "breathing idle" or low == "rifle idle":
					target_anim = "Idle"
				elif low == "pistol run" or low == "pistol running":
					target_anim = "Pistol_Run"
				elif low == "pistol walk" or low == "pistol walking":
					target_anim = "Pistol_Walk"
				elif low == "running" or low == "run" or low == "jogging" or low == "jog":
					target_anim = "Jog_Fwd"
				elif low == "sprint" or low == "fast run":
					target_anim = "Sprint"
				elif low == "jump" or low == "jumping":
					target_anim = "Jump"
				elif low == "jump start" or low == "jump_start":
					target_anim = "Jump_Start"
				elif low == "jump land" or low == "jump_land":
					target_anim = "Jump_Land"
				elif "punch" in low or "cross" in low:
					target_anim = "Punch_Jab"
				elif "aim" in low:
					target_anim = "Pistol_Aim_Neutral"
				elif "shoot" in low or "fire" in low or "firing" in low:
					target_anim = "Pistol_Shoot"
				elif "reload" in low:
					target_anim = "Pistol_Reload"
				elif "driving" in low or low == "drive":
					target_anim = "Driving"
				elif "entering car" in low or "enter car" in low:
					target_anim = "Sitting_Enter"
				elif "exiting car" in low or "exit car" in low or "getting out" in low:
					target_anim = "Sitting_Exit"
				elif "roll" in low or "dive roll" in low:
					target_anim = "Roll"
				elif "hit by car" in low:
					target_anim = "Hit_Knockback"
				elif "hit reaction" in low or "hit" in low or "damage" in low:
					target_anim = "Hit_Chest"
				elif "death" in low or "dying" in low:
					target_anim = "Death01"
				elif "crouch idle" in low or low == "crouch" or "kneeling idle" in low:
					target_anim = "Crouch_Idle"
				elif "crouch walk" in low:
					target_anim = "Crouch_Fwd"
				
				var fpath := MIXAMO_DIR + fname
				var msrc := _mixamo_as_ual(fpath, target_anim)
				if msrc:
					var mlib := Retarget.build_library(msrc, tmpl, PackedStringArray([target_anim]), 60.0)
					msrc.free()
					if mlib.has_animation(target_anim):
						var anim := mlib.get_animation(target_anim)
						if target_anim in IN_PLACE_CLIPS:
							_strip_root_motion(anim)          # the character is moved by the game, not by the clip
						lib.add_animation(target_anim, anim)
						
						# Add aliases for player.gd and ped scripts
						if target_anim == "Jog_Fwd":
							lib.add_animation("Run", anim)
						elif target_anim == "Jump":
							if not lib.has_animation("Jump_Start"): lib.add_animation("Jump_Start", anim)
							if not lib.has_animation("Jump_Land"): lib.add_animation("Jump_Land", anim)
						elif target_anim == "Idle":
							if not lib.has_animation("Pistol_Idle"): lib.add_animation("Pistol_Idle", anim)
							if not lib.has_animation("Pistol_Aim_Neutral"): lib.add_animation("Pistol_Aim_Neutral", anim)
						elif target_anim == "Pistol_Idle":
							lib.add_animation("Pistol_Aim_Neutral", anim)
			fname = dir.get_next()

	_add_ual_swim(lib, tmpl)
	_ground_feet(lib, tmpl)
	tmpl.free()
	return lib

## Rigify bone names of the Quaternius Universal Animation Library (Standard, CC0) -> the library names our retargeter knows.
const RIGIFY_TO_UAL := {"DEF-hips": "pelvis", "DEF-spine.001": "spine_01", "DEF-spine.002": "spine_02", "DEF-spine.003": "spine_03", "DEF-neck": "neck_01", "DEF-head": "Head",
	"DEF-shoulder.L": "clavicle_l", "DEF-upper_arm.L": "upperarm_l", "DEF-forearm.L": "lowerarm_l", "DEF-hand.L": "hand_l",
	"DEF-shoulder.R": "clavicle_r", "DEF-upper_arm.R": "upperarm_r", "DEF-forearm.R": "lowerarm_r", "DEF-hand.R": "hand_r",
	"DEF-thigh.L": "thigh_l", "DEF-shin.L": "calf_l", "DEF-foot.L": "foot_l", "DEF-toe.L": "ball_l",
	"DEF-thigh.R": "thigh_r", "DEF-shin.R": "calf_r", "DEF-foot.R": "foot_r", "DEF-toe.R": "ball_r"}
const UAL_PATH := "res://assets/animations/ual/AnimationLibrary_Godot_Standard.glb"

## The Universal Animation Library's own crawl-stroke swim and treading-water clips, retargeted onto the character; they replace the Mixamo swims.
func _add_ual_swim(lib: AnimationLibrary, tmpl: Node3D) -> void:
	var ps := load(UAL_PATH) as PackedScene
	if ps == null: return
	var inst := ps.instantiate()
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		inst.free()
		return
	var sk := sks[0] as Skeleton3D
	var ap := aps[0] as AnimationPlayer
	var src := AnimationLibrary.new()
	var names := PackedStringArray()
	for nm in ["Swim_Fwd", "Swim_Idle", "Idle", "Walk", "Idle_Talking", "Sitting_Idle", "Sitting_Talking", "Walk_Formal"]:
		if not ap.has_animation(nm): continue
		var an := ap.get_animation(nm).duplicate() as Animation
		for t in range(an.get_track_count()):
			var tp := String(an.track_get_path(t))
			var c := tp.rfind(":")
			if c < 0: continue
			var bone := tp.substr(c + 1)
			if RIGIFY_TO_UAL.has(bone): an.track_set_path(t, NodePath(tp.substr(0, c + 1) + String(RIGIFY_TO_UAL[bone])))
		src.add_animation(nm, an)
		names.append(nm)
	for i in range(sk.get_bone_count()):
		var b := sk.get_bone_name(i)
		if RIGIFY_TO_UAL.has(b): sk.set_bone_name(i, RIGIFY_TO_UAL[b])
	for n in ap.get_animation_library_list(): ap.remove_animation_library(n)
	ap.add_animation_library("", src)
	var out := Retarget.build_library(inst, tmpl, names, 60.0)
	inst.free()
	for nm in names:
		if not out.has_animation(nm): continue
		var an2 := out.get_animation(nm)
		_strip_root_motion(an2)
		var key := nm if nm.begins_with("Swim") else "UAL_" + nm
		if lib.has_animation(key): lib.remove_animation(key)
		lib.add_animation(key, an2)

const MIXAMO_WALK := "res://assets/animations/mixamo/Walking.fbx"
const UAL_FROM_MIXAMO := {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r"}

## A Mixamo download (character + clip) re-labelled with the Universal Animation Library bone names, so the
## existing retargeter can take its clip onto any of our characters in world space at 60 FPS without distortion.
func _mixamo_as_ual(path: String, clip_name: String) -> Node:
	var fbx_scene := load(path) as PackedScene
	if fbx_scene == null: return null
	var inst := fbx_scene.instantiate()
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		inst.free()
		return null
	var sk := sks[0] as Skeleton3D
	var ap := aps[0] as AnimationPlayer
	var anim_list := ap.get_animation_list()
	if anim_list.is_empty():
		inst.free()
		return null
	var src: Animation = ap.get_animation("mixamo_com") if ap.has_animation("mixamo_com") else ap.get_animation(anim_list[0])
	var anim := src.duplicate() as Animation
	
	# Strip forward root motion so locomotion is cleanly in-place
	if clip_name in ["Walk", "Jog_Fwd", "Sprint", "Run", "Crouch_Fwd"]:
		_strip_root_motion(anim)
		
	for t in range(anim.get_track_count()):
		var tp := String(anim.track_get_path(t))
		var c := tp.rfind(":")
		if c < 0: continue
		var bone := tp.substr(c + 1).trim_prefix("mixamorig_").trim_prefix("mixamorig:")
		if UAL_FROM_MIXAMO.has(bone):
			anim.track_set_path(t, NodePath(tp.substr(0, c + 1) + String(UAL_FROM_MIXAMO[bone])))
	for i in range(sk.get_bone_count()):
		var b := sk.get_bone_name(i).trim_prefix("mixamorig_").trim_prefix("mixamorig:")
		if UAL_FROM_MIXAMO.has(b): sk.set_bone_name(i, UAL_FROM_MIXAMO[b])
	var lib := AnimationLibrary.new()
	lib.add_animation(clip_name, anim)
	for n in ap.get_animation_library_list():
		ap.remove_animation_library(n)
	ap.add_animation_library("", lib)
	return inst


## Source-engine bone names of the player model -> the Mixamo names the shared clips are retargeted to.
const PLAYER_BONES := {"root hips": "Hips", "spine lower": "Spine", "spine middle": "Spine1", "spine upper": "Spine2",
	"head neck lower": "Neck", "head neck upper": "Head",
	"arm right shoulder 1": "RightShoulder", "arm right shoulder 2": "RightArm", "arm right elbow": "RightForeArm", "arm right wrist": "RightHand",
	"arm left shoulder 1": "LeftShoulder", "arm left shoulder 2": "LeftArm", "arm left elbow": "LeftForeArm", "arm left wrist": "LeftHand",
	"leg right thigh": "RightUpLeg", "leg right knee": "RightLeg", "leg right foot": "RightFoot", "leg right toe": "RightToeBase",
	"leg left thigh": "LeftUpLeg", "leg left knee": "LeftLeg", "leg left foot": "LeftFoot", "leg left toe": "LeftToeBase"}

const HERO_MODEL := "res://assets/hero/ace_robobeat_3d_model_rigged.glb"

## Robot-style names of the player model's body bones -> the Mixamo names the shared clips are retargeted to.
const ACE_BONES := {"Pelvis": "Hips", "Spine": "Spine", "Spine1": "Spine1", "Neck": "Neck", "Head": "Head",
	"L Clavicle": "LeftShoulder", "L UpperArm": "LeftArm", "L Forearm": "LeftForeArm", "L Hand": "LeftHand",
	"R Clavicle": "RightShoulder", "R UpperArm": "RightArm", "R Forearm": "RightForeArm", "R Hand": "RightHand",
	"L Thigh": "LeftUpLeg", "L Calf": "LeftLeg", "L Foot": "LeftFoot", "L Toe0": "LeftToeBase",
	"R Thigh": "RightUpLeg", "R Calf": "RightLeg", "R Foot": "RightFoot", "R Toe0": "RightToeBase"}
## Coat flaps: [first bone, last bone] of each hanging chain, moved by spring physics.
const COAT_CHAINS := [["Bone010", "Bone015"], ["Bone010(mirrored)", "Bone015(mirrored)"], ["Bone001", "Bone002"],
	["Bone001(mirrored)", "Bone002(mirrored)"], ["Bone004", "Bone005"], ["Bone004(mirrored)", "Bone005(mirrored)"],
	["Bone007", "Bone008"], ["Bone007(mirrored)", "Bone008(mirrored)"]]
const PLAYER_SCALE := 0.52

func _load_player_model() -> Node3D:
	# a Mixamo character: its skeleton already carries the names every clip is retargeted to
	if ResourceLoader.exists("res://assets/hero/exo_gray.fbx"):
		return (load("res://assets/hero/exo_gray.fbx") as PackedScene).instantiate() as Node3D
	var inst := (load("res://assets/hero/ace.glb") as PackedScene).instantiate() as Node3D
	var rx := RegEx.create_from_string("^(.*?)_\\d+$")
	var tx := {}
	for sk in inst.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for i in range(skel.get_bone_count()):
			var old := skel.get_bone_name(i)
			var m := rx.search(old)
			var clean := m.get_string(1) if m else old
			if clean.begins_with("Robot "): clean = clean.substr(6)
			var nn := ("mixamorig_" + String(ACE_BONES[clean])) if ACE_BONES.has(clean) else clean
			tx[old] = nn
			skel.set_bone_name(i, nn)
		for mi in skel.find_children("*", "MeshInstance3D", true, false):
			var skin := (mi as MeshInstance3D).skin
			if skin == null: continue
			for b in range(skin.get_bind_count()):
				if tx.has(skin.get_bind_name(b)): skin.set_bind_name(b, tx[skin.get_bind_name(b)])
		# the coat: spring chains so the flaps swing with the movement
		var sp := SpringBoneSimulator3D.new()
		sp.name = "CoatSprings"
		skel.add_child(sp)
		sp.setting_count = COAT_CHAINS.size()
		for i in range(COAT_CHAINS.size()):
			sp.set_root_bone_name(i, COAT_CHAINS[i][0])
			sp.set_end_bone_name(i, COAT_CHAINS[i][1])
			sp.set_extend_end_bone(i, true)
			sp.set_end_bone_length(i, 0.12)
			sp.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
			sp.set_stiffness(i, 0.6)
			sp.set_drag(i, 0.35)
			sp.set_gravity(i, 4.0)
	inst.scale = Vector3.ONE * PLAYER_SCALE
	return inst

## Instantiate a PSX character by id like "Male/Character_04".
func load_character(id: String) -> Node3D:
	if NPC_MODELS.has(id):
		return _load_npc_model(id)
	if id == MAIN_HERO:
		return _load_player_model()
	if id == COP_MODEL:
		var cop := (load("res://assets/hero/police_officer.glb") as PackedScene).instantiate() as Node3D
		# Sketchfab suffixes every bone with an index ("mixamorig_Hips_01"); strip it so the shared clips fit
		var rx := RegEx.create_from_string("^(mixamorig_.*?)_0?\\d+$")
		for sk in cop.find_children("*", "Skeleton3D", true, false):
			for i in range((sk as Skeleton3D).get_bone_count()):
				var m := rx.search((sk as Skeleton3D).get_bone_name(i))
				if m: (sk as Skeleton3D).set_bone_name(i, m.get_string(1))
			for mi in (sk as Skeleton3D).find_children("*", "MeshInstance3D", true, false):
				var skin := (mi as MeshInstance3D).skin
				if skin == null: continue
				for b in range(skin.get_bind_count()):
					var mb := rx.search(skin.get_bind_name(b))
					if mb: skin.set_bind_name(b, mb.get_string(1))
		cop.scale = Vector3.ONE * 100.0      # the export nests the rig under a 0.01 scale node
		# the rig's origin is at the pelvis: lift it so the soles (ankle joints sit 0.91 m below it) stand on the floor
		for c in cop.get_children():
			if c is Node3D: (c as Node3D).position.y += 0.98 / 100.0
		return cop
	return _load_player_model()

static func _npc_bone_name(old: String) -> String:
	var rx_m := RegEx.create_from_string("^(mixamorig_.*?)_0?\\d+$")
	var m := rx_m.search(old)
	if m: return m.get_string(1)
	var rx_p := RegEx.create_from_string("^([A-Za-z0-9]+)_0?\\d+$")
	var m2 := rx_p.search(old)
	if m2:
		var c := m2.get_string(1)
		if c == "Biped": return "mixamorig_Hips"
		if c in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"] or c.begins_with("Left") or c.begins_with("Right"):
			return "mixamorig_" + c
	return old

func _load_npc_model(id: String) -> Node3D:
	var cfg: Dictionary = NPC_MODELS[id]
	var inst := (load(String(cfg.path)) as PackedScene).instantiate() as Node3D
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	for sk in inst.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		var tx := {}
		for i in range(skel.get_bone_count()):
			var old := skel.get_bone_name(i)
			var nn := _npc_bone_name(old)
			if nn != old and skel.find_bone(nn) < 0:
				tx[old] = nn
				skel.set_bone_name(i, nn)
		for mi in skel.find_children("*", "MeshInstance3D", true, false):
			var skin := (mi as MeshInstance3D).skin
			if skin != null:
				for b in range(skin.get_bind_count()):
					if tx.has(skin.get_bind_name(b)): skin.set_bind_name(b, tx[skin.get_bind_name(b)])
			var m := mi as MeshInstance3D
			if m.mesh:
				for s in range(m.mesh.get_surface_count()):
					var mat = m.get_surface_override_material(s)
					if mat == null: mat = m.mesh.surface_get_material(s)
					if mat is BaseMaterial3D:
						var dup := mat.duplicate() as BaseMaterial3D
						dup.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
						dup.albedo_color.a = 1.0
						m.set_surface_override_material(s, dup)
	return _fit_model(inst, float(cfg.height))

## Wraps a model in a holder, scaled to the given height with its soles on the floor. The size comes from the skeleton's bones
## (a skinned mesh's own bounds can be in other units than what is drawn); unrigged models use their mesh bounds.
func _fit_model(inst: Node3D, height: float) -> Node3D:
	var holder := Node3D.new()
	holder.add_child(inst)
	var lo := 1e9
	var hi := -1e9
	for sk in inst.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		var xf: Transform3D = Car._xf_rel(skel, holder)
		for i in range(skel.get_bone_count()):
			var y: float = (xf * skel.get_bone_global_rest(i).origin).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
	if hi > lo:
		var span := hi - lo
		lo -= span * 0.025                 # soles sit just below the toe bones
		hi += span * 0.06                  # the head top sits above the head bone
	else:
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = Car._xf_rel(mi, holder) * (mi as MeshInstance3D).get_aabb()
			lo = minf(lo, b.position.y)
			hi = maxf(hi, b.end.y)
	if hi - lo > 0.01:
		var sc := height / (hi - lo)
		inst.transform = Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3(0, -lo * sc, 0)) * inst.transform
	return holder

## An unrigged standing figure (the firefighter): scaled to a height, soles on the floor.
func load_static_figure(path: String, height: float) -> Node3D:
	return _fit_model((load(path) as PackedScene).instantiate() as Node3D, height)

## The retargeted clips keep the hips at standing height, so run cycles hover a hand's width above the floor.
## Measure the lowest foot over each grounded clip and shift the hip track down by that much.
func _ground_feet(lib: AnimationLibrary, tmpl: Node3D) -> void:
	if is_inside_tree() and tmpl.get_parent() == null:
		add_child(tmpl)
	var sks := tmpl.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		if tmpl.get_parent() == self: remove_child(tmpl)
		return
	var sk := sks[0] as Skeleton3D
	var bones: Array[int] = []
	for n in ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]:
		var i := sk.find_bone(n)
		if i >= 0: bones.append(i)
	if bones.is_empty():
		for key in ["foot_l", "foot_r", "ball_l", "ball_r"]:
			var i := Retarget._find_matching_bone(sk, key)
			if i >= 0 and not bones.has(i): bones.append(i)
	var hips := sk.find_bone("mixamorig_Hips")
	if hips < 0:
		hips = Retarget._find_matching_bone(sk, "pelvis")
	if bones.is_empty() or hips < 0:
		if tmpl.get_parent() == self: remove_child(tmpl)
		return
	var hip_name := sk.get_bone_name(hips)
	sk.reset_bone_poses()
	var sk_tf := sk.global_transform if sk.is_inside_tree() else sk.transform
	var rest_low := 99.0
	for i in bones:
		rest_low = minf(rest_low, (sk_tf * sk.get_bone_global_pose(i)).origin.y)
	var ap := AnimationPlayer.new()
	tmpl.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", lib)
	for a in GROUNDED:
		if not lib.has_animation(a): continue
		var anim := lib.get_animation(a)
		ap.play(a)
		ap.pause()
		var low := 99.0
		for k in range(24):
			ap.seek(anim.length * k / 24.0, true)
			for i in bones:
				low = minf(low, (sk_tf * sk.get_bone_global_pose(i)).origin.y)
		var drop := low - rest_low
		if drop <= 0.005: continue
		var local_drop := sk_tf.basis.inverse() * Vector3(0, -drop, 0)
		for t in range(anim.get_track_count()):
			if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var tp := String(anim.track_get_path(t))
				if tp.ends_with(":" + hip_name) or tp.ends_with(":mixamorig_Hips") or tp.ends_with("Pelvis"):
					for k in range(anim.track_get_key_count(t)):
						anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) + local_drop)
	# a body lying on the floor: keep the lowest joint on the ground at every keyframe, never raise it
	for lying in ["Death01", "Hit_Knockback", "LayToIdle"]:
		if not lib.has_animation(lying): continue
		var la := lib.get_animation(lying)
		ap.play(lying)
		ap.pause()
		for t in range(la.get_track_count()):
			if la.track_get_type(t) != Animation.TYPE_POSITION_3D or (not String(la.track_get_path(t)).ends_with(":" + hip_name) and not String(la.track_get_path(t)).ends_with(":mixamorig_Hips")):
				continue
			for k in range(la.track_get_key_count(t)):
				ap.seek(la.track_get_key_time(t, k), true)
				var lowest := 99.0
				for bi in range(sk.get_bone_count()):
					lowest = minf(lowest, (sk_tf * sk.get_bone_global_pose(bi)).origin.y)
				var drop := lowest - 0.1
				if drop > 0.0:
					la.track_set_key_value(t, k, (la.track_get_key_value(t, k) as Vector3) + sk_tf.basis.inverse() * Vector3(0, -drop, 0))
	ap.stop()
	ap.remove_animation_library("")
	if tmpl.get_parent() == self:
		remove_child(tmpl)

func get_focus_pos() -> Vector3:
	if in_heli != null and is_instance_valid(in_heli):
		return (in_heli as Node3D).global_position
	if in_car != null and is_instance_valid(in_car):
		return (in_car as Node3D).global_position
	if player != null and is_instance_valid(player):
		return (player as Node3D).global_position
	return Vector3.ZERO


func _input(event: InputEvent) -> void:
	# F11 toggles fullscreen / 1920x1080 window
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var w := get_window()
		if w.mode == Window.MODE_FULLSCREEN:
			w.mode = Window.MODE_WINDOWED
			w.size = Vector2i(1920, 1080)
			w.move_to_center()
		else:
			w.mode = Window.MODE_FULLSCREEN
