class_name SurvivalMenus
extends RefCounted
## The bag, shop and stash menus (design/gdd/survival.md). Display only: every change goes through
## SurvivalController, and the menus are rebuilt from its state after each action.

var survival: SurvivalController
var hud: Hud
var player: Player
var progression: ProgressionState
## Called when a menu closes (the session restores input and the mouse).
var on_close: Callable = func(): pass


func _init(p_survival: SurvivalController, p_hud: Hud, p_player: Player, p_progression: ProgressionState) -> void:
	survival = p_survival
	hud = p_hud
	player = p_player
	progression = p_progression


func _open(title: String, items: Array) -> void:
	items.append({"text": "Close", "action": close})
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.open_menu(title, items)


func close() -> void:
	on_close.call()


func _line(id: String, n: int) -> String:
	var item := survival.config.item(id)
	return "%s x%d   (%.1f kg each)" % [item.name, n, float(item.weight)]


func bag_title() -> String:
	var n := survival.needs
	return "BAG  %.1f / %.0f kg   ·   Food %d  Water %d  Rest %d%s" % [survival.bag.weight(), survival.bag.capacity,
		int(n.food), int(n.water), int(n.rest), ("   ·   Bleeding x%d" % survival.wounds.bleeding) if survival.wounds.bleeding > 0 else ""]


## The bag: tap an item to use it (food, drink, medical). `at_safehouse` adds stash entries.
func open_bag(at_safehouse := false) -> void:
	var items: Array = []
	for id in survival.bag.ids():
		var item := survival.config.item(id)
		var usable: bool = not (item.get("effects", {}) as Dictionary).is_empty()
		items.append({"text": ("Use: " if usable else "") + _line(id, survival.bag.count(id)), "disabled": not usable,
			"action": func():
				hud.show_message(survival.use_item(id))
				open_bag(at_safehouse)})
		if at_safehouse:
			items.append({"text": "      put one in the stash", "disabled": not survival.stash.can_add(id),
				"action": func():
					survival.bag.move_to(survival.stash, id)
					open_bag(true)})
		else:
			items.append({"text": "      drop one", "action": func():
				hud.show_message(survival.drop_item(id))
				open_bag(false)})
	if items.is_empty():
		items.append({"text": "Your bag is empty.", "disabled": true, "action": func(): pass})
	if at_safehouse:
		for id in survival.stash.ids():
			items.append({"text": "Stash: take %s" % _line(id, survival.stash.count(id)), "disabled": not survival.bag.can_add(id),
				"action": func():
					survival.stash.move_to(survival.bag, id)
					open_bag(true)})
	items.append({"text": "Skills", "action": open_skills})
	_open(bag_title(), items)


func open_skills() -> void:
	var items: Array = []
	for id in survival.config.skill_ids():
		var s := survival.config.skill(str(id))
		var lvl := survival.skills.level(str(id))
		items.append({"text": "%s   level %d / %d   (%d%% to next)" % [s.get("name", id), lvl, int(survival.config.num("max_level", 5.0)),
			int(survival.skills.progress(str(id)) * 100.0)], "disabled": true, "action": func(): pass})
	items.append({"text": "Back to the bag", "action": func(): open_bag(false)})
	_open("SKILLS  (they grow as you use them)", items)


## A shop counter: buy from its stock, sell junk and valuables.
func open_shop(shop_name: String, kind := "shop") -> void:
	var items: Array = []
	for id in survival.config.shop_stock.get(kind, []):
		var item := survival.config.item(str(id))
		if item.is_empty():
			continue
		var price := int(item.price)
		items.append({"text": "Buy %s  —  R%d" % [item.name, price], "disabled": progression.cash < price or not survival.bag.can_add(str(id)),
			"action": func():
				hud.show_message(survival.buy(str(id)))
				open_shop(shop_name, kind)})
	for id in survival.bag.ids():
		var item := survival.config.item(id)
		if str(item.kind) in ["junk", "valuable"]:
			items.append({"text": "Sell %s x%d  —  R%d each" % [item.name, survival.bag.count(id), int(item.sell)],
				"action": func():
					hud.show_message(survival.sell(id))
					open_shop(shop_name, kind)})
	_open("%s   (R%d · bag %.1f / %.0f kg)" % [shop_name.to_upper(), progression.cash, survival.bag.weight(), survival.bag.capacity], items)
