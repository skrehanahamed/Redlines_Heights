class_name TrafficManager
extends Node
## Spawns and removes AI traffic around the player; the cars follow the road graph (streets, avenues, highways, bridge).

const TARGET := 36
var rng := RandomNumberGenerator.new()
var kinds := ["saloon", "wagon", "hatch", "van", "taxi", "old", "box"]
var service := ["ambulance", "firetruck"]
var _t := 0.0

func _ready() -> void:
	rng.seed = 99

func spawn_one() -> void:
	var fp := Game.get_focus_pos()
	for attempt in range(14):
		var n := CityData.random_node_near(fp, 70.0, 210.0, rng)
		if n < 0: return
		var adjs: Array = CityData.adj[n]
		if adjs.is_empty(): continue
		var ad: Dictionary = adjs[rng.randi() % adjs.size()]
		var pa := CityData.nodes[n]
		var pb := CityData.nodes[ad.n]
		var length := pa.distance_to(pb)
		if length < 20.0: continue
		var dist := rng.randf_range(length * 0.2, length * 0.8)
		var p := pa + (pb - pa) / length * dist
		# not on top of another car
		var clash := false
		for o in get_tree().get_nodes_in_group("traffic"):
			var q := (o as Node3D).global_position
			if Vector2(q.x - p.x, q.z - p.y).length() < 14.0: clash = true
		if clash: continue
		var kind: String = service[rng.randi() % service.size()] if rng.randf() < 0.08 else kinds[rng.randi() % kinds.size()]
		var tc := TrafficCar.new()
		get_parent().add_child(tc)
		tc.setup(kind, "")
		tc.place_on(n, ad.n, dist)
		return

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5: return
	_t = 0.0
	if Game.world == null: return
	var fp := Game.get_focus_pos()
	var cars := get_tree().get_nodes_in_group("traffic")
	for c in cars:
		if (c as Node3D).global_position.distance_to(fp) > 280.0:
			c.queue_free()
	if cars.size() < TARGET:
		spawn_one()
