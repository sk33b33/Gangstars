extends SceneTree
## Builds scenes/characters/remy/remy_anim_tree.tres (the AnimationTree) and remy_model.tscn (the reusable model).
## Run:  godot --headless --path . -s tools/godot/build_remy_model.gd
## (Re-run after changing it; the scenes are plain text, so they can also be edited in the editor and kept.)
##
## The tree (one per character):
##   Blend2 "aim"  (upper body only: Pistol_Aim over the legs' gait; filtered to the bones from the spine up)
##     in    : StateMachine "loco"
##               Grounded  = BlendTree( BlendSpace1D "gait": Idle 0, Walk 1, Run 2, Sprint 3  ->  TimeScale "speed" )
##               JumpStart / JumpAir / JumpLand = three pieces of the Jump clip (take-off, air, landing)
##               FallDown / Lying / StandUp = knocked out (the clips are played in place by RemyModel)
##     blend : Aim_Hold (a steady frame of Pistol_Aim)
const OUT := "res://scenes/characters/remy/"
const GLB := "res://assets/models/characters/Remy_Animations_Mobile.glb"
const SKELETON := "Armature/Skeleton3D"
const XFADE := 0.12
const NPC_DIR := "res://assets/models/characters/npc/"
const NPC_BODIES := ["James", "Kate", "Leonard", "Louise", "Meegan"]


func _anim(clip: String, start := 0.0, length := 0.0, loop := Animation.LOOP_NONE) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	if length > 0.0:
		n.use_custom_timeline = true
		n.stretch_time_scale = false   # (true, the default, rescales the time and the slice never plays properly)
		n.start_offset = start
		n.timeline_length = length
		n.loop_mode = loop
	return n


func _tr(advance := AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO, at_end := false, xfade := XFADE, condition := "") -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.advance_mode = advance
	t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END if at_end else AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	t.xfade_time = xfade
	if condition != "":
		t.advance_condition = condition
	return t


func _grounded() -> AnimationNodeBlendTree:
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 3.0
	space.sync = true   # the clips keep their steps in time with each other while they blend
	space.add_blend_point(_anim("Idle"), 0.0)
	space.add_blend_point(_anim("Walk"), 1.0)
	space.add_blend_point(_anim("Run"), 2.0)
	space.add_blend_point(_anim("Sprint"), 3.0)
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("gait", space, Vector2(0, 0))
	bt.add_node("speed", AnimationNodeTimeScale.new(), Vector2(300, 0))
	bt.connect_node("speed", 0, "gait")
	bt.connect_node("output", 0, "speed")
	return bt


func _loco() -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("Grounded", _grounded(), Vector2(0, 0))
	# The 1.93 s Jump clip in three pieces: crouch into take-off (from 0.25 s, so it is quick to react), the air
	# (0.5 to 1.25 s; the last frame is held if the fall is longer), and the landing (1.25 to 1.65 s).
	sm.add_node("JumpStart", _anim("Jump", 0.25, 0.25), Vector2(300, -80))
	sm.add_node("JumpAir", _anim("Jump", 0.5, 0.75), Vector2(500, 0))
	sm.add_node("JumpLand", _anim("Jump", 1.25, 0.4), Vector2(300, 80))
	# Knocked out: fall (2.3 s), lie (a held frame), get up (1.7 s). RemyModel.fall_down() / stand_up() travel there.
	sm.add_node("FallDown", _anim("Fall_Down"), Vector2(-300, -80))
	sm.add_node("Lying", _anim("Lying"), Vector2(-300, 0))
	sm.add_node("StandUp", _anim("Stand_Up"), Vector2(-300, 80))
	sm.add_transition("Start", "Grounded", _tr())
	for from in ["Grounded", "JumpStart", "JumpAir", "JumpLand"]:
		sm.add_transition(from, "FallDown", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED, false, 0.1))
	sm.add_transition("FallDown", "Lying", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO, true, 0.05))
	sm.add_transition("FallDown", "StandUp", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED, false, 0.2))
	sm.add_transition("Lying", "StandUp", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED, false, 0.25))
	sm.add_transition("StandUp", "Grounded", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO, true, 0.2))
	sm.add_transition("Grounded", "JumpStart", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED, false, 0.05))
	sm.add_transition("JumpStart", "JumpAir", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO, true, 0.05))
	sm.add_transition("Grounded", "JumpAir", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED, false, 0.15))   # walked off a ledge
	sm.add_transition("JumpAir", "JumpLand", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO, false, 0.05, "landed"))
	sm.add_transition("JumpLand", "Grounded", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO, true, 0.15))
	sm.add_transition("JumpLand", "JumpStart", _tr(AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED, false, 0.05))   # hop again
	return sm


## Every bone from the spine up (spine, chest, neck, head, shoulders, arms, hands, fingers).
func _upper_body(skeleton: Skeleton3D) -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array = [skeleton.find_bone("mixamorig_Spine")]
	while not stack.is_empty():
		var bone: int = stack.pop_back()
		out.append(skeleton.get_bone_name(bone))
		stack.append_array(skeleton.get_bone_children(bone))
	return out


func _tree(skeleton: Skeleton3D) -> AnimationNodeBlendTree:
	var aim := AnimationNodeBlend2.new()
	aim.filter_enabled = true
	for bone in _upper_body(skeleton):
		aim.set_filter_path(NodePath("%s:%s" % [SKELETON, bone]), true)
	var root := AnimationNodeBlendTree.new()
	root.add_node("loco", _loco(), Vector2(0, 0))
	# Aim_Hold: one steady frame of Pistol_Aim (RemyModel makes it). A looped slice of the real clip kept jumping back
	# to the lowered gun, so the held pose is used.
	root.add_node("aim_clip", _anim("Aim_Hold"), Vector2(0, 200))
	root.add_node("aim", aim, Vector2(400, 0))
	root.connect_node("aim", 0, "loco")
	root.connect_node("aim", 1, "aim_clip")
	root.connect_node("output", 0, "aim")
	return root


## The placeholder pistol: a slide and a grip made of boxes, 1 unit = 1 metre, under a node scaled to cancel the
## armature's 0.01 and the model's 0.5 (so 200). Move and turn "Pistol" in the editor until it sits in the hand.
func _pistol(unit := 200.0, boxes := true) -> Node3D:
	var pistol := Node3D.new()
	pistol.name = "Pistol"
	pistol.scale = Vector3.ONE * unit
	# Worked out in the aim pose: barrel along the character's forward, slide up, grip in the palm (units are 1/200 m
	# because of the scale: the palm is 15.6 units, about 8 cm, along the finger direction, which is the bone's +Y).
	pistol.position = Vector3(11.15, 17.32, -2.73) * (unit / 200.0)   # bone units: half as many for a life-size skeleton
	pistol.rotation_degrees = Vector3(-49.95, -156.24, 77.02)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#2b2d33")
	metal.roughness = 0.6
	for spec in ([["Slide", Vector3(0.03, 0.034, 0.19), Vector3(0.0, 0.0, 0.07)], ["Grip", Vector3(0.028, 0.09, 0.04), Vector3(0.0, -0.058, 0.0)]] if boxes else []):
		var mi := MeshInstance3D.new()
		mi.name = spec[0]
		var box := BoxMesh.new()
		box.size = spec[1]
		mi.mesh = box
		mi.position = spec[2]
		mi.material_override = metal
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pistol.add_child(mi)
	return pistol


## The transform of a bone's rest pose in the model scene (the glb instance is turned round and scaled 0.5 there).
func _bone_in_model(remy: Node3D, skeleton: Skeleton3D, bone: String) -> Transform3D:
	var armature := remy.get_node("Armature") as Node3D
	return remy.transform * armature.transform * skeleton.transform * skeleton.get_bone_global_rest(skeleton.find_bone(bone))


## A BoneAttachment3D on `bone` with a child node scaled 200 (1 unit = 1 metre inside it), placed so that the node's
## axes are `axes` (a Basis in model space: Z is the gun's barrel, Y its top) at `offset` metres from the bone.
func _carry(root: Node3D, remy: Node3D, skeleton: Skeleton3D, bone: String, attach_name: String, node_name: String, axes: Basis, offset: Vector3, unit := 200.0) -> void:
	var attach := BoneAttachment3D.new()
	attach.name = attach_name
	attach.use_external_skeleton = true
	attach.external_skeleton = NodePath("../Remy/" + SKELETON)
	attach.bone_name = bone
	root.add_child(attach)
	attach.owner = root
	var b := _bone_in_model(remy, skeleton, bone).basis.orthonormalized()
	var node := Node3D.new()
	node.name = node_name
	node.transform = Transform3D(Basis(b.inverse() * axes).scaled(Vector3.ONE * unit), b.inverse() * offset * unit)
	attach.add_child(node)
	node.owner = root


## One model scene: the glb (turned to face -Z, scaled), the AnimationPlayer and tree, and where a gun rides.
func _model(root_name: String, glb_path: String, model_scale: float, rig_key: String, out_path: String) -> void:
	var root := Node3D.new()
	root.name = root_name
	root.set_script(load("res://scripts/characters/remy_model.gd"))
	root.set("rig_key", rig_key)
	var remy := (load(glb_path) as PackedScene).instantiate() as Node3D
	remy.name = "Remy"
	remy.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * model_scale), Vector3.ZERO)   # faces -Z, 1.8 m tall
	root.add_child(remy)
	remy.owner = root
	var anims := AnimationPlayer.new()
	anims.name = "Anims"
	root.add_child(anims)
	anims.owner = root
	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = load(OUT + "remy_anim_tree.tres")
	tree.anim_player = NodePath("../Anims")
	tree.active = false   # RemyModel switches it on once the animation library is built
	root.add_child(tree)
	tree.owner = root
	# The gun follows the right hand. The attachment sits beside the model and points at its skeleton
	# (external skeleton), so the glb instance stays untouched and the scene stays tiny.
	var attach := BoneAttachment3D.new()
	attach.name = "RightHandAttachment"
	attach.use_external_skeleton = true
	attach.external_skeleton = NodePath("../Remy/" + SKELETON)
	attach.bone_name = "mixamorig_RightHand"
	root.add_child(attach)
	attach.owner = root
	var pistol := _pistol(100.0 / model_scale, rig_key == "")   # (the others get their guns from WeaponLibrary, no box placeholder)
	attach.add_child(pistol)
	pistol.owner = root
	for mi in pistol.get_children():
		mi.owner = root
	# Where a weapon rides when it is not in the hand: a pistol in a holster on the right hip (barrel down, slide to the
	# front), a long gun slung across the back (barrel up). (The model faces -Z, its right is +X, its back is +Z.)
	var skeleton_node := remy.get_node(SKELETON) as Skeleton3D
	var unit := 100.0 / model_scale   # a node this scaled measures 1 unit = 1 metre (the armature is 0.01)
	_carry(root, remy, skeleton_node, "mixamorig_Hips", "HipAttachment", "Holster",
		Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)), Vector3(0.2, -0.04, -0.02), unit)
	var barrel := Vector3(0.25, 0.97, 0).normalized()
	var top := Vector3(0, 0, 1)
	_carry(root, remy, skeleton_node, "mixamorig_Spine2", "BackAttachment", "Sling",
		Basis(top.cross(barrel).normalized(), top, barrel), Vector3(0.0, 0.0, 0.17), unit)
	var packed := PackedScene.new()
	print("pack: ", error_string(packed.pack(root)))
	print("save: ", error_string(ResourceSaver.save(packed, out_path)))
	root.free()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var glb := (load(GLB) as PackedScene).instantiate()
	var skeleton := glb.get_node(SKELETON) as Skeleton3D
	var tree_root := _tree(skeleton)
	var err := ResourceSaver.save(tree_root, OUT + "remy_anim_tree.tres")
	print("tree: ", error_string(err))
	glb.free()
	_model("RemyModel", GLB, 0.5, "", OUT + "remy_model.tscn")   # Remy's glb is twice life size
	# The five other Mixamo bodies (tools/blender/lighten_mixamo.py makes the glbs) are life size.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/characters/npc/"))
	for n in NPC_BODIES:
		_model(n + "Model", NPC_DIR + n + ".glb", 1.0, n, "res://scenes/characters/npc/%s_model.tscn" % n.to_lower())
	quit()
