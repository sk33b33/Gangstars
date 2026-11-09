class_name DebugOverlay
extends Node3D
## F3 debug view: navigation mesh, NPC paths and targets, destination anchors, and a text
## panel with each NPC's id/state/home/destination/path status/last transition/tier.
## F4 runs the house -> destination reachability check.

const TEXT_INTERVAL := 0.25

var district: District
var hud: Hud
var _lines: MeshInstance3D
var _navmesh_view: MeshInstance3D
var _line_mat: StandardMaterial3D
var _text_timer := 0.0
var _reach_text := ""


func setup(p_district: District, p_hud: Hud) -> void:
	district = p_district
	hud = p_hud
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.vertex_color_use_as_albedo = true
	_line_mat.no_depth_test = true
	_lines = MeshInstance3D.new()
	_lines.mesh = ImmediateMesh.new()
	add_child(_lines)
	visible = false


func toggle() -> void:
	visible = not visible
	hud.set_debug_visible(visible)
	for r in district.residents.values():
		r.name_label.visible = visible
	if visible and _navmesh_view == null and district.is_navigation_ready:
		_build_navmesh_view()


func run_reachability() -> String:
	var rep := district.reachability_report()
	_reach_text = "Reachability: %d ok, %d failed %s" % [rep.ok, rep.failed.size(), ", ".join(rep.failed)]
	return _reach_text


func _process(delta: float) -> void:
	if not visible or district == null:
		return
	_draw_paths()
	_text_timer -= delta
	if _text_timer <= 0.0:
		_text_timer = TEXT_INTERVAL
		hud.set_debug_text(_text())


func _draw_paths() -> void:
	var im: ImmediateMesh = _lines.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	var lift := Vector3(0, 0.15, 0)
	for r: Resident in district.residents.values():
		var path := r.current_path()
		im.surface_set_color(r.data.shirt_color)
		for i in range(path.size() - 1):
			im.surface_add_vertex(path[i] + lift)
			im.surface_add_vertex(path[i + 1] + lift)
		if not r.is_inside and r.path_status == "moving":
			var t := r.agent.target_position
			im.surface_add_vertex(t)
			im.surface_add_vertex(t + Vector3(0, 2.5, 0))
	im.surface_set_color(Color.YELLOW)
	for id in district.destinations.ids_of_kind("house_door") + district.destinations.ids_of_kind("shop") \
			+ district.destinations.ids_of_kind("transit") + district.destinations.ids_of_kind("gathering") \
			+ district.destinations.ids_of_kind("park"):
		var p := district.destinations.anchor_position(id)
		im.surface_add_vertex(p + Vector3(-0.3, 0.05, 0))
		im.surface_add_vertex(p + Vector3(0.3, 0.05, 0))
		im.surface_add_vertex(p + Vector3(0, 0.05, -0.3))
		im.surface_add_vertex(p + Vector3(0, 0.05, 0.3))
	im.surface_end()


func _build_navmesh_view() -> void:
	var nm := district.nav_region.navigation_mesh
	var verts := nm.get_vertices()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		for k in range(1, poly.size() - 1):
			# Both windings so the overlay is visible from above regardless of order.
			for idx in [poly[0], poly[k], poly[k + 1], poly[0], poly[k + 1], poly[k]]:
				st.add_vertex(verts[idx] + Vector3(0, 0.05, 0))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.9, 0.4, 0.28)
	_navmesh_view = MeshInstance3D.new()
	_navmesh_view.mesh = st.commit()
	_navmesh_view.material_override = mat
	add_child(_navmesh_view)


func _text() -> String:
	var lines: PackedStringArray = ["DEBUG  fps %d  npcs %d  nav polys %d" % [
		Engine.get_frames_per_second(), district.residents.size(),
		district.nav_region.navigation_mesh.get_polygon_count() if district.nav_region.navigation_mesh else 0]]
	for r: Resident in district.residents.values():
		lines.append("%s  [%s]  home %s  -> %s\n    path: %s | arrivals %d | tier %s\n    last: %s" % [
			r.data.id, r.state_name(), r.data.home_id, r.target_id if not r.target_id.is_empty() else "-",
			r.path_status, r.arrivals, r.sim_tier, r.brain.last_transition])
	if not _reach_text.is_empty():
		lines.append(_reach_text)
	return "\n".join(lines)
