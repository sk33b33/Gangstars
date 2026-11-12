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
## The Mitchells Plain aunty look (house dress or maxi, slippers, hoops, doek or curlers,
## handbag, cardigan). -1 derive (most grown women residents), 0 never, 1 always.
@export var dress: int = -1
@export var dress_print: String = ""        # a CharacterModel.PRINTS name, "solid", or "" (pick)
@export var cardigan_color: Color = Color(0, 0, 0, 0)
@export var bag_color: Color = Color(0, 0, 0, 0)
@export var shoe_color: Color = Color(0, 0, 0, 0)
@export var face_override: String = ""     # a CharacterModel.FACES name; "" = by figure and age
@export var pants_style: String = ""       # "denim", "tracksuit", "plain" or "" (pick)
@export var sole_color: Color = Color(0, 0, 0, 0)

## Hand-made looks for named characters, merged over generated data (see data/npcs/looks.json).
const LOOKS_FILE := "res://data/npcs/looks.json"
static var _looks: Dictionary = {}


func appearance() -> Dictionary:
	var h := absi(hash(id))
	var fig := figure if figure >= 0.0 else (0.85 + float(h % 15) / 100.0 if hair_style in ["long", "doek"] else 0.0)
	var hv := heavy if heavy >= 0.0 else (float(h / 7 % 60) / 100.0 if h % 3 == 0 else float(h / 7 % 15) / 100.0)
	var sk := skirt == 1 or (skirt == -1 and fig > 0.5 and h / 11 % 2 == 0)
	var look := {"hair_style": _hair_for(h), "hair_color": hair_color, "height": height, "sleeves": sleeves,
		"figure": fig, "heavy": hv, "skirt": sk, "accessories": Array(accessories), "apron_color": apron_color}
	_everyday_look(look, h)
	if dress == 1 or (dress == -1 and skirt == -1 and accessories.is_empty() and role == "resident" and fig > 0.5 and height >= 0.85 and h / 13 % 4 != 0):
		_aunty_look(look, h)
	return look


## More hair variety for generated residents (hand-made looks keep their hair): short hair
## may be a fade or cornrows, long hair braids, a bun, curls or a ponytail.
func _hair_for(h: int) -> String:
	if _looks.has(id):
		return hair_style
	match hair_style:
		"short":
			return ["short", "fade", "cornrows", "short", "fade"][h / 73 % 5]
		"long":
			return ["long", "braids", "bun", "curls", "ponytail", "braids"][h / 73 % 6]
	return hair_style


## Faces, trousers, hoodies, soles and crew cap logos for everyone (hand-made looks can set
## face, pants_style, sole_color; "hood" goes in accessories).
func _everyday_look(look: Dictionary, h: int) -> void:
	var grey := hair_color.s < 0.15 and hair_color.v > 0.5
	var woman := float(look.figure) > 0.5
	var kid := role == "kid" or height < 0.85
	var face := face_override
	if face.is_empty():
		face = ("face_old_f" if woman else "face_old_m") if grey else ("face_f" if woman else "face_m")
		if not woman and not grey and not kid and h / 61 % 3 == 0 and not accessories.has("beard"):
			face = "face_stubble"
	look.face = face
	look.idle = ["idle", "idle", "idle_shift", "idle", "idle_shift", "idle_hips"][h / 83 % 6]
	if grey and not kid:
		look.stoop = 0.6 + float(h / 89 % 5) * 0.1
	elif role == "resident" and not woman and not kid and h / 79 % 6 == 0 and height >= 0.98 and height <= 1.02:
		look.height = 0.94   # a lanky teen
		look.heavy = 0.0
	if role == "police":
		look.sole_color = Color("#1d1b24")
		return
	var style := pants_style
	if style.is_empty():
		var pick := h / 67 % 3 if not grey else 2
		if role == "crew":
			pick = h / 67 % 2
		style = ["denim", "tracksuit", ""][pick]
	look.pants_style = style
	look.sole_color = sole_color if sole_color.a > 0.0 else (Color("#2a2622") if grey else Color("#ece8dc"))
	if not woman and not grey and not kid and accessories.is_empty() and h / 71 % (2 if role == "crew" else 4) == 0:
		var acc: Array = look.accessories
		acc.append("hood")
	if role == "crew" and not faction_id.is_empty():
		look.cap_logo = faction_id
	_outfit(look, h, woman, grey, kid)


## Outfits on top of the everyday look (generated residents only): school uniforms for most
## kids, work overalls for some men, and Sunday best (white shirt, dark jacket, tie) for some
## older men.
func _outfit(look: Dictionary, h: int, woman: bool, grey: bool, kid: bool) -> void:
	if _looks.has(id) or bool(look.get("dress", false)):
		return
	var acc: Array = look.accessories
	if kid and h / 97 % 5 < 3:
		look.shirt_override = Color("#f4f4f0")
		look.pants_override = Color("#5d6066")
		look.tie_color = Color("#7a1f2e")
		look.sole_color = Color("#1d1b24")
		look.pants_style = ""
		acc.append("tie")
		acc.append("backpack")   # the school bag
		look.pack_color = [Color("#2f3f6a"), Color("#3a3d46"), Color("#7a1f2e"), Color("#1f6a58")][h / 101 % 4]
	elif role == "resident" and not woman and not grey and not kid and h / 97 % 6 == 0:
		var c: Color = [Color("#2f4f8a"), Color("#d35400"), Color("#3d5a3a")][h / 101 % 3]
		look.pants_override = c
		look.overall_color = c
		look.pants_style = ""
		acc.erase("hood")
		acc.append("overall")
	elif role == "resident" and not woman and grey and h / 103 % 3 == 0:
		look.shirt_override = Color("#f4f4f0")
		look.pants_override = Color("#26262e")
		look.cardigan_color = Color("#2c2c34")
		look.tie_color = [Color("#7a1f2e"), Color("#2f4a6e"), Color("#5a4a1e")][h / 107 % 3]
		look.pants_style = ""
		look.sole_color = Color("#1d1b24")
		acc.append_array(["cardigan", "tie"])


const SLIPPERS := ["#f29bbd", "#7fc3e8", "#1d1b24", "#f4f4f0", "#c8a27a", "#e2585e"]
const CARDIGANS := ["#d8cbb0", "#f4f4f0", "#a7c0d6", "#c98aa5", "#8c6044", "#5b7097"]
const BAGS := ["#7a2e2a", "#1d1b24", "#c8a27a", "#e2585e", "#f2b632", "#f4f4f0"]
const HIJABS := ["#1d1b24", "#2f3f6a", "#6a2f4a", "#1f6a58", "#e8e2d0", "#7a6a8a"]
const DOEKS := ["#d9442e", "#2f6db8", "#9a6cc4", "#e86a8a", "#159a8c", "#f2b632"]


## A house dress or maxi in a bright print (or a bright solid colour), comfortable shoes and,
## by hash, hoops, a handbag, a cardigan and either curlers or a satin doek. Hand-made looks
## (data/npcs/looks.json) can set any part.
func _aunty_look(look: Dictionary, h: int) -> void:
	look.dress = true
	look.skirt = false
	var p := dress_print
	if p.is_empty():
		p = "solid" if h / 37 % 6 == 0 else CharacterModel.PRINTS[h / 37 % CharacterModel.PRINTS.size()]
	look.print = p
	look.shoe_color = shoe_color if shoe_color.a > 0.0 else Color(SLIPPERS[h / 41 % SLIPPERS.size()])
	look.cardigan_color = cardigan_color if cardigan_color.a > 0.0 else Color(CARDIGANS[h / 43 % CARDIGANS.size()])
	look.bag_color = bag_color if bag_color.a > 0.0 else Color(BAGS[h / 47 % BAGS.size()])
	if dress == 1:
		return   # a hand-made look lists its own accessories and hair
	var acc: Array = look.accessories
	if h / 17 % 5 < 3:
		acc.append("hoops")
	if h / 19 % 5 < 2:
		acc.append("handbag")
	if h / 23 % 3 == 0:
		acc.append("cardigan")
	if h / 29 % 5 == 0:
		acc.append("curlers")
		look.hair_style = "short"
	elif h / 29 % 5 < 3:
		look.hair_style = "doek"
		look.hair_color = Color(DOEKS[h / 31 % DOEKS.size()])
	if h / 59 % 5 < 2 and not acc.has("curlers"):   # a headscarf (the suburb has mosques in Westridge, Rocklands and the Town Centre)
		look.hair_style = "hijab"
		look.hair_color = Color(HIJABS[h / 61 % HIJABS.size()])


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
	if n.hair_color.s < 0.15 and n.hair_color.v > 0.5 and n.role == "resident":
		n.walk_speed *= 0.85   # older people walk a little slower
	n.dress = int(d.get("dress", -1))
	n.dress_print = str(d.get("print", ""))
	n.cardigan_color = DataFiles.to_color(d.get("cardigan_color"), Color(0, 0, 0, 0))
	n.bag_color = DataFiles.to_color(d.get("bag_color"), Color(0, 0, 0, 0))
	n.shoe_color = DataFiles.to_color(d.get("shoe_color"), Color(0, 0, 0, 0))
	n.face_override = str(d.get("face", ""))
	n.pants_style = str(d.get("pants_style", ""))
	n.sole_color = DataFiles.to_color(d.get("sole_color"), Color(0, 0, 0, 0))
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
