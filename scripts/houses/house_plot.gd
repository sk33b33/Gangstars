class_name HousePlot
extends Node3D
## The game's own bit of a real house, built from HouseData: its front door (that opens), the house
## number, the stoep and the knock interaction. The house itself is drawn by the real map. Local frame:
## the origin is SETBACK in front of the door wall, +Z towards the street.

const SETBACK := 4.0

var data: HouseData
var door_interactable: Interactable
var _door_local := Vector3.ZERO
var _door_hinge: Node3D
var _door_tween: Tween


## Real-world mode: the home is a real building (drawn by the real map), so the plot adds only what
## the game needs at its front door: a door that opens, the house number, the stoep, the light on the
## step, and the door to knock on. The plot's origin is SETBACK in front of the door wall, +Z towards
## the street, exactly as for a kit house, so everything that asks the plot for its door or gate works.


func build_real(house: HouseData) -> void:
	data = house
	name = house.id
	transform = house.plot_transform()
	var front_z := -SETBACK
	var face := front_z + 0.05
	_door_local = Vector3(0.0, 0.0, front_z + 0.9)
	Geo.quad(self, Vector2(1.0, 2.0), Vector3(0.0, 1.0, face - 0.01), PixelMaterials.flat(Color("#141218")))
	_door_hinge = Node3D.new()
	_door_hinge.name = "DoorHinge"
	_door_hinge.position = Vector3(-0.5, 0.0, face + 0.01)
	add_child(_door_hinge)
	Geo.quad(_door_hinge, Vector2(1.0, 2.0), Vector3(0.5, 1.0, 0.0), PixelMaterials.panel("door_gate"))
	Geo.box(self, Vector3(2.2, 0.1, 1.4), Vector3(0.0, 0.05, front_z + 0.7), PixelMaterials.surface("sidewalk", Vector2(2, 2)), false)
	Geo.label(self, str(house.number), Vector3(0.85, 2.1, face + 0.01), 72, Color("#1d1b24"))
	if data.occupancy != "vacant":
		NightGlow.add(self, Vector3(0.0, 0.045, face + 1.1), Vector2(2.4, 2.0))
	door_interactable = Interactable.new()
	door_interactable.name = "Door"
	door_interactable.position = _door_local + Vector3(0, 1.0, 0)
	door_interactable.prompt = "Knock on %s" % house.address()
	door_interactable.kind = "door"
	door_interactable.target = house.id
	if house.ownership == "player":
		door_interactable.prompt = "Enter safehouse (%s)" % house.address()
	add_child(door_interactable)


func _door_x() -> float:
	return 0.0


## The open front yard between the fence and the house, in plot-local space (+Z = street side),
## kept clear of the fences. Yard dogs live here.
func front_yard() -> Rect2:
	return Rect2(-3.0, -SETBACK + 0.6, 6.0, SETBACK - 1.1)   # the strip in front of the door


## Swings the front door open and closed again (someone entering, leaving or answering).
func open_door(hold := 1.4) -> void:
	if _door_hinge == null or not is_inside_tree():
		return
	if _door_tween and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(_door_hinge, "rotation:y", 1.35, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_door_tween.tween_interval(hold)
	_door_tween.tween_property(_door_hinge, "rotation:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_door_open() -> bool:
	return _door_hinge != null and _door_hinge.rotation.y > 0.1


## Visible safehouse upgrades (props on the plot). Idempotent.
func show_upgrade(upgrade_id: String) -> void:
	if has_node("upgrade_" + upgrade_id):
		return
	var root := Node3D.new()
	root.name = "upgrade_" + upgrade_id
	add_child(root)
	var kit := {"door_x": _door_x()}
	var front_z := -SETBACK
	match upgrade_id:
		"security_light":
			Geo.box(root, Vector3(0.5, 0.25, 0.25), Vector3(kit.door_x, 2.45, front_z + 0.15), PixelMaterials.lamp(), false)
		"mural":
			var mural := PixelMaterials.flat(Color("#e2585e"))
			Geo.box(root, Vector3(2.2, 1.6, 0.04), Vector3(kit.door_x - 2.6, 1.3, front_z + 0.03), mural, false)
			Geo.box(root, Vector3(1.4, 0.9, 0.05), Vector3(kit.door_x - 2.6, 1.3, front_z + 0.05), PixelMaterials.flat(Color("#f1d36b")), false)
			Geo.box(root, Vector3(0.6, 0.4, 0.06), Vector3(kit.door_x - 2.6, 1.3, front_z + 0.07), PixelMaterials.flat(Color("#2f6e3a")), false)
		"stash":
			Geo.box(root, Vector3(0.7, 0.5, 0.5), Vector3(kit.door_x + 2.4, 0.25, front_z + 1.6), PixelMaterials.flat(Color("#6b4630")), false)
		"crew_lounge":
			for dx in [-1.1, 1.1]:
				Geo.box(root, Vector3(0.5, 0.45, 0.5), Vector3(kit.door_x + dx, 0.32, front_z + 0.9), PixelMaterials.flat(Color("#2e86c1")), false)
				Geo.box(root, Vector3(0.5, 0.5, 0.08), Vector3(kit.door_x + dx, 0.75, front_z + 0.66), PixelMaterials.flat(Color("#2e86c1")), false)


func door_position() -> Vector3:
	return to_global(_door_local)


## Point on the sidewalk just outside the garden gate (crew guard spot, meeting point).
func gate_position() -> Vector3:
	return to_global(Vector3(_door_local.x, 0.0, 1.0))
