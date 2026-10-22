extends SceneTree

func _init() -> void:
	for p in ["res://assets/town/artemis_fountain.glb", "res://assets/miami/gate_fence_iron_gold_ornate_ornament.glb", "res://assets/miami/spiky_iron_fence.glb"]:
		var s := load(p) as PackedScene
		if s == null:
			print("Failed to load: ", p)
			continue
		var inst := s.instantiate() as Node3D
		print("\n=== ASSET: ", p, " ===")
		for c in inst.find_children("*", "MeshInstance3D"):
			var mi := c as MeshInstance3D
			if mi.mesh:
				var aabb := mi.mesh.get_aabb()
				print("  MeshNode: ", mi.name, " AABB: ", aabb)
				for i in range(mi.mesh.get_surface_count()):
					var m := mi.mesh.surface_get_material(i)
					var tname: String = "none"
					if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
						tname = (m as BaseMaterial3D).albedo_texture.resource_path
					print("    Surface ", i, " Mat: ", (m.resource_name if m != null else "null"), " AlbTex: ", tname)
	quit(0)



