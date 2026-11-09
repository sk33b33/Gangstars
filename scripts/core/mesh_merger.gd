class_name MeshMerger
extends RefCounted
## Static batching: merges MeshInstance3D visuals that share a material into one mesh per
## (spatial cell, material), cutting draw calls by an order of magnitude. Colliders are not
## touched. Skipped: anything under a node that moves or toggles (door hinges, gates, braai,
## upgrade props), labels and particles. Small props are merged into separate per-cell meshes
## that keep a visibility range, so they still disappear at distance.

const CELL := 40.0
const SMALL_SIZE := 0.8
const SMALL_RANGE := 60.0
const SKIP_NAMES := ["DoorHinge", "Braai", "Cap", "Hair"]


## Returns {merged_from: int, merged_into: int}.
static func merge(root: Node3D) -> Dictionary:
	var groups := {}
	var count := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not _mergeable(mi, root):
			continue
		var centre := mi.global_transform * mi.get_aabb().get_center()
		var key := [Vector2i(floori(centre.x / CELL), floori(centre.z / CELL)), mi.material_override, _size(mi) < SMALL_SIZE]
		groups.get_or_add(key, []).append(mi)
		count += 1
	var made := 0
	var inv := root.global_transform.affine_inverse()
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for mi: MeshInstance3D in list:
			for s in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, s, inv * mi.global_transform)
		var merged := MeshInstance3D.new()
		merged.name = "Merged_%d" % made
		merged.mesh = st.commit()
		merged.material_override = key[1]
		merged.cast_shadow = list[0].cast_shadow
		if key[2]:
			merged.visibility_range_end = SMALL_RANGE
			merged.visibility_range_end_margin = 5.0
		root.add_child(merged)
		for mi: MeshInstance3D in list:
			mi.queue_free()
		made += 1
	return {"merged_from": count, "merged_into": made}


static func _size(mi: MeshInstance3D) -> float:
	var size := mi.get_aabb().size * mi.global_basis.get_scale().abs()
	return maxf(size.x, maxf(size.y, size.z))


static func _mergeable(mi: MeshInstance3D, root: Node) -> bool:
	if mi.mesh == null or mi.material_override == null or not mi.visible:
		return false
	var n: Node = mi.get_parent()
	while n != null and n != root:
		if n is DistrictGate or n is CPUParticles3D or SKIP_NAMES.has(String(n.name)) or String(n.name).begins_with("upgrade_"):
			return false
		n = n.get_parent()
	return true
