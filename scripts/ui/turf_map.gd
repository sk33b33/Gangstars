class_name TurfMap
extends Control
## Turf screen (M): a top-down map of the district (houses coloured by turf state, landmarks,
## player and crew, locked neighbours) and a side panel with starter influence and each
## neighbouring district's requirements. The Unlock button only *requests* an unlock; the
## DistrictManager decides (via the `unlock_requested` signal handled by the session).

signal unlock_requested(district_id: String)
signal closed

const STATE_COLORS := {
	"player": Color("#e2585e"), "friendly": Color("#5fbf6a"), "hostile": Color("#8e44ad"),
	"neutral": Color("#c9c6bf"), "vacant": Color("#6d7177"),
}
const DISTRICT_COLORS := {"locked": Color("#c0392b"), "unlockable": Color("#f1c40f"), "unlocked": Color("#5fbf6a"),
	"contested": Color("#e67e22"), "controlled": Color("#5fbf6a")}
const AREA_GROUND := {"starter": Color("#d9c49a")}
const MAP_SIZE := Vector2(640, 520)

var district: District
var manager: DistrictManager
var player: Node3D

var _canvas: Control
var _side: VBoxContainer
var _world_rect := Rect2()
var _map_scale := 1.0
var _map_offset := Vector2.ZERO


func setup(p_district: District, p_manager: DistrictManager, p_player: Node3D) -> void:
	district = p_district
	manager = p_manager
	player = p_player
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -320
	panel.offset_bottom = 320
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_color = Color("#ffd75e")
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	_canvas = Control.new()
	_canvas.custom_minimum_size = MAP_SIZE
	_canvas.draw.connect(_draw_map)
	row.add_child(_canvas)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(400, 0)
	_side.add_theme_constant_override("separation", 6)
	scroll.add_child(_side)
	# The map covers every built area plus a 40 m strip for neighbours that aren't built yet.
	var r := Rect2()
	for i in district.areas.size():
		var ab: Array = district.areas[i].get("bounds", [-72, -78, 72, 22])
		var ar := Rect2(ab[0], ab[1], ab[2] - ab[0], ab[3] - ab[1])
		r = ar if i == 0 else r.merge(ar)
	_world_rect = r.grow_individual(40.0, 6.0, 6.0, 6.0)
	_map_scale = minf(MAP_SIZE.x / _world_rect.size.x, MAP_SIZE.y / _world_rect.size.y)
	_map_offset = (MAP_SIZE - _world_rect.size * _map_scale) * 0.5
	visible = false


func open() -> void:
	refresh()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	for c in _side.get_children():
		_side.remove_child(c)
		c.queue_free()
	_add_label("TURF", 28, Color("#ffd75e"))
	var starter_state := manager.state("starter")
	_add_label("Vleirand — %s" % starter_state.to_upper(), 20, Color("#5fbf6a") if starter_state == "controlled" else Color("#f1c40f"))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = manager.influence("starter")
	bar.custom_minimum_size = Vector2(380, 20)
	_side.add_child(bar)
	_add_label("Influence %d%% = %d from missions and upgrades + %d from %d friendly houses" % [
		manager.influence("starter"), manager.progression.district_influence("starter"),
		manager.friendly_houses() * DistrictManager.FRIENDLY_HOUSE_INFLUENCE, manager.friendly_houses()], 14, Color("#c9c6bf"))
	_add_legend()
	for d in manager.neighbours():
		var id := str(d.id)
		var st := manager.state(id)
		_side.add_child(HSeparator.new())
		_add_label("%s (%s) — %s" % [d.display_name, d.side, st.to_upper()], 20, DISTRICT_COLORS.get(st, Color.WHITE))
		_add_label(str(d.get("description", "")), 14, Color("#c9c6bf"))
		if not manager.is_unlocked(id):
			for r in manager.get_unlock_requirements(id):
				_add_label(("✓ " if r.met else "✗ ") + r.text, 16, Color("#9fd8b8") if r.met else Color("#e2585e"))
			var btn := Button.new()
			btn.name = "Unlock_" + id
			btn.text = "Unlock %s" % d.display_name if st == "unlockable" else "Locked"
			btn.disabled = st != "unlockable"
			btn.pressed.connect(func(): unlock_requested.emit(id))
			_side.add_child(btn)
			if st == "unlockable":
				_focus_later(btn)
		else:
			_add_label("Open: walk through the gate on the %s side." % d.side, 16, Color("#9fd8b8"))
	var close_btn := Button.new()
	close_btn.text = "Close (M / Esc)"
	close_btn.pressed.connect(close)
	_side.add_child(close_btn)
	_canvas.queue_redraw()


static func _focus_later(c: Control) -> void:
	(func(): if is_instance_valid(c) and c.is_inside_tree(): c.grab_focus()).call_deferred()


## Text of the side panel, for tests and accessibility.
func panel_text() -> String:
	var parts: PackedStringArray = []
	for c in _side.get_children():
		if c is Label:
			parts.append(c.text)
		elif c is Button:
			parts.append("[%s%s]" % [c.text, " (disabled)" if c.disabled else ""])
	return "\n".join(parts)


func unlock_button(district_id: String) -> Button:
	return _side.get_node_or_null("Unlock_" + district_id)


func _process(_delta: float) -> void:
	if visible:
		_canvas.queue_redraw()  # player/crew markers move


func _add_label(text: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(390, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_side.add_child(l)


func _add_legend() -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	for key in ["player", "friendly", "neutral", "hostile", "vacant"]:
		var l := Label.new()
		l.text = "■ " + {"player": "yours", "friendly": "friendly", "neutral": "neutral", "hostile": "rival", "vacant": "empty"}[key]
		l.add_theme_color_override("font_color", STATE_COLORS[key])
		l.add_theme_font_size_override("font_size", 14)
		grid.add_child(l)
	_side.add_child(grid)


func _to_map(p: Vector3) -> Vector2:
	return _map_offset + (Vector2(p.x, p.z) - _world_rect.position) * _map_scale


func _draw_map() -> void:
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("#3a3326"))
	var b: Array = district.info.get("bounds", [-72, -78, 72, 22])
	for area in district.areas:
		var ab: Array = area.get("bounds", b)
		var ar := Rect2(_to_map(Vector3(ab[0], 0, ab[1])), Vector2(ab[2] - ab[0], ab[3] - ab[1]) * _map_scale)
		_canvas.draw_rect(ar, AREA_GROUND.get(str(area.id), Color("#d8a07a")))
	# Neighbouring districts: their real area if built, otherwise a strip beside Vleirand.
	var overlays: Array = []
	var labels: Array = []
	for d in manager.neighbours():
		var st := manager.state(str(d.id))
		var area := district.area_by_id(str(d.id))
		var zone: Rect2
		if not area.is_empty():
			var ab: Array = area.bounds
			zone = Rect2(_to_map(Vector3(ab[0], 0, ab[1])), Vector2(ab[2] - ab[0], ab[3] - ab[1]) * _map_scale)
			if not manager.is_unlocked(str(d.id)):
				overlays.append([zone, DISTRICT_COLORS.get(st, Color.GRAY)])
		else:
			var east: bool = d.side == "east"
			var zx: float = b[2] if east else b[0] - 40.0
			zone = Rect2(_to_map(Vector3(zx, 0, b[1])), Vector2(40.0, b[3] - b[1]) * _map_scale)
		var col: Color = DISTRICT_COLORS.get(st, Color.GRAY)
		_canvas.draw_rect(zone, Color(col, 0.25))
		_canvas.draw_rect(zone, col, false, 2.0)
		labels.append([zone, "%s · %s" % [str(d.display_name).to_upper(), st.to_upper()], col])
	# Streets (all areas).
	var all_streets: Array = []
	var all_pois: Array = []
	for area in district.areas:
		all_streets.append_array(area.get("streets", []))
		all_pois.append_array(area.get("pois", []))
	for s in all_streets:
		var hw: float = s.get("half_width", 4.0)
		var a0 := maxf(minf(s.from, s.to), _world_rect.position.x)
		var a1 := minf(maxf(s.from, s.to), _world_rect.end.x)
		var r: Rect2
		if s.axis == "x":
			r = Rect2(_to_map(Vector3(a0, 0, s.at - hw)), Vector2(a1 - a0, hw * 2) * _map_scale)
		else:
			r = Rect2(_to_map(Vector3(s.at - hw, 0, a0)), Vector2(hw * 2, a1 - a0) * _map_scale)
		_canvas.draw_rect(r, Color("#4a4a50"))
	# Houses by turf state.
	for id in district.registry.order:
		var house := district.registry.get_house(id)
		var t := house.plot_transform()
		var hw2 := house.plot_size.x * 0.5
		var poly := PackedVector2Array()
		for c in [Vector3(-hw2, 0, 0), Vector3(hw2, 0, 0), Vector3(hw2, 0, -house.plot_size.y), Vector3(-hw2, 0, -house.plot_size.y)]:
			poly.append(_to_map(t * c))
		_canvas.draw_colored_polygon(poly, STATE_COLORS.get(manager.house_state(house), Color.GRAY))
		poly.append(poly[0])
		_canvas.draw_polyline(poly, Color("#1d1b24"), 1.0)
	# Landmarks.
	for poi in all_pois:
		var pp := DataFiles.to_vec2(poi.get("position"))
		var m := _to_map(Vector3(pp.x, 0, pp.y))
		_canvas.draw_circle(m, 5.0, Color("#2e86c1"))
		_canvas.draw_string(font, m + Vector2(7, 4), str(poi.get("map_label", poi.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	for ov in overlays:
		_canvas.draw_rect(ov[0], Color(ov[1], 0.45))
		_canvas.draw_rect(ov[0], ov[1], false, 2.0)
	# District names last, centred just above each zone so houses and landmarks never cover them.
	for lb in labels:
		var zr: Rect2 = lb[0]
		var pos := Vector2(zr.position.x, zr.position.y - 8)
		_canvas.draw_string_outline(font, pos, lb[1], HORIZONTAL_ALIGNMENT_CENTER, zr.size.x, 14, 4, Color("#1d1b24"))
		_canvas.draw_string(font, pos, lb[1], HORIZONTAL_ALIGNMENT_CENTER, zr.size.x, 14, lb[2])
	# Crew and player.
	for r: Resident in district.residents.values():
		if r.data.role == "player_crew" and not r.is_inside:
			_canvas.draw_circle(_to_map(r.global_position), 4.0, Color("#e2585e"))
	if player:
		var p := _to_map(player.global_position)
		var f: Vector3 = player.facing_dir() if player.has_method("facing_dir") else Vector3.FORWARD
		var fwd := Vector2(f.x, f.z).normalized() * 9.0
		var side := Vector2(-fwd.y, fwd.x) * 0.6
		_canvas.draw_colored_polygon(PackedVector2Array([p + fwd, p - fwd * 0.6 + side, p - fwd * 0.6 - side]), Color.WHITE)
	_canvas.draw_string(font, Vector2(8, MAP_SIZE.y - 8), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
