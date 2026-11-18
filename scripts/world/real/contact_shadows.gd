class_name ContactShadows
extends RefCounted
## A soft dark blob on the ground under each solid prop (trees, bushes, bins, benches, tanks, boulders...): the cheap stand-in for a shadow
## on a phone, where real shadows cost too much. All of a piece's blobs are one MultiMesh (one draw) with one shared radial-gradient
## material. Props off the ground (a letterbox on a post, a dish on a roof) and small ones (grass, flowers) get none.

## Radius (m) of the blob under each prop at scale 1.
const RADIUS := {
	"tree_a": 1.3, "tree_b": 1.5, "tree_c": 2.0, "palm": 0.8, "shade_tree": 2.0, "bush": 0.7, "bush_pink": 0.7, "bush_yellow": 0.65, "bush_white": 0.6,
	"hedge": 0.9, "agave": 0.6, "aloe": 0.45, "wheelie_bin": 0.42, "litter_bin": 0.3, "park_bench": 0.9, "picnic_table": 1.2, "jojo_tank": 0.85,
	"crate_stack": 0.5, "plastic_chair": 0.35, "braai_drum": 0.4, "kennel": 0.6, "bicycle": 0.55, "drinks_fridge": 0.5, "chest_freezer": 0.8,
	"a_frame": 0.35, "gas_cage": 0.7, "park_lamp": 0.3, "boulder": 0.75, "fallen_log": 1.0, "seesaw": 1.3, "spring_rider": 0.4, "monkey_bars": 1.6,
	"netball_post": 0.3, "price_pylon": 0.45, "fire_hydrant": 0.25, "post_box": 0.35, "tyre_stack": 0.42, "oil_drums": 0.65, "air_machine": 0.3,
	"bollard": 0.15, "flagpole": 0.3, "bike_rack": 0.8, "tyre_planters": 0.7, "gas_bottle": 0.2,
}
const Y := 0.026                 # just above the ground decals (RealStreetDecor.Y_GROUND_DECAL is 0.0245)
const MAX_PROP_HEIGHT := 0.3     # props standing higher than this are on something, not on the ground
const ALPHA := 0.38

static var _mat: StandardMaterial3D
static var _mesh: PlaneMesh


## The transform of the blob under every ground prop in `props` ({name: [Transform3D]}).
static func transforms(props: Dictionary) -> Array:
	var blobs: Array = []
	for prop: String in props:
		var r: float = RADIUS.get(prop, 0.0)
		if r <= 0.0:
			continue
		for xf: Transform3D in props[prop]:
			if xf.origin.y > MAX_PROP_HEIGHT:
				continue
			var scale := xf.basis.get_scale().x
			blobs.append(Transform3D(Basis().scaled(Vector3(2.0 * r * scale, 1.0, 2.0 * r * scale)), Vector3(xf.origin.x, Y, xf.origin.z)))
	return blobs


## One MultiMeshInstance3D with a blob for every ground prop in `props`, or null if there is none.
static func build(props: Dictionary) -> MultiMeshInstance3D:
	var blobs := transforms(props)
	if blobs.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh()
	mm.instance_count = blobs.size()
	for i in blobs.size():
		mm.set_instance_transform(i, blobs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Blobs"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 90.0
	return mmi


## The flat square every blob is made from (its material fades to nothing at the edge, so the square never shows).
static func mesh() -> PlaneMesh:
	if _mesh == null:
		_mesh = PlaneMesh.new()
		_mesh.size = Vector2.ONE
		_mesh.material = material()
	return _mesh


static func material() -> StandardMaterial3D:
	if _mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.05, 0.04, 0.03, ALPHA))
		g.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_texture = tex
		_mat.disable_receive_shadows = true
	return _mat
