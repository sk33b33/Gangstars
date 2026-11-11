class_name TurfState
extends RefCounted
## Who holds which street corner, and how firmly (control 0..100). Pure logic, unit-tested;
## the TurfWar controller feeds it presence and time.
##   Taking: the player stands on a corner they don't hold with no owner crew standing there:
##     control drains (faster with crew-mates along); at 0 the corner is the player's crew's.
##   Pushes: now and then a rival crew moves on one of the player's corners. While their
##     members stand there and the player doesn't, control drains; at 0 the corner flips.
##     If the push runs out, or the player is there and no pushers stand, it's held.

signal flipped(corner_id: String, old_owner: String, new_owner: String)
signal push_started(corner_id: String, crew: String)
signal push_ended(corner_id: String, held: bool)

var cfg: Dictionary = {}
var corners: Dictionary = {}     # id -> {name, anchor, owner, control, push_crew, push_until}
var order: PackedStringArray = []
var player_crew := ""
var next_push := 360.0      # played minutes until the next rival push


static func load_default() -> TurfState:
	var t := TurfState.new()
	var raw: Variant = DataFiles.load_json("res://data/factions/corners.json")
	t.cfg = raw if raw is Dictionary else {}
	for c in t.cfg.get("corners", []):
		t.corners[str(c.id)] = {"name": str(c.name), "anchor": str(c.anchor), "owner": str(c.get("owner", "")),
			"control": 100.0 if str(c.get("owner", "")) != "" else 0.0, "push_crew": "", "push_until": 0.0}
		t.order.append(str(c.id))
	return t


func owner(id: String) -> String:
	return str(corners[id].owner)


func is_players(id: String) -> bool:
	return not player_crew.is_empty() and owner(id) == player_crew


func players_corners() -> Array:
	return Array(order).filter(func(id): return is_players(id))


func pushed(id: String) -> bool:
	return not str(corners[id].push_crew).is_empty()


## One step of `dt` game minutes. presence(id) -> {player: bool, crew: int (player's crew-mates),
## owners: int (owner crew standing there), pushers: int (pushing crew standing there)}.
func tick(now: float, dt: float, presence: Callable) -> void:
	for id in order:
		var c: Dictionary = corners[id]
		var p: Dictionary = presence.call(id)
		if not is_players(id):
			if bool(p.player) and int(p.owners) == 0 and not player_crew.is_empty():
				var rate := float(cfg.get("take_rate", 3.0)) + float(cfg.get("crew_bonus", 2.0)) * int(p.crew)
				if str(c.owner).is_empty():
					c.control = minf(100.0, float(c.control) + rate * dt)   # nobody's: build it up
					if c.control >= 50.0:
						_flip(id, player_crew, 40.0)
				else:
					c.control = maxf(0.0, float(c.control) - rate * dt)
					if c.control <= 0.0:
						_flip(id, player_crew, 30.0)
			elif not str(c.owner).is_empty():
				c.control = minf(100.0, float(c.control) + float(cfg.get("regen_rate", 0.4)) * dt)
			continue
		if pushed(id):
			if bool(p.player) and int(p.pushers) == 0:
				_end_push(id, true)
			elif now > float(c.push_until):
				_end_push(id, true)
			elif int(p.pushers) > 0 and not bool(p.player):
				c.control = maxf(0.0, float(c.control) - float(cfg.get("push_rate", 2.0)) * mini(int(p.pushers), 3) * dt)
				if c.control <= 0.0:
					var crew := str(c.push_crew)
					_end_push(id, false)
					_flip(id, crew, 40.0)
		else:
			c.control = minf(100.0, float(c.control) + float(cfg.get("regen_rate", 0.4)) * dt)


func start_push(id: String, crew: String, now: float) -> void:
	corners[id].push_crew = crew
	corners[id].push_until = now + float(cfg.get("push_minutes", 120))
	push_started.emit(id, crew)


func _end_push(id: String, held: bool) -> void:
	corners[id].push_crew = ""
	push_ended.emit(id, held)


func _flip(id: String, new_owner: String, control: float) -> void:
	var old := owner(id)
	corners[id].owner = new_owner
	corners[id].control = control
	flipped.emit(id, old, new_owner)


## Paint over a tag: the owner's hold weakens (or, on your own corner, it firms up).
func paint_over(id: String) -> void:
	var c: Dictionary = corners[id]
	if is_players(id):
		c.control = minf(100.0, float(c.control) + 10.0)
	else:
		c.control = maxf(1.0, float(c.control) - 15.0)


func to_dict() -> Dictionary:
	var out := {}
	for id in order:
		out[id] = {"owner": corners[id].owner, "control": corners[id].control}
	return {"corners": out, "next_push": next_push}


func load_dict(d: Dictionary) -> void:
	var cs: Dictionary = d.get("corners", {}) if d.get("corners") is Dictionary else {}
	for id in cs:
		if corners.has(id) and cs[id] is Dictionary:
			corners[id].owner = str(cs[id].get("owner", corners[id].owner))
			corners[id].control = clampf(float(cs[id].get("control", corners[id].control)), 0.0, 100.0)
			corners[id].push_crew = ""
	next_push = float(d.get("next_push", next_push))
