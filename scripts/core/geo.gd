class_name Geo
extends RefCounted
## Primitive builders for modular placeholder geometry.
## Solid boxes become StaticBody3D so the navigation bake carves them out.


static func box(parent: Node3D, size: Vector3, center: Vector3, mat: Material, solid := true, rot_y := 0.0) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if not solid:
		mi.position = center
		mi.rotation.y = rot_y
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = center
	body.rotation.y = rot_y
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mi)
	parent.add_child(body)
	return body


## Flat ground patch (visual only) covering rect (x, z, width, depth) at height y.
static func patch(parent: Node3D, rect: Rect2, y: float, mat: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = rect.size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(rect.position.x + rect.size.x * 0.5, y, rect.position.y + rect.size.y * 0.5)
	parent.add_child(mi)
	return mi


## Upright quad facing local +Z (rotated by rot_y), centred at pos.
static func quad(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


## Hip/gable roof over a w x d footprint, base at y=0, ridge height h, ridge along X.
## inset = 0 gives a gable (vertical triangular ends); inset = w/2 gives a pyramid.
## Front faces use Godot's clockwise winding.
static func roof_mesh(w: float, d: float, h: float, inset: float) -> ArrayMesh:
	var hw := w * 0.5
	var hd := d * 0.5
	var i := clampf(inset, 0.0, hw)
	var a := Vector3(-hw, 0, hd)
	var b := Vector3(hw, 0, hd)
	var c := Vector3(hw, 0, -hd)
	var dd := Vector3(-hw, 0, -hd)
	var r1 := Vector3(-hw + i, h, 0)
	var r2 := Vector3(hw - i, h, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[a, r1, r2], [a, r2, b], [c, r2, r1], [c, r1, dd], [b, r2, c], [dd, r1, a],
			[a, b, c], [a, c, dd], [a, c, b], [a, dd, c]]:
		if tri[0].distance_to(tri[1]) < 0.001 or tri[1].distance_to(tri[2]) < 0.001 or tri[0].distance_to(tri[2]) < 0.001:
			continue
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func label(parent: Node3D, text: String, pos: Vector3, size := 48, color := Color.WHITE, rot_y := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 8
	l.position = pos
	l.rotation.y = rot_y
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	parent.add_child(l)
	return l
