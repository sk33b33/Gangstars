class_name SpotRegistry
extends RefCounted
## Places a resident can settle into while dwelling somewhere: "sit" spots (benches, stoep chairs)
## and "lean" spots (walls people hang out against). Built once from Marker3D nodes in the groups
## "spot_sit" / "spot_lean" (benches, chairs and walls add them as they are built). A spot is
## claimed by one resident at a time. Purely cosmetic: schedules and the brain never depend on it.

const KINDS := ["sit", "lean"]
## How far in front of the spot the resident walks to before stepping/sitting into it
## (outside the bench or wall collider, on the navigation mesh).
const APPROACH := {"sit": 0.85, "lean": 0.55}

var _spots: Array[Dictionary] = []   # {position, yaw, kind, owner}


func collect(root: Node) -> void:
	_spots.clear()
	for kind in KINDS:
		for m in root.find_children("*", "Marker3D", true, false):
			if m.is_in_group("spot_" + kind):
				var t: Transform3D = (m as Marker3D).global_transform
				_spots.append({"position": t.origin, "yaw": (m as Marker3D).global_rotation.y, "kind": kind, "owner": ""})


func size() -> int:
	return _spots.size()


func count(kind: String) -> int:
	return _spots.filter(func(s): return s.kind == kind).size()


## Nearest free spot of one of `kinds` within max_dist of `near`, claimed for `who`; -1 if none.
func claim(near: Vector3, kinds: Array, max_dist: float, who: String) -> int:
	var best := -1
	var best_d := max_dist
	for i in _spots.size():
		var s := _spots[i]
		if not str(s.owner).is_empty() or not kinds.has(s.kind):
			continue
		var d := near.distance_to(s.position)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_spots[best].owner = who
	return best


func release(i: int, who: String) -> void:
	if i >= 0 and i < _spots.size() and _spots[i].owner == who:
		_spots[i].owner = ""


func owner_of(i: int) -> String:
	return str(_spots[i].owner) if i >= 0 and i < _spots.size() else ""


func kind(i: int) -> String:
	return str(_spots[i].kind)


func position(i: int) -> Vector3:
	return _spots[i].position


func yaw(i: int) -> float:
	return _spots[i].yaw


## Where to stand before settling in: in front of the spot along its facing.
func approach(i: int) -> Vector3:
	var s := _spots[i]
	return s.position + Vector3(sin(s.yaw), 0, cos(s.yaw)) * float(APPROACH[s.kind])


## A Marker3D for a spot, facing local +Z (the way the person will face).
static func marker(parent: Node3D, kind: String, local_pos: Vector3, rot_y := 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.position = local_pos
	m.rotation.y = rot_y
	m.add_to_group("spot_" + kind)
	parent.add_child(m)
	return m
