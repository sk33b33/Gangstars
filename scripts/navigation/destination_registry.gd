class_name DestinationRegistry
extends RefCounted
## Resolves stable destination IDs (POIs, house doors) to points on the navigation map.
## NPC behaviour asks for an ID; this class owns where that ID is. Anchors have a radius so
## several NPCs spread out instead of stacking on one coordinate.

var navigation_map: RID
var _anchors: Dictionary = {}  # id -> {position, radius, kind, name, enabled}


func register(id: String, position: Vector3, radius: float, kind: String, display_name: String) -> void:
	_anchors[id] = {"position": position, "radius": radius, "kind": kind, "name": display_name, "enabled": true}


func has(id: String) -> bool:
	return _anchors.has(id)


func is_available(id: String) -> bool:
	return _anchors.has(id) and _anchors[id].enabled


func set_enabled(id: String, enabled: bool) -> void:
	if _anchors.has(id):
		_anchors[id].enabled = enabled


func all_ids() -> PackedStringArray:
	return PackedStringArray(_anchors.keys())


func ids_of_kind(kind: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for id in _anchors:
		if _anchors[id].kind == kind:
			out.append(id)
	return out


func anchor_position(id: String) -> Vector3:
	return _anchors[id].position if _anchors.has(id) else Vector3.ZERO


func display_name(id: String) -> String:
	return _anchors[id].name if _anchors.has(id) else id


## Returns a Vector3 on the navigation map near the anchor, or null if unknown/disabled.
func resolve(id: String, rng: RandomNumberGenerator, extra_jitter := 0.0) -> Variant:
	if not is_available(id):
		return null
	var a: Dictionary = _anchors[id]
	var r: float = a.radius + extra_jitter
	var p: Vector3 = a.position + Vector3(rng.randf_range(-r, r), 0.0, rng.randf_range(-r, r))
	if navigation_map.is_valid():
		p = NavigationServer3D.map_get_closest_point(navigation_map, p)
	return p
