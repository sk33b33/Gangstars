class_name RealMap
extends RefCounted
## The real Mitchells Plain, from OpenStreetMap, inside the outline the player drew in KnoxMap
## (data/world/mitchells_plain.knoxmap.json). Built by tools/osm/build_real_map.py.
## Coordinates are metres from the outline's centre: x = east, y (z in the world) = south.
## Map data (c) OpenStreetMap contributors, ODbL 1.0.

const REAL_FILE := "res://data/world/mitchells_plain_real.json"
const STREETS_FILE := "res://data/world/mitchells_plain_streets.json"
const PLACES_FILE := "res://data/world/district_places.json"
const M_LAT := 110574.0

var credit := ""
var outline := PackedVector2Array()
var roads: Array = []        # {class: "freeway" | "main" | "collector", name, pts: PackedVector2Array}
var rail: Array = []         # PackedVector2Array
var suburbs: Array = []      # {name, at: Vector2}
var stations: Array = []     # {name, at: Vector2}
var bounds := Rect2()
var _origin := Vector2.ZERO  # lat, lon
var _places: Dictionary = {}


func load_data() -> bool:
	var d: Variant = DataFiles.load_json(REAL_FILE)
	if not d is Dictionary:
		return false
	credit = str(d.get("credit", ""))
	_origin = Vector2(float(d.origin.lat), float(d.origin.lon))
	outline = _line(d.get("outline", []))
	for r in d.get("roads", []):
		roads.append({"class": str(r["class"]), "name": str(r.get("name", "")), "pts": _line(r.pts)})
	for r in d.get("rail", []):
		rail.append(_line(r))
	for s in d.get("suburbs", []):
		suburbs.append({"name": str(s.name), "at": DataFiles.to_vec2(s.at)})
	for s in d.get("stations", []):
		stations.append({"name": str(s.name), "at": DataFiles.to_vec2(s.at)})
	if outline.is_empty():
		return false
	bounds = Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		bounds = bounds.expand(p)
	var places: Variant = DataFiles.load_json(PLACES_FILE)
	_places = places.get("places", {}) if places is Dictionary else {}
	return true


## Local residential streets (large; only loaded when a suburb is being laid out).
func load_streets() -> Array:
	var d: Variant = DataFiles.load_json(STREETS_FILE)
	var out: Array = []
	if d is Dictionary:
		for s in d.get("streets", []):
			out.append({"name": str(s.get("name", "")), "pts": _line(s.pts)})
	return out


func to_metres(lat: float, lon: float) -> Vector2:
	return Vector2((lon - _origin.y) * 111320.0 * cos(deg_to_rad(_origin.x)), -(lat - _origin.x) * M_LAT)


## Where a game district sits on the real map (null if it has no place).
func district_position(district_id: String) -> Variant:
	var p: Dictionary = _places.get(district_id, {})
	if p.has("metres"):
		return DataFiles.to_vec2(p.metres)
	if p.has("suburb"):
		return _named(suburbs, str(p.suburb))
	if p.has("station"):
		return _named(stations, str(p.station))
	if p.has("latlon"):
		return to_metres(float(p.latlon[0]), float(p.latlon[1]))
	return null


func road_names(road_class: String) -> PackedStringArray:
	var names := PackedStringArray()
	for r in roads:
		if r["class"] == road_class and not str(r.name).is_empty() and not names.has(str(r.name)):
			names.append(str(r.name))
	return names


static func _named(list: Array, place_name: String) -> Variant:
	for s in list:
		if s.name == place_name:
			return s.at
	return null


static func _line(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out
