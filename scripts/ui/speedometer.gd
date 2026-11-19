class_name Speedometer
extends Control
## Design: design/gdd/driving.md.
## The dashboard gauge, shown only while the player is in a car: a 270 degree dial with the needle on the speed (km/h), the engine speed as a
## thin ring round the edge (turning red near the redline), the speed in digits underneath and the gear (R, N, 1 to 5) in the middle of the
## dial. Drawn in code (no images). Reads the car's Drivetrain each frame; owns no gameplay.

const SIZE := 176.0
const START := deg_to_rad(135.0)      # the dial runs clockwise from the lower left
const SWEEP := deg_to_rad(270.0)
const GOLD := Color("#ffd75e")
const NEEDLE := Color("#ff5a4d")
const RED_ZONE := 0.85                # the last 15% of the scale is the redline

var car: DrivableCar
var shown_kmh := 0.0                  # what the needle shows (it follows the speed a little behind, like a real needle)
var max_kmh := 140.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the gauge for a car (the player got in), or hides it (the player got out).
func set_car(p_car: DrivableCar) -> void:
	car = p_car
	visible = car != null
	if car:
		max_kmh = scale_max(car.drivetrain.top_speed() * 3.6)
		shown_kmh = absf(car.speed) * 3.6
	queue_redraw()


## The top of the dial: the car's top speed rounded up to the next 20 km/h.
static func scale_max(top_kmh: float) -> float:
	return ceilf(top_kmh / 20.0) * 20.0


## How far round the dial (0 to 1) a speed is.
static func fraction(kmh: float, p_max: float) -> float:
	return clampf(kmh / maxf(p_max, 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	if car == null:
		return
	shown_kmh = lerpf(shown_kmh, absf(car.speed) * 3.6, clampf(delta * 10.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if car == null:
		return
	var c := Vector2(SIZE, SIZE) * 0.5
	var r := SIZE * 0.5 - 4.0
	var dt := car.drivetrain
	draw_circle(c, r + 2.0, Color(0.03, 0.04, 0.07, 0.62))
	draw_arc(c, r, 0.0, TAU, 48, Color(GOLD, 0.35), 2.0)
	# The engine speed, a thin ring just inside the edge.
	var rev := dt.rpm_fraction
	draw_arc(c, r - 5.0, START, START + SWEEP, 40, Color(1, 1, 1, 0.08), 3.0)
	if rev > 0.01:
		draw_arc(c, r - 5.0, START, START + SWEEP * rev, 40, Color("#ff5a4d") if rev >= RED_ZONE else Color("#5fd0c8"), 3.0)
	# The scale: a tick every 10 km/h, a longer one and the number every 20 (every 40 on a short gauge).
	var font := ThemeDB.fallback_font
	var steps := int(max_kmh / 10.0)
	for i in steps + 1:
		var f := float(i) / steps
		var a := START + SWEEP * f
		var dir := Vector2(cos(a), sin(a))
		var major := i % 2 == 0
		var col := Color("#ff8a7a") if f >= RED_ZONE else Color(1, 1, 1, 0.85 if major else 0.45)
		draw_line(c + dir * (r - (22.0 if major else 17.0)), c + dir * (r - 12.0), col, 2.0 if major else 1.0)
		if major and i % 4 == 0:
			var label := str(i * 10)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var at := c + dir * (r - 34.0)
			draw_string(font, at - Vector2(w * 0.5, -4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	# The needle.
	var na := START + SWEEP * fraction(shown_kmh, max_kmh)
	var ndir := Vector2(cos(na), sin(na))
	draw_line(c - ndir * 10.0, c + ndir * (r - 20.0), Color(0, 0, 0, 0.5), 5.0)
	draw_line(c - ndir * 10.0, c + ndir * (r - 20.0), NEEDLE, 3.0)
	draw_circle(c, 7.0, Color("#1d1b24"))
	draw_circle(c, 4.0, NEEDLE)
	# The gear, in the middle of the dial (dimmed while the gearbox is changing gear).
	var gear := dt.gear_text()
	var gear_col := Color(GOLD, 0.45) if dt.shift_left > 0.0 else GOLD
	var gc := c + Vector2(0, -26)
	draw_circle(gc, 21.0, Color(0, 0, 0, 0.55))
	draw_arc(gc, 21.0, 0.0, TAU, 28, Color(GOLD, 0.6), 1.5)
	var gw := font.get_string_size(gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(font, gc - Vector2(gw * 0.5, -10.0), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, gear_col)
	# The speed in digits.
	var text := str(roundi(shown_kmh))
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(font, c + Vector2(-tw * 0.5, 50.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	var unit_w := font.get_string_size("km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, c + Vector2(-unit_w * 0.5, 64.0), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))
