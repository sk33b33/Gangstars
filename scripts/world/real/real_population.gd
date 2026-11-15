class_name RealPopulation
extends Node
## The people of the real Westridge. Residents live in real houses (a door on the wall nearest the
## street), leave on a daily schedule, walk the real streets with NavigationAgent3D to real places
## (shops, parks, the civic centre, a neighbour, the corner) and go home again. They are the same
## `Resident` as in the old districts, so they keep their states, greetings and recovery.
## People exist only where the world has navigation (near you); a home whose chunk loses its
## navigation gives up its residents. Design: design/gdd/real_world.md.

const RESIDENT_SCENE := preload("res://scenes/npcs/resident.tscn")
const PEOPLE_FILE := "res://data/world/westridge/people.json"

## Hard cap on residents alive at once, and how many homes per chunk get one.
@export var max_residents := 48
@export var homes_per_chunk := 6
@export var near_distance := 45.0
@export var mid_distance := 110.0

var world: RealWorld
var clock := SimClock.new()
var player: Node3D
var residents := {}        # resident id -> Resident
var by_chunk := {}         # chunk key -> [resident ids]
var spots := SpotRegistry.new()
var spawned_total := 0
var _pools: Dictionary = {}
var _tier_accum := 0.0
var _spawn_queue: Array[Vector2i] = []


func setup(p_world: RealWorld, p_player: Node3D) -> void:
	world = p_world
	player = p_player
	var raw: Variant = DataFiles.load_json(PEOPLE_FILE)
	_pools = raw if raw is Dictionary else {}
	clock.set_hour(8.0)
	world.nav_ready.connect(func(key: Vector2i): _spawn_queue.append(key))
	world.nav_removed.connect(_despawn_chunk)


func _physics_process(delta: float) -> void:
	if world == null:
		return
	clock.advance(delta)
	if not _spawn_queue.is_empty():
		var key: Vector2i = _spawn_queue[0]
		if not world.nav_regions.has(key):
			_spawn_queue.pop_front()   # freed again before anyone moved in
		elif world.nav_synced(world.data.chunk_centre(key)):   # people need the map to know their street
			_spawn_queue.pop_front()
			spawn_chunk(key)
	_tier_accum += delta
	if _tier_accum >= 0.5:
		_tier_accum = 0.0
		_update_tiers()


func _update_tiers() -> void:
	var origin := player.global_position if player else Vector3.ZERO
	for r: Resident in residents.values():
		var d := r.global_position.distance_to(origin)
		r.set_tier("near" if d < near_distance else ("mid" if d < mid_distance else "far"))


## Gives some of the chunk's homes a resident (the same homes every time: picked by house id).
func spawn_chunk(key: Vector2i) -> void:
	if by_chunk.has(key) or not world.nav_regions.has(key):
		return
	var homes: Array = world.houses.get(key, []).duplicate()
	homes.sort_custom(func(a, b): return str(a.id).hash() < str(b.id).hash())
	var ids: Array = []
	for h in homes:
		if ids.size() >= homes_per_chunk or residents.size() >= max_residents:
			break
		var r := _spawn(h)
		if r:
			ids.append(r.data.id)
	by_chunk[key] = ids


func _spawn(home: Dictionary) -> Resident:
	var npc := NpcData.from_dict(make_person(home))
	if npc.schedule.is_empty():
		return null
	var r: Resident = RESIDENT_SCENE.instantiate()
	add_child(r)
	r.setup(npc, world.places, spawned_total * 0.11, clock, _lookup)
	r.spots = spots
	residents[npc.id] = r
	spawned_total += 1
	return r


func _lookup(id: String) -> Node3D:
	if id == "player":
		return player
	return residents.get(id)


## A resident for a home: name, look and a day made of the real places nearest that home.
func make_person(home: Dictionary) -> Dictionary:
	var hid := str(home.id)
	var h := absi(hid.hash())
	var woman := h % 2 == 0
	var firsts: Array = _pools.get("first_f" if woman else "first_m", ["Sam"])
	var surnames: Array = _pools.get("surnames", ["Daniels"])
	var lines: Array = _pools.get("lines", ["Hello."])
	var door: Vector3 = home.door
	var schedule: Array = []
	var shop := _nearest("shop", door, 700.0)
	var park := _nearest("park", door, 500.0)
	var meet := _nearest("gathering", door, 700.0)
	var neighbour := _neighbour(hid, door)
	if h % 3 != 0 and not shop.is_empty():
		schedule.append({"activity": "shopping", "destination": shop, "duration": 14 + h % 9, "window": [8, 18]})
	if not neighbour.is_empty():
		schedule.append({"activity": "visiting", "destination": neighbour, "duration": 12 + h % 11, "window": [9, 20]})
	if h % 2 == 0 and not park.is_empty():
		schedule.append({"activity": "relaxing", "destination": park, "duration": 16 + h % 7, "window": [9, 19]})
	if h % 4 == 1 and not meet.is_empty():
		schedule.append({"activity": "socializing", "destination": meet, "duration": 18, "window": [10, 21]})
	if schedule.is_empty():
		return {"id": "r_" + hid, "home_id": hid, "schedule": []}
	schedule.append({"activity": "home", "destination": "home", "duration": 20 + h % 25})
	return {
		"id": "r_" + hid, "home_id": hid, "role": "resident",
		"display_name": "%s %s" % [firsts[h / 7 % firsts.size()], surnames[h / 13 % surnames.size()]],
		"shirt_color": _pick("shirts", h / 17), "pants_color": _pick("pants", h / 19), "skin_color": _pick("skins", h / 23),
		"walk_speed": 1.35 + float(h % 40) / 100.0, "start_delay": float(h % 45), "personality": ["steady", "gossip", "shy"][h % 3],
		"active_hours": [6, 22], "schedule": schedule,
		"lines": [lines[h % lines.size()], lines[h / 3 % lines.size()]],
		"sleeves": "short" if h % 5 < 3 else "long",
	}


func _pick(pool: String, n: int) -> String:
	var list: Array = _pools.get(pool, ["#808080"])
	return str(list[n % list.size()])


func _nearest(kind: String, from: Vector3, max_distance: float) -> String:
	var id := world.places.nearest_of_kind(from, kind)
	return id if not id.is_empty() and world.places.anchor_position(id).distance_to(from) <= max_distance else ""


## Another home's door within 120 m (someone to visit).
func _neighbour(home_id: String, from: Vector3) -> String:
	var best := ""
	var best_score := INF
	for key: Vector2i in world.houses:
		if world.data.chunk_centre(key).distance_to(from) > 320.0:
			continue
		for h in world.houses[key]:
			if str(h.id) == home_id:
				continue
			var d: float = (h.door as Vector3).distance_to(from)
			if d < 25.0 or d > 120.0:
				continue
			var score := float(absi((home_id + str(h.id)).hash()) % 1000)   # a fixed friend, not just the closest house
			if score < best_score:
				best_score = score
				best = str(h.id) + ":door"
	return best


func _despawn_chunk(key: Vector2i) -> void:
	for id in by_chunk.get(key, []):
		var r: Resident = residents.get(id)
		if r:
			residents.erase(id)
			r.queue_free()
	by_chunk.erase(key)


func outdoors() -> int:
	var n := 0
	for r: Resident in residents.values():
		if not r.is_inside:
			n += 1
	return n
