class_name WeaponLibrary
extends RefCounted
## Weapon meshes (tools/blender/build_weapons.py -> weapons.glb) and their game stats.
## Stylised and generic. Damage is "knock-down" damage: nobody dies, people go down and get up.

const SOURCE := "res://assets/models/weapons/weapons.glb"
## damage per hit, shots per second, range (m), spread (radians), pellets, two_handed (long gun)
const STATS := {
	"pistol": {"damage": 22.0, "rate": 3.0, "range": 35.0, "spread": 0.035, "pellets": 1, "long": false, "sound_pitch": 1.0},
	"shotgun": {"damage": 14.0, "rate": 1.1, "range": 16.0, "spread": 0.12, "pellets": 5, "long": true, "sound_pitch": 0.7},
}

static var _meshes: Dictionary = {}


static func mesh(weapon: String) -> Mesh:
	if _meshes.is_empty():
		var root: Node = (load(SOURCE) as PackedScene).instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			_meshes[str(mi.name)] = (mi as MeshInstance3D).mesh
		root.free()
	return _meshes.get(weapon)


static func stats(weapon: String) -> Dictionary:
	return STATS.get(weapon, {})


static func is_long(weapon: String) -> bool:
	return bool(STATS.get(weapon, {}).get("long", false))
