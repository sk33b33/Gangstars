class_name ProgressionState
extends RefCounted
## Player progression: the single source of truth for cash, reputation, crew, relationships,
## missions completed and safehouse upgrades. UI only observes it (signal `changed`).
## Rewards go through `grant(key, ...)`, which applies each key at most once, ever.

signal changed
signal recruited(npc_id: String)

const MAX_REPUTATION := 1000
const TALK_RELATIONSHIP := 2
const FIRST_MEET_REPUTATION := 1

var cash := 100
var reputation := 0
var crew_influence := 0
var district_control := {"starter": 0}
var completed_mission_ids: PackedStringArray = []
var failed_mission_counts := {}
var unlocked_district_ids: PackedStringArray = ["starter"]
var recruited_crew_ids: PackedStringArray = []
var relationships := {}
var met_npc_ids: PackedStringArray = []
var safehouse_upgrades: PackedStringArray = []
var granted_reward_keys: PackedStringArray = []
var talk_days := {}


func can_afford(amount: int) -> bool:
	return cash >= amount


func spend(amount: int) -> bool:
	if amount < 0 or cash < amount:
		return false
	cash -= amount
	changed.emit()
	return true


func add_cash(amount: int) -> void:
	cash = maxi(0, cash + amount)
	changed.emit()


func add_reputation(amount: int) -> void:
	reputation = clampi(reputation + amount, 0, MAX_REPUTATION)
	changed.emit()


func add_crew_influence(amount: int) -> void:
	crew_influence = maxi(0, crew_influence + amount)
	changed.emit()


func relationship(npc_id: String) -> int:
	return int(relationships.get(npc_id, 0))


func add_relationship(npc_id: String, amount: int) -> void:
	relationships[npc_id] = clampi(relationship(npc_id) + amount, -100, 100)
	changed.emit()


## Talking: the first meeting ever gives reputation; the first talk each game day builds the
## relationship. Returns true if anything was gained.
func register_talk(npc_id: String, day: int) -> bool:
	var gained := false
	if not met_npc_ids.has(npc_id):
		met_npc_ids.append(npc_id)
		reputation = clampi(reputation + FIRST_MEET_REPUTATION, 0, MAX_REPUTATION)
		gained = true
	if int(talk_days.get(npc_id, -1)) != day:
		talk_days[npc_id] = day
		relationships[npc_id] = clampi(relationship(npc_id) + TALK_RELATIONSHIP, -100, 100)
		gained = true
	if gained:
		changed.emit()
	return gained


func recruit(npc_id: String) -> bool:
	if recruited_crew_ids.has(npc_id):
		return false
	recruited_crew_ids.append(npc_id)
	changed.emit()
	recruited.emit(npc_id)
	return true


func district_influence(district_id: String) -> int:
	return int(district_control.get(district_id, 0))


func add_district_influence(district_id: String, amount: int) -> void:
	district_control[district_id] = clampi(district_influence(district_id) + amount, 0, 100)
	changed.emit()


## Applies rewards {cash, reputation, crew_influence, relationship: {npc: n},
## influence: {district: n}, recruit} once per key.
func grant(key: String, rewards: Dictionary) -> bool:
	if granted_reward_keys.has(key):
		return false
	granted_reward_keys.append(key)
	cash = maxi(0, cash + int(rewards.get("cash", 0)))
	reputation = clampi(reputation + int(rewards.get("reputation", 0)), 0, MAX_REPUTATION)
	crew_influence = maxi(0, crew_influence + int(rewards.get("crew_influence", 0)))
	var rel: Dictionary = rewards.get("relationship", {})
	for npc in rel:
		relationships[npc] = clampi(relationship(npc) + int(rel[npc]), -100, 100)
	var infl: Dictionary = rewards.get("influence", {})
	for d in infl:
		district_control[d] = clampi(district_influence(d) + int(infl[d]), 0, 100)
	changed.emit()
	if rewards.has("recruit"):
		recruit(str(rewards.recruit))
	return true


func to_dict() -> Dictionary:
	return {
		"cash": cash, "reputation": reputation, "crew_influence": crew_influence,
		"district_control": district_control.duplicate(),
		"completed_mission_ids": Array(completed_mission_ids),
		"failed_mission_counts": failed_mission_counts.duplicate(),
		"unlocked_district_ids": Array(unlocked_district_ids),
		"recruited_crew_ids": Array(recruited_crew_ids),
		"relationships": relationships.duplicate(),
		"met_npc_ids": Array(met_npc_ids),
		"safehouse_upgrades": Array(safehouse_upgrades),
		"granted_reward_keys": Array(granted_reward_keys),
		"talk_days": talk_days.duplicate(),
	}


## Validates then applies saved data. On any problem nothing changes and an error is returned.
func load_dict(d: Variant) -> String:
	if not d is Dictionary:
		return "progression is not an object"
	for key in ["cash", "reputation", "crew_influence"]:
		if not (d.get(key) is float or d.get(key) is int):
			return "progression.%s missing or not a number" % key
	for key in ["completed_mission_ids", "unlocked_district_ids", "recruited_crew_ids", "granted_reward_keys"]:
		if not d.get(key) is Array:
			return "progression.%s missing or not a list" % key
	if not (d.unlocked_district_ids as Array).has("starter"):
		return "progression.unlocked_district_ids lost the starter district"
	cash = maxi(0, int(d.cash))
	reputation = clampi(int(d.reputation), 0, MAX_REPUTATION)
	crew_influence = maxi(0, int(d.crew_influence))
	district_control = d.get("district_control", {"starter": 0}) if d.get("district_control") is Dictionary else {"starter": 0}
	completed_mission_ids = PackedStringArray(d.completed_mission_ids)
	failed_mission_counts = d.get("failed_mission_counts", {}) if d.get("failed_mission_counts") is Dictionary else {}
	unlocked_district_ids = PackedStringArray(d.unlocked_district_ids)
	recruited_crew_ids = PackedStringArray(d.recruited_crew_ids)
	relationships = d.get("relationships", {}) if d.get("relationships") is Dictionary else {}
	met_npc_ids = PackedStringArray(d.get("met_npc_ids", []))
	safehouse_upgrades = PackedStringArray(d.get("safehouse_upgrades", []))
	granted_reward_keys = PackedStringArray(d.granted_reward_keys)
	talk_days = d.get("talk_days", {}) if d.get("talk_days") is Dictionary else {}
	changed.emit()
	return ""
