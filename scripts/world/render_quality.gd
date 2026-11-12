class_name RenderQuality
extends RefCounted
## Turns on the Forward+ look on desktop: filmic tonemapping, ambient occlusion (SSAO), bounced
## light (SSIL), bloom on lamps and windows, softer, longer shadows. The web build runs the
## Compatibility renderer, which has none of these, so it keeps the flat original look.
## Controlled by the "video/effects" setting.


static func is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


static func apply(env: Environment, sun: DirectionalLight3D, effects: bool) -> void:
	var on := effects and is_forward_plus()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if on else Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.05 if on else 1.0
	env.tonemap_white = 4.0
	env.ssao_enabled = on
	env.ssao_radius = 1.8
	env.ssao_intensity = 2.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.35
	env.ssil_enabled = on
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.7
	env.ssr_enabled = on   # wet roads, car paint and windows pick up the sky and lamps
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.25
	env.volumetric_fog_enabled = on   # dust shafts at sunset; DayNight sets the density
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_anisotropy = 0.5
	env.glow_enabled = on
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = on
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	if sun:
		sun.directional_shadow_max_distance = 120.0 if on else 80.0
		sun.shadow_blur = 1.5 if on else 1.0
		sun.light_angular_distance = 0.6 if on else 0.0
