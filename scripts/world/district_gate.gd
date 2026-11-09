class_name DistrictGate
extends Node3D
## Boom barrier where a street leaves the district. While its district is locked it blocks
## the street with a tall invisible collider (no jumping over) and shows the requirements
## hint; `set_open(true)` raises the boom, clears the collider and relabels the sign.
## Only the DistrictManager's unlock should open it (via District.set_district_open).

const COLLIDER_HEIGHT := 3.0

var district_id := ""
var display_name := ""
var is_open := false

var _boom: Node3D
var _body: StaticBody3D
var _label: Label3D
var _sign: MeshInstance3D
var _tween: Tween


## width = opening across the street (metres); face = +1 if the inside of the district is +X.
func setup(p_district_id: String, p_display_name: String, width: float, face: float) -> void:
	district_id = p_district_id
	display_name = p_display_name
	name = "Gate_%s_%d" % [district_id, get_index()]
	var red := PixelMaterials.flat(Color("#c0392b"))
	var white := PixelMaterials.flat(Color("#f1eee8"))
	var steel := PixelMaterials.flat(Color("#565a64"))
	var half := width * 0.5
	for z in [-half + 0.2, half - 0.2]:
		Geo.box(self, Vector3(0.3, 1.2, 0.3), Vector3(0, 0.6, z), steel, false)
	# Boom: pivots at the -Z post, red/white segments along +Z.
	_boom = Node3D.new()
	_boom.position = Vector3(0, 1.05, -half + 0.2)
	add_child(_boom)
	var length := width - 0.4
	var n := int(ceil(length))
	for i in n:
		var seg := minf(1.0, length - i)
		Geo.box(_boom, Vector3(0.12, 0.12, seg), Vector3(0, 0, i + seg * 0.5), red if i % 2 == 0 else white, false)
	# Tall invisible collider across the whole opening (carved out of the nav mesh too).
	_body = Geo.collider(self, Vector3(0.4, COLLIDER_HEIGHT, width), Vector3(0, COLLIDER_HEIGHT * 0.5, 0))
	_sign = Geo.quad(self, Vector2(2.6, 1.0), Vector3(face * 0.25, 1.9, half - 1.8), PixelMaterials.panel("sign_locked"), PI * 0.5 * face)
	Geo.box(self, Vector3(0.08, 1.5, 0.08), Vector3(face * 0.2, 0.75, half - 1.8), steel, false)
	_label = Geo.label(self, "", Vector3(face * 0.3, 2.85, 0), 72, Color("#ffd75e"), PI * 0.5 * face)
	_label.outline_modulate = Color("#1d1b24")
	_label.outline_size = 14
	_label.double_sided = false
	set_open(false, false)


func set_open(open: bool, animate := true) -> void:
	is_open = open
	# An open gate's collider leaves the tree entirely, so neither physics nor a navigation
	# re-bake can see it (layer filtering alone wasn't reliable for the bake).
	if open and _body.get_parent() == self:
		remove_child(_body)
	elif not open and _body.get_parent() == null:
		add_child(_body)
	_sign.visible = not open
	_label.text = ("%s — OPEN" % display_name.to_upper()) if open else ("%s — LOCKED TURF\nOpen the turf map (M / View) to see what it takes" % display_name.to_upper())
	_label.modulate = Color("#9fd8b8") if open else Color("#ffd75e")
	var target := -1.35 if open else 0.0
	if _tween and _tween.is_valid():
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(_boom, "rotation:x", target, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_boom.rotation.x = target


func _exit_tree() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_body) and _body.get_parent() == null:
		_body.free()


func blocks_movement() -> bool:
	return not is_open
