"""Builds the SAPS bakkie: assets/models/vehicles/hilux.glb, from the Toyota Hilux double cab the owner supplied (art/source/Hilux.glb,
47 000 triangles for the body and 4 x 4 500 for the wheels, 40 plain grey materials and no textures).

Run headless:  blender -b --factory-startup --python tools/blender/build_hilux.py

It becomes the model "police" (VehicleLibrary.EXTRA_SOURCES): the vehicle only the SAPS use, in place of the old double-cab bakkie.
  * turned half a turn (the source faces +Y; the game's front is -Y, which Godot reads as +Z), at its real size (5.4 m);
  * the 40 grey materials are given roles by which part of the truck they cover (found by rendering each one on its own): paint (Godot makes it
    white for the police), glass, headlight, taillight, chrome (the grille) and trim (everything else, black plastic and rubber);
  * welded and decimated to about 20 000 triangles; one wheel (tyre and rim, axle along X, outer face +X) is "police_tyre";
  * a light bar on the cab roof (material "lightbar", which flashes blue when the police respond), seats and a dashboard so the officers
    show through the windows, and empties police_axle_0..3 (front pair first), police_plate_front/rear and police_seat_0..3 (driver first).
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "source", "Hilux.glb")
OUT = os.path.join(ROOT, "assets", "models", "vehicles", "hilux.glb")
NAME = "police"
BODY_RATIO = 0.42
WHEEL_RATIO = 0.35

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene = bpy.context.scene


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


ROLES = {
    "paint": role_material("paint", "#f1eee8", 0.35),
    "glass": role_material("glass", "#22303f", 0.1),
    "trim": role_material("trim", "#1d1f24", 0.8),
    "chrome": role_material("chrome", "#d8dadf", 0.2, 0.4),
    "seat": role_material("seat", "#3a3f4a", 0.9),
    "headlight": role_material("headlight", "#f4f1e6", 0.2),
    "taillight": role_material("taillight", "#b0202a", 0.3),
    "tyre": role_material("tyre", "#232327", 0.9),
    "rim": role_material("rim", "#d2d5da", 0.35, 0.1),
    "lightbar": role_material("lightbar", "#2a6cff", 0.3),
}
# Which material slot of the source body is which part (found by rendering each slot on its own).
SLOT_ROLE = {}
for s in (14, 36, 13, 29, 17, 18, 20):   # cab, doors, bed sides, bonnet, bumper, tailgate
    SLOT_ROLE[s] = "paint"
for s in (25, 9, 26, 27):                # windows and windscreen
    SLOT_ROLE[s] = "glass"
SLOT_ROLE[23] = "headlight"
for s in (39, 12, 11):
    SLOT_ROLE[s] = "taillight"
SLOT_ROLE[1] = "chrome"                  # the grille and the bright trim


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def apply_all(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def weld(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0006)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def decimate(o, ratio):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)


body = bpy.data.objects["Body"]
wheels = [bpy.data.objects[n] for n in ("Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR")]
for o in [body] + wheels:
    o.parent = None
    o.rotation_euler = (0, 0, math.pi)   # the source faces +Y: turn it to face -Y
    apply_all(o)

# Roles: body slots by index, wheels by their two materials.
for i, slot in enumerate(body.material_slots):   # in place: clearing the list would reset every face to slot 0
    slot.material = ROLES[SLOT_ROLE.get(i, "trim")]
for w in wheels:
    for slot in w.material_slots:
        slot.material = ROLES["tyre"] if slot.material.name == "Material.020" else ROLES["rim"]

# Where the wheels are (before they are merged or moved): centre and radius.
centres = []
for w in wheels:
    pts = [w.matrix_world @ Vector(v) for v in w.bound_box]
    lo = Vector(map(min, *pts))
    hi = Vector(map(max, *pts))
    centres.append(((lo + hi) / 2, (hi.z - lo.z) / 2))

weld(body)
decimate(body, BODY_RATIO)

# A light bar on the cab roof, seats and a dashboard for the officers.
cab_pts = [v.co for v in body.data.vertices if v.co.z > 1.5 and abs(v.co.x) < 0.9 and -1.3 < v.co.y < 0.8]
roof_z = max(v.z for v in cab_pts)
cab_y = sum(v.y for v in cab_pts) / len(cab_pts)
parts = [body]


def box(centre, size, role):
    bpy.ops.mesh.primitive_cube_add(size=2, location=centre)
    b = bpy.context.active_object
    b.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    b.data.materials.append(ROLES[role])
    parts.append(b)


box((0, cab_y, roof_z + 0.03), (0.42, 1.1, 0.05), "trim")                 # the bar's base
box((-0.25, cab_y, roof_z + 0.09), (0.2, 0.95, 0.09), "lightbar")          # the lenses
box((0.25, cab_y, roof_z + 0.09), (0.2, 0.95, 0.09), "lightbar")
seat_y = (-0.5, 0.45)   # front row, back row (the front is -Y)
for sx in (-0.45, 0.45):
    for sy in seat_y:
        box((sx, sy, 0.62), (0.5, 0.5, 0.12), "seat")                    # cushion
        box((sx, sy + 0.24, 0.98), (0.5, 0.1, 0.62), "seat")              # back
box((0, -1.08, 1.0), (1.5, 0.35, 0.28), "trim")                          # dashboard
box((-0.45, -0.82, 1.12), (0.4, 0.04, 0.4), "trim")                      # steering wheel (static)

bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = body.data.name = NAME
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))

# One wheel: the +X side front one, centred on the origin, the rim facing +X.
wsrc = [w for w, c in zip(wheels, centres) if c[0].x > 0.3 and c[0].y < 0][0]
wc = centres[wheels.index(wsrc)][0]
for v in wsrc.data.vertices:
    v.co = v.co - wc
rim_idx = [i for i, m in enumerate(wsrc.data.materials) if m.name == "rim"]
rim_x = [sum(wsrc.data.vertices[i].co.x for i in p.vertices) / len(p.vertices) for p in wsrc.data.polygons if p.material_index in rim_idx]
flip = bool(rim_x) and sum(rim_x) / len(rim_x) < 0.0
if flip:
    for v in wsrc.data.vertices:
        v.co.x = -v.co.x
    bm = bmesh.new()
    bm.from_mesh(wsrc.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(wsrc.data)
    bm.free()
weld(wsrc)
decimate(wsrc, WHEEL_RATIO)
wsrc.name = wsrc.data.name = NAME + "_tyre"
wsrc.location = (0, -8, 0)
bpy.context.view_layer.objects.active = wsrc
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
for w in wheels:
    if w is not wsrc:
        bpy.data.objects.remove(w)
radius = centres[0][1]


def marker(name, at):
    e = bpy.data.objects.new("%s_%s" % (NAME, name), None)
    scene.collection.objects.link(e)
    e.parent = body
    e.location = at


axles = sorted([(c[0].x, c[0].y) for c in centres], key=lambda a: (a[1], -a[0]))
for i, (x, y) in enumerate(axles):
    marker("axle_%d" % i, (x, y, radius))
mid = [v.co for v in body.data.vertices if abs(v.co.x) < 0.08 and 0.35 < v.co.z < 0.9]
marker("plate_front", (0.0, min(c.y for c in mid) - 0.02, 0.6))
marker("plate_rear", (0.0, max(c.y for c in mid) + 0.02, 0.62))
marker("seat_0", (-0.45, seat_y[0], 0.7))     # right-hand drive: the driver on the -X side facing -Y
marker("seat_1", (0.45, seat_y[0], 0.7))
marker("seat_2", (-0.45, seat_y[1], 0.7))
marker("seat_3", (0.45, seat_y[1], 0.7))

for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("HILUX body tris", tris(body), "wheel tris", tris(wsrc), "radius", round(radius, 3), "flip", flip, "roof", round(roof_z, 2), "size", tuple(round(x, 2) for x in body.dimensions))
