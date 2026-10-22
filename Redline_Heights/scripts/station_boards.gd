class_name StationBoards
extends Node
## The "next train" boards of one station: the model's own boards (a picture of another town's timetable) are covered by a dark
## panel with live text, which counts down to the real trains (two lines, one per train).

var station_idx := 0
var names := ["REDLINE CENTRAL", "REDLINE AIRPORT"]
var labels: Array = []          # Label3D pairs: [line1, line2]
var _t := 0.0

## Adds a board over the model's panel: centre c (station root space), face normal sign along z.
func add_panel(root: Node3D, c: Vector3, size: Vector2) -> void:
	for face in [1.0, -1.0]:
		var holder := Node3D.new()
		holder.position = c + Vector3(0, 0, face * 0.12)
		holder.rotation.y = 0.0 if face > 0.0 else PI
		root.add_child(holder)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = size
		q.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.04, 0.05, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(0.03, 0.04, 0.04)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material_override = mat
		holder.add_child(q)
		var pair: Array = []
		for k in range(2):
			var l := Label3D.new()
			l.text = ""
			l.font_size = 64
			l.pixel_size = size.x / 2350.0
			l.modulate = Color(1.0, 0.86, 0.1)
			l.outline_size = 0
			l.shaded = false
			l.no_depth_test = false
			l.position = Vector3(0, size.y * (0.22 if k == 0 else -0.22), 0.01)
			holder.add_child(l)
			pair.append(l)
		labels.append(pair)

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0: return
	_t = 1.0
	var trains: Array = []
	for t in get_tree().get_nodes_in_group("trains"):
		trains.append(t)
	trains.sort_custom(func(a, b): return a.index < b.index)
	var dest: String = names[1 - station_idx]
	var lines: Array = ["", ""]
	for k in range(mini(2, trains.size())):
		var secs: float = (trains[k] as Train).seconds_until(station_idx)
		var txt := "BOARDING" if secs < 1.0 else ("%d min" % maxi(1, int(ceil(secs / 60.0))))
		lines[k] = "%s  >  %s  :  %s" % [names[station_idx], dest, txt] if k == 0 else "%s  >  %s  :  %s" % [names[station_idx], dest, txt]
	for pair in labels:
		(pair[0] as Label3D).text = lines[0]
		(pair[1] as Label3D).text = lines[1]
