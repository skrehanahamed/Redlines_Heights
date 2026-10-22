class_name GunHold
extends RefCounted
## Keeps the pistol's barrel (+Z) pointing where the character aims, gripped at the right-hand bone.

static func orient(pistol: Node3D, hand: Node3D, facing: Vector3, pitch_up: float) -> void:
	var aim := facing.normalized()
	var right := aim.cross(Vector3.UP).normalized()
	aim = aim.rotated(right, pitch_up).normalized()
	var basis := Basis.looking_at(-aim, Vector3.UP)
	var pos := hand.global_position + aim * 0.07 + Vector3.DOWN * 0.03
	pistol.global_transform = Transform3D(basis, pos)
