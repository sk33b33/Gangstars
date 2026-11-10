"""Builds the vehicle set: assets/models/vehicles/vehicles.glb.

Run headless:  blender -b --factory-startup --python tools/blender/build_vehicles.py
One object per vehicle (origin on the ground at the centre, front = -Y in Blender = +Z in Godot):
  hatch (3.9 m), sedan (4.4 m), bakkie (single cab + load bin, 4.6 m), taxi (minibus, 5.2 m),
  police (double-cab bakkie with canopy and light bar, 5.0 m; SAPS-inspired livery, no real crest).
Material slots are roles Godot recolours or swaps: paint (body colour), glass, trim (black
plastic), tyre, rim, chrome, headlight (shared night-glow lamp), taillight, plate_front (white),
plate_rear (yellow), police_blue, police_yellow, lightbar (flashes when responding).
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "vehicles", "vehicles.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(hexs):
    h = hexs.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mat(name, hexs, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexs), 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


M = {
    "paint": mat("paint", "#c0392b", 0.35), "glass": mat("glass", "#22303f", 0.1),
    "trim": mat("trim", "#1d1e22", 0.7), "tyre": mat("tyre", "#18181b", 0.95),
    "rim": mat("rim", "#b9bcc2", 0.35, 0.8), "chrome": mat("chrome", "#d8dadf", 0.2, 0.9),
    "headlight": mat("headlight", "#fff4d6", 0.2), "taillight": mat("taillight", "#b0202a", 0.3),
    "plate_front": mat("plate_front", "#f2f2ee", 0.6), "plate_rear": mat("plate_rear", "#f2c618", 0.6),
    "police_blue": mat("police_blue", "#123f8c", 0.4), "police_yellow": mat("police_yellow", "#f5c400", 0.4),
    "lightbar": mat("lightbar", "#2a6cff", 0.2),
}


def assign(o, name):
    o.data.materials.append(M[name])
    return o


def box(center, size, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    assign(o, material)
    if bevel > 0:
        _bevel(o, bevel, 2)
    return o


def cyl(center, radius, depth, material, axis="X", seg=16):
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=radius, depth=depth, location=center, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for p in o.data.polygons:
        p.use_smooth = True
    return assign(o, material)


def _bevel(o, width, segments):
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width = width
    bv.segments = segments
    bv.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier=bv.name)
    o.select_set(False)


def prism(profile, width, material, bevel=0.05, x0=0.0):
    """Side profile [(y, z), ...] (clockwise from the front-bottom) extruded across the width."""
    bm = bmesh.new()
    left = [bm.verts.new((x0 - width / 2, y, z)) for y, z in profile]
    right = [bm.verts.new((x0 + width / 2, y, z)) for y, z in profile]
    bm.faces.new(left)
    bm.faces.new(list(reversed(right)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("prism")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("prism", me)
    scene.collection.objects.link(o)
    assign(o, material)
    if bevel > 0:
        _bevel(o, bevel, 3)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def band(o, z_lo, z_hi, material):
    """Cut edge loops at z_lo/z_hi and paint the faces between them (livery stripes)."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for z in (z_lo, z_hi):
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, z), plane_no=(0, 0, 1))
    bm.to_mesh(o.data)
    bm.free()
    if material not in [m.name for m in o.data.materials]:
        o.data.materials.append(M[material])
    idx = [m.name for m in o.data.materials].index(material)
    for p in o.data.polygons:
        if z_lo < p.center.z < z_hi and abs(p.normal.z) < 0.7:
            p.material_index = idx


def wheels(parts, wheelbase, track, radius=0.32, width=0.22):
    for y in (-wheelbase / 2, wheelbase / 2):
        for s in (1, -1):
            x = s * track / 2
            parts.append(cyl((x, y, radius), radius, width, "tyre", seg=20))
            parts.append(cyl((x + s * (width / 2 + 0.005), y, radius), radius * 0.62, 0.02, "rim", seg=16))
            parts.append(cyl((x + s * (width / 2 + 0.012), y, radius), radius * 0.16, 0.02, "chrome", seg=8))
            # Dark wheel-arch lip on the body side.
            bpy.ops.mesh.primitive_torus_add(major_segments=20, minor_segments=4, major_radius=radius + 0.05,
                                             minor_radius=0.035, location=(x + s * 0.02, y, radius), rotation=(0, math.pi / 2, 0))
            arch = bpy.context.active_object
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            bm = bmesh.new()
            bm.from_mesh(arch.data)
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, radius - 0.02),
                                   plane_no=(0, 0, 1), clear_inner=True)
            bm.to_mesh(arch.data)
            bm.free()
            parts.append(assign(arch, "trim"))


def lights_and_plates(parts, front_y, rear_y, width, light_z, plate_z):
    for s in (1, -1):
        parts.append(box((s * (width / 2 - 0.22), front_y + 0.01, light_z), (0.34, 0.06, 0.13), "headlight", 0.015))
        parts.append(box((s * (width / 2 - 0.16), rear_y - 0.01, light_z), (0.22, 0.06, 0.16), "taillight", 0.015))
    parts.append(box((0, front_y - 0.005, plate_z), (0.52, 0.03, 0.12), "plate_front"))
    parts.append(box((0, rear_y + 0.005, plate_z), (0.52, 0.03, 0.12), "plate_rear"))
    parts.append(box((0, front_y + 0.005, light_z), (width - 0.85, 0.05, 0.12), "trim", 0.01))   # grille


def bumpers(parts, front_y, rear_y, width, z):
    parts.append(box((0, front_y - 0.02, z), (width + 0.04, 0.16, 0.2), "trim", 0.05))
    parts.append(box((0, rear_y + 0.02, z), (width + 0.04, 0.16, 0.2), "trim", 0.05))


def mirrors(parts, y, z, width):
    for s in (1, -1):
        parts.append(box((s * (width / 2 + 0.1), y, z), (0.16, 0.06, 0.1), "trim", 0.02))


def seams(parts, ys, z_lo, z_hi, width):
    for y in ys:
        for s in (1, -1):
            parts.append(box((s * (width / 2 + 0.004), y, (z_lo + z_hi) / 2), (0.01, 0.012, z_hi - z_lo), "trim"))


def cabin(parts, glass_profile, width, roof_y0, roof_y1, roof_z, pillars):
    parts.append(prism(glass_profile, width, "glass", 0.03))
    parts.append(box((0, (roof_y0 + roof_y1) / 2, roof_z), (width + 0.03, roof_y1 - roof_y0, 0.07), "paint", 0.03))
    for y0, z0, y1, z1 in pillars:   # A/B/C pillars as body-coloured strips over the glass
        for side in (1, -1):
            length = math.hypot(y1 - y0, z1 - z0)
            p = box((0, 0, 0), (0.02, 0.07, length), "paint")   # build at the origin, rotate, then place
            p.rotation_euler = (-math.atan2(y1 - y0, z1 - z0), 0, 0)
            bpy.context.view_layer.objects.active = p
            bpy.ops.object.transform_apply(rotation=True)
            p.location = (side * (width / 2 + 0.006), (y0 + y1) / 2, (z0 + z1) / 2)
            bpy.ops.object.transform_apply(location=True)
            parts.append(p)


def finish(parts, name, offset_x):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = o.data.name = name
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    o.location.x = offset_x
    return o


def hatch():
    W, F, R = 1.7, -1.95, 1.95
    p = [prism([(F, 0.3), (F - 0.03, 0.62), (F + 0.08, 0.78), (-1.2, 0.86), (1.85, 0.9), (R, 0.76), (R, 0.3)], W, "paint")]
    cabin(p, [(-1.15, 0.86), (-0.45, 1.38), (1.35, 1.42), (1.8, 0.9)], W - 0.14, -0.45, 1.35, 1.42,
          [(-1.15, 0.87, -0.45, 1.38), (0.45, 0.88, 0.45, 1.4), (1.8, 0.9, 1.35, 1.42)])
    wheels(p, 2.45, 1.48, 0.31)
    lights_and_plates(p, F, R, W, 0.7, 0.45)
    bumpers(p, F, R, W, 0.38)
    mirrors(p, -0.95, 0.98, W)
    seams(p, [-1.05, 0.4], 0.38, 0.86, W)
    return finish(p, "hatch", 0)


def sedan():
    W, F, R = 1.76, -2.2, 2.2
    p = [prism([(F, 0.3), (F - 0.02, 0.62), (F + 0.1, 0.76), (-1.2, 0.84), (1.4, 0.86), (R - 0.05, 0.82), (R, 0.6), (R, 0.3)], W, "paint")]
    cabin(p, [(-1.1, 0.84), (-0.35, 1.38), (0.95, 1.4), (1.6, 0.86)], W - 0.14, -0.35, 0.95, 1.4,
          [(-1.1, 0.85, -0.35, 1.38), (0.35, 0.86, 0.35, 1.39), (1.6, 0.86, 0.95, 1.4)])
    wheels(p, 2.65, 1.52, 0.32)
    lights_and_plates(p, F, R, W, 0.68, 0.44)
    bumpers(p, F, R, W, 0.36)
    mirrors(p, -0.85, 0.96, W)
    seams(p, [-0.95, 0.35, 1.45], 0.36, 0.84, W)
    return finish(p, "sedan", 6)


def bakkie_base(W, F, R, cab_back, height=0.96):
    return [prism([(F, 0.36), (F - 0.02, 0.68), (F + 0.12, 0.88), (-1.3, height), (R, height), (R + 0.02, 0.42)], W, "paint", 0.04)]


def bakkie():
    W, F, R = 1.76, -2.3, 2.3
    p = bakkie_base(W, F, R, 0.0)
    cabin(p, [(-1.25, 0.96), (-0.6, 1.6), (0.0, 1.62), (0.0, 0.96)], W - 0.12, -0.6, 0.02, 1.62,
          [(-1.25, 0.97, -0.6, 1.6), (0.0, 0.97, 0.0, 1.62)])
    # Open load bin: two side walls, tailgate, floor.
    for s in (1, -1):
        p.append(box((s * (W / 2 - 0.04), 1.17, 1.18), (0.07, 2.25, 0.44), "paint", 0.02))
    p.append(box((0, R - 0.04, 1.18), (W, 0.07, 0.44), "paint", 0.02))
    p.append(box((0, 1.17, 0.98), (W - 0.1, 2.25, 0.04), "trim"))
    wheels(p, 3.0, 1.52, 0.34)
    lights_and_plates(p, F, R, W, 0.74, 0.5)
    bumpers(p, F, R, W, 0.42)
    mirrors(p, -1.0, 1.1, W)
    seams(p, [-1.2, -0.05], 0.42, 0.96, W)
    return finish(p, "bakkie", 12)


def police():
    """Double cab with a canopy (prisoner section) and a roof light bar."""
    W, F, R = 1.84, -2.5, 2.5
    p = bakkie_base(W, F, R, 0.6, 0.98)
    band(p[0], 0.5, 0.74, "police_blue")
    band(p[0], 0.76, 0.81, "police_yellow")
    cabin(p, [(-1.35, 0.98), (-0.7, 1.62), (0.6, 1.64), (0.6, 0.98)], W - 0.12, -0.7, 0.62, 1.64,
          [(-1.35, 0.99, -0.7, 1.62), (-0.05, 0.99, -0.05, 1.63), (0.6, 0.99, 0.6, 1.64)])
    can = box((0, 1.56, 1.32), (W - 0.04, 1.86, 0.68), "paint", 0.04)
    band(can, 1.05, 1.12, "police_blue")
    p.append(can)
    for s in (1, -1):   # small barred canopy windows
        p.append(box((s * (W / 2 - 0.01), 1.6, 1.42), (0.02, 1.2, 0.28), "glass"))
        for k in range(5):
            p.append(box((s * (W / 2 + 0.005), 1.1 + k * 0.24, 1.42), (0.015, 0.025, 0.3), "trim"))
    # Light bar on the cab roof.
    p.append(box((0, -0.05, 1.72), (1.25, 0.24, 0.1), "trim", 0.02))
    for s in (1, -1):
        p.append(box((s * 0.33, -0.05, 1.79), (0.54, 0.22, 0.1), "lightbar", 0.03))
    wheels(p, 3.1, 1.58, 0.35)
    lights_and_plates(p, F, R, W, 0.78, 0.52)
    bumpers(p, F, R, W, 0.44)
    p.append(box((0, F - 0.12, 0.62), (1.1, 0.08, 0.5), "trim", 0.03))   # nudge bar
    mirrors(p, -1.1, 1.1, W)
    seams(p, [-1.3, -0.05, 0.62], 0.44, 0.98, W)
    return finish(p, "police", 18)


def taxi():
    """Minibus taxi: tall van with a window band all round and a sliding door line."""
    W, F, R = 1.9, -2.6, 2.6
    p = [prism([(F, 0.35), (F - 0.03, 0.75), (F + 0.15, 1.05), (-2.0, 1.95), (R - 0.1, 2.02), (R, 1.9), (R, 0.35)], W, "paint", 0.06)]
    for s in (1, -1):
        p.append(box((s * (W / 2 + 0.004), 0.35, 1.52), (0.012, 4.0, 0.5), "glass"))
        for y in (-1.0, 0.0, 0.9, 1.75):
            p.append(box((s * (W / 2 + 0.008), y, 1.52), (0.01, 0.07, 0.5), "paint"))
    p.append(prism([(F + 0.17, 1.07), (-2.02, 1.88), (-1.95, 1.88), (F + 0.24, 1.07)], W - 0.16, "glass", 0.0))
    p.append(box((0, R + 0.005, 1.5), (W - 0.4, 0.012, 0.45), "glass"))
    wheels(p, 3.1, 1.62, 0.33)
    lights_and_plates(p, F, R, W, 0.8, 0.5)
    bumpers(p, F, R, W, 0.42)
    mirrors(p, -2.2, 1.25, W)
    seams(p, [-1.75, -0.3, 1.3], 0.42, 1.25, W)
    for s in (1, -1):   # roof rails
        p.append(box((s * 0.6, -0.1, 2.06), (0.05, 3.2, 0.05), "trim", 0.01))
    return finish(p, "taxi", 24)


for build in (hatch, sedan, bakkie, police, taxi):
    build()
for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("WROTE", OUT, [(o.name, len(o.data.vertices)) for o in scene.objects if o.type == "MESH"])
