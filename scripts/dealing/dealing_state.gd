class_name DealingState
extends RefCounted
## The early-game hustle as pure data (unit-tested, saved with the game): stock, the phone's
## contacts (clients with a mood), incoming calls, open orders and counters for missions.
## Game-like and abstract. The DealingController connects it to the world and the phone UI.
## Moods: 0..100. Below `lost_below` a client takes their business to a rival crew's dealer.

signal call_incoming(call: Dictionary)
signal order_changed
signal client_changed(npc_id: String)
signal client_lost(npc_id: String, rival: String)

const FILE := "res://data/dealing/dealing.json"
const MOOD_ICONS := {"happy": 75, "ok": 55, "meh": 35}   # thresholds, else "angry"

var cfg: Dictionary = {}
var stock := {"weed": 0, "drink": 0}
var clients := {}       # npc id -> {name, product, home, mood, status: "client"|"lost", rival, next_call}
var orders: Array = []  # {id, npc, product, qty, place, deadline, accepted_at}
var call: Dictionary = {}   # ringing call: {npc, product, qty, place, rings_until}
var stats := {"weed_sold": 0, "drinks_sold": 0, "street_deals": 0, "busts": 0, "missed": 0, "lost_clients": 0}
var enabled := false    # calls only come once the player is dealing (mission)
var _next_order_id := 1


static func load_default() -> DealingState:
	var d := DealingState.new()
	var raw: Variant = DataFiles.load_json(FILE)
	d.cfg = raw if raw is Dictionary else {}
	return d


func product(id: String) -> Dictionary:
	return cfg.get("products", {}).get(id, {})


func mood_cfg(key: String) -> float:
	return float(cfg.get("mood", {}).get(key, 0))


# ------------------------------------------------------------------ stock

func add_stock(p: String, qty: int) -> void:
	stock[p] = int(stock.get(p, 0)) + qty


func take_stock(p: String, qty: int) -> bool:
	if int(stock.get(p, 0)) < qty:
		return false
	stock[p] = int(stock[p]) - qty
	return true


# ------------------------------------------------------------------ contacts

func is_client(npc: String) -> bool:
	return clients.has(npc) and clients[npc].status == "client"


## Saves someone to the phone. `minutes` = game time now (first call comes later).
func add_client(npc: String, name: String, product_id: String, home: String, minutes: float, rng: RandomNumberGenerator) -> bool:
	if clients.has(npc):
		return false
	clients[npc] = {"name": name, "product": product_id, "home": home, "mood": mood_cfg("start"),
		"status": "client", "rival": "", "next_call": minutes + _call_gap(rng) * 0.5}
	client_changed.emit(npc)
	return true


func mood_icon(npc: String) -> String:
	if not clients.has(npc):
		return ""
	var c: Dictionary = clients[npc]
	if c.status == "lost":
		return "lost"
	for k in ["happy", "ok", "meh"]:
		if float(c.mood) >= float(MOOD_ICONS[k]):
			return k
	return "angry"


## Changes a client's mood; too low and they go to a rival crew's dealer.
func change_mood(npc: String, delta: float, rival_if_lost := "") -> void:
	if not is_client(npc):
		return
	var c: Dictionary = clients[npc]
	c.mood = clampf(float(c.mood) + delta, 0.0, 100.0)
	if float(c.mood) < mood_cfg("lost_below"):
		c.status = "lost"
		c.rival = rival_if_lost
		stats.lost_clients += 1
		orders = orders.filter(func(o): return o.npc != npc)
		if call.get("npc", "") == npc:
			call = {}
		client_lost.emit(npc, rival_if_lost)
		order_changed.emit()
	client_changed.emit(npc)


## Tries to win a lost client back with a free item. True if they come back.
func win_back(npc: String) -> bool:
	if not clients.has(npc) or clients[npc].status != "lost":
		return false
	var p: String = clients[npc].product
	if not take_stock(p, 1):
		return false
	clients[npc].status = "client"
	clients[npc].mood = mood_cfg("win_back")
	clients[npc].rival = ""
	client_changed.emit(npc)
	return true


# ------------------------------------------------------------------ calls and orders

## Advances time: rings clients who are due (one call at a time), misses unanswered calls and
## expires late orders. `rival_for(npc)` names the rival crew a lost client goes to.
func tick(minutes: float, rng: RandomNumberGenerator, rival_for: Callable, can_call: Callable = Callable()) -> void:
	if not call.is_empty() and minutes >= float(call.rings_until):
		var npc: String = call.npc
		call = {}
		stats.missed += 1
		change_mood(npc, mood_cfg("missed"), rival_for.call(npc) if rival_for.is_valid() else "")
	for o in orders.duplicate():
		if minutes > float(o.deadline):
			orders.erase(o)
			change_mood(o.npc, mood_cfg("late"), rival_for.call(o.npc) if rival_for.is_valid() else "")
			order_changed.emit()
	if not enabled or not call.is_empty() or orders.size() >= int(cfg.get("max_open_orders", 2)):
		return
	for npc in clients:
		var c: Dictionary = clients[npc]
		if c.status != "client" or minutes < float(c.next_call) or orders.any(func(o): return o.npc == npc):
			continue
		if can_call.is_valid() and not can_call.call(npc):
			continue
		c.next_call = minutes + _call_gap(rng)
		var qty := 1 if c.product == "weed" else rng.randi_range(1, 2)
		call = {"npc": npc, "product": c.product, "qty": qty, "place": str(c.home) + ":gate",
			"rings_until": minutes + float(cfg.get("ring_seconds", 30))}   # 1 real second = 1 game minute
		call_incoming.emit(call)
		return


func answer(minutes: float, rng: RandomNumberGenerator) -> Dictionary:
	if call.is_empty():
		return {}
	var w: Array = cfg.get("order_window_minutes", [120, 200])
	var o := {"id": _next_order_id, "npc": call.npc, "product": call.product, "qty": call.qty, "place": call.place,
		"deadline": minutes + rng.randf_range(float(w[0]), float(w[1])), "accepted_at": minutes}
	_next_order_id += 1
	orders.append(o)
	call = {}
	order_changed.emit()
	return o


func decline(rival_for: Callable = Callable()) -> void:
	if call.is_empty():
		return
	var npc: String = call.npc
	call = {}
	change_mood(npc, mood_cfg("declined"), rival_for.call(npc) if rival_for.is_valid() else "")


func order_for(npc: String) -> Dictionary:
	for o in orders:
		if o.npc == npc:
			return o
	return {}


## Hands the goods over. Returns the cash earned, or -1 if there's no stock.
func complete(npc: String, minutes: float) -> int:
	var o := order_for(npc)
	if o.is_empty() or not take_stock(o.product, int(o.qty)):
		return -1
	orders.erase(o)
	var window := float(o.deadline) - float(o.accepted_at)
	var fast := minutes - float(o.accepted_at) < window * 0.5
	change_mood(npc, mood_cfg("fast") if fast else mood_cfg("on_time"))
	_count_sale(o.product, int(o.qty))
	stats.street_deals += 1
	order_changed.emit()
	return int(product(o.product).get("sell", 0)) * int(o.qty)


## Police saw the hand-over: the goods are gone, the client is spooked.
func bust(npc: String) -> void:
	var o := order_for(npc)
	if o.is_empty():
		return
	take_stock(o.product, int(o.qty))
	orders.erase(o)
	stats.busts += 1
	change_mood(npc, mood_cfg("spooked"))
	order_changed.emit()


## A drink (or bankie) sold over the smokkie counter. Returns cash, or -1 if out of stock.
func sell_counter(p: String) -> int:
	if not take_stock(p, 1):
		return -1
	_count_sale(p, 1)
	return int(product(p).get("sell", 0))


func _count_sale(p: String, qty: int) -> void:
	if p == "weed":
		stats.weed_sold += qty
	else:
		stats.drinks_sold += qty


func _call_gap(rng: RandomNumberGenerator) -> float:
	var g: Array = cfg.get("call_every_minutes", [300, 600])
	return rng.randf_range(float(g[0]), float(g[1]))


func stat(name: String) -> int:
	if name == "contacts":
		return clients.values().filter(func(c): return c.status == "client").size()
	return int(stats.get(name, 0))


# ------------------------------------------------------------------ save

func to_dict() -> Dictionary:
	return {"stock": stock.duplicate(), "clients": clients.duplicate(true), "orders": orders.duplicate(true),
		"stats": stats.duplicate(), "enabled": enabled, "next_order_id": _next_order_id}


func load_dict(d: Variant) -> void:
	if not d is Dictionary:
		return
	stock = d.get("stock", stock) if d.get("stock") is Dictionary else stock
	clients = d.get("clients", {}) if d.get("clients") is Dictionary else {}
	orders = d.get("orders", []) if d.get("orders") is Array else []
	for k in stats:
		stats[k] = int(d.get("stats", {}).get(k, 0)) if d.get("stats") is Dictionary else 0
	enabled = bool(d.get("enabled", false))
	_next_order_id = int(d.get("next_order_id", 1))
	call = {}
	order_changed.emit()
