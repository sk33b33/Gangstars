class_name GroundDetail
extends RefCounted
## Softens the hard edges of the flat ground: the Cape Flats are wind-blown sand, so there are worn
## earth and tough grass patches on the open lots, wind ripples, sand drifting over the pavement
## edges, weeds along walls and tufts of dune grass (Cape Flats dune strandveld). See
## docs/MITCHELLS_PLAIN_REFERENCE.md. Everything is a plain mesh with a shared material (so
## MeshMerger batches it) and no collider: it never changes where people can walk.

const PATCHES := ["dirt_patch", "dirt_patch", "grass_patch", "grass_patch", "sand_ripple"]
const CELL := 8.0


static func build(root: Node3D, info: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(info.get("id", "starter")) + ":ground-detail")
	var streets: Array = info.get("streets", [])
	var b: Array = info.get("bounds", [-72, -78, 72, 22])
	var keep_clear := _keep_clear_points(info)
	var n := 0
	# Patches and tufts on the open ground, on a jittered grid, away from roads and landmarks.
	var x := float(b[0]) - 6.0
	while x < float(b[2]) + 6.0:
		var z := float(b[1]) - 6.0
		while z < float(b[3]) + 6.0:
			var at := Vector3(x + rng.randf_range(0.0, CELL), 0.0, z + rng.randf_range(0.0, CELL))
			if not _on_road(streets, at, 1.0) and not _near_any(keep_clear, at, 7.0):
				var roll := rng.randf()
				if roll < 0.45:
					var tex: String = PATCHES[rng.randi() % PATCHES.size()]
					var w := rng.randf_range(2.6, 5.6)
					_flat(root, tex, Vector2(w, w * 0.72), at + Vector3(0, 0.012, 0), rng.randf() * TAU)
					n += 1
				elif roll < 0.62:
					for k in rng.randi_range(3, 6):   # a clump of dune grass
						_tuft(root, "dune_grass", Vector2(0.7, 0.95) * rng.randf_range(0.8, 1.3),
							at + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)), rng)
						n += 1
			z += CELL
		x += CELL
	# Along the streets: sand blown onto the pavement and weeds at the foot of the walls.
	for s in streets:
		n += _street(root, s, rng)
	return n


static func _street(root: Node3D, s: Dictionary, rng: RandomNumberGenerator) -> int:
	var hw: float = s.get("half_width", 4.0)
	var walk: float = s.get("sidewalk", 2.5)
	var a0: float = minf(s.get("sidewalk_from", s.from), s.get("sidewalk_to", s.to))
	var a1: float = maxf(s.get("sidewalk_from", s.from), s.get("sidewalk_to", s.to))
	var yaw := 0.0 if s.axis == "x" else PI * 0.5
	var n := 0
	var t := a0 + 1.0
	while t < a1 - 1.0:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		if rng.randf() < 0.22:   # a drift of sand over the outer edge of the pavement
			_flat(root, "sand_drift", Vector2(rng.randf_range(2.0, 3.6), 1.0),
				StreetBuilder._world(s, t, side * (hw + walk - 0.35)) + Vector3(0, 0.032, 0), yaw + (0.0 if side > 0.0 else PI))
			n += 1
		if rng.randf() < 0.3:   # weeds where the wall meets the pavement
			_tuft(root, "weed_tuft", Vector2(0.55, 0.5) * rng.randf_range(0.8, 1.4),
				StreetBuilder._world(s, t, side * (hw + walk + 0.12)), rng)
			n += 1
		t += 2.5
	return n


static func _on_road(streets: Array, at: Vector3, margin: float) -> bool:
	for s in streets:
		var hw: float = s.get("half_width", 4.0) + s.get("sidewalk", 2.5) + margin
		var across: float = at.z - float(s.at) if s.axis == "x" else at.x - float(s.at)
		var along: float = at.x if s.axis == "x" else at.z
		var lo: float = minf(float(s.from), float(s.to)) - margin
		var hi: float = maxf(float(s.from), float(s.to)) + margin
		if absf(across) < hw and along > lo and along < hi:
			return true
	return false


static func _keep_clear_points(info: Dictionary) -> Array:
	var out: Array = []
	for lm in info.get("landmarks", []):
		var p := DataFiles.to_vec2(lm.get("position"))
		out.append(Vector3(p.x, 0, p.y))
	for poi in info.get("pois", []):
		var p := DataFiles.to_vec2(poi.get("position"))
		out.append(Vector3(p.x, 0, p.y))
	return out


static func _near_any(points: Array, at: Vector3, dist: float) -> bool:
	for p: Vector3 in points:
		if Vector2(p.x - at.x, p.z - at.z).length() < dist:
			return true
	return false


static func _flat(root: Node3D, tex: String, size: Vector2, pos: Vector3, yaw: float) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = PixelMaterials.panel(tex, Color.WHITE, true)
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Two crossed vertical quads (a tuft seen from any side), standing on the ground.
static func _tuft(root: Node3D, tex: String, size: Vector2, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var mat := PixelMaterials.panel(tex, Color.WHITE, true)
	var yaw := rng.randf() * PI
	for k in 2:
		var q := Geo.quad(root, size, pos + Vector3(0, size.y * 0.5, 0), mat, yaw + k * PI * 0.5)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
