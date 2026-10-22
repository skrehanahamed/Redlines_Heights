class_name HelipadChopper
extends Chopper
## Helipad Chopper for Police Station and Hospital compounds.
## - Police Station: uses helicopter_police.glb (scaled 1.3, centered on rotor hub, facing +Z forward)
## - Hospital: uses as350_b2.glb (scaled 100.0, centered on rotor hub, facing +Z forward)
##
## Interactive vehicle:
## - The player can walk up to either helipad and press E to fly the helicopter!
## - Rotor blades animate/spin smoothly around their exact hub axes whenever the player
##   or an NPC is riding it (engine ramps up), and spin down smoothly when empty/parked.

const MODEL_POLICE   := "res://assets/town/helicopter_police.glb"
const MODEL_HOSPITAL := "res://assets/town/as350_b2.glb"

const SCALE_POLICE   := 1.3
const SCALE_HOSPITAL := 100.0

var compound_key: String = "police"
var _rotor_main: Node3D = null
var _rotor_tail: Node3D = null

func setup(p_compound_key: String) -> void:
	compound_key = p_compound_key

func _ready() -> void:
	add_to_group("player_heli")
	_build_model()
	_setup_audio()
	yaw = rotation.y

func _build_model() -> void:
	if compound_key == "police":
		_build_police()
	else:
		_build_hospital()

func _setup_audio() -> void:
	_snd = AudioStreamPlayer3D.new()
	var st := load("res://assets/audio/vehicles/helicopter_loop.ogg") as AudioStream
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_snd.stream = st
	_snd.max_distance = 600.0
	_snd.unit_size = 35.0
	_snd.volume_db = -80.0
	add_child(_snd)
	_snd.play()

func _build_police() -> void:
	hud_name = "POLICE HELICOPTER"
	enter_text = "E - fly police helicopter"
	cam_dist = 18.0
	reach = 3.0
	
	if not ResourceLoader.exists(MODEL_POLICE):
		return
	var scene := (load(MODEL_POLICE) as PackedScene).instantiate() as Node3D
	scene.scale = Vector3.ONE * SCALE_POLICE
	# Police model naturally faces +Z (the Chopper vehicle forward direction)
	scene.rotation_degrees.y = 0.0
	# Offset: Y=+0.60 so skids sit on pad surface; Z=-1.34 so rotor hub is at center (0,0)
	scene.position = Vector3(0.0, 0.60, -1.34)
	add_child(scene)
	
	# In helicopter_police.glb:
	# Cylinder = main rotor, Cylinder_001 = tail rotor
	for n in scene.find_children("*", "Node3D", true, false):
		if n.name == "Cylinder":
			_rotor_main = n
		elif n.name == "Cylinder_001":
			_rotor_tail = n
	
	# Solid collision boxes centered on helicopter
	add_solid([
		[Vector3(0, 1.4, -0.2), Vector3(2.4, 2.2, 5.8)],
		[Vector3(0, 1.8, -4.5), Vector3(0.8, 0.8, 4.8)]
	])

func _build_hospital() -> void:
	hud_name = "MEDEVAC HELICOPTER"
	enter_text = "E - fly medevac helicopter"
	cam_dist = 20.0
	reach = 3.0
	
	if not ResourceLoader.exists(MODEL_HOSPITAL):
		return
	var scene := (load(MODEL_HOSPITAL) as PackedScene).instantiate() as Node3D
	scene.scale = Vector3.ONE * SCALE_HOSPITAL
	# In as350_b2.glb, nose is naturally at -Z; rotate 180° so nose faces +Z (Chopper forward)
	scene.rotation_degrees.y = 180.0
	# Offset: Z=-1.58 so rotor mast is at center (0,0); Y=0.0 as skids are flush
	scene.position = Vector3(0.0, 0.0, -1.58)
	add_child(scene)
	
	# Find AS350_B2_complet_LP and the two rotor nodes
	var lp: Node3D = null
	var rp: Node3D = null
	var ra: Node3D = null
	for n in scene.find_children("*", "Node3D", true, false):
		if n.name == "AS350_B2_complet_LP": lp = n
		elif n.name == "rotor_pales": rp = n
		elif n.name == "rotor_anticouple": ra = n
	
	if lp != null and rp != null:
		# True hub center of the 3 main rotor blades is at (0.0912, 3.1408, -1.5791)
		var main_hub := Vector3(0.0912, 3.1408, -1.5791)
		var main_piv := Node3D.new()
		main_piv.name = "rotor_main_pivot"
		lp.add_child(main_piv)
		main_piv.position = main_hub
		rp.owner = null
		rp.reparent(main_piv, false)
		rp.position = -main_hub
		_rotor_main = main_piv
	
	if lp != null and ra != null:
		# True hub center of the tail rotor is at (0.4265, 2.0284, 4.5367)
		var tail_hub := Vector3(0.4265, 2.0284, 4.5367)
		var tail_piv := Node3D.new()
		tail_piv.name = "rotor_tail_pivot"
		lp.add_child(tail_piv)
		tail_piv.position = tail_hub
		ra.owner = null
		ra.reparent(tail_piv, false)
		ra.position = -tail_hub
		_rotor_tail = tail_piv
	
	# Solid collision boxes (nose is +Z, tail is -Z)
	add_solid([
		[Vector3(0, 1.6, 0.2), Vector3(2.6, 2.4, 6.0)],
		[Vector3(0, 2.0, -4.5), Vector3(0.8, 0.8, 5.4)]
	])

func _physics_process(delta: float) -> void:
	# Keep yaw in sync while parked so initial rotation set after add_child is respected
	if pilot == null and not is_npc_piloted:
		yaw = rotation.y
	
	super(delta)
	
	# Rotor blade animation when pilot or NPC is riding it
	if engine > 0.001:
		var rpm := engine * 42.0
		if compound_key == "police":
			if _rotor_main != null:
				_rotor_main.rotate_object_local(Vector3.FORWARD, delta * rpm)
			if _rotor_tail != null:
				_rotor_tail.rotate_object_local(Vector3.FORWARD, delta * rpm * 1.3)
		else:
			if _rotor_main != null:
				_rotor_main.rotate_y(delta * rpm)
			if _rotor_tail != null:
				_rotor_tail.rotate_x(delta * rpm * 1.3)
