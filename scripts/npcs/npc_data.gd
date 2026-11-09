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
## Appearance (see CharacterModel): hair style/colour, height (1.0 = 1.75 m), sleeves.
@export var hair_style: String = "short"
@export var hair_color: Color = Color("#1d1b24")
@export var height: float = 1.0
@export var sleeves: String = "long"
## Body shape (blend shapes on the rigged model): figure 0 = straight, 1 = curvy; heavy 0..1.
## -1 = derive from the id (doek/long hair lean curvy), so generated data needs no new fields.
@export var figure: float = -1.0
@export var heavy: float = -1.0
@export var skirt: int = -1   # -1 derive, 0 trousers, 1 skirt
## Extras shown on the model (see CharacterModel.ACCESSORIES), e.g. glasses, beard, apron.
@export var accessories: PackedStringArray = []
@export var apron_color: Color = Color("#ece8dc")

## Hand-made looks for named characters, merged over generated data (see data/npcs/looks.json).
const LOOKS_FILE := "res://data/npcs/looks.json"
static var _looks: Dictionary = {}


func appearance() -> Dictionary:
	var h := absi(hash(id))
	var fig := figure if figure >= 0.0 else (0.85 + float(h % 15) / 100.0 if hair_style in ["long", "doek"] else 0.0)
	var hv := heavy if heavy >= 0.0 else (float(h / 7 % 60) / 100.0 if h % 3 == 0 else float(h / 7 % 15) / 100.0)
	var sk := skirt == 1 or (skirt == -1 and fig > 0.5 and h / 11 % 2 == 0)
	return {"hair_style": hair_style, "hair_color": hair_color, "height": height, "sleeves": sleeves,
		"figure": fig, "heavy": hv, "skirt": sk, "accessories": Array(accessories), "apron_color": apron_color}


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
	n.hair_style = str(d.get("hair_style", "short"))
	n.hair_color = DataFiles.to_color(d.get("hair_color"), Color("#1d1b24"))
	n.height = clampf(float(d.get("height", 1.0)), 0.55 if str(d.get("role", "")) == "kid" else 0.85, 1.12)
	n.sleeves = str(d.get("sleeves", "long"))
	n.figure = float(d.get("figure", -1.0))
	n.heavy = float(d.get("heavy", -1.0))
	n.skirt = int(d.get("skirt", -1))
	n.accessories = PackedStringArray(d.get("accessories", []))
	n.apron_color = DataFiles.to_color(d.get("apron_color"), Color("#ece8dc"))
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
		var n := NpcData.from_dict(with_look(e))
		if n.id.is_empty() or seen.has(n.id) or n.schedule.is_empty():
			push_warning("NpcData: skipping invalid or duplicate NPC '%s'" % n.id)
			continue
		seen[n.id] = true
		out.append(n)
	return out


## Resident data with its hand-made look (if any) merged over it.
static func with_look(d: Dictionary) -> Dictionary:
	if _looks.is_empty():
		var raw: Variant = DataFiles.load_json(LOOKS_FILE)
		_looks = raw.get("looks", {}) if raw is Dictionary else {}
		_looks["_loaded"] = true
	var look: Variant = _looks.get(str(d.get("id", "")))
	if not look is Dictionary:
		return d
	var merged := d.duplicate()
	merged.merge(look, true)
	return merged
