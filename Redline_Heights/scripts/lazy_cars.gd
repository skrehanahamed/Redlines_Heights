class_name LazyCars
extends Node
## Parked cars that are only built when the player is near (a Car takes ~0.7 s to set up, so a block full of them made the loading screen long).
## add() registers a car spot; this node spawns it within `radius` of the player and removes it again when the player is far away and nobody touched it.

static var _inst: LazyCars = null
var _spots: Array = []          # {kind, pos, yaw, node}
var _t := 0.0
const RADIUS := 320.0

static func _mgr(w: World) -> LazyCars:
	if _inst == null or not is_instance_valid(_inst):
		_inst = LazyCars.new()
		_inst.name = "LazyCars"
		w.add_child(_inst)
	return _inst

static func add(w: World, kind: String, pos: Vector3, yaw: float) -> void:
	_mgr(w)._spots.append({"kind": kind, "pos": pos, "yaw": yaw, "node": null})

## A GolfNpc (club / district character) that is built only when the player comes near.
## An unrigged standing figure (path to a glb, scaled to `height`) with a capsule collider; built when the player is near.
static func add_figure(w: World, path: String, height: float, pos: Vector3, yaw: float) -> void:
	_mgr(w)._spots.append({"kind": "fig", "path": path, "height": height, "pos": pos, "yaw": yaw, "node": null, "world": w})

static func add_npc(w: World, id: String, pos: Vector3, yaw: float, clip: String, route: Array = []) -> void:
	_mgr(w)._spots.append({"kind": "npc", "id": id, "pos": pos, "yaw": yaw, "clip": clip, "route": route, "node": null, "world": w})

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5: return
	_t = 0.0
	var fp: Vector3 = Game.get_focus_pos()
	var built := 0
	for sp in _spots:
		var pos: Vector3 = sp.pos
		var d := Vector2(pos.x - fp.x, pos.z - fp.z).length()
		if sp.kind == "fig":
			var fn = sp.node
			if fn != null and not is_instance_valid(fn):
				sp.node = null
				fn = null
			if fn == null and d < RADIUS * 0.7 and built < 2:
				var fig: Node3D = Game.load_static_figure(String(sp.path), float(sp.height))
				fig.position = pos
				fig.rotation.y = float(sp.yaw)
				(sp.world as World).static_root.add_child(fig)
				var sb := StaticBody3D.new()
				sb.collision_layer = 1
				var cs := CollisionShape3D.new()
				var cap := CapsuleShape3D.new()
				cap.radius = 0.35
				cap.height = float(sp.height) * 0.95
				cs.shape = cap
				cs.position = Vector3(0, cap.height * 0.5, 0)
				sb.add_child(cs)
				fig.add_child(sb)
				sp.node = fig
				built += 1
			elif fn != null and d > RADIUS * 1.4:
				fn.queue_free()
				sp.node = null
			continue
		if sp.kind == "npc":
			var nn = sp.node
			if nn != null and not is_instance_valid(nn):
				sp.node = null
				nn = null
			if nn == null and d < RADIUS * 0.7 and built < 2:
				sp.node = GolfNpc.make(sp.world, String(sp.id), pos, float(sp.yaw), String(sp.clip), sp.route)
				built += 1
			elif nn != null and d > RADIUS * 1.4 and Vector2(nn.position.x - pos.x, nn.position.z - pos.z).length() < 40.0:
				nn.queue_free()
				sp.node = null
			continue
		var n: Car = sp.node
		if n != null and not is_instance_valid(n):
			sp.node = null
			n = null
		if n == null:
			if d < RADIUS and built < 1:
				var car := Car.new()
				car.position = pos
				car.rotation.y = float(sp.yaw)
				add_child(car)
				car.setup(String(sp.kind), "", true)
				sp.node = car
				built += 1
		elif d > RADIUS * 1.7 and not n.player_controlled and n.global_position.distance_to(pos) < 2.0:
			n.queue_free()
			sp.node = null
