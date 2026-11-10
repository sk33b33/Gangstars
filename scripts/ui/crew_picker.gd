class_name CrewPicker
extends Control
## "Who do you run with?" Shown at the start of a new game (or for a save from before crews
## existed). One card per crew: colour, home suburb, boss, what they're like and their perk.
## Mouse, keyboard or pad (focus starts on the first card's button).

signal chosen(crew_id: String)

var _row: HBoxContainer


func open(catalog: CrewCatalog, district: District) -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	box.add_child(_text("WHO DO YOU RUN WITH?", 34, Color("#ffd75e"), true))
	box.add_child(_text("You start in Westridge either way. Your crew are your allies; the others are rivals on their own turf.\nAll crews are fictional.", 16, Color("#c9c6bf"), true))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 14)
	box.add_child(_row)
	var first: Button = null
	for crew in catalog.crews:
		var b := _card(crew, catalog, district)
		if first == null:
			first = b
	visible = true
	if first:
		(func(): if is_instance_valid(first): first.grab_focus()).call_deferred()


func close() -> void:
	visible = false


func button(crew_id: String) -> Button:
	return find_child("Join_" + crew_id, true, false) as Button


func _card(crew: Dictionary, catalog: CrewCatalog, district: District) -> Button:
	var id := str(crew.id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a1c22")
	style.border_color = catalog.colour(id)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	_row.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var bar := ColorRect.new()
	bar.color = catalog.colour(id)
	bar.custom_minimum_size = Vector2(0, 10)
	v.add_child(bar)
	v.add_child(_text(str(crew.name).to_upper(), 22, Color.WHITE))
	v.add_child(_text("Home: " + str(crew.get("home_name", "")), 14, Color("#9fd8b8")))
	var boss: Resident = district.residents.get(str(crew.get("boss", "")))
	if boss:
		v.add_child(_text("Boss: " + boss.data.display_name, 14, Color("#c9c6bf")))
	v.add_child(_text(str(crew.get("pitch", "")), 14, Color("#c9c6bf")))
	v.add_child(_text(str(crew.get("perk_text", "")), 14, Color("#ffd75e")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var b := Button.new()
	b.name = "Join_" + id
	b.text = "Join the %s" % crew.name
	b.pressed.connect(func(): chosen.emit(id))
	v.add_child(b)
	return b


static func _text(t: String, size: int, colour: Color, centred := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(226, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(1060, 0)
	return l
