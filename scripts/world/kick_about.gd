class_name KickAbout
extends Node3D
## A kids' kick-about on one pitch. Kids (role "kid") who are dwelling at the pitch's POI with the
## "soccer" activity join in: the nearest one chases the ball and kicks it (a pass to a friend or
## a shot at one of the two end goals), the others jog to open spaces. The ball is scripted
## (rolls, slows, bounces off the edges), never a physics body, so it can't block anyone.
## Kids still move with their own physics (Resident.play_target); the brain decides when they
## arrive and when they go home. Nothing runs while the player is far away or nobody is playing.

const BALL_RADIUS := 0.11
const FRICTION := 2.4          # m/s^2
const CHASE_SPEED := 3.0
const ROAM_SPEED := 1.8
const KICK_RANGE := 0.6
const GOAL_HALF_WIDTH := 1.0
const ACTIVE_RANGE := 80.0
const CALLS := ["Pass, pass!", "Shoot!", "Here, here!", "Ag, too hard!", "Nice one!", "Mine!"]

var poi := ""
var center := Vector3.ZERO
var half := Vector2(4, 3)
var ball: MeshInstance3D
var ball_vel := Vector3.ZERO
var players: Array[Resident] = []
var kicks := 0
var goals := 0

var _district: District
var _chaser: Resident
var _roam := {}               # resident id -> Vector3
var _roam_timer := {}
var _kick_cd := 0.0
var _scan := 0.0
var _rng := RandomNumberGenerator.new()


func setup(district: District, p_poi: String, p_center: Vector3, p_half: Vector2) -> void:
	_district = district
	poi = p_poi
	center = p_center
	half = p_half
	_rng.seed = hash(p_poi)
	var mesh := SphereMesh.new()
	mesh.radius = BALL_RADIUS
	mesh.height = BALL_RADIUS * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	ball = MeshInstance3D.new()
	ball.name = "Ball"
	ball.mesh = mesh
	ball.material_override = PixelMaterials.flat(Color("#f4f1ea"))
	# A dark band so the roll is visible.
	var band := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = BALL_RADIUS * 0.96
	tm.outer_radius = BALL_RADIUS * 1.04
	band.mesh = tm
	band.material_override = PixelMaterials.flat(Color("#1d1b24"))
	ball.add_child(band)
	add_child(ball)
	ball.global_position = center + Vector3(0, BALL_RADIUS, 0)


func is_playing() -> bool:
	return players.size() >= 2


func _physics_process(dt: float) -> void:
	var pl: Node3D = _district.player
	if pl == null or pl.global_position.distance_to(center) > ACTIVE_RANGE:
		return
	_scan -= dt
	if _scan <= 0.0:
		_scan = 0.5
		_refresh_players()
	_kick_cd = maxf(0.0, _kick_cd - dt)
	if is_playing():
		_play(dt)
	_roll(dt)


func _refresh_players() -> void:
	var keep: Array[Resident] = []
	for r: Resident in _district.residents.values():
		if _can_play(r):
			keep.append(r)
		elif r.play_target != null and players.has(r):
			r.play_target = null
	for r in players:
		if not keep.has(r):
			r.play_target = null
	players = keep
	if not is_playing():
		for r in players:
			r.play_target = null
		_chaser = null


func _can_play(r: Resident) -> bool:
	if r.data.role != "kid" or r.is_inside or r.sim_tier == "far" or r.spot_phase != "":
		return false
	if not r.brain.state in [NpcBrain.State.AT_DESTINATION, NpcBrain.State.SOCIALIZING]:
		return false
	if r.brain.activity != "soccer" or r.target_id != poi:
		return false
	var p := r.global_position - center
	return absf(p.x) < half.x + 4.0 and absf(p.z) < half.y + 4.0


func _play(dt: float) -> void:
	var bp := ball.global_position
	# The nearest kid chases the ball (with a little hysteresis so they don't flicker).
	var best: Resident = null
	var best_d := INF
	for r in players:
		var d := _flat(r.global_position, bp) - (1.5 if r == _chaser else 0.0)
		if d < best_d:
			best_d = d
			best = r
	_chaser = best
	for r in players:
		if r == _chaser:
			r.play_target = bp
			r.play_speed = CHASE_SPEED
			continue
		var t: float = _roam_timer.get(r.data.id, 0.0) - dt
		if t <= 0.0 or not _roam.has(r.data.id) or _flat(r.global_position, _roam[r.data.id]) < 0.5:
			_roam[r.data.id] = _random_point(0.85)
			t = _rng.randf_range(2.0, 4.5)
		_roam_timer[r.data.id] = t
		r.play_target = _roam[r.data.id]
		r.play_speed = ROAM_SPEED
	if _chaser and _kick_cd <= 0.0 and _flat(_chaser.global_position, bp) < KICK_RANGE:
		_kick(_chaser)


func _kick(kicker: Resident) -> void:
	var bp := ball.global_position
	var target: Vector3
	var mates := players.filter(func(r): return r != kicker)
	if _rng.randf() < 0.65 and not mates.is_empty():
		target = (mates[_rng.randi() % mates.size()] as Resident).global_position
	else:
		var end := 1.0 if _rng.randf() < 0.5 else -1.0
		target = center + Vector3(end * (half.x + 0.5), 0, _rng.randf_range(-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH))
	var dir := target - bp
	dir.y = 0.0
	var dist := dir.length()
	if dist < 0.1:
		dir = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
		dist = 1.0
	# Enough pace to roll about the right distance against friction (v^2 = 2 a d), capped.
	ball_vel = dir / dist * clampf(sqrt(2.0 * FRICTION * dist) * 1.1, 2.5, 8.5)
	kicker.model.kick()
	kicker.face_point(target)
	kicks += 1
	_kick_cd = 0.8
	if _rng.randf() < 0.15:
		kicker.say(CALLS[_rng.randi() % CALLS.size()], 2.0)


func _roll(dt: float) -> void:
	var speed := ball_vel.length()
	if speed < 0.01:
		ball_vel = Vector3.ZERO
		return
	var p := ball.global_position + ball_vel * dt
	var rel := p - center
	if absf(rel.x) > half.x + 0.6:
		if absf(rel.z) < GOAL_HALF_WIDTH and absf(rel.x) < half.x + 1.2:
			goals += 1
			if not players.is_empty():
				(players[_rng.randi() % players.size()] as Resident).say("GOAL!!", 2.0)
			ball_vel = Vector3(-signf(rel.x) * 1.5, 0, ball_vel.z * 0.3)   # rolls back out of the goal
		else:
			ball_vel.x = -ball_vel.x * 0.55
		p.x = center.x + clampf(rel.x, -(half.x + 0.6), half.x + 0.6)
	if absf(rel.z) > half.y + 0.4:
		ball_vel.z = -ball_vel.z * 0.55
		p.z = center.z + clampf(rel.z, -(half.y + 0.4), half.y + 0.4)
	p.y = center.y + BALL_RADIUS
	var axis := Vector3.UP.cross(ball_vel).normalized()
	if axis.length() > 0.5:
		ball.rotate(axis, speed * dt / BALL_RADIUS)
	ball.global_position = p
	ball_vel = ball_vel.move_toward(Vector3.ZERO, FRICTION * dt)


func _random_point(spread: float) -> Vector3:
	return center + Vector3(_rng.randf_range(-half.x, half.x) * spread, 0, _rng.randf_range(-half.y, half.y) * spread)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
