class_name VehicleDetail
extends RefCounted
## Everything that makes a vehicle look lived-in, added on top of the Blender mesh when
## VehicleLibrary.build() makes one (docs/MITCHELLS_PLAIN_REFERENCE.md: cars here are old,
## repaired and personalised):
##   age     - sun-faded paint, rust at the wheel arches, dents, a mismatched replacement door,
##             bumper stickers (older = more);
##   taxis   - roof sign, side stripe, rear-window slogan, luggage on the roof, a conductor
##             leaning out of the sliding door;
##   bakkies - a canopy or a tied-down load in the bed;
##   moving  - a steering wheel that turns, wipers that sweep in the rain, drops on the
##             windscreen, a glowing dash at night, an exhaust that puffs, dust, brake glow.
## All positions are in the body's "Tilt" space: front = +Z, left = +X, up = +Y. Nothing here has
## a collider. Small details have a visibility range so far-off cars stay cheap.

## w = width, h = half length, belt = window sill height, roof, ws = windscreen [z_bottom,
## y_bottom, z_top, y_top], wb = wheelbase, dash = [z, y] of the dashboard top.
const DIMS := {
	"hatch": {"w": 1.7, "h": 1.95, "belt": 0.86, "roof": 1.42, "ws": [1.15, 0.86, 0.45, 1.38], "wb": 2.45},
	"sedan": {"w": 1.76, "h": 2.2, "belt": 0.84, "roof": 1.4, "ws": [1.1, 0.84, 0.35, 1.38], "wb": 2.65},
	"bakkie": {"w": 1.76, "h": 2.3, "belt": 0.96, "roof": 1.62, "ws": [1.25, 0.96, 0.6, 1.6], "wb": 3.0},
	"police": {"w": 1.84, "h": 2.5, "belt": 0.98, "roof": 1.64, "ws": [1.35, 0.98, 0.7, 1.62], "wb": 3.1},
	"taxi": {"w": 1.9, "h": 2.6, "belt": 1.22, "roof": 1.99, "ws": [2.43, 1.07, 2.0, 1.93], "wb": 3.1},
	"skoro": {"w": 1.68, "h": 2.15, "belt": 0.84, "roof": 1.38, "ws": [1.1, 0.84, 0.42, 1.36], "wb": 2.55},
	"combi": {"w": 1.78, "h": 2.2, "belt": 1.12, "roof": 1.9, "ws": [2.13, 1.13, 1.98, 1.86], "wb": 2.4},
	"panel_van": {"w": 1.85, "h": 2.5, "belt": 1.1, "roof": 2.0, "ws": [2.33, 1.12, 1.77, 1.92], "wb": 3.0},
	"bus": {"w": 2.4, "h": 4.4, "belt": 1.12, "roof": 2.76, "ws": [4.18, 1.14, 4.0, 2.7], "wb": 5.6},
	"refuse": {"w": 2.3, "h": 3.3, "belt": 1.4, "roof": 2.46, "ws": [3.13, 1.32, 2.95, 2.4], "wb": 4.4},
	"scooter": {"w": 0.5, "h": 0.95, "belt": 0.7, "roof": 1.0, "ws": [], "wb": 1.24},
}
const SLOGANS := ["taxi_slogan_a", "taxi_slogan_b"]
const STICKERS := ["sticker_a", "sticker_b", "sticker_c"]
const BAG_COLOURS := [Color("#c0392b"), Color("#2e86c1"), Color("#f2c43a"), Color("#27ae60"), Color("#5a3a22"), Color("#7a6a8a")]

static var _mats: Dictionary = {}


## How worn a vehicle is, 0 (new) to 1 (a wreck on wheels), from its seed and kind.
static func age_for(model: String, seed: int) -> float:
	var base := float(seed % 100) / 100.0
	match model:
		"police":
			return base * 0.25
		"skoro":
			return 0.8 + base * 0.2
		"taxi", "combi", "panel_van":
			return 0.25 + base * 0.6
		"bus", "refuse":
			return 0.3 + base * 0.5
	return base * 0.9


## Paint fades in the sun: older cars go chalky and lose some colour.
static func weathered(color: Color, age: float) -> Color:
	var c := color
	c.s *= 1.0 - age * 0.3
	return c.lerp(Color(0.78, 0.75, 0.7), age * 0.22)


static func _flat(c: Color) -> StandardMaterial3D:
	var key := "f|" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		_mats[key] = m
	return _mats[key]


static func _decal(tex: String) -> StandardMaterial3D:
	var key := "d|" + tex
	if not _mats.has(key):
		var m := PixelMaterials.panel(tex, Color.WHITE, true).duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.alpha_scissor_threshold = 0.0
		_mats[key] = m
	return _mats[key]


static func _quad(tilt: Node3D, tex: String, size: Vector2, pos: Vector3, yaw: float, far := 40.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _decal(tex)
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = far
	tilt.add_child(mi)
	return mi


static func _box(tilt: Node3D, size: Vector3, pos: Vector3, c: Color, far := 50.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = _flat(c)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = far
	tilt.add_child(mi)
	return mi


## Adds all the static detail for `model` to the body (Tilt). `marks` are the Blender markers.
static func dress(pivot: Node3D, tilt: Node3D, model: String, color: Color, seed: int, age: float, marks: Dictionary) -> void:
	var d: Dictionary = DIMS.get(model, {})
	if d.is_empty():
		return
	pivot.set_meta("age", age)
	pivot.set_meta("dims", d)
	if model != "scooter":
		_wear(tilt, d, color, seed, age, model)
		_windscreen(pivot, tilt, d, marks)
		if model != "police":
			_stickers(tilt, d, seed, age, model)
	match model:
		"taxi":
			_taxi(pivot, tilt, d, seed)
		"bakkie":
			_bakkie(tilt, d, color, seed)
		"bus":
			_bus(tilt, d, seed)
	if model != "scooter":
		_exhaust(pivot, tilt, d, age)


## Rust at the arches, dents, a mismatched door: more of each the older the vehicle.
static func _wear(tilt: Node3D, d: Dictionary, color: Color, seed: int, age: float, model: String) -> void:
	var w: float = d.w
	var wb: float = d.wb
	var belt: float = d.belt
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for side in [1.0, -1.0]:
		var yaw: float = PI * 0.5 * side
		if age > 0.3:   # rust blooms at the arches and along the sills
			for z in [wb * 0.5, -wb * 0.5]:
				if rng.randf() < age:
					_quad(tilt, "stain_rust", Vector2(0.38, 0.5), Vector3(side * (w * 0.5 + 0.008), 0.42, z + rng.randf_range(-0.1, 0.1)), yaw)
		if age > 0.4:   # dents in the doors
			for k in int(age * 3.0):
				_quad(tilt, "dent", Vector2(0.55, 0.42), Vector3(side * (w * 0.5 + 0.009), belt - 0.2 - rng.randf() * 0.15, rng.randf_range(-0.7, 0.9)), yaw)
	if age > 0.55 and seed % 3 == 0 and model not in ["police", "bus", "refuse"]:   # one door from a different car
		var side: float = 1.0 if seed % 2 == 0 else -1.0
		var odd := color.lightened(0.18) if seed % 4 < 2 else color.darkened(0.25)
		odd.h = fposmod(odd.h + 0.07, 1.0)
		_box(tilt, Vector3(0.016, 0.52, 0.95), Vector3(side * (w * 0.5 + 0.009), belt - 0.34, 0.05), odd, 45.0)


static func _stickers(tilt: Node3D, d: Dictionary, seed: int, age: float, model: String) -> void:
	var h: float = d.h
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 7
	var count := 1 + int(age * 2.0) + (1 if model == "taxi" else 0)
	for k in count:
		_quad(tilt, STICKERS[rng.randi() % STICKERS.size()], Vector2(0.28, 0.12),
			Vector3(rng.randf_range(-0.55, 0.55), 0.55 + rng.randf() * 0.2, -h - 0.012), PI, 30.0)


## Windscreen drops (shown in rain) and the dash glow (at night); the materials are shared, so
## VehicleLibrary just changes two numbers.
static func _windscreen(pivot: Node3D, tilt: Node3D, d: Dictionary, marks: Dictionary) -> void:
	var ws: Array = d.ws
	if ws.size() == 4:
		var dz: float = float(ws[0]) - float(ws[2])
		var dy: float = float(ws[3]) - float(ws[1])
		var l := Vector2(dz, dy).length()
		var n := Vector3(0, dz, dy) / l
		var q := QuadMesh.new()
		q.size = Vector2(float(d.w) - 0.3, l)
		var mi := MeshInstance3D.new()
		mi.name = "ScreenDrops"
		mi.mesh = q
		mi.material_override = VehicleLibrary.drops_material()
		mi.position = Vector3(0, (float(ws[1]) + float(ws[3])) * 0.5, (float(ws[0]) + float(ws[2])) * 0.5) + n * 0.012
		mi.rotation.x = -atan2(dz, dy)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 30.0
		tilt.add_child(mi)
	if marks.has("dash"):
		var dp: Vector3 = marks.dash
		var plane := PlaneMesh.new()
		plane.size = Vector2(float(d.w) - 0.45, 0.22)
		var glow := MeshInstance3D.new()
		glow.name = "DashGlow"
		glow.mesh = plane
		glow.material_override = VehicleLibrary.dash_material()
		glow.position = Vector3(0, dp.y + 0.075, dp.z - 0.03)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visibility_range_end = 25.0
		tilt.add_child(glow)
	if marks.has("steer"):   # the steering wheel (the driver's right): a ring that turns
		var sp: Vector3 = marks.steer
		var holder := Node3D.new()
		holder.name = "SteerHolder"
		holder.position = sp
		holder.rotation.x = 1.15
		tilt.add_child(holder)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.14
		torus.outer_radius = 0.18
		torus.rings = 16
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = _flat(Color("#1d1e22"))
		ring.visibility_range_end = 25.0
		holder.add_child(ring)
		pivot.set_meta("steer_ring", ring)
	var wipers: Array = []
	for wp: Vector3 in marks.get("wipers", []):
		var piv := Node3D.new()
		piv.position = wp + Vector3(0, 0.02, 0)
		piv.rotation.x = -atan2(float(d.ws[0]) - float(d.ws[2]), float(d.ws[3]) - float(d.ws[1])) if d.ws.size() == 4 else 0.0
		tilt.add_child(piv)
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.016, 0.014)
		blade.mesh = bm
		blade.material_override = _flat(Color("#16161a"))
		blade.position = Vector3(0.25, 0, 0)
		blade.visibility_range_end = 25.0
		piv.add_child(blade)
		wipers.append(piv)
	pivot.set_meta("wipers", wipers)


## Puffs from the exhaust when pulling away; old engines smoke more.
static func _exhaust(pivot: Node3D, tilt: Node3D, d: Dictionary, age: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "Exhaust"
	p.position = Vector3(-0.5 * float(d.w) * 0.6, 0.3, -float(d.h) - 0.1)
	p.amount = 10
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	p.direction = Vector3(0, 0.25, -1)
	p.spread = 14.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.25, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = grow
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	var fade := Gradient.new()
	var tone := lerpf(0.75, 0.25, age)
	fade.set_color(0, Color(tone, tone, tone, 0.5))
	fade.set_color(1, Color(tone, tone, tone, 0.0))
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _puff_texture()
	quad.material = mat
	p.mesh = quad
	p.local_coords = false
	p.emitting = false
	p.visibility_range_end = 45.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tilt.add_child(p)
	pivot.set_meta("exhaust", p)


static var _puff: ImageTexture


static func _puff_texture() -> ImageTexture:
	if _puff == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var r := Vector2(x - 7.5, y - 7.5).length() / 7.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - r, 0.0, 1.0)))
		_puff = ImageTexture.create_from_image(img)
	return _puff


## The minibus taxi: roof sign, a yellow side stripe, a slogan across the rear window, bags and
## a mattress strapped to the roof, a conductor hanging out of the sliding door.
static func _taxi(pivot: Node3D, tilt: Node3D, d: Dictionary, seed: int) -> void:
	var w: float = d.w
	var roof: float = d.roof
	var h: float = d.h
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 3
	_box(tilt, Vector3(0.7, 0.2, 0.28), Vector3(0, roof + 0.14, 0.9), Color("#1d1e22"), 80.0)
	for zf in [1.0, -1.0]:
		_quad(tilt, "sign_taxi", Vector2(0.5, 0.18), Vector3(0, roof + 0.14, 0.9 + zf * 0.142), 0.0 if zf > 0.0 else PI, 80.0)
	for side in [1.0, -1.0]:   # the stripe (the taxi association's colours) and a number
		_box(tilt, Vector3(0.014, 0.13, h * 1.7), Vector3(side * (w * 0.5 + 0.007), d.belt - 0.5, -0.1), Color("#f2c43a"), 80.0)
		_box(tilt, Vector3(0.016, 0.04, h * 1.7), Vector3(side * (w * 0.5 + 0.008), d.belt - 0.6, -0.1), Color("#1d1e22"), 80.0)
	var num := Label3D.new()
	num.text = "No. %d" % (10 + seed % 80)
	num.font_size = 40
	num.pixel_size = 0.004
	num.modulate = Color("#1d1e22")
	num.position = Vector3(w * 0.5 + 0.02, d.belt - 0.2, 1.7)
	num.rotation.y = PI * 0.5
	num.visibility_range_end = 25.0
	tilt.add_child(num)
	_quad(tilt, SLOGANS[seed % SLOGANS.size()], Vector2(1.3, 0.26), Vector3(0, roof - 0.42, -h - 0.014), PI, 35.0)
	# Luggage on a roof rack.
	if seed % 3 != 0:
		_box(tilt, Vector3(1.5, 0.03, 1.6), Vector3(0, roof + 0.03, -0.9), Color("#565a64"), 60.0)
		for k in 2 + seed % 3:
			var s := Vector3(rng.randf_range(0.45, 0.8), rng.randf_range(0.25, 0.4), rng.randf_range(0.4, 0.7))
			_box(tilt, s, Vector3(rng.randf_range(-0.35, 0.35), roof + 0.06 + s.y * 0.5, -0.5 - k * 0.5), BAG_COLOURS[rng.randi() % BAG_COLOURS.size()], 60.0)
		if seed % 5 == 0:   # a mattress, tied down
			_box(tilt, Vector3(1.2, 0.18, 1.9), Vector3(0, roof + 0.14, -0.9), Color("#e8e2d0"), 60.0)
			_box(tilt, Vector3(1.24, 0.2, 0.05), Vector3(0, roof + 0.14, -0.4), Color("#c0392b"), 60.0)
	# The conductor, leaning out of the sliding door with a hand up to tap the roof.
	var occ: Mesh = VehicleLibrary.mesh("occupant_passenger")
	if occ:
		var c := MeshInstance3D.new()
		c.name = "Conductor"
		c.mesh = occ
		c.position = Vector3(w * 0.5 - 0.1, d.belt - 0.25, 0.35)
		c.rotation.z = -0.4
		c.rotation.y = -PI * 0.5
		c.visibility_range_end = 35.0
		tilt.add_child(c)
		pivot.set_meta("conductor", c)
		VehicleLibrary.dress_occupant(c, seed + 11, Color("#c9d6e6"))
		var arm := _box(tilt, Vector3(0.07, 0.07, 0.5), Vector3(w * 0.5 + 0.28, d.belt + 0.28, 0.25), Color("#8d5a3b"), 30.0)
		arm.rotation = Vector3(0, 0.3, 0.9)


## An open bakkie carries a canopy (a third of them) or a tied-down load.
static func _bakkie(tilt: Node3D, d: Dictionary, color: Color, seed: int) -> void:
	var w: float = d.w
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 5
	var floor_y := 0.98
	var roll := seed % 100
	if roll < 33:
		_box(tilt, Vector3(w - 0.1, 0.72, 2.15), Vector3(0, floor_y + 0.38, -1.17), color.darkened(0.12), 70.0)
		for side in [1.0, -1.0]:
			_box(tilt, Vector3(0.012, 0.3, 1.3), Vector3(side * (w * 0.5 - 0.04), floor_y + 0.42, -1.17), Color("#1b232c"), 40.0)
	elif roll < 75:
		for k in 3 + seed % 3:
			var s := Vector3(rng.randf_range(0.45, 0.8), rng.randf_range(0.3, 0.55), rng.randf_range(0.4, 0.7))
			_box(tilt, s, Vector3(rng.randf_range(-0.4, 0.4), floor_y + s.y * 0.5, -0.55 - k * 0.42), BAG_COLOURS[rng.randi() % BAG_COLOURS.size()], 60.0)
		_box(tilt, Vector3(w - 0.2, 0.03, 0.06), Vector3(0, floor_y + 0.62, -1.0), Color("#c9a26b"), 40.0)   # the rope


static func _bus(tilt: Node3D, d: Dictionary, seed: int) -> void:
	var h: float = d.h
	_box(tilt, Vector3(0.9, 0.22, 0.04), Vector3(0, d.roof - 0.4, h - 0.12), Color("#14181c"), 60.0)   # route board over the windscreen
	var board := Label3D.new()
	board.text = "TOWN CENTRE" if seed % 2 == 0 else "TAFELSIG"
	board.font_size = 36
	board.pixel_size = 0.0035
	board.modulate = Color("#f2c43a")
	board.position = Vector3(0, d.roof - 0.4, h - 0.098)
	board.visibility_range_end = 35.0
	tilt.add_child(board)


## Things only a vehicle that drives needs: dust thrown up on dry days and a red glow on the road
## behind it when it brakes at night or on wet ground.
static func add_motion_fx(pivot: Node3D, model: String) -> void:
	var d: Dictionary = pivot.get_meta("dims", {})
	if d.is_empty() or not pivot.has_meta("tilt"):
		return
	var tilt: Node3D = pivot.get_meta("tilt")
	var dust := CPUParticles3D.new()
	dust.name = "DustFx"
	dust.position = Vector3(0, 0.15, -float(d.h) * 0.6)
	dust.amount = 16
	dust.lifetime = 1.4
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(float(d.w) * 0.45, 0.05, 0.2)
	dust.direction = Vector3(0, 0.3, -1)
	dust.spread = 25.0
	dust.initial_velocity_min = 0.8
	dust.initial_velocity_max = 2.0
	dust.gravity = Vector3(0, 0.15, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.4))
	dust.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.82, 0.72, 0.55, 0.45))
	fade.set_color(1, Color(0.82, 0.72, 0.55, 0.0))
	dust.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _puff_texture()
	quad.material = mat
	dust.mesh = quad
	dust.local_coords = false
	dust.emitting = false
	dust.visibility_range_end = 50.0
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tilt.add_child(dust)
	pivot.set_meta("dust_fx", dust)
	if model == "scooter":
		return
	if VehicleLibrary._brake_glow_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.15, 0.1, 0.6))
		g.set_color(1, Color(1.0, 0.15, 0.1, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.albedo_texture = tex
		VehicleLibrary._brake_glow_mat = gm
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(d.w) * 1.4, 1.6)
	var glow := MeshInstance3D.new()
	glow.name = "BrakeGlow"
	glow.mesh = plane
	glow.material_override = VehicleLibrary._brake_glow_mat
	glow.position = Vector3(0, 0.03, -float(d.h) - 0.7)
	glow.visible = false
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.visibility_range_end = 45.0
	tilt.add_child(glow)
	pivot.set_meta("brake_glow", glow)
