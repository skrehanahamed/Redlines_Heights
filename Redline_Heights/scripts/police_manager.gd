class_name PoliceManager
extends Node
## Spawns police cars that chase the player according to the wanted level.

var rng := RandomNumberGenerator.new()
var _t := 0.0
var _lose_t := 0.0

func _ready() -> void:
	rng.seed = 1312

func desired_count() -> int:
	return mini(Game.wanted, 5) if Game.wanted > 0 else 0

func spawn_police() -> void:
	var fp := Game.get_focus_pos()
	for attempt in range(12):
		var n := CityData.random_node_near(fp, 80.0, 170.0, rng, [0, 1, 3])
		if n < 0: continue
		var adjs: Array = CityData.adj[n]
		if adjs.is_empty(): continue
		var ad: Dictionary = adjs[rng.randi() % adjs.size()]
		var pa := CityData.nodes[n]
		var pb := CityData.nodes[ad.n]
		var d := (pb - pa).normalized()
		var p := pa + d * 6.0 + Vector2(-d.y, d.x) * 3.0
		var car := Car.new()
		get_parent().add_child(car)
		car.global_position = Vector3(p.x, 1.0, p.y)
		car.rotation.y = atan2(d.x, d.y)
		car.setup("police", "", false)
		car.make_police()
		return

func police_cars() -> Array:
	return get_tree().get_nodes_in_group("police")

func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0: return
	_t = 0.0
	if Game.world == null or Game.dead: return
	var cops := police_cars()
	var want := desired_count()
	var fp := Game.get_focus_pos()
	if want > cops.size():
		spawn_police()
	elif want == 0:
		for c in cops:
			(c as Car).ai_chase = false
			(c as Car).remove_from_group("police")
			c.add_to_group("cars")
	_manage_helis()
	for c in cops:
		if (c as Node3D).global_position.distance_to(fp) > 320.0:
			c.queue_free()
	# wanted level decays only when no police is close
	if Game.wanted > 0:
		var close := false
		for c in cops:
			if (c as Node3D).global_position.distance_to(fp) < 55.0: close = true
		if close:
			Game.wanted_timer = 25.0
		else:
			Game.wanted_timer -= 1.0
			if Game.wanted_timer <= 0.0:
				Game.wanted = Game.wanted - 1
				Game.message.emit("Wanted level lowered")

## From 4 stars on, police helicopters join the hunt (one at 4-5 stars, two at 6) and hunt the player from the air.
func _manage_helis() -> void:
	if not ResourceLoader.exists("res://assets/vehicles/heli/md500.glb"): return
	var want := 0
	if Game.wanted >= 6: want = 2
	elif Game.wanted >= 4: want = 1
	var helis := get_tree().get_nodes_in_group("heli")
	if helis.size() < want:
		var h := PoliceHeli.new()
		get_parent().add_child(h)
		var fp := Game.get_focus_pos()
		var a := rng.randf() * TAU
		h.global_position = Vector3(fp.x + cos(a) * 420.0, 70.0, fp.z + sin(a) * 420.0)
	elif helis.size() > want:
		for h in helis:
			if (h as PoliceHeli).state != "leaving":
				(h as PoliceHeli).leave()
				break
