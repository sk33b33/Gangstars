class_name AudioDirector
extends Node3D
## Plays the neighbourhood's sound: ambient beds (wind, rain, crickets, day birds) driven by
## clock + weather, positional one-shots from a small player pool, and engine loops attached
## to vehicles with pitch following speed. Buses: SFX, Ambient, UI (see default_bus_layout.tres).

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


func _loop_player(stream_name: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = AudioBank.get_stream(stream_name)
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func play_at(stream_name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
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
	if not night and rain_amount < 0.2 and listener_node:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = _rng.randf_range(4.0, 11.0)
			var a := _rng.randf() * TAU
			play_at("bird", listener_node.global_position + Vector3(cos(a) * 14.0, 6.0, sin(a) * 14.0), -6.0, _rng.randf_range(0.9, 1.2))
