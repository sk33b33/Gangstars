class_name MiniMap
extends Control
## A small translucent map in the top left corner: the streets around you (north is up), you as a white arrow that shows which
## way you face, and solid coloured dots: gold for the mission (the person to see, the place to go) and the people who have one
## for you, blue for the SAPS. A dot beyond the edge stays on the rim, pointing the way.
## Reads the real Westridge data; owns no rules. Design: design/gdd/hud.md.

const SIZE := 190.0
const RADIUS := 140.0        # metres from the middle to the edge
const REBUILD_DISTANCE := 20.0
const GOLD := Color("#ffd75e")
const POLICE := Color("#4a90e2")

var data: RealDistrictData
var player: Node3D
## Callable -> Array of {pos: Vector3, color: Color, big: bool}.
var markers_provider := Callable()
var _roads := PackedVector2Array()      # pairs of world (x, z) points: one street segment each
var _road_class := PackedInt32Array()   # 0 path, 1 lane or street, 2 main or collector
var _built_at := Vector2(1e9, 1e9)
var _redraw_in := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func setup(p_data: RealDistrictData, p_player: Node3D, p_markers := Callable()) -> void:
	data = p_data
	player = p_player
	markers_provider = p_markers
	_built_at = Vector2(1e9, 1e9)


func _process(delta: float) -> void:
	if not visible or data == null or player == null:
		return
	_redraw_in -= delta
	if _redraw_in <= 0.0:
		_redraw_in = 0.1   # ten times a second is plenty for a small map
		queue_redraw()


## The street segments within reach of `centre` (world x, z), from the chunks around it.
func _rebuild(centre: Vector2) -> void:
	_built_at = centre
	_roads.clear()
	_road_class.clear()
	var reach := RADIUS * 1.5
	var cx := data.chunk_at(Vector3(centre.x, 0, centre.y))
	var span := int(ceil(reach / data.chunk_size))
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var key := cx + Vector2i(dx, dz)
			if not data.has_chunk(key):
				continue
			for r in data.load_chunk(key).get("roads", []):
				var kind := 0 if str(r.c) == "path" else (2 if str(r.c) in ["main", "collector"] else 1)
				var p: Array = r.p
				for i in p.size() - 1:
					var a := Vector2(p[i][0], p[i][1])
					var b := Vector2(p[i + 1][0], p[i + 1][1])
					if a.distance_to(centre) < reach or b.distance_to(centre) < reach:
						_roads.append(a)
						_roads.append(b)
						_road_class.append(kind)


func _draw() -> void:
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0.05, 0.06, 0.09, 0.42)   # translucent: the world shows through
	edge.set_corner_radius_all(10)
	edge.border_width_left = 4
	edge.border_color = Color(GOLD, 0.8)
	draw_style_box(edge, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)))
	if data == null or player == null:
		return
	var here := Vector2(player.global_position.x, player.global_position.z)
	if here.distance_to(_built_at) > REBUILD_DISTANCE:
		_rebuild(here)
	var scale := SIZE * 0.5 / RADIUS
	var mid := Vector2(SIZE, SIZE) * 0.5
	for i in _road_class.size():
		var a := mid + (_roads[i * 2] - here) * scale
		var b := mid + (_roads[i * 2 + 1] - here) * scale
		match _road_class[i]:
			0:
				draw_line(a, b, Color(1, 1, 1, 0.18), 1.0)
			1:
				draw_line(a, b, Color(1, 1, 1, 0.55), 2.5)
			_:
				draw_line(a, b, Color(0.98, 0.88, 0.55, 0.75), 3.5)
	if markers_provider.is_valid():
		for m: Dictionary in markers_provider.call():
			_marker(m, here, scale, mid)
	_player_arrow(mid)


func _marker(m: Dictionary, here: Vector2, scale: float, mid: Vector2) -> void:
	var pos: Vector3 = m.pos
	var off := (Vector2(pos.x, pos.z) - here) * scale
	var limit := SIZE * 0.5 - 7.0
	var clamped := off
	var outside := absf(off.x) > limit or absf(off.y) > limit
	if outside:
		clamped = off * (limit / maxf(absf(off.x), absf(off.y)))
	var radius := 7.0 if bool(m.get("big", false)) else 5.0
	draw_circle(mid + clamped, radius + 1.5, Color(0, 0, 0, 0.7))
	draw_circle(mid + clamped, radius, m.color)
	if outside:   # on the rim: a small pointer towards it
		var dir := off.normalized()
		draw_circle(mid + clamped + dir * (radius + 3.0), 2.0, m.color)


func _player_arrow(mid: Vector2) -> void:
	var face := Vector2(0, -1)
	if player.has_method("facing_dir"):
		var f: Vector3 = player.facing_dir()
		face = Vector2(f.x, f.z).normalized() if Vector2(f.x, f.z).length() > 0.01 else face
	var side := Vector2(-face.y, face.x)
	var tip := mid + face * 10.0
	var left := mid - face * 6.0 + side * 6.0
	var right := mid - face * 6.0 - side * 6.0
	draw_colored_polygon(PackedVector2Array([tip + face * 1.5, left - side * 1.0, right + side * 1.0]), Color(0, 0, 0, 0.8))
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color.WHITE)
