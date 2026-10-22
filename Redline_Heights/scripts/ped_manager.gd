class_name PedManager
extends Node
## Keeps ~40 pedestrians around the player, spawning on sidewalks and removing distant ones.

const TARGET := 42
var rng := RandomNumberGenerator.new()
var civ_ids: Array[String] = []
var cop_ids: Array[String] = []
var _t := 0.0

func _ready() -> void:
	rng.seed = 4242
	civ_ids = [Game.MAIN_HERO]          # until more character models are supplied everyone shares the player model
	cop_ids = [Game.COP_MODEL]
	Game.civ_pool = civ_ids
	Game.cop_pool = cop_ids
	Game.doctor_pool = ["npc_doctor"]
	Game.nurse_pool = ["npc_nurse"]
	print("peds: civilians=", civ_ids.size(), " cops=", cop_ids.size(), " doctors=", Game.doctor_pool.size(), " fire=", Game.fire_pool.size(), " beach=", Game.beach_pool.size())

## A walk along the pavement: a random run of street edges, on the right-hand side of the road.
func _route(start: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var cur := start
	var prev := -1
	var d_prev := Vector2.ZERO
	for i in range(9):
		var opts: Array = []
		for ad in CityData.adj[cur]:
			if ad.n == prev: continue
			if int(CityData.edges[ad.e][2]) != 0 and int(CityData.edges[ad.e][2]) != 3: continue
			var d := (CityData.nodes[ad.n] - CityData.nodes[cur]).normalized()
			opts.append({"n": ad.n, "d": d, "w": 3.0 if (d_prev == Vector2.ZERO or d.dot(d_prev) > 0.5) else 1.0})
		if opts.is_empty(): break
		var total := 0.0
		for o in opts: total += o.w
		var r := rng.randf() * total
		var pick: Dictionary = opts[0]
		for o in opts:
			r -= o.w
			if r <= 0.0:
				pick = o
				break
		var right := Vector2(-pick.d.y, pick.d.x)
		var p := CityData.nodes[cur] + right * 9.4
		pts.append(Vector3(p.x, 0.5, p.y))
		d_prev = pick.d
		prev = cur
		cur = pick.n
	var last := CityData.nodes[cur] + Vector2(-d_prev.y, d_prev.x) * 9.4
	pts.append(Vector3(last.x, 0.5, last.y))
	return pts

func spawn_one() -> void:
	var fp := Game.get_focus_pos()
	for attempt in range(10):
		var n := CityData.random_node_near(fp, 25.0, 150.0, rng, [0, 3])
		if n < 0: continue
		var route := _route(n)
		if route.size() < 3: continue
		var start := rng.randi() % route.size()
		var pos := route[start]
		if Vector2(pos.x - fp.x, pos.z - fp.z).length() < 20.0: continue
		var ped := Ped.new()
		get_parent().add_child(ped)
		ped.global_position = pos
		ped.setup(civ_ids[rng.randi() % civ_ids.size()], route, start, 1 if rng.randf() < 0.5 else -1)
		ped.open_route = true
		return

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.4: return
	_t = 0.0
	if Game.world == null or civ_ids.is_empty(): return
	var fp := Game.get_focus_pos()
	var peds := get_tree().get_nodes_in_group("peds")
	for p in peds:
		if (p as Node3D).global_position.distance_to(fp) > 200.0:
			p.queue_free()
	if peds.size() < TARGET:
		spawn_one()
