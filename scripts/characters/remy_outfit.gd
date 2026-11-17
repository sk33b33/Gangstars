class_name RemyOutfit
extends Resource
## What one NPC wears: a texture and a tint for each clothing slot, a skin tone, and parts to hide.
## Make one per NPC (or build them from data) and call RemyModel.apply_outfit(). Leave a texture empty to keep the
## original; the tint multiplies it (white = unchanged). Different meshes (a female body, another top) go through
## RemyModel.replace_part(). See scenes/characters/remy/README.md.

@export var skin_tint := Color.WHITE
@export var tops_texture: Texture2D
@export var tops_tint := Color.WHITE
@export var bottoms_texture: Texture2D
@export var bottoms_tint := Color.WHITE
@export var shoes_texture: Texture2D
@export var shoes_tint := Color.WHITE
@export var hair_texture: Texture2D
@export var hair_tint := Color.WHITE
## Slots to hide (for example "Hair" for a bald NPC, or "Tops" under a replacement that covers it).
@export var hidden: PackedStringArray = []


func apply(model: RemyModel) -> void:
	_part(model, "Body", null, skin_tint)   # (the eyes are left alone: their white would take the skin tone too)
	_part(model, "Tops", tops_texture, tops_tint)
	_part(model, "Bottoms", bottoms_texture, bottoms_tint)
	_part(model, "Shoes", shoes_texture, shoes_tint)
	_part(model, "Hair", hair_texture, hair_tint)
	for slot in RemyModel.SLOTS:
		model.set_part_visible(slot, not hidden.has(slot))


static func _part(model: RemyModel, slot: String, texture: Texture2D, tint: Color) -> void:
	if texture == null and tint == Color.WHITE:
		return   # nothing to change: keep the shared material
	if texture != null:
		model.set_part_texture(slot, texture)
	model.set_part_tint(slot, tint)
