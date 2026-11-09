class_name CharacterModel
extends Node3D
## Placeholder low-poly person (legs, torso, head, eyes facing +Z) with a walk bob.
## Swap for a rigged model later without touching movement or AI code.

var _bob_time := 0.0
var _torso: Node3D


func build(shirt: Color, pants: Color, skin: Color, hat: Color = Color(0, 0, 0, 0)) -> void:
	var legs := BoxMesh.new()
	legs.size = Vector3(0.36, 0.8, 0.22)
	_add(legs, Vector3(0, 0.4, 0), pants)
	_torso = Node3D.new()
	add_child(_torso)
	var body := CapsuleMesh.new()
	body.radius = 0.24
	body.height = 0.8
	_add(body, Vector3(0, 1.15, 0), shirt, _torso)
	var head := SphereMesh.new()
	head.radius = 0.16
	head.height = 0.32
	_add(head, Vector3(0, 1.66, 0), skin, _torso)
	var eyes := BoxMesh.new()
	eyes.size = Vector3(0.18, 0.04, 0.04)
	_add(eyes, Vector3(0, 1.69, 0.15), Color("#1d1b24"), _torso)
	if hat.a > 0.0:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.16
		cap.bottom_radius = 0.17
		cap.height = 0.1
		_add(cap, Vector3(0, 1.8, 0), hat, _torso)
		var brim := BoxMesh.new()
		brim.size = Vector3(0.26, 0.03, 0.16)
		_add(brim, Vector3(0, 1.76, 0.18), hat, _torso)


## Call every frame with horizontal speed; bobs the torso while walking.
func animate(delta: float, speed: float) -> void:
	if _torso == null:
		return
	if speed > 0.1:
		_bob_time += delta * speed * 4.0
		_torso.position.y = absf(sin(_bob_time)) * 0.05
	else:
		_torso.position.y = move_toward(_torso.position.y, 0.0, delta)


func _add(mesh: Mesh, pos: Vector3, color: Color, parent: Node3D = self) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = PixelMaterials.flat(color)
	parent.add_child(mi)
