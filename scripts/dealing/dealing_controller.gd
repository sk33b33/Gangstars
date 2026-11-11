class_name DealingController
extends Node
## Connects the DealingState (pure logic) to the world. Owned by the GameSession.
## - Contacts: chatting to a neighbour who's interested saves them to the phone (once "Bankies"
##   has started).
## - Calls: clients ring with orders; answering sends them out to wait at their gate.
## - Street deals: talk to the client to hand over. If SAPS can see it, it's a bust: stock lost,
##   heat up.
## - Smokkie counters (venues in dealing.json: Aunty Mavis', Doreen's, Ma Lena's): serve the
##   evening crowd from your own stock.
## - Prices move: a risk premium per heat star; cheaper where rivals hold the corners, dearer
##   where you do.
## - Runners (hired at the safehouse) take answered orders for you, for a cut and some risk.
## - Restock is ordered at the safehouse and picked up at a drop (ready after a while).
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
var turf: TurfWar       # set by the GameSession once turf exists (prices follow the corners)
var venues: Dictionary = {}   # id -> venue dict (dealing.json)
var _drop_nodes: Dictionary = {}   # drop id -> Node3D

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
	for v in state.cfg.get("venues", []):
		venues[str(v.id)] = v
	_build_counter()
	_build_venue_houses()


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
	for res in state.resolve_runners(minutes(), _rng, runner_success, client_mult):
		var who := str(state.clients[res.npc].name) if state.clients.has(res.npc) else "a client"
		if res.ok:
			progression.add_cash(int(res.cash))
			message.emit("Your runner sorted %s: R%d (after their cut)." % [who, int(res.cash)])
		else:
			message.emit("Your runner got caught by SAPS on the way to %s. The stock's gone." % who)
		missions._check_stat_objectives()
	for gone in state.expire_drops(minutes()):
		message.emit("Nobody picked up the %s. It's gone." % _plural(str(gone.product), int(gone.qty)))
	_update_drops()
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
	var cash := state.complete(npc_id, minutes(), client_mult(npc_id))
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


## Serves everyone waiting at a smokkie: a drink each (sometimes a bankie).
func serve_counter(venue_id := "shebeen") -> String:
	var v: Dictionary = venues.get(venue_id, {"crowd": "poi_shebeen", "host": "npc_mavis"})
	if not district.destinations.has(str(v.crowd)):
		return "Nobody's about."
	var at := district.destinations.anchor_position(str(v.crowd))
	var mult := price_mult(district.area_at(at))
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
		var cash := state.sell_counter(wants, mult)
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

## Orders stock from your crew's runner (safehouse menu): it's dropped off for you to pick up.
## False if you can't afford it.
func buy_stock(index: int) -> bool:
	var r: Array = state.cfg.get("restock", [])
	if index < 0 or index >= r.size():
		return false
	var item: Dictionary = r[index]
	var cost := int(state.product(str(item.product)).get("buy", 0)) * int(item.qty)
	if not progression.spend(cost):
		return false
	state.order_drop(str(item.product), int(item.qty), drop_anchor(), minutes())
	_update_drops()
	return true


func restock_items() -> Array:
	var out: Array = []
	var r: Array = state.cfg.get("restock", [])
	for i in r.size():
		var cost := int(state.product(str(r[i].product)).get("buy", 0)) * int(r[i].qty)
		out.append({"label": "Order %s from your crew's runner  —  R%d (pick up at %s)" % [r[i].label, cost,
			district.destinations.display_name(drop_anchor())], "cost": cost, "index": i})
	return out


## Where drops are left: a corner you hold in Westridge, else your safehouse gate.
func drop_anchor() -> String:
	if turf:
		for id in turf.state.players_corners():
			if turf.area_of(id) == "starter":
				return str(turf.state.corners[id].anchor)
	return GameSession.SAFEHOUSE_ID + ":gate"


## A crate at each waiting drop, with "Collect".
func _update_drops() -> void:
	var live := {}
	for d in state.drops:
		live[int(d.id)] = d
		if _drop_nodes.has(int(d.id)) or not district.destinations.has(str(d.at)):
			continue
		var n := Node3D.new()
		n.name = "Drop%d" % int(d.id)
		district.add_child(n)
		n.global_position = district.destinations.anchor_position(str(d.at)) + Vector3(1.2, 0, 1.2)
		PropLibrary.place(n, "crate_stack", Vector3.ZERO, 0.4, Color("#c0392b") if str(d.product) == "drink" else Color("#2f6e3a"))
		var it := Interactable.new()
		it.name = "Collect"
		it.kind = "drop"
		it.target = str(d.id)
		it.radius = 1.6
		it.prompt = "Collect your %s" % _plural(str(d.product), int(d.qty))
		it.on_interact = collect.bind(int(d.id))
		n.add_child(it)
		it.position = Vector3(0, 1.0, 0)
		_drop_nodes[int(d.id)] = n
	for id in _drop_nodes.keys():
		if not live.has(id):
			_drop_nodes[id].queue_free()
			_drop_nodes.erase(id)


func collect(drop_id: int) -> String:
	var d: Array = state.drops.filter(func(x): return int(x.id) == drop_id)
	var why := state.collect_drop(drop_id, minutes())
	_update_drops()
	if not why.is_empty() or d.is_empty():
		return why
	return "Picked up %d %s." % [int(d[0].qty), _plural(str(d[0].product), int(d[0].qty))]


# ------------------------------------------------------------------ prices and runners

## Street price multiplier in a suburb: +10% per heat star (risk), cheaper where rivals hold the
## corners (competition), dearer where you do.
func price_mult(area: String) -> float:
	var pc: Dictionary = state.cfg.get("prices", {})
	var m := 1.0 + float(pc.get("per_heat", 0.1)) * (police.heat.level() if police else 0)
	if turf:
		var share := turf_share(area)
		m += float(pc.get("own_turf", 0.15)) * share.own - float(pc.get("competition", 0.25)) * share.rival
	return clampf(m, float(pc.get("min", 0.75)), float(pc.get("max", 1.5)))


## {own, rival}: shares of a suburb's corners held by your crew and by rival crews.
func turf_share(area: String) -> Dictionary:
	var total := 0
	var own := 0
	var rival := 0
	if turf:
		for id in turf.state.order:
			if turf.area_of(id) != area:
				continue
			total += 1
			if turf.state.is_players(id):
				own += 1
			elif not turf.state.owner(id).is_empty():
				rival += 1
	return {"own": float(own) / maxf(1.0, total), "rival": float(rival) / maxf(1.0, total)}


func client_area(npc_id: String) -> String:
	var r: Resident = district.residents.get(npc_id)
	return district.resident_district(r) if r else "starter"


func client_mult(npc_id: String) -> float:
	return price_mult(client_area(npc_id))


func runner_success(npc_id: String) -> float:
	var rc: Dictionary = state.cfg.get("runner", {})
	var heat := police.heat.level() if police else 0
	return clampf(float(rc.get("base_success", 0.9)) - float(rc.get("per_heat", 0.08)) * heat
		- float(rc.get("competition", 0.1)) * float(turf_share(client_area(npc_id)).rival), 0.2, 0.98)


## Hire a runner (safehouse menu). "" or why not.
func hire_runner() -> String:
	var rc: Dictionary = state.cfg.get("runner", {})
	if state.runners >= int(rc.get("max", 2)):
		return "You've got all the runners you can use."
	if not progression.spend(int(rc.get("hire_cost", 200))):
		return "You can't afford a runner (R%d)." % int(rc.get("hire_cost", 200))
	state.hire_runner()
	return ""


func send_runner(npc_id: String) -> String:
	if state.send_runner(npc_id, minutes()):
		return "Your runner's on the way to %s." % str(state.clients[npc_id].name)
	return "No runner free (or not enough stock)."


# ------------------------------------------------------------------ venues

func is_venue(id: String) -> bool:
	return venues.has(id)


func venue_open(id: String) -> bool:
	var h: Array = venues[id].get("hours", [10, 23])
	var hour := district.director.clock.minutes / 60.0
	return hour >= float(h[0]) and hour < float(h[1])


## House smokkies: a sign over the door, and the door takes you in (no knocking).
func _build_venue_houses() -> void:
	for id in venues:
		var plot: HousePlot = district.plots.get(id)
		if plot == null:
			continue
		var v: Dictionary = venues[id]
		var facade := plot.door_position() - plot.global_basis.z * 0.86 + Vector3(0, 2.35, 0)
		var sign := Geo.quad(district, Vector2(2.4, 0.6), Vector3.ZERO, PixelMaterials.panel(str(v.get("sign", "sign_shebeen"))))
		sign.global_position = facade
		sign.global_rotation = plot.global_rotation
		plot.door_interactable.prompt = "Go into %s" % str(v.name)
		plot.door_interactable.on_interact = func(): return ""


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
