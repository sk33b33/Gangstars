"""Builds Remy's van: assets/models/vehicles/hiace.glb, from the 2012 Toyota HiAce Commuter model Remy's owner supplied
(art/source/2012_Toyota_HiAce_Commuter.fbx, ~500 000 triangles with 30 photo textures).

Run headless:  blender -b --factory-startup --python tools/blender/build_hiace.py

What it does, so the van drives like every other vehicle in VehicleLibrary (see tools/blender/build_vehicles.py):
  * scales the model by 0.8 (it was 1.25 times life size: 5.4 m long, 1.86 m wide after) and puts its origin on the ground at the centre,
    front = -Y in Blender (+Z in Godot), right-hand drive;
  * drops the roof luggage and the roof rack floor (the van has no roof rack) and its steering wheel (Godot makes a ring that turns);
  * decimates every part (the phone cannot draw 500 000 triangles for one van) to roughly 30 000 triangles in total;
  * replaces the 30 photo textures with plain role materials named as in vehicles.glb: paint (Godot recolours it), glass, trim (black
    plastic), chrome, seat, headlight, taillight - no textures at all;
  * makes one wheel (tyre and rim, axle along X, outer face +X) as "hiace_tyre", and empties "hiace_axle_0..3" (front pair first),
    "hiace_plate_front/rear" and "hiace_seat_0/1" (driver first) under the body "hiace".
The steering wheel, doors and mirrors stay as static parts of the body. Credit and licence of the source model: supplied by the user.
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "source", "2012_Toyota_HiAce_Commuter.fbx")
OUT = os.path.join(ROOT, "assets", "models", "vehicles", "hiace.glb")
SCALE = 0.8
DROP = ("Baggages", "Baggage Floor", "steering", "steering.001", "Rims9", "Rims11")   # Rims9/11: flat hub discs fixed to the body at the front wheels (the wheels have their own rims)   # the steering wheel is a ring Godot makes and turns (hiace_steer)
WHEELS = ("TireRing173", "TireRing174", "TireRing173.001", "TireRing174.001")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)
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
    "rim": role_material("rim", "#d2d5da", 0.35, 0.1),   # barely metallic: a metal surface with nothing to reflect renders black
    "indicator_L": role_material("indicator_L", "#e8901c", 0.4),
    "indicator_R": role_material("indicator_R", "#e8901c", 0.4),
}
# The lamp clusters at the corners: the vehicle's left is +X (Godot's left when facing +Z). They blink when the van turns.
INDICATORS = {"Meshpart73": "indicator_L", "Meshpart36": "indicator_L", "Meshpart8": "indicator_R", "Meshpart36.002": "indicator_R"}
PAINT = ("car_body", "Meshpart1Mtl.001", "Meshpart1Mtl.002", "Material.004")
GLASS = ("Material.001", "Material.002", "Material.003", "Meshpart32Mtl.001")
CHROME = ("Door_lf_hi_ok.4", "Material.008", "Material.009", "Material.013", "Material.019", "Material.021", "Meshpart30Mtl.001")


def role_of(material_name):
    if material_name in PAINT:
        return "paint"
    if material_name in GLASS:
        return "glass"
    if material_name in CHROME:
        return "chrome"
    if material_name == "Material.015":
        return "seat"
    if material_name == "Meshpart1Mtl.004":
        return "headlight"
    if material_name == "Material.005":
        return "taillight"
    if material_name == "TireRing171Mtl.001":
        return "tyre"
    if material_name in ("Rims2Mtl.001", "Rims3Mtl.001"):
        return "rim"
    return "trim"


def world_apply(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# Detach every mesh from the FBX's parent empties, drop the luggage, and set each slot to its role material.
meshes = [o for o in scene.objects if o.type == "MESH"]
for o in meshes:
    if o.parent:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
wheel_src = {}
parts = []
for o in meshes:
    if o.name in DROP:
        bpy.data.objects.remove(o)
        continue
    if o.name in WHEELS:
        wheel_src[o.name] = o
        continue
    parts.append(o)
for o in list(scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)

for o in parts + list(wheel_src.values()):
    for slot in o.material_slots:   # in place: clearing the material list resets every face to slot 0 (the wheels lost their rims that way)
        slot.material = ROLES[INDICATORS.get(o.name) or role_of(slot.material.name if slot.material else "")]
    world_apply(o)

# Scale about the origin, then centre the van on x = 0 with its wheels on the ground (z = 0).
lo = Vector((1e9,) * 3)
hi = Vector((-1e9,) * 3)
for o in parts:
    for v in o.bound_box:
        lo = Vector(map(min, lo, v))
        hi = Vector(map(max, hi, v))
shift_x = -(lo.x + hi.x) / 2 if False else 0.03   # the model's left-right middle is x = -0.03


def move_scale(o):
    for v in o.data.vertices:
        v.co = Vector(((v.co.x + shift_x) * SCALE, v.co.y * SCALE, v.co.z * SCALE))
    o.data.update()


for o in parts + list(wheel_src.values()):
    move_scale(o)

# Weld the vertices the FBX split at every edge (decimating a mesh in loose pieces leaves holes and black patches) and make the face
# normals consistent, then decimate each part: big painted panels keep a little more.
def weld(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0008)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


for o in parts:
    weld(o)
budget = {"paint": 0.10}
for o in parts:
    n = tris(o)
    if n <= 120:
        continue
    roles = {s.material.name for s in o.material_slots}
    ratio = budget.get("paint", 0.1) if "paint" in roles else 0.06
    ratio = max(ratio, min(1.0, 60.0 / n))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)

# Join the body.
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = body.data.name = "hiace"
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))

# One wheel: the +X-side front tyre, centred on the origin, rim facing +X.
tyre_src = wheel_src["TireRing174"]
wc = sum((v.co for v in tyre_src.data.vertices), Vector()) / len(tyre_src.data.vertices)
rim_x = [sum((tyre_src.data.vertices[i].co.x for i in p.vertices)) / len(p.vertices) for p in tyre_src.data.polygons
         if tyre_src.material_slots[p.material_index].material.name == "rim"]
flip = rim_x and (sum(rim_x) / len(rim_x) - wc.x) < 0.0
for v in tyre_src.data.vertices:
    v.co = Vector((-(v.co.x - wc.x) if flip else v.co.x - wc.x, v.co.y - wc.y, v.co.z - wc.z))
if flip:
    bm = bmesh.new()
    bm.from_mesh(tyre_src.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(tyre_src.data)
    bm.free()
tyre_src.data.update()
tyre_src.name = tyre_src.data.name = "hiace_tyre"
tyre_src.location = (0.0, -8.0, 0.0)
radius = (max(v.co.z for v in tyre_src.data.vertices) - min(v.co.z for v in tyre_src.data.vertices)) / 2
bpy.context.view_layer.objects.active = tyre_src
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
for name in WHEELS:
    if name != "TireRing174" and name in wheel_src:
        pass
for name in ("TireRing173", "TireRing173.001", "TireRing174.001"):
    bpy.data.objects.remove(wheel_src[name])

# Where the wheels, plates and seats go (read from the model itself).
front_y, rear_y, track = -2.13 * SCALE, 1.74 * SCALE, (0.97 + 1.02) * 0.5 * SCALE
body_verts = [v.co for v in body.data.vertices]
mid = [c for c in body_verts if abs(c.x) < 0.08 and 0.35 < c.z < 0.85]
plate_front_y = min(c.y for c in mid)
plate_rear_y = max(c.y for c in mid)
steer_x, steer_y = (-0.65 + shift_x) * SCALE, -2.50 * SCALE


def marker(name, at):
    e = bpy.data.objects.new("hiace_" + name, None)
    scene.collection.objects.link(e)
    e.parent = body
    e.location = at


axles = [(-track, front_y), (track, front_y), (-track, rear_y), (track, rear_y)]
axles.sort(key=lambda a: (a[1], -a[0]))
for i, (x, y) in enumerate(axles):
    marker("axle_%d" % i, (x, y, radius))
marker("plate_front", (0.0, plate_front_y - 0.02, 0.6))
marker("plate_rear", (0.0, plate_rear_y + 0.02, 0.7))
marker("seat_0", (steer_x, steer_y + 0.62, 0.78))     # right-hand drive: the driver on the -X side facing -Y
marker("seat_1", (-steer_x, steer_y + 0.62, 0.78))
marker("steer", (steer_x, steer_y + 0.05, 1.2))      # the centre of the steering wheel (the model's own is left out)
# Wiper pivots at the foot of the windscreen (Blender coordinates: the glass runs from y -2.49, z 1.29 up to y -1.85, z 1.79).
marker("wiper_0", (steer_x - 0.1, -2.4, 1.33))
marker("wiper_1", (steer_x + 0.55, -2.4, 1.33))

bpy.ops.object.select_all(action="DESELECT")
for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("HIACE body tris", tris(body), "wheel tris", tris(tyre_src), "radius", round(radius, 3), "flip", bool(flip),
      "plates", round(plate_front_y, 2), round(plate_rear_y, 2), "size", tuple(round(x, 2) for x in body.dimensions))
