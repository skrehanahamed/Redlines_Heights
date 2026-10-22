class_name Population
extends Node
## Streams the island's permanent population in and out around the player: station officers, doctors, firefighters,
## beach-goers, park strollers, harbour workers, and cars parked along the streets (including police cars, ambulances
## and fire trucks at their stations). Nothing outside ~220 m of the player exists, so the big map stays fast.

const SPAWN_R := 190.0
const DESPAWN_R := 250.0
const PARKED_KINDS := ["saloon", "saloon", "wagon", "wagon", "hatch", "hatch", "van", "taxi", "old", "box", "factory_gt"]

var entries: Array = []           # {type, pos, yaw, who/kind, wander, tex, node}
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _rr := 0

func _ready() -> void:
	rng.seed = 5150
	var w: World = Game.world
	for sp in w.spawns:
		var e: Dictionary = sp.duplicate()
		e["node"] = null
		entries.append(e)
	print("population entries: ", entries.size())

func _parked_along_streets() -> void:
	for ei in range(CityData.edges.size()):
		var e: Array = CityData.edges[ei]
		if int(e[2]) != 0 and int(e[2]) != 3: continue
		var pa := CityData.nodes[int(e[0])]
		var pb := CityData.nodes[int(e[1])]
		var length := pa.distance_to(pb)
		if length < 50.0: continue
		var d := (pb - pa) / length
		var right := Vector2(-d.y, d.x)
		for side in [-1.0, 1.0]:
			if rng.randf() > 0.30: continue
			var dist := rng.randf_range(18.0, length - 18.0)
			var sd: float = side
			var p: Vector2 = pa + d * dist + right * sd * 6.2
			if CityData.is_water(p.x, p.y): continue
			var kind: String = PARKED_KINDS[rng.randi() % PARKED_KINDS.size()]
			var def: Dictionary = Car.DEFS[kind]
			var tex: String = def.tex[rng.randi() % def.tex.size()]
			var yaw := atan2(d.x, d.y) + (0.0 if side > 0.0 else PI)
			entries.append({"type": "car", "kind": kind, "tex": tex, "pos": Vector3(p.x, 0.8, p.y), "yaw": yaw, "node": null})

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.25: return
	_t = 0.0
	var fp := Game.get_focus_pos()
	var spawned := 0
	# walk through a slice of the list each tick
	var n := entries.size()
	if n == 0: return
	var slice := 400
	for k in range(mini(slice, n)):
		_rr = (_rr + 1) % n
		var e: Dictionary = entries[_rr]
		var d := Vector2(e.pos.x - fp.x, e.pos.z - fp.z).length()
		var alive: bool = e.node != null and is_instance_valid(e.node)
		if not alive:
			e.node = null
			if d < SPAWN_R and spawned < 2:
				_spawn(e)
				spawned += 1
		elif d > DESPAWN_R:
			# never remove a car the player is using or that is being chased in
			if e.node == Game.in_car: continue
			e.node.queue_free()
			e.node = null

func _spawn(e: Dictionary) -> void:
	var w: World = Game.world
	if e.type == "car":
		var car := Car.new()
		get_parent().add_child(car)
		car.global_position = e.pos
		car.rotation.y = e.yaw
		car.setup(e.kind, e.get("tex", ""), true)
		e.node = car
		return
	if e.type == "static":
		var fig: Node3D = Game.load_static_figure(String(e.path), float(e.get("height", 1.82)))
		get_parent().add_child(fig)
		var sy := maxf(CityData.height_at(e.pos.x, e.pos.z), 0.0)
		fig.global_position = Vector3(e.pos.x, sy, e.pos.z)
		fig.rotation.y = float(e.get("yaw", 0.0))
		e.node = fig
		return
	# an NPC
	var pool: Array = Game.civ_pool
	match String(e.get("who", "civ")):
		"cop": pool = Game.cop_pool
		"doctor": pool = Game.doctor_pool
		"nurse": pool = Game.nurse_pool
		"fire": pool = Game.fire_pool
		_:
			var z := CityData.zone_at(e.pos.x, e.pos.z)
			if (z == CityData.Z_BEACH or z == CityData.Z_PARK) and not Game.beach_pool.is_empty() and rng.randf() < 0.6:
				pool = Game.beach_pool
	if pool.is_empty():
		pool = Game.civ_pool
	if pool.is_empty(): return
	var ped := Ped.new()
	get_parent().add_child(ped)
	var gy := maxf(CityData.height_at(e.pos.x, e.pos.z), 0.0)
	ped.global_position = Vector3(e.pos.x, gy + 0.5, e.pos.z)
	var wander: float = e.get("wander", 6.0)
	var route: Array[Vector3] = []
	var cur := Vector3(e.pos.x, gy + 0.5, e.pos.z)
	route.append(cur)
	for i in range(3):
		var off := Vector3(rng.randf_range(-wander, wander), 0.0, rng.randf_range(-wander, wander))
		var q := cur + off
		if CityData.is_water(q.x, q.z): q = cur
		route.append(Vector3(q.x, maxf(CityData.height_at(q.x, q.z), 0.0) + 0.5, q.z))
	ped.setup(pool[rng.randi() % pool.size()], route, 0, 1)
	ped.open_route = true
	ped.walk_speed *= 0.6
	e.node = ped
