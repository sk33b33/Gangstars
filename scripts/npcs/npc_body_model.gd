class_name NpcBodyModel
extends RemyPlayerModel
## A resident's body: one of the five Mixamo characters (scenes/characters/npc/<name>_model.tscn, Remy's clips retargeted
## onto them), behind the calls the old CharacterModel answered, so Resident, the interiors and the vendors need only the
## factory NpcBodies.create(). Design: scenes/characters/remy/README.md ("The five NPC bodies").
##
## Faces +Z like CharacterModel (the Resident turns the whole node). Differences from the old model, all because the clips
## do not exist yet (see the README, "What is missing"): no talk, phone, guard, sit, lean, wave, kick or flinch pose (they
## stand, or face the person they talk to), no hats, hair styles, faces or accessories. Knocked out ("down") falls and
## lies for real; getting up plays the get-up clip.

## Walk, run and sprint speeds (m/s) the gait blend expects of residents (their walk speed is 1.0 to 1.6, fleeing 2 to 5).
const WALK := 1.4
const RUN := 3.2
const SPRINT := 5.0
## How far (radians) a talking resident turns towards what they look at, and how fast (per second).
const TURN_LIMIT := 1.3
const TURN_RATE := 4.0

## "idle", "talk", "guard", "phone": only "talk" (turn to face the look target) does anything.
var mode := "idle"
var carrying := false
var stoop := 0.0
var body := ""            # James, Kate, Leonard, Louise or Meegan
const WAVE_TIME := 1.8   # there is no wave clip yet: is_waving() just stays true this long, so the Resident logic behaves
var _wave_left := 0.0
var _seated := false
var _look: Variant = null
var _facing := 0.0        # the turn towards the look target, radians, applied to the body inside this node


## Builds the body (call before adding to the tree).
func setup_body(p_body: String) -> void:
	body = p_body
	var scene := load("res://scenes/characters/npc/%s_model.tscn" % body.to_lower()) as PackedScene
	remy = scene.instantiate()
	remy.name = "RemyModel"          # RemyPlayerModel._ready looks for this name
	remy.rotation.y = PI              # the Remy scenes face -Z; residents face +Z
	add_child(remy)


func _ready() -> void:
	super._ready()
	remy.walk_speed = WALK
	remy.run_speed = RUN
	remy.sprint_speed = SPRINT
	# The tree is advanced from animate() (the Resident's distance tiers decide how often), not every frame.
	remy.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	remy.update_locomotion(0.0, false, true, 0.0)
	remy.tree.advance(0.02)   # no T-pose on the first frame


## Colours: the clothes keep their own look; a share of the resident's colour is tinted in where the body has a separate top
## or trousers. `opts.height` scales the whole body (children are smaller). Hair, face and accessories do not apply.
func build(shirt: Color, pants: Color, skin: Color, hat: Color = Color(0, 0, 0, 0), opts: Dictionary = {}) -> void:
	if remy.part("Tops"):
		remy.set_part_tint("Tops", shirt.lerp(Color.WHITE, 0.55))
	if remy.part("Bottoms"):
		remy.set_part_tint("Bottoms", pants.lerp(Color.WHITE, 0.6))
	var h := float(opts.get("height", 1.0))
	scale = Vector3.ONE * clampf(h, 0.7, 1.12)
	stoop = float(opts.get("stoop", 0.0))
	_skin = skin


var _skin := Color.WHITE


## A recruited crew member is marked by their colour on the top (the old model gave them a cap).
func set_hat(color: Color, _logo := "") -> void:
	if remy.part("Tops"):
		remy.set_part_tint("Tops", color.lerp(Color.WHITE, 0.2))


func wave() -> void:
	_wave_left = WAVE_TIME


func is_waving() -> bool:
	return _wave_left > 0.0


func look_at_point(p: Variant) -> void:
	_look = p


## Call with the horizontal speed (every frame near, at a lower rate far away).
func animate(delta: float, speed: float) -> void:
	_wave_left = maxf(0.0, _wave_left - delta)
	if _seated:
		return   # posed by hand (see _seat): nothing to advance
	remy.update_locomotion(speed, speed > RUN + 0.3, true, delta)
	remy.tree.advance(delta)
	_turn_to_look(delta, speed)


func _turn_to_look(delta: float, speed: float) -> void:
	var want := 0.0
	if mode == "talk" and speed < 0.1 and _look is Vector3 and base_pose.is_empty():
		var to: Vector3 = (_look as Vector3) - global_position
		var own_yaw := global_rotation.y
		want = clampf(angle_difference(own_yaw, atan2(to.x, to.z)), -TURN_LIMIT, TURN_LIMIT)
	_facing = lerp_angle(_facing, want, clampf(delta * TURN_RATE, 0.0, 1.0))
	remy.rotation.y = PI + _facing


func head_yaw() -> float:
	return _facing


func walk_amplitude() -> float:
	return clampf(remy.gait, 0.0, 1.0)


func skeleton() -> Skeleton3D:
	return remy.skeleton


## Called by the base_pose setter. "down" falls (RemyModel); "sit" bends the body into a chair pose by hand (no clip yet):
## the AnimationTree is switched off and the hips, thighs and shins are set directly. Anything else stands.
func _lay_down(down: bool) -> void:
	_seat(base_pose == "sit" and not down)
	if down:
		remy.fall_down()
	else:
		remy.stand_up()


## Seat height: the origin of a sitting character is the middle of a 0.45 m seat (SpotRegistry).
const SIT_DROP := 0.43      # the hips sink this far (m) from standing
const SIT_THIGH := 90.0     # degrees the thighs swing forward
const SIT_SHIN := 90.0      # degrees the shins fold back


func _seat(on: bool) -> void:
	if on == _seated:
		return
	_seated = on
	var sk := remy.skeleton
	if on:
		remy.gait = 0.0
		remy.update_locomotion(0.0, false, true, 0.0)
		remy.tree.advance(0.05)   # the Idle pose (arms down) is the starting point
	remy.tree.active = not on
	if not on:
		return
	var hips := sk.find_bone("mixamorig_Hips")
	var rest := sk.get_bone_rest(hips)
	# local Z of the hips is the vertical axis, negative up (see RemyModel._in_place): less negative is lower
	sk.set_bone_pose_position(hips, rest.origin + Vector3(0, 0, SIT_DROP * 100.0))
	for side in ["Left", "Right"]:
		var up := sk.find_bone("mixamorig_%sUpLeg" % side)
		var leg := sk.find_bone("mixamorig_%sLeg" % side)
		sk.set_bone_pose_rotation(up, sk.get_bone_rest(up).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(SIT_THIGH)))
		sk.set_bone_pose_rotation(leg, sk.get_bone_rest(leg).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(-SIT_SHIN)))
