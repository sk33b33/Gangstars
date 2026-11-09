class_name Weather
extends Node3D
## Cape Town weather spells: clear, cloudy, windy or rain. A new spell is rolled every few
## game hours from a seeded RNG; intensities ease in and out. Rain draws camera-following
## particles, darkens the sky (DayNight.overcast) and makes residents stay home instead of
## lingering outside (NpcBrain.raining). Disabled in settings => always clear.

signal changed(kind: String)

const KINDS := {"clear": [0.0, 0.0, 0.25], "cloudy": [0.0, 0.55, 0.35], "windy": [0.0, 0.3, 0.9], "rain": [1.0, 0.85, 0.6]}
# [rain, overcast, wind] targets per kind

var clock: SimClock
var day_night: DayNight
var district: District
var follow: Node3D
var enabled := true
var kind := "clear"
var rain := 0.0
var overcast := 0.0
var wind := 0.25

var _rng := RandomNumberGenerator.new()
var _next_change := 0.0
var _particles: CPUParticles3D
var _drop_mat: StandardMaterial3D


func setup(p_district: District, p_clock: SimClock, p_day_night: DayNight) -> void:
	district = p_district
	clock = p_clock
	day_night = p_day_night
	_rng.seed = 4242
	_next_change = _now() + 180.0
	_particles = CPUParticles3D.new()
	_particles.amount = 700
	_particles.lifetime = 0.9
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(18, 0.5, 18)
	_particles.direction = Vector3(0.15, -1, 0)
	_particles.spread = 3.0
	_particles.gravity = Vector3(0, -20, 0)
	_particles.initial_velocity_min = 12.0
	_particles.initial_velocity_max = 15.0
	_particles.local_coords = false
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.82, 0.95, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = mat
	_drop_mat = mat
	_particles.mesh = drop
	_particles.emitting = false
	add_child(_particles)


func _now() -> float:
	return clock.day * 1440.0 + clock.minutes


## Forces a spell (debug / tests). Intensities still ease towards it.
func set_kind(k: String) -> void:
	if not KINDS.has(k):
		return
	kind = k
	_next_change = _now() + _rng.randf_range(180.0, 360.0)
	changed.emit(kind)


func is_raining() -> bool:
	return enabled and rain > 0.35


func _process(delta: float) -> void:
	if clock == null:
		return
	if enabled and _now() >= _next_change:
		var roll := _rng.randf()
		set_kind("rain" if roll < 0.25 else ("windy" if roll < 0.45 else ("cloudy" if roll < 0.7 else "clear")))
	var target: Array = KINDS[kind] if enabled else KINDS["clear"]
	var k := clampf(delta * 0.25, 0.0, 1.0)
	rain = lerpf(rain, float(target[0]), k)
	overcast = lerpf(overcast, float(target[1]), k)
	wind = lerpf(wind, float(target[2]), k)
	_particles.emitting = rain > 0.15
	_drop_mat.albedo_color.a = 0.45 * clampf(rain, 0.0, 1.0)
	if follow:
		_particles.global_position = follow.global_position + Vector3(0, 12, 0)
	if day_night:
		day_night.overcast = overcast
	if district:
		var raining := is_raining()
		for r: Resident in district.residents.values():
			r.brain.raining = raining
