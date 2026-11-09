class_name CharacterModel
extends Node3D
## A person: the shared rigged, skinned model built in Blender (tools/blender/build_character.py
## -> assets/models/characters/person.glb), recoloured and dressed per character. Faces +Z.
## An AnimationTree blends idle/walk/run by speed (playback scaled so feet don't slide) and
## layers upper-body poses ("talk" gestures, "guard" arms folded) on top while standing.
## The tree is advanced manually from animate(), so far-away NPCs cost what their tier allows.

const MODEL := preload("res://assets/models/characters/person.glb")
const HAIR_STYLES: PackedStringArray = ["short", "doek", "beanie", "bald", "long"]
const BLEND_RATE := 6.0        # how fast the gait blends in/out
const WALK_REF := 1.5          # m/s the walk animation is authored for
const RUN_REF := 4.5           # m/s the run animation is authored for
## Bones the upper-body poses may drive (legs and hips keep walking/standing).
const UPPER_BONES := ["spine", "chest", "neck", "head", "upper_arm.L", "forearm.L", "hand.L",
	"upper_arm.R", "forearm.R", "hand.R"]

## Pose layered on the gait while standing: "idle", "talk" (hand gestures), "guard" (arms folded).
var mode := "idle"
var _root: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _head_bone := -1
var _speed := 0.0
var _amp := 0.0
var _talk := 0.0
var _guard := 0.0
var _look_target: Variant = null
var _head_yaw := 0.0
var _hat: MeshInstance3D
var _hair: Array[MeshInstance3D] = []


## opts: {hair_style, hair_color: Color, height (1.0 = 1.75 m), sleeves: "long"/"short",
##        figure: 0..1, heavy: 0..1, skirt: bool}
func build(shirt: Color, pants: Color, skin: Color, hat: Color = Color(0, 0, 0, 0), opts: Dictionary = {}) -> void:
	for c in get_children():
		c.queue_free()
	var height: float = clampf(float(opts.get("height", 1.0)), 0.85, 1.12)
	scale = Vector3(lerpf(1.0, height, 0.5), height, lerpf(1.0, height, 0.5))
	_root = MODEL.instantiate()
	add_child(_root)
	_skeleton = _root.find_child("Skeleton3D", true, false)
	_head_bone = _skeleton.find_bone("head")
	var skirt: bool = bool(opts.get("skirt", false))
	var hair_color: Color = opts.get("hair_color", Color("#1d1b24"))
	var colours := {
		"skin": skin, "shirt": shirt, "pants": skin.darkened(0.08) if skirt else pants,
		"forearm": shirt if opts.get("sleeves", "long") == "long" else skin,
		"shoes": Color("#1d1b24"), "hair": hair_color, "hat": hat if hat.a > 0.0 else Color("#1d1b24"),
		"skirt": pants, "eye_white": Color("#ece8dc"), "pupil": Color("#1a1412"), "lips": skin.darkened(0.35),
	}
	var style := str(opts.get("hair_style", "short"))
	for mi in _skeleton.get_children():
		if not mi is MeshInstance3D:
			continue
		_recolour(mi, colours)
		var n := str(mi.name)
		if n.begins_with("Hair_"):
			_hair.append(mi)
			mi.visible = n == "Hair_" + style
		elif n == "Hat_cap":
			_hat = mi
			mi.visible = false
		elif n == "Skirt":
			mi.visible = skirt
		elif n == "Body":
			mi.set_blend_shape_value(mi.find_blend_shape_by_name("Figure"), clampf(float(opts.get("figure", 0.0)), 0.0, 1.0))
			mi.set_blend_shape_value(mi.find_blend_shape_by_name("Heavy"), clampf(float(opts.get("heavy", 0.0)), 0.0, 1.0))
	_build_tree(_root.find_child("AnimationPlayer", true, false))
	if hat.a > 0.0:
		set_hat(hat)


## Adds (or recolours) a cap, e.g. when someone joins the player's crew. Hides the hair.
func set_hat(color: Color) -> void:
	if _hat == null:
		return
	_hat.visible = true
	_hat.set_surface_override_material(0, PixelMaterials.flat(color))
	for h in _hair:
		h.visible = false


## Call every frame with horizontal speed (m/s). Drives the gait, poses and head look.
func animate(delta: float, speed: float) -> void:
	if _tree == null:
		return
	var k := clampf(delta * BLEND_RATE, 0.0, 1.0)
	_speed = lerpf(_speed, speed, k)
	_amp = lerpf(_amp, clampf(speed / 1.4, 0.0, 1.3), k)
	var idle := 1.0 - minf(_amp, 1.0)
	_talk = lerpf(_talk, (1.0 if mode == "talk" else 0.0) * idle, k)
	_guard = lerpf(_guard, (1.0 if mode == "guard" else 0.0) * idle, k)
	_tree.set("parameters/loco/blend_position", _speed)
	_tree.set("parameters/pace/scale", _pace(_speed))
	_tree.set("parameters/talk_mix/blend_amount", _talk)
	_tree.set("parameters/guard_mix/blend_amount", _guard)
	_tree.advance(delta)
	_apply_look(delta)


## Turns the head (within ±60°) towards a world point; null looks straight ahead.
func look_at_point(p: Variant) -> void:
	_look_target = p


func head_yaw() -> float:
	return _head_yaw


func walk_amplitude() -> float:
	return _amp


func skeleton() -> Skeleton3D:
	return _skeleton


## Playback rate so the authored stride matches the real speed (no foot sliding).
static func _pace(speed: float) -> float:
	if speed < 0.3:
		return 1.0
	var ref := WALK_REF if speed <= WALK_REF else lerpf(WALK_REF, RUN_REF, clampf((speed - WALK_REF) / (RUN_REF - WALK_REF), 0.0, 1.0))
	return clampf(speed / ref, 0.4, 1.8)


func _apply_look(delta: float) -> void:
	var target_yaw := 0.0
	if _look_target != null:
		var local := global_transform.affine_inverse() * (_look_target as Vector3)
		target_yaw = clampf(atan2(local.x, local.z), -1.05, 1.05)
	_head_yaw = lerp_angle(_head_yaw, target_yaw, clampf(delta * 5.0, 0.0, 1.0))
	if _head_bone >= 0 and absf(_head_yaw) > 0.001:
		var q := _skeleton.get_bone_pose_rotation(_head_bone)
		_skeleton.set_bone_pose_rotation(_head_bone, q * Quaternion(Vector3.UP, _head_yaw))


func _recolour(mi: MeshInstance3D, colours: Dictionary) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		var key := m.resource_name if m else ""
		if colours.has(key):
			mi.set_surface_override_material(i, PixelMaterials.flat(colours[key]))


func _build_tree(player: AnimationPlayer) -> void:
	for anim_name in player.get_animation_list():
		player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = RUN_REF
	loco.add_blend_point(_anim("idle"), 0.0)
	loco.add_blend_point(_anim("walk"), WALK_REF)
	loco.add_blend_point(_anim("run"), RUN_REF)
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("loco", loco)
	bt.add_node("pace", AnimationNodeTimeScale.new())
	bt.connect_node("pace", 0, "loco")
	var upper := _upper_paths(player.get_animation("talk"))
	var previous := "pace"
	for pose in ["talk", "guard"]:
		bt.add_node(pose, _anim(pose))
		var mix := AnimationNodeBlend2.new()
		mix.filter_enabled = true
		for path in upper:
			mix.set_filter_path(path, true)
		bt.add_node(pose + "_mix", mix)
		bt.connect_node(pose + "_mix", 0, previous)
		bt.connect_node(pose + "_mix", 1, pose)
		previous = pose + "_mix"
	bt.connect_node("output", 0, previous)
	_tree = AnimationTree.new()
	_tree.tree_root = bt
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_root.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.active = true


static func _anim(anim_name: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = anim_name
	return a


static func _upper_paths(anim: Animation) -> Array[NodePath]:
	var out: Array[NodePath] = []
	for i in anim.get_track_count():
		var path := anim.track_get_path(i)
		if path.get_subname_count() > 0 and UPPER_BONES.has(str(path.get_subname(0))):
			out.append(path)
	return out
