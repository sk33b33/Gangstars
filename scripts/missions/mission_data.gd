class_name MissionData
extends Resource
## One mission, loaded from data/missions/*.json. Objectives run in order.
## Objective types:
##   talk_to {target: npc_id, allow_knock?: bool}  - talk to them (or knock their home while they're in)
##   knock {target: house_id}                       - knock on a house door
##   visit {target: anchor_id, radius?, window?}    - stand near a place (optionally during hours)
##   talk_distinct {count}                          - talk to N different residents
##   reputation {value}                             - reach a reputation level
##   hold {target, radius, minutes, window?, with_crew?} - stay at a place for N game minutes
##                                                    (leaving resets; optionally with crew nearby)
##   district_unlocked {target: district_id}        - a district has been unlocked
##   enter_vehicle {target: vehicle_id}             - get into that car
##   drive_to {target, radius, vehicle?}            - arrive somewhere while driving
## visit / talk_distinct may add "event": id       - only counts while that calendar event runs

const OBJECTIVE_TYPES: PackedStringArray = ["talk_to", "knock", "visit", "talk_distinct", "reputation", "hold", "district_unlocked", "enter_vehicle", "drive_to"]

@export var id := ""
@export var title := ""
@export var description := ""
@export var giver := ""            # npc id; empty + auto_start = starts by itself
@export var auto_start := false
@export var intro := ""
@export var prerequisites: Dictionary = {}   # {missions: [], reputation: n, crew: n}
@export var objectives: Array = []
@export var rewards: Dictionary = {}
@export var time_limit_minutes := 0.0         # game minutes; 0 = no limit
@export var fail_text := ""


static func from_dict(d: Dictionary) -> MissionData:
	var m := MissionData.new()
	m.id = str(d.get("id", ""))
	m.title = str(d.get("title", m.id))
	m.description = str(d.get("description", ""))
	m.giver = str(d.get("giver", ""))
	m.auto_start = bool(d.get("auto_start", false))
	m.intro = str(d.get("intro", ""))
	m.prerequisites = d.get("prerequisites", {}) if d.get("prerequisites") is Dictionary else {}
	m.objectives = d.get("objectives", []) if d.get("objectives") is Array else []
	m.rewards = d.get("rewards", {}) if d.get("rewards") is Dictionary else {}
	m.time_limit_minutes = float(d.get("time_limit_minutes", 0.0))
	m.fail_text = str(d.get("fail_text", ""))
	return m


func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	if id.is_empty():
		problems.append("mission without id")
	if objectives.is_empty():
		problems.append("%s: no objectives" % id)
	if giver.is_empty() and not auto_start:
		problems.append("%s: needs a giver or auto_start" % id)
	for o in objectives:
		if not o is Dictionary or not OBJECTIVE_TYPES.has(str(o.get("type", ""))):
			problems.append("%s: bad objective %s" % [id, o])
		elif o.type in ["talk_to", "knock", "visit", "hold", "district_unlocked", "enter_vehicle", "drive_to"] and str(o.get("target", "")).is_empty():
			problems.append("%s: objective %s needs a target" % [id, o.get("id", "?")])
	return problems


static func load_file(path: String) -> Array[MissionData]:
	var out: Array[MissionData] = []
	var raw: Variant = DataFiles.load_json(path)
	if not raw is Dictionary:
		return out
	var seen := {}
	for e in raw.get("missions", []):
		if not e is Dictionary:
			continue
		var m := MissionData.from_dict(e)
		var problems := m.validate()
		if seen.has(m.id):
			problems.append("duplicate mission id " + m.id)
		if not problems.is_empty():
			for p in problems:
				push_warning("MissionData: " + p)
			continue
		seen[m.id] = true
		out.append(m)
	return out
