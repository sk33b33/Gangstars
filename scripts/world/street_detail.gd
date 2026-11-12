class_name StreetDetail
extends RefCounted
## The small stuff that makes streets lived-in, placed deterministically along each street of an
## area: litter on pavements and in gutters, potholes and tar patches, manholes, storm drains
## at the kerb, a speed hump on side streets, municipal pole bins and a transformer box.
## Everything is a plain mesh with a shared material, so MeshMerger batches it into a few draw
## calls. Visual only (no colliders): it never changes where people can walk.

static var _puddle_mat: StandardMaterial3D
const LITTER := ["litter_chips", "litter_can", "litter_paper", "litter_bottle"]


static func build(root: Node3D, info: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(info.get("id", "starter")) + ":street-detail")
	var count := 0
	for s in info.get("streets", []):
		count += _street(root, s, rng)
	return count


static func _street(root: Node3D, s: Dictionary, rng: RandomNumberGenerator) -> int:
	var hw: float = s.get("half_width", 4.0)
	var walk: float = s.get("sidewalk", 2.5)
	var a0: float = minf(s.get("sidewalk_from", s.from), s.get("sidewalk_to", s.to))
	var a1: float = maxf(s.get("sidewalk_from", s.from), s.get("sidewalk_to", s.to))
	var yaw := 0.0 if s.axis == "x" else PI * 0.5
	var crossings: Array = StreetBuilder.crossing_centres(s)
	var near_crossing := func(t: float) -> bool:
		return crossings.any(func(c): return absf(float(c) - t) < 3.0)
	var n := 0
	var t := a0 + 2.0
	while t < a1 - 2.0:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		if rng.randf() < 0.35:   # litter on the pavement or in the gutter
			var across := hw + rng.randf_range(0.3, walk - 0.3) if rng.randf() < 0.6 else hw - rng.randf_range(0.15, 0.5)
			var size := rng.randf_range(0.3, 0.5)
			_flat(root, LITTER[rng.randi() % LITTER.size()], Vector2(size, size), StreetBuilder._world(s, t, side * across) + Vector3(0, 0.028, 0), rng.randf() * TAU)
			n += 1
		if int(t - a0) % 12 < 3 and rng.randf() < 0.3 and not near_crossing.call(t):   # road wear
			var pot := rng.randf() < 0.5
			var at := StreetBuilder._world(s, t, rng.randf_range(-hw + 1.0, hw - 1.0))
			_flat(root, "pothole" if pot else "tar_patch", Vector2(1.2, 0.9) if pot else Vector2(1.6, 1.4), at + Vector3(0, 0.016, 0), yaw + rng.randf_range(-0.3, 0.3))
			if pot:   # rain collects in potholes
				_puddle(root, at + Vector3(0, 0.02, 0), Vector2(2.0, 1.5), yaw)
			n += 1
		if rng.randf() < 0.3:   # puddles along the gutter and low spots (shown only when wet)
			_puddle(root, StreetBuilder._world(s, t, side * (hw - rng.randf_range(0.6, 1.4))) + Vector3(0, 0.02, 0),
				Vector2(rng.randf_range(1.5, 3.2), rng.randf_range(0.9, 1.8)), yaw + rng.randf_range(-0.2, 0.2))
		if int(t - a0) % 22 < 3:   # storm drain at the kerb
			_flat(root, "drain_grate", Vector2(0.9, 0.32), StreetBuilder._world(s, t, side * (hw - 0.22)) + Vector3(0, 0.017, 0), yaw)
			n += 1
		if int(t - a0) % 31 < 3 and rng.randf() < 0.5:   # manhole
			_flat(root, "manhole", Vector2(0.8, 0.8), StreetBuilder._world(s, t, rng.randf_range(-1.5, 1.5)) + Vector3(0, 0.017, 0), 0.0)
			n += 1
		if int(t - a0) % 40 < 3:   # municipal pole bin at the kerb
			var p := StreetBuilder._world(s, t, side * (hw + 0.35))
			Geo.box(root, Vector3(0.06, 1.0, 0.06), p + Vector3(0, 0.5, 0), PixelMaterials.flat(Color("#565a64")), false)
			Geo.box(root, Vector3(0.42, 0.48, 0.36), p + Vector3(0, 0.78, 0.06), PixelMaterials.flat(Color("#2f5d3a")), false, yaw)
			n += 2
		t += 3.0
	# A speed hump across side streets (z-axis streets), away from the crossings.
	if s.axis == "z":
		var mid := (a0 + a1) * 0.5
		if near_crossing.call(mid):
			mid += 6.0
		Geo.box(root, Vector3(hw * 2.0, 0.06, 0.7), StreetBuilder._world(s, mid, 0) + Vector3(0, 0.03, 0), PixelMaterials.panel("speed_hump"), false, yaw + PI * 0.5)
		n += 1
	# One transformer box per street, at the kerb a third of the way along.
	var tp := StreetBuilder._world(s, a0 + (a1 - a0) * 0.33, -(hw + 0.45))
	Geo.box(root, Vector3(1.1, 1.3, 0.6), tp + Vector3(0, 0.65, 0), PixelMaterials.flat(Color("#4f6b4a")), false, yaw)
	var sticker := Geo.quad(root, Vector2(0.25, 0.25), Vector3.ZERO, PixelMaterials.panel("danger_sticker", Color.WHITE, true))
	var out := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)   # sticker on the road-facing side
	sticker.global_position = tp + Vector3(0, 0.95, 0) + out * 0.31
	sticker.rotation.y = yaw
	return n + 2


## Dark mirror-like water; Weather fades its alpha in with the wetness of the ground.
static func puddle_material() -> StandardMaterial3D:
	if _puddle_mat == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var r := Vector2(x - 15.5, y - 15.5).length() / 15.5
				var wob := 0.85 + 0.12 * sin(atan2(y - 15.5, x - 15.5) * 3.0 + 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(wob - 0.18, wob, r)))
		_puddle_mat = StandardMaterial3D.new()
		_puddle_mat.albedo_texture = ImageTexture.create_from_image(img)
		_puddle_mat.albedo_color = Color(0.08, 0.1, 0.14, 0.0)
		_puddle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puddle_mat.metallic = 0.9
		_puddle_mat.metallic_specular = 1.0
		_puddle_mat.roughness = 0.04
		_puddle_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _puddle_mat


static func _puddle(root: Node3D, pos: Vector3, size: Vector2, yaw: float) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Puddle"
	mi.mesh = pm
	mi.material_override = puddle_material()
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## A flat decal-like plane lying on the ground (alpha-scissor pixel texture).
static func _flat(root: Node3D, tex: String, size: Vector2, pos: Vector3, yaw: float) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = PixelMaterials.panel(tex, Color.WHITE, true)
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
