class_name DogModel
extends Node3D
## The neighbourhood dog (tools/blender/build_dog.py -> dog.glb), recoloured per dog. Faces +Z.
## idle/walk/trot blend by speed (playback scaled to the real speed), "lie" replaces standing,
## and bark() fires a one-shot head jerk. Advanced manually from animate().

const MODEL := preload("res://assets/models/animals/dog.glb")
const WALK_REF := 1.0
const TROT_REF := 2.6

var lying := false
var _tree: AnimationTree
var _speed := 0.0
var _lie := 0.0


func build(coat: Color, light: Color, size := 1.0) -> void:
	for c in get_children():
		c.queue_free()
	scale = Vector3.ONE * clampf(size, 0.7, 1.25)
	var root: Node3D = MODEL.instantiate()
	add_child(root)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var key := m.surface_get_material(i).resource_name if m.surface_get_material(i) else ""
			if key == "coat":
				mi.set_surface_override_material(i, PixelMaterials.flat(coat))
			elif key == "coat_light":
				mi.set_surface_override_material(i, PixelMaterials.flat(light))
	var player: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	for a in player.get_animation_list():
		player.get_animation(a).loop_mode = Animation.LOOP_NONE if a == "bark" else Animation.LOOP_LINEAR
	var loco := AnimationNodeBlendSpace1D.new()
	loco.max_space = TROT_REF
	loco.add_blend_point(_anim("idle"), 0.0)
	loco.add_blend_point(_anim("walk"), WALK_REF)
	loco.add_blend_point(_anim("trot"), TROT_REF)
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("loco", loco)
	bt.add_node("pace", AnimationNodeTimeScale.new())
	bt.connect_node("pace", 0, "loco")
	bt.add_node("lie", _anim("lie"))
	bt.add_node("lie_mix", AnimationNodeBlend2.new())
	bt.connect_node("lie_mix", 0, "pace")
	bt.connect_node("lie_mix", 1, "lie")
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.05
	shot.fadeout_time = 0.15
	bt.add_node("bark", _anim("bark"))
	bt.add_node("bark_shot", shot)
	bt.connect_node("bark_shot", 0, "lie_mix")
	bt.connect_node("bark_shot", 1, "bark")
	bt.connect_node("output", 0, "bark_shot")
	_tree = AnimationTree.new()
	_tree.tree_root = bt
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	root.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.active = true


func animate(delta: float, speed: float) -> void:
	if _tree == null:
		return
	var k := clampf(delta * 6.0, 0.0, 1.0)
	_speed = lerpf(_speed, speed, k)
	_lie = lerpf(_lie, 1.0 if lying else 0.0, clampf(delta * 2.5, 0.0, 1.0))
	_tree.set("parameters/loco/blend_position", _speed)
	var ref := WALK_REF if _speed <= WALK_REF else lerpf(WALK_REF, TROT_REF, clampf((_speed - WALK_REF) / (TROT_REF - WALK_REF), 0.0, 1.0))
	_tree.set("parameters/pace/scale", 1.0 if _speed < 0.2 else clampf(_speed / ref, 0.5, 1.8))
	_tree.set("parameters/lie_mix/blend_amount", _lie)
	_tree.advance(delta)


func bark() -> void:
	if _tree:
		_tree.set("parameters/bark_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func lie_amount() -> float:
	return _lie


static func _anim(anim_name: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = anim_name
	return a
