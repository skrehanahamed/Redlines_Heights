class_name RailAudio
extends RefCounted
## Synthesised railway sounds (no sample files needed): wheel rumble with rail clacks, the crossing bell, a station chime.

const RATE := 22050

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

static var _cache := {}

## Low rumble plus a rhythmic clack-clack, seamless loop of 2 s.
static func rumble() -> AudioStreamWAV:
	if _cache.has("rumble"): return _cache["rumble"]
	var n := RATE * 2
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	var lp2 := 0.0
	for i in range(n):
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.035
		lp2 += (lp - lp2) * 0.2
		var t := float(i) / RATE
		var hum := sin(TAU * 38.0 * t) * 0.25 + sin(TAU * 76.0 * t) * 0.1
		# a clack every 0.25 s, doubled like a bogie crossing a rail joint
		var ph := fposmod(t, 0.25)
		var clack := 0.0
		for off in [0.0, 0.045]:
			var u: float = ph - off
			if u >= 0.0: clack += exp(-u * 70.0) * sin(TAU * 520.0 * u) * 0.35
		s[i] = lp2 * 3.2 + hum + clack
	_cache["rumble"] = _wav(s, true)
	return _cache["rumble"]

## A crossing bell: a bright ding every 0.55 s, loop of 1.1 s.
static func bell() -> AudioStreamWAV:
	if _cache.has("bell"): return _cache["bell"]
	var n := int(RATE * 1.1)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var u := fposmod(t, 0.55)
		var amp := exp(-u * 7.0)
		s[i] = (sin(TAU * 1250.0 * u) * 0.6 + sin(TAU * 2510.0 * u) * 0.25 + sin(TAU * 3720.0 * u) * 0.1) * amp * 0.7
	_cache["bell"] = _wav(s, true)
	return _cache["bell"]

## Two-note station chime ("ding-dong"), played once.
static func chime() -> AudioStreamWAV:
	if _cache.has("chime"): return _cache["chime"]
	var n := int(RATE * 2.4)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var v := 0.0
		for note in [[0.0, 880.0], [0.9, 660.0]]:
			var u: float = t - note[0]
			if u >= 0.0:
				v += (sin(TAU * note[1] * u) + 0.35 * sin(TAU * note[1] * 2.0 * u)) * exp(-u * 2.6) * 0.45
		s[i] = v
	_cache["chime"] = _wav(s, false)
	return _cache["chime"]

## The door warning: three short two-tone beeps.
static func door_beep() -> AudioStreamWAV:
	if _cache.has("beep"): return _cache["beep"]
	var n := int(RATE * 1.3)
	var s := PackedFloat32Array()
	s.resize(n)
	for k in range(3):
		var t0 := 0.05 + k * 0.38
		for i in range(int(RATE * 0.22)):
			var u := float(i) / RATE
			var idx := int((t0 + u) * RATE)
			if idx < n:
				var env := minf(u / 0.01, 1.0) * minf((0.22 - u) / 0.02, 1.0)
				s[idx] = (sin(TAU * 1180.0 * u) + 0.6 * sin(TAU * 880.0 * u)) * 0.32 * env
	_cache["beep"] = _wav(s, false)
	return _cache["beep"]

static func player(parent: Node3D, stream: AudioStream, max_d: float, unit: float, db := 0.0, autoplay := false) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.max_distance = max_d
	p.unit_size = unit
	p.volume_db = db
	parent.add_child(p)
	if autoplay: p.play()
	return p
