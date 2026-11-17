class_name RemyModel
extends Node3D
## The Mixamo "Remy" character as a reusable model for the player and for NPCs (scene: scenes/characters/remy/remy_model.tscn).
## One skeleton, one AnimationTree, about 1.8 m tall (the glb is twice that, so its `Remy` child is scaled by 0.5).
## The model faces -Z like any Godot node (the `Remy` child is turned round), so look_at() and `basis` just work.
##
## Drive it with update_locomotion() every physics frame, jump(), set_aiming(); dress it with apply_outfit().
## Animation names, speeds, the gun attachment and what is missing (Idle): scenes/characters/remy/README.md.

## Speeds (m/s) the clips were authored for (the glb's root motion was removed). The clip's play speed is
## actual speed / authored speed, so the feet do not skate. These are where the planted foot stood stillest when
## measured in the game (tests: tools in docs, README): Walk 1.7, Run 5.5, Sprint 6.0 (the uploaded notes said 5.4 and
## 5.5 for Run and Sprint; Sprint measured nearer 6). Tune by eye on the phone.
const AUTHORED_WALK := 1.7
const AUTHORED_RUN := 5.5
const AUTHORED_SPRINT := 6.0
const IDLE_BLEND := 0.35        # below this speed (m/s) the idle pose fades into Walk
const SWITCH_WINDOW := 0.3      # Walk fades into Run over (walk + run) / 2, plus and minus this
const SLOTS := ["Body", "Tops", "Bottoms", "Shoes", "Hair", "Eyes", "Eyelashes"]
const SKELETON_PATH := "Remy/Armature/Skeleton3D"
## Jump clip (1.93 s): crouch to 0.4 s, apex 0.8 s, feet back on the ground about 1.3 s. It is played in three pieces
## (see tools/godot/build_remy_model.gd): take-off, air (held while falling), landing.
## Pistol_Aim (7.1 s) raises the gun by 0.5 s, holds it steady until about 1 s, then lowers it. The hold is this moment of it.
const AIM_FRAME_TIME := 0.75

## Speeds the character is expected to move at (the player sets them); they decide how Walk, Run and Sprint blend.
@export var walk_speed := 1.7
@export var run_speed := 4.0
@export var sprint_speed := 6.0
## How fast the gait and the aim blend follow what the player is doing (per second).
@export var gait_response := 8.0
@export var aim_response := 10.0

var tree: AnimationTree
var anims: AnimationPlayer
var skeleton: Skeleton3D
var holster: Node3D                # where a pistol rides on the right hip (barrel down)
var sling: Node3D                  # where a long gun rides on the back (barrel up)
var pistol: Node3D                 # the placeholder gun: RightHandAttachment (a BoneAttachment3D on mixamorig_RightHand) > Pistol
var gait := 0.0                    # 0 idle, 1 walk, 2 run, 3 sprint (blended)

static var _library: AnimationLibrary   # shared by every Remy: the six clips (Idle, Walk, Run, Sprint, Jump, Pistol_Aim) plus the aim hold

var _playback: AnimationNodeStateMachinePlayback
var _aim := 0.0
var _aim_target := 0.0
var _clock := 0.0                  # seconds of simulated time (the sum of the deltas): not the wall clock, so tests and slow frames agree
var _jumped_at := -10.0
var _stood_at := -10.0


func _ready() -> void:
	tree = $AnimationTree
	anims = $Anims
	skeleton = get_node(SKELETON_PATH) as Skeleton3D
	pistol = get_node_or_null("RightHandAttachment/Pistol") as Node3D
	holster = get_node_or_null("HipAttachment/Holster") as Node3D
	sling = get_node_or_null("BackAttachment/Sling") as Node3D
	var imported := $Remy/AnimationPlayer as AnimationPlayer
	if _library == null:
		_library = _make_library(imported)
	anims.add_animation_library("", _library)
	anims.root_node = anims.get_path_to($Remy)   # the clips' track paths start at the glb's root
	tree.anim_player = tree.get_path_to(anims)
	tree.active = true
	_playback = tree.get("parameters/loco/playback") as AnimationNodeStateMachinePlayback
	imported.queue_free()   # the glb's own player is not needed: one AnimationTree drives the skeleton


## The shared library: the glb's clips by reference (no copies), plus a held pose made from them:
## Aim_Hold (the steady part of Pistol_Aim).
static func _make_library(imported: AnimationPlayer) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for clip in imported.get_animation_list():
		lib.add_animation(clip, imported.get_animation(clip))
	lib.add_animation("Aim_Hold", _held_pose(imported.get_animation("Pistol_Aim"), AIM_FRAME_TIME))
	# Knocked out: the glb's fall and get-up carry about a metre of root motion each, but the player's body stays where
	# it is, so both are played in place (the hips keep their start position on the ground plane).
	var fall := _in_place(imported.get_animation("Fall_Down"))
	lib.add_animation("Fall_Down", fall)
	lib.add_animation("Lying", _held_pose(fall, fall.length))
	lib.add_animation("Stand_Up", _in_place(imported.get_animation("Stand_Up")))
	return lib


## A copy of `src` whose hips stay over their first position (the Mixamo hips track: local X and Y lie on the ground,
## Z is the height), so a clip with root motion plays on the spot.
static func _in_place(src: Animation) -> Animation:
	var a := src.duplicate() as Animation
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D or not str(a.track_get_path(i)).ends_with("mixamorig_Hips"):
			continue
		var first: Vector3 = a.track_get_key_value(i, 0)
		for k in a.track_get_key_count(i):
			var v: Vector3 = a.track_get_key_value(i, k)
			a.track_set_key_value(i, k, Vector3(first.x, first.y, v.z))
	return a


## A one-key-per-track copy of `src` at time `t`: the same pose, held. (Used for the steady aim pose.)
static func _held_pose(src: Animation, t: float) -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	for i in src.get_track_count():
		var kind := src.track_get_type(i)
		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
			continue
		var n := a.add_track(kind)
		a.track_set_path(n, src.track_get_path(i))
		match kind:
			Animation.TYPE_POSITION_3D:
				a.position_track_insert_key(n, 0.0, src.position_track_interpolate(i, t))
			Animation.TYPE_ROTATION_3D:
				a.rotation_track_insert_key(n, 0.0, src.rotation_track_interpolate(i, t))
			_:
				a.scale_track_insert_key(n, 0.0, src.scale_track_interpolate(i, t))
	return a


# ------------------------------------------------------------------ driving the animation

## Call every physics frame: `speed` is the horizontal speed in m/s, `sprinting` whether the sprint button is down.
## No allocations: it sets a handful of tree parameters.
func update_locomotion(speed: float, sprinting: bool, on_floor: bool, delta: float) -> void:
	var want := gait_for(speed, sprinting, walk_speed, run_speed, sprint_speed)
	gait = move_toward(gait, want, gait_response * delta)
	tree.set("parameters/loco/Grounded/gait/blend_position", gait)
	tree.set("parameters/loco/Grounded/speed/scale", play_speed(gait, speed))
	_aim = move_toward(_aim, _aim_target, aim_response * delta)
	tree.set("parameters/aim/blend_amount", _aim)
	_clock += delta
	var state := _playback.get_current_node()
	if state == &"FallDown" or state == &"Lying":
		return
	if state == &"StandUp":
		if speed > run_speed * 0.5 and _clock - _stood_at > 1.0:
			_playback.travel(&"Grounded")   # walking off cuts the get-up short
		return
	if not on_floor and _playback.get_current_node() == &"Grounded" and _clock - _jumped_at > 0.3:
		_playback.travel(&"JumpAir")   # walked off a ledge (not the first frames of a jump: it is already on its way)
	tree.set("parameters/loco/conditions/landed", on_floor and _clock - _jumped_at > 0.2)


## Knocked out: falls (Fall_Down), then lies there until stand_up(). Lowers the gun arm.
func fall_down() -> void:
	_aim_target = 0.0
	_aim = 0.0
	_playback.travel(&"FallDown")


## Gets up again (Stand_Up), then back to the normal gaits. Does nothing if not down.
func stand_up() -> void:
	if is_down():
		_stood_at = _clock
		_playback.travel(&"StandUp")


## Falling or lying (knocked out).
func is_down() -> bool:
	var s := _playback.get_current_node()
	return s == &"FallDown" or s == &"Lying"


## Plays the take-off. (The player applies the jump velocity at the same moment, so it never feels delayed.)
func jump() -> void:
	_jumped_at = _clock
	tree.set("parameters/loco/conditions/landed", false)
	if is_down() or _playback.get_current_node() == &"StandUp":
		return
	_playback.travel(&"JumpStart")


## Raise (true) or lower the gun arm: the upper body blends to Pistol_Aim while the legs keep walking.
func set_aiming(on: bool) -> void:
	_aim_target = 1.0 if on else 0.0


func is_aiming() -> bool:
	return _aim_target > 0.5


## The state the locomotion machine is in: Grounded, JumpStart, JumpAir, JumpLand, FallDown, Lying or StandUp.
func state_name() -> StringName:
	return _playback.get_current_node()


## 0 idle, 1 walk, 2 run, 3 sprint for a speed. Not a straight slide between clips: mixing two clips with different
## strides makes the feet skate, so each clip is kept alone at a matched play speed (Walk from a crawl up to a brisk
## walk) and only the first IDLE_BLEND m/s (idle to walk) and a narrow window around the walk/run switch are blended.
static func gait_for(speed: float, sprinting: bool, walk: float, run: float, sprint: float) -> float:
	if sprinting and speed > run:
		return 2.0 + clampf((speed - run) / maxf(sprint - run, 0.01), 0.0, 1.0)
	if speed < IDLE_BLEND:
		return clampf(speed / IDLE_BLEND, 0.0, 1.0)
	var middle := (walk + run) * 0.5
	return 1.0 + clampf((speed - (middle - SWITCH_WINDOW)) / (2.0 * SWITCH_WINDOW), 0.0, 1.0)


## The clip speed that makes the feet keep up with the ground: actual speed / the speed the clip was authored for.
static func play_speed(gait_value: float, speed: float) -> float:
	if gait_value < 0.05:
		return 1.0
	var authored: float
	if gait_value <= 1.0:
		authored = AUTHORED_WALK
	elif gait_value <= 2.0:
		authored = lerpf(AUTHORED_WALK, AUTHORED_RUN, gait_value - 1.0)
	else:
		authored = lerpf(AUTHORED_RUN, AUTHORED_SPRINT, gait_value - 2.0)
	return clampf(speed / authored, 0.4, 1.8)


## Stops or restarts the AnimationTree (a far-away NPC does not need to animate).
func set_animation_enabled(on: bool) -> void:
	tree.active = on


# ------------------------------------------------------------------ dressing it

## The MeshInstance3D of a slot ("Body", "Tops", "Bottoms", "Shoes", "Hair", "Eyes", "Eyelashes").
func part(slot: String) -> MeshInstance3D:
	return skeleton.get_node_or_null(slot) as MeshInstance3D


## Gives a part its own copy of the material (made once) so one NPC can differ from the others.
func _own_material(slot: String) -> StandardMaterial3D:
	var mi := part(slot)
	if mi == null:
		return null
	var mat := mi.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		mat = (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, mat)
	return mat


func set_part_tint(slot: String, color: Color) -> void:
	var mat := _own_material(slot)
	if mat:
		mat.albedo_color = color


func set_part_texture(slot: String, albedo: Texture2D) -> void:
	var mat := _own_material(slot)
	if mat:
		mat.albedo_texture = albedo


func set_part_visible(slot: String, on: bool) -> void:
	var mi := part(slot)
	if mi:
		mi.visible = on


## Swaps a part's mesh for one skinned to the same Mixamo skeleton (a different top, a female body...).
## `source` is a MeshInstance3D from another imported glb: its mesh, skin and material come with it.
func replace_part(slot: String, source: MeshInstance3D) -> void:
	var mi := part(slot)
	if mi == null or source == null:
		return
	mi.mesh = source.mesh
	mi.skin = source.skin
	mi.set_surface_override_material(0, null)
	var mat := source.get_active_material(0)
	if mat != null:
		mi.set_surface_override_material(0, mat)


## Applies a RemyOutfit (colours, textures, hidden parts) to this character.
func apply_outfit(outfit: RemyOutfit) -> void:
	if outfit == null:
		return
	outfit.apply(self)
