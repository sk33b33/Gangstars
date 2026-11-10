class_name DistrictManager
extends RefCounted
## The single authority for district state and unlocks (data: data/districts/districts.json).
## UI may *request* an unlock; only `unlock_district` changes state, and only when every
## requirement is met. Unlocked ids live in ProgressionState.unlocked_district_ids (saved).
##
## Starter influence (0-100) = stored influence (mission/upgrade rewards)
##                             + FRIENDLY_HOUSE_INFLUENCE per friendly house.

signal district_unlocked(district_id: String)
signal became_unlockable(district_id: String)

const FRIENDLY_HOUSE_INFLUENCE := 2
const FRIENDLY_RELATIONSHIP := 15
const CONTROLLED_INFLUENCE := 50

var districts: Dictionary = {}   # id -> Dictionary
var order: PackedStringArray = []
var progression: ProgressionState
var houses: HouseRegistry
var _announced: Dictionary = {}


static func load_file(path: String, p_progression: ProgressionState, p_houses: HouseRegistry) -> DistrictManager:
	var m := DistrictManager.new()
	m.progression = p_progression
	m.houses = p_houses
	var raw: Variant = DataFiles.load_json(path)
	if raw is Dictionary:
		for d in raw.get("districts", []):
			if d is Dictionary and d.has("id"):
				m.districts[str(d.id)] = d
				m.order.append(str(d.id))
	return m


func get_district(id: String) -> Dictionary:
	return districts.get(id, {})


func display_name(id: String) -> String:
	return str(get_district(id).get("display_name", id))


func is_unlocked(id: String) -> bool:
	return bool(get_district(id).get("is_initially_unlocked", false)) or progression.unlocked_district_ids.has(id)


func neighbours() -> Array:
	var out: Array = []
	for id in order:
		if districts[id].has("side"):
			out.append(districts[id])
	return out


## The rest of Mitchells Plain: listed on the turf map as future turf, not built yet.
func planned() -> Array:
	var out: Array = []
	for id in order:
		if bool(districts[id].get("planned", false)):
			out.append(districts[id])
	return out


## Turf state of a house for the map: player / hostile / friendly / vacant / neutral.
func house_state(house: HouseData) -> String:
	if house.ownership == "player":
		return "player"
	if house.ownership == "hostile":
		return "hostile"
	if house.occupancy == "vacant":
		return "vacant"
	for npc in house.occupant_ids:
		if progression.relationship(npc) >= FRIENDLY_RELATIONSHIP or progression.recruited_crew_ids.has(npc):
			return "friendly"
	return "neutral"


func friendly_houses(district_id := "starter") -> int:
	var n := 0
	if houses == null:
		return n
	for id in houses.order:
		var h := houses.get_house(id)
		if h.district_id == district_id and house_state(h) == "friendly":
			n += 1
	return n


func influence(district_id: String) -> int:
	var total := progression.district_influence(district_id)
	if district_id == "starter":
		total += friendly_houses(district_id) * FRIENDLY_HOUSE_INFLUENCE
	return clampi(total, 0, 100)


## "locked", "unlockable", "contested"/"controlled" once unlocked, or "planned" (not built yet).
func state(id: String) -> String:
	if bool(get_district(id).get("planned", false)):
		return "planned"
	if bool(get_district(id).get("is_initially_unlocked", false)):
		return "controlled" if influence(id) >= CONTROLLED_INFLUENCE else "contested"
	if is_unlocked(id):
		# Unlocked districts are turf like Westridge: contested until you build influence there.
		return "controlled" if influence(id) >= CONTROLLED_INFLUENCE else "contested"
	return "unlockable" if can_unlock(id) else "locked"


## Each requirement with whether it is met: [{text, met: bool}].
func get_unlock_requirements(id: String) -> Array:
	var req: Dictionary = get_district(id).get("unlock_requirements", {})
	var out: Array = []
	for m in req.get("missions", []):
		var done := progression.completed_mission_ids.has(str(m))
		out.append({"text": "Complete \"%s\"" % _mission_title(str(m)), "met": done})
	if req.has("reputation"):
		var need := int(req.reputation)
		out.append({"text": "Reputation %d/%d" % [mini(progression.reputation, need), need], "met": progression.reputation >= need})
	if req.has("crew"):
		var need := int(req.crew)
		var have := progression.recruited_crew_ids.size()
		out.append({"text": "Crew members %d/%d" % [mini(have, need), need], "met": have >= need})
	var infl: Dictionary = req.get("influence", {})
	for d in infl:
		var need := int(infl[d])
		var have := influence(d)
		out.append({"text": "%s influence %d%%/%d%%" % [display_name(d), mini(have, need), need], "met": have >= need})
	return out


func can_unlock(id: String) -> bool:
	if districts.is_empty() or not districts.has(id) or is_unlocked(id) or bool(districts[id].get("planned", false)):
		return false
	for r in get_unlock_requirements(id):
		if not r.met:
			return false
	return true


## Validates, then unlocks. Returns false (and changes nothing) if requirements aren't met.
func unlock_district(id: String) -> bool:
	if not can_unlock(id):
		return false
	progression.unlocked_district_ids.append(id)
	progression.district_control[id] = progression.district_influence(id)
	progression.changed.emit()
	district_unlocked.emit(id)
	return true


## Call when progression changes: announces districts that just became unlockable (once).
func check_unlockable() -> void:
	for d in neighbours():
		var id := str(d.id)
		if can_unlock(id) and not _announced.has(id):
			_announced[id] = true
			became_unlockable.emit(id)


var mission_titles: Dictionary = {}


func _mission_title(id: String) -> String:
	return str(mission_titles.get(id, id))
