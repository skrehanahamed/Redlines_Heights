class_name FlagProjector
extends Node
## Cycles the picture of a night projector through pre-drawn frames of the Indian flag (saffron, white with the navy Ashoka Chakra,
## green) rippling like cloth. Frames are drawn once at start; the lights switch on with the night clock (CityLights).

const N := 20
const S := 192
static var _frames: Array = []
var decals: Array = []
static var override_night := -1.0   # dev/test: force the night amount (-1 = follow the clock)
var _t := 0.0

static func frames() -> Array:
	if not _frames.is_empty(): return _frames
	var saffron := Color(1.0, 0.45, 0.05)
	var white := Color(1.0, 1.0, 1.0)
	var green := Color(0.0, 0.62, 0.20)
	var navy := Color(0.05, 0.10, 0.60)
	for f in range(N):
		var ph := TAU * float(f) / float(N)
		var img := Image.create(S, S, false, Image.FORMAT_RGB8)
		for y in range(S):
			var v := float(y) / float(S - 1)
			for x in range(S):
				var u := float(x) / float(S - 1)
				# cloth ripple: the picture is displaced up and down by a travelling wave
				var vv := v + 0.018 * sin(u * 9.0 - ph) + 0.008 * sin(v * 6.0 + u * 4.0 - ph * 2.0)
				var uu := u + 0.008 * sin(v * 7.0 - ph)
				var c := Color.BLACK
				if absf(uu - 0.5) < 0.46 and vv > 0.16 and vv < 0.84:
					if vv < 0.16 + 0.68 / 3.0: c = saffron
					elif vv < 0.16 + 0.68 * 2.0 / 3.0: c = white
					else: c = green
					# Ashoka Chakra: ring, hub and 24 spokes
					var dx := uu - 0.5
					var dy := vv - 0.5
					var r := sqrt(dx * dx + dy * dy)
					if r < 0.125:
						var spokes := absf(sin(atan2(dy, dx) * 12.0)) > 0.86
						if (r > 0.100 and r < 0.125) or r < 0.022 or (spokes and r < 0.102): c = navy
				img.set_pixel(x, y, c)
		_frames.append(ImageTexture.create_from_image(img))
	return _frames

func _process(delta: float) -> void:
	var night := override_night
	if night < 0.0:
		var wx := Game.weather as Weather
		night = wx.night_amount() if wx != null else 0.0
	var on := night > 0.05
	_t += delta
	var tex: Texture2D = null
	if on: tex = frames()[int(_t * 10.0) % frames().size()]
	for d in decals:
		if not is_instance_valid(d): continue
		(d as Decal).visible = on
		if on:
			(d as Decal).texture_emission = tex
			(d as Decal).emission_energy = night * 1.7
