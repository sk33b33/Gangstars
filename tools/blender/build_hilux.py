"""Builds the SAPS bakkie: assets/models/vehicles/hilux.glb, from the "SAPN Hilux" model by stephen.williams (https://skfb.ly/6SAY8,
Creative Commons Attribution-NonCommercial 4.0: credit in docs/CREDITS.md and the game's credits; the licence forbids commercial use), saved as
art/source/sapn_hilux.glb (21 000 triangles, four 1024 px textures, a canopy on the tray, a power company's logo and baked-in mud).

Run headless:  blender -b --factory-startup --python tools/blender/build_hilux.py

It is the model "police" (VehicleLibrary.EXTRA_SOURCES), the vehicle only the SAPS use:
  * scaled to a real double cab (5.4 m long), the wheelbase put in the middle, front = -Y in Blender (+Z in Godot);
  * the textures are only read, never kept (so the company logo and the mud do not reach the game): each face of the cab and the canopy gets
    a role by the colour the texture has on it (vehicle_common.py): paint (white, for the police), glass, trim, headlight; the wheels are cut out
    of the model's one wheel mesh, the front right one becomes "police_tyre" (axle along X, outer face +X, tyre and rim by radius);
  * a light bar on the cab roof (material "lightbar", which flashes blue when the police respond) and empties police_axle_0..3 (front pair first),
    police_plate_front/rear and police_seat_0..3 (driver first, on the -X side) under the body "police".
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_common as vc  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "source", "sapn_hilux.glb")
OUT = os.path.join(ROOT, "assets", "models", "vehicles", "hilux.glb")
NAME = "police"
LENGTH = 5.4

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene = bpy.context.scene
ROLES = vc.make_roles()

meshes = {}
for o in [o for o in scene.objects if o.type == "MESH"]:
    vc.detach(o)
for o in [o for o in scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)
for o in [o for o in scene.objects if o.type == "MESH"]:
    vc.apply_transform(o)
    meshes[o.name] = o
bpy.data.objects.remove(meshes.pop("Icosphere"))   # a stray sphere at the origin
textures = {m.name: vc.Texture(m.node_tree.nodes[[n.name for n in m.node_tree.nodes if n.type == "TEX_IMAGE"][0]].image)
            for m in bpy.data.materials if m.use_nodes and any(n.type == "TEX_IMAGE" for n in m.node_tree.nodes)}

# The model's own numbers: wheelbase y -1.46 / +1.54, wheel centre z -0.40, tyre radius 0.345, outer face x 0.8, length 4.66.
S = LENGTH / 4.66
GROUND = -0.75
FRONT_Y, REAR_Y, WHEEL_Z, WHEEL_R, OUTER_X = -1.46, 1.54, -0.40, 0.345, 0.80
SHIFT = Vector((0.0, -(FRONT_Y + REAR_Y) / 2, -GROUND))


def classify(o, glass_below_belt=0.2):
    mat = o.material_slots[0].material.name
    tex = textures[mat]
    roles = []
    for p in o.data.polygons:
        col = vc.face_colour(o, p, tex)
        b, sat = vc.brightness(col), vc.saturation(col)
        c = vc.face_centroid(o, p)
        if "Windows" in mat:
            roles.append("headlight" if b > 0.45 and abs(c.x) > 0.3 else "trim")   # the lamps at the corners, the grille between
        elif b < 0.14 and c.z > glass_below_belt and abs(c.x) < 0.88:
            roles.append("glass")
        elif b < 0.22 and sat < 0.18:
            roles.append("trim")   # black plastic and the bull bar; the grey mud on the panels counts as paint
        else:
            roles.append("paint")   # white, mud and the logo's orange: all become white paint
    return roles


parts = []
for name, o in list(meshes.items()):
    if name == "Object_5":
        continue   # the wheels, below
    mat = o.material_slots[0].material.name
    if name in ("Object_12", "Object_13", "Object_14"):
        roles = ["glass"] * len(o.data.polygons)   # the canopy's windows
    else:
        roles = classify(o)
    parts += list(vc.split_by_role(o, roles, ROLES, name).values())
    bpy.data.objects.remove(o)

# The four wheels are one mesh: the front right wheel (+X, front), by faces outside x = 0.5 (what is inboard is axle under the car).
wheels = meshes["Object_5"]
bm = bmesh.new()
bm.from_mesh(wheels.data)
bm.faces.ensure_lookup_table()
keep = []
for f in bm.faces:
    c = sum((v.co for v in f.verts), Vector()) / len(f.verts)
    if c.x > 0.5 and c.y < 0.0:
        keep.append(f)
drop = [f for f in bm.faces if f not in keep]
bmesh.ops.delete(bm, geom=drop, context="FACES")
bm.to_mesh(wheels.data)
bm.free()
centre = Vector((OUTER_X - 0.115, FRONT_Y, WHEEL_Z))
wheel_roles = []
for p in wheels.data.polygons:
    c = sum((wheels.data.vertices[v].co for v in p.vertices), Vector()) / len(p.vertices)
    r = math.hypot(c.y - centre.y, c.z - centre.z)
    wheel_roles.append("rim" if r < WHEEL_R * 0.62 else "tyre")
wheel_parts = list(vc.split_by_role(wheels, wheel_roles, ROLES, "wheel").values())
bpy.data.objects.remove(wheels)

for o in parts + wheel_parts:
    vc.apply_transform(o)
for o in parts:
    for v in o.data.vertices:
        v.co = (v.co + SHIFT) * S
    o.data.update()
    vc.weld(o, 0.002)
for o in wheel_parts:
    for v in o.data.vertices:
        v.co = (v.co - centre) * S
    o.data.update()
    vc.weld(o, 0.002)

# Decimate what is dense: the cab is 13 000 triangles.
for o in parts:
    vc.decimate(o, 0.5 if "paint" in o.name else 0.6)
for o in wheel_parts:
    vc.decimate(o, 0.8)

# A light bar on the cab roof.
roof_z = max(v.co.z for o in parts for v in o.data.vertices if v.co.y < -0.4 and v.co.y > -1.4 and abs(v.co.x) < 0.5 and v.co.z < 1.9)
bar = []
bar_y = -0.55
vc.box(scene, bar, ROLES, (0, bar_y, roof_z + 0.03), (0.42, 1.0, 0.05), "trim")
vc.box(scene, bar, ROLES, (-0.25, bar_y, roof_z + 0.09), (0.2, 0.9, 0.09), "lightbar")
vc.box(scene, bar, ROLES, (0.25, bar_y, roof_z + 0.09), (0.2, 0.9, 0.09), "lightbar")
parts += bar
body = vc.join(parts, NAME)
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
wheel = vc.join(wheel_parts, NAME + "_tyre")
wheel.location = (0, -8, 0)
vc.select_only(wheel)
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
radius = WHEEL_R * S


def marker(name, at):
    e = bpy.data.objects.new("%s_%s" % (NAME, name), None)
    scene.collection.objects.link(e)
    e.parent = body
    e.location = at


track = (OUTER_X - 0.115) * S
front_y = (FRONT_Y + SHIFT.y) * S
rear_y = (REAR_Y + SHIFT.y) * S
axles = sorted([(-track, front_y), (track, front_y), (-track, rear_y), (track, rear_y)], key=lambda a: (a[1], -a[0]))
for i, (x, y) in enumerate(axles):
    marker("axle_%d" % i, (x, y, radius))
mid = [v.co for v in body.data.vertices if abs(v.co.x) < 0.08 and 0.35 < v.co.z < 0.9]
marker("plate_front", (0.0, min(c.y for c in mid) - 0.02, 0.62))
marker("plate_rear", (0.0, max(c.y for c in mid) + 0.02, 0.8))
seat_z = 0.95
marker("seat_0", (-0.42, -0.55 * S + 0.1, seat_z))     # right-hand drive: the driver on the -X side facing -Y
marker("seat_1", (0.42, -0.55 * S + 0.1, seat_z))
marker("seat_2", (-0.42, 0.35 * S + 0.1, seat_z))
marker("seat_3", (0.42, 0.35 * S + 0.1, seat_z))

for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("HILUX body tris", vc.tris(body), "wheel tris", vc.tris(wheel), "radius", round(radius, 3), "roof", round(roof_z, 2), "size", tuple(round(x, 2) for x in body.dimensions))
