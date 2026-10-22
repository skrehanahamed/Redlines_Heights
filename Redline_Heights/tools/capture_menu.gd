extends SceneTree

func _init():
	var menu_scene = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu_scene)
	for i in range(10):
		await process_frame
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("../media/screenshots/main_screen.png")
		print("SUCCESS_SAVED_MAIN_SCREEN: ", img.get_size())
	else:
		print("FAILED_GET_IMAGE")
	quit(0)
