class_name NpcData
extends Resource
## Static description of one NPC (loaded from data/npcs/*.json). Runtime state lives elsewhere.

@export var id: String = ""
@export var display_name: String = ""
@export var home_id: String = ""
@export var role: String = "resident"
@export var faction_id: String = ""
@export var shirt_color: Color = Color.GRAY
@export var pants_color: Color = Color.DIM_GRAY
@export var skin_color: Color = Color("#a7754f")
@export var walk_speed: float = 1.5
@export var start_delay: float = 0.0
## curious / timid / gossip / steady / tough (see ReactionPolicy).
@export var personality: String = "steady"
## Hours (start, end) the NPC is out and about; wraps midnight if start > end.
@export var active_hours: Vector2 = Vector2(6, 22)
## Array of {activity, destination, duration, window?: Vector2, route?: PackedStringArray}.
## destination "home" = own door; "@leader:<npc id>" = follow that NPC; route = patrol waypoints.
@export var schedule: Array = []
@export var lines: PackedStringArray = []


static func from_dict(d: Dictionary) -> NpcData:
	var n := NpcData.new()
	n.id = str(d.get("id", ""))
	n.display_name = str(d.get("display_name", n.id))
	n.home_id = str(d.get("home_id", ""))
	n.role = str(d.get("role", "resident"))
	n.faction_id = str(d.get("faction_id", ""))
	n.shirt_color = DataFiles.to_color(d.get("shirt_color"), Color.GRAY)
	n.pants_color = DataFiles.to_color(d.get("pants_color"), Color.DIM_GRAY)
	n.skin_color = DataFiles.to_color(d.get("skin_color"), Color("#a7754f"))
	n.walk_speed = clampf(float(d.get("walk_speed", 1.5)), 0.5, 4.0)
	n.start_delay = maxf(0.0, float(d.get("start_delay", 0.0)))
	n.personality = str(d.get("personality", "steady"))
	n.active_hours = DataFiles.to_vec2(d.get("active_hours"), Vector2(6, 22))
	for e in d.get("schedule", []):
		if not e is Dictionary or not (e.has("destination") or e.has("route")):
			continue
		var entry := {
			"activity": str(e.get("activity", "idle")),
			"destination": str(e.get("destination", "")),
			"duration": maxf(1.0, float(e.get("duration", 10.0))),
		}
		if e.has("window"):
			entry["window"] = DataFiles.to_vec2(e.window, Vector2(0, 24))
		if e.has("route"):
			entry["route"] = PackedStringArray(e.route)
			if entry.route.is_empty():
				continue
		n.schedule.append(entry)
	n.lines = PackedStringArray(d.get("lines", []))
	return n


static func load_file(path: String) -> Array[NpcData]:
	var out: Array[NpcData] = []
	var raw: Variant = DataFiles.load_json(path)
	if not raw is Dictionary:
		return out
	var seen := {}
	for e in raw.get("residents", []):
		if not e is Dictionary:
			continue
		var n := NpcData.from_dict(e)
		if n.id.is_empty() or seen.has(n.id) or n.schedule.is_empty():
			push_warning("NpcData: skipping invalid or duplicate NPC '%s'" % n.id)
			continue
		seen[n.id] = true
		out.append(n)
	return out
