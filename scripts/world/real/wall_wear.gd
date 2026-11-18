class_name WallWear
extends RefCounted
## Marks on the painted walls, each with a cause: rising damp (a darker band above the plinth, ragged at the top, on about half the homes), a
## rain streak running down from under some window sills, and now and then a repaired patch of fresh paint. Soft alpha layers just proud of
## the wall, merged into the piece's meshes like every other surface.

const DAMP_PERCENT := 55        # share of homes with damp at the foot of their walls
const DAMP_Y := Vector2(0.5, 0.92)   # above the plinth band (RealChunkBuilder.PLINTH_HEIGHT)
const DAMP_TILE := 2.0          # one texture tile of damp along the wall (m)
const STREAK_PERCENT := 60      # share of windows with a stain below the sill
const STREAK_SIZE := Vector2(0.7, 0.55)
const PATCH_PERCENT := 14       # share of walls with a repaired patch
const TAG_PERCENT := 9          # share of longer walls with a tag sprayed on them
const PATCH_SIZE := Vector2(0.9, 0.9)
const LIFT := 0.014             # how far off the wall the layers sit (the windows' panels are 0.04 off)

static var _mats: Dictionary = {}


static func material(tex: String) -> StandardMaterial3D:
	if not _mats.has(tex):
		var m := PixelMaterials.panel(tex, Color.WHITE, true).duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # soft stains, not cut-out ones
		m.disable_receive_shadows = true
		_mats[tex] = m
	return _mats[tex]


static func tool(tex: String, surfaces: Dictionary, materials: Dictionary) -> SurfaceTool:
	return RealChunkBuilder._tool("wallwear_" + tex, surfaces, materials, material(tex))


## The damp and the patches for the walls of a house outline (the window streaks are drawn with the windows, `streak`).
static func draw(ring: PackedVector2Array, seed_value: int, surfaces: Dictionary, materials: Dictionary) -> void:
	var damp := seed_value % 100 < DAMP_PERCENT
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var length := p0.distance_to(p1)
		if length < 2.5:
			continue
		var t := (p1 - p0) / length
		var normal := Vector2(-t.y, t.x)
		if normal.dot(RealChunkBuilder.edge_out(ring, p0, p1)) < 0.0:
			normal = -normal
		var mid := (p0 + p1) * 0.5
		if damp:
			var tiles := maxi(1, roundi(length / DAMP_TILE))
			var seg := length / tiles
			var damp_tool := tool("wall_damp", surfaces, materials)
			for k in tiles:
				RealChunkBuilder._panel(damp_tool, p0 + t * seg * (k + 0.5) + normal * LIFT, t, normal, seg, DAMP_Y.x, DAMP_Y.y)
		var hash := RealChunkBuilder._wall_hash(mid)
		if hash % 100 >= 100 - TAG_PERCENT and length > 4.5:   # a gang tag sprayed on a plain side wall
			var tag: String = RealChunkBuilder.TAGS[(hash / 100) % RealChunkBuilder.TAGS.size()]
			var tag_tool := RealChunkBuilder._tool("panel_" + tag, surfaces, materials, PixelMaterials.panel(tag, Color.WHITE, true))
			RealChunkBuilder._panel(tag_tool, mid + t * (float(hash / 400 % 100) / 100.0 - 0.5) * (length - 3.0) + normal * LIFT, t, normal, 2.0, 0.85, 1.7)
		if hash % 100 < PATCH_PERCENT and length > 4.0:
			var along := (float(hash / 100 % 100) / 100.0 - 0.5) * (length - 2.0)
			RealChunkBuilder._panel(tool("wall_patch", surfaces, materials), mid + t * along + normal * LIFT, t, normal, PATCH_SIZE.x, 1.2, 1.2 + PATCH_SIZE.y)


## A stain below a window sill at `mid` (the sill is at 1.0 m), on STREAK_PERCENT of windows.
static func streak(st: SurfaceTool, mid: Vector2, tangent: Vector2, normal: Vector2) -> void:
	if st == null or RealChunkBuilder._wall_hash(mid) % 100 >= STREAK_PERCENT:
		return
	RealChunkBuilder._panel(st, mid + normal * LIFT, tangent, normal, STREAK_SIZE.x, 1.0 - STREAK_SIZE.y, 1.0)
