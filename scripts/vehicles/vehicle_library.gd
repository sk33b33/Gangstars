class_name VehicleLibrary
extends RefCounted
## Vehicle meshes from tools/blender/build_vehicles.py (vehicles.glb), by model name:
## hatch, sedan, bakkie, taxi, police, skoro, combi, panel_van. build() returns a pivot whose model faces local +X (the
## convention the traffic, parking and driving code already uses). "paint" takes the car's colour,
## "headlight" shares the night-glow lamp material, and police "lightbar" surfaces get their own
## material per vehicle so its lights can flash (see set_lights()).

const SOURCE := "res://assets/models/vehicles/vehicles.glb"
const MODELS := ["hatch", "sedan", "bakkie", "taxi", "police", "skoro", "combi", "panel_van", "bus", "refuse", "scooter"]
const CIVILIAN := ["hatch", "hatch", "sedan", "bakkie", "skoro", "combi", "panel_van"]   # weighted pick for everyday cars
## Length of each model (m), for colliders and obstacles.
const LENGTH := {"hatch": 4.0, "sedan": 4.5, "bakkie": 4.7, "taxi": 5.3, "police": 5.1, "skoro": 4.4, "combi": 4.5, "panel_van": 5.1, "bus": 8.8, "refuse": 6.6, "scooter": 1.9}
## Colours for the skorokoro's odd door and primer patches, and for occupants.
const ODD_PANELS := [Color("#8f949a"), Color("#c9c2b4"), Color("#2e6a8f"), Color("#7a2420"), Color("#e8e2d0")]
const SHIRTS := [Color("#f1eee8"), Color("#2c3e50"), Color("#a63a4c"), Color("#27ae60"), Color("#f2b632"), Color("#5dade2"), Color("#1d1b24")]
const SKINS := [Color("#6b4430"), Color("#8d5a3b"), Color("#a7754f"), Color("#4a2f22"), Color("#c58c62")]

static var _meshes: Dictionary = {}
static var _markers: Dictionary = {}   # model -> {"wheels": [Vector3], "plate_front": Vector3, "plate_rear": Vector3}
## 0 by day, 1 at night; DayNight sets it. Moving cars switch their headlight beams on at night.
static var night := 0.0
## Set by Weather/DayNight: 0..1 rain, haze (dust, wet air: beams show in it), wet ground, dust.
static var rain := 0.0
static var haze := 0.0
static var wet := 0.0
static var dust := 0.0
static var _drops_mat: StandardMaterial3D
static var _dash_mat: StandardMaterial3D
static var _brake_glow_mat: StandardMaterial3D
static var _skid_mat: StandardMaterial3D
static var _skids: Array = []
static var _skid_next := 0
static var _glass: StandardMaterial3D
static var _tint: StandardMaterial3D


static func mesh(model: String) -> Mesh:
	_load()
	return _meshes.get(model)


static func _load() -> void:
	if not _meshes.is_empty():
		return
	var root: Node = (load(SOURCE) as PackedScene).instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		_meshes[str(mi.name)] = (mi as MeshInstance3D).mesh
	# Marker empties under each body: <model>_axle_0..3 (front pair first), <model>_plate_*.
	for model in MODELS:
		var body := root.find_child(model, true, false) as Node3D
		var m := {"wheels": [], "seats": [], "wipers": []}
		if body:
			for c in body.get_children():
				var n := str(c.name)
				if n == model + "_steer" or n == model + "_dash":
					m[n.trim_prefix(model + "_")] = (c as Node3D).position
				elif n.begins_with(model + "_wiper_"):
					m.wipers.append((c as Node3D).position)
				elif n.begins_with(model + "_axle_"):
					m.wheels.append([n, (c as Node3D).position])
				elif n.begins_with(model + "_seat_"):
					m.seats.append([n, (c as Node3D).position])
				elif n.begins_with(model + "_plate_"):
					m[n.trim_prefix(model + "_")] = (c as Node3D).position
		m.wheels.sort_custom(func(a, b): return a[0] < b[0])
		m.wheels = m.wheels.map(func(w): return w[1])
		m.seats.sort_custom(func(a, b): return a[0] < b[0])
		m.seats = m.seats.map(func(w): return w[1])
		_markers[model] = m
	root.free()


## A civilian model picked deterministically from a seed (e.g. a vehicle id).
static func civilian_for(seed_text: String) -> String:
	return CIVILIAN[absi(seed_text.hash()) % CIVILIAN.size()]


## The vehicle: pivot (faces +X) > Tilt (body, pitches on the suspension) + Wheels (spin, front
## pair steers). Per-vehicle materials for paint, brake lights and indicators; a made-up Cape
## number plate. animate() drives it; add_headlights() gives moving cars night beams.
static func build(root: Node3D, model: String, color: Color, center := Vector3.ZERO, rot_y := 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Body_" + model
	pivot.position = center
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	var m := mesh(model)
	if m == null:
		push_warning("Unknown vehicle model: " + model)
		return pivot
	var seed := absi(("%s|%s|%s" % [model, color, center]).hash())
	var age := VehicleDetail.age_for(model, seed)
	if model not in ["police", "taxi", "bus", "refuse"]:
		color = VehicleDetail.weathered(color, age)
	# Some cars are dusty from the roads; the skorokoro always is.
	var dirty := model == "skoro" or seed % 20 < 7
	pivot.set_meta("model", model)
	pivot.set_meta("seed", seed)
	var tilt := Node3D.new()
	tilt.name = "Tilt"
	tilt.rotation.y = PI * 0.5   # Blender front (-Y) -> Godot +Z -> rotate to +X
	pivot.add_child(tilt)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = m
	tilt.add_child(mi)
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		var key := mat.resource_name if mat else ""
		match key:
			"paint":
				var paint := StandardMaterial3D.new()
				paint.albedo_color = Color.WHITE if model == "police" else color
				paint.metallic = 0.35
				paint.roughness = 0.3
				paint.clearcoat_enabled = true
				paint.clearcoat = 0.8
				paint.clearcoat_roughness = 0.12
				if dirty:   # road grime (vertex colours) and a duller finish
					paint.vertex_color_use_as_albedo = true
					paint.roughness = 0.55 if model != "skoro" else 0.8
					paint.clearcoat = 0.2 if model != "skoro" else 0.0
				mi.set_surface_override_material(i, paint)
			"paint2":
				var odd := StandardMaterial3D.new()
				odd.albedo_color = ODD_PANELS[seed % ODD_PANELS.size()]
				odd.roughness = 0.75
				odd.vertex_color_use_as_albedo = dirty
				mi.set_surface_override_material(i, odd)
			"glass":
				mi.set_surface_override_material(i, glass())
			"tint":
				mi.set_surface_override_material(i, tint())
			"white", "sign_panel":
				var white := StandardMaterial3D.new()
				white.albedo_color = Color("#f2f0ea")
				white.roughness = 0.4 if key == "white" else 0.6
				white.vertex_color_use_as_albedo = dirty
				mi.set_surface_override_material(i, white)
			"headlight":
				mi.set_surface_override_material(i, PixelMaterials.lamp())
			"taillight":
				var tail := _glow(Color("#b0202a"), Color("#ff2a2a"))
				mi.set_surface_override_material(i, tail)
				pivot.set_meta("taillight", tail)
			"indicator_L", "indicator_R":
				var ind := _glow(Color("#e8901c"), Color("#ffa024"))
				mi.set_surface_override_material(i, ind)
				pivot.set_meta(key, ind)
			"lightbar":
				var bar := _glow(Color("#2a6cff"), Color("#2a6cff"))
				mi.set_surface_override_material(i, bar)
				pivot.set_meta("lightbar", bar)
	var marks: Dictionary = _markers.get(model, {})
	var wheel_mesh: Mesh = _meshes.get(model + "_tyre")
	var wheels: Array = []
	if wheel_mesh and marks.has("wheels"):
		var set := Node3D.new()
		set.name = "Wheels"
		set.rotation.y = PI * 0.5
		pivot.add_child(set)
		for k in marks.wheels.size():
			var w := MeshInstance3D.new()
			w.name = "Wheel%d" % k
			w.mesh = wheel_mesh
			w.position = marks.wheels[k]
			w.visibility_range_end = 90.0
			# The mesh's rim faces +X: wheels on the -X side are turned round.
			w.set_meta("flip", 0.0 if w.position.x > 0.0 else PI)
			w.set_meta("front", k < marks.wheels.size() / 2)
			w.rotation.y = w.get_meta("flip")
			set.add_child(w)
			wheels.append(w)
		pivot.set_meta("wheels", wheels)
		pivot.set_meta("wheel_radius", absf(float(marks.wheels[0].y)))
	var plate := "CA %03d-%03d" % [absi(("%s%s%s" % [model, color, center]).hash()) % 1000, absi(("%s%s" % [center, model]).hash()) % 1000]
	for end in ["plate_front", "plate_rear"]:
		if marks.has(end):
			var l := Label3D.new()
			l.text = plate
			l.font_size = 48
			l.pixel_size = 0.0014
			l.outline_size = 0
			l.modulate = Color("#16161a")
			l.double_sided = false
			var front: bool = end == "plate_front"
			l.position = marks[end] + Vector3(0, 0, 0.004 if front else -0.004)
			l.rotation.y = 0.0 if front else PI
			l.visibility_range_end = 25.0
			tilt.add_child(l)
	pivot.set_meta("tilt", tilt)
	if model == "police":
		_police_markings(pivot)
	elif model == "panel_van":
		_bakery_panels(tilt)
	VehicleDetail.dress(pivot, tilt, model, color, seed, age, marks)
	return pivot


## Shared "rain on the glass" material: its alpha follows the rain.
static func drops_material() -> StandardMaterial3D:
	if _drops_mat == null:
		_drops_mat = PixelMaterials.panel("rain_drops", Color.WHITE, true).duplicate() as StandardMaterial3D
		_drops_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_drops_mat.albedo_color = Color(1, 1, 1, 0)
	return _drops_mat


## Shared dashboard glow (amber instruments): emission follows the night.
static func dash_material() -> StandardMaterial3D:
	if _dash_mat == null:
		_dash_mat = StandardMaterial3D.new()
		_dash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dash_mat.albedo_color = Color(1.0, 0.62, 0.2, 0.0)
		_dash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _dash_mat


static func dress_occupant(mi: MeshInstance3D, seed: int, shirt: Color) -> void:
	_dress(mi, shirt, SKINS[seed % SKINS.size()], Color("#1d1b24"))


## The made-up bakery's painted side panels on the delivery van (Tilt space: front is -Z... the
## model's Blender -Y, so the van's length runs along Tilt's Z and its sides face +-X).
static func _bakery_panels(tilt: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.8, 0.95)
	var mat := PixelMaterials.panel("van_bakery", Color.WHITE, false)
	for side in [1.0, -1.0]:
		var mi := MeshInstance3D.new()
		mi.name = "BakeryPanel%s" % ("L" if side > 0 else "R")
		mi.mesh = quad
		mi.material_override = mat
		mi.visibility_range_end = 60.0
		mi.position = Vector3(side * 0.94, 1.35, -0.7)
		mi.rotation.y = side * PI * 0.5
		tilt.add_child(mi)


## See-through, reflective glass (cabins have interiors behind it).
static func glass() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color(0.1, 0.14, 0.19, 0.55)
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.metallic = 0.6
		_glass.roughness = 0.05
		_glass.metallic_specular = 0.9
	return _glass


## Dark tinted glass (taxi and canopy windows: there is solid body behind them).
static func tint() -> StandardMaterial3D:
	if _tint == null:
		_tint = StandardMaterial3D.new()
		_tint.albedo_color = Color("#1b2633")
		_tint.metallic = 0.8
		_tint.roughness = 0.06
		_tint.clearcoat_enabled = true
		_tint.clearcoat_roughness = 0.0
	return _tint


## People in the car: a driver (and, by seed, passengers) seen through the windows.
## Police cars carry two officers. Parked cars stay empty.
static func add_occupants(pivot: Node3D, passengers := -1) -> void:
	var model: String = pivot.get_meta("model", "")
	var seats: Array = _markers.get(model, {}).get("seats", [])
	if seats.is_empty() or not pivot.has_meta("tilt"):
		return
	var seed: int = pivot.get_meta("seed", 0)
	var count: int = 1 + (passengers if passengers >= 0 else (1 if model == "police" else (4 + seed % 6 if model == "taxi" else [0, 0, 1, 2][seed / 7 % 4])))
	var people: Array = []
	for k in mini(count, seats.size()):
		var mi := MeshInstance3D.new()
		mi.name = "Occupant%d" % k
		mi.mesh = _meshes.get("occupant_driver" if k == 0 else "occupant_passenger")
		mi.position = seats[k]
		mi.visibility_range_end = 45.0
		var s := seed / (k + 3)
		var shirt: Color = Color("#9db4d6") if model == "police" else SHIRTS[s % SHIRTS.size()]
		_dress(mi, shirt, SKINS[(s / 5) % SKINS.size()], Color("#1d1b24") if s % 4 else Color("#a7a39a"))
		(pivot.get_meta("tilt") as Node3D).add_child(mi)
		people.append(mi)
	pivot.set_meta("occupants", people)


## The player at the wheel of a drivable car (shown while they drive).
static func set_driver(pivot: Node3D, on: bool, shirt := Color("#f1eee8")) -> void:
	if not pivot.has_meta("occupants"):
		add_occupants(pivot, 0)
	for mi: MeshInstance3D in pivot.get_meta("occupants", []):
		if on:
			_dress(mi, shirt, Color("#8d5a3b"), Color("#1d1b24"))
		mi.visible = on


static func _dress(mi: MeshInstance3D, shirt: Color, skin: Color, hair: Color) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		match m.resource_name if m else "":
			"occ_shirt":
				mi.set_surface_override_material(i, PixelMaterials.cloth(shirt))
			"occ_skin":
				mi.set_surface_override_material(i, PixelMaterials.skin(skin))
			"occ_hair":
				mi.set_surface_override_material(i, PixelMaterials.cloth(hair))


static func _glow(albedo: Color, glow: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = 0.0
	return mat


## Per-frame look of a moving vehicle. speed in m/s (negative = reversing), steer -1..1
## (+ = left), accel in m/s² (braking is negative), indicate -1 left / 0 / 1 right.
static func animate(pivot: Node3D, speed: float, steer: float, accel: float, indicate: int, delta: float, time: float) -> void:
	if pivot == null or not pivot.has_meta("tilt"):
		return
	var r: float = pivot.get_meta("wheel_radius", 0.32)
	var spin: float = float(pivot.get_meta("spin", 0.0)) + speed / r * delta
	pivot.set_meta("spin", fmod(spin, TAU))
	for w: MeshInstance3D in pivot.get_meta("wheels", []):
		var flip: float = w.get_meta("flip")
		var yaw := flip + (steer * 0.5 if w.get_meta("front") else 0.0)
		w.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, spin if flip == 0.0 else -spin)
	# Suspension: the nose dips under braking and lifts when pulling away, with a little roll.
	var tilt: Node3D = pivot.get_meta("tilt")
	var pitch := clampf(-accel * 0.007, -0.03, 0.03)
	var roll := clampf(steer * absf(speed) * 0.002, -0.025, 0.025)
	tilt.rotation.x = lerpf(tilt.rotation.x, pitch, clampf(delta * 6.0, 0.0, 1.0))
	tilt.rotation.z = lerpf(tilt.rotation.z, -roll, clampf(delta * 6.0, 0.0, 1.0))
	var tail: StandardMaterial3D = pivot.get_meta("taillight", null)
	if tail:
		var braking := accel < -0.5 or (absf(speed) < 0.3 and accel < 0.0)
		tail.emission_energy_multiplier = 3.0 if braking else night * 1.2
	var blink := fmod(time, 0.8) < 0.4
	for side in ["indicator_L", "indicator_R"]:
		var ind: StandardMaterial3D = pivot.get_meta(side, null)
		if ind:
			var on: bool = blink and ((indicate < 0 and side == "indicator_L") or (indicate > 0 and side == "indicator_R"))
			ind.emission_energy_multiplier = 4.0 if on else 0.0
	var beams: Array = pivot.get_meta("beams", [])
	for b: SpotLight3D in beams:
		b.visible = night > 0.4
		b.light_volumetric_fog_energy = clampf(haze * 2.2 + rain * 1.2, 0.0, 3.0)   # beams show in dust and rain
	_animate_detail(pivot, speed, steer, accel, delta, time)


## The moving parts of the detail: steering wheel, wipers, glass drops, dash glow, exhaust, dust,
## brake glow on the road, skid marks.
static func _animate_detail(pivot: Node3D, speed: float, steer: float, accel: float, delta: float, time: float) -> void:
	_drops_mat_update()
	var ring: Node3D = pivot.get_meta("steer_ring", null)
	if ring:
		ring.rotation.y = lerpf(ring.rotation.y, -steer * 1.4, clampf(delta * 8.0, 0.0, 1.0))
	var wipers: Array = pivot.get_meta("wipers", [])
	var sweeping := rain > 0.35
	for i in wipers.size():
		var piv: Node3D = wipers[i]
		var target := (0.5 - 0.5 * cos(time * 5.0 + i * 0.3)) * 1.25 if sweeping else 0.0
		piv.rotation.z = lerpf(piv.rotation.z, target, clampf(delta * 14.0, 0.0, 1.0))
	var tilt: Node3D = pivot.get_meta("tilt")
	var ex: CPUParticles3D = pivot.get_meta("exhaust", null)
	if ex:
		var age: float = pivot.get_meta("age", 0.3)
		ex.emitting = (accel > 0.7 and speed > 0.2) or (age > 0.7 and speed > 0.3 and fmod(time, 3.0) < 0.5)
	var dust_fx: CPUParticles3D = pivot.get_meta("dust_fx", null)
	if dust_fx:
		dust_fx.emitting = dust > 0.25 and speed > 5.0
	var glow: MeshInstance3D = pivot.get_meta("brake_glow", null)
	if glow:
		glow.visible = (accel < -0.5 or (absf(speed) < 0.3 and accel < 0.0)) and (night > 0.35 or wet > 0.3)
	if accel < -6.0 and speed > 5.0:
		_skid(pivot)


static func _drops_mat_update() -> void:
	if _drops_mat:
		_drops_mat.albedo_color.a = clampf((rain - 0.3) / 0.5, 0.0, 1.0)
	if _dash_mat:
		_dash_mat.albedo_color.a = clampf(night * 0.9, 0.0, 0.9)


## Two dark streaks on the road behind the rear wheels; they fade over about half a minute.
static func _skid(pivot: Node3D) -> void:
	var last: float = pivot.get_meta("last_skid", -10.0)
	var now := Time.get_ticks_msec() / 1000.0
	if now - last < 0.35 or not pivot.is_inside_tree():
		return
	pivot.set_meta("last_skid", now)
	if _skid_mat == null:
		_skid_mat = PixelMaterials.panel("skid_mark", Color.WHITE, true).duplicate() as StandardMaterial3D
		_skid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dims: Dictionary = pivot.get_meta("dims", {})
	var back: float = float(dims.get("h", 2.0)) * 0.7
	var f := pivot.global_basis.x
	f.y = 0.0
	f = f.normalized()
	var mark: MeshInstance3D
	if _skids.size() < 36:
		mark = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(float(dims.get("w", 1.7)) * 0.75, 1.8)
		mark.mesh = plane
		mark.material_override = _skid_mat
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.visibility_range_end = 70.0
		pivot.get_tree().root.add_child(mark)
		_skids.append(mark)
	else:
		mark = _skids[_skid_next]
		_skid_next = (_skid_next + 1) % _skids.size()
	if not is_instance_valid(mark):
		_skids.clear()
		return
	mark.global_position = pivot.global_position - f * back + Vector3(0, 0.02, 0)
	mark.rotation = Vector3(0, atan2(f.x, f.z), 0)
	mark.transparency = 0.0
	mark.visible = true
	var tw := mark.create_tween()
	tw.tween_property(mark, "transparency", 1.0, 28.0)


## Impact: dents, then (hard hits) a cracked windscreen. `strength` roughly 0..3 per knock.
static func hit(pivot: Node3D, strength: float) -> void:
	if not pivot.has_meta("tilt") or strength < 0.3:
		return
	var tilt: Node3D = pivot.get_meta("tilt")
	var dims: Dictionary = pivot.get_meta("dims", {})
	if dims.is_empty():
		return
	var dmg: float = float(pivot.get_meta("damage", 0.0)) + strength
	pivot.set_meta("damage", dmg)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(dmg * 1000.0) + hash(pivot.name)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	if rng.randf() < 0.4:   # front or rear
		var z := (float(dims.h) + 0.01) * (1.0 if rng.randf() < 0.5 else -1.0)
		VehicleDetail._quad(tilt, "dent", Vector2(0.9, 0.5), Vector3(rng.randf_range(-0.4, 0.4), 0.6, z), 0.0 if z > 0.0 else PI, 60.0)
	else:
		VehicleDetail._quad(tilt, "dent", Vector2(0.8, 0.55), Vector3(side * (float(dims.w) * 0.5 + 0.01), float(dims.belt) - 0.25, rng.randf_range(-1.0, 1.0)), PI * 0.5 * side, 60.0)
	if dmg >= 2.0 and not pivot.has_meta("cracked") and dims.ws.size() == 4:
		pivot.set_meta("cracked", true)
		var ws: Array = dims.ws
		var dz: float = float(ws[0]) - float(ws[2])
		var dy: float = float(ws[3]) - float(ws[1])
		var l := Vector2(dz, dy).length()
		var crack := VehicleDetail._quad(tilt, "crack_a", Vector2(0.9, 0.7), Vector3(0.25, (float(ws[1]) + float(ws[3])) * 0.5, (float(ws[0]) + float(ws[2])) * 0.5) + Vector3(0, dz, dy) / l * 0.014, 0.0, 40.0)
		crack.rotation.x = -atan2(dz, dy)


## Parked cars aren't all alike: some under a cover, some on bricks without their wheels, some with
## a flat tyre. Deterministic from the car; only for cars that stand still.
static func dress_parked(pivot: Node3D) -> void:
	if not pivot.has_meta("tilt"):
		return
	var model: String = pivot.get_meta("model", "")
	var dims: Dictionary = pivot.get_meta("dims", {})
	if dims.is_empty() or model in ["police", "taxi", "bus", "refuse", "scooter"]:
		return
	var tilt: Node3D = pivot.get_meta("tilt")
	var seed: int = int(pivot.get_meta("seed", 0))
	var roll := (seed / 13) % 100
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if roll < 12:   # a cover
		var cover := Color(["#9aa3ab", "#8a7f6a", "#6a7f94"][seed % 3])
		VehicleDetail._box(tilt, Vector3(float(dims.w) + 0.08, 0.9, float(dims.h) * 2.0 - 0.3), Vector3(0, float(dims.belt) * 0.75 + 0.2, 0), cover, 70.0)
		VehicleDetail._box(tilt, Vector3(float(dims.w) - 0.35, 0.5, float(dims.h) * 1.1), Vector3(0, float(dims.belt) + 0.55, -0.1), cover, 70.0)
	elif roll < 20:   # on bricks, wheels off
		var wheels_node: Node3D = pivot.get_node_or_null("Wheels")
		if wheels_node:
			wheels_node.visible = false
		tilt.position.y += 0.3
		var brick := Color("#a8553a")
		for sx in [1.0, -1.0]:
			for sz in [1.0, -1.0]:
				VehicleDetail._box(pivot, Vector3(0.4, 0.3, 0.4), Vector3(sz * float(dims.wb) * 0.5, 0.15, sx * float(dims.w) * 0.36), brick, 60.0)
	elif roll < 32:   # a flat tyre
		var ws: Array = pivot.get_meta("wheels", [])
		if not ws.is_empty():
			var flat: MeshInstance3D = ws[rng.randi() % ws.size()]
			flat.scale.y = 0.72
			flat.position.y *= 0.86
			tilt.rotation.x = 0.012 * (1.0 if flat.position.z > 0.0 else -1.0)


## Two headlight beams for a car that drives (traffic, police, the player's car); on at night.
static func add_headlights(pivot: Node3D, model: String) -> void:
	var l: float = LENGTH.get(model, 4.0)
	var beams: Array = []
	for side in [-0.55, 0.55]:
		var s := SpotLight3D.new()
		s.light_color = Color("#fff1cf")
		s.light_energy = 2.5
		s.spot_range = 16.0
		s.spot_angle = 32.0
		s.spot_attenuation = 0.8
		s.shadow_enabled = false
		s.position = Vector3(l * 0.5, 0.7, side)
		s.rotation = Vector3(-0.12, -PI * 0.5, 0)   # SpotLight shines along -Z: turn it to +X, dip it a little
		s.visible = night > 0.4
		pivot.add_child(s)
		beams.append(s)
	VehicleDetail.add_motion_fx(pivot, model)
	pivot.set_meta("beams", beams)


## Flashing blue lights (police). on=false switches them off. Call every frame while on.
static func set_lights(pivot: Node3D, on: bool, time: float) -> void:
	if not pivot.has_meta("lightbar"):
		return
	var bar: StandardMaterial3D = pivot.get_meta("lightbar")
	bar.emission_energy_multiplier = (6.0 if fmod(time, 0.5) < 0.25 else 1.0) if on else 0.0


## "POLICE / POLISIE" on the doors and canopy, and the made-up crest (not the real SAPS emblem).
static func _police_markings(pivot: Node3D) -> void:
	for side in [1.0, -1.0]:
		var z: float = side * 0.935
		var door := Label3D.new()
		door.text = "POLICE"
		door.font_size = 64
		door.pixel_size = 0.004
		door.modulate = Color("#123f8c")
		door.outline_size = 0
		door.position = Vector3(0.55, 0.42, z)
		door.rotation.y = 0.0 if side > 0 else PI
		door.double_sided = false
		pivot.add_child(door)
		var back := door.duplicate() as Label3D
		back.text = "POLICE"
		back.position = Vector3(-1.55, 1.72, z)
		back.font_size = 48
		pivot.add_child(back)
		var crest := Geo.quad(pivot, Vector2(0.3, 0.36), Vector3(1.0, 0.82, z + side * 0.002),
			PixelMaterials.panel("police_crest", Color.WHITE, true), 0.0 if side > 0 else PI)
		crest.name = "Crest"
