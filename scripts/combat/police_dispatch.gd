class_name PoliceDispatch
extends Node
## Who fights whom, and the player's heat. Owned by the GameSession.
## - Heat (see Heat): shooting near people, hurting civilians and especially police raises it.
## - Police who can see the player: heat 1 -> "Stop! Police!"; heat 2+ -> they draw and fight.
##   They also take on gangsters who are shooting near them. Bakkies run lights and sirens while
##   the police are busy.
## - The player's crew fights whoever is fighting the player; rival crews back each other up.
## - Knocked out: wake at the safehouse, pay a R100 fine, heat cleared.

signal player_knocked_out
signal player_woke

const TICK := 0.25
const SEE_RANGE := 35.0
const WARN_RANGE := 20.0
const FIRE_HEAT_RANGE := 35.0
const FIRE_HEAT_COOLDOWN := 8.0
const ASSIST_RANGE := 30.0
const WAKE_TIME := 4.0
const FINE := 100
const TURF_WARN_RANGE := 12.0
const TURF_FIGHT_RANGE := 6.0
const TURF_LINGER := 5.0
const AIM_PROVOKE_RANGE := 15.0

var heat := Heat.new()
var district: District
var player: Player
var progression: ProgressionState
var audio: AudioDirector
var safehouse_id := ""
var responding := false
var police_fights := 0
var knockouts := 0

var _tick := 0.0
var _time := 0.0
var _last_fire_heat := -99.0
var _warned := {}            # resident id -> time
var _crew_shooters := {}     # Resident -> time of last shot
var _siren_timer := 0.0
var _wake_timer := -1.0
var _turf_warned := {}      # resident id -> time
var _linger := {}           # resident id -> seconds the player has stood too close
var turf_fights := 0


func setup(p_district: District, p_player: Player, p_progression: ProgressionState, p_safehouse_id: String) -> void:
	district = p_district
	player = p_player
	progression = p_progression
	safehouse_id = p_safehouse_id
	player.combat = district.combat
	district.combat.shot_fired.connect(_on_shot_fired)
	district.combat.target_hit.connect(_on_target_hit)
	player.knocked_out.connect(_on_knocked_out)


func _physics_process(delta: float) -> void:
	if district == null:
		return
	_time += delta
	if _wake_timer >= 0.0:
		_wake_timer -= delta
		if _wake_timer < 0.0:
			_wake()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var seen := _update_police()
	heat.tick(TICK, seen)
	_update_crews()
	_update_bakkies(TICK)


# ------------------------------------------------------------------ heat

func _on_shot_fired(shooter: Node3D, origin: Vector3, _weapon: String) -> void:
	if shooter == player:
		if _time - _last_fire_heat > FIRE_HEAT_COOLDOWN and _anyone_near(origin, FIRE_HEAT_RANGE):
			_last_fire_heat = _time
			heat.add(1.0)
	elif shooter is Resident and (shooter as Resident).data.role == "crew":
		_crew_shooters[shooter] = _time


func _on_target_hit(target: Node3D, shooter: Node3D, _damage: float, down: bool) -> void:
	if shooter != player or not target is Resident:
		return
	match (target as Resident).data.role:
		"police":
			heat.add(2.0 + (1.0 if down else 0.0))
		"crew":
			heat.add(0.25)
		"player_crew":
			pass
		_:
			heat.add(1.0)


func _anyone_near(p: Vector3, radius: float) -> bool:
	for r: Resident in district.residents.values():
		if not r.is_inside and r.global_position.distance_to(p) < radius:
			return true
	return false


# ------------------------------------------------------------------ police

## Returns true if any officer can see the player.
func _update_police() -> bool:
	var level := heat.level()
	var any_seen := false
	police_fights = 0
	for r: Resident in district.residents.values():
		if r.data.role != "police" or not r.can_fight() or r.sim_tier == "far":
			continue
		if r.fight_target != null:
			police_fights += 1
			if r.fight_target == player and level == 0:
				r.end_fight()
			continue
		var d := r.global_position.distance_to(player.global_position)
		var sees := not player.is_down() and d < SEE_RANGE and r._line_of_sight(player)
		any_seen = any_seen or sees
		if sees and level >= 2:
			r.start_fight(player)
		elif sees and level == 1 and d < WARN_RANGE and _time - float(_warned.get(r.data.id, -99.0)) > 12.0:
			_warned[r.data.id] = _time
			r.say("Stop! Police!", 2.5)
			r.face_point(player.global_position)
		else:
			# Gangsters shooting nearby are fair game too.
			for shooter in _crew_shooters.keys():
				if not is_instance_valid(shooter) or _time - float(_crew_shooters[shooter]) > 6.0:
					_crew_shooters.erase(shooter)
					continue
				if (shooter as Resident).global_position.distance_to(r.global_position) < 45.0 and r._line_of_sight(shooter):
					r.start_fight(shooter)
					break
	responding = level >= 2 or police_fights > 0
	return any_seen


# ------------------------------------------------------------------ crews

func _update_crews() -> void:
	var attackers: Array[Resident] = []
	for r: Resident in district.residents.values():
		if r.fight_target == player and r.data.role != "police":
			attackers.append(r)
	for r: Resident in district.residents.values():
		if r.fight_target != null or not r.can_fight() or r.sim_tier == "far":
			continue
		if r.data.role == "player_crew" or r.is_ally():
			# Back up the player: take on the nearest attacker (gangster or police).
			var best: Resident = null
			var best_d := ASSIST_RANGE
			for a in district.residents.values():
				if a.fight_target == player:
					var d: float = a.global_position.distance_to(r.global_position)
					if d < best_d:
						best_d = d
						best = a
			if best:
				r.start_fight(best)
		elif r.data.role == "crew":
			# Rival crews stick together: join a crew-mate already fighting the player.
			var joined := false
			for a in attackers:
				if a.data.faction_id == r.data.faction_id and a.global_position.distance_to(r.global_position) < 20.0:
					joined = r.start_fight(player)
					break
			if not joined:
				_turf_check(r)


## Rival crews on their own turf: a warning first; standing in their face or pointing a gun at
## them starts a fight.
func _turf_check(r: Resident) -> void:
	if district.player_crew_id.is_empty() or player.is_down() or player.is_driving():
		return
	var d := r.global_position.distance_to(player.global_position)
	if d > AIM_PROVOKE_RANGE:
		_linger.erase(r.data.id)
		return
	if player.aiming:
		var to := (r.global_position - player.global_position).normalized()
		if (-player.pivot.global_basis.z).dot(to) > 0.92 and r._line_of_sight(player):
			_provoke(r, "Ja? You pointing that at me?")
			return
	var home := district.crews.home(r.data.faction_id)
	if home.is_empty() or district.area_at(r.global_position) != home:
		return   # away from their turf they mind their own business
	if d < TURF_WARN_RANGE and _time - float(_turf_warned.get(r.data.id, -99.0)) > 30.0 and r._line_of_sight(player):
		_turf_warned[r.data.id] = _time
		var warning := str(district.crews.get_crew(r.data.faction_id).get("warning", "Not your turf, %s."))
		r.say(warning % district.crews.display_name(district.player_crew_id).trim_suffix("s"), 3.0)
		r.face_point(player.global_position)
	if d < TURF_FIGHT_RANGE:
		_linger[r.data.id] = float(_linger.get(r.data.id, 0.0)) + TICK
		if _linger[r.data.id] >= TURF_LINGER:
			_provoke(r, "I told you. Now you'll learn.")
	else:
		_linger.erase(r.data.id)


func _provoke(r: Resident, line: String) -> void:
	_linger.erase(r.data.id)
	if r.start_fight(player):
		turf_fights += 1
		r.say(line, 2.5)


# ------------------------------------------------------------------ bakkies

func _update_bakkies(dt: float) -> void:
	if district.traffic == null:
		return
	_siren_timer -= dt
	for car: TrafficCar in district.traffic.cars:
		if car.model != "police" or car.body == null:
			continue
		VehicleLibrary.set_lights(car.body, responding, _time)
		car.cruise_speed = 11.0 if responding else 8.0
		if responding and _siren_timer <= 0.0 and audio and car.global_position.distance_to(player.global_position) < 70.0:
			audio.play_at("siren", car.global_position + Vector3(0, 1.5, 0), -4.0)
	if _siren_timer <= 0.0:
		_siren_timer = 1.6


# ------------------------------------------------------------------ knocked out

func _on_knocked_out() -> void:
	knockouts += 1
	player.input_enabled = false
	_wake_timer = WAKE_TIME
	player_knocked_out.emit()


func _wake() -> void:
	for r: Resident in district.residents.values():
		if r.fight_target == player:
			r.end_fight()
	var plot: HousePlot = district.plots.get(safehouse_id)
	var at: Vector3 = plot.door_position() + plot.global_basis.z * 1.5 if plot else Vector3(0, 0.1, 5.4)
	player.revive_at(at)
	progression.spend(mini(FINE, progression.cash))
	heat.clear()
	player.input_enabled = true
	player_woke.emit()
