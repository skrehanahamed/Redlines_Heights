class_name Rules
extends Node
## Death ("wasted") and respawn. There is no arrest: the police keep shooting until the player is dead.

var hud: HUD
var respawn_point := Vector3(6.0, 0.7, 14.0)

func _process(delta: float) -> void:
	if Game.dead:
		return
	if Game.health <= 0.0:
		_die()
		return

func _die() -> void:
	Game.dead = true
	hud.show_banner("banner_dead", 4.0)
	var pl := Game.player as Player
	if pl.in_heli != null:
		pl.in_heli.try_exit(true)
	if Game.in_car != null:
		pl._exit_car()
	pl.play("Death01", 1.0, 0.05)
	await get_tree().create_timer(4.2).timeout
	_respawn(100)

func _respawn(fine: int) -> void:
	var pl := Game.player as Player
	if Game.in_car != null:
		Game.in_car.exit_car()
		pl.visible = true
		pl.shape.disabled = false
	Game.money -= fine
	Game.health = 100.0
	Game.wanted = 0
	pl.global_position = respawn_point
	pl.velocity = Vector3.ZERO
	pl.cur_anim = ""
	Game.dead = false
	for c in get_tree().get_nodes_in_group("cops"):
		c.queue_free()
	for c in get_tree().get_nodes_in_group("police"):
		(c as Car).ai_chase = false
		c.remove_from_group("police")
		c.queue_free()
	Game.message.emit("Fined $%d" % fine)
