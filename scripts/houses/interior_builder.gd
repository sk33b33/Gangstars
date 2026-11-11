class_name InteriorBuilder
extends RefCounted
## Builds a house interior from code: a room shell (floor, walls with a front door, ceiling,
## windows, lights) and a furniture layout. Layouts: "home" (lounge + kitchen), "safehouse"
## (home with a bed, a stash crate and a planning map) and "shebeen" (Aunty Mavis' smokkie: bar,
## bottle shelf, pool table, jukebox, crates). Local frame: floor at y = 0, the front wall (with
## the door) at z = +depth/2, the room faces -Z from the door. Props come from PropLibrary.
## Returns the spots the InteriorSystem needs (spawn, exit, seats, counter...).

const HEIGHT := 2.7
const WALL := 0.2
## Collision boxes for the furniture (size), so nobody walks through the couch.
const SOLID := {
	"couch": Vector3(2.0, 0.8, 0.85), "armchair": Vector3(0.95, 0.8, 0.85), "coffee_table": Vector3(1.0, 0.45, 0.56),
	"tv_unit": Vector3(1.4, 1.1, 0.45), "kitchen_counter": Vector3(2.4, 0.92, 0.62), "stove": Vector3(0.6, 0.92, 0.6),
	"fridge": Vector3(0.66, 1.76, 0.64), "dining_table": Vector3(1.2, 0.76, 0.8), "bed": Vector3(1.44, 0.6, 2.1),
	"wardrobe": Vector3(1.2, 2.0, 0.6), "bar_counter": Vector3(3.1, 1.08, 0.62), "bottle_shelf": Vector3(2.0, 1.8, 0.32),
	"jukebox": Vector3(0.7, 1.45, 0.5), "pool_table": Vector3(2.3, 0.85, 1.3), "crate_stack": Vector3(1.1, 0.6, 0.4),
	"stash_crate": Vector3(0.9, 0.55, 0.6),
}
const WALL_COLOURS := [Color("#f2e6c9"), Color("#d8e8d0"), Color("#f0d6c8"), Color("#cfe0ec"), Color("#efe2a8"), Color("#e6d4e8")]
const SOFA_COLOURS := [Color("#7a2e2a"), Color("#3f5874"), Color("#5b7a3a"), Color("#8c6044"), Color("#6d4a7a")]
const PRINTS := ["print_rose", "print_blue", "print_sun", "print_teal", "print_lilac"]


## kind: "home", "safehouse" or "shebeen". seed varies colours. Returns the layout's spots.
## style (homes): "cottage" (Rocklands: floorboards, whitewash), "flat" (Lentegeur), "double"
## (a staircase), or "" (Westridge).
static func build(root: Node3D, kind: String, seed: int, sign := "sign_shebeen", style := "") -> Dictionary:
	match kind:
		"shebeen":
			var sp := _shell(root, Vector2(10.0, 7.0), Color("#3d5a4a"), "floor_boards", seed)
			_shebeen(root, Vector2(10.0, 7.0), sp, seed, sign)
			return sp
		"den":
			var sp := _shell(root, Vector2(7.0, 5.5), Color("#4a4f3a"), "floor_boards", seed)
			_den(root, Vector2(7.0, 5.5), sp, seed, sign)
			return sp
		"police":
			var sp := _shell(root, Vector2(9.0, 6.5), Color("#dfe6ef"), "floor_lino", seed)
			_police(root, Vector2(9.0, 6.5), sp)
			return sp
	# Homes: a lounge + kitchen (9 m) and a bedroom (3.6 m) through a doorway on the right.
	var wall_tint: Color = WALL_COLOURS[seed % WALL_COLOURS.size()]
	var floor_tex := "floor_lino"
	if style == "cottage":
		wall_tint = Color("#f4efe4")
		floor_tex = "floor_boards"
	var size := Vector2(12.6, 6.5)
	var spots := _shell(root, size, wall_tint, floor_tex, seed)
	var main := Node3D.new()
	main.name = "Main"
	main.position = Vector3(-1.8, 0, 0)
	root.add_child(main)
	var local := {"seats": [], "stands": [], "windows": spots.windows}
	_home(main, Vector2(9.0, 6.5), local, seed, kind == "safehouse", style)
	for key in ["seats", "stands"]:
		for sp in local[key]:
			spots[key].append({"pos": sp.pos + main.position, "yaw": sp.yaw})
	for key in ["stash"]:
		if local.has(key):
			spots[key] = local[key] + main.position
	spots["bed"] = _bedroom(root, size, wall_tint, seed, kind == "safehouse")
	return spots


static func _bedroom(root: Node3D, size: Vector2, tint: Color, seed: int, safehouse: bool) -> Vector3:
	var d := size.y
	var x0 := size.x / 2 - 3.6   # partition
	var wall := PixelMaterials.surface("wall_plaster", Vector2(2, 2), tint)
	var gap := 1.0
	var back_len := d / 2 - gap / 2
	Geo.box(root, Vector3(0.15, HEIGHT, back_len), Vector3(x0, HEIGHT / 2, -d / 2 + back_len / 2), wall)
	Geo.box(root, Vector3(0.15, HEIGHT, back_len), Vector3(x0, HEIGHT / 2, d / 2 - back_len / 2), wall)
	Geo.box(root, Vector3(0.15, HEIGHT - 2.1, gap), Vector3(x0, 2.1 + (HEIGHT - 2.1) / 2, 0), wall)
	var bx := size.x / 2 - 1.0
	_put(root, "bed", Vector3(bx, 0, -d / 2 + 1.3), 0.0 if not safehouse else 0.0, Color("#2f4a6e") if safehouse else SOFA_COLOURS[(seed / 3) % SOFA_COLOURS.size()])
	_put(root, "wardrobe", Vector3(x0 + 0.75, 0, -d / 2 + 0.35))
	Geo.box(root, Vector3(1.4, 0.012, 1.0), Vector3(bx - 0.4, 0.006, 0.3), PixelMaterials.panel("rug"), false)
	_picture(root, "frame_mountain" if seed % 2 else "frame_family", Vector2(0.6, 0.42), Vector3(size.x / 2 - 0.01, 1.6, 0.6), -PI / 2)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(bx - 0.6, HEIGHT - 0.5, -0.5)
	lamp.light_color = Color("#ffe2b0")
	lamp.light_energy = 1.0
	lamp.omni_range = 4.5
	root.add_child(lamp)
	PropLibrary.place(root, "ceiling_lamp", Vector3(bx - 0.6, HEIGHT, -0.5))
	return Vector3(bx, 1.0, -d / 2 + 1.3)


# ------------------------------------------------------------------ the room

static func _shell(root: Node3D, size: Vector2, wall_tint: Color, floor_tex: String, seed: int) -> Dictionary:
	var w := size.x
	var d := size.y
	var wall := PixelMaterials.surface("wall_plaster", Vector2(2, 2), wall_tint)
	Geo.box(root, Vector3(w + WALL * 2, 0.2, d + WALL * 2), Vector3(0, -0.1, 0), PixelMaterials.surface(floor_tex, Vector2(0.8, 0.8)))
	Geo.box(root, Vector3(w + WALL * 2, 0.2, d + WALL * 2), Vector3(0, HEIGHT + 0.1, 0), PixelMaterials.flat(Color("#ece8dc")))
	Geo.box(root, Vector3(w, HEIGHT, WALL), Vector3(0, HEIGHT / 2, -d / 2 - WALL / 2), wall)                    # back
	Geo.box(root, Vector3(WALL, HEIGHT, d), Vector3(-w / 2 - WALL / 2, HEIGHT / 2, 0), wall)                    # left
	Geo.box(root, Vector3(WALL, HEIGHT, d), Vector3(w / 2 + WALL / 2, HEIGHT / 2, 0), wall)                     # right
	var side := (w - 1.1) / 2.0                                                                               # front, door gap at x = 0
	Geo.box(root, Vector3(side, HEIGHT, WALL), Vector3(-w / 2 + side / 2, HEIGHT / 2, d / 2 + WALL / 2), wall)
	Geo.box(root, Vector3(side, HEIGHT, WALL), Vector3(w / 2 - side / 2, HEIGHT / 2, d / 2 + WALL / 2), wall)
	Geo.box(root, Vector3(1.1, HEIGHT - 2.1, WALL), Vector3(0, 2.1 + (HEIGHT - 2.1) / 2, d / 2 + WALL / 2), wall)
	Geo.box(root, Vector3(1.1, 2.1, WALL), Vector3(0, 1.05, d / 2 + WALL * 1.5), PixelMaterials.flat(Color("#141218")))   # behind the door
	var door := Geo.quad(root, Vector2(1.0, 2.05), Vector3(0, 1.03, d / 2 - 0.01), PixelMaterials.panel("door_gate"), PI)
	door.name = "ExitDoor"
	# Skirting boards.
	var skirting := PixelMaterials.flat(wall_tint.darkened(0.45))
	Geo.box(root, Vector3(w, 0.1, 0.02), Vector3(0, 0.05, -d / 2 + 0.01), skirting, false)
	Geo.box(root, Vector3(0.02, 0.1, d), Vector3(-w / 2 + 0.01, 0.05, 0), skirting, false)
	Geo.box(root, Vector3(0.02, 0.1, d), Vector3(w / 2 - 0.01, 0.05, 0), skirting, false)
	# Windows on the front wall (daylight through burglar bars) with print curtains.
	var windows: Array = []
	var curtain := PixelMaterials.fabric(PRINTS[seed % PRINTS.size()])
	for x in [-w / 2 + 1.6, w / 2 - 1.6]:
		windows.append(Geo.quad(root, Vector2(1.4, 1.15), Vector3(x, 1.55, d / 2 - 0.01), _window_material(), PI))
		for s in [-1.0, 1.0]:
			Geo.box(root, Vector3(0.35, 1.5, 0.04), Vector3(x + s * 0.85, 1.45, d / 2 - 0.05), curtain, false)
		Geo.box(root, Vector3(2.0, 0.03, 0.03), Vector3(x, 2.25, d / 2 - 0.05), PixelMaterials.flat(Color("#c9c9c4")), false)
	# Ceiling lamp and its light.
	PropLibrary.place(root, "ceiling_lamp", Vector3(0, HEIGHT, 0))
	var bulb := OmniLight3D.new()
	bulb.name = "Bulb"
	bulb.position = Vector3(0, HEIGHT - 0.5, 0)
	bulb.light_color = Color("#ffe2b0")
	bulb.light_energy = 1.6
	bulb.omni_range = maxf(w, d) * 1.1
	bulb.shadow_enabled = false
	root.add_child(bulb)
	var fill := OmniLight3D.new()   # soft bounce so corners aren't black
	fill.position = Vector3(0, HEIGHT - 0.3, d / 2 - 0.4)
	fill.light_color = Color("#dfe8ff")
	fill.light_energy = 0.35
	fill.omni_range = maxf(w, d)
	root.add_child(fill)
	return {"size": size, "spawn": Vector3(0, 0.05, d / 2 - 1.1), "exit": Vector3(0, 1.0, d / 2 - 0.45), "windows": windows,
		"seats": [], "stands": []}


static func _window_material() -> StandardMaterial3D:
	var m := PixelMaterials.panel("window_inside").duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.8
	return m


static func _put(root: Node3D, prop: String, pos: Vector3, rot_y := 0.0, paint: Variant = null) -> void:
	PropLibrary.place(root, prop, pos, rot_y, paint)
	if SOLID.has(prop):
		var s: Vector3 = SOLID[prop]
		Geo.collider(root, s, pos + Vector3(0, s.y / 2, 0), rot_y)


static func _picture(root: Node3D, tex: String, size: Vector2, pos: Vector3, rot_y: float) -> void:
	Geo.quad(root, size, pos, PixelMaterials.panel(tex), rot_y)


# ------------------------------------------------------------------ layouts

static func _home(root: Node3D, size: Vector2, spots: Dictionary, seed: int, safehouse: bool, style := "") -> void:
	var w := size.x
	var d := size.y
	var sofa: Color = SOFA_COLOURS[seed % SOFA_COLOURS.size()]
	var lounge_x := -w / 2 + 1.9
	# Lounge: TV against the back wall, couch facing it, coffee table and rug between.
	_put(root, "tv_unit", Vector3(lounge_x, 0, -d / 2 + 0.3))
	_put(root, "couch", Vector3(lounge_x, 0, 0.5), PI, sofa)
	_put(root, "coffee_table", Vector3(lounge_x, 0, -1.0))
	Geo.box(root, Vector3(2.4, 0.012, 1.6), Vector3(lounge_x, 0.006, -0.9), PixelMaterials.panel("rug"), false)
	spots.seats.append({"pos": Vector3(lounge_x - 0.5, 0, 0.5), "yaw": PI})
	spots.seats.append({"pos": Vector3(lounge_x + 0.5, 0, 0.5), "yaw": PI})
	_picture(root, "sign_home", Vector2(1.3, 0.4), Vector3(lounge_x, 2.05, -d / 2 + 0.01), 0.0)
	_picture(root, "frame_family", Vector2(0.72, 0.54), Vector3(-w / 2 + 0.01, 1.6, 0.4), PI / 2)
	_picture(root, "wall_clock", Vector2(0.32, 0.32), Vector3(0.4, 2.05, -d / 2 + 0.01), 0.0)
	_picture(root, "frame_mountain", Vector2(0.8, 0.53), Vector3(-1.5, 1.7, d / 2 - 0.01), PI)
	# Kitchen along the back wall on the right, fridge in the corner.
	var kx := w / 2 - 2.2
	_put(root, "kitchen_counter", Vector3(kx, 0, -d / 2 + 0.31))
	_put(root, "stove", Vector3(kx + 1.55, 0, -d / 2 + 0.31))
	_put(root, "fridge", Vector3(w / 2 - 0.36, 0, -d / 2 + 1.35), -PI / 2)
	_picture(root, "calendar", Vector2(0.3, 0.4), Vector3(w / 2 - 0.01, 1.5, 0.2), -PI / 2)
	spots.windows.append(Geo.quad(root, Vector2(1.1, 0.9), Vector3(kx, 1.7, -d / 2 + 0.01), _window_material(), 0.0))
	spots.stands.append({"pos": Vector3(kx - 0.3, 0, -d / 2 + 1.0), "yaw": PI})
	if safehouse:
		# Your place: the stash and a map of the area on the wall (the bed's next door).
		_put(root, "stash_crate", Vector3(-0.6, 0, -d / 2 + 0.45))
		_picture(root, "poster_map", Vector2(1.1, 0.8), Vector3(-w / 2 + 0.01, 1.6, -1.6), PI / 2)
		spots["stash"] = Vector3(-0.6, 1.0, -d / 2 + 0.9)
	else:
		# A dining table with plastic chairs, and an armchair.
		var tx := w / 2 - 2.2
		_put(root, "dining_table", Vector3(tx, 0, 0.9))
		for c in [[Vector3(tx - 0.85, 0, 0.9), PI / 2], [Vector3(tx + 0.85, 0, 0.9), -PI / 2], [Vector3(tx, 0, 1.6), PI]]:
			PropLibrary.place(root, "plastic_chair", c[0], c[1])
		spots.seats.append({"pos": Vector3(tx - 0.85, 0, 0.9), "yaw": PI / 2})
		_put(root, "armchair", Vector3(-w / 2 + 0.6, 0, -1.6), PI / 2, sofa.lightened(0.15))
		spots.seats.append({"pos": Vector3(-w / 2 + 0.6, 0, -1.6), "yaw": PI / 2})
	if style == "double":
		# A staircase up the front-left wall (the upstairs isn't open).
		var steps := PixelMaterials.flat(Color("#8c6044"))
		for k in 9:
			Geo.box(root, Vector3(0.9, 0.26 * (k + 1), 0.28), Vector3(-w / 2 + 0.5, 0.13 * (k + 1), d / 2 - 0.5 - k * 0.28), steps, false)
		Geo.collider(root, Vector3(0.9, HEIGHT, 2.6), Vector3(-w / 2 + 0.5, HEIGHT / 2, d / 2 - 1.6))
	elif style == "flat":
		_picture(root, "calendar", Vector2(0.3, 0.4), Vector3(-w / 2 + 0.01, 1.5, -0.6), PI / 2)


static func _shebeen(root: Node3D, size: Vector2, spots: Dictionary, seed: int, sign := "sign_shebeen") -> void:
	var w := size.x
	var d := size.y
	_put(root, "bottle_shelf", Vector3(0, 0, -d / 2 + 0.18))
	_put(root, "bar_counter", Vector3(0, 0, -d / 2 + 1.5))
	spots["counter"] = Vector3(0, 1.0, -d / 2 + 2.2)
	spots["host"] = {"pos": Vector3(0.8, 0, -d / 2 + 0.75), "yaw": 0.0}
	_put(root, "crate_stack", Vector3(-w / 2 + 0.7, 0, -d / 2 + 0.35), 0.0, Color("#c0392b"))
	_put(root, "crate_stack", Vector3(w / 2 - 1.2, 0, -d / 2 + 0.35), 0.0, Color("#f2b632"))
	_put(root, "jukebox", Vector3(w / 2 - 0.3, 0, 0.6), -PI / 2, Color("#a63a4c"))
	_put(root, "pool_table", Vector3(-w / 2 + 2.6, 0, 1.0))
	_put(root, "dining_table", Vector3(w / 2 - 2.4, 0, 1.6))
	for c in [[Vector3(w / 2 - 3.25, 0, 1.6), PI / 2], [Vector3(w / 2 - 1.55, 0, 1.6), -PI / 2]]:
		PropLibrary.place(root, "plastic_chair", c[0], c[1])
	spots.seats.append({"pos": Vector3(w / 2 - 3.25, 0, 1.6), "yaw": PI / 2})
	spots.seats.append({"pos": Vector3(w / 2 - 1.55, 0, 1.6), "yaw": -PI / 2})
	spots.stands.append({"pos": Vector3(-w / 2 + 2.6, 0, 2.2), "yaw": PI})       # at the pool table
	spots.stands.append({"pos": Vector3(-1.2, 0, -d / 2 + 2.3), "yaw": PI})      # at the bar
	spots.stands.append({"pos": Vector3(w / 2 - 0.9, 0, -0.4), "yaw": -PI / 2})  # by the jukebox
	_picture(root, "poster_cold", Vector2(0.6, 0.84), Vector3(-w / 2 + 0.01, 1.6, -1.0), PI / 2)
	_picture(root, "poster_soccer", Vector2(0.6, 0.84), Vector3(w / 2 - 0.01, 1.6, 2.0), -PI / 2)
	_picture(root, sign, Vector2(2.0, 0.5), Vector3(0, 2.25, -d / 2 + 0.01), 0.0)
	# Coloured party lights.
	for l in [[Vector3(-3.0, 2.3, 0.5), Color("#ff5a5a")], [Vector3(3.0, 2.3, 0.5), Color("#5aff8a")], [Vector3(0, 2.2, -d / 2 + 1.5), Color("#ffd27a")]]:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = 1.0
		o.omni_range = 6.0
		root.add_child(o)
	(root.get_node("Bulb") as OmniLight3D).light_energy = 0.7


# A crew's den or a rival crew's house: an old couch, TV, crates, their tag on the wall, the stash.
static func _den(root: Node3D, size: Vector2, spots: Dictionary, seed: int, tag: String) -> void:
	var w := size.x
	var d := size.y
	_put(root, "couch", Vector3(-1.2, 0, 0.3), PI, Color("#5a4a3a"))
	_put(root, "tv_unit", Vector3(-1.2, 0, -d / 2 + 0.3))
	_put(root, "crate_stack", Vector3(w / 2 - 0.8, 0, -d / 2 + 0.35), 0.0, Color("#c0392b"))
	_put(root, "stash_crate", Vector3(1.6, 0, -d / 2 + 0.45))
	PropLibrary.place(root, "plastic_chair", Vector3(w / 2 - 0.8, 0, 1.0), -PI / 2)
	spots.seats.append({"pos": Vector3(-1.7, 0, 0.3), "yaw": PI})
	spots.seats.append({"pos": Vector3(-0.7, 0, 0.3), "yaw": PI})
	spots.stands.append({"pos": Vector3(w / 2 - 1.5, 0, 0.4), "yaw": -PI / 2})
	spots["stash"] = Vector3(1.6, 1.0, -d / 2 + 0.9)
	if not tag.is_empty():
		_picture(root, tag, Vector2(2.2, 0.92), Vector3(-w / 2 + 0.01, 1.6, -0.6), PI / 2)
	_picture(root, "poster_soccer", Vector2(0.5, 0.7), Vector3(w / 2 - 0.01, 1.6, -1.2), -PI / 2)


# A SAPS-style community police post: charge office counter, benches, a holding cell.
static func _police(root: Node3D, size: Vector2, spots: Dictionary) -> void:
	var w := size.x
	var d := size.y
	_put(root, "bar_counter", Vector3(-1.5, 0, -d / 2 + 1.5))
	spots["desk"] = Vector3(-1.5, 1.0, -d / 2 + 2.2)
	spots["host"] = {"pos": Vector3(-1.5, 0, -d / 2 + 0.7), "yaw": 0.0}
	Geo.bench(root, Vector3(-w / 2 + 0.5, 0, 0.8), PI / 2, 2.0)
	_picture(root, "police_crest", Vector2(0.6, 0.7), Vector3(-1.5, 2.0, -d / 2 + 0.01), 0.0)
	_picture(root, "calendar", Vector2(0.3, 0.4), Vector3(-w / 2 + 0.01, 1.6, -1.5), PI / 2)
	# Holding cell in the back-right corner: a wall of bars and a bench.
	var bars := PixelMaterials.flat(Color("#565a64"))
	var cx0 := w / 2 - 3.0
	for k in 12:
		Geo.box(root, Vector3(0.04, HEIGHT, 0.04), Vector3(cx0 + k * 0.25, HEIGHT / 2, -0.6), bars, false)
	Geo.collider(root, Vector3(3.0, HEIGHT, 0.1), Vector3(cx0 + 1.5, HEIGHT / 2, -0.6))
	Geo.bench(root, Vector3(w / 2 - 1.5, 0, -d / 2 + 0.5), 0.0, 2.0)
