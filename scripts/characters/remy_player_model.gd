class_name RemyPlayerModel
extends Node3D
## The game Player's visual: Remy, behind the same few calls the old CharacterModel answered (so Player, the interiors
## and the tests need no changes beyond a jump call). Scene: scenes/characters/remy/remy_player_model.tscn.
##
## Convention of the Player: this node is turned with rotation.y so that its +Z points the way the character faces
## (`atan2(velocity.x, velocity.z)`). Remy faces -Z, so the RemyModel inside is turned half a turn.
## Weapons: the pistol or long gun of WeaponLibrary is in the hand (aim pose) while drawn, otherwise in a holster on the
## right hip (pistols) or slung across the back (long guns).

var remy: RemyModel
var weapon := ""
var weapon_drawn := false
## Knocked out: "down" plays the fall and lies there; "" gets up again.
var base_pose := "":
	set(value):
		base_pose = value
		_lay_down(value == "down")
var aiming := false:
	set(value):
		aiming = value and not weapon.is_empty()
		if remy:
			remy.set_aiming(aiming)

## The hand's node (RightHandAttachment/Pistol) was tuned for a placeholder whose origin is the top of the grip; the weapon mesh's
## origin is the middle of the gun (grip centre 4 cm below the slide's), so the mesh is moved down and back to put the grip in the palm.
const PISTOL_IN_HAND := Vector3(0.0, -0.04, 0.0)
var _gun: MeshInstance3D
var _body: CharacterBody3D


func _ready() -> void:
	remy = $RemyModel
	_body = get_parent() as CharacterBody3D
	if _body and "walk_speed" in _body:
		# Gaits follow the Player's own speeds: its walk is Remy's run (with the Walk clip for slow pushes), its sprint is Sprint.
		remy.run_speed = float(_body.walk_speed)
		remy.sprint_speed = float(_body.sprint_speed)
	if remy.pistol:
		for c in remy.pistol.get_children():
			c.visible = false   # the box placeholder: real weapons are drawn from WeaponLibrary


## Dresses the character (crew colours). The shirt tints the top, the trousers the bottoms, the skin the body.
## (The hat and the old model's hair, face and trouser options have no Remy equivalent.)
func build(shirt: Color, pants: Color, skin: Color, _hat := Color(0, 0, 0, 0), _opts := {}) -> void:
	remy.set_part_tint("Tops", shirt.lerp(Color.WHITE, 0.25))
	remy.set_part_tint("Bottoms", pants.lerp(Color.WHITE, 0.35))
	remy.set_part_tint("Body", Color.WHITE.lerp(skin.lightened(0.25), 0.55))


## Call every physics frame with the horizontal speed.
func animate(delta: float, speed: float) -> void:
	var on_floor := _body.is_on_floor() if _body else true
	var sprinting: bool = _body.is_sprinting() if _body and _body.has_method("is_sprinting") else false
	remy.update_locomotion(speed, sprinting, on_floor, delta)


## The take-off animation (the Player applies the jump velocity itself).
func jump() -> void:
	remy.jump()


func set_weapon(p_weapon: String) -> void:
	weapon = p_weapon
	weapon_drawn = false
	aiming = false
	if _gun:
		_gun.queue_free()
		_gun = null
	if weapon.is_empty():
		return
	_gun = MeshInstance3D.new()
	_gun.name = "Weapon"
	_gun.mesh = WeaponLibrary.mesh(weapon)
	_gun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_place_gun()


## Draw (true) or put away (false) the weapon.
func draw_weapon(drawn: bool) -> void:
	if weapon.is_empty() or drawn == weapon_drawn:
		return
	weapon_drawn = drawn
	if not drawn:
		aiming = false
	_place_gun()


func _place_gun() -> void:
	if _gun == null:
		return
	if _gun.get_parent():
		_gun.get_parent().remove_child(_gun)
	var long_gun := WeaponLibrary.is_long(weapon)
	var holder: Node3D = remy.pistol if weapon_drawn else (remy.sling if long_gun else remy.holster)
	holder.add_child(_gun)
	_gun.transform = Transform3D(Basis(), Vector3(0, 0, 0.0))
	if weapon_drawn and long_gun:
		_gun.position = Vector3(0, -0.02, 0.1)   # the stock near the hands, the barrel out in front
	elif weapon_drawn:
		_gun.position = PISTOL_IN_HAND


## World position of the muzzle (for tracers), or the chest if unarmed.
func muzzle_position() -> Vector3:
	if _gun and weapon_drawn:
		return _gun.global_transform * Vector3(0, 0.0, 0.2 if not WeaponLibrary.is_long(weapon) else 0.75)
	return global_position + Vector3(0, 1.35, 0)


## A hit: the old model played a flinch. Remy has no hit clip yet (listed in his README): nothing happens.
func flinch() -> void:
	pass


func kick() -> void:
	pass


func wave() -> void:
	pass


func is_waving() -> bool:
	return false


## Sitting: the AnimationTree is switched off and the hips, thighs and shins are set by hand (there is no sit clip yet). The origin of a
## sitting character is the middle of a 0.45 m seat. `at_wheel` also puts the arms forward, the hands on a steering wheel.
const SIT_DROP := 0.43      # the hips sink this far (m) from standing
const SIT_THIGH := 90.0     # degrees the thighs swing forward
const SIT_SHIN := 90.0      # degrees the shins fold back
const WHEEL_ARM := 90.0     # degrees the upper arms swing forward (about the bone's Z, mirrored left to right) to reach the wheel
const WHEEL_FOREARM := 30.0    # and the forearms bend about X (found by searching the poses for hands 0.2 m either side of the wheel's centre)
var _pose_seated := false


func is_seated() -> bool:
	return _pose_seated


func set_seated(on: bool, at_wheel := false) -> void:
	if remy == null or (on == _pose_seated and not at_wheel):
		return
	_pose_seated = on
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
		if at_wheel:
			var arm := sk.find_bone("mixamorig_%sArm" % side)
			var fore := sk.find_bone("mixamorig_%sForeArm" % side)
			var swing := WHEEL_ARM * (1.0 if side == "Left" else -1.0)
			sk.set_bone_pose_rotation(arm, sk.get_bone_rest(arm).basis.get_rotation_quaternion() * Quaternion(Vector3.BACK, deg_to_rad(swing)))
			sk.set_bone_pose_rotation(fore, sk.get_bone_rest(fore).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(WHEEL_FOREARM)))


func _lay_down(down: bool) -> void:
	if remy == null:
		return
	if down:
		remy.fall_down()
	else:
		remy.stand_up()
