class_name AudioManager
extends Node
## City ambience + a car radio playing the CC0 tracks. R changes station / toggles the radio.

const TRACKS := [
	"res://assets/audio/oga/lofi-hip-hop/lofihiphop.ogg",
	"res://assets/audio/oga/funky-hip-hop-lofi-jam/CVP701Jam.ogg",
	"res://assets/audio/oga/lofi-hip-hop-loop/LofiLoop_1.ogg",
	"res://assets/audio/oga/instrumental-hip-hop-theme/prophesy of domination (promodj.com).mp3",
	"res://assets/audio/oga/night-prowler/S31-Night Prowler.ogg",
	"res://assets/audio/oga/pressure/Pressure.ogg",
	"res://assets/audio/oga/menace/Menace.ogg",
	"res://assets/audio/oga/emptycity-background-music/EmptyCity.ogg",
	"res://assets/audio/oga/covert-operations/covert_operations.mp3",
]
var ambient: AudioStreamPlayer
var radio: Radio
var _was_in_car := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambient = AudioStreamPlayer.new()
	var st := load("res://assets/audio/oga/high-traffic-road-sounds/gatve Varniu_2.ogg") as AudioStream
	if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop = true
	ambient.stream = st
	ambient.volume_db = -20.0
	add_child(ambient)
	ambient.play()
	radio = Radio.new()
	add_child(radio)
	var ui := RadioUI.new()
	ui.radio = radio
	add_child(ui)

func _process(_dt: float) -> void:
	var in_car := Game.in_car != null
	if in_car and not _was_in_car:
		radio.play_in_car()
	elif not in_car and _was_in_car:
		radio.stop_all()
	_was_in_car = in_car
	ambient.volume_db = lerpf(ambient.volume_db, -80.0 if Game.underground else (-26.0 if in_car else -20.0), 0.08)    # no city ambience underground
