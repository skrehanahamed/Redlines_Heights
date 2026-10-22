@tool
extends SceneTree

func check_spawn_orientations() -> void:
	var cb_script = load("res://scripts/city_build.gd")
	cb_script._specs()
	var specs = cb_script.specs
	
	for key in ["police", "hospital"]:
		var sp = specs[key]
		var w = float(sp.w)
		var d = float(sp.d)
		var xc = -44.0 if key == "police" else -36.0
		var cd = 18.0 if key == "police" else 15.0
		var door_dx = -5.6 if key == "police" else 0.0
		var back_t = cd + d + 0.8
		var heli_x = xc + door_dx + w * 0.5 + 16.5
		var hyaw = (-PI * 0.5) if heli_x > xc else (PI * 0.5)
		var hc_rot_y = hyaw + PI
		
		# Now check what heading the helicopter nose is facing:
		# In Chopper, the nose is what points forward during flight.
		# For police: scene was rotated 180° around Y inside HelipadChopper
		# For hospital: scene was rotated 0° around Y inside HelipadChopper
		print("\n--- ", key.to_upper(), " HELIPAD ---")
		print("Helipad position: X = ", heli_x, " (Building xc = ", xc, ")")
		print("hyaw = ", rad_to_deg(hyaw), " deg, hc.rotation.y = ", rad_to_deg(hc_rot_y), " deg")
		
		# A vehicle with rotation.y = hc_rot_y has forward vector:
		# In Godot convention, forward is -Z rotated by rotation.y:
		var godot_fwd = -Vector3(sin(hc_rot_y), 0, cos(hc_rot_y))
		# In Chopper.gd convention (line 117):
		# fwd := Vector3(sin(yaw), 0, cos(yaw))
		var chopper_fwd = Vector3(sin(hc_rot_y), 0, cos(hc_rot_y))
		print("Godot -Z rotated: ", godot_fwd)
		print("Chopper fwd vector: ", chopper_fwd)
		
		# If the building is to the LEFT (-X), then facing AWAY from building means +X!
		# If facing the yard / street (Z axis):
		# What is the compound yard layout?
	quit()

func _init() -> void:
	check_spawn_orientations()
