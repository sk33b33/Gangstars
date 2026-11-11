class_name Phone
extends Control
## The cellphone (P / D-pad up): contacts with their mood, open orders with time left, stock,
## a "SAPS nearby" warning, and incoming calls (Answer / Decline). A small ringing badge shows
## on screen while a client is calling. Mouse, keyboard or pad.

signal closed

var dealing: DealingController
var _panel: PanelContainer
var _list: VBoxContainer
var _badge: Label
var _tab := "contacts"


func setup(p_dealing: DealingController) -> void:
	dealing = p_dealing
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge = Label.new()
	_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_badge.offset_left = -430
	_badge.offset_top = -70
	_badge.offset_right = -20
	_badge.offset_bottom = -40
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge.add_theme_font_size_override("font_size", 22)
	_badge.add_theme_color_override("font_color", Color("#7fd1ff"))
	_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_badge.add_theme_constant_override("outline_size", 6)
	_badge.visible = false
	add_child(_badge)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -440
	_panel.offset_right = -20
	_panel.offset_top = 90
	_panel.offset_bottom = -90
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14161c")
	style.border_color = Color("#7fd1ff")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(380, 0)
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_panel.visible = true
	_tab = "call" if not dealing.state.call.is_empty() else _tab
	refresh()


func close() -> void:
	_panel.visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if dealing == null:
		return
	var c := dealing.state.call
	_badge.visible = not c.is_empty() and not _panel.visible
	if _badge.visible:
		_badge.text = "%s is calling…  [%s] phone" % [str(dealing.state.clients.get(c.npc, {}).get("name", "Someone")), InputHints.key("phone")]
		_badge.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 250.0))


func refresh() -> void:
	if not _panel.visible:
		return
	for c in _list.get_children():
		c.queue_free()
	var st := dealing.state
	_label("PHONE", 26, Color("#7fd1ff"))
	_label("Stock: %d %s · %d %s" % [int(st.stock.weed), "bankie" if int(st.stock.weed) == 1 else "bankies",
		int(st.stock.drink), "drink" if int(st.stock.drink) == 1 else "drinks"], 16, Color("#ffd75e"))
	var here := dealing.district.area_at(dealing.player.global_position)
	var m := dealing.price_mult(here if not here.is_empty() else "starter")
	_label("Street prices here: bankie R%d · drink R%d  (%s)%s" % [st.price("weed", m), st.price("drink", m),
		"x%.2f" % m, "  · %d runner%s" % [st.runners, "" if st.runners == 1 else "s"] if st.runners > 0 else ""], 14, Color("#c9c6bf"))
	for d in st.drops:
		var wait := float(d.ready) - dealing.minutes()
		_label("Drop: %d %s at %s — %s" % [int(d.qty), dealing._plural(str(d.product), int(d.qty)), dealing.district.destinations.display_name(str(d.at)),
			"ready" if wait <= 0.0 else "in %d min" % int(ceil(wait))], 14, Color("#9fd8b8"))
	if dealing.police_watching(dealing.player.global_position):
		_label("!! SAPS nearby. Don't deal here.", 16, Color("#ff6b6b"))
	var tabs := HBoxContainer.new()
	_list.add_child(tabs)
	var first: Button = null
	for t in ["contacts", "orders"]:
		var b := Button.new()
		b.name = "Tab_" + t
		b.text = ("Contacts (%d)" % st.stat("contacts")) if t == "contacts" else ("Orders (%d)" % st.orders.size())
		b.toggle_mode = true
		b.button_pressed = _tab == t
		b.pressed.connect(func(): _tab = t; refresh())
		tabs.add_child(b)
		if first == null:
			first = b
	if not st.call.is_empty():
		first = _call_view()
	elif _tab == "orders":
		_orders_view()
	else:
		_contacts_view()
	var close_b := Button.new()
	close_b.text = "Put the phone away (%s)" % InputHints.key("phone")
	close_b.pressed.connect(close)
	_list.add_child(close_b)
	if first:
		(func(): if is_instance_valid(first): first.grab_focus()).call_deferred()


func _call_view() -> Button:
	var c := dealing.state.call
	var client: Dictionary = dealing.state.clients.get(c.npc, {})
	_row(str(c.npc), "%s is calling" % str(client.get("name", "Someone")),
		"Wants %d %s at %s." % [int(c.qty), dealing._plural(str(c.product), int(c.qty)), dealing.district.destinations.display_name(str(c.place))])
	var answer := Button.new()
	answer.name = "Answer"
	answer.text = "Answer and take the order"
	answer.pressed.connect(func():
		var note := dealing.answer()
		dealing.message.emit(note)
		_tab = "orders"
		refresh())
	_list.add_child(answer)
	var decline := Button.new()
	decline.name = "Decline"
	decline.text = "Decline (they won't like it)"
	decline.pressed.connect(func(): dealing.decline(); refresh())
	_list.add_child(decline)
	return answer


func _orders_view() -> void:
	var st := dealing.state
	if st.orders.is_empty():
		_label("No open orders. Clients call when they want something.", 15, Color("#c9c6bf"))
	for o in st.orders:
		var left := maxf(0.0, float(o.deadline) - dealing.minutes())
		var each := st.price(str(o.product), dealing.client_mult(str(o.npc)))
		_row(str(o.npc), "%s — %d %s (R%d each)" % [str(st.clients[o.npc].name), int(o.qty), dealing._plural(str(o.product), int(o.qty)), each],
			"At %s · %d:%02d left%s" % [dealing.district.destinations.display_name(str(o.place)), int(left / 60.0), int(fmod(left, 60.0)),
				"  · your runner's on it" if o.has("runner_at") else ""])
		if st.runners > 0 and not o.has("runner_at"):
			var b := Button.new()
			b.name = "Runner_" + str(o.npc)
			b.text = "Send your runner (%d free) — %d%% safe" % [st.runners - st.runners_busy(), int(dealing.runner_success(str(o.npc)) * 100)]
			b.disabled = st.runners_busy() >= st.runners
			b.pressed.connect(func():
				dealing.message.emit(dealing.send_runner(str(o.npc)))
				refresh())
			_list.add_child(b)


func _contacts_view() -> void:
	var st := dealing.state
	if st.clients.is_empty():
		_label("No contacts yet. Chat to people around Westridge; some will ask for your number.", 15, Color("#c9c6bf"))
	for npc in st.clients:
		var c: Dictionary = st.clients[npc]
		if c.status == "lost":
			_row(npc, str(c.name), "Buying from the %s now." % str(c.rival))
			var b := Button.new()
			b.text = "Win them back: a free %s" % dealing._plural(str(c.product), 1)
			b.disabled = int(st.stock.get(c.product, 0)) < 1
			b.pressed.connect(func():
				if st.win_back(npc):
					dealing.message.emit("%s is back with you." % str(c.name))
				refresh())
			_list.add_child(b)
		else:
			var house := dealing.district.registry.get_house(str(c.home))
			_row(npc, str(c.name), "Wants %s · %s" % [dealing._plural(str(c.product), 2), house.address() if house else ""])


func _row(npc: String, title: String, sub: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = DealingController.mood_texture(dealing.state.mood_icon(npc))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_child(_mk(title, 17, Color.WHITE))
	v.add_child(_mk(sub, 13, Color("#c9c6bf")))
	h.add_child(v)
	_list.add_child(h)


func _label(t: String, size: int, colour: Color) -> void:
	_list.add_child(_mk(t, size, colour))


static func _mk(t: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(330, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
