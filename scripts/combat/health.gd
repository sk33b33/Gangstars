class_name Health
extends RefCounted
## Arcade health: hits take points off; at 0 the character is knocked down (never killed), lies
## down for DOWN_TIME, then gets up with RECOVER_HP. Out of a fight, health slowly regenerates.
## Pure logic, unit-tested; the owner calls tick() and listens to the signals.

signal hurt(amount: float)
signal knocked_down
signal recovered

const MAX_HP := 100.0
const DOWN_TIME := 20.0
const RECOVER_HP := 60.0
const REGEN_DELAY := 6.0
const REGEN_RATE := 4.0       # hp per second

var hp := MAX_HP
var down := false
var times_down := 0
var _down_timer := 0.0
var _since_hit := 99.0


## Returns true if this hit knocked the character down.
func take(amount: float) -> bool:
	if down or amount <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	_since_hit = 0.0
	hurt.emit(amount)
	if hp <= 0.0:
		down = true
		times_down += 1
		_down_timer = DOWN_TIME
		knocked_down.emit()
		return true
	return false


func tick(dt: float) -> void:
	if down:
		_down_timer -= dt
		if _down_timer <= 0.0:
			down = false
			hp = RECOVER_HP
			_since_hit = 0.0
			recovered.emit()
		return
	_since_hit += dt
	if _since_hit > REGEN_DELAY and hp < MAX_HP:
		hp = minf(MAX_HP, hp + REGEN_RATE * dt)


## Gets up now (e.g. the player waking at the safehouse).
func revive(amount := RECOVER_HP) -> void:
	down = false
	hp = amount
	_down_timer = 0.0
	recovered.emit()


func fraction() -> float:
	return hp / MAX_HP
