class_name CombatSystem
extends Node3D
## Shots for everyone (player, gangsters, police): hitscan rays with spread, a short tracer and
## muzzle flash, damage to whoever is hit (Resident.on_shot / Player.on_shot), and a "gunfire"
## incident so bystanders flee and police respond. A child of the District.
## Stylised: no blood, no gore; people are knocked down, never killed.

signal shot_fired(shooter: Node3D, origin: Vector3, weapon: String)
signal target_hit(target: Node3D, shooter: Node3D, damage: float, knocked_down: bool)

## World, player, residents, drivable cars, traffic: bullets stop at all of them (not dogs).
const SHOT_MASK := 1 | (1 << 1) | (1 << 2) | (1 << 4) | (1 << 5)
const TRACER_TIME := 0.06
const EVENT_COOLDOWN := 2.0

var events: NeighbourhoodEvents
var shots := 0
var hits := 0
var _fx: Array = []                 # [node, seconds left]
var _last_event := {}               # shooter instance id -> time
var _rng := RandomNumberGenerator.new()
var _tracer_mat: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	_rng.seed = 4242
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.86, 0.45)
	_tracer_mat.emission_enabled = true
	_tracer_mat.emission = Color(1.0, 0.8, 0.4)
	_tracer_mat.emission_energy_multiplier = 3.0


## Fires `weapon` from `origin` towards `aim_point`. spread_mult > 1 for less accurate shooters.
## Returns the list of hit targets.
func fire(shooter: Node3D, weapon: String, origin: Vector3, aim_point: Vector3, spread_mult := 1.0) -> Array:
	var st := WeaponLibrary.stats(weapon)
	if st.is_empty():
		return []
	shots += 1
	var space := get_world_3d().direct_space_state
	var base_dir := (aim_point - origin).normalized()
	var hit_targets: Array = []
	for i in int(st.pellets):
		var spread: float = float(st.spread) * spread_mult
		var dir := base_dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
		var side := dir.cross(Vector3.UP).normalized()
		if side.length() > 0.5:
			dir = dir.rotated(side, _rng.randf_range(-spread, spread) * 0.6)
		var to := origin + dir * float(st.range)
		var q := PhysicsRayQueryParameters3D.create(origin, to, SHOT_MASK)
		if shooter is CollisionObject3D:
			q.exclude = [(shooter as CollisionObject3D).get_rid()]
		var res := space.intersect_ray(q)
		var end := to
		if not res.is_empty():
			end = res.position
			var body: Object = res.collider
			if body and body.has_method("on_shot") and not hit_targets.has(body):
				hit_targets.append(body)
				hits += 1
				var down: bool = body.on_shot(float(st.damage) * (1.0 if i == 0 else 0.8), shooter)
				target_hit.emit(body, shooter, float(st.damage), down)
		_tracer(origin, end)
	_flash(origin)
	shot_fired.emit(shooter, origin, weapon)
	_raise_gunfire(shooter, origin)
	return hit_targets


func _raise_gunfire(shooter: Node3D, origin: Vector3) -> void:
	if events == null:
		return
	var key := shooter.get_instance_id()
	if _time - float(_last_event.get(key, -99.0)) < EVENT_COOLDOWN:
		return
	_last_event[key] = _time
	var e := events.raise("gunfire", origin)
	e["shooter"] = shooter


func _tracer(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.2:
		return
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.025, 0.025, length)
	mi.mesh = m
	mi.material_override = _tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	_fx.append([mi, TRACER_TIME])


func _flash(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 3.0
	light.omni_range = 3.5
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at
	_fx.append([light, 0.05])


func _process(delta: float) -> void:
	_time += delta
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i][1] -= delta
		if _fx[i][1] <= 0.0:
			(_fx[i][0] as Node).queue_free()
			_fx.remove_at(i)
