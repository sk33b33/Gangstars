"""Shared helpers for the vehicle build scripts that start from a textured model (build_taxi.py): the role materials
VehicleLibrary knows, welding and decimating, and sorting a mesh's faces into roles by the colour the model's texture has at each face
(so the texture itself, with its logos and baked mud, never reaches the game: the roles are plain colours, and the paint can be recoloured).
Imported with sys.path.insert(0, <this folder>) from a script run by `blender -b --python`."""
import bmesh
import bpy
import numpy as np
from mathutils import Vector


def role_material(name, hexs, rough=0.5, metal=0.0):
    h = hexs.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def make_roles():
    return {
        "paint": role_material("paint", "#f1eee8", 0.35),
        "glass": role_material("glass", "#22303f", 0.1),
        "trim": role_material("trim", "#1d1f24", 0.8),
        "chrome": role_material("chrome", "#d8dadf", 0.2, 0.9),
        "seat": role_material("seat", "#3a3f4a", 0.9),
        "headlight": role_material("headlight", "#f4f1e6", 0.2),
        "taillight": role_material("taillight", "#b0202a", 0.3),
        "tyre": role_material("tyre", "#232327", 0.9),
        "rim": role_material("rim", "#d2d5da", 0.35, 0.1),   # barely metallic: a metal surface with nothing to reflect renders black
        "indicator_L": role_material("indicator_L", "#e8901c", 0.4),
        "indicator_R": role_material("indicator_R", "#e8901c", 0.4),
        "lightbar": role_material("lightbar", "#2a6cff", 0.3),
    }


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def select_only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def apply_transform(o):
    select_only(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def detach(o):
    """Unparent keeping where it stands in the world."""
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw


def weld(o, dist=0.0006):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=dist)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def decimate(o, ratio, floor=24):
    if ratio >= 1.0 or tris(o) < 40:
        return
    select_only(o)
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.ratio = max(ratio, min(1.0, floor / tris(o)))
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)


class Texture:
    """A model's base colour image as a numpy array, sampled by UV."""

    def __init__(self, image):
        self.w, self.h = image.size
        arr = np.empty(self.w * self.h * 4, dtype=np.float32)
        image.pixels.foreach_get(arr)
        self.px = arr.reshape(self.h, self.w, 4)

    def rgb(self, u, v):
        x = min(self.w - 1, max(0, int((u % 1.0) * self.w)))
        y = min(self.h - 1, max(0, int((v % 1.0) * self.h)))
        return self.px[y, x, :3]


def face_colour(obj, poly, tex):
    """The colour of a face: the median of the texture at its corners and middle (a face that clips a logo keeps the colour of the rest)."""
    uv = obj.data.uv_layers.active.data
    pts = [Vector(uv[l].uv) for l in poly.loop_indices]
    mid = sum(pts, Vector((0, 0))) / len(pts)
    samples = [mid] + [mid.lerp(p, 0.6) for p in pts]
    cols = np.array([tex.rgb(s.x, s.y) for s in samples])
    return np.median(cols, axis=0)


def brightness(c):
    return float(c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11)


def saturation(c):
    mx, mn = float(max(c)), float(min(c))
    return 0.0 if mx <= 0.0 else (mx - mn) / mx


def face_centroid(obj, poly):
    return sum((obj.matrix_world @ obj.data.vertices[v].co for v in poly.vertices), Vector()) / len(poly.vertices)


def split_by_role(obj, roles, role_materials, prefix):
    """One new object per role holding that role's faces (roles: a role name per polygon of obj, in order). obj is left alone."""
    out = {}
    for role in set(roles):
        if role is None:
            continue
        me = obj.data.copy()
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        drop = [f for f in bm.faces if roles[f.index] != role]
        bmesh.ops.delete(bm, geom=drop, context="FACES")
        bm.to_mesh(me)
        bm.free()
        me.materials.clear()
        me.materials.append(role_materials[role])
        new = bpy.data.objects.new("%s_%s" % (prefix, role), me)
        bpy.context.scene.collection.objects.link(new)
        new.matrix_world = obj.matrix_world.copy()
        if len(me.polygons):
            out[role] = new
        else:
            bpy.data.objects.remove(new)
    return out


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    res = bpy.context.active_object
    res.name = res.data.name = name
    return res


def box(scene, parts, role_materials, centre, size, role):
    bpy.ops.mesh.primitive_cube_add(size=2, location=centre)
    b = bpy.context.active_object
    b.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    b.data.materials.append(role_materials[role])
    parts.append(b)
    return b


def procedural_wheel(role_materials, radius, width, name):
    """A wheel with its axle along X, the outer face on +X: a tyre, a rim disc, five spokes and a hub on the outer face."""
    import math
    parts = []

    def part(role):
        o = bpy.context.active_object
        o.data.materials.append(role_materials[role])
        apply_transform(o)   # the rotation goes into the mesh: only the mesh is used in the game
        parts.append(o)

    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=width, rotation=(0, math.pi / 2, 0))
    part("tyre")
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius * 0.66, depth=width * 0.9, location=(width * 0.07, 0, 0), rotation=(0, math.pi / 2, 0))
    part("rim")
    for k in range(5):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(width * 0.5, 0, 0))
        sp = bpy.context.active_object
        sp.scale = (width * 0.06, radius * 0.1, radius * 0.62)
        apply_transform(sp)
        # a spoke is a bar along Z (radius*0.62 long in total): turn it about the axle (X) and push it out so it lies on the face
        sp.rotation_euler = (k * 2 * math.pi / 5, 0, 0)
        part("trim")
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius * 0.2, depth=width * 0.2, location=(width * 0.52, 0, 0), rotation=(0, math.pi / 2, 0))
    part("chrome")
    return join(parts, name)
