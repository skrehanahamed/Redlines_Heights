class_name Thrown
extends RigidBody3D
## A grenade or molotov in flight. Grenades go off after a fuse, molotovs burst on the first hit.

var item := "x_grenade"
var fuse := 2.5
var armed := false

static func launch(par: Node, id: String, from: Vector3, vel: Vector3) -> Thrown:
	var t := Thrown.new()
	t.item = id
	t.fuse = 2.5 if id == "x_grenade" else 6.0
	var made := GunShop.make_extra(id)
	if not made.is_empty():
		var n: Node3D = made.node
		var sz: Vector3 = made.bb.size
		n.scale = Vector3.ONE * (float(GunShop.extra_def(id)[6]) * 0.5 / maxf(sz.x, 0.001))
		t.add_child(n)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.1
	cs.shape = sh
	t.add_child(cs)
	t.collision_layer = 0
	t.collision_mask = 1
	t.contact_monitor = true
	t.max_contacts_reported = 4
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	t.physics_material_override = pm
	par.add_child(t)
	t.global_position = from
	t.linear_velocity = vel
	t.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	t.body_entered.connect(t._on_hit)
	return t

func _process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		_detonate()

func _on_hit(_b: Node) -> void:
	if item == "x_molotov" and armed:
		_detonate()
	armed = true

func _detonate() -> void:
	set_process(false)
	var par := get_parent()
	var at := global_position
	if item == "x_molotov":
		Blast.fire_pool(par, at, 3.2, 8.0)
	else:
		Blast.explode(par, at, 8.0, 120.0)
	queue_free()
