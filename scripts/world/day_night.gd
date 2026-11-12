class_name DayNight
extends Node
## Drives sun angle/energy, sky and ambient colours, and streetlight glow from the SimClock.

var clock: SimClock
var sun: DirectionalLight3D
var environment: Environment
var shadows_allowed := true
## 0..1 from Weather: greys the sky, dims the sun, pulls the fog in.
var overcast := 0.0
## 0..1 from Weather: wind lifts Cape Flats sand into a tan haze.
var dust := 0.0
## 0..1 from Weather: wet ground after rain (shiny, darker), dries off slowly.
var wet := 0.0
## Patchy cloud passing over the sun on cloudy days (0 = clear).
var cloud_cover := 0.0
var _cloud_t := 0.0
var _applied_wet := -1.0
## False during load-shedding: streetlights and windows go dark.
var power_on := true
const OVERCAST_SKY := Color(0.52, 0.55, 0.6)

const DAY_AMBIENT := Color(0.62, 0.68, 0.78)
const NIGHT_AMBIENT := Color(0.3, 0.36, 0.56)
const MOON_COLOR := Color(0.62, 0.72, 1.0)
const MOON_ENERGY := 0.3
const DAY_SKY_TOP := Color(0.32, 0.55, 0.86)
const NIGHT_SKY_TOP := Color(0.03, 0.05, 0.12)
const DAY_HORIZON := Color(0.78, 0.84, 0.9)
const DUSK_HORIZON := Color(0.95, 0.6, 0.4)
const NIGHT_HORIZON := Color(0.1, 0.12, 0.22)
const DUSK_TOP := Color(0.36, 0.3, 0.55)        # violet overhead at sunset
const DAWN_HORIZON := Color(0.98, 0.7, 0.62)    # pinker at sunrise
const GOLDEN_SUN := Color(1.0, 0.62, 0.36)
const DUST_FOG := Color(0.82, 0.72, 0.56)


## True when streetlights are on (night with power): drives the LightPool.
var is_lit := false


func setup(p_clock: SimClock, p_sun: DirectionalLight3D, p_env: Environment) -> void:
	clock = p_clock
	sun = p_sun
	environment = p_env
	apply()


func _process(delta: float) -> void:
	_cloud_t += delta
	if clock:
		apply()


## How much a passing cloud is shading the sun right now (0..1), from two slow waves.
func cloud_shade() -> float:
	var w := 0.5 + 0.5 * sin(_cloud_t * 0.21) * sin(_cloud_t * 0.083 + 1.3)
	return clampf(cloud_cover * smoothstep(0.35, 0.75, w), 0.0, 1.0)


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
	# Golden hour: a deep orange sun low in the sky, warming to white by mid-morning.
	var sun_color := GOLDEN_SUN.lerp(Color(1, 0.88, 0.74), smoothstep(0.15, 0.4, light)).lerp(Color.WHITE, smoothstep(0.4, 0.7, light))
	sun.light_color = sun_color.lerp(MOON_COLOR, night)
	var shade := cloud_shade() * (1.0 - night)
	sun.light_energy = lerpf(0.95 * smoothstep(0.0, 0.25, light), MOON_ENERGY, night) * (1.0 - overcast * 0.55) * (1.0 - shade * 0.2) * (1.0 - dust * 0.25)
	sun.shadow_enabled = shadows_allowed
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY if night > 0.5 else DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, night)
	environment.ambient_light_energy = lerpf(0.55, 0.6, night)
	var sky := environment.sky.sky_material as ProceduralSkyMaterial if environment.sky else null
	if sky:
		var clear := 1.0 - overcast
		sky.sky_top_color = DAY_SKY_TOP.lerp(DUST_FOG, dust * 0.55).lerp(DUSK_TOP, dusk * clear * 0.7).lerp(OVERCAST_SKY, overcast * (1.0 - night)).lerp(NIGHT_SKY_TOP, night)
		var glow := DAWN_HORIZON if h < 12.0 else DUSK_HORIZON
		var horizon := DAY_HORIZON.lerp(DUST_FOG, dust * 0.9).lerp(glow, dusk * clear).lerp(OVERCAST_SKY.lightened(0.15), overcast * (1.0 - night)).lerp(NIGHT_HORIZON, night)
		sky.sky_horizon_color = horizon
		sky.ground_horizon_color = horizon
		sky.ground_bottom_color = horizon.darkened(0.3)
		environment.fog_light_color = horizon.lerp(DUST_FOG.darkened(night * 0.8), dust * 0.7)
		environment.fog_depth_begin = lerpf(80.0, 10.0, maxf(overcast * 0.45, dust))
		environment.fog_depth_end = lerpf(320.0, 110.0, dust)
	var power := 1.0 if power_on else 0.0
	PixelMaterials.lamp().emission_energy_multiplier = lerpf(0.3, 4.0, night) * power
	VehicleLibrary.night = night
	var win := PixelMaterials.panel("window_bars")
	if not win.emission_enabled:
		win.emission_enabled = true
		win.emission_texture = win.albedo_texture
		win.emission = Color("#ffcf7a")
	win.emission_energy_multiplier = night * 0.8 * power
	is_lit = night > 0.5 and power_on
	if absf(wet - _applied_wet) > 0.02:
		_applied_wet = wet
		PixelMaterials.set_wetness(wet)
