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
var turf: TurfWar

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
	scroll.follow_focus = true  # D-pad focus scrolls the requirements list
	row.add_child(scroll)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(400, 0)
	_side.add_theme_constant_override("separation", 6)
	scroll.add_child(_side)
	# The map covers every built area plus a 40 m strip for neighbours that aren't built yet.
	_world_rect = district.real.data.bounds.grow(30.0)
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
	_add_label("Westridge — %s" % starter_state.to_upper(), 20, Color("#5fbf6a") if starter_state == "controlled" else Color("#f1c40f"))
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
	var focused := false
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
				focused = true
		else:
			_add_label("Open: walk through the gate on the %s side." % d.side, 16, Color("#9fd8b8"))
	if turf and not turf.state.order.is_empty():
		_side.add_child(HSeparator.new())
		_add_label("Corners (stand on one to take it; crew-mates help)", 20, Color("#ffd75e"))
		for id in turf.state.order:
			var c: Dictionary = turf.state.corners[id]
			var mine := turf.state.is_players(id)
			var line := "%s — %s %d%%" % [str(c.name).capitalize(), "YOURS" if mine else turf.crew_name(str(c.owner)), int(c.control)]
			if turf.state.pushed(id):
				line += "  ·  the %s are pushing!" % turf.crew_name(str(c.push_crew))
			var col: Color = Color("#9fd8b8") if mine else (district.crews.colour(str(c.owner)) if not str(c.owner).is_empty() else Color("#c9c6bf"))
			_add_label(line, 15, Color("#e2585e") if turf.state.pushed(id) else col)
	var future := manager.planned()
	if not future.is_empty():
		_side.add_child(HSeparator.new())
		_add_label("The rest of Mitchells Plain", 20, Color("#c9c6bf"))
		for d in future:
			var reqs: Array = manager.get_unlock_requirements(str(d.id))
			var need := " · ".join(reqs.map(func(r): return r.text))
			_add_label("%s — coming later" % d.display_name, 16, Color("#8a8f99"))
			_add_label("%s\nWill need: %s" % [str(d.get("description", "")), need], 13, Color("#8a8f99"))
	var close_btn := Button.new()
	close_btn.text = "Close (M / Esc · B on a pad)"
	close_btn.pressed.connect(close)
	_side.add_child(close_btn)
	if not focused:
		_focus_later(close_btn)  # something must hold focus so a pad can move through the list
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


## The map: the real suburb with its streets, the game's homes by turf state, the parts
## of Westridge (locked ones tinted), places, corners, crew and you.
func _draw_real() -> void:
	var font := ThemeDB.fallback_font
	var data := district.real.data
	_canvas.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("#22303a"))
	var land := PackedVector2Array()
	for p in data.boundary:
		land.append(_to_map(Vector3(p.x, 0, p.y)))
	_canvas.draw_colored_polygon(land, Color("#3a3326"))
	for key in data.chunk_keys:
		for line: PackedVector2Array in data.road_lines(key):
			var pts := PackedVector2Array()
			for p in line:
				pts.append(_to_map(Vector3(p.x, 0, p.y)))
			_canvas.draw_polyline(pts, Color("#6b6b72"), 1.0)
	# The parts of Westridge: a ring at each one's heart, in its state's colour.
	var all: Array = [{"id": "starter", "display_name": district.info.get("display_name", "Westridge")}]
	all.append_array(manager.neighbours())
	for d in all:
		var area := district.area_by_id(str(d.id))
		if area.is_empty():
			continue
		var at := DataFiles.to_vec2(area.get("anchor"))
		var m := _to_map(Vector3(at.x, 0, at.y))
		var st := "controlled" if str(d.id) == "starter" else manager.state(str(d.id))
		var col: Color = DISTRICT_COLORS.get(st, Color.GRAY)
		_canvas.draw_circle(m, 26.0, Color(col, 0.16))
		_canvas.draw_arc(m, 26.0, 0.0, TAU, 40, col, 2.0)
		var text := "%s · %s" % [str(d.display_name).to_upper(), st.to_upper()]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var pos := m + Vector2(-tw * 0.5, -31)
		_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("#1d1b24"))
		_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	for id in district.registry.order:
		var house := district.registry.get_house(id)
		var m := _to_map(Vector3(house.position.x, 0, house.position.y))
		_canvas.draw_rect(Rect2(m - Vector2(2.5, 2.5), Vector2(5, 5)), STATE_COLORS.get(manager.house_state(house), Color.GRAY))
	for area in district.areas:
		for poi in area.get("pois", []):
			var pp := DataFiles.to_vec2(poi.get("position"))
			_canvas.draw_circle(_to_map(Vector3(pp.x, 0, pp.y)), 2.5, Color("#2e86c1"))
	if turf:
		for id in turf.state.order:
			var c: Dictionary = turf.state.corners[id]
			var m := _to_map(turf.anchor(id))
			var col: Color = district.crews.colour(str(c.owner)) if not str(c.owner).is_empty() else Color("#f4f1ea")
			_canvas.draw_arc(m, 6.0, 0.0, TAU * float(c.control) / 100.0, 20, col, 2.5)
			if turf.state.pushed(id):
				_canvas.draw_arc(m, 9.0, 0.0, TAU, 20, Color("#e2585e"), 2.0)
	for r: Resident in district.residents.values():
		if r.data.role == "player_crew" and not r.is_inside:
			_canvas.draw_circle(_to_map(r.global_position), 3.0, Color("#e2585e"))
	if player:
		var p := _to_map(player.global_position)
		_canvas.draw_circle(p, 4.0, Color.WHITE)
		_canvas.draw_arc(p, 7.0, 0.0, TAU, 20, Color.WHITE, 1.5)
	_canvas.draw_string(font, Vector2(8, 16), "N ↑   Westridge (real map)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	_canvas.draw_string(font, Vector2(8, MAP_SIZE.y - 5), data.credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.7))


func _draw_map() -> void:
	_draw_real()
