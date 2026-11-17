class_name NpcBodies
extends RefCounted
## Chooses and builds the body a resident wears (NpcBodyModel). `enabled = false` brings back the old CharacterModel
## everywhere (the tests that look at its hair, faces and accessories turn it off while they run).

const MEN: PackedStringArray = ["James", "Leonard"]
const WOMEN: PackedStringArray = ["Kate", "Louise", "Meegan"]
## Crew in hoodie and headphones, the police in the dark sweater.
const CREW := {"man": "James", "woman": "Meegan"}
const POLICE := "Leonard"

static var enabled := true


## The body name for a person: crew and police have their own, everyone else is picked by their id.
static func pick(id: String, role: String, woman: bool) -> String:
	if role == "police":
		return POLICE
	if role == "crew":
		return CREW.woman if woman else CREW.man
	var pool := WOMEN if woman else MEN
	return pool[absi(hash(id)) % pool.size()]


## A ready (not yet built/dressed) NpcBodyModel for a resident's data.
static func create(data: NpcData) -> NpcBodyModel:
	return make(data.id, data.role, float(data.appearance().figure) > 0.5)


static func make(id: String, role: String, woman: bool) -> NpcBodyModel:
	var m := NpcBodyModel.new()
	m.setup_body(pick(id, role, woman))
	return m


## Either kind of model (see `enabled`) for someone with this id, role and sex: for the interiors and the vendors, which
## build and dress it themselves.
static func model_for(id: String, role: String, woman: bool) -> Node3D:
	if enabled:
		return make(id, role, woman)
	return CharacterModel.new()
