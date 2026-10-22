class_name Radio
extends Node
## Car radio with live Indian internet radio. Each channel has a few stream URLs (tried in turn) plus optional lookups
## in the free radio-browser.info directory; the stream is decoded by ffmpeg and played through an AudioStreamGenerator.
## Channel 0 is the old built-in lo-fi / instrumental tracks and is the fallback when there is no network or no ffmpeg.
## R: next channel   hold R: radio wheel (move the mouse, release to tune in)   the wheel's centre switches the radio off.

signal channel_changed(idx: int)
signal title_changed(text: String)

const API := "https://de1.api.radio-browser.info/json/stations/search"
const RATE := 44100
const QUEUE_MAX := 88200            # frames queued ahead (~2 s)

## name, tag line, colours (a, b), glyph, built-in streams, directory lookups [{name, country}]
const ICON_BASE := "https://onlineradiohub.com/wp-content/uploads/"
const CHANNELS := [
	{"name": "Redline FM", "tag": "LO-FI & INSTRUMENTALS", "a": "#e8321c", "b": "#5a0c08", "glyph": "RF", "style": 0, "local": true, "local_icon": "res://assets/ui/radio_redline_fm.png"},
	{"name": "Radio Mirchi Hindi", "tag": "HINDI HITS", "a": "#ff3b30", "b": "#8a0a14", "glyph": "M", "style": 1,
		"icon": ICON_BASE + "2023/05/radio-mirchi-hindi-fm.jpg",
		"urls": ["https://eu8.fastcast4u.com/proxy/clyedupq/stream", "https://stream.zeno.fm/8ty8szwpwfeuv"], "find": [{"name": "radio mirchi", "country": "IN"}]},
	{"name": "Hindi Retro", "tag": "BOLLYWOOD RETRO", "a": "#f2b630", "b": "#7a4a06", "glyph": "BG", "style": 2,
		"icon": ICON_BASE + "2023/05/mirchi-retro-hindi.jpg",
		"urls": ["https://stream.zeno.fm/v2zfmxef798uv", "https://stream.zeno.fm/rm4i9pdex3cuv"], "find": [{"name": "hindi retro", "country": "IN"}]},
	{"name": "Shuddh Desi Radio", "tag": "DESI POP & HITS", "a": "#8e3df0", "b": "#2a0a66", "glyph": "SD", "style": 3,
		"icon": ICON_BASE + "2023/08/shuddh-desi-radio.jpg",
		"urls": ["https://streamer.radio.co/se30891e37/listen", "https://www.desizoneradio.com/relay2"], "find": [{"name": "desi", "country": "IN"}]},
	{"name": "Bol Punjabi Radio", "tag": "PUNJABI & BHANGRA", "a": "#ff8a00", "b": "#7a2d00", "glyph": "PB", "style": 4,
		"icon": ICON_BASE + "2022/01/bol-punjabi.jpg",
		"urls": ["https://bolpunjabi-ekamsoftware.radioca.st/stream", "http://stream.zeno.fm/t2ekq8zsgtzuv"], "find": [{"name": "punjabi", "country": "IN"}]},
	{"name": "Big FM Tamil", "tag": "TAMIL & SOUTH", "a": "#12b886", "b": "#06433a", "glyph": "BF", "style": 5,
		"icon": ICON_BASE + "2023/02/big-fm-tamil.jpg",
		"urls": ["https://stream.zeno.fm/r2gn1pgm4qruv", "https://stream.zeno.fm/48w230kx8vzuv.aac"], "find": [{"name": "tamil", "country": "IN"}, {"name": "telugu", "country": "IN"}]},
	{"name": "Mixify Bengali Hits", "tag": "BENGALI NEW AGE", "a": "#22b8cf", "b": "#10305e", "glyph": "BN", "style": 6,
		"icon": ICON_BASE + "2023/11/mixify-radio.jpg",
		"urls": ["https://server.mixify.in/listen/bangla/radio.mp3", "https://stream.radiotreetal.com/listen", "http://stream.zeno.fm/2k6xfu1pvs8uv"], "find": [{"name": "bangla", "country": "IN"}, {"name": "bengali", "country": "IN"}]},
	{"name": "Capital FM London", "tag": "ENGLISH POP HITS", "a": "#e8321c", "b": "#5a0c08", "glyph": "CF", "style": 1,
		"icon": "https://imgs.capitalfm.com/images/573609?format=png&signature=fxgDCsRPRQMvt-WaQM8YWFAMFa8=",
		"urls": ["https://media-ssl.musicradio.com/CapitalMP3", "http://media-ice.musicradio.com/CapitalMP3"], "find": [{"name": "capital fm london", "country": "GB"}]},
	{"name": "WQHT Hot 97", "tag": "HIP-HOP & R&B", "a": "#f2b630", "b": "#3a2606", "glyph": "H97", "style": 4,
		"icon": "https://www.hot97.com/wp-content/uploads/sites/2/2024/03/cropped-hot97-site-icon.png?w=180",
		"urls": ["https://18313.live.streamtheworld.com/WQHTFMAAC.aac"], "find": [{"name": "hot 97", "country": "US"}]},
	{"name": "Radio Paradise", "tag": "ROCK & ECLECTIC", "a": "#12b886", "b": "#06433a", "glyph": "RP", "style": 5,
		"icon": "https://radioparadise.com/apple-touch-icon.png",
		"urls": ["http://stream-uk1.radioparadise.com/aac-320", "http://stream.radioparadise.com/rock-320"], "find": [{"name": "radio paradise", "country": "US"}]},
	{"name": "SomaFM Groove Salad", "tag": "CHILL & AMBIENT", "a": "#22b8cf", "b": "#10305e", "glyph": "SF", "style": 6,
		"icon": "https://somafm.com/img3/groovesalad-400.jpg",
		"urls": ["https://ice5.somafm.com/groovesalad-128-mp3", "https://ice6.somafm.com/groovesalad-128-aac"], "find": [{"name": "somafm groove salad", "country": "US"}]},
]

signal icon_ready(idx: int, tex: Texture2D)
var icons: Array = []               # Texture2D or null per channel (the stations' own logos, fetched when the game starts)

var idx := 0
var on := true
var title := ""
var _urls: Array = []               # per channel: array of stream URLs
var _player: AudioStreamPlayer
var _gen: AudioStreamGenerator
var _pb: AudioStreamGeneratorPlayback
var _local: AudioStreamPlayer
var _local_idx := 0
var _pid := -1
var _stdio: FileAccess
var _stderr: FileAccess
var _thread: Thread
var _err_thread: Thread
var _stop := false
var _mutex := Mutex.new()
var _queue := PackedVector2Array()
var _got_audio := 0.0
var _try := 0
var _tuning := false
var _ffmpeg := ""
var _volume_db := -7.0
var _http_done := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]:
		if FileAccess.file_exists(p):
			_ffmpeg = p
			break
	for c in CHANNELS:
		_urls.append((c.get("urls", []) as Array).duplicate())
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = RATE
	_gen.buffer_length = 1.0
	_player = AudioStreamPlayer.new()
	_player.stream = _gen
	_player.volume_db = _volume_db
	add_child(_player)
	_local = AudioStreamPlayer.new()
	_local.volume_db = -9.0
	_local.finished.connect(_next_local)
	add_child(_local)
	_local_idx = randi() % AudioManager.TRACKS.size()
	idx = 1 if _ffmpeg != "" else 0
	icons.resize(CHANNELS.size())
	for ci in range(CHANNELS.size()):
		if CHANNELS[ci].has("local_icon"): icons[ci] = load(CHANNELS[ci].local_icon) as Texture2D
	_load_icons()
	_lookup_directory()

## Station logos are fetched from the network (and cached in user://radio_icons) rather than shipped with the game.
func _load_icons() -> void:
	DirAccess.make_dir_recursive_absolute("user://radio_icons")
	for ci in range(CHANNELS.size()):
		var url := String(CHANNELS[ci].get("icon", ""))
		if url == "": continue
		var cache := "user://radio_icons/%d.bin" % ci
		if FileAccess.file_exists(cache):
			_set_icon(ci, FileAccess.get_file_as_bytes(cache))
		var req := HTTPRequest.new()
		req.timeout = 10.0
		add_child(req)
		req.request_completed.connect(_on_icon.bind(ci, req))
		if req.request(url) != OK:
			req.queue_free()

func _on_icon(_res: int, code: int, _h: PackedStringArray, body: PackedByteArray, ci: int, req: HTTPRequest) -> void:
	req.queue_free()
	if code != 200 or body.size() < 64: return
	if _set_icon(ci, body):
		var f := FileAccess.open("user://radio_icons/%d.bin" % ci, FileAccess.WRITE)
		if f != null:
			f.store_buffer(body)

func _set_icon(ci: int, bytes: PackedByteArray) -> bool:
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50: err = img.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8: err = img.load_jpg_from_buffer(bytes)
	elif bytes[0] == 0x52 and bytes[1] == 0x49: err = img.load_webp_from_buffer(bytes)
	if err != OK: return false
	var tex := ImageTexture.create_from_image(img)
	icons[ci] = tex
	icon_ready.emit(ci, tex)
	return true

## Adds working stations from the radio-browser directory behind each channel's own streams.
func _lookup_directory() -> void:
	for ci in range(CHANNELS.size()):
		for q in CHANNELS[ci].get("find", []):
			var req := HTTPRequest.new()
			req.timeout = 8.0
			add_child(req)
			var url := "%s?name=%s&countrycode=%s&limit=12&hidebroken=true&order=clickcount&reverse=true" % [API, String(q.name).uri_encode(), q.country]
			req.request_completed.connect(_on_directory.bind(ci, req))
			if req.request(url) != OK:
				req.queue_free()

func _on_directory(_res: int, code: int, _h: PackedStringArray, body: PackedByteArray, ci: int, req: HTTPRequest) -> void:
	req.queue_free()
	if code != 200: return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Array): return
	for s in data:
		var u := String(s.get("url_resolved", ""))
		var codec := String(s.get("codec", ""))
		if int(s.get("lastcheckok", 0)) != 1 or u == "" or u.contains(".m3u8") or not (codec in ["MP3", "AAC", "AAC+"]): continue
		if not (_urls[ci] as Array).has(u):
			(_urls[ci] as Array).append(u)
			if (_urls[ci] as Array).size() >= 8: break

func channel_count() -> int:
	return CHANNELS.size()

func channel_name(i: int) -> String:
	return CHANNELS[i].name

func play_in_car() -> void:
	if on: _tune(idx)

func stop_all() -> void:
	_kill_stream()
	_local.stop()
	_player.stop()

func next_channel() -> void:
	on = true
	_tune((idx + 1) % CHANNELS.size())

func turn_off() -> void:
	on = false
	stop_all()
	title = ""
	channel_changed.emit(-1)

func tune(i: int) -> void:
	on = true
	_tune(i)

func _tune(i: int) -> void:
	idx = i
	title = ""
	_try = 0
	stop_all()
	title_changed.emit("")
	channel_changed.emit(idx)
	if CHANNELS[idx].get("local", false) or _ffmpeg == "":
		if _ffmpeg == "" and not CHANNELS[idx].get("local", false):
			Game.message.emit("Live radio needs ffmpeg - playing the built-in tracks")
		_play_local()
	else:
		_start_stream()

func _play_local() -> void:
	_local.stream = load(AudioManager.TRACKS[_local_idx]) as AudioStream
	_local.play()

func _next_local() -> void:
	_local_idx = (_local_idx + 1) % AudioManager.TRACKS.size()
	if on and Game.in_car != null and (CHANNELS[idx].get("local", false) or _ffmpeg == ""):
		_play_local()

func _start_stream() -> void:
	var list: Array = _urls[idx]
	if list.is_empty():
		_play_local()
		return
	var url: String = list[_try % list.size()]
	var args := PackedStringArray(["-hide_banner", "-loglevel", "info", "-reconnect", "1", "-reconnect_streamed", "1", "-reconnect_delay_max", "4",
		"-i", url, "-vn", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-"])
	var r := OS.execute_with_pipe(_ffmpeg, args, false)
	if r.is_empty():
		_play_local()
		return
	_pid = int(r.pid)
	_stdio = r.stdio
	_stderr = r.stderr
	_stop = false
	_mutex.lock()
	_queue = PackedVector2Array()
	_mutex.unlock()
	_got_audio = 0.0
	_tuning = true
	_player.play()
	_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_thread = Thread.new()
	_thread.start(_read_audio)
	_err_thread = Thread.new()
	_err_thread.start(_read_info)

func _kill_stream() -> void:
	_stop = true
	if _pid > 0:
		OS.kill(_pid)
		_pid = -1
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if _err_thread != null:
		_err_thread.wait_to_finish()
		_err_thread = null
	_stdio = null
	_stderr = null
	_tuning = false

func _read_audio() -> void:
	var io := _stdio
	var pid := _pid
	while not _stop:
		_mutex.lock()
		var full := _queue.size() > QUEUE_MAX
		_mutex.unlock()
		if full:
			OS.delay_msec(20)
			continue
		var b := io.get_buffer(8192)
		if b.is_empty():
			if not OS.is_process_running(pid): break
			OS.delay_msec(10)
			continue
		var n := b.size() / 4
		var frames := PackedVector2Array()
		frames.resize(n)
		for i in range(n):
			frames[i] = Vector2(b.decode_s16(i * 4), b.decode_s16(i * 4 + 2)) / 32768.0
		_mutex.lock()
		_queue.append_array(frames)
		_mutex.unlock()

func _read_info() -> void:
	var io := _stderr
	var pid := _pid
	while not _stop:
		var line := io.get_line()
		if line == "" and io.get_error() != OK:
			if not OS.is_process_running(pid): break
			OS.delay_msec(100)
			continue
		if line.contains("StreamTitle"):
			var t := line.substr(line.find(":") + 1).strip_edges()
			call_deferred("_set_title", t)

func _set_title(t: String) -> void:
	if t == "" or t == title: return
	title = t
	title_changed.emit(t)

func _process(delta: float) -> void:
	if _pid <= 0 or _pb == null: return
	_mutex.lock()
	var avail := _pb.get_frames_available()
	var n := mini(avail, _queue.size())
	if n > 0:
		_pb.push_buffer(_queue.slice(0, n))
		_queue = _queue.slice(n)
		_got_audio += float(n) / RATE
	_mutex.unlock()
	if _tuning:
		_tune_t += delta
		if _got_audio > 0.2:
			_tuning = false
			_tune_t = 0.0
		elif _tune_t > 7.0:
			# this stream is dead or too slow: try the channel's next address
			_tune_t = 0.0
			_try += 1
			var keep := idx
			_kill_stream()
			if _try >= maxi((_urls[keep] as Array).size(), 1):
				Game.message.emit("%s is off the air - built-in tracks" % CHANNELS[keep].name)
				_play_local()
			else:
				_start_stream()
var _tune_t := 0.0

func _exit_tree() -> void:
	_kill_stream()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _pid > 0: OS.kill(_pid)
