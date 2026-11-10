class_name DealingController
extends Node
## Connects the DealingState (pure logic) to the world. Owned by the GameSession.
## - Contacts: chatting to a neighbour who's interested saves them to the phone (once "Bankies"
##   has started).
## - Calls: clients ring with orders; answering sends them out to wait at their gate.
## - Street deals: talk to the client to hand over. If SAPS can see it, it's a bust: stock lost,
##   heat up.
## - The smokkie counter (Aunty Mavis'): serve the evening crowd from your own stock.
## - Mood faces float over clients' heads when you're near.
## Game-like and abstract on purpose (see CLAUDE.md: no real-world specifics).

signal ringing(call: Dictionary)
signal message(text: String)

const POLICE_SEE_RANGE := 18.0
const BAKKIE_SEE_RANGE := 25.0
const HANDOVER_RANGE := 3.0
const COUNTER_CROWD_RANGE := 8.0
const ICON_RANGE := 16.0
const SERVE_COOLDOWN := 90.0    # game minutes before the same customer buys again
const TICK := 0.5

var state := DealingState.load_default()
var district: District
var player: Player
var progression: ProgressionState
var missions: MissionManager
var police: PoliceDispatch
var counter: Interactable

var _rng := RandomNumberGenerator.new()
var _tick := 0.0
var _served := {}         # npc id -> minute last served at the counter
var _icons := {}          # npc id -> Sprite3D


func setup(p_district: District, p_player: Player, p_progression: ProgressionState, p_missions: MissionManager, p_police: PoliceDispatch) -> void:
	district = p_district
	player = p_player
	progression = p_progression
	missions = p_missions
	police = p_police
	_rng.seed = 9090
	missions.stat_value = state.stat
	state.call_incoming.connect(func(c: Dictionary): ringing.emit(c))
	state.client_lost.connect(_on_client_lost)
	state.order_changed.connect(func(): missions._check_stat_objectives())
	_build_counter()


func minutes() -> float:
	return district.director.clock.day * 1440.0 + district.director.clock.minutes


## Contacts and calls open up once the "Bankies" mission starts.
func collecting_contacts() -> bool:
	return missions.active.has("bankies") or missions.is_completed("bankies")


func _physics_process(delta: float) -> void:
	if district == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	state.enabled = collecting_contacts()
	state.tick(minutes(), _rng, _rival_for, _can_call)
	_update_icons()


# ------------------------------------------------------------------ contacts

## Called after the player chats to someone. Returns a note to show, or "".
func on_chat(npc_id: String) -> String:
	if not collecting_contacts() or state.clients.has(npc_id):
		return ""
	var r: Resident = district.residents.get(npc_id)
	if r == null or not _could_be_client(r):
		return ""
	var wants := "weed" if absi((npc_id + "taste").hash()) % 10 < 7 else "drink"
	state.add_client(npc_id, r.data.display_name, wants, r.data.home_id, minutes(), _rng)
	missions._check_stat_objectives()
	return "%s saved your number. They'll call when they want %s." % [r.data.display_name, _a(wants)]


func _could_be_client(r: Resident) -> bool:
	if r.data.role != "resident" or r.data.id == "npc_mavis":
		return false
	if district.registry.get_house(r.data.home_id) == null:
		return false
	return float(absi((r.data.id + "client").md5_text().hash()) % 100) < float(state.cfg.get("client_share", 0.5)) * 100.0


func _can_call(npc_id: String) -> bool:
	var r: Resident = district.residents.get(npc_id)
	return r != null and r.brain.is_active_hours() and not r.is_down()


# ------------------------------------------------------------------ calls

func answer() -> String:
	var c := state.call.duplicate()
	var o := state.answer(minutes(), _rng)
	if o.is_empty():
		return ""
	var r: Resident = district.residents.get(o.npc)
	if r:
		# The client steps out to wait at their gate until the deadline.
		r.brain.pending_event = {"activity": "waiting", "destination": o.place,
			"duration": maxf(30.0, float(o.deadline) - minutes()), "event": "deal"}
		if r.brain.state == NpcBrain.State.AT_HOME:
			r.brain.timer = minf(r.brain.timer, 1.0)
		elif r.brain.state in [NpcBrain.State.AT_DESTINATION, NpcBrain.State.SOCIALIZING, NpcBrain.State.GUARDING]:
			r.brain.timer = 0.0
	return "%s wants %d %s. Meet them at %s before %s." % [str(state.clients[c.npc].name), int(o.qty),
		_plural(o.product, int(o.qty)), district.destinations.display_name(o.place), _clock_text(float(o.deadline))]


func decline() -> void:
	state.decline(_rival_for)


# ------------------------------------------------------------------ street deals

## True if talking to this NPC should hand over their order instead of chatting.
func handles(npc_id: String) -> bool:
	var r: Resident = district.residents.get(npc_id)
	return r != null and not state.order_for(npc_id).is_empty() and r.global_position.distance_to(player.global_position) <= HANDOVER_RANGE + 0.5


func try_sell(npc_id: String) -> String:
	var o := state.order_for(npc_id)
	if o.is_empty():
		return ""
	var name := str(state.clients[npc_id].name)
	if int(state.stock.get(o.product, 0)) < int(o.qty):
		return "You don't have %d %s on you. Restock at your safehouse." % [int(o.qty), _plural(o.product, int(o.qty))]
	if police_watching(player.global_position):
		state.bust(npc_id)
		police.heat.add(2.0)
		return "BUSTED! SAPS saw the hand-over. The %s is gone and %s is spooked." % [_plural(o.product, int(o.qty)), name]
	var cash := state.complete(npc_id, minutes())
	progression.add_cash(cash)
	missions._check_stat_objectives()
	var r: Resident = district.residents.get(npc_id)
	if r:
		r.brain.pending_event = {}
	return "Sold %d %s to %s: R%d." % [int(o.qty), _plural(o.product, int(o.qty)), name, cash]


## Any officer (on foot, with line of sight) or police bakkie close enough to see a deal here.
func police_watching(at: Vector3) -> bool:
	for r: Resident in district.residents.values():
		if r.data.role == "police" and not r.is_inside and not r.is_down() \
				and r.global_position.distance_to(at) < POLICE_SEE_RANGE and r._line_of_sight(player):
			return true
	if district.traffic:
		for car: TrafficCar in district.traffic.cars:
			if car.model == "police" and car.global_position.distance_to(at) < BAKKIE_SEE_RANGE:
				return true
	return false


# ------------------------------------------------------------------ the smokkie counter

func _build_counter() -> void:
	if not district.destinations.has("shebeen:counter"):
		return
	counter = Interactable.new()
	counter.name = "SmokkieCounter"
	counter.kind = "counter"
	counter.target = "shebeen"
	counter.radius = 1.4
	counter.prompt = "Serve at Aunty Mavis' counter"
	counter.on_interact = serve_counter
	district.add_child(counter)
	counter.global_position = district.destinations.anchor_position("shebeen:counter") + Vector3(0, 1.0, 0)


## Serves everyone waiting at the smokkie: a drink each (sometimes a bankie).
func serve_counter() -> String:
	var at := district.destinations.anchor_position("poi_shebeen")
	var crowd: Array[Resident] = []
	for r: Resident in district.residents.values():
		if r.is_inside or r.data.role in ["kid", "police"] or r.data.id == "npc_mavis" or r.is_down():
			continue
		if r.global_position.distance_to(at) < COUNTER_CROWD_RANGE and minutes() - float(_served.get(r.data.id, -9999.0)) > SERVE_COOLDOWN:
			crowd.append(r)
	if crowd.is_empty():
		return "Nobody's waiting at the counter. The smokkie's busy in the evening (17:00–23:00)."
	var earned := 0
	var served := 0
	var out_of := ""
	for r in crowd:
		var wants := "weed" if absi((r.data.id + "smokkie").hash()) % 10 < 3 and int(state.stock.weed) > 0 else "drink"
		if wants == "weed" and police_watching(player.global_position):
			wants = "drink"   # not with SAPS looking
		var cash := state.sell_counter(wants)
		if cash < 0:
			out_of = wants
			continue
		earned += cash
		served += 1
		_served[r.data.id] = minutes()
	progression.add_cash(earned)
	missions._check_stat_objectives()
	if served == 0:
		return "You're out of %s. Restock at your safehouse." % _plural(out_of if not out_of.is_empty() else "drink", 2)
	return "You served %d customer%s: R%d.%s" % [served, "" if served == 1 else "s", earned,
		("  (Out of %s for the rest.)" % _plural(out_of, 2)) if not out_of.is_empty() else ""]


# ------------------------------------------------------------------ restocking

## Buys stock from your crew's runner (safehouse menu). False if you can't afford it.
func buy_stock(index: int) -> bool:
	var r: Array = state.cfg.get("restock", [])
	if index < 0 or index >= r.size():
		return false
	var item: Dictionary = r[index]
	var cost := int(state.product(str(item.product)).get("buy", 0)) * int(item.qty)
	if not progression.spend(cost):
		return false
	state.add_stock(str(item.product), int(item.qty))
	return true


func restock_items() -> Array:
	var out: Array = []
	var r: Array = state.cfg.get("restock", [])
	for i in r.size():
		var cost := int(state.product(str(r[i].product)).get("buy", 0)) * int(r[i].qty)
		out.append({"label": "Buy %s from your crew's runner  —  R%d" % [r[i].label, cost], "cost": cost, "index": i})
	return out


# ------------------------------------------------------------------ moods

func _rival_for(npc_id: String) -> String:
	var ids := Array(district.crews.ids()).filter(func(id): return id != progression.crew_id)
	if ids.is_empty():
		return "another dealer"
	return district.crews.display_name(ids[absi(npc_id.hash()) % ids.size()])


func _on_client_lost(npc_id: String, rival: String) -> void:
	message.emit("%s is fed up and buying from the %s now." % [str(state.clients[npc_id].name), rival])


## Mood faces over nearby clients' heads.
func _update_icons() -> void:
	for npc in state.clients:
		var r: Resident = district.residents.get(npc)
		if r == null:
			continue
		var show := not r.is_inside and r.global_position.distance_to(player.global_position) < ICON_RANGE
		var icon: Sprite3D = _icons.get(npc)
		if show and icon == null:
			icon = Sprite3D.new()
			icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			icon.pixel_size = 0.035
			icon.position = Vector3(0, 2.5, 0)
			icon.no_depth_test = true
			r.add_child(icon)
			_icons[npc] = icon
		if icon:
			icon.visible = show
			if show:
				icon.texture = mood_texture(state.mood_icon(npc))


static func mood_texture(icon: String) -> Texture2D:
	return load("res://assets/textures/pxl/mood_%s.png" % (icon if not icon.is_empty() else "ok"))


# ------------------------------------------------------------------ text helpers

func _plural(p: String, qty: int) -> String:
	var d := state.product(p)
	return str(d.get("name", p)) if qty == 1 else str(d.get("plural", p + "s"))


func _a(p: String) -> String:
	return "a " + _plural(p, 1)


func _clock_text(abs_minutes: float) -> String:
	var m := fmod(abs_minutes, 1440.0)
	return "%02d:%02d" % [int(m / 60.0), int(fmod(m, 60.0))]
