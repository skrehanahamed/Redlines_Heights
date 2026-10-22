extends Node
## Renders a straight-down picture of Redline Island with numbered blocks 1-8 (dev tool, output /tmp/rh_island/block_map.png).
## Layout: image-left = world east, bridge at the bottom. Row B (north) = 1-4 along the top... see the printed legend.

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh_island")
	Game.reset_state()
	var world := World.new()
	world.name = "World"
	add_child(world)
	Game.world = world
	await world.build()
	await get_tree().process_frame
	var xs := [-200.0, 0.0, 200.0, 400.0, 600.0]
	var zs := [1950.0, 2200.0, 2450.0]
	var n := 1
	# numbered like reading the picture: top row left to right (south row, east to west), then the bottom row
	for row in [1, 0]:
		for col in [3, 2, 1, 0]:
			var cx: float = (xs[col] + xs[col + 1]) * 0.5
			var cz: float = (zs[row] + zs[row + 1]) * 0.5
			var l := Label3D.new()
			l.text = str(n)
			l.font_size = 256
			l.pixel_size = 0.9
			l.modulate = Color(1, 0.95, 0.2)
			l.outline_size = 48
			l.outline_modulate = Color(0, 0, 0)
			l.no_depth_test = true
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = Vector3(cx, 40.0, cz)
			add_child(l)
			print("BLOCK ", n, " x ", xs[col], "..", xs[col + 1], "  z ", zs[row], "..", zs[row + 1])
			n += 1
	var cam := Camera3D.new()
	cam.far = 30000.0
	cam.fov = 40
	add_child(cam)
	cam.look_at_from_position(Vector3(200.0, 1100.0, 2200.0), Vector3(200.0, 0.0, 2200.0), Vector3(0, 0, 1))
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/rh_island/block_map.png")
	get_tree().quit()
