class_name DayNight
extends Node
## Drives sun angle/energy, sky and ambient colours, and streetlight glow from the SimClock.

var clock: SimClock
var sun: DirectionalLight3D
var environment: Environment

const DAY_AMBIENT := Color(0.62, 0.68, 0.78)
const NIGHT_AMBIENT := Color(0.3, 0.36, 0.56)
const MOON_COLOR := Color(0.62, 0.72, 1.0)
const MOON_ENERGY := 0.3
const DAY_SKY_TOP := Color(0.32, 0.55, 0.86)
const NIGHT_SKY_TOP := Color(0.03, 0.05, 0.12)
const DAY_HORIZON := Color(0.78, 0.84, 0.9)
const DUSK_HORIZON := Color(0.95, 0.6, 0.4)
const NIGHT_HORIZON := Color(0.1, 0.12, 0.22)


func setup(p_clock: SimClock, p_sun: DirectionalLight3D, p_env: Environment) -> void:
	clock = p_clock
	sun = p_sun
	environment = p_env
	apply()


func _process(_delta: float) -> void:
	if clock:
		apply()


## daylight: 0 at night, 1 at noon. Sun rises at 6:00 and sets at 19:00.
static func daylight(h: float) -> float:
	if h < 6.0 or h > 19.0:
		return 0.0
	return sin((h - 6.0) / 13.0 * PI)


func apply() -> void:
	var h := clock.hour()
	var light := daylight(h)
	var dusk := clampf(1.0 - absf(light - 0.15) / 0.15, 0.0, 1.0) if light > 0.0 else 0.0
	var night := 1.0 - smoothstep(0.0, 0.3, light)
	# By day the light is the sun; at night the same light becomes a dim blue moon, so the
	# street stays readable. The sky disc is hidden at night.
	sun.rotation = Vector3(-lerpf(0.9, 1.2, light) if night > 0.99 else -lerpf(0.15, 1.2, light), 0.52 + (h - 12.0) * 0.08, 0)
	var sun_color := Color(1, 0.85, 0.7).lerp(Color.WHITE, smoothstep(0.1, 0.5, light))
	sun.light_color = sun_color.lerp(MOON_COLOR, night)
	sun.light_energy = lerpf(0.95 * smoothstep(0.0, 0.25, light), MOON_ENERGY, night)
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY if night > 0.5 else DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, night)
	environment.ambient_light_energy = lerpf(0.55, 0.6, night)
	var sky := environment.sky.sky_material as ProceduralSkyMaterial if environment.sky else null
	if sky:
		sky.sky_top_color = DAY_SKY_TOP.lerp(NIGHT_SKY_TOP, night)
		var horizon := DAY_HORIZON.lerp(DUSK_HORIZON, dusk).lerp(NIGHT_HORIZON, night)
		sky.sky_horizon_color = horizon
		sky.ground_horizon_color = horizon
		sky.ground_bottom_color = horizon.darkened(0.3)
	PixelMaterials.lamp().emission_energy_multiplier = lerpf(0.3, 4.0, night)
