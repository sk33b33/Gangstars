class_name Puddles
extends RefCounted
## Puddles on the roads after rain: pale pools laid along the gutters when the roads are built, invisible by default and shown while the
## ground is wet. One shared material, so every puddle batches; DayNight only calls set_wetness() with the wet amount (0 dry, 1 soaked).

const START := 0.25     # no puddles until the ground is this wet
const FULL := 0.75      # all the way visible from here

static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = PixelMaterials.panel("puddle", Color.WHITE, true).duplicate() as StandardMaterial3D
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(1, 1, 1, 0)
		_mat.roughness = 0.1
		_mat.disable_receive_shadows = true
	return _mat


## How visible the puddles are for a given wetness.
static func visibility(wet: float) -> float:
	return clampf((wet - START) / (FULL - START), 0.0, 1.0)


static func set_wetness(wet: float) -> void:
	material().albedo_color.a = visibility(wet)
