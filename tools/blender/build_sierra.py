"""Builds Remy's car: assets/models/vehicles/sierra.glb, from the Ford Sierra model the owner supplied (art/source/ford_sierra.glb:
93 000 triangles, 60 untextured materials, a full engine bay, suspension, roll cage and interior).

Run headless:  blender -b --factory-startup --python tools/blender/build_sierra.py

The model "sierra" (VehicleLibrary.EXTRA_SOURCES, EXCLUSIVE: only Remy's car id gets it):
  * everything nobody sees is dropped (engine, suspension, brakes, exhaust, tank, roll cage, pedals, the wipers and the steering wheel,
    which Godot makes and turns) and the duplicate wheel set is dropped;
  * the rest gets the role materials VehicleLibrary knows - paint (Godot recolours it), glass, trim, chrome, seat, headlight, taillight,
    indicator_L/R (they blink) - welded and decimated to about 22 000 triangles; the seats and dashboard stay so Remy sits inside;
  * one wheel (tyre and alloy rim, axle along X, outer face +X) is "sierra_tyre"; empties sierra_axle_0..3 (front pair first), sierra_plate_front/
    rear, sierra_seat_0..3 (driver first, on the -X side: right-hand drive), sierra_steer and sierra_wiper_0/1 sit under the body "sierra".
Front = -Y in Blender (+Z in Godot). The model's wheelbase is moved to the middle (y = 0).
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "source", "ford_sierra.glb")
OUT = os.path.join(ROOT, "assets", "models", "vehicles", "sierra.glb")
NAME = "sierra"

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
    "chrome": role_material("chrome", "#d8dadf", 0.2, 0.9),
    "seat": role_material("seat", "#3a3f4a", 0.9),
    "headlight": role_material("headlight", "#f4f1e6", 0.2),
    "taillight": role_material("taillight", "#b0202a", 0.3),
    "tyre": role_material("tyre", "#232327", 0.9),
    "rim": role_material("rim", "#d2d5da", 0.35, 0.1),
    "indicator_L": role_material("indicator_L", "#e8901c", 0.4),
    "indicator_R": role_material("indicator_R", "#e8901c", 0.4),
}
DROP_MATERIALS = ("hatch", "undercarriage", "pickup", "rollcage_01a", "material_0", "material", "tire0", "inner_rim")
DROP_PARENTS = ("sierra_exhaust", "sierra_tank", "sierra_steer", "sierra_wipers_f", "sierra_wiper_r", "sierra_pedals", "sierra_clutch",
                "sierra_brake", "sierra_acc", "sierra_parkbrake", "sierra_needle_rpm", "sierra_needle_mph", "sierra_engine",
                "sierra_wheel_fl", "sierra_wheel_fr", "sierra_wheel_rl", "sierra_wheel_rr")
RATIO = {"paint": 0.45, "trim": 0.35, "seat": 0.12, "glass": 1.0, "chrome": 0.6}


def role_of(mat, parent):
    if mat in DROP_MATERIALS or parent in DROP_PARENTS:
        return None
    if mat == "body":
        return "paint"
    if mat in ("nodmg", "black"):
        return "trim"
    if mat in ("badge", "reverse", "mirrorLeft", "mirrorRight", "mirrorMiddle"):
        return "chrome"
    if mat in ("badge_001", "interior"):
        return "seat"
    if mat in ("glass", "window"):
        return "glass"
    if mat == "lights1":
        if "taillight" in parent:
            return "taillight"
        return "headlight" if "glass" in parent else "trim"
    if mat in ("lights0", "headlights", "brights"):
        return "headlight"
    if mat in ("brake", "parking"):
        return "taillight"
    if mat == "signal_l":
        return "indicator_L"   # the vehicle's left is +X (Godot's left when facing +Z)
    if mat == "signal_r":
        return "indicator_R"
    return "trim"


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def select_only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def weld(o, dist=0.0006):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=dist)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def decimate(o, ratio):
    if ratio >= 1.0 or tris(o) < 40:
        return
    select_only(o)
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.ratio = max(ratio, min(1.0, 24.0 / tris(o)))
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)


# Detach every mesh from the glTF's empties (keeping where it stands), remembering what its parent was.
meshes = []
for o in [o for o in scene.objects if o.type == "MESH"]:
    parent = o.parent.name if o.parent else ""
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
    mat = o.material_slots[0].material.name if o.material_slots and o.material_slots[0].material else ""
    meshes.append((o, mat, parent))
for o in [o for o in scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)

SHIFT_Y = 0.125   # the wheelbase's middle (front axle y -1.44, rear +1.19) to y = 0
keep = []
wheel_parts = {}
for o, mat, parent in meshes:
    if tris(o) == 0:
        bpy.data.objects.remove(o)
        continue
    if parent == "wheel_01a_17x9_FL" or (parent.startswith("wheel_01a_17x9_") and parent != "wheel_01a_17x9_FL"):
        if parent == "wheel_01a_17x9_FL":
            wheel_parts[mat] = o
        elif parent.endswith("_FR") or parent.endswith("_RL") or parent.endswith("_RR"):
            pass
        if parent != "wheel_01a_17x9_FL":
            bpy.data.objects.remove(o)
        continue
    role = role_of(mat, parent)
    if role is None:
        bpy.data.objects.remove(o)
        continue
    for slot in o.material_slots:
        slot.material = ROLES[role]
    select_only(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for v in o.data.vertices:
        v.co.y += SHIFT_Y
    o.data.update()
    weld(o)
    decimate(o, RATIO.get(role, 0.5))
    keep.append(o)

# Where the wheels are: the front left alloy (+X) gives the centre and radius; the others stand at the mirrored / rear spots.
tyre_o, rim_o = wheel_parts["tire_002"], wheel_parts["wheel_01a"]
for o in (tyre_o, rim_o):
    select_only(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts = [v.co.copy() for o in (tyre_o, rim_o) for v in o.data.vertices]
lo = Vector(map(min, *pts))
hi = Vector(map(max, *pts))
wc = (lo + hi) / 2
radius = (hi.z - lo.z) / 2
front_y = wc.y + SHIFT_Y
rear_y = front_y + 1.19 + 1.44
track = abs(wc.x)
tyre_o.data.materials.clear()
rim_o.data.materials.clear()
tyre_o.data.materials.append(ROLES["tyre"])
rim_o.data.materials.append(ROLES["rim"])
for o in (tyre_o, rim_o):
    for v in o.data.vertices:
        v.co -= wc
    o.data.update()
    weld(o)
decimate(rim_o, 0.3)
decimate(tyre_o, 0.6)
# The rim faces out (+X) on this side already; flip if the rim sits on the inside of the tyre's middle.
rim_x = sum(v.co.x for v in rim_o.data.vertices) / len(rim_o.data.vertices)
tyre_x = sum(v.co.x for v in tyre_o.data.vertices) / len(tyre_o.data.vertices)
flip = rim_x < tyre_x - 0.002
bpy.ops.object.select_all(action="DESELECT")
tyre_o.select_set(True)
rim_o.select_set(True)
bpy.context.view_layer.objects.active = tyre_o
bpy.ops.object.join()
wheel = tyre_o
if flip:
    for v in wheel.data.vertices:
        v.co.x = -v.co.x
    bm = bmesh.new()
    bm.from_mesh(wheel.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(wheel.data)
    bm.free()
wheel.name = wheel.data.name = NAME + "_tyre"
wheel.location = (0, -8, 0)
select_only(wheel)
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))

# Join the body.
bpy.ops.object.select_all(action="DESELECT")
for o in keep:
    o.select_set(True)
bpy.context.view_layer.objects.active = keep[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = body.data.name = NAME
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))


def marker(name, at):
    e = bpy.data.objects.new("%s_%s" % (NAME, name), None)
    scene.collection.objects.link(e)
    e.parent = body
    e.location = at


axles = sorted([(-track, front_y), (track, front_y), (-track, rear_y), (track, rear_y)], key=lambda a: (a[1], -a[0]))
for i, (x, y) in enumerate(axles):
    marker("axle_%d" % i, (x, y, radius))
mid = [v.co for v in body.data.vertices if abs(v.co.x) < 0.08 and 0.35 < v.co.z < 0.8]
marker("plate_front", (0.0, min(c.y for c in mid) - 0.02, 0.55))
marker("plate_rear", (0.0, max(c.y for c in mid) + 0.02, 0.6))
steer_x, steer_y = -0.37, -0.39 + SHIFT_Y
marker("seat_0", (steer_x, steer_y + 0.55, 0.62))   # right-hand drive: the driver on the -X side facing -Y
marker("seat_1", (-steer_x, steer_y + 0.55, 0.62))
marker("seat_2", (steer_x, steer_y + 1.55, 0.62))
marker("seat_3", (-steer_x, steer_y + 1.55, 0.62))
marker("steer", (steer_x, steer_y, 0.81))
marker("wiper_0", (-0.30, -0.92 + SHIFT_Y, 0.97))
marker("wiper_1", (0.18, -0.92 + SHIFT_Y, 0.97))

for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("SIERRA body tris", tris(body), "wheel tris", tris(wheel), "radius", round(radius, 3), "flip", flip, "axle y", round(front_y, 2), round(rear_y, 2),
      "track", round(track, 2), "size", tuple(round(x, 2) for x in body.dimensions))
