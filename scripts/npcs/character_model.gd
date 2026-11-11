class_name CharacterModel
extends Node3D
## A person: the shared rigged, skinned model built in Blender (tools/blender/build_character.py
## -> assets/models/characters/person.glb), recoloured and dressed per character. Faces +Z.
## An AnimationTree blends idle/walk/run by speed (playback scaled so feet don't slide) and
## layers upper-body poses ("talk" gestures, "guard" arms folded) on top while standing.
## The tree is advanced manually from animate(), so far-away NPCs cost what their tier allows.

const MODEL := preload("res://assets/models/characters/person.glb")
const HAIR_STYLES: PackedStringArray = ["short", "doek", "beanie", "bald", "long", "afro", "ponytail"]
const ACCESSORIES: PackedStringArray = ["glasses", "sunglasses", "beard", "moustache", "collar", "chain", "apron",
	"police_cap", "police_vest", "dutybelt", "hoops", "curlers", "handbag", "cardigan"]
## House-dress prints (pxl textures in assets/textures/pxl).
const PRINTS: PackedStringArray = ["print_rose", "print_blue", "print_sun", "print_teal", "print_lilac"]
const WAVE_TIME := 1.8
const BLEND_RATE := 6.0        # how fast the gait blends in/out
const WALK_REF := 1.5          # m/s the walk animation is authored for
const RUN_REF := 4.5           # m/s the run animation is authored for
## Bones the upper-body poses may drive (legs and hips keep walking/standing).
const UPPER_BONES := ["spine", "chest", "neck", "head", "upper_arm.L", "forearm.L", "hand.L",
	"upper_arm.R", "forearm.R", "hand.R"]

## Pose layered on the gait while standing: "idle", "talk" (hand gestures), "guard" (arms folded).
var mode := "idle"
## Whole-body resting pose that replaces standing: "" (stand), "sit" (on a seat), "lean" (on a wall).
var base_pose := ""
var _sit := 0.0
var _down := 0.0
var _lean := 0.0
var _wave := 0.0
var _wave_timer := 0.0
## Weapon carried ("" none, "pistol", "shotgun"); drawn = in the hand, aiming = raised.
var weapon := ""
var weapon_drawn := false
var aiming := false
var _aim := 0.0
var _hand: BoneAttachment3D
var _holster: BoneAttachment3D
var _chest: BoneAttachment3D
var _gun: MeshInstance3D
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
var _head_scale := 1.0
var _hat: MeshInstance3D
var _hair: Array[MeshInstance3D] = []


## opts: {hair_style, hair_color: Color, height (1.0 = 1.75 m), sleeves: "long"/"short",
##        figure: 0..1, heavy: 0..1, skirt: bool, accessories: Array[String], apron_color: Color,
##        dress: bool (long house dress; the shirt colour is its colour), print: one of PRINTS or "",
##        cardigan_color, bag_color, shoe_color: Color}
func build(shirt: Color, pants: Color, skin: Color, hat: Color = Color(0, 0, 0, 0), opts: Dictionary = {}) -> void:
	for c in get_children():
		c.queue_free()
	# A rebuild (e.g. the player changing into crew colours) starts from a clean slate.
	_hair = []
	_hat = null
	_hand = null
	_holster = null
	_chest = null
	_gun = null
	var height: float = clampf(float(opts.get("height", 1.0)), 0.55, 1.12)
	var child := height < 0.8
	# Children are slimmer for their height, with a relatively bigger head (below).
	var width := height * 1.08 if child else lerpf(1.0, height, 0.5)
	scale = Vector3(width, height, width)
	_root = MODEL.instantiate()
	add_child(_root)
	_skeleton = _root.find_child("Skeleton3D", true, false)
	_head_bone = _skeleton.find_bone("head")
	_head_scale = 1.3 if child else 1.0
	var dress: bool = bool(opts.get("dress", false))
	var skirt: bool = bool(opts.get("skirt", false)) and not dress
	var hair_color: Color = opts.get("hair_color", Color("#1d1b24"))
	var extras: Array = opts.get("accessories", [])
	var cardigan: Color = opts.get("cardigan_color", Color("#d8cbb0"))
	# A printed house dress: the same cotton print on the bodice and the long skirt.
	var fabric: Variant = shirt
	if dress and PRINTS.has(str(opts.get("print", ""))):
		fabric = PixelMaterials.fabric(str(opts.print))
	var colours := {
		"skin": skin, "shirt": fabric, "pants": skin.darkened(0.08) if skirt or dress else pants,
		"forearm": cardigan if extras.has("cardigan") else (fabric if opts.get("sleeves", "long") == "long" else skin),
		"dress": fabric, "cardigan": cardigan, "bag": opts.get("bag_color", Color("#7a2e2a")), "acc_pink": Color("#f29bbd"),
		"shoes": opts.get("shoe_color", Color("#1d1b24")), "hair": hair_color, "hat": hat if hat.a > 0.0 else Color("#1d1b24"),
		"skirt": pants, "eye_white": Color("#ece8dc"), "pupil": Color("#1a1412"), "lips": skin.darkened(0.35),
		"apron": opts.get("apron_color", Color("#ece8dc")), "acc_frame": Color("#1a1a1e"), "acc_lens": Color("#101018"),
		"acc_gold": Color("#d4a63a"), "acc_white": Color("#f4f4f0"),
		"uniform": Color("#25366a"), "vest": Color("#5b7097"), "badge": Color("#e8b400"), "belt": Color("#121214"),
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
		elif n == "Dress":
			mi.visible = dress
		elif n.begins_with("Acc_"):
			var key := n.trim_prefix("Acc_")
			if key.begins_with("cardigan"):
				key = "cardigan"   # Acc_cardigan + Acc_cardigan_armL/R
			mi.visible = extras.has(key)
		elif n == "Body":
			mi.set_blend_shape_value(mi.find_blend_shape_by_name("Figure"), clampf(float(opts.get("figure", 0.0)), 0.0, 1.0))
			mi.set_blend_shape_value(mi.find_blend_shape_by_name("Heavy"), clampf(float(opts.get("heavy", 0.0)), 0.0, 1.0))
	_build_tree(_root.find_child("AnimationPlayer", true, false))
	if extras.has("police_vest"):
		_vest_lettering()
	if hat.a > 0.0:
		set_hat(hat)


## White "POLICE" across the vest, front and back (follows the chest bone).
func _vest_lettering() -> void:
	var chest := BoneAttachment3D.new()
	chest.bone_name = "chest"
	_skeleton.add_child(chest)
	for front in [true, false]:
		var l := Label3D.new()
		l.text = "POLICE"
		l.font_size = 40
		l.pixel_size = 0.0028
		l.outline_size = 0
		l.modulate = Color("#f4f4f0")
		l.double_sided = false
		l.position = Vector3(0, 0.06 if front else 0.09, 0.142 if front else -0.142)
		l.rotation.y = 0.0 if front else PI
		chest.add_child(l)


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
	var k_slow := clampf(delta * 4.0, 0.0, 1.0)
	_sit = lerpf(_sit, 1.0 if base_pose == "sit" else 0.0, k_slow)
	_down = lerpf(_down, 1.0 if base_pose == "down" else 0.0, clampf(delta * 6.0, 0.0, 1.0))
	_lean = lerpf(_lean, 1.0 if base_pose == "lean" else 0.0, k_slow)
	_wave_timer = maxf(0.0, _wave_timer - delta)
	_aim = lerpf(_aim, 1.0 if aiming and weapon_drawn else 0.0, clampf(delta * 10.0, 0.0, 1.0))
	_wave = lerpf(_wave, 1.0 if _wave_timer > 0.3 else 0.0, k)
	_tree.set("parameters/loco/blend_position", _speed)
	_tree.set("parameters/pace/scale", _pace(_speed))
	_tree.set("parameters/talk_mix/blend_amount", _talk)
	_tree.set("parameters/guard_mix/blend_amount", _guard)
	_tree.set("parameters/sit_mix/blend_amount", _sit)
	_tree.set("parameters/lean_mix/blend_amount", _lean)
	_tree.set("parameters/wave_mix/blend_amount", _wave)
	var long_gun := WeaponLibrary.is_long(weapon)
	_tree.set("parameters/aim_pistol_mix/blend_amount", 0.0 if long_gun else _aim)
	_tree.set("parameters/aim_long_mix/blend_amount", _aim if long_gun else 0.0)
	_tree.set("parameters/down_mix/blend_amount", _down)
	_tree.advance(delta)
	_apply_look(delta)


## Turns the head (within ±60°) towards a world point; null looks straight ahead.
func look_at_point(p: Variant) -> void:
	_look_target = p


## A short friendly wave (right arm), layered over whatever the body is doing.
func wave() -> void:
	_wave_timer = WAVE_TIME


## Gives the character a weapon (holstered / slung). "" removes it.
func set_weapon(p_weapon: String) -> void:
	weapon = p_weapon
	weapon_drawn = false
	aiming = false
	if _gun:
		_gun.queue_free()
		_gun = null
	if weapon.is_empty() or _skeleton == null:
		return
	if _hand == null:
		_hand = BoneAttachment3D.new()
		_hand.bone_name = "hand.R"
		_skeleton.add_child(_hand)
		_holster = BoneAttachment3D.new()
		_holster.bone_name = "hips"
		_skeleton.add_child(_holster)
		_chest = BoneAttachment3D.new()
		_chest.bone_name = "chest"
		_skeleton.add_child(_chest)
	_gun = MeshInstance3D.new()
	_gun.name = "Weapon"
	_gun.mesh = WeaponLibrary.mesh(weapon)
	_place_gun()


## Draw (true) or put away (false) the weapon.
func draw_weapon(drawn: bool) -> void:
	if weapon.is_empty() or drawn == weapon_drawn:
		return
	weapon_drawn = drawn
	if not drawn:
		aiming = false
	_place_gun()


func flinch() -> void:
	if _tree:
		_tree.set("parameters/hit_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## World position of the muzzle (for tracers), or the chest if unarmed.
func muzzle_position() -> Vector3:
	if _gun and weapon_drawn:
		return _gun.global_transform * Vector3(0, 0.05, 0.2 if not WeaponLibrary.is_long(weapon) else 0.75)
	return global_position + Vector3(0, 1.35 * scale.y, 0)


func _place_gun() -> void:
	if _gun == null:
		return
	if _gun.get_parent():
		_gun.get_parent().remove_child(_gun)
	var long_gun := WeaponLibrary.is_long(weapon)
	if weapon_drawn and long_gun:
		# Long guns sit at the right shoulder, pointing straight ahead (the arms pose around it).
		_chest.add_child(_gun)
		_gun.transform = Transform3D(Basis(), Vector3(-0.1, 0.12, 0.2))
	elif weapon_drawn:
		_hand.add_child(_gun)
		# Hand bone +Y runs down the fingers: the barrel (+Z) follows it, the top faces the thumb.
		_gun.transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(0, 0.07, 0.0))
	else:
		_holster.add_child(_gun)
		if long_gun:   # slung across the back, barrel up
			_gun.transform = Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0.6)), Vector3(0.05, 0.35, -0.17))
		else:          # pistol in the right-hip holster, barrel down
			_gun.transform = Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(-0.17, -0.02, 0.02))


func kick() -> void:
	if _tree:
		_tree.set("parameters/kick_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func is_waving() -> bool:
	return _wave_timer > 0.0


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
	if _head_bone >= 0 and _head_scale != 1.0:
		_skeleton.set_bone_pose_scale(_head_bone, Vector3.ONE * _head_scale)


func _recolour(mi: MeshInstance3D, colours: Dictionary) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		var key := m.resource_name if m else ""
		if colours.has(key):
			var c: Variant = colours[key]
			mi.set_surface_override_material(i, c if c is Material else PixelMaterials.flat(c))


func _build_tree(player: AnimationPlayer) -> void:
	for anim_name in player.get_animation_list():
		player.get_animation(anim_name).loop_mode = Animation.LOOP_NONE if anim_name in ["kick", "hit"] else Animation.LOOP_LINEAR
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
	var previous := "pace"
	# Whole-body resting poses replace the standing gait.
	for pose in ["sit", "lean", "down"]:
		bt.add_node(pose, _anim(pose))
		bt.add_node(pose + "_mix", AnimationNodeBlend2.new())
		bt.connect_node(pose + "_mix", 0, previous)
		bt.connect_node(pose + "_mix", 1, pose)
		previous = pose + "_mix"
	# A full-body one-shot kick (kids' kick-about).
	var kick := AnimationNodeOneShot.new()
	kick.fadein_time = 0.05
	kick.fadeout_time = 0.15
	bt.add_node("kick", _anim("kick"))
	bt.add_node("kick_shot", kick)
	bt.connect_node("kick_shot", 0, previous)
	bt.connect_node("kick_shot", 1, "kick")
	previous = "kick_shot"
	# Upper-body gestures on top (legs keep walking, sitting or leaning).
	var upper := _upper_paths(player.get_animation("talk"))
	for pose in ["talk", "guard", "wave", "aim_pistol", "aim_long"]:
		bt.add_node(pose, _anim(pose))
		var mix := AnimationNodeBlend2.new()
		mix.filter_enabled = true
		for path in upper:
			mix.set_filter_path(path, true)
		bt.add_node(pose + "_mix", mix)
		bt.connect_node(pose + "_mix", 0, previous)
		bt.connect_node(pose + "_mix", 1, pose)
		previous = pose + "_mix"
	# Flinch when hit (one-shot over everything, upper body only).
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.03
	hit.fadeout_time = 0.2
	hit.filter_enabled = true
	for path in upper:
		hit.set_filter_path(path, true)
	bt.add_node("hit", _anim("hit"))
	bt.add_node("hit_shot", hit)
	bt.connect_node("hit_shot", 0, previous)
	bt.connect_node("hit_shot", 1, "hit")
	previous = "hit_shot"
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
