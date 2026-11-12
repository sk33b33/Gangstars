class_name AudioDirector
extends Node3D
## Plays the neighbourhood's sound: ambient beds (wind, rain, crickets, day birds) driven by
## clock + weather, positional one-shots from a small player pool, and engine loops attached
## to vehicles with pitch following speed. Buses: SFX, Ambient, UI, Music (see default_bus_layout.tres).
## Also: the car radio (three made-up stations), music at the smokkies on smokkie nights and
## inside them, taxi hooters at the ranks, market callers, church bells, and gibberish voices
## when people greet or chat.

const POOL_SIZE := 10

var clock: SimClock
var listener_node: Node3D
var rain_amount := 0.0
var wind_amount := 0.3
var played_count := 0

var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _wind: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _bird_timer := 3.0
var _engines: Array = []   # [player, node with `speed`]
const STATIONS := [{"name": "Plain FM", "stream": "music_plain"}, {"name": "Spine Road Jazz", "stream": "music_jazz"},
	{"name": "Gospel 101", "stream": "music_gospel"}, {"name": "Kasi Beats", "stream": "music_kasi"},
	{"name": "Cape Ghoema FM", "stream": "music_ghoema"}]
var radio_station := 0      # index into STATIONS; -1 = off
var radio_on := false
var _radio: AudioStreamPlayer
var _inside: AudioStreamPlayer
var _venues: Array = []     # [AudioStreamPlayer3D, hours Vector2]
var ranks: Array = []       # positions: taxi ranks (hooters)
var markets: Array = []     # positions: market stalls (callers)
var churches: Array = []    # positions: church halls (bells on the hour at 8, 12, 18)
var _street_timer := 4.0
var _last_bell_hour := -1
var voices_played := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 99
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 6.0
		p.max_distance = 70.0
		add_child(p)
		_pool.append(p)
	_wind = _loop_player("wind", &"Ambient")
	_rain = _loop_player("rain", &"Ambient")
	_crickets = _loop_player("crickets", &"Ambient")
	_ui = AudioStreamPlayer.new()
	_ui.bus = &"UI"
	add_child(_ui)
	_radio = AudioStreamPlayer.new()
	_radio.bus = &"Music"
	_radio.volume_db = -6.0
	add_child(_radio)
	_inside = AudioStreamPlayer.new()
	_inside.bus = &"Music"
	_inside.volume_db = -9.0
	add_child(_inside)


func _loop_player(stream_name: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = AudioBank.get_stream(stream_name)
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


## Sounds that get a caption for players who can't hear them (Settings > Accessibility).
const CAPTIONS := {"gunshot": "Gunshot", "horn": "Car horn", "hooter": "Taxi hooter", "door": "Door", "bark": "Dog barking",
	"ring": "Phone ringing", "siren": "Siren", "alarm": "Alarm", "whistle": "Whistle", "bell": "Bell", "bird": "Birdsong"}
## label, world position: the HUD turns it into "[Gunshot]" with an arrow towards the sound.
signal sound_heard(label: String, pos: Vector3)


func play_at(stream_name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if CAPTIONS.has(stream_name) and listener_node and listener_node.global_position.distance_to(pos) < 45.0:
		sound_heard.emit(str(CAPTIONS[stream_name]), pos)
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = AudioBank.get_stream(stream_name)
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	played_count += 1


func play_ui(stream_name: String, volume_db := 0.0) -> void:
	_ui.stream = AudioBank.get_stream(stream_name)
	_ui.volume_db = volume_db
	_ui.play()
	played_count += 1


## Engine hum that follows a vehicle; `vehicle.speed` drives the pitch.
func attach_engine(vehicle: Node3D, volume_db := -6.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = AudioBank.get_stream("engine")
	p.bus = &"SFX"
	p.unit_size = 5.0
	p.max_distance = 45.0
	p.volume_db = volume_db
	vehicle.add_child(p)
	p.play()
	_engines.append([p, vehicle])


var weather: Weather


# ------------------------------------------------------------------ music

## Car radio: on while you drive; cycle stations (and off) with the radio key.
func set_driving(on: bool) -> void:
	radio_on = on
	_update_radio()


func next_station() -> String:
	radio_station = radio_station + 1 if radio_station + 1 < STATIONS.size() else -1
	_update_radio()
	return "Radio off" if radio_station < 0 else "Radio: %s" % STATIONS[radio_station].name


func radio_playing() -> bool:
	return _radio.playing


func _update_radio() -> void:
	if radio_on and radio_station >= 0:
		var stream := AudioBank.get_stream(STATIONS[radio_station].stream)
		if _radio.stream != stream or not _radio.playing:
			_radio.stream = stream
			_radio.play()
	else:
		_radio.stop()


## Set by the session so event music (the Tweede Nuwe Jaar parade) can follow the calendar.
var calendar: NeighbourhoodCalendar


## Music from a smokkie's speakers during its evening hours (or, with event_id, while that
## calendar event runs).
func add_venue(pos: Vector3, hours := Vector2(17, 23), stream_name := "music_plain", event_id := "") -> void:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"Music"
	p.unit_size = 4.0
	p.max_distance = 40.0
	p.volume_db = -4.0
	p.set_meta("stream", stream_name)
	add_child(p)
	p.global_position = pos + Vector3(0, 1.5, 0)
	_venues.append([p, hours, event_id])


func venues_playing() -> int:
	return _venues.filter(func(v): return (v[0] as AudioStreamPlayer3D).playing).size()


## Indoors at a smokkie: the music's all around you.
func set_inside_music(on: bool) -> void:
	if on:
		_inside.stream = AudioBank.get_stream("music_plain")
		_inside.play()
	else:
		_inside.stop()


## Someone talks: a gibberish voice at their head, if you're close enough to hear it.
func voice(pos: Vector3, seed: int, female: bool) -> void:
	if listener_node == null or listener_node.global_position.distance_to(pos) > 18.0:
		return
	var pitch := (1.35 if female else 0.95) * (0.9 + float(absi(seed) % 20) / 100.0)
	play_at("mumble%d" % (absi(seed) % 4), pos + Vector3(0, 1.6, 0), -10.0, pitch)
	voices_played += 1


func _street_life(delta: float) -> void:
	if listener_node == null:
		return
	var here := listener_node.global_position
	_street_timer -= delta
	if _street_timer <= 0.0:
		_street_timer = _rng.randf_range(3.0, 8.0)
		for r: Vector3 in ranks:
			if here.distance_to(r) < 45.0 and _rng.randf() < 0.6:
				play_at("hooter", r + Vector3(_rng.randf_range(-6, 6), 1.0, _rng.randf_range(-4, 4)), -4.0, _rng.randf_range(0.9, 1.1))
		for m: Vector3 in markets:
			if here.distance_to(m) < 35.0 and clock and clock.hour() >= 7.0 and clock.hour() < 18.0:
				play_at("mumble%d" % _rng.randi_range(0, 3), m + Vector3(_rng.randf_range(-10, 10), 1.6, _rng.randf_range(-6, 6)), -2.0, _rng.randf_range(1.1, 1.5))
	if clock:
		var h := int(clock.hour())
		if h != _last_bell_hour:
			_last_bell_hour = h
			if h in [8, 12, 18]:
				for c: Vector3 in churches:
					for k in 3:
						get_tree().create_timer(k * 1.4).timeout.connect(func(): play_at("bell", c + Vector3(0, 6, 0), 2.0))


func _process(delta: float) -> void:
	if weather:
		rain_amount = weather.rain if weather.enabled else 0.0
		wind_amount = weather.wind
	var night := clock != null and clock.is_night()
	_wind.volume_db = linear_to_db(clampf(0.15 + wind_amount * 0.6, 0.001, 1.0))
	_rain.volume_db = linear_to_db(clampf(rain_amount * 0.9, 0.001, 1.0))
	_crickets.volume_db = linear_to_db(0.35 if night and rain_amount < 0.3 else 0.001)
	for e in _engines:
		var p: AudioStreamPlayer3D = e[0]
		var v: Node3D = e[1]
		var spd := absf(float(v.get("speed")))
		p.pitch_scale = 0.7 + spd * 0.09
		p.volume_db = lerpf(-14.0, -4.0, clampf(spd / 10.0, 0.0, 1.0))
	_street_life(delta)
	if clock:
		var hour := clock.hour()
		for v in _venues:
			var p: AudioStreamPlayer3D = v[0]
			var hrs: Vector2 = v[1]
			var ev := str(v[2]) if v.size() > 2 else ""
			var in_hours := hour >= hrs.x and hour < hrs.y and (ev.is_empty() or (calendar != null and calendar.is_active(ev)))
			var on := in_hours and listener_node != null and listener_node.global_position.distance_to(p.global_position) < 60.0
			if on and not p.playing:
				p.stream = AudioBank.get_stream(str(p.get_meta("stream")))
				p.play()
			elif not on and p.playing:
				p.stop()
	if not night and rain_amount < 0.2 and listener_node:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = _rng.randf_range(4.0, 11.0)
			var a := _rng.randf() * TAU
			play_at("bird", listener_node.global_position + Vector3(cos(a) * 14.0, 6.0, sin(a) * 14.0), -6.0, _rng.randf_range(0.9, 1.2))
