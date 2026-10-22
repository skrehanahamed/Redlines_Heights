extends SceneTree

func _init() -> void:
	for p in ["res://assets/town/artemis_fountain.glb", "res://assets/miami/gate_fence_iron_gold_ornate_ornament.glb", "res://assets/miami/spiky_iron_fence.glb"]:
		var parts: Array = CoastProps._parts(p)
		print("Asset:", p, "Parts count:", parts.size())
		for pt in parts:
			print("  Part:", pt.name, "AABB:", pt.aabb)
	quit(0)
