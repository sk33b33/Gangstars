class_name HouseData
extends Resource
## One house plot. Loaded from data/houses/*.json. `id` is the stable save key.

const KITS: PackedStringArray = ["single_hip", "single_gable", "double_semi", "double_garage", "flats", "row_house"]
const FACING_ROTATION := {"south": 0.0, "north": PI, "east": PI * 0.5, "west": -PI * 0.5}
const OCCUPANCY: PackedStringArray = ["occupied", "vacant"]
const OWNERSHIP: PackedStringArray = ["neutral", "friendly", "hostile", "player", "mission"]

@export var id: String = ""
@export var number: int = 0
@export var street: String = ""
@export var display_name: String = ""
@export var district_id: String = ""
@export var kit: String = "single_hip"
## World x/z of the plot's front-centre (the street fence line).
@export var position: Vector2 = Vector2.ZERO
## Direction the front door faces ("north" = towards -Z).
@export var facing: String = "north"
@export var plot_size: Vector2 = Vector2(12, 14)
@export var wall_color: Color = Color.WHITE
@export var roof: String = "tiles"
@export var fence: String = "precast"
@export var fence_color: Color = Color.WHITE
@export var occupancy: String = "occupied"
@export var ownership: String = "neutral"
@export var occupant_ids: PackedStringArray = []
## Plot dressing: {yard: sand|paved|lawn, bin, dish, washing, wendy, tree, gate: bool}.
@export var props: Dictionary = {}


func address() -> String:
	return "%d %s" % [number, street] if not street.is_empty() else "No. %d" % number


func entrance_id() -> String:
	return id + ":door"


func plot_transform() -> Transform3D:
	var basis := Basis(Vector3.UP, FACING_ROTATION.get(facing, 0.0))
	return Transform3D(basis, Vector3(position.x, 0.0, position.y))


## Returns a list of human-readable problems; empty means valid.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	if id.is_empty():
		problems.append("house has empty id")
	if not KITS.has(kit):
		problems.append("%s: unknown kit '%s'" % [id, kit])
	if not FACING_ROTATION.has(facing):
		problems.append("%s: unknown facing '%s'" % [id, facing])
	if not OCCUPANCY.has(occupancy):
		problems.append("%s: unknown occupancy '%s'" % [id, occupancy])
	if not OWNERSHIP.has(ownership):
		problems.append("%s: unknown ownership '%s'" % [id, ownership])
	if occupancy == "occupied" and occupant_ids.is_empty():
		problems.append("%s: occupied but has no occupant_ids" % id)
	return problems


static func from_dict(d: Dictionary, default_district: String) -> HouseData:
	var h := HouseData.new()
	h.id = str(d.get("id", ""))
	h.number = int(d.get("number", 0))
	h.street = str(d.get("street", ""))
	h.display_name = str(d.get("display_name", ""))
	h.district_id = str(d.get("district_id", default_district))
	h.kit = str(d.get("kit", "single_hip"))
	h.position = DataFiles.to_vec2(d.get("position"))
	h.facing = str(d.get("facing", "north"))
	h.plot_size = DataFiles.to_vec2(d.get("plot_size"), Vector2(12, 14))
	h.wall_color = DataFiles.to_color(d.get("wall_color"))
	h.roof = str(d.get("roof", "tiles"))
	h.fence = str(d.get("fence", "precast"))
	h.fence_color = DataFiles.to_color(d.get("fence_color"))
	h.occupancy = str(d.get("occupancy", "occupied"))
	h.ownership = str(d.get("ownership", "neutral"))
	h.occupant_ids = PackedStringArray(d.get("occupant_ids", []))
	h.props = d.get("props", {}) if d.get("props") is Dictionary else {}
	return h
