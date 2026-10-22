class_name Weather
extends Node
## Day / night cycle, lunar phases (incl. a blood moon) and dynamic weather: clear, cloudy, overcast, windy, foggy, drizzle, rain, thunderstorm, sandstorm, snow, heat wave.
## Clock: a full day lasts DAY_SECONDS of real time. Keys: N skips two hours, B changes the weather.

const DAY_SECONDS := 1200.0
const STATES := ["clear", "cloudy", "overcast", "windy", "foggy", "drizzle", "rain", "storm", "sandstorm", "snow", "heatwave"]
const STATE_NAMES := {"clear": "Clear", "cloudy": "Cloudy", "overcast": "Overcast", "windy": "Windy", "foggy": "Foggy", "drizzle": "Drizzle", "rain": "Rain", "storm": "Thunderstorm", "sandstorm": "Sandstorm", "snow": "Snow", "heatwave": "Heat Wave"}
## target values per weather: cloud cover, rain, storm (darkness + lightning), fog, wind, dust, snow, warm (heat tint)
const TABLE := {
	"clear": {"cloud": 0.0, "rain": 0.0, "storm": 0.0, "fog": 0.0, "wind": 0.15, "dust": 0.0, "snow": 0.0, "warm": 0.0},
	"cloudy": {"cloud": 0.55, "rain": 0.0, "storm": 0.05, "fog": 0.0, "wind": 0.3, "dust": 0.0, "snow": 0.0, "warm": 0.0},
	"overcast": {"cloud": 1.0, "rain": 0.0, "storm": 0.3, "fog": 0.05, "wind": 0.25, "dust": 0.0, "snow": 0.0, "warm": 0.0},
	"windy": {"cloud": 0.45, "rain": 0.0, "storm": 0.05, "fog": 0.0, "wind": 1.0, "dust": 0.0, "snow": 0.0, "warm": 0.0},
	"foggy": {"cloud": 0.7, "rain": 0.0, "storm": 0.12, "fog": 1.0, "wind": 0.04, "dust": 0.0, "snow": 0.0, "warm": 0.0},
	"drizzle": {"cloud": 0.85, "rain": 0.25, "storm": 0.3, "fog": 0.18, "wind": 0.25, "dust": 0.0, "snow": 0.0, "warm": 0.0},
	"rain": {"cloud": 0.95, "rain": 0.75, "storm": 0.55, "fog": 0.12, "wind": 0.5, "dust": 0.0, "snow": 0.0, "warm": 0.0},
	"storm": {"cloud": 1.0, "rain": 1.0, "storm": 1.0, "fog": 0.1, "wind": 1.0, "dust": 0.0, "snow": 0.0, "warm": 0.0},
	"sandstorm": {"cloud": 0.25, "rain": 0.0, "storm": 0.1, "fog": 0.0, "wind": 1.0, "dust": 1.0, "snow": 0.0, "warm": 0.5},
	"snow": {"cloud": 0.9, "rain": 0.0, "storm": 0.3, "fog": 0.3, "wind": 0.3, "dust": 0.0, "snow": 1.0, "warm": 0.0},
	"heatwave": {"cloud": 0.0, "rain": 0.0, "storm": 0.0, "fog": 0.0, "wind": 0.08, "dust": 0.0, "snow": 0.0, "warm": 1.0},
}
## chance of each weather coming next
const ODDS := {"clear": 0.26, "cloudy": 0.2, "overcast": 0.09, "windy": 0.08, "foggy": 0.07, "drizzle": 0.08, "rain": 0.08, "storm": 0.05, "sandstorm": 0.03, "snow": 0.02, "heatwave": 0.04}
const MOON_NAMES := ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]
const MOON_CYCLE_DAYS := 8.0

var hour := 9.0                       # 0..24
var state := "clear"
var rain := 0.0                       # smoothed 0..1
var storm := 0.0
var cloud := 0.0
var fog := 0.0
var wind := 0.15
var dust := 0.0
var snow := 0.0
var warm := 0.0
var moon_day := 3                     # whole days elapsed on the lunar calendar
var moon_phase := 0.4                 # 0 new .. 0.5 full .. 1 new
var moon_red := 0.0
var moon_force := -1.0                # >=0 pins the phase (debug)
var _gust := 0.0
var _cloud_pos := Vector2.ZERO
var _wind_ang := 0.6
var _gust_cd := 6.0
var _target: Dictionary = TABLE["clear"]
var _change_t := 100.0
var _flash := 0.0
var _next_strike := 8.0
var _world: World
var _sky: ShaderMaterial
var _rain_fx: CPUParticles3D
var _splash_fx: CPUParticles3D
var _rain_snd: AudioStreamPlayer
var _wind_snd: AudioStreamPlayer
var _bolt: MeshInstance3D
var _lights_cd := 0.0
var _moon: DirectionalLight3D
var _snow_fx: CPUParticles3D
var _dust_fx: CPUParticles3D
var _howl_snd: AudioStreamPlayer
var _blizzard_snd: AudioStreamPlayer

func _ready() -> void:
	_world = Game.world
	_sky = _world.env.sky.sky_material as ShaderMaterial
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("#8fa8e0")
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_moon)
	_world.sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_sky.set_shader_parameter("moon_tex", load("res://assets/textures/moon_nasa.png"))
	_make_rain()
	_make_snow()
	_make_dust()
	_howl_snd = _loop("res://assets/audio/weather/wind_howl_loop.ogg")
	_blizzard_snd = _loop("res://assets/audio/weather/blizzard_loop.ogg")
	_rain_snd = _loop("res://assets/audio/weather/rain_light_loop.ogg")
	_wind_snd = _loop("res://assets/audio/weather/wind_steady_loop.ogg")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hour="): hour = float(a.substr(7))
		if a.begins_with("--weather="): set_weather(a.substr(10), true)
		if a.begins_with("--moon="):
			var mv := a.substr(7).split(",")
			moon_force = float(mv[0])
			if mv.size() > 1: moon_red = float(mv[1])
	_apply(1.0)

func _loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var st := load(path) as AudioStream
	if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop = true
	p.stream = st
	p.volume_db = -60.0
	add_child(p)
	p.play()
	return p

func _make_rain() -> void:
	_rain_fx = CPUParticles3D.new()
	_rain_fx.amount = 2600
	_rain_fx.lifetime = 0.9
	_rain_fx.preprocess = 1.0
	_rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain_fx.emission_box_extents = Vector3(28, 0.5, 28)
	_rain_fx.direction = Vector3(0.15, -1, 0.05)
	_rain_fx.spread = 3.0
	_rain_fx.initial_velocity_min = 26.0
	_rain_fx.initial_velocity_max = 32.0
	_rain_fx.gravity = Vector3(0, -6, 0)
	_rain_fx.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.025, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.88, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	qm.material = mat
	_rain_fx.mesh = qm
	_rain_fx.emitting = false
	_rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain_fx)

func _soft_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _make_snow() -> void:
	_snow_fx = CPUParticles3D.new()
	_snow_fx.amount = 3200
	_snow_fx.lifetime = 8.0
	_snow_fx.preprocess = 8.0
	_snow_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow_fx.emission_box_extents = Vector3(30, 0.5, 30)
	_snow_fx.direction = Vector3(0.1, -1, 0)
	_snow_fx.spread = 18.0
	_snow_fx.initial_velocity_min = 1.3
	_snow_fx.initial_velocity_max = 2.3
	_snow_fx.gravity = Vector3.ZERO
	_snow_fx.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.13, 0.13)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.9)
	mat.albedo_texture = _soft_tex()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	_snow_fx.mesh = qm
	_snow_fx.emitting = false
	_snow_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_snow_fx)

func _make_dust() -> void:
	_dust_fx = CPUParticles3D.new()
	_dust_fx.amount = 900
	_dust_fx.lifetime = 2.2
	_dust_fx.preprocess = 2.0
	_dust_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust_fx.emission_box_extents = Vector3(32, 4, 32)
	_dust_fx.direction = Vector3(1, 0.03, 0.2)
	_dust_fx.spread = 6.0
	_dust_fx.initial_velocity_min = 16.0
	_dust_fx.initial_velocity_max = 26.0
	_dust_fx.gravity = Vector3.ZERO
	_dust_fx.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(2.6, 1.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.38, 0.1)
	mat.albedo_texture = _soft_tex()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	_dust_fx.mesh = qm
	_dust_fx.emitting = false
	_dust_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust_fx)

func set_weather(w: String, instant := false) -> void:
	state = w
	_target = TABLE[w]
	if instant:
		_snap()
	_change_t = randf_range(120.0, 260.0)
	Game.message.emit("Weather: %s" % STATE_NAMES[w])

func _snap() -> void:
	rain = _target.rain
	storm = _target.storm
	cloud = _target.cloud
	fog = _target.fog
	wind = _target.wind
	dust = _target.dust
	snow = _target.snow
	warm = _target.warm

func _pick_next() -> String:
	var roll := randf()
	var acc := 0.0
	for k in ODDS:
		if k == state: continue
		acc += ODDS[k]
		if roll * (1.0 - ODDS.get(state, 0.0)) < acc:
			return k
	return "clear"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weather_next"):
		set_weather(STATES[(STATES.find(state) + 1) % STATES.size()])
	elif event.is_action_pressed("time_skip"):
		hour = fmod(hour + 2.0, 24.0)
		Game.message.emit("Time: %s" % clock_text())
	elif event.is_action_pressed("moon_next"):
		moon_day += 1
		Game.message.emit("Moon: %s" % moon_text())

func moon_text() -> String:
	var n: String = MOON_NAMES[int(round(moon_phase * 8.0)) % 8]
	return n + (" - Blood Moon" if moon_red > 0.5 else "")

func clock_text() -> String:
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0)
	return "%02d:%02d" % [h, m]

## 0 at midday, 1 deep night.
func night_amount() -> float:
	# sun elevation from the clock: noon = +1, midnight = -1
	var e := -cos((hour - 0.0) / 24.0 * TAU)
	return clampf(smoothstep(0.2, -0.25, e), 0.0, 1.0)

func is_night() -> bool:
	return night_amount() > 0.55

func _process(delta: float) -> void:
	var prev := hour
	hour = fmod(hour + delta * 24.0 / DAY_SECONDS, 24.0)
	if hour < prev: moon_day += 1
	_change_t -= delta
	if _change_t <= 0.0:
		set_weather(_pick_next())
	rain = move_toward(rain, _target.rain, delta * 0.12)
	storm = move_toward(storm, _target.storm, delta * 0.12)
	cloud = move_toward(cloud, _target.cloud, delta * 0.03)
	fog = move_toward(fog, _target.fog, delta * 0.06)
	wind = move_toward(wind, _target.wind, delta * 0.1)
	dust = move_toward(dust, _target.dust, delta * 0.1)
	snow = move_toward(snow, _target.snow, delta * 0.1)
	warm = move_toward(warm, _target.warm, delta * 0.05)
	_wind_ang += delta * 0.015
	var t := Time.get_ticks_msec() * 0.001
	_gust = wind * (0.65 + 0.35 * sin(t * 0.7) * sin(t * 0.23 + 1.0))
	_apply(delta)
	_lightning(delta)
	_auto_lights(delta)
	_gusts(delta)

func _gusts(delta: float) -> void:
	if wind < 0.55: return
	_gust_cd -= delta
	if _gust_cd > 0.0: return
	_gust_cd = randf_range(5.0, 12.0) / wind
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/weather/gust_01.ogg") as AudioStream
	p.volume_db = lerpf(-16.0, -4.0, wind)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _apply(delta: float) -> void:
	var elev := -cos(hour / 24.0 * TAU)                      # +1 noon, -1 midnight
	var night := night_amount()
	var dusk := clampf(1.0 - absf(elev) * 3.5, 0.0, 1.0)
	# sun travels east -> west across the southern sky
	var ang := hour / 24.0 * TAU
	var sun_dir := Vector3(sin(ang) * 0.9, -cos(ang), 0.45).normalized()    # direction towards the sun
	_world.sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	var day_f := 1.0 - night
	var murk := clampf(storm * 0.65 + fog * 0.45 + dust * 0.55 + cloud * 0.18 + snow * 0.2, 0.0, 0.92)
	_world.sun.light_energy = lerpf(0.0, 1.35, day_f) * (1.0 - murk) * (1.0 + warm * 0.12)
	_world.sun.light_color = Color("#fff0d0").lerp(Color("#ff9a55"), dusk * 0.8).lerp(Color("#ffd27a"), warm * 0.5).lerp(Color("#e0a860"), dust * 0.6)
	_world.sun.shadow_enabled = _world.sun.light_energy > 0.15
	if Game.underground:
		_world.sun.light_energy = 0.0                 # no sun in the metro: it would light the tunnel through the ground and cast shadows there
		_world.sun.shadow_enabled = false
	# ---- the moon: lunar calendar, phases, size and the blood moon
	var lunar := (moon_force * MOON_CYCLE_DAYS) if moon_force >= 0.0 else (float(moon_day) + hour / 24.0)
	var cyc := floori(lunar / MOON_CYCLE_DAYS)
	moon_phase = moon_force if moon_force >= 0.0 else fposmod(lunar / MOON_CYCLE_DAYS, 1.0)
	if moon_force < 0.0:
		moon_red = smoothstep(0.07, 0.035, absf(moon_phase - 0.5)) if cyc % 3 == 1 else 0.0
	var mang := ang - moon_phase * TAU
	var moon_dir := Vector3(sin(mang) * 0.9, -cos(mang), 0.45).normalized()
	var illum := 0.5 - 0.5 * cos(moon_phase * TAU)
	var mup := clampf(moon_dir.y, 0.0, 1.0)
	var m_above := smoothstep(-0.05, 0.15, moon_dir.y)
	_moon.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP if absf(moon_dir.y) < 0.99 else Vector3.RIGHT)
	_moon.light_color = Color("#8fa8e0").lerp(Color("#ff6a3a"), moon_red)
	_moon.light_energy = (0.05 + illum * 0.42) * m_above * lerpf(0.25, 1.0, night) * (1.0 - murk * 0.8) * lerpf(1.0, 0.8, moon_red)
	_moon.light_specular = 1.6
	_moon.shadow_enabled = _moon.light_energy > 0.14
	if Game.underground:
		_moon.light_energy = 0.0
		_moon.shadow_enabled = false
	var size := 0.068 * (1.0 + 0.32 * (1.0 - mup)) * (1.0 + 0.16 * cos(lunar * TAU / 6.5)) * (1.0 + moon_red * 0.14)
	var env := _world.env
	var moon_amb := (0.1 + illum * 0.22) * m_above
	env.ambient_light_energy = (lerpf(0.12 + moon_amb, 0.9, day_f) * (1.0 - storm * 0.3) - fog * 0.12) + (0.0 if Game.underground else _flash * 0.8)
	env.ambient_light_energy = maxf(env.ambient_light_energy, 0.08)
	# fog / dust veil (no permanent haze: clear weather has none)
	var fog_day := Color(0.78, 0.81, 0.85).lerp(Color(0.42, 0.45, 0.5), storm).lerp(Color(0.86, 0.9, 0.95), snow)
	fog_day = fog_day.lerp(Color(0.8, 0.6, 0.36), clampf(dust, 0.0, 1.0)).lerp(Color(1.0, 0.72, 0.5), dusk * 0.4)
	var light_k := lerpf(0.05 + illum * 0.09, 1.0, day_f)
	var fog_col := Color(fog_day.r * light_k, fog_day.g * light_k, fog_day.b * light_k * 1.04 + (1.0 - day_f) * 0.015)
	var veil := clampf(fog * 0.95 + dust * 0.9 + snow * 0.25, 0.0, 1.0)
	env.fog_enabled = veil > 0.01 or rain > 0.05 or storm > 0.3
	env.fog_light_color = fog_col
	env.fog_density = fog * 0.011 + dust * 0.0085 + snow * 0.0025 + rain * 0.0012 + storm * 0.0009
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = clampf(fog * 0.5 + dust * 0.25, 0.0, 1.0) * day_f
	env.tonemap_exposure = lerpf(1.0, 0.9, storm) * (1.0 + warm * 0.06)
	if _sky != null:
		_sky.set_shader_parameter("night", night)
		_sky.set_shader_parameter("dusk", dusk)
		_sky.set_shader_parameter("storm", storm)
		_sky.set_shader_parameter("flash", _flash)
		_sky.set_shader_parameter("cloud_cover", lerpf(0.30, 1.0, cloud))
		_cloud_pos += Vector2(cos(_wind_ang), sin(_wind_ang) * 0.5 + 0.35) * 0.0016 * (1.0 + _gust * 3.0 + storm) * delta
		_sky.set_shader_parameter("cloud_offset", _cloud_pos)
		_sky.set_shader_parameter("moon_dir", moon_dir)
		_sky.set_shader_parameter("sun_pos", sun_dir)
		_sky.set_shader_parameter("moon_phase", moon_phase)
		_sky.set_shader_parameter("moon_radius", size)
		_sky.set_shader_parameter("moon_red", moon_red)
		_sky.set_shader_parameter("moon_bright", lerpf(0.4, 1.0, night) * (1.0 - clampf(storm * 0.9 + fog * 0.7 + dust * 0.8, 0.0, 1.0)))
		_sky.set_shader_parameter("haze", veil)
		_sky.set_shader_parameter("haze_color", Color(fog_col.r, fog_col.g, fog_col.b))
		_sky.set_shader_parameter("heat", warm)
	if Coast.sea_mat != null:
		Coast.sea_mat.set_shader_parameter("night", night)
		Coast.sea_mat.set_shader_parameter("storm", clampf(storm + wind * 0.3, 0.0, 1.0))
		Coast.sea_mat.set_shader_parameter("rain", rain)
		for wm in Coast.extra_water_mats:
			(wm as ShaderMaterial).set_shader_parameter("rain", rain)
			(wm as ShaderMaterial).set_shader_parameter("night", night)
			(wm as ShaderMaterial).set_shader_parameter("storm", clampf(storm + wind * 0.3, 0.0, 1.0))
	# precipitation follows the camera
	var cam := get_viewport().get_camera_3d()
	var wv := Vector2(cos(_wind_ang), sin(_wind_ang)) * _gust
	if cam != null:
		_rain_fx.global_position = cam.global_position + Vector3(0, 14.0, 0)
		_snow_fx.global_position = cam.global_position + Vector3(0, 12.0, 0)
		_dust_fx.global_position = cam.global_position + Vector3(0, 3.0, 0)
	# no rain, snow or dust underground: in the metro (the stations, the tunnel, the stairwells) there is no weather
	var under := cam != null and (cam.global_position.y < -2.5 or Metro.in_stairs(cam.global_position))
	Game.underground = under
	# inside the golf clubhouse hall it is dry too: no rain, snow, dust or wind noise under its roof (the sky and light stay as they are)
	var sheltered := under or (cam != null and cam.global_position.y < 6.0 and GolfInterior.HALL.has_point(Vector2(cam.global_position.x, cam.global_position.z)))
	_rain_fx.visible = not sheltered
	_snow_fx.visible = not sheltered
	_dust_fx.visible = not sheltered
	_rain_fx.direction = Vector3(wv.x * 0.55, -1.0, wv.y * 0.55)
	_rain_fx.emitting = rain > 0.05 and not sheltered
	var want := 700 + int(rain * 2200.0) / 300 * 300
	if absi(_rain_fx.amount - want) > 300: _rain_fx.amount = want
	(_rain_fx.mesh.material as StandardMaterial3D).albedo_color.a = lerpf(0.25, 0.5, rain)
	_snow_fx.emitting = snow > 0.05 and not sheltered
	_snow_fx.direction = Vector3(wv.x * 1.4, -1.0, wv.y * 1.4)
	_dust_fx.emitting = dust > 0.05 and not sheltered
	_dust_fx.direction = Vector3(wv.x + 0.3, 0.03, wv.y + 0.2)
	_dust_fx.initial_velocity_min = 14.0 + dust * 6.0
	_dust_fx.initial_velocity_max = 22.0 + dust * 8.0
	(_dust_fx.mesh.material as StandardMaterial3D).albedo_color = Color(fog_col.r * 1.05, fog_col.g * 0.95, fog_col.b * 0.85, 0.1 * dust)
	var loud := clampf(rain * 1.2, 0.0, 1.0)
	_rain_snd.volume_db = lerpf(-60.0, -7.0, loud) if (rain > 0.02 and not sheltered) else -60.0
	_wind_snd.volume_db = lerpf(-60.0, -10.0, clampf(_gust * 1.1, 0.0, 1.0)) if (_gust > 0.12 and not sheltered) else -60.0
	_howl_snd.volume_db = lerpf(-60.0, -8.0, clampf((_gust - 0.5) * 2.0, 0.0, 1.0)) if (_gust > 0.5 and not sheltered) else -60.0
	_blizzard_snd.volume_db = lerpf(-60.0, -9.0, snow) if (snow > 0.1 and not sheltered) else -60.0
	Game.is_night = night > 0.55
	Game.raining = rain > 0.2

func _lightning(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 4.0)
	if storm < 0.7: return
	_next_strike -= delta
	if _next_strike > 0.0: return
	_next_strike = randf_range(5.0, 16.0)
	var fp := Game.get_focus_pos()
	var ang := randf() * TAU
	var dist := randf_range(250.0, 900.0)
	var at := Vector3(fp.x + cos(ang) * dist, 0.0, fp.z + sin(ang) * dist)
	_strike(at, dist)

func _strike(at: Vector3, dist: float) -> void:
	# a jagged bolt from the clouds
	if _bolt != null and is_instance_valid(_bolt): _bolt.queue_free()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var p := Vector3(at.x, 420.0, at.z)
	var segs := 22
	for i in range(segs + 1):
		var t := float(i) / segs
		im.surface_add_vertex(p.lerp(at, t) + Vector3(randf_range(-14, 14), 0, randf_range(-14, 14)) * (1.0 - t * 0.4) * (0.0 if i == segs else 1.0))
	im.surface_end()
	_bolt = MeshInstance3D.new()
	_bolt.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.93, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.88, 1.0)
	mat.emission_energy_multiplier = 8.0
	_bolt.material_override = mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.top_level = true
	add_child(_bolt)
	# flash: two quick pulses
	_flash = 1.0
	var tw := create_tween()
	tw.tween_interval(0.07)
	tw.tween_callback(func(): _flash = 0.25)
	tw.tween_interval(0.07)
	tw.tween_callback(func(): _flash = 1.0)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if is_instance_valid(_bolt): _bolt.queue_free())
	# thunder arrives after the flash: sound travels ~340 m/s (sped up so it feels right in game)
	var delay := dist / 340.0 * 0.6
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://assets/audio/weather/%s" % ("thunder_mid_01.ogg" if dist < 500.0 else "thunder_far_01.ogg")) as AudioStream
	snd.volume_db = lerpf(0.0, -10.0, clampf(dist / 900.0, 0.0, 1.0))
	add_child(snd)
	get_tree().create_timer(delay).timeout.connect(func():
		if Game.underground:
			snd.queue_free()                 # nothing of the storm is heard in the metro
			return
		snd.play()
		var cam := Game.camera as ThirdPersonCamera
		if cam != null and dist < 450.0: cam.add_shake(0.25))
	snd.finished.connect(snd.queue_free)

func _auto_lights(delta: float) -> void:
	_lights_cd -= delta
	if _lights_cd > 0.0: return
	_lights_cd = 1.0
	var on := is_night() or storm > 0.6
	for grp in ["cars", "police"]:
		for c in get_tree().get_nodes_in_group(grp):
			var car := c as Car
			if car == null: continue
			if car == Game.in_car:
				# the player's own car: lights come on once when they get in (after that the L key is theirs)
				if car.lights_pending:
					car.lights_pending = false
					car.set_lights(on)
				continue
			# nobody inside: headlights and tail lights stay off
			var want := on and car.driver != null
			if car.lights_on != want:
				car.set_lights(want)
