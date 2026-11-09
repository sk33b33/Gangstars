"""Builds the yard/street prop set: assets/models/props/props.glb.

Run headless:  blender -b --factory-startup --python tools/blender/build_props.py
Each prop is one object (origin at its base centre, front = -Y in Blender = +Z in Godot), so the
game can pull out its mesh by name. Materials are named by role; Godot may recolour "paint".
Props: wheelie_bin, tree_a, tree_b, aloe, satellite_dish, washing_line, tyre_planters,
jojo_tank, plastic_chair, gas_bottle, crate.
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "props", "props.glb")
random.seed(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, color, rough=0.85, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def srgb(hexs):
    h = hexs.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


M = {
    "paint": mat("paint", srgb("#2f6e3a")),          # recoloured in Godot (bin, tank, tyre paint)
    "plastic_dark": mat("plastic_dark", srgb("#1d1f24")),
    "bark": mat("bark", srgb("#6b4630")),
    "leaf": mat("leaf", srgb("#4f8a3c")),
    "leaf_dark": mat("leaf_dark", srgb("#3c6e30")),
    "aloe": mat("aloe", srgb("#6f9a6a")),
    "aloe_flower": mat("aloe_flower", srgb("#e0582f")),
    "metal": mat("metal", srgb("#c9c9c4"), 0.45, 0.6),
    "metal_dark": mat("metal_dark", srgb("#7d828c"), 0.5, 0.5),
    "rubber": mat("rubber", srgb("#232327"), 0.9),
    "cloth_a": mat("cloth_a", srgb("#e74c3c")),
    "cloth_b": mat("cloth_b", srgb("#f4f1ea")),
    "cloth_c": mat("cloth_c", srgb("#3498db")),
    "cloth_d": mat("cloth_d", srgb("#f1c40f")),
    "white_plastic": mat("white_plastic", srgb("#efefea"), 0.6),
    "soil": mat("soil", srgb("#6b5a45")),
    "gas": mat("gas", srgb("#c0392b"), 0.5, 0.2),
    "wood": mat("wood", srgb("#a8794e")),
}


def add(kind, loc, scale, material, rot=(0, 0, 0), **kw):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=2, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("seg", 16), radius=1, depth=2, location=loc)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("seg", 16), radius1=1, radius2=kw.get("r2", 0), depth=2, location=loc)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=kw.get("sub", 2), radius=1, location=loc)
    elif kind == "uvsphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("seg", 16), ring_count=kw.get("rings", 8), radius=1, location=loc)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_segments=kw.get("seg", 16), minor_segments=8,
                                         major_radius=1, minor_radius=kw.get("minor", 0.3), location=loc)
    o = bpy.context.active_object
    o.scale = scale
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(M[material])
    for p in o.data.polygons:
        p.use_smooth = kw.get("smooth", kind in ("cyl", "sphere", "uvsphere", "torus", "cone"))
    if kw.get("jitter"):
        for v in o.data.vertices:
            v.co += Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * kw["jitter"]
    return o


def join(parts, name, offset=(0, 0, 0)):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    # Origin at the prop's base centre, then spread props out along X so the source file is readable.
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    o.location = offset
    return o


def wheelie_bin(x):
    p = [add("cube", (0, 0, 0.5), (0.3, 0.36, 0.46), "paint", smooth=False)]
    p[0].data.polygons[0].use_smooth = False
    p.append(add("cube", (0, 0.02, 1.0), (0.32, 0.4, 0.035), "paint", rot=(0.04, 0, 0)))
    p.append(add("cube", (0, 0.39, 0.98), (0.24, 0.035, 0.03), "plastic_dark"))     # handle at the back
    for s in (1, -1):
        p.append(add("cyl", (0.26 * s, 0.33, 0.1), (0.1, 0.1, 0.04), "rubber", rot=(0, math.pi / 2, 0)))
    return join(p, "wheelie_bin", (x, 0, 0))


def tree(x, name, trunk_h, clumps, seed):
    random.seed(seed)
    p = [add("cyl", (0, 0, trunk_h / 2), (0.11, 0.11, trunk_h / 2), "bark", seg=8, r2=0.7, jitter=0.01)]
    p.append(add("cone", (0, 0, trunk_h * 0.15), (0.2, 0.2, trunk_h * 0.15), "bark", seg=8, r2=0.5))
    for i in range(clumps):
        a = i / clumps * math.tau + random.uniform(-0.3, 0.3)
        r = random.uniform(0.35, 0.75)
        h = trunk_h + random.uniform(-0.15, 0.8)
        size = random.uniform(0.55, 0.85)
        p.append(add("sphere", (math.cos(a) * r, math.sin(a) * r, h), (size, size, size * 0.8),
                     "leaf" if i % 3 else "leaf_dark", sub=1, jitter=0.06))
        if r > 0.5:
            p.append(add("cyl", (math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, trunk_h - 0.1), (0.05, 0.05, 0.4), "bark",
                         seg=6, rot=(-math.sin(a) * 0.9, math.cos(a) * 0.9, 0)))
    p.append(add("sphere", (0, 0, trunk_h + 0.9), (0.75, 0.75, 0.6), "leaf", sub=1, jitter=0.06))
    return join(p, name, (x, 0, 0))


def aloe(x):
    p = [add("cyl", (0, 0, 0.12), (0.18, 0.18, 0.12), "soil", seg=10)]
    for i in range(11):
        a = i / 11 * math.tau
        tilt = 0.55 + (i % 3) * 0.12
        p.append(add("cone", (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.42), (0.06, 0.025, 0.32), "aloe", seg=6,
                     rot=(-math.sin(a) * tilt, math.cos(a) * tilt, a)))
    for i in range(2):
        p.append(add("cyl", (0.04 * i, 0.02, 0.75), (0.015, 0.015, 0.35), "aloe", seg=5))
        p.append(add("cone", (0.04 * i, 0.02, 1.15), (0.05, 0.05, 0.12), "aloe_flower", seg=6))
    return join(p, "aloe", (x, 0, 0))


def satellite_dish(x):
    # Mounted on a wall bracket; origin = bracket on the wall, dish faces +Y (out from the wall).
    dish = add("uvsphere", (0, -0.28, 0.0), (0.36, 0.36, 0.36), "metal", seg=20, rings=10)
    bm = bmesh.new()
    bm.from_mesh(dish.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, -0.28 + 0.24, 0),
                           plane_no=(0, 1, 0), clear_outer=True)
    bm.to_mesh(dish.data)
    bm.free()
    dish.rotation_euler = (math.radians(35), 0, 0)
    bpy.context.view_layer.objects.active = dish
    bpy.ops.object.transform_apply(rotation=True)
    p = [dish]
    p.append(add("cyl", (0, -0.42, -0.12), (0.012, 0.012, 0.3), "metal_dark", seg=6, rot=(1.0, 0, 0)))
    p.append(add("cube", (0, -0.62, -0.02), (0.035, 0.05, 0.035), "plastic_dark"))
    p.append(add("cyl", (0, -0.12, -0.05), (0.02, 0.02, 0.12), "metal_dark", seg=6, rot=(math.pi / 2, 0, 0)))
    p.append(add("cube", (0, 0.0, -0.05), (0.08, 0.01, 0.08), "metal_dark", smooth=False))
    return join(p, "satellite_dish", (x, 0, 1.5))


def washing_line(x):
    # 5.2 m line between two T-poles; clothes pegged along it.
    p = []
    for s in (1, -1):
        p.append(add("cyl", (2.6 * s, 0, 0.95), (0.035, 0.035, 0.95), "metal_dark", seg=6))
        p.append(add("cyl", (2.6 * s, 0, 1.88), (0.025, 0.025, 0.35), "metal_dark", seg=6, rot=(math.pi / 2, 0, 0)))
    for y in (-0.3, 0.3):
        p.append(add("cyl", (0, y, 1.86), (0.006, 0.006, 2.6), "white_plastic", seg=4, rot=(0, math.pi / 2, 0)))
    cloths = [(-2.0, -0.3, 0.55, 0.7, "cloth_a"), (-1.2, -0.3, 0.45, 0.5, "cloth_b"), (-0.4, 0.3, 0.6, 0.9, "cloth_c"),
              (0.5, -0.3, 0.4, 0.55, "cloth_d"), (1.3, 0.3, 0.7, 0.45, "cloth_b"), (2.0, -0.3, 0.35, 0.6, "cloth_a")]
    for cx, cy, w, h, m in cloths:
        c = add("cube", (cx, cy, 1.86 - h / 2), (w / 2, 0.012, h / 2), m, smooth=False)
        for v in c.data.vertices:  # a little sag and sway
            v.co.y += math.sin(v.co.x * 3.0 + cx) * 0.03
        p.append(c)
    return join(p, "washing_line", (x, 0, 0))


def tyre_planters(x):
    # Three half-buried painted tyres in a row (garden edging), 0.7 m apart.
    p = []
    for i in range(3):
        t = add("torus", ((i - 1) * 0.7, 0, 0.12), (0.3, 0.3, 0.3), "paint", rot=(math.pi / 2, 0, 0), minor=0.32, seg=18)
        p.append(t)
        p.append(add("cyl", ((i - 1) * 0.7, 0, 0.05), (0.22, 0.22, 0.05), "soil", seg=12))
    return join(p, "tyre_planters", (x, 0, 0))


def jojo_tank(x):
    p = [add("cyl", (0, 0, 0.9), (0.7, 0.7, 0.85), "paint", seg=24)]
    for z in (0.35, 0.75, 1.15, 1.5):
        p.append(add("torus", (0, 0, z), (0.705, 0.705, 0.705), "paint", minor=0.03, seg=24))
    p.append(add("cone", (0, 0, 1.85), (0.7, 0.7, 0.12), "paint", seg=24, r2=0.25))
    p.append(add("cyl", (0, 0, 2.0), (0.2, 0.2, 0.05), "plastic_dark", seg=12))
    p.append(add("cyl", (0, 0, 0.04), (0.8, 0.8, 0.04), "metal_dark", seg=16, smooth=False))
    p.append(add("cyl", (0, -0.72, 0.25), (0.03, 0.03, 0.08), "metal", seg=6, rot=(math.pi / 2, 0, 0)))
    return join(p, "jojo_tank", (x, 0, 0))


def plastic_chair(x):
    p = [add("cube", (0, 0, 0.44), (0.23, 0.22, 0.025), "white_plastic", smooth=False)]
    p.append(add("cube", (0, 0.21, 0.72), (0.22, 0.02, 0.24), "white_plastic", rot=(-0.12, 0, 0), smooth=False))
    for sx in (1, -1):
        for sy in (1, -1):
            p.append(add("cyl", (0.19 * sx, 0.18 * sy, 0.22), (0.022, 0.022, 0.22), "white_plastic", seg=6,
                         rot=(0.08 * sy, -0.08 * sx, 0)))
        p.append(add("cube", (0.23 * sx, 0.02, 0.6), (0.02, 0.2, 0.02), "white_plastic", smooth=False))
    return join(p, "plastic_chair", (x, 0, 0))


def gas_bottle(x):
    p = [add("cyl", (0, 0, 0.32), (0.16, 0.16, 0.27), "gas", seg=16)]
    p.append(add("uvsphere", (0, 0, 0.58), (0.16, 0.16, 0.07), "gas", seg=16, rings=6))
    p.append(add("cyl", (0, 0, 0.7), (0.04, 0.04, 0.05), "metal", seg=8))
    p.append(add("torus", (0, 0, 0.72), (0.09, 0.09, 0.09), "metal", minor=0.18, seg=12))
    p.append(add("cyl", (0, 0, 0.03), (0.17, 0.17, 0.03), "metal_dark", seg=16))
    return join(p, "gas_bottle", (x, 0, 0))


def crate(x):
    p = [add("cube", (0, 0, 0.18), (0.25, 0.18, 0.18), "paint", smooth=False)]
    for s in (1, -1):
        p.append(add("cube", (0.255 * s, 0, 0.26), (0.006, 0.06, 0.03), "plastic_dark", smooth=False))
    return join(p, "crate", (x, 0, 0))


x = 0.0
for build in (wheelie_bin, lambda x: tree(x, "tree_a", 1.8, 7, 3), lambda x: tree(x, "tree_b", 2.4, 9, 11), aloe,
              satellite_dish, washing_line, tyre_planters, jojo_tank, plastic_chair, gas_bottle, crate):
    build(x)
    x += 6.0

for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("WROTE", OUT, len([o for o in scene.objects if o.type == "MESH"]), "props")
