extends SceneTree

func _init():
	var game_script = load("res://scripts/game.gd")
	var game_node = Node.new()
	game_node.set_script(game_script)
	root.add_child(game_node)
	var player_script = load("res://scripts/player.gd")
	var player = CharacterBody3D.new()
	player.set_script(player_script)
	root.add_child(player)
	print("Player initialized. Weapon: ", player.weapon, " Aiming: ", player.aiming)
	quit()
