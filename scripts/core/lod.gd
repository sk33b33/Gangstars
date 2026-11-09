class_name Lod
extends RefCounted
## Visibility ranges for small things, so distant props and people stop costing draw calls.
## Lamps and windows (emissive at night) are never culled by range.

const SMALL := 0.8      # max dimension (m) -> hidden beyond SMALL_RANGE
const MEDIUM := 2.0     # -> hidden beyond MEDIUM_RANGE
const SMALL_RANGE := 45.0
const MEDIUM_RANGE := 85.0
const CHARACTER_RANGE := 110.0
const MARGIN := 4.0


## Returns how many instances got a range.
static func apply(root: Node, character_range := false) -> int:
	var n := 0
	var keep := [PixelMaterials.lamp(), PixelMaterials.panel("window_bars")]
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if gi.visibility_range_end > 0.0 or keep.has(gi.material_override):
			continue
		var size := _size(gi)
		var end := 0.0
		if character_range:
			end = CHARACTER_RANGE
		elif size < SMALL:
			end = SMALL_RANGE
		elif size < MEDIUM:
			end = MEDIUM_RANGE
		if end > 0.0:
			gi.visibility_range_end = end
			gi.visibility_range_end_margin = MARGIN
			n += 1
	return n


static func _size(gi: GeometryInstance3D) -> float:
	var aabb := gi.get_aabb()
	var s := aabb.size * gi.global_basis.get_scale().abs()
	return maxf(s.x, maxf(s.y, s.z))
