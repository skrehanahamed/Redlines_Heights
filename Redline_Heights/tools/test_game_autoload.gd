@tool
extends SceneTree

func _init() -> void:
	# Load autoload singletons so scripts that reference Game compile cleanly
	var game_script = load("res://scripts/game.gd")
	if not Engine.has_singleton("Game"):
		# In headless tool mode, we can register or reference Game
		pass
	print("Checking if Chopper compiles...")
	var ch_script = load("res://scripts/chopper.gd")
	print("ch_script: ", ch_script)
	quit()
