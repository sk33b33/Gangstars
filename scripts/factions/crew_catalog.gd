class_name CrewCatalog
extends RefCounted
## The joinable crews (data/factions/crews.json). All fictional: made-up names, colours and
## bosses, not real gangs. The player picks one at the start of a new game (see CrewPicker).

const FILE := "res://data/factions/crews.json"

var crews: Array = []        # [{id, name, home, home_name, colour, boss, perk, perk_text, pitch, warning}]
var _by_id := {}


static func load_default() -> CrewCatalog:
	var c := CrewCatalog.new()
	var raw: Variant = DataFiles.load_json(FILE)
	if raw is Dictionary:
		for e in raw.get("crews", []):
			if e is Dictionary and not str(e.get("id", "")).is_empty():
				c.crews.append(e)
				c._by_id[str(e.id)] = e
	return c


func has(id: String) -> bool:
	return _by_id.has(id)


func get_crew(id: String) -> Dictionary:
	return _by_id.get(id, {})


func display_name(id: String) -> String:
	return str(get_crew(id).get("name", id))


func colour(id: String) -> Color:
	return DataFiles.to_color(get_crew(id).get("colour"), Color.GRAY)


func home(id: String) -> String:
	return str(get_crew(id).get("home", ""))


func perk(id: String) -> String:
	return str(get_crew(id).get("perk", ""))


func ids() -> PackedStringArray:
	return PackedStringArray(crews.map(func(c): return str(c.id)))
