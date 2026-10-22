class_name Weapons
extends RefCounted
## Stats and hand models of every weapon bought at Redline Ammo. A gun's class decides which Mixamo clips the player uses
## (pistol / rifle / shotgun), melee weapons use the melee clips.

const PISTOL_SFX := ["res://assets/audio/guns/pistol_1911_01.mp3", "res://assets/audio/guns/pistol_1911_02.mp3"]
const WALTHER_SFX := ["res://assets/audio/guns/pistol_walther_ppq_01.mp3", "res://assets/audio/guns/pistol_walther_ppq_02.mp3"]
const REVOLVER_SFX := ["res://assets/audio/guns/revolver_sw642_01.mp3", "res://assets/audio/guns/revolver_sw642_02.mp3"]
const SMG_SFX := ["res://assets/audio/guns/smg_ppsh_01.mp3", "res://assets/audio/guns/smg_ppsh_02.mp3", "res://assets/audio/guns/smg_ppsh_03.mp3", "res://assets/audio/guns/smg_ppsh_04.mp3"]
const GUSTAV_SFX := ["res://assets/audio/guns/smg_carl_gustav_01.mp3", "res://assets/audio/guns/smg_carl_gustav_02.mp3", "res://assets/audio/guns/smg_carl_gustav_03.mp3"]
const AK_SFX := ["res://assets/audio/guns/rifle_ak47_01.mp3", "res://assets/audio/guns/rifle_ak47_02.mp3", "res://assets/audio/guns/rifle_ak47_03.mp3", "res://assets/audio/guns/rifle_ak47_04.mp3"]
const AR_SFX := ["res://assets/audio/guns/rifle_ar15_01.mp3", "res://assets/audio/guns/rifle_ar15_02.mp3"]
const SKS_SFX := ["res://assets/audio/guns/rifle_sks_01.mp3", "res://assets/audio/guns/rifle_sks_02.mp3"]
const SHOTGUN_SFX := ["res://assets/audio/guns/shotgun_mossberg_01.mp3", "res://assets/audio/guns/shotgun_mossberg_02.mp3", "res://assets/audio/guns/shotgun_nova_01.mp3", "res://assets/audio/guns/shotgun_nova_02.mp3"]
const MINIGUN_SFX := ["res://assets/audio/guns_and_gameplay/minigun_shot_01.ogg"]
const SWING_SFX := ["res://assets/audio/guns_and_gameplay/ricochet_01.ogg"]

## Weapons whose handle end the mesh test guessed wrong (the model is turned round).
const FLIP := {"x_knife": true}

const MELEE := {
	"x_bat": {"dmg": 40.0, "len": 0.85, "hit": 0.28},
	"x_axe": {"dmg": 75.0, "len": 0.8, "hit": 0.34},
	"x_machete": {"dmg": 60.0, "len": 0.7, "hit": 0.26},
	"x_hammer": {"dmg": 50.0, "len": 0.4, "hit": 0.26},
	"x_cleaver": {"dmg": 55.0, "len": 0.32, "hit": 0.24},
	"x_knife": {"dmg": 35.0, "len": 0.3, "hit": 0.2}}

## Everything the player needs to use item `id`: kind (pistol / rifle / shotgun / melee / thrown), fire interval, damage,
## pellets, spread, model length in metres and shot sounds. {} when the id is unknown.
static func info(id: String) -> Dictionary:
	if id.begins_with("x_"):
		if MELEE.has(id):
			var m: Dictionary = MELEE[id]
			var d := {"kind": "melee", "id": id, "dmg": m.dmg, "len": m.len, "hit": m.hit, "cd": 0.6, "reach": 1.9, "sfx": SWING_SFX}
			d["name"] = String(GunShop.extra_def(id)[1])
			return d
		var e := GunShop.extra_def(id)
		if e.is_empty(): return {}
		return {"kind": "thrown", "id": id, "name": String(e[1]), "len": float(e[6]) * 0.5, "cd": 0.9}
	for gi in range(GunShop.GUNS.size()):
		var g: Array = GunShop.GUNS[gi]
		if String(g[0]) != id: continue
		var cat := GunShop.category_of(gi)
		var price := float(g[2])
		var d := {"id": id, "name": String(g[1]), "pellets": 1, "spread": 0.0}
		match cat:
			"PISTOLS":
				d.merge({"kind": "pistol", "cd": 0.24, "dmg": 20.0 + price * 0.04, "len": 0.23, "sfx": WALTHER_SFX if id == "Glock17" or id == "LugerP08" else (REVOLVER_SFX if id.begins_with("Revolver") else PISTOL_SFX)})
			"SMGS":
				d.merge({"kind": "rifle", "cd": 0.085, "dmg": 13.0 + price * 0.005, "len": 0.5, "spread": 0.012, "sfx": SMG_SFX if id != "Kriss_Vector" else GUSTAV_SFX})
			"RIFLES":
				d.merge({"kind": "rifle", "cd": 0.11, "dmg": 21.0 + price * 0.006, "len": 0.95, "spread": 0.008, "sfx": AK_SFX if id == "AK47" else AR_SFX})
			"SHOTGUNS":
				d.merge({"kind": "shotgun", "cd": 0.85 if id != "SawedOff" else 0.7, "dmg": 13.0, "len": 1.0, "pellets": 8, "spread": 0.07, "sfx": SHOTGUN_SFX})
			"SNIPERS":
				d.merge({"kind": "rifle", "cd": 1.15, "dmg": 120.0 + price * 0.01, "len": 1.25, "sfx": SKS_SFX, "scope": true})
			_:
				d.merge({"kind": "rifle", "cd": 0.07 if id != "Minigun" else 0.045, "dmg": 22.0, "len": 1.1, "spread": 0.02, "sfx": MINIGUN_SFX if id == "Minigun" else AK_SFX, "heavy": true})
		return d
	return {}

## The weapon model as a Node3D whose origin is the grip, barrel / blade along +Z and up along +Y (the same frame as HandGun), plus
## `muzzle` (a local point at the tip): {node, muzzle}. Melee weapons are tilted up in the fist.
static func make_held(id: String, inf: Dictionary) -> Dictionary:
	var made: Dictionary
	var src: Node3D = null
	if id.begins_with("x_"):
		made = GunShop.make_extra(id)
	else:
		src = (load(GunShop.PACK) as PackedScene).instantiate() as Node3D
		made = GunShop.make_gun(src, id)
	if src != null: src.free()
	if made.is_empty(): return {}
	var node: Node3D = made.node
	var sz: Vector3 = made.bb.size
	var longest := maxf(sz.x, maxf(sz.y, sz.z))
	var s: float = float(inf.len) / maxf(longest, 0.001)
	var inner := Node3D.new()
	inner.add_child(node)
	var kind := String(inf.kind)
	# long axis -> +Z (guns come with the muzzle on +Z when long in z, extras are turned to x by make_extra)
	if id.begins_with("x_"):
		# handle at -Z (in the fist), blade / head towards +Z
		var hx: bool = bool(made.get("handle_x_pos", false)) != bool(FLIP.get(id, false))
		node.rotation.y = PI * 0.5 if hx else -PI * 0.5
	elif sz.x > sz.z:
		node.rotation.y = -PI * 0.5
	inner.scale = Vector3.ONE * s
	var len := float(inf.len)
	var outer := Node3D.new()
	var tilt := Node3D.new()                                         # pivots around the grip
	outer.add_child(tilt)
	tilt.add_child(inner)
	if kind == "melee":
		# the handle (rear 12 %) is at the origin, the weapon extends along +Z; hold_melee puts that point in the palm
		inner.position = Vector3(0, 0, len * 0.38)
		return {"node": outer, "muzzle": Vector3.ZERO, "front": 0.0}
	# rear grip (right hand) and fore grip (left hand) as fractions of the length from the model's middle
	var rear := -0.08
	var fore := 0.0
	var cat := "PISTOLS"
	if kind == "shotgun":
		rear = -0.10
		fore = 0.18
	elif kind == "rifle":
		if bool(inf.get("scope", false)):
			rear = -0.14
			fore = 0.2
		elif bool(inf.get("heavy", false)):
			rear = -0.10
			fore = 0.2
		elif len < 0.6:
			rear = -0.06
			fore = 0.2
		else:
			rear = -0.12
			fore = 0.15
	var below := 0.3 if kind == "pistol" else 0.22
	inner.position = Vector3(0.0, sz.y * s * below, -rear * len)
	return {"node": outer, "muzzle": Vector3(0.0, sz.y * s * below, len * (0.5 - rear)), "front": (fore - rear) * len if kind != "pistol" else 0.0}

## Puts a two-handed weapon (rifle, shotgun, pack pistol) between the hands: the grip sits in the right hand and the barrel points
## from the right hand towards the left hand, so it never floats off the arms. One-handed poses fall back to the fixed hand grip.
static func hold(g: Node3D, sk: Skeleton3D, front_dist := 0.0) -> void:
	if sk == null or not is_instance_valid(sk):
		HandGun.hold(g)
		return
	var rh := sk.find_bone("mixamorig_RightHand")
	var lh := sk.find_bone("mixamorig_LeftHand")
	if rh < 0 or lh < 0:
		HandGun.hold(g)
		return
	var rt: Transform3D = sk.global_transform * sk.get_bone_global_pose(rh)
	var lpos: Vector3 = (sk.global_transform * sk.get_bone_global_pose(lh)).origin
	var grip: Vector3 = rt.origin + rt.basis.y.normalized() * 0.05       # the palm, a little along the fingers
	var d := lpos - grip
	var dist := d.length()
	if dist < 0.14 or dist > 0.85:
		HandGun.hold(g)                       # the other hand is not on the weapon (walking one-handed): fixed grip
		return
	var f := d / dist
	var up := Vector3.UP
	# the barrel keeps the heading of the hands but never points up into the sky: while aiming it follows the crosshair's height,
	# otherwise (low ready) it is held level or lower
	var fh := Vector3(f.x, 0.0, f.z)
	if fh.length() > 0.05:
		fh = fh.normalized()
		var elev := clampf(asin(clampf(f.y, -1.0, 1.0)), -0.9, 0.08)
		var cam := Game.camera as Camera3D
		if Game.aiming and cam != null:
			elev = clampf(asin(clampf(-cam.global_transform.basis.z.y, -1.0, 1.0)), -0.45, 0.45)
		f = fh * cos(elev) + up * sin(elev)
	var x := up.cross(f)
	if x.length() < 0.2:
		HandGun.hold(g)
		return
	x = x.normalized()
	var y := f.cross(x).normalized()
	# slide the gun along the barrel so both hands meet the grips: the rear grip is at the right hand, the fore grip front_dist ahead
	# of it; any difference to the real hand spacing is shared between the two hands. Pistols are pushed out in front of the hands.
	var shift := 0.1
	if front_dist > 0.0:
		shift = clampf((dist - front_dist) * 0.5, -0.1, 0.2) + 0.03
	g.global_transform = Transform3D(Basis(x, y, f), grip + f * shift)


# ---- hand-tuned grips (made with the dev grip editor, F11) ----
const GRIP_FILE := "res://data/weapon_grips.json"
static var _grips: Dictionary = {}
static var _grips_loaded := false

static func grips() -> Dictionary:
	if not _grips_loaded:
		_grips_loaded = true
		if FileAccess.file_exists(GRIP_FILE):
			var j = JSON.parse_string(FileAccess.get_file_as_string(GRIP_FILE))
			if j is Dictionary: _grips = j
	return _grips

## Offset (in the weapon's own frame, on top of the computed hold) for a weapon in a pose: idle / aim / run / swing.
static func grip_offset(id: String, pose: String) -> Transform3D:
	var e = grips().get("%s|%s" % [id, pose])
	if e == null: return Transform3D.IDENTITY
	var p: Array = e.pos
	var r: Array = e.rot
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(float(r[0])), deg_to_rad(float(r[1])), deg_to_rad(float(r[2])))), Vector3(float(p[0]), float(p[1]), float(p[2])))

static func set_grip(id: String, pose: String, off: Transform3D) -> void:
	var e := off.basis.get_euler()
	grips()["%s|%s" % [id, pose]] = {"pos": [snappedf(off.origin.x, 0.0001), snappedf(off.origin.y, 0.0001), snappedf(off.origin.z, 0.0001)],
		"rot": [snappedf(rad_to_deg(e.x), 0.01), snappedf(rad_to_deg(e.y), 0.01), snappedf(rad_to_deg(e.z), 0.01)]}

static func save_grips() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	var f := FileAccess.open(GRIP_FILE, FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(grips(), "\t"))


## Melee weapon in the fist: the handle is in the palm (a little along the fingers from the wrist), the weapon crosses the palm
## and points up out of the thumb side, tilted forward. `variant` picks which hand axis is the weapon axis (for fitting).
static var melee_axis := 2
static var melee_sign := -1.0
static func hold_melee(g: Node3D, sk: Skeleton3D) -> void:
	var rh := sk.find_bone("mixamorig_RightHand")
	if rh < 0:
		HandGun.hold(g)
		return
	var rt: Transform3D = sk.global_transform * sk.get_bone_global_pose(rh)
	var b := rt.basis.orthonormalized()
	var palm: Vector3 = rt.origin + b.y * 0.085
	var ax: Vector3 = [b.x, b.y, b.z][melee_axis] * melee_sign
	# weapon +Z along ax; its up (+Y) towards the player's forward side
	var up_hint := b.y if melee_axis != 1 else b.z
	var x := up_hint.cross(ax)
	if x.length() < 0.1: x = Vector3.RIGHT
	x = x.normalized()
	var y := ax.cross(x).normalized()
	g.global_transform = Transform3D(Basis(x, y, ax.normalized()), palm)
