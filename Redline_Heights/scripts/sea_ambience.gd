class_name SeaAmbience
extends Node
## Surf sound that swells when the player is near the shore or the water.

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _t := 0.0
var _vol := -60.0

func _ready() -> void:
	_a = _make("res://assets/audio/sea/wave_01.mp3")
	_b = _make("res://assets/audio/sea/wave_04.mp3")

func _make(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var st := load(path) as AudioStreamMP3
	st.loop = true
	p.stream = st
	p.volume_db = -60.0
	add_child(p)
	p.play(randf() * 2.0)
	return p

func _shore_distance(pos: Vector3) -> float:
	var best := 200.0
	for a in range(12):
		var d := Vector2.from_angle(a * TAU / 12.0)
		var r := 0.0
		while r < 200.0:
			if CityData.is_water(pos.x + d.x * r, pos.z + d.y * r):
				best = minf(best, r)
				break
			r += 10.0
	return best

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.5:
		_t = 0.0
		var fp := Game.get_focus_pos()
		var dist := 0.0 if CityData.is_water(fp.x, fp.z) else _shore_distance(fp)
		_vol = lerpf(-4.0, -60.0, clampf(dist / 180.0, 0.0, 1.0))
	_a.volume_db = lerpf(_a.volume_db, -80.0 if Game.underground else _vol, clampf(delta * 3.0, 0.0, 1.0))
	_b.volume_db = _a.volume_db - 3.0
