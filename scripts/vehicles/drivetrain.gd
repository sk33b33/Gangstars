class_name Drivetrain
extends RefCounted
## Design: design/gdd/driving.md.
## An engine and an automatic gearbox, so a car pulls away slowly and strongly in 1st and runs out of puff in 5th (data/vehicles/drivetrains.json,
## per vehicle model). Pure logic: DrivableCar feeds it the pedal and its speed each physics frame and gets back the acceleration;
## the speedometer and the engine sound read `gear`, `rpm_fraction` and `rpm`.
##
##   - acceleration in a gear is `launch_accel` scaled by how short the gear is (1st's top speed over this gear's) and by a torque curve
##     over the engine speed, so each gear is weaker than the one below; nothing is pulled while the gearbox is changing gear (a short
##     torque cut) or at the redline;
##   - it shifts up near the redline and down when the engine would fall below about half its range; at a stop in neutral, the pedal
##     picks 1st or reverse; braking is a separate, stronger force; lifting off slows you by rolling and air drag plus engine braking
##     (more in a low gear).

const UP_AT := 0.93            # shift up at this fraction of the gear's top speed (with the pedal down)
const DOWN_BELOW := 0.55       # shift down when below this fraction of the next gear down's top speed
const SHIFT_TIME := 0.28       # seconds of torque cut when changing up
const DOWNSHIFT_TIME := 0.18
const CLUTCH_FLOOR := 0.34     # the engine never turns slower than this share of its range while pulling away (the clutch slips)
const STILL := 0.3             # m/s: below this the car counts as stopped
const BRAKE := 8.5             # m/s^2 at full brake
const GRIP := 6.0              # the most the tyres can push the car forward (m/s^2)
const ROLL := 0.10             # m/s^2 rolling resistance
const AIR := 0.00045           # m/s^2 per (m/s)^2

var gears_kmh: Array = [30.0, 55.0, 82.0, 108.0, 128.0]
var launch_accel := 4.0
var reverse_kmh := 20.0
var idle := 850.0
var redline := 6200.0
## The driver's skill (Player.drive_factor): scales every gear's speed, so a better driver is a little faster.
var skill := 1.0

## 1..gears: forward; 0: neutral; -1: reverse.
var gear := 0
var rpm_fraction := 0.0
var shift_left := 0.0
var braking := false


static var _data: Dictionary = {}


## The drivetrain for a vehicle model from the data file (the default entry for a model it does not list).
static func for_model(model: String) -> Drivetrain:
	if _data.is_empty():
		var loaded: Variant = DataFiles.load_json("res://data/vehicles/drivetrains.json")
		_data = loaded if loaded is Dictionary else {"default": {}, "models": {}}
	var spec: Dictionary = (_data.get("models", {}) as Dictionary).get(model, _data.get("default", {}))
	var d := Drivetrain.new()
	d.gears_kmh = spec.get("gears_kmh", d.gears_kmh)
	d.launch_accel = float(spec.get("launch_accel", d.launch_accel))
	d.reverse_kmh = float(spec.get("reverse_kmh", d.reverse_kmh))
	d.idle = float(spec.get("idle", d.idle))
	d.redline = float(spec.get("redline", d.redline))
	return d


func gear_count() -> int:
	return gears_kmh.size()


## Top speed in m/s (the last gear at the redline).
func top_speed() -> float:
	return float(gears_kmh[gears_kmh.size() - 1]) / 3.6 * skill


## Speed (m/s) the current forward gear reaches at the redline.
func gear_top(g: int) -> float:
	return float(gears_kmh[clampi(g, 1, gears_kmh.size()) - 1]) / 3.6 * skill


func rpm() -> float:
	return lerpf(idle, redline, rpm_fraction)


## "R", "N" or the gear number, for the speedometer.
func gear_text() -> String:
	return "R" if gear < 0 else ("N" if gear == 0 else str(gear))


## The torque available at a share of the engine's range: weak at low revs, strongest in the middle, fading towards the redline.
static func torque(r: float) -> float:
	return lerpf(0.55, 1.0, clampf(r / 0.55, 0.0, 1.0)) if r < 0.55 else lerpf(1.0, 0.78, clampf((r - 0.55) / 0.45, 0.0, 1.0))


## Advances the gearbox by `delta` and returns the acceleration (m/s^2, along the car's forward axis, positive forwards).
## `speed` is signed (negative backing up); `pedal` is -1 (brake / reverse) to +1 (accelerate).
func update(delta: float, speed: float, pedal: float) -> float:
	braking = false
	var moving_forward := speed > STILL
	var moving_back := speed < -STILL
	var v := absf(speed)
	shift_left = maxf(0.0, shift_left - delta)
	var drag := ROLL + AIR * v * v
	# What the pedal means depends on which way the car is going.
	var drive := 0.0       # +1 pulling forwards, -1 pulling backwards
	var brake := 0.0
	if moving_forward:
		if pedal > 0.0: drive = pedal
		elif pedal < 0.0: brake = -pedal
	elif moving_back:
		if pedal < 0.0: drive = pedal
		elif pedal > 0.0: brake = pedal
	else:
		drive = pedal
	# Gear selection.
	if drive < 0.0 and not moving_forward:
		gear = -1
	elif drive > 0.0 and gear <= 0:
		gear = 1
		shift_left = 0.0
	elif gear == 0 and v < STILL:
		gear = 0
	if gear > 0:
		_shift(v, drive > 0.0)
	if gear > 0 and drive == 0.0 and brake == 0.0 and v < 0.2:
		gear = 0
	# Engine speed.
	if gear > 0:
		var r := v / gear_top(gear)
		rpm_fraction = clampf(maxf(r, CLUTCH_FLOOR if drive > 0.0 and v < gear_top(1) * 0.35 else 0.0), 0.0, 1.0)
	elif gear < 0:
		rpm_fraction = clampf(maxf(v / (reverse_kmh / 3.6 * skill), CLUTCH_FLOOR if drive < 0.0 else 0.0), 0.0, 1.0)
	else:
		rpm_fraction = move_toward(rpm_fraction, 0.0, delta * 2.0)
	# Forces.
	var accel := 0.0
	if drive != 0.0 and shift_left <= 0.0 and gear != 0:
		var top := gear_top(gear) if gear > 0 else reverse_kmh / 3.6 * skill
		if v < top:
			var ratio := gear_top(1) / gear_top(maxi(gear, 1))
			var pull := minf(launch_accel * (pow(ratio, 0.62) if gear > 0 else 0.6) * torque(rpm_fraction) * absf(drive), GRIP)
			accel = pull * signf(drive)
	if brake > 0.0:
		braking = true
		accel -= BRAKE * brake * signf(speed)
	var resist := drag
	if drive == 0.0 and brake == 0.0 and gear > 0:   # coasting in gear: the engine holds the car back, more in a low gear
		resist += (0.25 + 1.4 * rpm_fraction) * (gear_top(1) / gear_top(gear)) * 0.5
	if v > 0.05:
		accel -= resist * signf(speed)
	return accel


func _shift(v: float, pedal_down: bool) -> void:
	if shift_left > 0.0:
		return
	if pedal_down and gear < gear_count() and v >= gear_top(gear) * UP_AT:
		gear += 1
		shift_left = SHIFT_TIME
	elif gear > 1 and v < gear_top(gear - 1) * DOWN_BELOW:
		gear -= 1
		shift_left = DOWNSHIFT_TIME
