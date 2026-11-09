"""Builds the neighbourhood dog: assets/models/animals/dog.glb.

Run headless:  blender -b --factory-startup --python tools/blender/build_dog.py
A medium mixed-breed dog (about 0.5 m at the shoulder). Faces -Y in Blender (= +Z in Godot).
- Armature "DogRig": hips > spine > chest > neck > head; tail; legs leg_upper/lower .FL .FR .BL .BR.
- "DogBody": one skinned mesh, material slots coat (recoloured per dog) and coat_light (muzzle,
  chest, paws, tail tip); "DogHead": ears, eyes, nose (rigid on the head bone).
- Actions: idle (tail wag), walk, trot, lie (loops) and bark (one-shot). 24 fps.
  Walk is authored at 1.0 m/s, trot at 2.6 m/s; Godot scales playback to the real speed.
"""
import math
import os

import bpy
from mathutils import Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "animals", "dog.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 24

# ----------------------------------------------------------------------------- rig
J = {
    "hips": ((0, 0.2, 0.47), (0, 0.02, 0.48), None),
    "spine": ((0, 0.02, 0.48), (0, -0.14, 0.49), "hips"),
    "chest": ((0, -0.14, 0.49), (0, -0.22, 0.52), "spine"),
    "neck": ((0, -0.22, 0.52), (0, -0.3, 0.64), "chest"),
    "head": ((0, -0.3, 0.64), (0, -0.46, 0.65), "neck"),
    "tail": ((0, 0.24, 0.5), (0, 0.46, 0.6), "hips"),
}
for side, s in (("L", 1), ("R", -1)):
    J["leg_upper.F" + side] = ((0.075 * s, -0.15, 0.42), (0.075 * s, -0.16, 0.23), "chest")
    J["leg_lower.F" + side] = ((0.075 * s, -0.16, 0.23), (0.075 * s, -0.15, 0.03), "leg_upper.F" + side)
    J["leg_upper.B" + side] = ((0.075 * s, 0.19, 0.42), (0.075 * s, 0.25, 0.22), "hips")
    J["leg_lower.B" + side] = ((0.075 * s, 0.25, 0.22), (0.075 * s, 0.2, 0.03), "leg_upper.B" + side)


def make_rig():
    data = bpy.data.armatures.new("DogRig")
    rig = bpy.data.objects.new("DogRig", data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (h, t, parent) in J.items():
        b = data.edit_bones.new(name)
        b.head, b.tail, b.roll = h, t, 0.0
        if parent:
            b.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def mat(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = 0.9
    return m


M = {n: mat(n, c) for n, c in {"coat": (0.35, 0.22, 0.12), "coat_light": (0.8, 0.7, 0.55),
                               "nose": (0.03, 0.03, 0.03), "eye": (0.05, 0.03, 0.02)}.items()}

# ----------------------------------------------------------------------------- body (Skin modifier)
PTS = {
    "tail_tip": ((0, 0.47, 0.6), 0.018, 0.018), "tail_base": ((0, 0.26, 0.5), 0.03, 0.03),
    "rump": ((0, 0.19, 0.47), 0.1, 0.1), "belly": ((0, 0.02, 0.46), 0.095, 0.105),
    "chest": ((0, -0.15, 0.47), 0.105, 0.125), "neck": ((0, -0.25, 0.57), 0.06, 0.065),
    "head": ((0, -0.32, 0.66), 0.068, 0.072), "snout": ((0, -0.43, 0.63), 0.04, 0.038),
    "nose": ((0, -0.48, 0.635), 0.026, 0.024),
}
for side, s in (("L", 1), ("R", -1)):
    PTS["shoulder" + side] = ((0.07 * s, -0.15, 0.4), 0.048, 0.052)
    PTS["elbow" + side] = ((0.075 * s, -0.16, 0.23), 0.032, 0.032)
    PTS["fpaw" + side] = ((0.075 * s, -0.17, 0.03), 0.032, 0.036)
    PTS["thigh" + side] = ((0.07 * s, 0.19, 0.41), 0.058, 0.065)
    PTS["hock" + side] = ((0.075 * s, 0.25, 0.21), 0.03, 0.03)
    PTS["bpaw" + side] = ((0.075 * s, 0.2, 0.03), 0.032, 0.036)
EDGES = [("tail_tip", "tail_base"), ("tail_base", "rump"), ("rump", "belly"), ("belly", "chest"),
         ("chest", "neck"), ("neck", "head"), ("head", "snout"), ("snout", "nose")]
for side in ("L", "R"):
    EDGES += [("chest", "shoulder" + side), ("shoulder" + side, "elbow" + side), ("elbow" + side, "fpaw" + side),
              ("rump", "thigh" + side), ("thigh" + side, "hock" + side), ("hock" + side, "bpaw" + side)]


def make_body():
    names = list(PTS)
    me = bpy.data.meshes.new("DogBody")
    me.from_pydata([PTS[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in EDGES], [])
    obj = bpy.data.objects.new("DogBody", me)
    scene.collection.objects.link(obj)
    sk = obj.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    for i, n in enumerate(names):
        sv = me.skin_vertices[0].data[i]
        sv.radius = (PTS[n][1], PTS[n][2])
        sv.use_root = n == "belly"
    obj.modifiers.new("Sub", "SUBSURF").levels = 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(M["coat"])
    me.materials.append(M["coat_light"])
    for p in me.polygons:
        c = p.center
        light = (c.y < -0.4) or (c.z < 0.08) or (c.y > 0.42) or (c.y < -0.12 and c.z < 0.45 and abs(c.x) < 0.06)
        p.material_index = 1 if light else 0
    return obj


def prim(kind, loc, scale, material, rot=(0, 0, 0)):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=1, depth=2, location=loc)
    o = bpy.context.active_object
    o.scale, o.rotation_euler = scale, rot
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(M[material])
    for p in o.data.polygons:
        p.use_smooth = kind == "sphere"
    return o


def make_head_parts():
    parts = []
    for s in (1, -1):
        parts.append(prim("cone", (0.045 * s, -0.31, 0.74), (0.03, 0.018, 0.045), "coat", rot=(0.25, 0.35 * s, 0)))
        parts.append(prim("sphere", (0.033 * s, -0.385, 0.68), (0.012, 0.01, 0.012), "eye"))
    parts.append(prim("sphere", (0, -0.5, 0.645), (0.018, 0.014, 0.014), "nose"))
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = o.data.name = "DogHead"
    return o


# ----------------------------------------------------------------------------- animation helpers
def rest(rig, bone):
    return rig.data.bones[bone].matrix_local.to_3x3().to_quaternion()


def rot(rig, bone, rots):
    """Armature-space rotations (axis, angle) applied in order, stored in bone space."""
    q = Quaternion()
    for axis, angle in rots:
        q = Quaternion({"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[axis], angle) @ q
    r = rest(rig, bone)
    pb = rig.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = r.inverted() @ q @ r


def move(rig, bone, offset):
    """Armature-space translation of a root bone."""
    rig.pose.bones[bone].location = rest(rig, bone).inverted() @ Vector(offset)


def reset(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()


LEGS = ("FL", "FR", "BL", "BR")


def gait(rig, t, phases, amp, lift, bob):
    ph = t * 2 * math.pi
    for leg in LEGS:
        a = ph + phases[leg]
        swing = math.sin(a)
        rot(rig, "leg_upper." + leg[0] + leg[1], [("X", -swing * amp)])  # forward = -X
        bend = max(0.0, math.sin(a + 1.4)) * lift
        rot(rig, "leg_lower." + leg[0] + leg[1], [("X", (-bend if leg[0] == "F" else bend))])
    move(rig, "hips", (0, 0, abs(math.cos(ph)) * bob))
    rot(rig, "tail", [("Z", math.sin(ph * 2) * 0.35)])
    rot(rig, "head", [("X", math.sin(ph * 2) * 0.04)])


def walk(rig, t):
    gait(rig, t, {"BL": 0.0, "FL": math.pi / 2, "BR": math.pi, "FR": 3 * math.pi / 2}, 0.38, 0.6, 0.012)


def trot(rig, t):
    gait(rig, t, {"FL": 0.0, "BR": 0.0, "FR": math.pi, "BL": math.pi}, 0.6, 0.9, 0.03)
    rot(rig, "neck", [("X", 0.12)])


def idle(rig, t):
    ph = t * 2 * math.pi
    rot(rig, "tail", [("Z", math.sin(ph * 6) * 0.55), ("X", -0.2)])
    rot(rig, "chest", [("X", math.sin(ph) * 0.015)])
    rot(rig, "head", [("Z", math.sin(ph * 0.5) * 0.25)])


def lie(rig, t):
    ph = t * 2 * math.pi
    move(rig, "hips", (0, 0, -0.33))
    for side in ("L", "R"):
        rot(rig, "leg_upper.F" + side, [("X", -1.45)])
        rot(rig, "leg_lower.F" + side, [("X", 0.1)])
        rot(rig, "leg_upper.B" + side, [("X", -1.35)])
        rot(rig, "leg_lower.B" + side, [("X", 2.3)])
    rot(rig, "neck", [("X", 0.45)])
    rot(rig, "head", [("X", -0.25 + math.sin(ph) * 0.02)])
    rot(rig, "tail", [("Z", 0.6), ("X", 0.5)])
    rot(rig, "spine", [("X", math.sin(ph) * 0.02)])


def bark(rig, t):
    idle(rig, t)
    jerk = max(0.0, math.sin(t * 2 * math.pi * 2)) ** 2   # two barks
    rot(rig, "neck", [("X", -0.25 * jerk)])
    rot(rig, "head", [("X", -0.3 * jerk)])
    rot(rig, "chest", [("X", 0.08 * jerk)])
    move(rig, "hips", (0, 0, -0.03 * jerk))


def bake(rig, name, frames, fn):
    action = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = action
    for f in range(frames + 1):
        reset(rig)
        fn(rig, f / frames)
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    action.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, action)
    rig.animation_data.action = None


# ----------------------------------------------------------------------------- build
rig = make_rig()
body = make_body()
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
head = make_head_parts()
vg = head.vertex_groups.new(name="head")
vg.add(list(range(len(head.data.vertices))), 1.0, "REPLACE")
head.parent = rig
head.modifiers.new("Armature", "ARMATURE").object = rig

bake(rig, "idle", 48, idle)
bake(rig, "walk", 24, walk)
bake(rig, "trot", 12, trot)
bake(rig, "lie", 72, lie)
bake(rig, "bark", 14, bark)
reset(rig)

for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_skins=True, export_yup=True,
                          export_def_bones=False)
print("WROTE", OUT, len(body.data.vertices))
