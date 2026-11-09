class_name HouseRegistry
extends RefCounted
## All houses of a district, keyed by stable id. Invalid or duplicate entries are rejected
## and reported in `errors` instead of crashing the game.

var houses: Dictionary = {}  # id -> HouseData
var order: PackedStringArray = []
var errors: PackedStringArray = []


static func load_file(path: String) -> HouseRegistry:
	var reg := HouseRegistry.new()
	var raw: Variant = DataFiles.load_json(path)
	if not raw is Dictionary:
		reg.errors.append("could not load %s" % path)
		return reg
	var district: String = str(raw.get("district_id", ""))
	for entry in raw.get("houses", []):
		if entry is Dictionary:
			reg.add(HouseData.from_dict(entry, district))
	return reg


func add(house: HouseData) -> bool:
	var problems := house.validate()
	if houses.has(house.id):
		problems.append("duplicate house id '%s'" % house.id)
	if not problems.is_empty():
		errors.append_array(problems)
		for p in problems:
			push_warning("HouseRegistry: " + p)
		return false
	houses[house.id] = house
	order.append(house.id)
	return true


func get_house(house_id: String) -> HouseData:
	return houses.get(house_id)


func count() -> int:
	return houses.size()
