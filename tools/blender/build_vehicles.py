"""Builds the vehicle set: assets/models/vehicles/vehicles.glb.

Run headless:  blender -b --factory-startup --python tools/blender/build_vehicles.py
One object per vehicle (origin on the ground at the centre, front = -Y in Blender = +Z in Godot):
  hatch (3.9 m), sedan (4.4 m), bakkie (single cab + load bin, 4.6 m), taxi (minibus, 5.2 m),
  police (double-cab bakkie with canopy and light bar, 5.0 m; SAPS-inspired livery, no real crest),
  skoro (a rusty old boxy sedan with a mismatched door, 4.3 m).
Cabins have interiors (dash, right-hand-drive wheel, seats) behind see-through glass; empties
"<model>_seat_N" (driver first) place the occupant_driver / occupant_passenger busts. Bodies
carry vertex colours (road grime) that Godot uses on dirty cars. "tint" is opaque dark glass
(taxi and canopy windows, which have a solid body behind them).
Material slots are roles Godot recolours or swaps: paint (body colour), glass, trim (black
plastic), tyre, rim, chrome, headlight (shared night-glow lamp), taillight, plate_front (white),
plate_rear (yellow), police_blue, police_yellow, lightbar (flashes when responding),
indicator_L / indicator_R (blink when turning).
Wheels are separate meshes "<model>_tyre" (axle X, outer face +X) so Godot can spin and steer
them; empties "<model>_axle_0..3" (front pair first) and "<model>_plate_front/rear" are
children of each body and mark where they go.
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
    "tint": mat("tint", "#1b232c", 0.1), "seat": mat("seat", "#2c2c31", 0.9), "rust": mat("rust", "#7a3f22", 0.95),
    "paint2": mat("paint2", "#8f949a", 0.6), "occ_shirt": mat("occ_shirt", "#3f5874", 0.9),
    "occ_skin": mat("occ_skin", "#8d5a3b", 0.6), "occ_hair": mat("occ_hair", "#1d1b24", 0.9),
    "indicator_L": mat("indicator_L", "#e8901c", 0.3), "indicator_R": mat("indicator_R", "#e8901c", 0.3),
}
# Filled while a vehicle is built, turned into marker empties by finish():
# wheels (x, y, radius, width) and plates (name, (x, y, z)).
PENDING = {"wheels": [], "plates": [], "seats": []}


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
    """Records the four wheels (separate spinning meshes, see wheel_mesh) and adds the dark
    wheel-arch lips to the body."""
    for y in (-wheelbase / 2, wheelbase / 2):
        for s in (1, -1):
            x = s * track / 2
            PENDING["wheels"].append((x, y, radius, width))
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
            # Dark arch liner so you don't see daylight through the body above the wheel.
            parts.append(box((x - s * 0.05, y, radius + 0.08), (0.08, radius * 2.1, 0.04), "trim"))


def wheel_mesh(name, radius, width):
    """One wheel at the origin, axle along X, outer face +X: tyre with a sidewall bulge, a
    five-spoke rim and a chrome hub (the spokes make the spin readable)."""
    parts = [cyl((0, 0, 0), radius, width, "tyre", seg=24)]
    parts.append(cyl((0, 0, 0), radius * 0.93, width + 0.02, "tyre", seg=24))   # sidewall bulge
    parts.append(cyl((width / 2 + 0.008, 0, 0), radius * 0.64, 0.012, "trim", seg=20))   # dark well behind the spokes
    ring = cyl((width / 2 + 0.014, 0, 0), radius * 0.64, 0.016, "rim", seg=20)
    inner = cyl((width / 2 + 0.014, 0, 0), radius * 0.54, 0.03, "rim", seg=20)
    diff = ring.modifiers.new("cut", "BOOLEAN")
    diff.operation = "DIFFERENCE"
    diff.object = inner
    bpy.context.view_layer.objects.active = ring
    bpy.ops.object.modifier_apply(modifier=diff.name)
    bpy.data.objects.remove(inner)
    parts.append(ring)
    for k in range(5):
        a = k * 2 * math.pi / 5
        spoke = box((0, 0, 0), (0.02, 0.05, radius * 0.56), "rim")
        spoke.location = (width / 2 + 0.016, math.sin(a) * radius * 0.3, math.cos(a) * radius * 0.3)
        spoke.rotation_euler = (-a, 0, 0)
        bpy.context.view_layer.objects.active = spoke
        bpy.ops.object.transform_apply(location=True, rotation=True)
        parts.append(spoke)
    parts.append(cyl((width / 2 + 0.024, 0, 0), radius * 0.16, 0.02, "chrome", seg=10))
    for k in range(4):   # wheel nuts
        a = k * math.pi / 2 + math.pi / 4
        parts.append(cyl((width / 2 + 0.03, math.sin(a) * radius * 0.1, math.cos(a) * radius * 0.1), 0.012, 0.012, "chrome", seg=6))
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = o.data.name = name
    return o


def lights_and_plates(parts, front_y, rear_y, width, light_z, plate_z):
    for s in (1, -1):
        parts.append(box((s * (width / 2 - 0.22), front_y + 0.01, light_z), (0.34, 0.06, 0.13), "headlight", 0.015))
        parts.append(box((s * (width / 2 - 0.16), rear_y - 0.01, light_z), (0.22, 0.06, 0.16), "taillight", 0.015))
        # Amber indicators: beside the headlights, inboard of the tail lights.
        ind = "indicator_L" if s > 0 else "indicator_R"
        parts.append(box((s * (width / 2 - 0.02), front_y + 0.03, light_z), (0.07, 0.06, 0.11), ind, 0.01))
        parts.append(box((s * (width / 2 - 0.32), rear_y - 0.012, light_z), (0.07, 0.05, 0.13), ind, 0.01))
    parts.append(box((0, front_y - 0.005, plate_z), (0.52, 0.03, 0.12), "plate_front"))
    parts.append(box((0, rear_y + 0.005, plate_z), (0.52, 0.03, 0.12), "plate_rear"))
    PENDING["plates"] += [("plate_front", (0, front_y - 0.022, plate_z)), ("plate_rear", (0, rear_y + 0.022, plate_z))]
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


def interior(parts, W, dash_y, belt, rows, ws_top=None, roof=None):
    """What you see through the windows: dashboard, right-hand-drive steering wheel, seats with
    headrests, a rear-view mirror; records seat markers (driver first) for occupants."""
    parts.append(box((0, dash_y, belt - 0.02), (W - 0.2, 0.32, 0.14), "trim", 0.03))
    wx, wy, wz = -0.37, dash_y + 0.3, belt + 0.1          # driver sits on the right (Blender -X)
    bpy.ops.mesh.primitive_torus_add(major_segments=20, minor_segments=6, major_radius=0.16, minor_radius=0.018,
                                     location=(wx, wy, wz), rotation=(1.15, 0, 0))
    ring = bpy.context.active_object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    parts.append(assign(ring, "trim"))
    parts.append(cyl((wx, (wy + dash_y) / 2, wz - 0.04), 0.025, 0.3, "trim", axis="Y", seg=8))
    if ws_top and roof:
        parts.append(box((0, ws_top[0] + 0.12, ws_top[1] - 0.07), (0.2, 0.03, 0.06), "trim", 0.01))
    for k, y in enumerate(rows):
        xs = (-0.37, 0.37) if k == 0 else (-0.4, 0.0, 0.4)
        for x in (-0.37, 0.37) if k == 0 else (-0.4, 0.4):
            parts.append(box((x, y + 0.2, belt + 0.06), (0.44, 0.12, 0.5), "seat", 0.04))
            parts.append(box((x, y + 0.22, belt + 0.38), (0.24, 0.09, 0.15), "seat", 0.03))
        for x in xs:
            PENDING["seats"].append((x, y, belt - 0.3))


def handles(parts, ys, z, W):
    for y in ys:
        for s in (1, -1):
            parts.append(box((s * (W / 2 + 0.012), y, z), (0.02, 0.14, 0.03), "trim", 0.008))


def wipers(parts, y, z):
    for x in (-0.28, 0.2):
        w = box((0, 0, 0), (0.5, 0.018, 0.014), "trim")
        w.rotation_euler = (0, 0, 0.12)
        bpy.context.view_layer.objects.active = w
        bpy.ops.object.transform_apply(rotation=True)
        w.location = (x, y, z)
        bpy.ops.object.transform_apply(location=True)
        parts.append(w)


def extras(parts, F, R, W, belt, light_z, exhaust_z=0.3, flaps=False, wheelbase=0.0):
    """Grille slats, side indicator repeaters, exhaust, optional mud flaps."""
    for dz in (-0.03, 0.03):
        parts.append(box((0, F - 0.02, light_z + dz), (W - 0.9, 0.02, 0.015), "chrome"))
    for s in (1, -1):
        parts.append(box((s * (W / 2 + 0.006), F + 0.55, belt - 0.12), (0.012, 0.07, 0.03),
                         "indicator_L" if s > 0 else "indicator_R", 0.005))
    parts.append(cyl((0.45, R + 0.06, exhaust_z), 0.032, 0.18, "chrome", axis="Y", seg=10))
    if flaps:
        for s in (1, -1):
            parts.append(box((s * (W / 2 - 0.12), wheelbase / 2 + 0.42, 0.28), (0.22, 0.012, 0.3), "trim"))


def dirt(o, strength=1.0):
    """Vertex colours: road grime fading up from the sills (Godot multiplies a dirty car's
    paint by them; clean cars ignore them)."""
    me = o.data
    if "Col" not in me.color_attributes:
        me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    col = me.color_attributes["Col"]
    for poly in me.polygons:
        for li in poly.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            g = max(0.0, min(1.0, (0.85 - z) / 0.55)) * 0.55 * strength
            col.data[li].color = (1.0 - g * 0.3, 1.0 - g * 0.4, 1.0 - g * 0.55, 1.0)


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
    # Marker empties (children of the body, so Godot reads their local positions): axle_0..3
    # (never "wheel" in a name: Godot's importer turns those into VehicleWheel3D nodes)
    # (front pair first) and the plate centres. The wheel itself is one shared mesh per model.
    ws = sorted(PENDING["wheels"], key=lambda w: (w[1], -w[0]))
    for i, (x, y, r, wd) in enumerate(ws):
        e = bpy.data.objects.new("%s_axle_%d" % (name, i), None)
        scene.collection.objects.link(e)
        e.parent = o
        e.location = (x, y, r)
    for pname, at in PENDING["plates"]:
        e = bpy.data.objects.new("%s_%s" % (name, pname), None)
        scene.collection.objects.link(e)
        e.parent = o
        e.location = at
    for i, at in enumerate(PENDING["seats"]):
        e = bpy.data.objects.new("%s_seat_%d" % (name, i), None)
        scene.collection.objects.link(e)
        e.parent = o
        e.location = at
    PENDING["seats"] = []
    dirt(o, 1.6 if name == "skoro" else 1.0)
    if ws:
        w = wheel_mesh(name + "_tyre", ws[0][2], ws[0][3])
        w.location = (offset_x, -8, ws[0][2])
    PENDING["wheels"] = []
    PENDING["plates"] = []
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
    interior(p, W, -0.92, 0.88, [-0.05, 0.75], (-0.45, 1.38), 1.42)
    handles(p, [0.22], 0.78, W)
    wipers(p, -1.08, 0.9)
    extras(p, F, R, W, 0.86, 0.7)
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
    interior(p, W, -0.85, 0.84, [-0.05, 0.75], (-0.35, 1.38), 1.4)
    handles(p, [0.18, 1.28], 0.76, W)
    wipers(p, -1.03, 0.87)
    extras(p, F, R, W, 0.84, 0.68)
    p.append(cyl((-0.3, 0.9, 1.6), 0.006, 0.4, "trim", axis="Z", seg=6))   # aerial
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
    interior(p, W, -1.05, 0.96, [-0.38], (-0.6, 1.6), 1.62)
    handles(p, [-0.2], 0.88, W)
    wipers(p, -1.18, 0.99)
    extras(p, F, R, W, 0.96, 0.74, 0.36, True, 3.0)
    p.append(box((0, R + 0.1, 0.42), (0.12, 0.2, 0.06), "trim"))        # tow bar
    p.append(cyl((0, R + 0.2, 0.48), 0.03, 0.06, "chrome", axis="Z", seg=8))
    return finish(p, "bakkie", 12)


def police():
    """Double cab with a canopy (prisoner section) and a roof light bar."""
    W, F, R = 1.84, -2.5, 2.5
    p = bakkie_base(W, F, R, 0.6, 0.98)
    # Livery from reference photos: a blue band edged in yellow above and below.
    band(p[0], 0.56, 0.6, "police_yellow")
    band(p[0], 0.6, 0.72, "police_blue")
    band(p[0], 0.72, 0.76, "police_yellow")
    cabin(p, [(-1.35, 0.98), (-0.7, 1.62), (0.6, 1.64), (0.6, 0.98)], W - 0.12, -0.7, 0.62, 1.64,
          [(-1.35, 0.99, -0.7, 1.62), (-0.05, 0.99, -0.05, 1.63), (0.6, 0.99, 0.6, 1.64)])
    can = box((0, 1.56, 1.32), (W - 0.04, 1.86, 0.68), "paint", 0.04)
    band(can, 1.53, 1.6, "police_blue")
    band(can, 1.5, 1.53, "police_yellow")
    p.append(can)
    for s in (1, -1):   # small barred canopy windows
        p.append(box((s * (W / 2 - 0.01), 1.6, 1.42), (0.02, 1.2, 0.28), "tint"))
        for k in range(5):
            p.append(box((s * (W / 2 + 0.005), 1.1 + k * 0.24, 1.42), (0.015, 0.025, 0.3), "trim"))
    # Light bar on the cab roof.
    p.append(box((0, -0.05, 1.72), (1.25, 0.24, 0.1), "trim", 0.02))
    for s in (1, -1):
        p.append(box((s * 0.33, -0.05, 1.79), (0.54, 0.22, 0.1), "lightbar", 0.03))
    wheels(p, 3.1, 1.58, 0.35)
    lights_and_plates(p, F, R, W, 0.78, 0.52)
    bumpers(p, F, R, W, 0.44)
    for s in (1, -1):   # chrome bull bar
        p.append(cyl((s * 0.42, F - 0.16, 0.6), 0.03, 0.55, "chrome", axis="Z", seg=10))
    p.append(cyl((0, F - 0.16, 0.86), 0.03, 0.9, "chrome", axis="X", seg=10))
    p.append(cyl((0, F - 0.16, 0.5), 0.03, 0.9, "chrome", axis="X", seg=10))
    mirrors(p, -1.1, 1.1, W)
    seams(p, [-1.3, -0.05, 0.62], 0.44, 0.98, W)
    interior(p, W, -1.15, 0.98, [-0.5, 0.25], (-0.7, 1.62), 1.64)
    handles(p, [-0.2, 0.47], 0.9, W)
    wipers(p, -1.28, 1.01)
    extras(p, F, R, W, 0.98, 0.78, 0.38, True, 3.1)
    return finish(p, "police", 18)


def taxi():
    """Minibus taxi: tall van with a window band all round and a sliding door line."""
    W, F, R = 1.9, -2.6, 2.6
    p = [prism([(F, 0.35), (F - 0.03, 0.75), (F + 0.15, 1.05), (-2.0, 1.95), (R - 0.1, 2.02), (R, 1.9), (R, 0.35)], W, "paint", 0.06)]
    for s in (1, -1):
        p.append(box((s * (W / 2 + 0.004), 0.35, 1.52), (0.012, 4.0, 0.5), "tint"))
        for y in (-1.0, 0.0, 0.9, 1.75):
            p.append(box((s * (W / 2 + 0.008), y, 1.52), (0.01, 0.07, 0.5), "paint"))
    p.append(prism([(F + 0.17, 1.07), (-2.02, 1.88), (-1.95, 1.88), (F + 0.24, 1.07)], W - 0.16, "tint", 0.0))
    p.append(box((0, R + 0.005, 1.5), (W - 0.4, 0.012, 0.45), "tint"))
    wheels(p, 3.1, 1.62, 0.33)
    lights_and_plates(p, F, R, W, 0.8, 0.5)
    bumpers(p, F, R, W, 0.42)
    mirrors(p, -2.2, 1.25, W)
    seams(p, [-1.75, -0.3, 1.3], 0.42, 1.25, W)
    for s in (1, -1):   # roof rails
        p.append(box((s * 0.6, -0.1, 2.06), (0.05, 3.2, 0.05), "trim", 0.01))
    handles(p, [-1.55, -0.1], 1.12, W)
    for s in (1, -1):   # sliding door rail
        p.append(box((s * (W / 2 + 0.01), 0.6, 1.24), (0.012, 1.6, 0.025), "trim"))
    wipers(p, F + 0.24, 1.1)
    extras(p, F, R, W, 1.15, 0.8, 0.36, True, 3.1)
    return finish(p, "taxi", 24)


def skoro():
    """The skorokoro: a tired old boxy sedan with a door from another car, primer patches,
    rust on the sills and arches, a dented flank and a rear bumper hanging a bit low."""
    W, F, R = 1.68, -2.15, 2.15
    body = prism([(F, 0.32), (F - 0.02, 0.66), (F + 0.06, 0.8), (-1.15, 0.84), (1.45, 0.86), (R - 0.04, 0.84), (R, 0.62), (R, 0.32)],
                 W, "paint", 0.02)
    for v in body.data.vertices:   # dents: push in a few spots on the flanks
        if v.co.x > W / 2 - 0.03:
            d = math.exp(-((v.co.y - 0.9) / 0.35) ** 2) * math.exp(-((v.co.z - 0.6) / 0.15) ** 2)
            v.co.x -= 0.035 * d
    p = [body]
    cabin(p, [(-1.1, 0.84), (-0.42, 1.36), (0.95, 1.38), (1.55, 0.86)], W - 0.12, -0.42, 0.95, 1.38,
          [(-1.1, 0.85, -0.42, 1.36), (0.3, 0.86, 0.3, 1.37), (1.55, 0.86, 0.95, 1.38)])
    p.append(box((-(W / 2 + 0.006), -0.35, 0.6), (0.012, 1.15, 0.44), "paint2"))   # the other car's door
    for y, z, sx, sz in ((-1.35, 0.45, 0.4, 0.14), (1.3, 0.42, 0.5, 0.12), (0.3, 0.36, 0.7, 0.07), (-0.6, 0.37, 0.4, 0.06)):
        for s in (1, -1):
            p.append(box((s * (W / 2 + 0.008), y, z), (0.012, sx, sz), "rust", 0.004))
    p.append(box((0.3, -1.62, 0.83), (0.5, 0.45, 0.014), "paint2"))   # a primer patch on the bonnet
    wheels(p, 2.55, 1.46, 0.3)
    lights_and_plates(p, F, R, W, 0.66, 0.43)
    p.append(box((0, F - 0.02, 0.36), (W + 0.02, 0.15, 0.17), "chrome", 0.04))   # old chrome bumper
    rb = box((0, 0, 0), (W + 0.02, 0.15, 0.17), "chrome", 0.04)
    rb.rotation_euler = (0, 0.05, 0)
    bpy.context.view_layer.objects.active = rb
    bpy.ops.object.transform_apply(rotation=True)
    rb.location = (0, R + 0.03, 0.31)
    bpy.ops.object.transform_apply(location=True)
    p.append(rb)
    mirrors(p, -0.9, 0.95, W)
    seams(p, [-0.95, 0.3, 1.45], 0.34, 0.84, W)
    interior(p, W, -0.85, 0.84, [-0.05, 0.75], (-0.42, 1.36), 1.38)
    handles(p, [0.15, 1.3], 0.76, W)
    wipers(p, -1.03, 0.87)
    extras(p, F, R, W, 0.84, 0.66)
    return finish(p, "skoro", 30)


def occupants():
    """Drivers and passengers seen through the windows: a seated upper body (origin at the hip),
    arms to the wheel for the driver, in the lap for passengers. Godot recolours occ_*."""
    for kind in ("driver", "passenger"):
        parts = [box((0, 0.02, 0.28), (0.36, 0.2, 0.5), "occ_shirt", 0.06)]
        parts.append(cyl((0, 0.02, 0.57), 0.05, 0.1, "occ_skin", axis="Z", seg=10))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1, location=(0, 0.0, 0.7))
        head = bpy.context.active_object
        head.scale = (0.088, 0.1, 0.11)
        bpy.ops.object.transform_apply(scale=True)
        parts.append(assign(head, "occ_skin"))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1, location=(0, 0.01, 0.725))
        hair = bpy.context.active_object
        hair.scale = (0.093, 0.106, 0.1)
        bpy.ops.object.transform_apply(scale=True)
        parts.append(assign(hair, "occ_hair"))
        for s in (1, -1):
            if kind == "driver":
                a, b = Vector((0.17 * s, 0.0, 0.48)), Vector((0.14 * s, -0.42, 0.42))
            else:
                a, b = Vector((0.19 * s, 0.0, 0.48)), Vector((0.16 * s, -0.18, 0.12))
            mid, d = (a + b) / 2, (b - a)
            arm = cyl((0, 0, 0), 0.04, d.length, "occ_shirt", axis="Z", seg=8)
            arm.rotation_euler = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
            bpy.context.view_layer.objects.active = arm
            bpy.ops.object.transform_apply(rotation=True)
            arm.location = mid
            bpy.ops.object.transform_apply(location=True)
            parts.append(arm)
            parts.append(assign(_sphere(b, 0.035), "occ_skin"))   # hand
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        o = bpy.context.active_object
        o.name = o.data.name = "occupant_" + kind
        o.location.x = 40 + (2 if kind == "passenger" else 0)


def _sphere(at, r):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=r, location=at)
    return bpy.context.active_object


for build in (hatch, sedan, bakkie, police, taxi, skoro):
    build()
occupants()
for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True,
                          export_vertex_color="ACTIVE")
print("WROTE", OUT, [(o.name, len(o.data.vertices)) for o in scene.objects if o.type == "MESH"])
