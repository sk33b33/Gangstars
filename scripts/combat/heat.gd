class_name Heat
extends RefCounted
## How much attention the player has from the police, 0..5 ("stars"). Shooting near people, and
## especially hurting civilians or police, raises it; it cools down while no officer can see the
## player. Pure logic, unit-tested; GameSession feeds it and the police read level().
##   1+: officers who see you come over ("Stop! Police!")
##   2+: officers who see you draw and fight; bakkies run lights and siren

signal changed(level: int)

const MAX := 5.0
const COOL_DELAY := 25.0      # seconds unseen before it starts dropping
const COOL_RATE := 1.0 / 20.0 # stars per second after that

var value := 0.0
## Perk: heat builds more slowly (Vlakte Vipers' "low profile" sets this to 0.6).
var gain_mult := 1.0
var _unseen := 0.0
var _last_level := 0


func add(amount: float) -> void:
	value = clampf(value + amount * gain_mult, 0.0, MAX)
	_unseen = 0.0
	_emit()


func tick(dt: float, seen_by_police: bool) -> void:
	if value <= 0.0:
		return
	if seen_by_police:
		_unseen = 0.0
		return
	_unseen += dt
	if _unseen > COOL_DELAY:
		value = maxf(0.0, value - COOL_RATE * dt)
		_emit()


func clear() -> void:
	value = 0.0
	_unseen = 0.0
	_emit()


func level() -> int:
	return int(ceil(value - 0.001)) if value > 0.0 else 0


func _emit() -> void:
	var l := level()
	if l != _last_level:
		_last_level = l
		changed.emit(l)
