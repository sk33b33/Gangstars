extends SceneTree
## Dev: renders the speedometer in four states. xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/godot/gauge_shot.gd
var _frame := 0
var _gauge: Speedometer
var _car: DrivableCar
var _states := [[0.0, 0, 0.0, 0.0], [5.6, 1, 0.55, 0.0], [19.4, 3, 0.62, 0.0], [34.4, 5, 0.96, 0.0]]
var _i := -1


func _initialize() -> void:
	root.size = Vector2i(640, 240)
	var bg := ColorRect.new()
	bg.color = Color("#6f8f6a")
	bg.size = Vector2(640, 240)
	root.add_child(bg)
	_car = DrivableCar.new()
	root.add_child(_car)
	_car.setup("gauge_demo", "demo", Color.WHITE)
	_gauge = Speedometer.new()
	_gauge.position = Vector2(232, 30)
	root.add_child(_gauge)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_gauge.set_car(_car)   # the nodes have been through _ready by now
	if _frame % 4 != 0 or _frame < 4:
		return false
	if _i >= 0:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/output/gauge_%d.png" % _i))
	_i += 1
	if _i >= _states.size():
		quit()
		return true
	var st: Array = _states[_i]
	_car.speed = st[0]
	_car.drivetrain.gear = st[1]
	_car.drivetrain.rpm_fraction = st[2]
	_gauge.shown_kmh = float(st[0]) * 3.6
	return false
