class_name GunShop
extends RefCounted
## "Redline Ammo": a walk-in gun shop. A brick building with a glass front and an open door, a counter, and every gun of the weapon pack
## on the back wall with a price tag. Standing at a gun and pressing E buys it (the money is taken, the gun goes into Game.guns_owned
## with its ammo). The shop is built from boxes, so it can be swapped for a modelled building later without touching the rest.

const PACK := "res://assets/guns/low-poly_weapon_asset_pack.glb"
const W := 14.0                      # width along x
const D := 11.0                      # depth along z (the front faces +z)
const H := 3.5
const LOT_W := 13.0                  # driveway and side customer parking width along x (east)
const BACK_D := 7.5                  # rear parking lot depth along z (behind the shop)

## name of the node prefix in the pack, shop label, price, ammo bought with it
const GUNS := [
	["M1911", "M1911 pistol", 250, 24], ["LugerP08", "Luger P08", 300, 24], ["Glock17", "Glock 17", 350, 34], ["Deagle", "Desert Eagle", 600, 14],
	["Usp45_Silenced", "USP .45 silenced", 550, 24], ["Revolver_2", "Revolver", 400, 18],
	["Uzi", "Uzi SMG", 800, 64], ["Mp5K", "MP5K SMG", 900, 60], ["P90", "P90 SMG", 1100, 100], ["Kriss_Vector", "Kriss Vector SMG", 1200, 60],
	["Sten", "Sten SMG", 650, 64], ["PPHS", "PPSh SMG", 700, 142],
	["AK47", "AK-47", 1500, 60], ["M16A4", "M16A4", 1600, 60], ["G36", "G36", 1700, 60], ["ScarH", "SCAR-H", 1900, 40], ["XM8", "XM8", 1800, 60],
	["Famas", "FAMAS", 1750, 75], ["FN2000", "FN2000", 1850, 60], ["M1Garand", "M1 Garand", 1300, 40],
	["AA12", "AA-12 shotgun", 2200, 32], ["Spas_12", "SPAS-12 shotgun", 1400, 24], ["SawedOff", "Sawed-off shotgun", 700, 12],
	["VSS_Sniper", "VSS sniper", 2600, 20], ["L115_Awp", "L115 sniper", 3200, 10], ["Barett", "Barrett .50", 4500, 10],
	["M249", "M249 machine gun", 5200, 200], ["M60", "M60 machine gun", 5600, 200], ["Minigun", "Minigun", 9000, 500]]

## The pack's parts are flat grey; each material is given a real gun colour (black / grey steel, wooden or polymer furniture).
const GUN_COLORS := {"material": Color(0.17, 0.17, 0.19), "material_2": Color(0.34, 0.35, 0.38), "material_4": Color(0.22, 0.22, 0.24),
	"material_5": Color(0.3, 0.19, 0.11), "material_7": Color(0.36, 0.22, 0.12), "White": Color(0.62, 0.63, 0.66), "Glass": Color(0.3, 0.5, 0.6)}

static var keeper_pos := Vector3.ZERO
static var keeper_positions: Array[Vector3] = []
static var items: Array = []         # [{pos: Vector3, id, name, price, ammo}] world position of each gun on the wall, for buying
static var ammo_box := {"cat": "AMMO", "id": "ammo", "name": "Ammo box (+60 rounds)", "price": 80, "ammo": 60}

## Builds the shop with its front-left corner at (x0, z1) world: it spans x0..x0+W and z1-D..z1, front on the z1 side (facing +z).
static func build(w: World, body: StaticBody3D, x0: float, z1: float, gy: float) -> void:
	if keeper_positions.is_empty():
		items.clear()
	var z0 := z1 - D
	# --- 1. Materials & Textures ---
	var brick_tex := load("res://assets/textures/ammo_shop_bricks097.jpg") as Texture2D
	var floor_tex := load("res://assets/textures/ammo_shop_diamondplate009.jpg") as Texture2D
	var ceil_tex := load("res://assets/textures/ammo_shop_tiles141.jpg") as Texture2D
	var door_tex := load("res://assets/textures/ammo_shop_door.png") as Texture2D
	var crate_side_tex := load("res://assets/textures/ammo_crate_side.png") as Texture2D
	var crate_top_tex := load("res://assets/textures/ammo_crate_top.png") as Texture2D
	var target_tex := load("res://assets/textures/shooting_target.png") as Texture2D
	var safety_tex := load("res://assets/textures/safety_warning_sign.png") as Texture2D
	var white_pegboard_tex := load("res://assets/textures/ammo_shop_white_pegboard.png") as Texture2D

	var brick := StandardMaterial3D.new()
	if brick_tex:
		brick.albedo_texture = brick_tex
		brick.uv1_triplanar = true
		brick.uv1_scale = Vector3(0.35, 0.35, 0.35)
		brick.roughness = 0.85
	else:
		brick.albedo_color = Color("#7a3b2c")

	var trim: Material = w._flat(Color("#202124"))
	var metal_dark: Material = w._flat(Color("#1a1b1e"))
	var white_pegboard := StandardMaterial3D.new()
	if white_pegboard_tex:
		white_pegboard.albedo_texture = white_pegboard_tex
		white_pegboard.uv1_scale = Vector3(6.0, 2.0, 1.0)
	white_pegboard.albedo_color = Color(0.98, 0.98, 1.0)
	white_pegboard.roughness = 0.35
	white_pegboard.emission_enabled = true
	white_pegboard.emission = Color(1.0, 1.0, 1.0)
	white_pegboard.emission_energy_multiplier = 0.22

	var shelf_white := StandardMaterial3D.new()
	shelf_white.albedo_color = Color("#f4f5f8")
	shelf_white.roughness = 0.3
	shelf_white.metallic = 0.05

	var floor_m := StandardMaterial3D.new()
	if floor_tex:
		floor_m.albedo_texture = floor_tex
		floor_m.uv1_triplanar = true
		floor_m.uv1_scale = Vector3(0.45, 0.45, 0.45)
		floor_m.metallic = 0.65
		floor_m.roughness = 0.35
	else:
		floor_m.albedo_color = Color("#32353a")

	var ceil_m := StandardMaterial3D.new()
	if ceil_tex:
		ceil_m.albedo_texture = ceil_tex
		ceil_m.uv1_triplanar = true
		ceil_m.uv1_scale = Vector3(0.4, 0.4, 0.4)
		ceil_m.albedo_color = Color(0.4, 0.4, 0.42)
		ceil_m.roughness = 0.7
	else:
		ceil_m.albedo_color = Color("#2a2b2e")

	var wall_in := StandardMaterial3D.new()
	if brick_tex:
		wall_in.albedo_texture = brick_tex
		wall_in.uv1_triplanar = true
		wall_in.uv1_scale = Vector3(0.35, 0.35, 0.35)
		wall_in.roughness = 0.8
	else:
		wall_in.albedo_color = Color("#6e382b")

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.65, 0.82, 0.92, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.04
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	var door_mat := StandardMaterial3D.new()
	if door_tex:
		door_mat.albedo_texture = door_tex
		door_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		door_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		door_mat.roughness = 0.1
	else:
		door_mat.albedo_color = Color(0.2, 0.25, 0.3, 0.8)

	var crate_side_mat := StandardMaterial3D.new()
	if crate_side_tex: crate_side_mat.albedo_texture = crate_side_tex
	else: crate_side_mat.albedo_color = Color("#435128")
	crate_side_mat.roughness = 0.75

	var crate_top_mat := StandardMaterial3D.new()
	if crate_top_tex: crate_top_mat.albedo_texture = crate_top_tex
	else: crate_top_mat.albedo_color = Color("#4a582c")
	crate_top_mat.roughness = 0.75

	var target_mat := StandardMaterial3D.new()
	if target_tex: target_mat.albedo_texture = target_tex
	target_mat.roughness = 0.9
	target_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var safety_mat := StandardMaterial3D.new()
	if safety_tex: safety_mat.albedo_texture = safety_tex
	safety_mat.roughness = 0.5
	safety_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var x1 := x0 + W
	var fy := gy + 0.02

	# --- 2. Floors & Structure ---
	_box(w, body, Vector3(x0, gy, z0), Vector3(x1, fy, z1), floor_m)
	_box(w, body, Vector3(x0 - 0.15, gy + H, z0 - 0.15), Vector3(x1 + 0.15, gy + H + 0.35, z1 + 0.15), trim)
	_box(w, body, Vector3(x0, gy + H - 0.05, z0), Vector3(x1, gy + H, z1), ceil_m, false)

	# Outer walls (solid brick)
	var t := 0.3
	_box(w, body, Vector3(x0, gy, z0 - t), Vector3(x1, gy + H, z0), brick)
	_box(w, body, Vector3(x0 - t, gy, z0 - t), Vector3(x0, gy + H, z1), brick)
	# East wall facing parking lot: solid back wall, side display window, and front corner pillar
	_box(w, body, Vector3(x1, gy, z0 - t), Vector3(x1 + t, gy + H, z1 - 3.8), brick)
	# Side display window facing parking lot (glazed display window)
	_box(w, body, Vector3(x1, gy, z1 - 3.8), Vector3(x1 + t, gy + 0.65, z1 - 1.2), brick)
	_box(w, body, Vector3(x1 + 0.08, gy + 0.65, z1 - 3.8), Vector3(x1 + 0.16, gy + 2.75, z1 - 1.2), glass, true)
	_box(w, body, Vector3(x1 - 0.02, gy + 0.63, z1 - 3.85), Vector3(x1 + t + 0.02, gy + 0.67, z1 - 1.15), trim, false)
	_box(w, body, Vector3(x1, gy + 2.75, z1 - 3.8), Vector3(x1 + t, gy + H, z1 - 1.2), brick)
	_box(w, body, Vector3(x1 - 0.02, gy + 2.73, z1 - 3.85), Vector3(x1 + t + 0.02, gy + 2.77, z1 - 1.15), trim, false)
	_box(w, body, Vector3(x1, gy, z1 - 1.2), Vector3(x1 + t, gy + H, z1), brick)
	_box(w, body, Vector3(x0, gy, z0), Vector3(x1, gy + H, z0 + 0.04), wall_in, false)

	# Storefront facade with 4 large display windows and double-door entryway
	var door_w := 2.0
	var dc := x0 + W * 0.5
	var sill := 0.65
	var win_top := 2.75
	# Solid corner brick pillars
	_box(w, body, Vector3(x0, gy, z1 - t), Vector3(x0 + 0.45, gy + H, z1), brick)
	_box(w, body, Vector3(x1 - 0.45, gy, z1 - t), Vector3(x1, gy + H, z1), brick)
	# Structural mullions between outer and inner window bays
	for mx in [[dc - 3.40, dc - 3.15], [dc + 3.15, dc + 3.40]]:
		_box(w, body, Vector3(mx[0], gy, z1 - t), Vector3(mx[1], gy + H, z1), brick)
		_box(w, body, Vector3(mx[0] - 0.02, gy + sill, z1 - 0.14), Vector3(mx[1] + 0.02, gy + win_top, z1 - 0.02), trim, false)
	# 4 Glass storefront window bays (all glazed with full windows!)
	var window_bays := [
		[x0 + 0.45, dc - 3.40],
		[dc - 3.15, dc - 1.05],
		[dc + 1.05, dc + 3.15],
		[dc + 3.40, x1 - 0.45]
	]
	for wb in window_bays:
		var bx0: float = wb[0]
		var bx1: float = wb[1]
		# Brick knee wall under window
		_box(w, body, Vector3(bx0, gy, z1 - t), Vector3(bx1, gy + sill, z1), brick)
		# Aluminum sill trim
		_box(w, body, Vector3(bx0 - 0.02, gy + sill - 0.02, z1 - t - 0.02), Vector3(bx1 + 0.02, gy + sill + 0.03, z1 + 0.02), trim, false)
		# Clear display glass
		_box(w, body, Vector3(bx0, gy + sill, z1 - 0.12), Vector3(bx1, gy + win_top, z1 - 0.04), glass, true)
		# Upper lintel trim
		_box(w, body, Vector3(bx0 - 0.02, gy + win_top - 0.03, z1 - t - 0.02), Vector3(bx1 + 0.02, gy + win_top + 0.02, z1 + 0.02), trim, false)
		# Upper brick wall above window
		_box(w, body, Vector3(bx0, gy + win_top, z1 - t), Vector3(bx1, gy + H, z1), brick)

	# Wall above door transom
	_box(w, body, Vector3(dc - door_w * 0.5, gy + 2.5, z1 - t), Vector3(dc + door_w * 0.5, gy + H, z1), brick)

	# --- 3. Commercial Storefront Double Doors ---
	# Door outer aluminum jambs and header transom
	_box(w, body, Vector3(dc - door_w * 0.5 - 0.06, gy, z1 - 0.12), Vector3(dc - door_w * 0.5, gy + 2.5, z1 + 0.04), trim)
	_box(w, body, Vector3(dc + door_w * 0.5, gy, z1 - 0.12), Vector3(dc + door_w * 0.5 + 0.06, gy + 2.5, z1 + 0.04), trim)
	_box(w, body, Vector3(dc - door_w * 0.5 - 0.04, gy + 2.44, z1 - 0.12), Vector3(dc + door_w * 0.5 + 0.04, gy + 2.52, z1 + 0.04), trim)
	# Transom window glass above doors
	_box(w, body, Vector3(dc - door_w * 0.5 + 0.02, gy + 2.15, z1 - 0.08), Vector3(dc + door_w * 0.5 - 0.02, gy + 2.44, z1 - 0.02), glass, false)
	_box(w, body, Vector3(dc - 0.03, gy + 2.15, z1 - 0.10), Vector3(dc + 0.03, gy + 2.44, z1 + 0.02), trim, false)
	# Animated automatic double doors (smoothly opens upon approach, closes when walking away)
	var doors := GunShopDoors.new()
	w.add_child(doors)
	doors.setup(dc, z1, gy, door_w, door_mat, trim)

	# Entrance welcome mat on floor
	var mat_m := StandardMaterial3D.new()
	mat_m.albedo_color = Color("#18191b")
	mat_m.roughness = 0.9
	_box(w, body, Vector3(dc - 1.2, fy, z1 - 1.4), Vector3(dc + 1.2, fy + 0.015, z1 - 0.1), mat_m, false)

	# --- 4. Main Exterior Signs ---
	var sign_m := StandardMaterial3D.new()
	sign_m.albedo_color = Color("#a31616")
	sign_m.emission_enabled = true
	sign_m.emission = Color("#ff2a1a")
	sign_m.emission_energy_multiplier = 0.0
	CityLights.register_material(sign_m, Color("#ff3322"), 1.6)
	_box(w, body, Vector3(x0 + 2.0, gy + H + 0.35, z1 - 0.1), Vector3(x1 - 2.0, gy + H + 1.55, z1 + 0.15), sign_m, false)
	var lab := Label3D.new()
	lab.text = "REDLINE AMMO"
	lab.font = load("res://assets/fonts/BlackOpsOne-Regular.ttf") as Font
	lab.font_size = 150
	lab.pixel_size = 0.0072
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 16
	lab.outline_modulate = Color(0.3, 0.02, 0.02)
	lab.shaded = false
	lab.position = Vector3(dc, gy + H + 0.95, z1 + 0.17)
	w.static_root.add_child(lab)
	var lab2 := Label3D.new()
	lab2.text = "GUNS  •  AMMO  •  TACTICAL GEAR"
	lab2.font = load("res://assets/fonts/Oswald.ttf") as Font
	lab2.font_size = 64
	lab2.pixel_size = 0.0062
	lab2.modulate = Color(1.0, 0.9, 0.5)
	lab2.shaded = false
	lab2.position = Vector3(dc, gy + 2.95, z1 + 0.06)
	w.static_root.add_child(lab2)

	# --- 5. Back-Wall Racks & Weapon Wall ---
	var rack_z := z0 + 0.06
	var gun_panel := StandardMaterial3D.new()                                  # same plain dark panel as the melee / thrown walls
	gun_panel.albedo_color = Color("#2f343b")
	gun_panel.roughness = 0.9
	# White tactical pegboard backing panel covering back wall (bright white so all guns stand out clearly)
	_box(w, body, Vector3(x0 + 0.3, fy + 0.3, rack_z - 0.02), Vector3(x1 - 0.3, fy + 3.1, rack_z + 0.04), gun_panel, false)
	# Clean white powder-coated weapon shelves
	for ry in [0.85, 1.65, 2.45]:
		_box(w, body, Vector3(x0 + 0.3, fy + ry - 0.04, rack_z), Vector3(x1 - 0.3, fy + ry + 0.04, rack_z + 0.35), shelf_white, false)
		# Subtle dark trim edge on front of shelves for clean definition
		_box(w, body, Vector3(x0 + 0.3, fy + ry - 0.045, rack_z + 0.345), Vector3(x1 - 0.3, fy + ry + 0.045, rack_z + 0.36), trim, false)
	_box(w, body, Vector3(x0 + 0.3, fy, rack_z), Vector3(x1 - 0.3, fy + 0.28, rack_z + 0.45), metal_dark)
	_guns(w, x0, x1, rack_z, fy)
	_side_displays(w, body, x0, x1, z0, z1, fy, metal_dark, trim)

	# --- 6. Front Glass Showcase Counter ---
	var cx0 := x0 + 2.2
	var cx1 := x1 - 2.2
	var cz0 := z1 - 5.3
	var cz1 := z1 - 4.45
	var ch := 1.08

	# Heavy black steel base plinth
	_box(w, body, Vector3(cx0, fy, cz0), Vector3(cx1, fy + 0.34, cz1), metal_dark)
	# Aluminum counter end-caps and center divider
	_box(w, body, Vector3(cx0, fy + 0.34, cz0), Vector3(cx0 + 0.18, fy + ch, cz1), trim)
	_box(w, body, Vector3(cx1 - 0.18, fy + 0.34, cz0), Vector3(cx1, fy + ch, cz1), trim)
	_box(w, body, Vector3(dc - 0.09, fy + 0.34, cz0), Vector3(dc + 0.09, fy + ch, cz1), trim)
	# Velvet display deck inside showcase
	var velvet_mat := StandardMaterial3D.new()
	velvet_mat.albedo_color = Color("#141517")
	velvet_mat.roughness = 0.95
	_box(w, body, Vector3(cx0 + 0.18, fy + 0.34, cz0 + 0.05), Vector3(cx1 - 0.18, fy + 0.36, cz1 - 0.05), velvet_mat, false)
	# Front showcase clear glass panels
	_box(w, body, Vector3(cx0 + 0.18, fy + 0.35, cz1 - 0.06), Vector3(cx1 - 0.18, fy + ch - 0.04, cz1 - 0.02), glass, false)
	# Top showcase clear glass counter top
	_box(w, body, Vector3(cx0, fy + ch - 0.03, cz0 - 0.04), Vector3(cx1, fy + ch, cz1 + 0.04), glass, true)
	# Sleek aluminum counter top rim
	_box(w, body, Vector3(cx0 - 0.04, fy + ch, cz0 - 0.06), Vector3(cx1 + 0.04, fy + ch + 0.03, cz1 + 0.06), trim, false)

	# Interior soft LED strip light along top rim of showcase
	var case_led := StandardMaterial3D.new()
	case_led.albedo_color = Color(0.9, 0.95, 1.0)
	case_led.emission_enabled = true
	case_led.emission = Color(0.85, 0.92, 1.0)
	case_led.emission_energy_multiplier = 2.0
	CityLights.register_material(case_led, Color(0.85, 0.92, 1.0), 2.0)
	_box(w, body, Vector3(cx0 + 0.2, fy + ch - 0.06, cz1 - 0.08), Vector3(cx1 - 0.2, fy + ch - 0.04, cz1 - 0.05), case_led, false)

	# Handguns displayed under glass on velvet deck
	_showcase_handguns(w, cx0, cx1, fy + 0.38, cz0 + 0.4)

	# Countertop accessories: Computer POS monitor and gun cleaning mat
	var pos_mat := w._flat(Color("#1d1f22"))
	_box(w, body, Vector3(dc - 1.25, fy + ch + 0.03, cz1 - 0.55), Vector3(dc - 0.85, fy + ch + 0.38, cz1 - 0.50), pos_mat, false)
	_box(w, body, Vector3(dc - 1.10, fy + ch + 0.03, cz1 - 0.55), Vector3(dc - 1.00, fy + ch + 0.15, cz1 - 0.45), pos_mat, false)
	# Cleaning / checkout rubber mat on top of counter
	var mat_top := w._flat(Color("#23282f"))
	_box(w, body, Vector3(dc - 0.55, fy + ch + 0.03, cz1 - 0.70), Vector3(dc + 0.55, fy + ch + 0.04, cz1 - 0.20), mat_top, false)

	# Ammo Box on counter (interactive item)
	var ab := MeshInstance3D.new()
	var abm := BoxMesh.new()
	abm.size = Vector3(0.52, 0.30, 0.34)
	ab.mesh = abm
	ab.material_override = crate_side_mat
	ab.position = Vector3(dc + 1.2, fy + ch + 0.15 + 0.03, cz1 - 0.48)
	w.static_root.add_child(ab)
	items.append({"pos": Vector3(dc + 1.2, fy + ch + 0.15, cz1 - 0.48), "cat": "AMMO", "id": "ammo", "name": ammo_box.name, "price": ammo_box.price, "ammo": ammo_box.ammo})

	# --- 7. Shop Owner Character (SWAT Model) ---
	keeper_pos = Vector3(dc - 2.3, fy, z1 - 6.2)
	keeper_positions.append(keeper_pos)
	var keeper := Ped.new()
	w.add_child(keeper)
	keeper.global_position = keeper_pos + Vector3(0, 0.02, 0)
	var kp: Array[Vector3] = [keeper_pos]
	keeper.setup("npc_shopkeeper", kp, 0, 1)
	keeper.remove_from_group("peds")
	keeper.set_physics_process(false)
	keeper.face = 0.0
	keeper.model.rotation.y = 0.0
	keeper.play("Idle")

	# --- 8. Tactical Ammo Crates Stacks ---
	# Front-left window crate stack (3 crates)
	# Side counter munitions stack
	_ammo_crate(w, body, Vector3(x0 + 1.2, fy, z1 - 4.6), 90.0, Vector3(0.95, 0.48, 0.60), crate_side_mat, crate_top_mat, trim)
	_ammo_crate(w, body, Vector3(x0 + 1.2, fy + 0.48, z1 - 4.6), 85.0, Vector3(0.90, 0.44, 0.56), crate_side_mat, crate_top_mat, trim)

	# --- 9. Wall Posters & Signage ---
	# Left wall: Shooting range qualification targets with bullet groupings
	_wall_poster(w, Vector3(x0 + 0.02, fy + 1.85, z1 - 2.6), Vector3.RIGHT, 0.70, 1.05, target_mat)
	_wall_poster(w, Vector3(x0 + 0.02, fy + 1.85, z1 - 3.8), Vector3.RIGHT, 0.70, 1.05, target_mat)
	# Left wall: Official Safety Warning Rules Sign
	_wall_poster(w, Vector3(x0 + 0.02, fy + 2.05, z1 - 1.3), Vector3.RIGHT, 0.95, 0.48, safety_mat)
	# Right wall: Official Safety Sign and Target

	# --- 10. Proper Industrial Ceiling Lighting ---
	var troffer_mat := w._flat(Color("#1d1f23"))
	var tube_mat := StandardMaterial3D.new()
	tube_mat.albedo_color = Color(0.96, 0.98, 1.0)
	tube_mat.emission_enabled = true
	tube_mat.emission = Color(0.96, 0.98, 1.0)
	tube_mat.emission_energy_multiplier = 2.4
	CityLights.register_material(tube_mat, Color(0.96, 0.98, 1.0), 2.4)

	# 4 Industrial fluorescent ceiling troffers
	var troffer_pts: Array[Vector3] = [
		Vector3(x0 + 3.6, gy + H - 0.12, z1 - 2.6), # Front-left
		Vector3(x1 - 3.6, gy + H - 0.12, z1 - 2.6), # Front-right
		Vector3(x0 + 3.6, gy + H - 0.12, z0 + 3.2), # Back-left
		Vector3(x1 - 3.6, gy + H - 0.12, z0 + 3.2), # Back-right
	]
	for tp in troffer_pts:
		_ceiling_troffer(w, tp, Vector3(2.2, 0.12, 0.65), troffer_mat, tube_mat, 1.4)

	# 2 Focused showcase downward spotlights (crisp specular highlights on glass and counter guns)
	for sx in [x0 + 4.2, x1 - 4.2]:
		var cs := SpotLight3D.new()
		cs.position = Vector3(sx, gy + H - 0.2, cz1 - 0.25)
		cs.rotation_degrees.x = -85.0
		cs.spot_range = 5.2
		cs.spot_angle = 38.0
		cs.spot_attenuation = 0.75
		cs.light_energy = 1.9
		cs.light_color = Color(0.98, 0.99, 1.0)
		cs.shadow_enabled = false
		CityLights.register_light(cs, 1.9)
		w.add_child(cs)

	# 2 Angled spotlights illuminating the back pegboard gun wall
	for bx in [x0 + 4.0, x1 - 4.0]:
		var bs := SpotLight3D.new()
		bs.position = Vector3(bx, gy + H - 0.2, z0 + 2.4)
		bs.rotation_degrees = Vector3(-62.0, 180.0, 0.0)
		bs.spot_range = 6.0
		bs.spot_angle = 48.0
		bs.spot_attenuation = 0.8
		bs.light_energy = 2.8
		bs.light_color = Color(1.0, 1.0, 1.0)
		bs.shadow_enabled = false
		CityLights.register_light(bs, 2.8)
		w.add_child(bs)

	# Warm welcoming downlight directly over the front entrance doorway
	var door_light := SpotLight3D.new()
	door_light.position = Vector3(dc, gy + 2.58, z1 - 0.25)
	door_light.rotation_degrees.x = -88.0
	door_light.spot_range = 4.2
	door_light.spot_angle = 48.0
	door_light.spot_attenuation = 0.7
	door_light.light_energy = 1.8
	door_light.light_color = Color(1.0, 0.95, 0.88)
	door_light.shadow_enabled = false
	CityLights.register_light(door_light, 1.8)
	w.add_child(door_light)

	# Ambient soft fill omni light
	var fill := OmniLight3D.new()
	fill.position = Vector3(dc, gy + H - 0.4, z0 + D * 0.5)
	fill.omni_range = 10.0
	fill.light_energy = 0.45
	fill.light_color = Color(0.95, 0.92, 0.85)
	fill.shadow_enabled = false
	w.add_child(fill)

	w.add_poi("gun", "REDLINE AMMO", Vector3(dc, 0.0, z1 - 4.0))
	(CityBuild.layout.buildings as Array).append({"k": "gunshop", "x": dc, "z": z0 + D * 0.5, "yaw": 0.0, "w": W, "d": D})
	_build_parking(w, body, x0, z1, gy)

## Builds the dedicated customer and rear parking for Redline Ammo.
## Extends LOT_W (13 m) to the east (+x) as a driveway and side parking bay,
## and BACK_D (7.5 m) behind (-z) across the full width (27 m) for rear parking.
## Paved with dark asphalt, painted white bays, concrete wheel stops, brick pillars
## with security railings, entrance sign, commercial dumpster, stacked ammo crates,
## a nighttime floodlight pole, and a parked car.
static func _build_parking(w: World, body: StaticBody3D, x0: float, z1: float, gy: float) -> void:
	var z0 := z1 - D
	var x1 := x0 + W
	var x_east := x1 + LOT_W
	var z_back := z0 - BACK_D
	var py := gy + 0.02

	var asphalt: Material = w._flat(Color("#28282b"))
	var kerb: Material = w._flat(Color("#c2bfb8"))
	var brick: Material = w._flat(Color("#7a3b2c"))
	var trim: Material = w._flat(Color("#2b2b2e"))
	var line_mat: Material = w._flat(Color("#f0eee4"))
	var fence_mat: Material = w._flat(Color("#232427"))
	var wood_pal: Material = w._flat(Color("#5a432e"))
	var ammo_crate_mat: Material = w._flat(Color("#435128"))
	var dumpster_mat: Material = w._flat(Color("#27422c"))
	var steel_door: Material = w._flat(Color("#36383e"))

	# 1. Asphalt paving
	# Side driveway / customer lot: x1..x_east, z0..z1
	_box(w, body, Vector3(x1, gy, z0), Vector3(x_east, py, z1), asphalt)
	# Apron connecting smoothly to the lane street
	_box(w, body, Vector3(x1 + 0.2, gy - 0.02, z1), Vector3(x_east - 0.2, py, z1 + 3.0), asphalt)
	# Rear parking lot: x0..x_east, z_back..z0
	_box(w, body, Vector3(x0, gy, z_back), Vector3(x_east, py, z0), asphalt)

	# Register in CityBuild.layout.lots for maps and minimap
	(CityBuild.layout.lots as Array).append([x1, z0, x_east, z1])
	(CityBuild.layout.lots as Array).append([x0, z_back, x_east, z0])

	# 2. Outer perimeter concrete kerbs
	var kw := 0.26
	var kh := 0.18
	# North border (back)
	_box(w, body, Vector3(x0 - kw, gy, z_back - kw), Vector3(x_east + kw, gy + kh, z_back), kerb)
	# West border (behind shop)
	_box(w, body, Vector3(x0 - kw, gy, z_back), Vector3(x0, gy + kh, z0), kerb)
	# East border
	_box(w, body, Vector3(x_east, gy, z_back), Vector3(x_east + kw, gy + kh, z1), kerb)

	# 3. Security perimeter: Brick pillars and metal fence
	var pillar_pts: Array[Vector2] = [
		Vector2(x_east, z1),
		Vector2(x_east, (z1 + z_back) * 0.5),
		Vector2(x_east, z_back),
		Vector2((x0 + x_east) * 0.5, z_back),
		Vector2(x0, z_back),
		Vector2(x0, z0)
	]
	var pw := 0.65
	var ph := 2.05
	for pt in pillar_pts:
		_box(w, body, Vector3(pt.x - pw * 0.5, gy, pt.y - pw * 0.5), Vector3(pt.x + pw * 0.5, gy + ph, pt.y + pw * 0.5), brick)
		_box(w, body, Vector3(pt.x - pw * 0.5 - 0.05, gy + ph, pt.y - pw * 0.5 - 0.05), Vector3(pt.x + pw * 0.5 + 0.05, gy + ph + 0.18, pt.y + pw * 0.5 + 0.05), trim)

	# Metal fence railings between pillars
	_fence_section(w, body, Vector3(x_east, gy, z1 - pw * 0.5), Vector3(x_east, gy, (z1 + z_back) * 0.5 + pw * 0.5), fence_mat)
	_fence_section(w, body, Vector3(x_east, gy, (z1 + z_back) * 0.5 - pw * 0.5), Vector3(x_east, gy, z_back + pw * 0.5), fence_mat)
	_fence_section(w, body, Vector3(x_east - pw * 0.5, gy, z_back), Vector3((x0 + x_east) * 0.5 + pw * 0.5, gy, z_back), fence_mat)
	_fence_section(w, body, Vector3((x0 + x_east) * 0.5 - pw * 0.5, gy, z_back), Vector3(x0 + pw * 0.5, gy, z_back), fence_mat)
	_fence_section(w, body, Vector3(x0, gy, z_back + pw * 0.5), Vector3(x0, gy, z0 - 0.1), fence_mat)

	# 4. Painted Bays and Concrete Wheel Stops
	# A) Rear bays: 4 bays along the back north wall behind the shop
	var bay_w := 2.85
	var bay_d := 4.8
	var rear_bays_x0 := x0 + 0.8
	for k in range(5):
		var lx := rear_bays_x0 + k * bay_w
		_box(w, body, Vector3(lx - 0.06, py, z_back + 0.2), Vector3(lx + 0.06, py + 0.008, z_back + bay_d), line_mat, false)
	for k in range(4):
		var bc := rear_bays_x0 + (k + 0.5) * bay_w
		_box(w, body, Vector3(bc - 0.9, py, z_back + 0.5), Vector3(bc + 0.9, py + 0.13, z_back + 0.72), kerb)
		var num := Label3D.new()
		num.text = str(k + 1)
		num.font_size = 40
		num.pixel_size = 0.005
		num.modulate = Color(1.0, 0.88, 0.3)
		num.rotation_degrees = Vector3(-90, 180, 0)
		num.position = Vector3(bc, py + 0.01, z_back + 1.2)
		w.static_root.add_child(num)

	# B) Side bays: 2 customer bays along the east fence
	var side_bay_l := 4.9
	var s_z1 := z1 - 2.8
	var s_z2 := s_z1 - 3.0
	var s_z3 := s_z2 - 3.0
	for sz in [s_z1, s_z2, s_z3]:
		_box(w, body, Vector3(x_east - side_bay_l, py, sz - 0.06), Vector3(x_east - 0.2, py + 0.008, sz + 0.06), line_mat, false)
	for sz_c in [(s_z1 + s_z2) * 0.5, (s_z2 + s_z3) * 0.5]:
		_box(w, body, Vector3(x_east - 0.72, py, sz_c - 0.9), Vector3(x_east - 0.5, py + 0.13, sz_c + 0.9), kerb)



	# 6. Rear Service Door on the back wall of the Gun Shop (outer face at z0 - 0.3)
	var z_wall := z0 - 0.3
	var door_x := x0 + 11.2
	_box(w, body, Vector3(door_x - 0.58, gy, z_wall - 0.02), Vector3(door_x + 0.58, gy + 2.25, z_wall + 0.02), trim)
	_box(w, body, Vector3(door_x - 0.50, gy, z_wall - 0.04), Vector3(door_x + 0.50, gy + 2.18, z_wall - 0.01), steel_door)
	var dlab := Label3D.new()
	dlab.text = "DELIVERIES"
	dlab.font_size = 32
	dlab.pixel_size = 0.003
	dlab.modulate = Color(1.0, 0.85, 0.3)
	dlab.rotation_degrees = Vector3(0, 180, 0)
	dlab.position = Vector3(door_x, gy + 2.05, z_wall - 0.06)
	w.static_root.add_child(dlab)

	# Service door lamp above door
	_box(w, body, Vector3(door_x - 0.12, gy + 2.45, z_wall - 0.22), Vector3(door_x + 0.12, gy + 2.58, z_wall), trim)
	var door_glow_mat := StandardMaterial3D.new()
	door_glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	CityLights.register_material(door_glow_mat, Color(1.0, 0.8, 0.4), 2.0)
	_box(w, body, Vector3(door_x - 0.08, gy + 2.42, z_wall - 0.20), Vector3(door_x + 0.08, gy + 2.45, z_wall - 0.04), door_glow_mat, false)
	var door_light := OmniLight3D.new()
	door_light.position = Vector3(door_x, gy + 2.38, z_wall - 0.25)
	door_light.omni_range = 6.0
	door_light.light_energy = 0.9
	door_light.light_color = Color(1.0, 0.88, 0.65)
	door_light.shadow_enabled = false
	CityLights.register_light(door_light, 0.9)
	w.add_child(door_light)

	# 7. Stacked Ammo Crates & Pallets
	var pal_x := x0 + 8.5
	var pal_z := z_wall - 0.85
	_box(w, body, Vector3(pal_x - 0.7, py, pal_z - 0.6), Vector3(pal_x + 0.7, py + 0.14, pal_z + 0.6), wood_pal)
	_box(w, body, Vector3(pal_x - 0.62, py + 0.14, pal_z - 0.52), Vector3(pal_x - 0.05, py + 0.52, pal_z + 0.52), ammo_crate_mat)
	_box(w, body, Vector3(pal_x + 0.05, py + 0.14, pal_z - 0.52), Vector3(pal_x + 0.62, py + 0.52, pal_z + 0.52), ammo_crate_mat)
	_box(w, body, Vector3(pal_x - 0.32, py + 0.52, pal_z - 0.45), Vector3(pal_x + 0.32, py + 0.90, pal_z + 0.45), ammo_crate_mat)
	var crate_lbl := Label3D.new()
	crate_lbl.text = "7.62x39\nAMMO"
	crate_lbl.font_size = 32
	crate_lbl.pixel_size = 0.003
	crate_lbl.modulate = Color(1.0, 0.9, 0.3)
	crate_lbl.rotation_degrees = Vector3(0, 180, 0)
	crate_lbl.position = Vector3(pal_x, py + 0.72, pal_z - 0.48)
	w.static_root.add_child(crate_lbl)

	# 8. Commercial Green Dumpster in back-east corner
	var dump_x := x_east - 2.6
	var dump_z := z_back + 1.8
	_box(w, body, Vector3(dump_x - 1.05, py + 0.1, dump_z - 0.75), Vector3(dump_x + 1.05, py + 1.25, dump_z + 0.75), dumpster_mat)
	_box(w, body, Vector3(dump_x - 1.08, py + 1.25, dump_z - 0.78), Vector3(dump_x + 1.08, py + 1.34, dump_z + 0.78), trim)
	_box(w, body, Vector3(dump_x - 1.15, py + 0.55, dump_z - 0.5), Vector3(dump_x - 1.05, py + 0.75, dump_z + 0.5), trim)
	_box(w, body, Vector3(dump_x + 1.05, py + 0.55, dump_z - 0.5), Vector3(dump_x + 1.15, py + 0.75, dump_z + 0.5), trim)

	# 9. Parking Lot Floodlight Pole (3D Model: single_parking_lot_light.glb)
	var pole_x := x_east - 0.5
	var pole_z := z0 - 0.2
	var light_scene := load("res://assets/props/single_parking_lot_light.glb") as PackedScene
	if light_scene:
		var pole_inst := light_scene.instantiate() as Node3D
		var light_scale := 0.72  # ~7.5m pole height, 2.7m arm reach
		pole_inst.scale = Vector3.ONE * light_scale
		pole_inst.rotation.y = PI * 0.92  # Arm reaches inward across the lot bays
		pole_inst.position = Vector3(pole_x, gy, pole_z)
		w.static_root.add_child(pole_inst)

		# Collision for the pole base
		CoastProps._box(body, Vector3(0.5, 7.5, 0.5), Vector3(pole_x, gy + 3.75, pole_z))

		# Register emissive head with CityLights so it illuminates at dusk/night
		for c in pole_inst.find_children("*", "MeshInstance3D"):
			var mi := c as MeshInstance3D
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var m := mi.mesh.surface_get_material(s)
					if m and m.resource_name == "material_15":
						var dup: StandardMaterial3D = m.duplicate()
						mi.set_surface_override_material(s, dup)
						CityLights.register_material(dup, Color(1.0, 0.95, 0.88), 4.0)

		var head_local := Vector3(2.24, 10.13, 0.0)
		var head_world: Vector3 = pole_inst.transform * head_local

		# Ambient omni fill under the fixture
		var flood_l := OmniLight3D.new()
		flood_l.position = head_world + Vector3(0, -0.3, 0)
		flood_l.omni_range = 28.0
		flood_l.omni_attenuation = 0.8
		flood_l.light_energy = 2.0
		flood_l.light_color = Color(1.0, 0.96, 0.88)
		flood_l.shadow_enabled = false
		CityLights.register_light(flood_l, 2.0)
		w.add_child(flood_l)

		# Downward angled beam illuminating the lot asphalt & bays
		var beam := SpotLight3D.new()
		var beam_target := Vector3(pole_x - 6.5, gy, pole_z - 3.5)
		beam.look_at_from_position(head_world + Vector3(0, -0.2, 0), beam_target, Vector3.UP)
		beam.spot_range = 35.0
		beam.spot_angle = 68.0
		beam.spot_attenuation = 0.9
		beam.spot_angle_attenuation = 1.0
		beam.light_energy = 3.2
		beam.light_color = Color(1.0, 0.97, 0.90)
		beam.shadow_enabled = false
		CityLights.register_light(beam, 3.2)
		w.add_child(beam)

	# 10. Parked Vehicle in Rear Bay 2
	var car := Car.new()
	car.position = Vector3(rear_bays_x0 + 1.5 * bay_w, py + Car.RIDE + 0.15, z_back + 2.7)
	car.rotation.y = 0.0
	w.add_child(car)
	car.setup("van", "", true)

static func _fence_section(w: Node3D, body: StaticBody3D, p0: Vector3, p1: Vector3, mat: Material) -> void:
	var len := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	if len < 0.2: return
	var fh := 1.7
	var dir := Vector2(p1.x - p0.x, p1.z - p0.z).normalized()
	var perp := Vector2(-dir.y, dir.x) * 0.06
	var min_x := minf(p0.x, p1.x) - absf(perp.x)
	var max_x := maxf(p0.x, p1.x) + absf(perp.x)
	var min_z := minf(p0.z, p1.z) - absf(perp.y)
	var max_z := maxf(p0.z, p1.z) + absf(perp.y)
	_box(w, body, Vector3(min_x, p0.y + 0.05, min_z), Vector3(max_x, p0.y + fh, max_z), mat)

static func _box(w: Node3D, body: StaticBody3D, a: Vector3, b: Vector3, mat: Material, collide := true) -> void:
	var size := (b - a).abs()
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001: return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(w as World).static_root.add_child(mi)
	if collide: CoastProps._box(body, size, mi.position)

## Every gun of the pack on the back wall, three shelves, barrels pointing along the wall, with a price tag under each.
static func _guns(w: World, x0: float, x1: float, rack_z: float, fy: float) -> void:
	if not ResourceLoader.exists(PACK): return
	var src := (load(PACK) as PackedScene).instantiate() as Node3D
	var per_row := 10
	for gi in range(GUNS.size()):
		var g: Array = GUNS[gi]
		var made := make_gun(src, String(g[0]))
		if made.is_empty(): continue
		var holder: Node3D = made.node
		var bb: AABB = made.bb
		var row := gi / per_row
		var col := gi % per_row
		var span := (x1 - x0 - 0.9)
		var cx := x0 + 0.45 + span * (float(col) + 0.5) / float(per_row)
		var ry: float = [0.85, 1.65, 2.45][row]
		var len := maxf(bb.size.z, maxf(bb.size.x, bb.size.y))
		var holder_root := Node3D.new()
		holder_root.add_child(holder)
		var long_z := bb.size.z >= bb.size.x
		holder.rotation.y = PI * 0.5 if long_z else 0.0                       # lie along the wall (x)
		var squash := minf(1.0, (span / float(per_row)) / maxf(len, 0.01) * 0.92)
		squash = minf(squash, 0.6 / maxf(bb.size.y, 0.01))                    # never taller than the gap to the shelf above
		holder.scale = Vector3.ONE * squash
		holder_root.position = Vector3(cx, fy + ry + bb.size.y * squash * 0.5 + 0.05, rack_z + 0.17)
		w.static_root.add_child(holder_root)
		var tag := Label3D.new()
		tag.text = "%s\n$%d" % [g[1], int(g[2])]
		tag.font_size = 40
		tag.pixel_size = 0.0034
		tag.width = 420
		tag.modulate = Color(0.95, 0.95, 0.97)
		tag.outline_size = 8
		tag.outline_modulate = Color(0.05, 0.05, 0.07)
		tag.shaded = false
		tag.double_sided = false
		tag.position = Vector3(cx, fy + ry - 0.2, rack_z + 0.38)
		w.static_root.add_child(tag)
		items.append({"pos": Vector3(cx, fy + ry + 0.1, rack_z + 0.4), "cat": category_of(gi), "id": String(g[0]), "name": String(g[1]), "price": int(g[2]), "ammo": int(g[3])})
	src.free()

static func _door_wing(w: World, body: StaticBody3D, hinge_pos: Vector3, angle_rad: float, w_door: float, h_door: float, door_mat: Material, metal_mat: Material) -> void:
	var door_root := Node3D.new()
	door_root.position = hinge_pos
	door_root.rotation.y = angle_rad
	w.static_root.add_child(door_root)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w_door, h_door, 0.04)
	mi.mesh = bm
	mi.material_override = door_mat
	mi.position = Vector3(w_door * 0.5, h_door * 0.5, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	door_root.add_child(mi)

	var bar := MeshInstance3D.new()
	var barm := BoxMesh.new()
	barm.size = Vector3(w_door * 0.85, 0.06, 0.07)
	bar.mesh = barm
	bar.material_override = metal_mat
	bar.position = Vector3(w_door * 0.5, 1.05, 0.045)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	door_root.add_child(bar)

	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.04, 0.40, 0.08)
	handle.mesh = hm
	handle.material_override = metal_mat
	handle.position = Vector3(w_door * 0.86, 1.05, -0.045)
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	door_root.add_child(handle)

static func _wall_poster(w: World, center_pos: Vector3, normal: Vector3, pw: float, ph: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(pw, ph)
	mi.mesh = qm
	mi.material_override = mat
	mi.position = center_pos + normal * 0.015
	if normal.dot(Vector3.RIGHT) > 0.9:
		mi.rotation.y = -PI * 0.5
	elif normal.dot(Vector3.LEFT) > 0.9:
		mi.rotation.y = PI * 0.5
	elif normal.dot(Vector3.FORWARD) > 0.9:
		mi.rotation.y = PI
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

static func _ammo_crate(w: World, body: StaticBody3D, pos: Vector3, yaw_deg: float, sz: Vector3, side_mat: Material, top_mat: Material, trim_mat: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	w.static_root.add_child(root)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = side_mat
	mi.position = Vector3(0, sz.y * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(sz.x * 1.02, 0.035, sz.z * 1.02)
	top.mesh = tm
	top.material_override = top_mat
	top.position = Vector3(0, sz.y + 0.018, 0)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(top)

	for cx in [-sz.x * 0.47, sz.x * 0.47]:
		var band := MeshInstance3D.new()
		var bdm := BoxMesh.new()
		bdm.size = Vector3(0.045, sz.y * 1.02, sz.z * 1.04)
		band.mesh = bdm
		band.material_override = trim_mat
		band.position = Vector3(cx, sz.y * 0.5, 0)
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(band)

	CoastProps._box(body, sz, pos + Vector3(0, sz.y * 0.5, 0))

static func _ceiling_troffer(w: World, pos: Vector3, sz: Vector3, housing_mat: Material, emissive_mat: Material, spot_energy: float) -> void:
	var h := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = sz
	h.mesh = hm
	h.material_override = housing_mat
	h.position = pos
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(h)

	var diff := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(sz.x * 0.88, 0.02, sz.z * 0.75)
	diff.mesh = dm
	diff.material_override = emissive_mat
	diff.position = pos - Vector3(0, sz.y * 0.5 + 0.01, 0)
	diff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(diff)

	var spot := SpotLight3D.new()
	spot.position = pos - Vector3(0, sz.y * 0.5 + 0.05, 0)
	spot.rotation_degrees.x = -90.0
	spot.spot_range = 7.5
	spot.spot_angle = 55.0
	spot.spot_attenuation = 0.85
	spot.light_energy = spot_energy
	spot.light_color = Color(0.97, 0.98, 1.0)
	spot.shadow_enabled = false
	CityLights.register_light(spot, spot_energy)
	w.add_child(spot)

static func _showcase_handguns(w: World, x0: float, x1: float, y_deck: float, z_deck: float) -> void:
	if not ResourceLoader.exists(PACK): return
	var src := (load(PACK) as PackedScene).instantiate() as Node3D
	var guns_to_show := ["Deagle", "Revolver_2", "Glock17", "M1911", "Usp45_Silenced", "LugerP08"]
	var count := guns_to_show.size()
	var span := x1 - x0 - 1.4
	for i in range(count):
		var gid: String = guns_to_show[i]
		var made := make_gun(src, gid)
		if made.is_empty(): continue
		var node: Node3D = made.node
		var bb: AABB = made.bb
		var gx := x0 + 0.7 + span * (float(i) + 0.5) / float(count)
		var hroot := Node3D.new()
		hroot.add_child(node)
		var long_z := bb.size.z >= bb.size.x
		node.rotation_degrees = Vector3(15.0, 45.0 if long_z else -45.0, 0.0)
		var max_dim := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		var sc := clampf(0.32 / maxf(max_dim, 0.01), 0.5, 1.1)
		node.scale = Vector3.ONE * sc
		hroot.position = Vector3(gx, y_deck + 0.08, z_deck)
		w.static_root.add_child(hroot)

		var wedge := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.24, 0.05, 0.16)
		wedge.mesh = wm
		var wedge_mat := StandardMaterial3D.new()
		wedge_mat.albedo_color = Color(0.18, 0.20, 0.24, 0.8)
		wedge_mat.roughness = 0.2
		wedge.material_override = wedge_mat
		wedge.position = Vector3(gx, y_deck + 0.025, z_deck)
		wedge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(wedge)
	src.free()

## One gun of the pack as a node centred on its middle (barrel along the model's z): {node, bb}, or {} if the pack has no such gun.
static func make_gun(src: Node3D, id: String) -> Dictionary:
	var holder := Node3D.new()
	var bb := AABB()
	var first := true
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var pn := String(mi.get_parent().name)
		if not pn.begins_with(id): continue
		if id == "Revolver_2" and not (pn == "Revolver_2" or pn == "Revolver_Magazine"): continue
		var xf := Metro._xf(mi, src)
		var node := MeshInstance3D.new()
		node.mesh = (mi as MeshInstance3D).mesh
		node.transform = xf
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in range(node.mesh.get_surface_count()):
			var gm := node.mesh.surface_get_material(si) as BaseMaterial3D
			if gm != null:
				var d := gm.duplicate() as BaseMaterial3D
				d.metallic = minf(d.metallic, 0.2)
				d.roughness = maxf(d.roughness, 0.55)
				d.albedo_texture = null
				d.albedo_color = GUN_COLORS.get(String(gm.resource_name), Color(0.2, 0.2, 0.22))
				node.set_surface_override_material(si, d)
		holder.add_child(node)
		var b: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	if first:
		holder.free()
		return {}
	for ch in holder.get_children(): (ch as Node3D).position -= bb.get_center()
	return {"node": holder, "bb": bb}

## True when the player stands at the counter (within reach of the shopkeeper).
static func near_counter(p: Vector3) -> bool:
	for kp in keeper_positions:
		if Vector2(p.x - kp.x, p.z - kp.z).length() < 3.6 and absf(p.y - kp.y) < 2.5:
			keeper_pos = kp
			return true
	if keeper_pos != Vector3.ZERO:
		return Vector2(p.x - keeper_pos.x, p.z - keeper_pos.z).length() < 3.6 and absf(p.y - keeper_pos.y) < 2.5
	return false

static func category_of(index: int) -> String:
	if index < 6: return "PISTOLS"
	if index < 12: return "SMGS"
	if index < 20: return "RIFLES"
	if index < 23: return "SHOTGUNS"
	if index < 26: return "SNIPERS"
	return "HEAVY"

static func buy(it: Dictionary) -> void:
	if it.is_empty(): return
	if Game.money < int(it.price):
		Game.message.emit("Not enough money for the %s ($%d)" % [it.name, int(it.price)])
		return
	Game.money -= int(it.price)
	if String(it.id) == "ammo":
		Game.ammo_reserve += int(it.ammo)
		Game.message.emit("Bought an ammo box  (reserve %d)" % Game.ammo_reserve)
		return
	var have: int = int(Game.guns_owned.get(String(it.id), 0))
	Game.guns_owned[String(it.id)] = have + int(it.ammo)
	match String(it.get("cat", "")):
		"MELEE": Game.message.emit("Bought %s" % it.name)
		"THROWN": Game.message.emit("Bought %s  (x%d)" % [it.name, int(it.ammo)])
		_: Game.message.emit("Bought %s  (+%d rounds)" % [it.name, int(it.ammo)])


# ---- melee weapons and throwables (side walls) ----
const MELEE_PACK := "res://assets/weapons_extra/melee_pack.glb"
## [id, label, price, count, glb, exact node name in the glb ("" = the whole model), length on the wall (m)]
const EXTRAS := [
	["x_bat", "Baseball bat", 120, 1, MELEE_PACK, "bat", 0.95, "MELEE"],
	["x_axe", "Axe", 300, 1, MELEE_PACK, "axe", 0.85, "MELEE"],
	["x_machete", "Machete", 250, 1, MELEE_PACK, "machete", 0.8, "MELEE"],
	["x_hammer", "Hammer", 150, 1, MELEE_PACK, "hammer", 0.55, "MELEE"],
	["x_cleaver", "Cleaver", 180, 1, MELEE_PACK, "cleaver", 0.4, "MELEE"],
	["x_knife", "Kitchen knife", 90, 1, MELEE_PACK, "kitchenKnife", 0.35, "MELEE"],
	["x_grenade", "Frag grenade", 200, 3, "res://assets/weapons_extra/grenade.glb", "", 0.3, "THROWN"],
	["x_molotov", "Molotov cocktail", 120, 3, "res://assets/weapons_extra/molotov.glb", "", 0.5, "THROWN"]]

static func extra_def(id: String) -> Array:
	for e in EXTRAS:
		if String(e[0]) == id: return e
	return []

## A melee weapon / throwable as a node centred on its middle with the longest side along x (for the menu preview): {node, bb}.
static func make_extra(id: String) -> Dictionary:
	var e := extra_def(id)
	if e.is_empty() or not ResourceLoader.exists(String(e[4])): return {}
	var src := (load(String(e[4])) as PackedScene).instantiate() as Node3D
	var holder := Node3D.new()
	var bb := AABB()
	var first := true
	var verts := PackedVector3Array()
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		if String(e[5]) != "" and String(mi.get_parent().name) != String(e[5]) and String(mi.name) != String(e[5]): continue
		var xf := Metro._xf(mi, src)
		var node := MeshInstance3D.new()
		node.mesh = (mi as MeshInstance3D).mesh
		node.transform = xf
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(node)
		var b: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
		var m := (mi as MeshInstance3D).mesh
		for si in range(m.get_surface_count()):
			var arr := m.surface_get_arrays(si)
			if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array): verts.append(xf * v - Vector3.ZERO)
	src.free()
	if first:
		holder.free()
		return {}
	# which end of the long axis is the thin handle: the end whose cross-section is smaller
	var ax := 0
	if bb.size.y >= bb.size.x and bb.size.y >= bb.size.z: ax = 1
	elif bb.size.z >= bb.size.x: ax = 2
	var ctr := bb.get_center()
	var half := bb.size[ax] * 0.5
	var rad_pos := 0.0
	var rad_neg := 0.0
	var n_pos := 0
	var n_neg := 0
	for v in verts:
		var t := v[ax] - ctr[ax]
		var o1 := v[(ax + 1) % 3] - ctr[(ax + 1) % 3]
		var o2 := v[(ax + 2) % 3] - ctr[(ax + 2) % 3]
		var r2 := o1 * o1 + o2 * o2
		if t > half * 0.35:
			rad_pos += r2
			n_pos += 1
		elif t < -half * 0.35:
			rad_neg += r2
			n_neg += 1
	var handle_pos := (rad_pos / maxf(n_pos, 1)) < (rad_neg / maxf(n_neg, 1))
	for ch in holder.get_children(): (ch as Node3D).position -= bb.get_center()
	# turn the longest side to x
	var root := Node3D.new()
	root.add_child(holder)
	var sz := bb.size
	if sz.y >= sz.x and sz.y >= sz.z:
		root.rotation.z = PI * 0.5
		bb = AABB(-Vector3(sz.y, sz.x, sz.z) * 0.5, Vector3(sz.y, sz.x, sz.z))
	elif sz.z >= sz.x:
		root.rotation.y = PI * 0.5
		bb = AABB(-Vector3(sz.z, sz.y, sz.x) * 0.5, Vector3(sz.z, sz.y, sz.x))
	# handle end on +x of the returned node? (rotating y to x flips the sign, z to x does not)
	var handle_x_pos := handle_pos if ax != 1 else not handle_pos
	return {"node": root, "bb": bb, "handle_x_pos": handle_x_pos}

## Melee weapons hang on a pegboard on the left wall; grenades and molotovs sit on a shelf on the right wall.
static func _side_displays(w: World, body: StaticBody3D, x0: float, x1: float, z0: float, z1: float, fy: float, metal_dark: Material, trim: Material) -> void:
	var peg := StandardMaterial3D.new()                                      # plain dark panel: the weapons stand out, no dotted pegboard
	peg.albedo_color = Color("#2f343b")
	peg.roughness = 0.9
	var za := z0 + 1.0
	var zb := z1 - 5.7
	# left wall: melee
	_box(w, body, Vector3(x0, fy + 0.5, za - 0.2), Vector3(x0 + 0.05, fy + 2.6, zb + 0.2), peg, false)
	_box(w, body, Vector3(x0, fy + 0.7, za - 0.2), Vector3(x0 + 0.3, fy + 0.78, zb + 0.2), trim, false)
	_label(w, "MELEE", Vector3(x0 + 0.08, fy + 2.4, (za + zb) * 0.5), 90.0, 0.006, 60)
	var melee := EXTRAS.filter(func(e): return String(e[7]) == "MELEE")
	for i in melee.size():
		var e: Array = melee[i]
		var made := make_extra(String(e[0]))
		if made.is_empty(): continue
		var z := za + (zb - za) * (float(i) + 0.5) / float(melee.size())
		var node: Node3D = made.node
		var sc: float = float(e[6]) * 1.25 / maxf(made.bb.size.x, 0.001)
		var hold := Node3D.new()
		hold.add_child(node)
		hold.scale = Vector3.ONE * sc
		hold.rotation.z = PI * 0.5                                           # hang vertically
		node.rotation.x = PI * 0.5                                           # spin about the long axis: flat side towards the room
		hold.position = Vector3(x0 + 0.1, fy + 1.65, z)
		w.static_root.add_child(hold)
		_label(w, "%s\n$%d" % [e[1], int(e[2])], Vector3(x0 + 0.08, fy + 0.95, z), 90.0, 0.0034, 40)
		items.append({"pos": Vector3(x0 + 0.5, fy, z), "cat": "MELEE", "id": String(e[0]), "name": String(e[1]), "price": int(e[2]), "ammo": int(e[3])})
	# right wall: throwables on a shelf
	var zc0 := z0 + 1.2
	var zc1 := z1 - 4.4
	_box(w, body, Vector3(x1 - 0.05, fy + 0.5, zc0 - 0.2), Vector3(x1, fy + 2.6, zc1 + 0.2), peg, false)
	_box(w, body, Vector3(x1 - 0.4, fy + 1.1, zc0 - 0.2), Vector3(x1, fy + 1.16, zc1 + 0.2), trim, false)
	_label(w, "THROWN", Vector3(x1 - 0.08, fy + 2.4, (zc0 + zc1) * 0.5), -90.0, 0.006, 60)
	var thrown := EXTRAS.filter(func(e): return String(e[7]) == "THROWN")
	for i in thrown.size():
		var e: Array = thrown[i]
		var made := make_extra(String(e[0]))
		if made.is_empty(): continue
		var zc := zc0 + (zc1 - zc0) * (float(i) + 0.5) / float(thrown.size())
		var sc: float = float(e[6]) / maxf(made.bb.size.x, 0.001)
		for k in 3:
			var hold := Node3D.new()
			hold.add_child(made.node.duplicate())
			hold.scale = Vector3.ONE * sc
			hold.rotation.z = -PI * 0.5 if String(e[0]) == "x_molotov" else 0.0   # bottles stand up
			hold.position = Vector3(x1 - 0.2, fy + 1.16 + made.bb.size.x * sc * 0.5 * (1.0 if String(e[0]) == "x_molotov" else 0.0) + (0.0 if String(e[0]) == "x_molotov" else made.bb.size.y * sc * 0.5), zc + (float(k) - 1.0) * 0.28)
			w.static_root.add_child(hold)
		_label(w, "%s\n$%d" % [e[1], int(e[2])], Vector3(x1 - 0.08, fy + 0.85, zc), -90.0, 0.0034, 40)
		items.append({"pos": Vector3(x1 - 0.5, fy, zc), "cat": "THROWN", "id": String(e[0]), "name": String(e[1]), "price": int(e[2]), "ammo": int(e[3])})

static func _label(w: World, text: String, pos: Vector3, yaw_deg: float, px: float, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = Color(0.95, 0.95, 0.97)
	l.outline_size = 8
	l.outline_modulate = Color(0.05, 0.05, 0.07)
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation_degrees.y = yaw_deg
	w.static_root.add_child(l)
