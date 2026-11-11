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
    "wood_dark": mat("wood_dark", srgb("#5a3a26"), 0.6),
    "screen": mat("screen", srgb("#101318"), 0.15, 0.3),
    "mattress": mat("mattress", srgb("#ece6da")),
    "felt": mat("felt", srgb("#1f6b45"), 0.95),
    "glass_brown": mat("glass_brown", srgb("#6b3a12"), 0.2),
    "glass_green": mat("glass_green", srgb("#2f6a2a"), 0.2),
    "glass_clear": mat("glass_clear", srgb("#d8e2e0"), 0.15),
    "chrome": mat("chrome", srgb("#d8dadf"), 0.2, 0.9),
    "counter_top": mat("counter_top", srgb("#d9d2c2"), 0.5),
    "glow": mat("glow", srgb("#ffcf7a"), 0.4),
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


# ----------------------------------------------------------------------------- indoors
# Furniture for house interiors (front = -Y in Blender = +Z in Godot). "paint" is the
# recolourable upholstery / blanket / crate colour.
def couch(x, name="couch", width=2.0):
    p = [add("cube", (0, 0, 0.24), (width / 2, 0.42, 0.14), "paint", smooth=False)]
    for k in range(int(round(width / 0.65))):
        n = int(round(width / 0.65))
        cx = -width / 2 + (k + 0.5) * width / n
        p.append(add("cube", (cx, -0.04, 0.43), (width / n / 2 - 0.02, 0.36, 0.07), "paint", jitter=0.004))
    p.append(add("cube", (0, 0.34, 0.62), (width / 2, 0.1, 0.3), "paint", rot=(-0.12, 0, 0)))
    for s in (1, -1):
        p.append(add("cube", (s * (width / 2 - 0.08), 0, 0.5), (0.1, 0.42, 0.14), "paint"))
    for sx in (1, -1):
        for sy in (1, -1):
            p.append(add("cyl", (sx * (width / 2 - 0.1), sy * 0.33, 0.05), (0.03, 0.03, 0.05), "wood_dark", seg=8))
    return join(p, name, (x, 0, 0))


def coffee_table(x):
    p = [add("cube", (0, 0, 0.4), (0.5, 0.28, 0.025), "wood", smooth=False)]
    p.append(add("cube", (0, 0, 0.14), (0.45, 0.24, 0.012), "wood_dark", smooth=False))
    for sx in (1, -1):
        for sy in (1, -1):
            p.append(add("cube", (sx * 0.45, sy * 0.23, 0.2), (0.025, 0.025, 0.2), "wood_dark", smooth=False))
    p.append(add("cyl", (0.2, -0.05, 0.47), (0.04, 0.04, 0.045), "white_plastic", seg=10))   # mug
    p.append(add("cube", (-0.2, 0.05, 0.43), (0.12, 0.09, 0.008), "cloth_c", smooth=False))   # magazine
    return join(p, "coffee_table", (x, 0, 0))


def tv_unit(x):
    p = [add("cube", (0, 0, 0.25), (0.7, 0.22, 0.25), "wood_dark", smooth=False)]
    for s in (1, -1):
        p.append(add("cube", (s * 0.35, -0.225, 0.25), (0.32, 0.005, 0.2), "wood", smooth=False))
    p.append(add("cube", (0, 0, 0.85), (0.52, 0.03, 0.31), "plastic_dark", smooth=False))
    p.append(add("cube", (0, -0.032, 0.85), (0.49, 0.003, 0.28), "screen", smooth=False))
    p.append(add("cube", (0, 0.02, 0.52), (0.12, 0.06, 0.02), "plastic_dark", smooth=False))
    p.append(add("cube", (0.45, 0, 0.53), (0.12, 0.1, 0.03), "plastic_dark", smooth=False))   # decoder
    return join(p, "tv_unit", (x, 0, 0))


def kitchen_counter(x):
    p = [add("cube", (0, 0, 0.43), (1.2, 0.3, 0.43), "white_plastic", smooth=False)]
    p.append(add("cube", (0, -0.01, 0.885), (1.22, 0.32, 0.025), "counter_top", smooth=False))
    for k in range(4):
        cx = -0.9 + k * 0.6
        p.append(add("cube", (cx, -0.302, 0.45), (0.28, 0.004, 0.36), "white_plastic", smooth=False))
        p.append(add("cube", (cx + 0.2, -0.31, 0.7), (0.05, 0.008, 0.01), "chrome", smooth=False))
    p.append(add("cube", (0.5, -0.02, 0.9), (0.3, 0.2, 0.03), "metal", smooth=False))       # sink
    p.append(add("cyl", (0.5, 0.15, 1.0), (0.015, 0.015, 0.1), "chrome", seg=8))             # tap
    p.append(add("cube", (0.5, 0.08, 1.09), (0.012, 0.08, 0.012), "chrome", smooth=False))
    p.append(add("cube", (-0.6, 0.05, 0.98), (0.12, 0.08, 0.07), "cloth_d", smooth=False))   # tin
    p.append(add("cyl", (-0.85, 0.08, 1.0), (0.07, 0.07, 0.09), "metal", seg=12))           # kettle
    return join(p, "kitchen_counter", (x, 0, 0))


def stove(x):
    p = [add("cube", (0, 0, 0.45), (0.3, 0.3, 0.45), "white_plastic", smooth=False)]
    p.append(add("cube", (0, -0.302, 0.4), (0.25, 0.004, 0.22), "plastic_dark", smooth=False))
    for sx in (1, -1):
        for sy in (1, -1):
            p.append(add("cyl", (sx * 0.13, sy * 0.13, 0.905), (0.08, 0.08, 0.008), "plastic_dark", seg=12))
    p.append(add("cyl", (0.13, 0.13, 0.97), (0.11, 0.11, 0.06), "metal", seg=12))   # a pot on
    return join(p, "stove", (x, 0, 0))


def fridge(x):
    p = [add("cube", (0, 0, 0.88), (0.33, 0.32, 0.88), "white_plastic", smooth=False)]
    p.append(add("cube", (0, -0.325, 1.2), (0.32, 0.006, 0.006), "plastic_dark", smooth=False))
    for z in (0.75, 1.45):
        p.append(add("cube", (0.26, -0.34, z), (0.012, 0.012, 0.12), "chrome", smooth=False))
    p.append(add("cube", (-0.1, -0.327, 1.5), (0.05, 0.003, 0.06), "cloth_a", smooth=False))   # fridge magnets
    p.append(add("cube", (0.05, -0.327, 1.35), (0.04, 0.003, 0.05), "cloth_d", smooth=False))
    return join(p, "fridge", (x, 0, 0))


def bed(x):
    p = [add("cube", (0, 0, 0.2), (0.72, 1.02, 0.12), "wood_dark", smooth=False)]
    p.append(add("cube", (0, 0, 0.4), (0.68, 0.98, 0.1), "mattress"))
    p.append(add("cube", (0, -0.15, 0.52), (0.7, 0.82, 0.04), "paint", jitter=0.01))     # blanket
    for s in (1, -1):
        p.append(add("cube", (s * 0.3, 0.82, 0.55), (0.26, 0.12, 0.07), "cloth_b"))
    p.append(add("cube", (0, 1.04, 0.55), (0.72, 0.04, 0.45), "wood_dark", smooth=False))   # headboard
    return join(p, "bed", (x, 0, 0))


def wardrobe(x):
    p = [add("cube", (0, 0, 1.0), (0.6, 0.3, 1.0), "wood_dark", smooth=False)]
    p.append(add("cube", (0, -0.302, 1.0), (0.004, 0.003, 0.95), "plastic_dark", smooth=False))
    for s in (1, -1):
        p.append(add("cube", (s * 0.06, -0.31, 1.05), (0.01, 0.01, 0.08), "chrome", smooth=False))
    p.append(add("cube", (0.3, -0.305, 1.0), (0.18, 0.002, 0.5), "glass_clear", smooth=False))   # mirror
    return join(p, "wardrobe", (x, 0, 0))


def dining_table(x):
    p = [add("cube", (0, 0, 0.73), (0.6, 0.4, 0.025), "wood", smooth=False)]
    for sx in (1, -1):
        for sy in (1, -1):
            p.append(add("cube", (sx * 0.54, sy * 0.34, 0.36), (0.03, 0.03, 0.36), "wood_dark", smooth=False))
    p.append(add("cube", (0, 0, 0.757), (0.42, 0.3, 0.003), "cloth_a", smooth=False))   # table cloth
    p.append(add("cyl", (0.1, 0.05, 0.8), (0.1, 0.1, 0.04), "white_plastic", seg=14))   # bowl
    return join(p, "dining_table", (x, 0, 0))


def bar_counter(x):
    p = [add("cube", (0, 0, 0.52), (1.5, 0.28, 0.52), "wood_dark", smooth=False)]
    p.append(add("cube", (0, -0.03, 1.06), (1.55, 0.34, 0.03), "wood", smooth=False))
    for k in range(6):
        p.append(add("cube", (-1.25 + k * 0.5, -0.285, 0.52), (0.008, 0.005, 0.48), "wood", smooth=False))
    for k, mat_name in enumerate(("glass_brown", "glass_green", "glass_brown", "glass_clear")):
        p.append(add("cyl", (-0.9 + k * 0.25, -0.1, 1.17), (0.03, 0.03, 0.09), mat_name, seg=8))
    p.append(add("cube", (1.1, -0.05, 1.12), (0.18, 0.14, 0.03), "plastic_dark", smooth=False))   # till
    return join(p, "bar_counter", (x, 0, 0))


def bottle_shelf(x):
    p = [add("cube", (0, 0.12, 0.9), (1.0, 0.03, 0.9), "wood_dark", smooth=False)]
    for z in (0.5, 1.0, 1.5):
        p.append(add("cube", (0, 0, z), (1.0, 0.15, 0.015), "wood", smooth=False))
        for k in range(10):
            m = ("glass_brown", "glass_green", "glass_clear", "glass_brown", "paint")[(k * 3 + int(z * 7)) % 5]
            h = 0.12 + 0.03 * ((k + int(z * 3)) % 3)
            p.append(add("cyl", (-0.85 + k * 0.19, 0, z + 0.015 + h), (0.032, 0.032, h), m, seg=8))
    return join(p, "bottle_shelf", (x, 0, 0))


def jukebox(x):
    p = [add("cube", (0, 0, 0.6), (0.35, 0.25, 0.6), "paint")]
    p.append(add("cyl", (0, 0, 1.2), (0.35, 0.35, 0.25), "paint", seg=20, rot=(math.pi / 2, 0, 0)))
    p.append(add("cube", (0, -0.255, 0.85), (0.26, 0.006, 0.18), "glow", smooth=False))
    p.append(add("cube", (0, -0.255, 0.45), (0.22, 0.006, 0.12), "plastic_dark", smooth=False))
    for k in range(5):
        p.append(add("cube", (-0.2 + k * 0.1, -0.26, 1.15), (0.02, 0.004, 0.15), "chrome", smooth=False))
    return join(p, "jukebox", (x, 0, 0))


def pool_table(x):
    p = [add("cube", (0, 0, 0.74), (1.1, 0.6, 0.06), "felt", smooth=False)]
    for s in (1, -1):
        p.append(add("cube", (0, s * 0.63, 0.79), (1.17, 0.05, 0.05), "wood_dark", smooth=False))
        p.append(add("cube", (s * 1.13, 0, 0.79), (0.05, 0.6, 0.05), "wood_dark", smooth=False))
    p.append(add("cube", (0, 0, 0.5), (1.0, 0.5, 0.18), "wood_dark", smooth=False))
    for sx in (1, -1):
        for sy in (1, -1):
            p.append(add("cube", (sx * 0.95, sy * 0.45, 0.22), (0.07, 0.07, 0.22), "wood_dark", smooth=False))
    for k, m in enumerate(("white_plastic", "cloth_a", "cloth_d", "cloth_c", "plastic_dark", "cloth_a")):
        p.append(add("uvsphere", (-0.3 + (k % 3) * 0.12, -0.1 + (k // 3) * 0.12, 0.83), (0.028, 0.028, 0.028), m, seg=8, rings=6))
    p.append(add("cyl", (0.3, 0.3, 0.83), (0.01, 0.01, 0.7), "wood", seg=6, rot=(0, math.pi / 2, 0.3)))   # cue
    return join(p, "pool_table", (x, 0, 0))


def crate_stack(x):
    p = []
    for k, (cx, cy, cz) in enumerate(((0, 0, 0.15), (0, 0, 0.45), (0.55, 0, 0.15))):
        p.append(add("cube", (cx, cy, cz), (0.25, 0.18, 0.15), "paint", smooth=False))
        for j in range(3):
            p.append(add("cyl", (cx - 0.12 + j * 0.12, cy, cz + 0.17), (0.03, 0.03, 0.05), "glass_brown", seg=6))
    return join(p, "crate_stack", (x, 0, 0))


def stash_crate(x):
    p = [add("cube", (0, 0, 0.25), (0.45, 0.3, 0.25), "wood", smooth=False)]
    p.append(add("cube", (0, 0.05, 0.52), (0.47, 0.32, 0.025), "wood_dark", smooth=False, rot=(-0.08, 0, 0)))
    for s in (1, -1):
        p.append(add("cube", (s * 0.3, -0.305, 0.25), (0.04, 0.005, 0.23), "metal_dark", smooth=False))
    p.append(add("cube", (0, -0.31, 0.4), (0.05, 0.01, 0.04), "metal", smooth=False))   # padlock
    return join(p, "stash_crate", (x, 0, 0))


def ceiling_lamp(x):
    p = [add("cyl", (0, 0, -0.15), (0.008, 0.008, 0.15), "plastic_dark", seg=6)]
    p.append(add("cone", (0, 0, -0.34), (0.16, 0.16, 0.08), "white_plastic", r2=0.3, seg=16))
    p.append(add("uvsphere", (0, 0, -0.4), (0.05, 0.05, 0.05), "glow", seg=10, rings=6))
    return join(p, "ceiling_lamp", (x, 0, 0))



x = 0.0
for build in (wheelie_bin, lambda x: tree(x, "tree_a", 1.8, 7, 3), lambda x: tree(x, "tree_b", 2.4, 9, 11), aloe,
              satellite_dish, washing_line, tyre_planters, jojo_tank, plastic_chair, gas_bottle, crate,
              couch, lambda x: couch(x, "armchair", 0.95), coffee_table, tv_unit, kitchen_counter, stove, fridge,
              bed, wardrobe, dining_table, bar_counter, bottle_shelf, jukebox, pool_table, crate_stack, stash_crate,
              ceiling_lamp):
    build(x)
    x += 6.0

for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("WROTE", OUT, len([o for o in scene.objects if o.type == "MESH"]), "props")
