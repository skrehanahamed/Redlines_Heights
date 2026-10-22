class_name HandGun
extends RefCounted

## The supplied hand gun (centimetre model, barrel along X): wrapped so the barrel points +Z like the old pistol,
## with its slide / magazine animations renamed to "fire" and "reload".
static func make() -> Node3D:
	var holder := Node3D.new()
	var gun := (load("res://assets/weapons/hand_gun.glb") as PackedScene).instantiate() as Node3D
	gun.scale = Vector3.ONE * GUN_SCALE
	gun.rotation_degrees = Vector3(0, GUN_YAW, 0)
	gun.position = GUN_OFFSET
	holder.add_child(gun)
	for ap in gun.find_children("*", "AnimationPlayer", true, false):
		var a := ap as AnimationPlayer
		var lib := a.get_animation_library(&"")
		var fire_name := ""
		var reload_name := ""
		for n in a.get_animation_list():
			var ns := String(n)
			if fire_name == "" and ns.begins_with("Gun|Gun|") and ns.ends_with("pistol slide|Gun|pistol slide"): fire_name = ns
			if reload_name == "" and ns.begins_with("muni_rot|muni_rot|muni_rot|muni_rot"): reload_name = ns
		if fire_name != "": lib.add_animation("fire", a.get_animation(fire_name))
		if reload_name != "": lib.add_animation("reload", a.get_animation(reload_name))
	return holder

const GUN_SCALE := 0.0015
const GUN_YAW := -90.0
const GUN_OFFSET := Vector3(0, 0.0375, 0.075)
## How the gun sits in the right-hand bone (the pistol clips hold it in this pose).
const GUN_HAND_ROT := Vector3(270, 0, 270)
const GUN_HAND_POS := Vector3(0.0, 0, -0.05)

static func hold(g: Node3D) -> void:
	var base := Transform3D(Basis.from_euler(GUN_HAND_ROT * (PI / 180.0)), GUN_HAND_POS)
	g.transform = base
	# two-handed grip: slide the gun sideways so it sits between both hands instead of out at the right hand
	var ba := g.get_parent() as Node3D
	var sk := ba.get_parent() as Skeleton3D if ba != null else null
	if sk == null: return
	var lh := sk.find_bone("mixamorig_LeftHand")
	if lh < 0: return
	var left_world := sk.global_transform * sk.get_bone_global_pose(lh).origin
	var v := ba.global_transform.affine_inverse() * left_world - base.origin
	if v.length() > GRIP_MAX_DIST: return            # the other hand is not on the gun (walking, idle)
	var barrel := base.basis * Vector3(0, 0, 1)
	v -= barrel * v.dot(barrel)
	g.position = base.origin + v * GRIP_CENTER

## Left hand further than this from the gun hand means a one-handed pose: leave the gun where it is.
const GRIP_MAX_DIST := 0.28
## Fraction of the way from the gun hand towards the support hand the gun is moved (0.5 = exactly between).
const GRIP_CENTER := 0.85
