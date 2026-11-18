class_name RealShopDecor
extends RefCounted
## What stands outside a shop: the shopping-centre and corner-shop frontages (a sign board on the parapet band, drinks fridges,
## a chest freezer, gas cages, an A-frame board, crates and chairs on the pavement under the veranda) and the spaza shops run
## from a front room (a striped awning over the hatch, a fridge and a freezer either side, a gas cage, an A-frame board).
## Everything is placed in front of the wall (`n` is the outward normal, `t` the tangent along it) from a seed, so it never changes.

const SHOP_SIGN_Y := Vector2(4.1, 4.9)    # on the parapet band above a shop's roof line (RealLandmarks.SHOP_WALL / SHOP_BAND)
const SHOP_SIGN_WIDTH := 6.0
const SHOP_GOODS_MIN_LENGTH := 6.0


## A shop frontage: `mid` the middle of the front wall, `length` its length.
static func draw_shop(mid: Vector2, t: Vector2, n: Vector2, length: float, seed_value: int, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sign := RealChunkBuilder._tool("panel_sign_shop", surfaces, materials, PixelMaterials.panel("sign_shop"))
	RealChunkBuilder._panel(sign, mid + n * 0.04, t, n, minf(SHOP_SIGN_WIDTH, length - 0.8), SHOP_SIGN_Y.x, SHOP_SIGN_Y.y)
	if length < SHOP_GOODS_MIN_LENGTH:
		return
	var reach := length * 0.5 - 1.2
	var out := n * 1.0
	RealStreetDecor.add_prop(props, "drinks_fridge", mid + out + t * (-reach if rng.randi() % 2 == 0 else reach), atan2(n.x, n.y))
	RealStreetDecor.add_prop(props, "chest_freezer", mid + out + t * rng.randf_range(-reach, reach) * 0.5, atan2(n.x, n.y))
	if rng.randi() % 2 == 0:
		RealStreetDecor.add_prop(props, "gas_cage", mid + out + t * reach * 0.6, atan2(n.x, n.y))
	RealStreetDecor.add_prop(props, "a_frame", mid + n * 2.2 + t * rng.randf_range(-reach, reach) * 0.7, atan2(n.x, n.y) + rng.randf_range(-0.3, 0.3))
	for k in 2 + rng.randi() % 2:
		RealStreetDecor.add_prop(props, "plastic_chair", mid + n * 1.6 + t * (reach * (-0.3 + 0.35 * k)), atan2(n.x, n.y) + rng.randf_range(-0.5, 0.5))
	RealStreetDecor.add_prop(props, "crate_stack", mid + n * 1.2 - t * reach * 0.4, rng.randf() * TAU)


## A spaza hatch at `at` in the front wall: an awning over it, a drinks fridge on one side and a chest freezer on the other, an
## A-frame board out front and sometimes a gas cage. (The crates and chair are placed by RealHomeDecor.)
static func draw_spaza(at: Vector2, t: Vector2, n: Vector2, seed_value: int, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 17
	var awning := RealChunkBuilder._tool("awning", surfaces, materials, PixelMaterials.panel("awning_stripes"))
	RealStreetDecor.decal(awning, at + n * 0.6, t, 1.3, 2.4, 2.05)
	var flip := 1.0 if rng.randi() % 2 == 0 else -1.0
	RealStreetDecor.add_prop(props, "drinks_fridge", at + t * 1.9 * flip + n * 0.45, atan2(n.x, n.y))
	RealStreetDecor.add_prop(props, "chest_freezer", at - t * 1.9 * flip + n * 0.5, atan2(n.x, n.y))
	RealStreetDecor.add_prop(props, "a_frame", at + n * 2.0 + t * 0.4 * flip, atan2(n.x, n.y) + rng.randf_range(-0.3, 0.3))
	if rng.randi() % 3 == 0:
		RealStreetDecor.add_prop(props, "gas_cage", at + t * 3.2 * flip + n * 0.4, atan2(n.x, n.y))
