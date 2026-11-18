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
    "bloom_pink": mat("bloom_pink", srgb("#e0589a")),
    "bloom_yellow": mat("bloom_yellow", srgb("#f2c230")),
    "bloom_red": mat("bloom_red", srgb("#d6402e")),
    "bloom_white": mat("bloom_white", srgb("#f4f1ea")),
    "bloom_purple": mat("bloom_purple", srgb("#8e5ab8")),
    "agave": mat("agave", srgb("#7fa08a")),
    "palm_leaf": mat("palm_leaf", srgb("#4a8a3a")),
    "grass_dry": mat("grass_dry", srgb("#b9a65a")),
    "grass_green": mat("grass_green", srgb("#7aa245")),
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



def bush(x, name="bush", blooms=None, size=1.0):
    """A round shrub about 0.9 m high and 1.2 m across; `blooms`: a bloom material to dot it with flowers."""
    random.seed(len(name) * 13)
    p = []
    for i in range(6):
        a = i / 6 * math.tau
        r = 0.32 * size if i else 0.0
        h = (0.38 + random.uniform(-0.05, 0.12)) * size
        s = random.uniform(0.34, 0.46) * size
        p.append(add("sphere", (math.cos(a) * r, math.sin(a) * r, h), (s, s, s * 0.85), "leaf" if i % 2 else "leaf_dark", sub=1, jitter=0.04))
    if blooms:
        for i in range(16):
            a = random.uniform(0, math.tau)
            e = random.uniform(0.2, 0.85)
            r = 0.52 * size * math.cos(e)
            p.append(add("cube", (math.cos(a) * r, math.sin(a) * r, (0.1 + 0.55 * math.sin(e)) * size + 0.12), (0.06, 0.06, 0.05), blooms, smooth=False))
    return join(p, name, (x, 0, 0))


def flower_bed(x, name, bloom, bloom2):
    """A low mound of leaves, 1.2 x 0.7 m, covered in flowers of two colours."""
    random.seed(len(name) * 29)
    p = [add("sphere", (0, 0, 0.03), (0.62, 0.36, 0.12), "soil", sub=1)]
    for i in range(5):
        p.append(add("sphere", ((i - 2) * 0.22, random.uniform(-0.1, 0.1), 0.13), (0.2, 0.2, 0.13), "leaf" if i % 2 else "leaf_dark", sub=1, jitter=0.02))
    for i in range(22):
        m = bloom if i % 3 else bloom2
        p.append(add("cube", (random.uniform(-0.55, 0.55), random.uniform(-0.28, 0.28), random.uniform(0.2, 0.3)), (0.045, 0.045, 0.035), m, smooth=False))
    return join(p, name, (x, 0, 0))


def grass_tuft(x, name, material, height):
    """A clump of thin blades (dune and verge grass)."""
    random.seed(len(name) * 7)
    p = []
    for i in range(11):
        a = i / 11 * math.tau + random.uniform(-0.2, 0.2)
        tilt = random.uniform(0.25, 0.7)
        h = height * random.uniform(0.7, 1.15)
        p.append(add("cone", (math.cos(a) * 0.05, math.sin(a) * 0.05, h * 0.5), (0.03, 0.012, h * 0.5), material, seg=4,
                     rot=(-math.sin(a) * tilt, math.cos(a) * tilt, a)))
    return join(p, name, (x, 0, 0))


def agave(x):
    """A Cape agave: a rosette of fat grey-green leaves, 0.8 m across."""
    p = []
    for ring_i, (n, tilt, h, sz) in enumerate(((10, 0.95, 0.3, 0.34), (8, 0.55, 0.38, 0.3), (5, 0.2, 0.42, 0.26))):
        for i in range(n):
            a = i / n * math.tau + ring_i * 0.3
            p.append(add("cone", (math.cos(a) * 0.06, math.sin(a) * 0.06, h), (0.07, 0.025, sz), "agave", seg=5,
                         rot=(-math.sin(a) * tilt, math.cos(a) * tilt, a)))
    return join(p, "agave", (x, 0, 0))


def palm(x):
    """A fan palm about 5 m tall: a slightly leaning ringed trunk and a crown of drooping fronds."""
    p = []
    for i in range(6):
        z = 0.4 + i * 0.75
        p.append(add("cyl", (0.04 * i * i * 0.12, 0, z), (0.17 - i * 0.006, 0.17 - i * 0.006, 0.4), "bark", seg=8, jitter=0.006))
    top = (0.04 * 25 * 0.12, 0, 4.7)
    for i in range(10):
        a = i / 10 * math.tau
        tilt = 1.05 + (i % 2) * 0.35
        p.append(add("cone", (top[0] + math.cos(a) * 0.55, math.sin(a) * 0.55, top[2] + 0.1 - (i % 2) * 0.15), (0.16, 0.035, 0.95), "palm_leaf", seg=5,
                     rot=(-math.sin(a) * tilt, math.cos(a) * tilt, a)))
    p.append(add("sphere", (top[0], 0, top[2] - 0.1), (0.22, 0.22, 0.2), "bark", sub=1))
    return join(p, "palm", (x, 0, 0))


def shade_tree(x):
    """A broad-crowned street tree (a milkwood or Port Jackson): short trunk, a wide flat-topped crown, 4 m tall."""
    random.seed(41)
    p = [add("cyl", (0, 0, 1.0), (0.15, 0.15, 1.0), "bark", seg=8, r2=0.7, jitter=0.01)]
    for br in range(3):
        a = br / 3 * math.tau
        p.append(add("cyl", (math.cos(a) * 0.35, math.sin(a) * 0.35, 2.1), (0.06, 0.06, 0.5), "bark", seg=6, rot=(-math.sin(a) * 0.7, math.cos(a) * 0.7, 0)))
    for i in range(9):
        a = i / 9 * math.tau + random.uniform(-0.3, 0.3)
        r = random.uniform(0.9, 1.6) if i else 0.0
        h = 2.9 + random.uniform(-0.2, 0.45)
        s = random.uniform(0.85, 1.2)
        p.append(add("sphere", (math.cos(a) * r, math.sin(a) * r, h), (s, s, s * 0.6), "leaf" if i % 3 else "leaf_dark", sub=1, jitter=0.07))
    return join(p, "tree_c", (x, 0, 0))


def hedge(x):
    """A clipped hedge piece, 2 m long and 0.9 m high."""
    random.seed(3)
    p = []
    for i in range(5):
        p.append(add("cube", ((i - 2) * 0.4, 0, 0.45), (0.22, 0.28, 0.45), "leaf" if i % 2 else "leaf_dark", smooth=False))
    return join(p, "hedge", (x, 0, 0))



def solar_geyser(x):
    """A roof solar water heater: a flat collector panel with a horizontal tank at its upper end, on short legs. Origin at the middle of
    the panel's underside, the panel lying flat (normal up) with the tank towards +Y (up the roof slope): the placement tilts it to the roof."""
    p = [add("cube", (0, 0, 0.14), (0.62, 0.92, 0.045), "metal_dark", smooth=False)]            # the collector frame
    p.append(add("cube", (0, 0, 0.17), (0.56, 0.86, 0.02), "screen", smooth=False))               # its dark glass
    for i in range(-2, 3):
        p.append(add("cube", (i * 0.22, 0, 0.19), (0.008, 0.85, 0.008), "metal", smooth=False))    # the tubes' lines
    for sx in (-0.5, 0.5):
        for sy in (-0.7, 0.7):
            p.append(add("cube", (sx, sy, 0.06), (0.04, 0.04, 0.06), "metal_dark", smooth=False))   # legs
    p.append(add("cyl", (0, 1.12, 0.45), (0.22, 0.22, 0.62), "white_plastic", rot=(0, math.pi / 2, 0), seg=16))   # the tank
    for sx in (-0.4, 0.4):
        p.append(add("cube", (sx, 1.0, 0.3), (0.03, 0.15, 0.16), "metal_dark", smooth=False))      # tank cradle
    return join(p, "solar_geyser", (x, 0, 0))



def braai_drum(x):
    """A braai drum: half an oil drum on four legs with a grid on top (0.6 m across, 0.9 m high)."""
    p = [add("cyl", (0, 0, 0.62), (0.3, 0.3, 0.3), "metal_dark", seg=16, rot=(0, math.pi / 2, 0))]   # the drum, lying on its side
    p.append(add("cube", (0, 0, 0.86), (0.3, 0.27, 0.015), "metal", smooth=False))                   # the grid
    for sx in (-0.24, 0.24):
        for sy in (-0.2, 0.2):
            p.append(add("cyl", (sx, sy, 0.3), (0.02, 0.02, 0.3), "metal_dark", seg=6))
    p.append(add("cube", (0.0, 0.0, 0.42), (0.26, 0.2, 0.02), "plastic_dark", smooth=False))        # ash tray under the drum
    return join(p, "braai_drum", (x, 0, 0))


def kennel(x):
    """A wooden dog kennel with a pitched roof and a dark doorway; the door faces -Y (Godot +Z)."""
    p = [add("cube", (0, 0, 0.3), (0.38, 0.5, 0.3), "wood", smooth=False)]
    for s in (-1, 1):
        p.append(add("cube", (0.23 * s, 0, 0.72), (0.27, 0.58, 0.025), "wood_dark", rot=(0, -0.62 * s, 0), smooth=False))   # roof halves
    p.append(add("cube", (0, -0.505, 0.26), (0.18, 0.01, 0.2), "plastic_dark", smooth=False))        # the doorway
    p.append(add("cube", (0, -0.505, 0.5), (0.2, 0.012, 0.012), "wood_dark", smooth=False))
    return join(p, "kennel", (x, 0, 0))


def bicycle(x):
    """A child's bicycle, standing on its kickstand, 1.5 m long."""
    p = []
    for sy in (-0.55, 0.55):
        p.append(add("torus", (0, sy, 0.33), (0.33, 0.33, 0.33), "rubber", rot=(0, math.pi / 2, 0), minor=0.05, seg=20))
        p.append(add("cyl", (0, sy, 0.33), (0.008, 0.008, 0.04), "metal", seg=6, rot=(0, math.pi / 2, 0)))
    p.append(add("cyl", (0, 0.0, 0.5), (0.015, 0.015, 0.6), "cloth_a", seg=6, rot=(math.pi / 2 - 0.25, 0, 0)))    # top tube
    p.append(add("cyl", (0, 0.2, 0.42), (0.015, 0.015, 0.4), "cloth_a", seg=6, rot=(0.9, 0, 0)))                   # seat tube / chain stay
    p.append(add("cyl", (0, -0.5, 0.55), (0.015, 0.015, 0.3), "metal_dark", seg=6, rot=(-0.25, 0, 0)))             # fork
    p.append(add("cyl", (0, -0.5, 0.86), (0.015, 0.015, 0.22), "metal_dark", seg=6, rot=(0, math.pi / 2, 0)))      # handlebar
    p.append(add("cube", (0, 0.2, 0.68), (0.05, 0.1, 0.02), "plastic_dark", smooth=False))                         # seat
    return join(p, "bicycle", (x, 0, 0))


def letterbox(x):
    """A steel letterbox for a gate post, 0.3 x 0.12 x 0.22 m, the slot on the face towards -Y (Godot +Z)."""
    p = [add("cube", (0, 0, 0.11), (0.15, 0.06, 0.11), "cloth_a", smooth=False)]
    p.append(add("cube", (0, 0.0, 0.23), (0.16, 0.07, 0.012), "cloth_a", smooth=False))
    p.append(add("cube", (0, -0.062, 0.14), (0.09, 0.004, 0.012), "plastic_dark", smooth=False))
    return join(p, "letterbox", (x, 0, 0))


def park_bench(x):
    """A park bench with a slatted seat and back on steel ends, 1.7 m wide; people sit facing -Y (Godot +Z)."""
    p = []
    for i in range(3):
        p.append(add("cube", (0, -0.08 + i * 0.12, 0.45), (0.85, 0.05, 0.02), "wood", smooth=False))       # seat slats
    for i in range(3):
        p.append(add("cube", (0, 0.2, 0.62 + i * 0.1), (0.85, 0.015, 0.045), "wood", rot=(-0.2, 0, 0), smooth=False))   # back slats
    for sx in (-0.78, 0.78):
        p.append(add("cube", (sx, 0.05, 0.22), (0.03, 0.22, 0.22), "metal_dark", smooth=False))
        p.append(add("cube", (sx, 0.2, 0.6), (0.03, 0.02, 0.3), "metal_dark", rot=(-0.2, 0, 0), smooth=False))
    return join(p, "park_bench", (x, 0, 0))


def picnic_table(x):
    """A wooden picnic table with two attached benches, 1.8 x 1.6 m, 0.75 m high."""
    p = [add("cube", (0, 0, 0.75), (0.9, 0.4, 0.03), "wood", smooth=False)]
    for sy in (-0.65, 0.65):
        p.append(add("cube", (0, sy, 0.45), (0.9, 0.15, 0.025), "wood", smooth=False))
    for sx in (-0.65, 0.65):
        p.append(add("cube", (sx, 0, 0.38), (0.05, 0.75, 0.04), "wood_dark", smooth=False))
        for sy in (-0.3, 0.3):
            p.append(add("cube", (sx, sy, 0.4), (0.04, 0.03, 0.4), "wood_dark", rot=(0.25 * (1 if sy > 0 else -1), 0, 0), smooth=False))
    return join(p, "picnic_table", (x, 0, 0))


def litter_bin(x):
    """A municipal litter bin: a green steel drum with a rain lid on a post, 0.9 m high."""
    p = [add("cyl", (0, 0, 0.5), (0.22, 0.22, 0.32), "paint", seg=12)]
    p.append(add("cyl", (0, 0, 0.84), (0.24, 0.24, 0.03), "metal_dark", seg=12))
    p.append(add("cyl", (0, 0, 0.14), (0.04, 0.04, 0.14), "metal_dark", seg=6))
    p.append(add("cube", (0, -0.215, 0.62), (0.1, 0.01, 0.07), "plastic_dark", smooth=False))      # the opening
    return join(p, "litter_bin", (x, 0, 0))


def boulder(x):
    """A weathered granite boulder with a smaller one beside it, 1.1 m across."""
    random.seed(9)
    p = [add("sphere", (0, 0, 0.3), (0.55, 0.45, 0.32), "metal_dark", sub=2, jitter=0.05),
         add("sphere", (0.55, 0.2, 0.15), (0.28, 0.24, 0.17), "metal", sub=1, jitter=0.03)]
    return join(p, "boulder", (x, 0, 0))


def fallen_log(x):
    """A fallen log, 1.8 m long, lying along X."""
    p = [add("cyl", (0, 0, 0.17), (0.17, 0.17, 0.9), "bark", seg=8, rot=(0, math.pi / 2, 0), jitter=0.01)]
    p.append(add("cyl", (0.3, 0.1, 0.1), (0.05, 0.05, 0.25), "bark", seg=6, rot=(0.9, 0.5, 0)))
    return join(p, "fallen_log", (x, 0, 0))


def park_lamp(x):
    """A park lamp post: a slim dark steel pole with a round white lantern, 3.6 m high."""
    p = [add("cyl", (0, 0, 1.75), (0.045, 0.045, 1.75), "metal_dark", seg=8)]
    p.append(add("cyl", (0, 0, 0.1), (0.1, 0.1, 0.1), "metal_dark", seg=8))
    p.append(add("uvsphere", (0, 0, 3.55), (0.2, 0.2, 0.2), "white_plastic", seg=12, rings=6))
    p.append(add("cyl", (0, 0, 3.78), (0.16, 0.16, 0.03), "metal_dark", seg=10))
    return join(p, "park_lamp", (x, 0, 0))


def seesaw(x):
    """A seesaw: a 2.6 m plank tilted on a central steel fulcrum, handles at each end; the plank runs along X."""
    p = [add("cube", (0, 0, 0.55), (1.3, 0.14, 0.04), "cloth_d", rot=(0, 0.14, 0), smooth=False)]
    p.append(add("cube", (0, 0, 0.3), (0.05, 0.14, 0.3), "metal_dark", smooth=False))
    p.append(add("cube", (0, 0, 0.04), (0.35, 0.05, 0.04), "metal_dark", smooth=False))
    for sx, sz in ((-1.1, 0.4), (1.1, 0.7)):
        p.append(add("cyl", (sx, 0, sz + 0.2), (0.015, 0.015, 0.16), "metal", seg=6))
        p.append(add("cube", (sx, 0, sz + 0.37), (0.015, 0.1, 0.015), "metal", smooth=False))
    return join(p, "seesaw", (x, 0, 0))


def spring_rider(x):
    """A spring rider: a painted animal on a coiled spring, 0.9 m high, facing -Y (Godot +Z)."""
    p = [add("cyl", (0, 0, 0.03), (0.25, 0.25, 0.03), "metal_dark", seg=10)]
    for i in range(4):
        p.append(add("torus", (0, 0, 0.12 + i * 0.07), (0.08, 0.08, 0.08), "metal", minor=0.18, seg=10))
    p.append(add("sphere", (0, 0.0, 0.62), (0.2, 0.38, 0.2), "cloth_c", sub=2))                       # the body
    p.append(add("sphere", (0, -0.36, 0.78), (0.15, 0.15, 0.15), "cloth_c", sub=1))                    # the head
    p.append(add("cube", (0, -0.5, 0.74), (0.03, 0.06, 0.03), "cloth_d", smooth=False))               # the nose
    p.append(add("cube", (0, -0.22, 0.88), (0.2, 0.015, 0.015), "metal", smooth=False))               # handlebar
    p.append(add("cube", (0.2, -0.1, 0.4), (0.025, 0.1, 0.025), "cloth_d", smooth=False))             # footrests
    p.append(add("cube", (-0.2, -0.1, 0.4), (0.025, 0.1, 0.025), "cloth_d", smooth=False))
    return join(p, "spring_rider", (x, 0, 0))


def monkey_bars(x):
    """Monkey bars: two A-frames with eight rungs between them, 3 m long (along X) and 1.9 m high."""
    p = []
    for sx in (-1.5, 1.5):
        for sy in (-0.45, 0.45):
            p.append(add("cyl", (sx, sy * 1.0, 0.95), (0.025, 0.025, 0.98), "cloth_a", seg=6, rot=(-sy * 0.5, 0, 0)))
        p.append(add("cube", (sx, 0, 1.88), (0.03, 0.03, 0.03), "cloth_a", smooth=False))
    for i in range(8):
        p.append(add("cyl", (-1.3 + i * 0.37, 0, 1.85), (0.015, 0.015, 0.2), "metal", seg=6, rot=(math.pi / 2, 0, 0)))
    p.append(add("cyl", (0, 0, 1.85), (0.02, 0.02, 1.5), "cloth_a", seg=6, rot=(0, math.pi / 2, 0)))
    return join(p, "monkey_bars", (x, 0, 0))


def netball_post(x):
    """A netball post: a 3.05 m steel pole with a ring on a short arm towards -Y (Godot +Z)."""
    p = [add("cyl", (0, 0, 1.52), (0.04, 0.04, 1.52), "white_plastic", seg=8)]
    p.append(add("cyl", (0, 0.0, 0.08), (0.09, 0.09, 0.08), "metal_dark", seg=8))
    p.append(add("cube", (0, -0.1, 2.98), (0.015, 0.1, 0.015), "metal", smooth=False))
    p.append(add("torus", (0, -0.3, 3.0), (0.19, 0.19, 0.19), "cloth_a", minor=0.07, seg=14))
    return join(p, "netball_post", (x, 0, 0))


def flagpole(x):
    """A school flagpole: a 7 m tapering pole on a concrete base with a flag flying towards +X."""
    p = [add("cyl", (0, 0, 0.12), (0.3, 0.3, 0.12), "counter_top", seg=10)]
    p.append(add("cyl", (0, 0, 3.6), (0.05, 0.05, 3.5), "metal", seg=8, r2=0.6))
    p.append(add("sphere", (0, 0, 7.12), (0.07, 0.07, 0.07), "chrome", sub=1))
    for i, m in enumerate(("cloth_c", "cloth_b", "cloth_a")):
        p.append(add("cube", (0.62, 0, 6.82 - i * 0.2), (0.6, 0.012, 0.1), m, smooth=False))
    return join(p, "flagpole", (x, 0, 0))


def bike_rack(x):
    """A steel bicycle rack: a rail on six hoops, 2.2 m long (along X), 0.8 m high."""
    p = []
    for i in range(6):
        sx = -1.0 + i * 0.4
        p.append(add("torus", (sx, 0, 0.3), (0.3, 0.3, 0.3), "metal_dark", rot=(math.pi / 2, 0, 0), minor=0.04, seg=12))
    p.append(add("cube", (0, 0, 0.02), (1.1, 0.14, 0.02), "metal_dark", smooth=False))
    return join(p, "bike_rack", (x, 0, 0))


def fire_hydrant(x):
    """A red fire hydrant, 0.8 m high, with two side outlets along X."""
    p = [add("cyl", (0, 0, 0.06), (0.13, 0.13, 0.06), "metal_dark", seg=10)]
    p.append(add("cyl", (0, 0, 0.42), (0.1, 0.1, 0.34), "gas", seg=10))
    p.append(add("sphere", (0, 0, 0.78), (0.11, 0.11, 0.09), "gas", sub=1))
    p.append(add("cyl", (0, 0, 0.7), (0.13, 0.13, 0.03), "metal_dark", seg=10))
    for sx in (-1, 1):
        p.append(add("cyl", (0.13 * sx, 0, 0.5), (0.05, 0.05, 0.05), "metal_dark", seg=8, rot=(0, math.pi / 2, 0)))
    p.append(add("cyl", (0, -0.12, 0.45), (0.045, 0.045, 0.04), "metal_dark", seg=8, rot=(math.pi / 2, 0, 0)))
    return join(p, "fire_hydrant", (x, 0, 0))


def post_box(x):
    """A red pillar post box with a dome top and a posting slot towards -Y (Godot +Z), 1.25 m high."""
    p = [add("cyl", (0, 0, 0.58), (0.23, 0.23, 0.58), "gas", seg=14)]
    p.append(add("sphere", (0, 0, 1.15), (0.23, 0.23, 0.1), "gas", sub=2))
    p.append(add("cyl", (0, 0, 0.04), (0.26, 0.26, 0.04), "metal_dark", seg=14))
    p.append(add("cube", (0, -0.225, 0.9), (0.12, 0.012, 0.025), "plastic_dark", smooth=False))
    p.append(add("cyl", (0, 0, 1.06), (0.245, 0.245, 0.012), "metal_dark", seg=14))
    return join(p, "post_box", (x, 0, 0))


def drinks_fridge(x):
    """A shop drinks fridge: a red upright cabinet with a lit glass door and shelves of bottles, 0.7 x 0.7 x 1.9 m, door towards -Y (Godot +Z)."""
    p = [add("cube", (0, 0, 0.95), (0.35, 0.35, 0.95), "gas", smooth=False)]
    p.append(add("cube", (0, -0.355, 0.95), (0.3, 0.01, 0.8), "glow", smooth=False))              # the lit door
    for i in range(4):
        p.append(add("cube", (0, -0.36, 0.4 + i * 0.4), (0.28, 0.012, 0.04), "glass_green", smooth=False))   # bottles on the shelves
    p.append(add("cube", (0, -0.36, 1.78), (0.3, 0.012, 0.06), "cloth_b", smooth=False))          # the lit header
    return join(p, "drinks_fridge", (x, 0, 0))


def chest_freezer(x):
    """A white chest freezer with a sliding lid and a red ice sign, 1.3 x 0.65 x 0.9 m, front towards -Y (Godot +Z)."""
    p = [add("cube", (0, 0, 0.42), (0.65, 0.32, 0.42), "white_plastic", smooth=False)]
    p.append(add("cube", (0, 0, 0.86), (0.66, 0.33, 0.03), "cloth_b", smooth=False))
    p.append(add("cube", (0, -0.331, 0.5), (0.3, 0.006, 0.12), "cloth_c", smooth=False))          # the sign on the front
    return join(p, "chest_freezer", (x, 0, 0))


def a_frame(x):
    """An A-frame advertising board on the pavement, 0.6 m wide and 0.95 m high, the writing side towards -Y (Godot +Z)."""
    p = []
    for s in (-1, 1):
        p.append(add("cube", (0, 0.2 * s * 0.5, 0.48), (0.3, 0.012, 0.5), "cloth_d" if s < 0 else "wood_dark", rot=(0.18 * s, 0, 0), smooth=False))
    p.append(add("cube", (0, -0.1, 0.62), (0.22, 0.004, 0.14), "plastic_dark", rot=(-0.18, 0, 0), smooth=False))
    return join(p, "a_frame", (x, 0, 0))


def gas_cage(x):
    """A gas bottle exchange cage: a steel mesh cage holding four red gas bottles, 1.2 x 0.6 x 1.1 m."""
    p = [add("cube", (0, 0, 0.03), (0.6, 0.3, 0.03), "metal_dark", smooth=False)]
    for sx in (-0.58, 0.58):
        for sy in (-0.28, 0.28):
            p.append(add("cyl", (sx, sy, 0.55), (0.02, 0.02, 0.55), "metal_dark", seg=6))
    for sz in (0.2, 0.55, 1.08):
        p.append(add("cube", (0, 0, sz), (0.6, 0.3, 0.012), "metal_dark", smooth=False))
    for i in range(4):
        p.append(add("cyl", (-0.45 + i * 0.3, 0, 0.32), (0.11, 0.11, 0.28), "gas", seg=10))
    return join(p, "gas_cage", (x, 0, 0))


def tyre_stack(x):
    """A stack of four used tyres, 0.65 m across and 0.75 m high."""
    p = [add("torus", (0, 0, 0.1 + i * 0.18), (0.3, 0.3, 0.3), "rubber", minor=0.28, seg=14) for i in range(4)]
    return join(p, "tyre_stack", (x, 0, 0))


def oil_drums(x):
    """Three blue 200 litre oil drums standing together, 0.58 m across, 0.88 m high."""
    p = []
    for sx, sy in ((-0.3, 0.0), (0.3, 0.0), (0.0, 0.52)):
        p.append(add("cyl", (sx, sy, 0.44), (0.29, 0.29, 0.44), "cloth_c", seg=14))
        p.append(add("cyl", (sx, sy, 0.88), (0.3, 0.3, 0.02), "metal_dark", seg=14))
        p.append(add("cyl", (sx, sy, 0.3), (0.3, 0.3, 0.012), "metal_dark", seg=14))
        p.append(add("cyl", (sx, sy, 0.62), (0.3, 0.3, 0.012), "metal_dark", seg=14))
    return join(p, "oil_drums", (x, 0, 0))


def air_machine(x):
    """A forecourt tyre-air and water machine: a yellow pedestal with a coiled hose, 1.3 m high, face towards -Y (Godot +Z)."""
    p = [add("cube", (0, 0, 0.65), (0.2, 0.18, 0.65), "cloth_d", smooth=False)]
    p.append(add("cube", (0, -0.185, 1.05), (0.14, 0.01, 0.12), "screen", smooth=False))
    p.append(add("cube", (0, 0, 0.03), (0.28, 0.25, 0.03), "metal_dark", smooth=False))
    p.append(add("torus", (0.22, 0, 0.7), (0.1, 0.1, 0.1), "rubber", rot=(math.pi / 2, 0, 0), minor=0.2, seg=10))
    return join(p, "air_machine", (x, 0, 0))


def bollard(x):
    """A steel bollard with a yellow band, 0.9 m high."""
    p = [add("cyl", (0, 0, 0.45), (0.07, 0.07, 0.45), "metal", seg=10)]
    p.append(add("cyl", (0, 0, 0.72), (0.075, 0.075, 0.07), "cloth_d", seg=10))
    return join(p, "bollard", (x, 0, 0))


def price_pylon(x):
    """The pole of a forecourt price pylon: a 6.8 m steel column on a concrete base with a lamp on top (the price board is a panel)."""
    p = [add("cube", (0, 0, 0.2), (0.45, 0.45, 0.2), "counter_top", smooth=False)]
    p.append(add("cube", (0, 0, 3.4), (0.1, 0.1, 3.4), "metal_dark", smooth=False))
    p.append(add("sphere", (0, 0, 6.9), (0.16, 0.16, 0.12), "glow", sub=1))
    return join(p, "price_pylon", (x, 0, 0))


def crescent_finial(x):
    """A gold crescent and star on a short pole, for a mosque dome or minaret: 1.4 m tall, the crescent open upwards-and-forwards, in the XZ plane."""
    p = [add("cyl", (0, 0, 0.35), (0.025, 0.025, 0.35), "chrome", seg=6)]
    p.append(add("torus", (0, 0, 0.95), (0.22, 0.22, 0.22), "glow", rot=(math.pi / 2, 0, 0), minor=0.13, seg=14))
    p.append(add("sphere", (0.12, 0, 1.05), (0.07, 0.05, 0.07), "glow", sub=1))
    p.append(add("sphere", (0, 0, 1.38), (0.05, 0.05, 0.05), "glow", sub=1))
    return join(p, "crescent_finial", (x, 0, 0))


x = 0.0
for build in (wheelie_bin, lambda x: tree(x, "tree_a", 1.8, 7, 3), lambda x: tree(x, "tree_b", 2.4, 9, 11), aloe,
              satellite_dish, washing_line, tyre_planters, jojo_tank, plastic_chair, gas_bottle, crate,
              couch, lambda x: couch(x, "armchair", 0.95), coffee_table, tv_unit, kitchen_counter, stove, fridge,
              bed, wardrobe, dining_table, bar_counter, bottle_shelf, jukebox, pool_table, crate_stack, stash_crate,
              ceiling_lamp,
              bush, lambda x: bush(x, "bush_pink", "bloom_pink"), lambda x: bush(x, "bush_yellow", "bloom_yellow", 0.9), lambda x: bush(x, "bush_white", "bloom_white", 0.8),
              lambda x: flower_bed(x, "flowers_pink", "bloom_pink", "bloom_white"), lambda x: flower_bed(x, "flowers_yellow", "bloom_yellow", "bloom_red"),
              lambda x: flower_bed(x, "flowers_purple", "bloom_purple", "bloom_pink"),
              lambda x: grass_tuft(x, "grass_dry", "grass_dry", 0.55), lambda x: grass_tuft(x, "grass_green", "grass_green", 0.4),
              agave, palm, shade_tree, hedge, solar_geyser, braai_drum, kennel, bicycle, letterbox, park_bench, picnic_table, litter_bin, boulder, fallen_log, park_lamp, seesaw, spring_rider, monkey_bars, netball_post, flagpole, bike_rack, fire_hydrant, post_box, drinks_fridge, chest_freezer, a_frame, gas_cage, tyre_stack, oil_drums, air_machine, bollard, price_pylon, crescent_finial):
    build(x)
    x += 6.0

for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("WROTE", OUT, len([o for o in scene.objects if o.type == "MESH"]), "props")
