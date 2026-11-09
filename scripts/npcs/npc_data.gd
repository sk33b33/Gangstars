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
## Array of {activity: String, destination: String, duration: float}; destination "home" = own door.
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
	for e in d.get("schedule", []):
		if e is Dictionary and e.has("destination"):
			n.schedule.append({
				"activity": str(e.get("activity", "idle")),
				"destination": str(e.destination),
				"duration": maxf(1.0, float(e.get("duration", 10.0))),
			})
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
