class_name SurvivalController
extends Node
## Runs the survival layer (design/gdd/survival.md): needs, the bag and stash, wounds, skills and
## search spots. Owns the pure-logic classes, feeds them game time and player events, and applies
## their effects to the player. No UI here: it emits `message` and `changed`; menus live in
## SurvivalMenus.

signal message(text: String)
signal banner(text: String)
signal changed            # anything the HUD line shows

const SEARCH_RANGE := 3.0

var config: SurvivalConfig
var needs: Needs
var bag: Inventory
var stash: Inventory
var wounds: Wounds
var skills: Skills
var loot: Loot

var player: Player
var clock: SimClock
var progression: ProgressionState
## Returns the police heat level (0 = none); set by the session.
var heat_level: Callable = func() -> int: return 0

var _last_minutes := -1.0
var _last_pos := Vector3.ZERO
var _sprint_m := 0.0
var _drive_m := 0.0
var _search := {}          # {id, table, left, at}
var _spots := {}           # spot id -> Interactable


func setup(p_player: Player, p_clock: SimClock, p_progression: ProgressionState) -> void:
	player = p_player
	clock = p_clock
	progression = p_progression
	config = SurvivalConfig.load_default()
	needs = Needs.new(config)
	bag = Inventory.new(config, config.num("bag_capacity", 10.0))
	stash = Inventory.new(config, config.num("stash_capacity", 60.0))
	wounds = Wounds.new(config)
	skills = Skills.new(config)
	loot = Loot.new(config)
	reset()
	needs.warned.connect(func(n: String): message.emit({"food": "You're getting hungry.", "water": "You're thirsty.", "rest": "You're tired. Sleep at your safehouse."}[n]))
	needs.emptied.connect(func(n: String): message.emit({"food": "You're starving. Eat something.", "water": "You badly need a drink.", "rest": "You're exhausted: no more running until you sleep."}[n]))
	skills.levelled.connect(func(s: String, lvl: int): banner.emit("%s level %d" % [str(config.skill(s).get("name", s)), lvl]))
	for sig in [bag.changed, wounds.changed]:
		sig.connect(func(): changed.emit())
	player.health.hurt.connect(_on_player_hurt)
	player.knocked_out.connect(func():
		wounds.bandage_all()
		needs.wake_up())
	_last_pos = player.global_position


## A new game: full needs, the starter items, no wounds, no skills.
func reset() -> void:
	needs.load_dict({})
	bag.load_dict(config.values.get("starter_items", {}))
	stash.load_dict({})
	wounds.load_dict({"bleeding": 0})
	skills.load_dict({})
	loot.load_dict({})
	_last_minutes = -1.0


func total_minutes() -> float:
	return clock.day * 1440.0 + clock.minutes


func _physics_process(delta: float) -> void:
	if player == null or clock == null:
		return
	var now := total_minutes()
	var hours := 0.0 if _last_minutes < 0.0 else maxf(0.0, now - _last_minutes) / 60.0
	_last_minutes = now
	if hours > 2.0:
		hours = 0.0   # the clock jumped (sleep, load, debug): sleeping charges its own drain
	var moved := player.global_position.distance_to(_last_pos)
	_last_pos = player.global_position
	if moved > 20.0:
		moved = 0.0   # teleport
	var sprinting := false
	if player.is_driving():
		_drive_m += moved
		while _drive_m >= 100.0:
			_drive_m -= 100.0
			skills.add("driving", "per_100m")
	elif player.is_sprinting():
		sprinting = true
		_sprint_m += moved
		while _sprint_m >= 50.0:
			_sprint_m -= 50.0
			skills.add("fitness", "per_50m")
	needs.drain(hours, sprinting, false, 1.0 - skills.bonus("fitness", "rest_bonus"))
	wounds.tick_hours(hours)
	_apply_health(delta, hours)
	_apply_to_player()
	_tick_search(delta)
	if Engine.get_physics_frames() % 30 == 0:
		changed.emit()


func _apply_health(delta: float, hours: float) -> void:
	var h := player.health
	h.regen_blocked = wounds.bleeding > 0 or needs.starving()
	if h.down:
		return
	h.hp -= wounds.bleed_damage(delta, h.hp)
	if needs.starving():
		var floor_hp := config.num("starve_floor", 20.0)
		if h.hp > floor_hp:
			h.hp = maxf(floor_hp, h.hp - config.num("starve_per_minute", 0.5) * hours * 60.0)


func _apply_to_player() -> void:
	player.speed_factor = wounds.speed_factor() * (config.num("tired_walk_factor", 0.85) if needs.exhausted() else 1.0)
	player.sprint_allowed = not needs.exhausted() and not wounds.blocks_sprint()
	player.sprint_factor = 1.0 + skills.bonus("fitness")
	player.spread_factor = maxf(0.2, 1.0 - skills.bonus("shooting"))
	player.drive_factor = 1.0 + skills.bonus("driving")


func _on_player_hurt(_amount: float) -> void:
	if wounds.on_hit(randf()):
		message.emit("You're bleeding. Use a bandage (open your bag).")


## Call when the player's shot hits someone.
func on_player_hit_target() -> void:
	skills.add("shooting", "hit")


## Call when the player completes a sale.
func on_sale() -> void:
	skills.add("hustle", "sale")


# ---------------------------------------------------------------- items

## Uses one item from the bag. Returns what happened (always a message).
func use_item(id: String) -> String:
	var item := config.item(id)
	if bag.count(id) <= 0 or item.is_empty():
		return "You don't have that."
	var fx: Dictionary = item.get("effects", {})
	if fx.is_empty():
		return "%s: nothing to do with it but sell it." % item.name
	var did := false
	if fx.has("bandage") and wounds.bandage(int(fx.bandage)) > 0:
		did = true
	for need in Needs.IDS:
		if fx.has(need) and needs.value(need) < 100.0:
			needs.restore(need, float(fx[need]))
			did = true
	if fx.has("health") and player.health.hp < Health.MAX_HP and not player.health.down:
		player.health.hp = minf(Health.MAX_HP, player.health.hp + float(fx.health))
		did = true
	if not did:
		return "No need for the %s right now." % str(item.name).to_lower()
	bag.remove(id)
	changed.emit()
	return "Used: %s." % item.name


func drop_item(id: String) -> String:
	return "Dropped: %s." % config.item_name(id) if bag.remove(id) else "You don't have that."


func buy(id: String) -> String:
	var item := config.item(id)
	var price := int(item.get("price", 0))
	if item.is_empty() or price <= 0:
		return "That's not for sale."
	if progression.cash < price:
		return "You can't afford the %s (R%d)." % [str(item.name).to_lower(), price]
	if not bag.can_add(id):
		return "Your bag is full (%.1f of %.0f kg)." % [bag.weight(), bag.capacity]
	progression.add_cash(-price)
	bag.add(id)
	return "Bought: %s (R%d)." % [item.name, price]


func sell(id: String) -> String:
	var value := int(config.item(id).get("sell", 0))
	if value <= 0 or not bag.remove(id):
		return "They don't want that."
	progression.add_cash(value)
	return "Sold: %s (R%d)." % [config.item_name(id), value]


# ---------------------------------------------------------------- sleep

## "" if the player may sleep now, otherwise why not.
func why_not_sleep() -> String:
	if int(heat_level.call()) > 0:
		return "Not with SAPS looking for you."
	if wounds.bleeding > 0:
		return "You're bleeding. Bandage it first."
	return ""


func sleep() -> String:
	var why := why_not_sleep()
	if not why.is_empty():
		return why
	var hours := needs.sleep()
	wounds.heal_bandaged()
	clock.advance(hours * 60.0 / clock.minutes_per_second)
	_last_minutes = total_minutes()
	changed.emit()
	return "You sleep for %d hours. It's %s on day %d." % [roundi(hours), clock.label(), clock.day]


# ---------------------------------------------------------------- searching

## Adds a searchable spot to the world (a bin, a crate...). `parent` holds the interactable.
func add_spot(spot_id: String, table: String, at: Vector3, label: String, parent: Node) -> Interactable:
	var it := Interactable.new()
	it.name = "Search_" + spot_id
	it.kind = "search"
	it.target = spot_id
	it.radius = 1.6
	it.prompt = "Search the %s" % label
	it.on_interact = func() -> String: return start_search(spot_id, table, at)
	parent.add_child(it)
	it.global_position = at + Vector3(0, 0.8, 0)
	_spots[spot_id] = it
	return it


func spot_ids() -> Array:
	return _spots.keys()


func start_search(spot_id: String, table: String, at: Vector3) -> String:
	if loot.is_empty(spot_id, clock.day):
		return "Nothing left here. Try again in a day or two."
	if not _search.is_empty():
		return "You're already searching."
	var secs := config.num("search_seconds", 2.0)
	_search = {"id": spot_id, "table": table, "left": secs, "at": at}
	return "Searching..."


func is_searching() -> bool:
	return not _search.is_empty()


func _tick_search(delta: float) -> void:
	if _search.is_empty():
		return
	if player.global_position.distance_to(_search.at) > SEARCH_RANGE or not player.input_enabled or player.is_driving():
		_search = {}
		message.emit("You stop searching.")
		return
	_search.left = float(_search.left) - delta
	if float(_search.left) <= 0.0:
		var s := _search
		_search = {}
		message.emit(finish_search(str(s.id), str(s.table)))


## Takes what the spot holds (as much as fits) and marks it searched.
func finish_search(spot_id: String, table: String) -> String:
	var found: Array = loot.contents(spot_id, table, clock.day, skills.bonus("scavenging"))
	loot.mark_searched(spot_id, clock.day)
	skills.add("scavenging", "search")
	if found.is_empty():
		return "Nothing useful."
	var took: Array = []
	var left: Array = []
	for id in found:
		if bag.add(str(id)):
			took.append(config.item_name(str(id)))
		else:
			left.append(config.item_name(str(id)))
	var text := "Found: %s." % ", ".join(took) if not took.is_empty() else "Found something, but"
	if not left.is_empty():
		text += " Your bag is too full for: %s." % ", ".join(left)
	return text


# ---------------------------------------------------------------- HUD and saving

## One short line for the HUD: only what needs attention (empty when all is well).
func status_line() -> String:
	var parts: Array = []
	for need in Needs.IDS:
		if needs.is_low(need):
			parts.append("%s %d%%" % [{"food": "Hungry", "water": "Thirsty", "rest": "Tired"}[need], int(needs.value(need))])
	if wounds.bleeding > 0:
		parts.append("Bleeding x%d" % wounds.bleeding)
	elif not wounds.bandaged.is_empty():
		parts.append("Bandaged x%d" % wounds.bandaged.size())
	return "  ·  ".join(parts)


func to_dict() -> Dictionary:
	return {"needs": needs.to_dict(), "bag": bag.to_dict(), "stash": stash.to_dict(), "wounds": wounds.to_dict(),
		"skills": skills.to_dict(), "loot": loot.to_dict()}


## Old saves have no survival section: start from a fresh state.
func load_dict(d: Variant) -> void:
	reset()
	if not d is Dictionary:
		return
	needs.load_dict(d.get("needs"))
	bag.load_dict(d.get("bag"))
	stash.load_dict(d.get("stash"))
	wounds.load_dict(d.get("wounds"))
	skills.load_dict(d.get("skills"))
	loot.load_dict(d.get("loot"))
	_last_minutes = -1.0
	changed.emit()
