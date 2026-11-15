class_name PivotRegistry
extends DestinationRegistry
## A registry seen from inside a turned landmark: anchors registered in the landmark's own frame are
## passed on to the real registry in world space. Used by StreetBuilder.build_real.

var target: DestinationRegistry
var pivot: Node3D


func _init(p_target: DestinationRegistry, p_pivot: Node3D) -> void:
	target = p_target
	pivot = p_pivot


func register(id: String, position: Vector3, radius: float, kind: String, display_name: String) -> void:
	target.register(id, pivot.transform * position, radius, kind, display_name)


func has(id: String) -> bool:
	return target.has(id)
