class_name Terrain
extends RefCounted
## The ground is built by Coast (mainland, island, beaches and sea).

static func build(w: World) -> void:
	Coast.build(w)
