class_name OceanFollower
extends Node
## Keeps the detailed wave surface centred under the camera, snapped to 4 m so the vertices do not crawl.

var target: Node3D

func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or target == null: return
	var p := cam.global_position
	target.global_position = Vector3(snappedf(p.x, 4.0), -0.55, snappedf(p.z, 4.0))
