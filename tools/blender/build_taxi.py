"""Builds the minibus taxi: assets/models/vehicles/taxi.glb, from the "Toyota Hiace Passenger Van L2H3 GLX 2020" model by Aeroux
(https://skfb.ly/pH7KN, Creative Commons Attribution 4.0: credit in docs/CREDITS.md and the game's credits), saved as art/source/hiace_l2h3.glb
(1 100 triangles, one 4096 x 4096 texture, the wheels part of the body).

Run headless:  blender -b --factory-startup --python tools/blender/build_taxi.py

The model "taxi" (VehicleLibrary.EXTRA_SOURCES; every taxi in the game):
  * scaled to its real length (5.4 m), the wheelbase put in the middle, front = -Y in Blender (+Z in Godot), right-hand drive;
  * its texture (shrunk to 2048 x 2048, a JPEG) stays as the one material "taxi_body": the model is 1 100 triangles with all its detail
    painted on; the baked-in wheels are cut out of the body and replaced by one made wheel that spins and steers ("taxi_tyre", axle along X,
    outer face +X);
  * empties: taxi_axle_0..3 (front pair first), taxi_plate_front/rear, taxi_seat_0..9 (driver first, then the passengers' rows),
    taxi_steer and taxi_wiper_0/1 under the body "taxi".
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_common as vc  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "source", "hiace_l2h3.glb")
OUT = os.path.join(ROOT, "assets", "models", "vehicles", "taxi.glb")
NAME = "taxi"
LENGTH = 5.4

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene = bpy.context.scene
ROLES = vc.make_roles()

src = [o for o in scene.objects if o.type == "MESH"][0]
vc.detach(src)
for o in [o for o in scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)
vc.apply_transform(src)
tex = vc.Texture(bpy.data.images[0])

# Real size, then the wheelbase's middle on y = 0, the middle on x = 0 and the tyres on z = 0.
lo = Vector((1e9,) * 3)
hi = Vector((-1e9,) * 3)
for v in src.data.vertices:
    lo = Vector(map(min, lo, v.co))
    hi = Vector(map(max, hi, v.co))
S = LENGTH / (hi.y - lo.y)
for v in src.data.vertices:
    v.co = v.co * S
src.data.update()
FRONT_Y, REAR_Y, WHEEL_Z, WHEEL_R = -2.0, 1.1, 0.33, 0.40     # found from the model: where its wheels are (before moving it)
CX = 0.065
SHIFT = Vector((-CX, -(FRONT_Y + REAR_Y) / 2, 0.05))


def wheel_face(c):
    if abs(c.x - CX) < 0.55:
        return False
    return min(math.hypot(c.y - FRONT_Y, c.z - WHEEL_Z), math.hypot(c.y - REAR_Y, c.z - WHEEL_Z)) < WHEEL_R


# The model's detail (windows, lamps, panel lines) is all in its texture, so the texture stays (shrunk to 2048 x 2048 and saved as a JPEG, so it
# costs the phone a few MB) as the one material "taxi_body": VehicleLibrary leaves a surface of that name alone. Only the baked-in wheels are cut
# out of the body: they are replaced by the made wheel that spins and steers.
bm = bmesh.new()
bm.from_mesh(src.data)
bm.faces.ensure_lookup_table()
wheel_faces = [f for f in bm.faces if wheel_face(sum((src.matrix_world @ v.co for v in f.verts), Vector()) / len(f.verts))]
bmesh.ops.delete(bm, geom=wheel_faces, context="FACES")
bm.to_mesh(src.data)
bm.free()
src.data.update()
img = bpy.data.images[0]
img.scale(2048, 2048)
src.material_slots[0].material.name = "taxi_body"
vc.apply_transform(src)
for v in src.data.vertices:
    v.co += SHIFT
src.data.update()
body = src
body.name = body.data.name = NAME
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))

# The made wheel and the markers.
TRACK = 0.845
WIDTH = 0.19
wheel = vc.procedural_wheel(ROLES, WHEEL_R - 0.02, WIDTH, NAME + "_tyre")
wheel.location = (0, -8, 0)
vc.select_only(wheel)
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))


def marker(name, at):
    e = bpy.data.objects.new("%s_%s" % (NAME, name), None)
    scene.collection.objects.link(e)
    e.parent = body
    e.location = at


front_y = FRONT_Y + SHIFT.y
rear_y = REAR_Y + SHIFT.y
axles = sorted([(-TRACK, front_y), (TRACK, front_y), (-TRACK, rear_y), (TRACK, rear_y)], key=lambda a: (a[1], -a[0]))
for i, (x, y) in enumerate(axles):
    marker("axle_%d" % i, (x, y, WHEEL_R - 0.02))
mid = [v.co for v in body.data.vertices if abs(v.co.x) < 0.1 and 0.3 < v.co.z < 0.8]
marker("plate_front", (0.0, min(c.y for c in mid) - 0.02, 0.6))
marker("plate_rear", (0.0, max(c.y for c in mid) + 0.02, 0.7))
ws_y = -2.3   # the foot of the windscreen (read from the model)
steer_x, steer_y = -0.5, ws_y + 0.5
marker("seat_0", (steer_x, steer_y + 0.62, 0.78))     # right-hand drive: the driver on the -X side facing -Y
marker("seat_1", (-steer_x, steer_y + 0.62, 0.78))
for k, (sx, sy) in enumerate([(-0.52, -0.45), (0.52, -0.45), (-0.52, 0.35), (0.52, 0.35), (-0.52, 1.15), (0.52, 1.15), (-0.52, 1.95), (0.52, 1.95)]):
    marker("seat_%d" % (k + 2), (sx, sy, 0.78))   # the passengers' rows behind the driver and the front passenger
marker("steer", (steer_x, steer_y, 1.2))
marker("wiper_0", (steer_x - 0.1, ws_y, 1.45))
marker("wiper_1", (steer_x + 0.55, ws_y, 1.45))

for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True, export_image_format="JPEG")
for stray in os.listdir(os.path.dirname(OUT)):   # the exporter leaves a copy of the texture beside the .glb: it is inside it already
    if stray.startswith("taxi_Image") and stray.endswith(".jpg"):
        os.remove(os.path.join(os.path.dirname(OUT), stray))
print("TAXI body tris", vc.tris(body), "wheel tris", vc.tris(wheel), "windscreen base y", round(ws_y, 2), "size", tuple(round(x, 2) for x in body.dimensions))
