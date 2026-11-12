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
var wet := 0.0   # puddle/shine on the ground: builds up in rain, dries slowly after

var _rng := RandomNumberGenerator.new()
var _next_change := 0.0
var _particles: CPUParticles3D
var _drop_mat: StandardMaterial3D
var _clouds: Array[Decal] = []
const CLOUD_SIZE := 70.0


func setup(p_district: District, p_clock: SimClock, p_day_night: DayNight) -> void:
	district = p_district
	clock = p_clock
	day_night = p_day_night
	_rng.seed = 4242
	# The first day is always clear (a new player's first impression); spells start on day 2.
	_next_change = (clock.day + 1) * 1440.0 + 360.0
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
	_make_cloud_shadows()


## Cloud shadows: a few big soft dark decals drifting downwind over the streets near the
## camera. They fade out far downwind and come back in upwind, so there's no pop.
func _make_cloud_shadows() -> void:
	# Soft blobs of shade from noise, built synchronously (decals want a ready texture).
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var v := noise.get_noise_2d(x, y)
			var r := Vector2(x - 64, y - 64).length() / 64.0   # fade out towards the edges
			var a := smoothstep(0.0, 0.25, v) * (1.0 - smoothstep(0.6, 1.0, r)) * 0.45
			img.set_pixel(x, y, Color(0.05, 0.06, 0.09, a))
	var tex := ImageTexture.create_from_image(img)
	for i in 3:
		var d := Decal.new()
		d.name = "CloudShadow%d" % i
		d.texture_albedo = tex
		d.size = Vector3(CLOUD_SIZE, 40.0, CLOUD_SIZE)
		d.cull_mask = 1
		d.upper_fade = 0.0
		d.lower_fade = 0.0
		d.modulate = Color(1, 1, 1, 0)
		d.rotation.y = i * 2.1
		d.set_meta("offset", Vector2(-CLOUD_SIZE + i * CLOUD_SIZE, (i - 1) * CLOUD_SIZE * 0.6))
		add_child(d)
		_clouds.append(d)


func _move_clouds(delta: float) -> void:
	var amount := clampf(overcast * 1.6, 0.0, 1.0) * (1.0 - smoothstep(0.6, 0.85, overcast))
	var day := DayNight.daylight(clock.hour()) if clock else 0.0
	var at := follow.global_position if follow else Vector3.ZERO
	for d in _clouds:
		var off: Vector2 = d.get_meta("offset")
		off.x += delta * (1.5 + wind * 4.0)   # drifts east with the wind
		if off.x > CLOUD_SIZE * 1.5:
			off.x -= CLOUD_SIZE * 3.0
		d.set_meta("offset", off)
		var edge := 1.0 - smoothstep(CLOUD_SIZE * 0.9, CLOUD_SIZE * 1.5, absf(off.x))
		d.modulate.a = amount * smoothstep(0.05, 0.3, day) * edge
		d.visible = d.modulate.a > 0.02
		d.global_position = Vector3(at.x + off.x, 10.0, at.z + off.y)


func _now() -> float:
	return clock.day * 1440.0 + clock.minutes


## Forces a spell (debug / tests). Intensities still ease towards it.
func set_kind(k: String) -> void:
	if not KINDS.has(k):
		return
	kind = k
	_next_change = _now() + _rng.randf_range(180.0, 360.0)
	changed.emit(kind)


## Forces a spell and keeps it (screenshots, debugging): no new spells are rolled.
func hold(k: String) -> void:
	set_kind(k)
	_next_change = INF


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
	_move_clouds(delta)
	if follow:
		_particles.global_position = follow.global_position + Vector3(0, 12, 0)
	# The ground stays wet for a while after the rain stops, drying in the sun and wind.
	wet = clampf(wet + (rain * 0.1 - (0.004 + wind * 0.004)) * delta * (0.25 if rain < 0.2 else 1.0), 0.0, 1.0) if enabled else 0.0
	if day_night:
		day_night.overcast = overcast
		day_night.dust = smoothstep(0.5, 0.9, wind) * (1.0 - rain)
		day_night.wet = wet
		day_night.cloud_cover = clampf(overcast * 1.6, 0.0, 1.0) * (1.0 - smoothstep(0.6, 0.85, overcast))
	if district:
		var raining := is_raining()
		for r: Resident in district.residents.values():
			r.brain.raining = raining
