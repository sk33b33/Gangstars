"""Builds the shared Gangstars person: assets/models/characters/person.glb.

Run headless:  blender -b --factory-startup --python tools/blender/build_character.py
Deterministic: same script -> same file. Everything is code (like the pxl textures).

Contents (Blender Z-up, character faces -Y; glTF export turns that into Godot's +Z facing):
- Armature "Rig": hips > spine > chest > neck > head; shoulder-less arms (upper_arm, forearm, hand)
  and legs (thigh, shin, foot), .L/.R.
- "Body": one skinned mesh (Skin-modifier sculpt) with material slots skin / shirt / forearm /
  pants / shoes. Godot recolours slots per resident; "forearm" is shirt (long sleeves) or skin.
  Shape keys "Figure" (hips/chest/waist) and "Heavy" (belly/width) give body variety.
- "Head" + face parts (eyes, pupils, brows, nose, mouth, ears): rigid on the head bone.
- Hair_short, Hair_long, Hair_doek, Hair_beanie, Hat_cap, Skirt: optional pieces Godot toggles.
- Accessories (Acc_glasses, Acc_sunglasses, Acc_beard, Acc_moustache, Acc_collar, Acc_chain,
  Acc_apron) and Hair_afro / Hair_ponytail for named characters.
- The aunty look: Dress (long house dress), Acc_hoops, Acc_curlers, Acc_handbag, Acc_cardigan
  (+ Acc_cardigan_armL/R sleeves).
- Actions: idle, walk, run, talk, guard, sit, lean, wave (loops), kick (one-shot); 24 fps. Walk = 1 s per two steps at
  1.5 m/s; run = 0.6 s at 4.5 m/s (Godot scales playback to the real speed).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "characters", "person.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 24

# ----------------------------------------------------------------------------- joints
# name: (head, tail, parent). Metres, Z up, front = -Y.
J = {
    "hips": ((0, 0, 0.94), (0, 0, 1.08), None),
    "spine": ((0, 0, 1.08), (0, 0, 1.26), "hips"),
    "chest": ((0, 0, 1.26), (0, 0, 1.47), "spine"),
    "neck": ((0, 0, 1.47), (0, 0, 1.56), "chest"),
    "head": ((0, 0, 1.56), (0, 0, 1.80), "neck"),
}
for side, s in (("L", 1), ("R", -1)):
    J["upper_arm." + side] = ((0.19 * s, 0.0, 1.43), (0.25 * s, 0.01, 1.17), "chest")
    J["forearm." + side] = ((0.25 * s, 0.01, 1.17), (0.29 * s, -0.02, 0.93), "upper_arm." + side)
    J["hand." + side] = ((0.29 * s, -0.02, 0.93), (0.30 * s, -0.03, 0.84), "forearm." + side)
    J["thigh." + side] = ((0.095 * s, 0.0, 0.93), (0.1 * s, -0.01, 0.51), "hips")
    J["shin." + side] = ((0.1 * s, -0.01, 0.51), (0.1 * s, 0.02, 0.09), "thigh." + side)
    J["foot." + side] = ((0.1 * s, 0.02, 0.09), (0.1 * s, -0.13, 0.03), "shin." + side)


def make_armature():
    arm_data = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", arm_data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (h, t, parent) in J.items():
        b = arm_data.edit_bones.new(name)
        b.head = h
        b.tail = t
        b.roll = 0.0
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = Vector(arm_data.edit_bones[parent].tail) == Vector(h)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


# ----------------------------------------------------------------------------- materials
def mat(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    return m


MATS = {n: mat(n, c) for n, c in {
    "skin": (0.55, 0.36, 0.25), "shirt": (0.8, 0.8, 0.8), "forearm": (0.8, 0.8, 0.8),
    "pants": (0.15, 0.2, 0.3), "shoes": (0.08, 0.08, 0.1), "hair": (0.05, 0.05, 0.06),
    "eye_white": (0.93, 0.92, 0.88), "pupil": (0.04, 0.03, 0.03), "lips": (0.35, 0.18, 0.15),
    "hat": (0.6, 0.2, 0.25), "skirt": (0.5, 0.25, 0.4),
    "acc_frame": (0.03, 0.03, 0.035), "acc_lens": (0.02, 0.02, 0.03), "acc_gold": (0.8, 0.6, 0.2),
    "acc_white": (0.95, 0.95, 0.93), "apron": (0.9, 0.9, 0.88),
    "face_paint": (1.0, 1.0, 1.0), "tie": (0.45, 0.1, 0.15), "overall": (0.18, 0.3, 0.55), "bag_red": (0.75, 0.12, 0.12),
    "phone_screen": (0.1, 0.2, 0.3), "soles": (0.92, 0.9, 0.86), "cap_logo": (1.0, 1.0, 1.0),
    "dress": (0.9, 0.4, 0.55), "cardigan": (0.85, 0.8, 0.7), "bag": (0.5, 0.2, 0.15), "acc_pink": (0.95, 0.55, 0.7),
    "uniform": (0.03, 0.05, 0.12), "vest": (0.02, 0.025, 0.04), "badge": (0.9, 0.7, 0.05), "belt": (0.015, 0.015, 0.018),
}.items()}


# ----------------------------------------------------------------------------- body
# Vertex skeleton for the Skin modifier: (position, radius x, radius y) with edges between.
BODY_PTS = {
    "pelvis": ((0, 0, 0.95), 0.150, 0.110),
    "waist": ((0, 0, 1.10), 0.128, 0.098),
    "belly": ((0, -0.005, 1.22), 0.140, 0.105),
    "chest": ((0, 0, 1.36), 0.165, 0.112),
    "shoulders": ((0, 0, 1.44), 0.150, 0.095),
    "neck": ((0, 0.005, 1.53), 0.050, 0.052),
    "neck_top": ((0, 0.01, 1.60), 0.046, 0.048),
}
for side, s in (("L", 1), ("R", -1)):
    BODY_PTS["shoulder" + side] = ((0.185 * s, 0, 1.425), 0.062, 0.062)
    BODY_PTS["elbow" + side] = ((0.25 * s, 0.01, 1.17), 0.046, 0.046)
    BODY_PTS["wrist" + side] = ((0.288 * s, -0.018, 0.94), 0.034, 0.030)
    BODY_PTS["hand" + side] = ((0.298 * s, -0.026, 0.87), 0.040, 0.020)
    BODY_PTS["hip" + side] = ((0.095 * s, 0, 0.90), 0.090, 0.090)
    BODY_PTS["knee" + side] = ((0.1 * s, -0.005, 0.51), 0.058, 0.058)
    BODY_PTS["calf" + side] = ((0.1 * s, 0.005, 0.36), 0.056, 0.056)
    BODY_PTS["ankle" + side] = ((0.1 * s, 0.015, 0.10), 0.040, 0.040)
    BODY_PTS["heel" + side] = ((0.1 * s, 0.03, 0.045), 0.046, 0.045)
    BODY_PTS["toe" + side] = ((0.1 * s, -0.12, 0.04), 0.048, 0.038)

BODY_EDGES = [("pelvis", "waist"), ("waist", "belly"), ("belly", "chest"), ("chest", "shoulders"),
              ("shoulders", "neck"), ("neck", "neck_top")]
for side in ("L", "R"):
    BODY_EDGES += [("shoulders", "shoulder" + side), ("shoulder" + side, "elbow" + side),
                   ("elbow" + side, "wrist" + side), ("wrist" + side, "hand" + side),
                   ("pelvis", "hip" + side), ("hip" + side, "knee" + side), ("knee" + side, "calf" + side),
                   ("calf" + side, "ankle" + side), ("ankle" + side, "heel" + side), ("heel" + side, "toe" + side)]


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for m in list(obj.modifiers):
        if m.type != "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=m.name)
    obj.select_set(False)


def make_body():
    names = list(BODY_PTS)
    me = bpy.data.meshes.new("Body")
    me.from_pydata([BODY_PTS[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in BODY_EDGES], [])
    obj = bpy.data.objects.new("Body", me)
    scene.collection.objects.link(obj)
    sk = obj.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.6
    for i, n in enumerate(names):
        sv = me.skin_vertices[0].data[i]
        sv.radius = (BODY_PTS[n][1], BODY_PTS[n][2])
        sv.use_root = n == "pelvis"
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    apply_modifiers(obj)
    for p in me.polygons:
        p.use_smooth = True
    return obj


def seg_dist(p, a, b):
    a, b = Vector(a), Vector(b)
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def add_hem_loops(obj):
    """Edge loops at the colour boundaries, so hems are straight instead of per-face jagged."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for z in (0.045, 0.13, 0.955, 1.0, 1.49):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1))
    bm.to_mesh(obj.data)
    bm.free()


def paint_body(obj):
    for n in ("skin", "shirt", "forearm", "pants", "shoes", "soles"):
        obj.data.materials.append(MATS[n])
    slot = {n: i for i, n in enumerate(("skin", "shirt", "forearm", "pants", "shoes", "soles"))}
    P = {n: Vector(v[0]) for n, v in BODY_PTS.items()}
    for poly in obj.data.polygons:
        c = obj.matrix_world @ poly.center
        best, region = 9.0, "torso"
        for side in ("L", "R"):
            for a, b, r in (("shoulder", "elbow", "upper"), ("elbow", "wrist", "fore"), ("wrist", "hand", "hand"),
                            ("hip", "knee", "leg"), ("knee", "ankle", "leg"), ("ankle", "toe", "foot")):
                d = seg_dist(c, P[a + side], P[b + side])
                if d < best:
                    best, region = d, r
        for a, b in (("pelvis", "waist"), ("waist", "chest"), ("chest", "shoulders"), ("shoulders", "neck_top")):
            d = seg_dist(c, P[a], P[b]) * 1.15
            if d < best:
                best, region = d, "torso"
        if region == "torso":
            name = "skin" if c.z > 1.49 else ("pants" if c.z < 1.0 else "shirt")
        elif region == "upper":
            name = "shirt"
        elif region == "fore":
            name = "forearm" if c.z > 0.955 else "skin"
        elif region == "hand":
            name = "skin"
        elif region == "foot":
            name = "soles" if c.z < 0.045 else "shoes"
        else:
            name = ("soles" if c.z < 0.045 else "shoes") if c.z < 0.13 else ("shirt" if c.z > 1.0 else "pants")
        poly.material_index = slot[name]


def add_shape_keys(obj):
    obj.shape_key_add(name="Basis")
    fig = obj.shape_key_add(name="Figure")
    heavy = obj.shape_key_add(name="Heavy")
    base = obj.data.vertices
    for i, v in enumerate(base):
        p = v.co
        arm = abs(p.x) > 0.17 and 0.85 < p.z < 1.45
        # Figure: fuller hips and thighs, narrower waist, chest, slightly narrower shoulders.
        d = Vector((0, 0, 0))
        if not arm:
            hip_w = math.exp(-((p.z - 0.92) / 0.12) ** 2)
            waist_w = math.exp(-((p.z - 1.12) / 0.06) ** 2)
            d.x += p.x * (0.22 * hip_w - 0.12 * waist_w)
            d.y += p.y * (0.12 * hip_w)
            if 1.25 < p.z < 1.42 and p.y < 0:
                bust = math.exp(-((p.z - 1.33) / 0.05) ** 2) * math.exp(-((abs(p.x) - 0.075) / 0.06) ** 2)
                d.y -= 0.045 * bust
            if p.z > 1.38:
                d.x -= p.x * 0.08
        fig.data[i].co = p + d
        # Heavy: belly forward, everything a little wider.
        h = Vector((p.x * 0.12, p.y * 0.08, 0))
        if not arm and 0.95 < p.z < 1.35 and p.y < 0.02:
            belly = math.exp(-((p.z - 1.15) / 0.11) ** 2)
            h.y -= 0.07 * belly * max(0.0, 1.0 - abs(p.x) / 0.16)
        if arm:
            h.x = p.x * 0.05
        heavy.data[i].co = p + h


# ----------------------------------------------------------------------------- head & pieces
def prim(kind, name, loc, scale=(1, 1, 1), material="skin", rot=(0, 0, 0), **kw):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("seg", 16), ring_count=kw.get("rings", 10), radius=1, location=loc)
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=2, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("seg", 16), radius=1, depth=2, location=loc)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("seg", 12), radius1=1, radius2=kw.get("r2", 0.0), depth=2, location=loc)
    elif kind == "torus_ring":  # thin ring, flat in XY; rot=(pi/2,0,0) stands it up facing -Y (glasses rims)
        bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=6, major_radius=1, minor_radius=0.12,
                                         location=loc)
    elif kind == "torus_thick":  # chunkier ring (hoop earrings, bag handles), flat in XY
        bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=6, major_radius=1, minor_radius=0.2,
                                         location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(MATS[material])
    if kw.get("smooth", True):
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


def cut_below(obj, z, keep_above=True, slope=0.0):
    """Removes the part of a mesh below (or above) a plane z (for caps and hair). slope > 0
    raises the cut at the front (a hairline above the forehead, lower at the nape)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, HEAD_C.y, z), plane_no=(0, slope, 1),
                           clear_inner=keep_above, clear_outer=not keep_above)
    bm.to_mesh(obj.data)
    bm.free()


HEAD_C = Vector((0, 0.005, 1.665))


def _g(v, c, w):
    return math.exp(-((v - c) / w) ** 2)


def sculpt_skull(o):
    """One skull mesh shaped in code: narrower jaw and chin, cheekbones, eye sockets, a brow
    ridge, a flatter face and a fuller back of the head. Coordinates are normalised to the skull
    radii (front = -Y)."""
    rx, ry, rz = 0.098, 0.108, 0.118
    for v in o.data.vertices:
        p = v.co - HEAD_C
        xn, yn, zn = p.x / rx, p.y / ry, p.z / rz
        front = max(0.0, -yn)
        k = max(0.0, min(1.0, (0.1 - zn) / 1.0))
        k = k * k * (3 - 2 * k)
        p.x *= 1.0 - 0.24 * k                                   # jaw tapers to the chin
        if yn > 0:
            p.y *= 1.0 - 0.32 * k                               # neck side of the jaw
        p.y *= 1.0 - 0.07 * front * _g(zn, 0.0, 0.55)          # flatter face
        p.y -= 0.011 * front * _g(zn, -0.8, 0.2) * _g(xn, 0, 0.35)   # chin
        p.y -= 0.004 * front * _g(zn, -0.45, 0.18) * _g(xn, 0, 0.3)  # mouth
        for sx in (1, -1):
            sock = _g(xn, 0.37 * sx, 0.17) * _g(zn, 0.15, 0.13) * front
            p.y += 0.008 * sock                                 # eye sockets
            cheek = _g(xn, 0.62 * sx, 0.18) * _g(zn, -0.12, 0.15) * front
            p.x += 0.005 * sx * cheek                           # cheekbones
            p.y -= 0.003 * cheek
        p.y -= 0.005 * front * _g(zn, 0.38, 0.09) * _g(abs(xn), 0.35, 0.3)   # brow ridge
        if yn > 0.3 and zn > -0.1:
            p.y *= 1.04                                         # fuller back of the head
        v.co = HEAD_C + p


def surf_y(o, x, z):
    """Front surface (most negative y) of a mesh at (x, z), by ray cast."""
    hit, loc, _n, _i = o.ray_cast(Vector((x, -0.5, z)), Vector((0, 1, 0)))
    return loc.y if hit else HEAD_C.y - 0.1


def make_head():
    skull = prim("sphere", "skull", HEAD_C, (0.098, 0.108, 0.118), seg=32, rings=24)
    sculpt_skull(skull)
    bpy.context.view_layer.update()
    sy = lambda x, z: surf_y(skull, x, HEAD_C.z + z)
    parts = [skull]
    # Nose: a narrow bridge widening to a rounded tip, with two nostril wings.
    nz = -0.012
    ny = sy(0, nz)
    nose = prim("sphere", "nose", (0, ny - 0.011, HEAD_C.z + nz), (0.013, 0.016, 0.032), seg=14, rings=10)
    for v in nose.data.vertices:
        t = (v.co.z - (HEAD_C.z + nz)) / 0.032           # -1 tip/bottom .. 1 bridge/top
        v.co.x *= 1.0 - 0.45 * max(0.0, t)
        v.co.y += 0.008 * max(0.0, t)                    # bridge sinks into the face
        if t < -0.3:
            v.co.y -= 0.004 * (-t - 0.3)                 # tip pushes forward
    parts.append(nose)
    for s in (1, -1):
        parts.append(prim("sphere", "wing", (0.0125 * s, sy(0.0125 * s, nz - 0.022) - 0.0015, HEAD_C.z + nz - 0.021),
                          (0.0065, 0.006, 0.0055), seg=10, rings=6))
        parts.append(prim("sphere", "ear", HEAD_C + Vector((0.094 * s, 0.004, -0.005)), (0.013, 0.022, 0.031), seg=12, rings=8))
    head = join(parts, "Head")
    face = []
    for s in (1, -1):
        ex, ez = 0.036 * s, HEAD_C.z + 0.018
        ey = sy(ex, 0.018) + 0.004
        face.append(prim("sphere", "eye", (ex, ey, ez), (0.016, 0.01, 0.012), "eye_white", seg=12, rings=8))
        face.append(prim("sphere", "pupil", (ex, ey - 0.008, ez - 0.001), (0.0085, 0.004, 0.0095), "pupil", seg=10, rings=6))
        by = sy(0.038 * s, 0.044)
        face.append(prim("cube", "brow", (0.038 * s, by - 0.003, HEAD_C.z + 0.046), (0.021, 0.005, 0.0045), "hair",
                         rot=(0, 0.12 * s, 0), smooth=False))
    # (The mouth and lips are painted on the face shell, see make_face_paint.)
    face = join(face, "Face")
    # Blink: skin-coloured lids over the eyes, and a dark open mouth for talking; Godot shows them.
    lids = []
    for s in (1, -1):
        ex, ez = 0.036 * s, HEAD_C.z + 0.018
        lid = prim("sphere", "lid", (ex, sy(ex, 0.018) + 0.0035, ez + 0.001), (0.018, 0.0115, 0.0135), seg=12, rings=8)
        cut_below(lid, ez - 0.004)
        lids.append(lid)
    blink = join(lids, "Blink")
    mouth = prim("sphere", "Mouth_open", (0, sy(0, -0.056) - 0.0005, HEAD_C.z - 0.057), (0.011, 0.003, 0.0055), "pupil", seg=10, rings=6)
    return head, face, blink, mouth


def make_fingers(side, s):
    """Four fingers and a thumb on a hand (rigid on hand.L/R): small, but hands stop looking like mittens."""
    parts = []
    hx = 0.298 * s
    for k, dy in enumerate((-0.0165, -0.0055, 0.0055, 0.0165)):
        length = (0.022, 0.025, 0.024, 0.019)[k]
        f = prim("sphere", "finger", (hx - 0.003 * s, -0.026 + dy, 0.866 - length), (0.0068, 0.0062, length), seg=8, rings=6,
                 rot=(0, -0.12 * s, 0))
        parts.append(f)
    parts.append(prim("sphere", "thumb", (hx - 0.01 * s, -0.047, 0.872), (0.0072, 0.0072, 0.02), seg=8, rings=6,
                      rot=(-0.6, -0.25 * s, 0)))
    return join(parts, "Fingers_" + side)


def make_face_paint(head):
    """A thin shell 1.5 mm in front of the face, front-projected UVs (0.2 m wide, chin to brow),
    for the painted face texture (eyelids, lips, wrinkles...). Mostly transparent in Godot."""
    paint = head.copy()
    paint.data = head.data.copy()
    paint.name = paint.data.name = "Face_paint"
    scene.collection.objects.link(paint)
    bm = bmesh.new()
    bm.from_mesh(paint.data)
    lo, hi = HEAD_C.z - 0.11, HEAD_C.z + 0.09
    drop = [f for f in bm.faces if f.normal.y > -0.2 or not (lo < f.calc_center_median().z < hi)
            or abs(f.calc_center_median().x) > 0.09]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    for v in bm.verts:
        v.co += v.normal * 0.0015
    bm.to_mesh(paint.data)
    bm.free()
    paint.data.materials.clear()
    paint.data.materials.append(MATS["face_paint"])
    while paint.data.uv_layers:
        paint.data.uv_layers.remove(paint.data.uv_layers[0])
    uv = paint.data.uv_layers.new(name="UVMap")
    for poly in paint.data.polygons:
        for li in poly.loop_indices:
            co = paint.data.vertices[paint.data.loops[li].vertex_index].co
            uv.data[li].uv = (0.5 + co.x / 0.2, (co.z - lo) / 0.2)
    return paint


def make_hair_pieces():
    out = []
    short = prim("sphere", "Hair_short", HEAD_C + Vector((0, 0.008, 0.012)), (0.104, 0.114, 0.12), "hair", seg=20, rings=14)
    cut_below(short, HEAD_C.z + 0.01, slope=0.45)
    out.append(short)
    cap = prim("sphere", "long_top", HEAD_C + Vector((0, 0.008, 0.012)), (0.106, 0.116, 0.122), "hair", seg=20, rings=14)
    cut_below(cap, HEAD_C.z + 0.0, slope=0.45)
    back = prim("cube", "long_back", HEAD_C + Vector((0, 0.07, -0.07)), (0.1, 0.045, 0.12), "hair")
    out.append(join([cap, back], "Hair_long"))
    doek = prim("sphere", "doek_top", HEAD_C + Vector((0, 0.02, 0.035)), (0.11, 0.122, 0.13), "hair", seg=20, rings=14)
    cut_below(doek, HEAD_C.z + 0.012, slope=0.3)
    knot = prim("sphere", "doek_knot", HEAD_C + Vector((0, 0.07, 0.14)), (0.06, 0.05, 0.045), "hair", seg=12, rings=8)
    out.append(join([doek, knot], "Hair_doek"))
    beanie = prim("sphere", "beanie_top", HEAD_C + Vector((0, 0.005, 0.03)), (0.108, 0.118, 0.13), "hair", seg=20, rings=14)
    cut_below(beanie, HEAD_C.z + 0.03)
    rim = prim("cyl", "beanie_rim", HEAD_C + Vector((0, 0.005, 0.045)), (0.111, 0.121, 0.022), "hair", seg=20)
    out.append(join([beanie, rim], "Hair_beanie"))
    dome = prim("sphere", "cap_dome", HEAD_C + Vector((0, 0.005, 0.03)), (0.108, 0.118, 0.122), "hat", seg=20, rings=14)
    cut_below(dome, HEAD_C.z + 0.035)
    brim = prim("cyl", "cap_brim", HEAD_C + Vector((0, -0.1, 0.04)), (0.075, 0.07, 0.006), "hat", seg=16, rot=(-0.12, 0, 0))
    out.append(join([dome, brim], "Hat_cap"))
    # Crew logo patch on the cap front (a small square with full 0..1 UVs; shown with the cap).
    bpy.ops.mesh.primitive_plane_add(size=1, location=HEAD_C + Vector((0, -0.1135, 0.07)), rotation=(math.pi / 2 + 0.38, 0, 0))
    logo = bpy.context.active_object
    logo.name = logo.data.name = "Acc_cap_logo"
    logo.scale = (0.05, 0.05, 0.05)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    logo.data.materials.append(MATS["cap_logo"])
    out.append(logo)
    skirt = prim("cone", "Skirt", (0, 0, 0.75), (0.25, 0.22, 0.26), "skirt", seg=24, r2=0.76)
    out.append(skirt)
    afro = prim("sphere", "Hair_afro", HEAD_C + Vector((0, 0.025, 0.05)), (0.14, 0.15, 0.135), "hair", seg=20, rings=14)
    cut_below(afro, HEAD_C.z - 0.01, slope=0.45)
    out.append(afro)
    pony_top = prim("sphere", "pony_top", HEAD_C + Vector((0, 0.008, 0.012)), (0.104, 0.114, 0.12), "hair", seg=20, rings=14)
    cut_below(pony_top, HEAD_C.z + 0.01, slope=0.45)
    tie = prim("sphere", "pony_tie", HEAD_C + Vector((0, 0.11, 0.05)), (0.03, 0.03, 0.03), "hair", seg=10, rings=6)
    tail = prim("cone", "pony_tail", HEAD_C + Vector((0, 0.135, -0.05)), (0.035, 0.035, 0.1), "hair", seg=10, r2=0.4,
                rot=(-0.25, 0, 0))
    out.append(join([pony_top, tie, tail], "Hair_ponytail"))
    out += make_more_hair()
    return out


def _on_skull(x, theta, lift):
    """A point on the skull surface (scaled by `lift`) in lane x, at angle theta measured from
    the front (0 = straight ahead at eye height, pi/2 = crown, pi = back)."""
    rx, ry, rz = 0.098, 0.108, 0.118
    f = math.sqrt(max(0.0, 1.0 - (x / rx) ** 2)) * lift
    return HEAD_C + Vector((x * lift, -ry * math.cos(theta) * f + 0.006, rz * math.sin(theta) * f + 0.004))


def make_more_hair():
    """Fade, cornrows, braids, curls and a bun (the hair colour slot)."""
    out = []
    # Fade: a skin-tight shell low on the sides, fuller on top.
    sides = prim("sphere", "fade_sides", HEAD_C + Vector((0, 0.006, 0.006)), (0.1, 0.11, 0.12), "hair", seg=24, rings=16)
    cut_below(sides, HEAD_C.z - 0.005, slope=0.45)
    top = prim("sphere", "fade_top", HEAD_C + Vector((0, 0.004, 0.022)), (0.103, 0.114, 0.125), "hair", seg=24, rings=16)
    cut_below(top, HEAD_C.z + 0.06, slope=0.25)
    out.append(join([sides, top], "Hair_fade"))
    # Cornrows: a close shell with raised rows running front to back.
    base = prim("sphere", "rows_base", HEAD_C + Vector((0, 0.006, 0.006)), (0.1, 0.11, 0.12), "hair", seg=24, rings=16)
    cut_below(base, HEAD_C.z + 0.01, slope=0.45)
    rows = [base]
    for x in (-0.06, -0.04, -0.02, 0.0, 0.02, 0.04, 0.06):
        th = 0.55
        while th < math.pi + 0.3:
            rows.append(prim("sphere", "bead", _on_skull(x, th, 1.02), (0.0085, 0.0085, 0.0085), "hair", seg=6, rings=4))
            th += 0.14
    out.append(join(rows, "Hair_cornrows"))
    # Braids: a close cap plus braids hanging to the shoulders from the sides and back.
    cap = prim("sphere", "braid_cap", HEAD_C + Vector((0, 0.008, 0.01)), (0.104, 0.114, 0.12), "hair", seg=20, rings=14)
    cut_below(cap, HEAD_C.z + 0.005, slope=0.45)
    braids = [cap]
    for k in range(16):
        a = math.pi * 0.15 + k * (math.pi * 0.7 / 15)      # round the back, ear to ear
        x = 0.1 * math.cos(a)
        y = 0.105 * math.sin(a) + 0.01
        top_pt = HEAD_C + Vector((x, y, -0.01 * (k % 2)))
        length = 0.2 + 0.03 * (k % 3)
        b = prim("cyl", "braid", top_pt + Vector((0, 0.01, -length / 2)), (0.0075, 0.0075, length / 2), "hair", seg=6)
        braids.append(b)
    out.append(join(braids, "Hair_braids"))
    # Curls: a cap of small tight curls.
    curls = [prim("sphere", "curl_base", HEAD_C + Vector((0, 0.008, 0.012)), (0.104, 0.114, 0.12), "hair", seg=20, rings=14)]
    cut_below(curls[0], HEAD_C.z + 0.01, slope=0.45)
    for x in (-0.075, -0.05, -0.025, 0.0, 0.025, 0.05, 0.075):
        th = 0.6 + (0.07 if int(x * 100) % 2 else 0.0)
        while th < math.pi + 0.2:
            c = _on_skull(x, th, 1.08)
            curls.append(prim("sphere", "curl", c, (0.019, 0.019, 0.018), "hair", seg=8, rings=6))
            th += 0.26
    out.append(join(curls, "Hair_curls"))
    # Bun: hair pulled back into a bun on the crown.
    pulled = prim("sphere", "bun_cap", HEAD_C + Vector((0, 0.008, 0.012)), (0.104, 0.114, 0.12), "hair", seg=20, rings=14)
    cut_below(pulled, HEAD_C.z + 0.01, slope=0.45)
    bun = prim("sphere", "bun", HEAD_C + Vector((0, 0.07, 0.11)), (0.042, 0.04, 0.036), "hair", seg=14, rings=10)
    tie = prim("torus_thick", "bun_tie", HEAD_C + Vector((0, 0.055, 0.092)), (0.03, 0.03, 0.03), "hair", rot=(0.9, 0, 0))
    out.append(join([pulled, bun, tie], "Hair_bun"))
    return out


def make_accessories():
    """Optional extras for named characters, shown by name from data (CharacterModel opts.accessories)."""
    out = []
    ey = HEAD_C.y - 0.1
    ez = HEAD_C.z + 0.017
    frames = []
    for s in (1, -1):
        frames.append(prim("torus_ring", "rim", (0.036 * s, ey - 0.004, ez), (0.021, 0.021, 0.021), "acc_frame",
                           rot=(math.pi / 2, 0, 0)))
        frames.append(prim("cube", "arm", (0.085 * s, ey + 0.05, ez + 0.005), (0.003, 0.05, 0.003), "acc_frame", smooth=False))
    frames.append(prim("cube", "bridge", (0, ey - 0.004, ez + 0.004), (0.012, 0.003, 0.003), "acc_frame", smooth=False))
    out.append(join(frames, "Acc_glasses"))
    shades = []
    for s in (1, -1):
        shades.append(prim("sphere", "lens", (0.037 * s, ey - 0.006, ez), (0.026, 0.007, 0.018), "acc_lens", seg=12, rings=6))
        shades.append(prim("cube", "arm", (0.085 * s, ey + 0.05, ez + 0.006), (0.003, 0.05, 0.004), "acc_frame", smooth=False))
    shades.append(prim("cube", "bridge", (0, ey - 0.006, ez + 0.006), (0.014, 0.003, 0.004), "acc_frame", smooth=False))
    out.append(join(shades, "Acc_sunglasses"))
    beard = prim("sphere", "Acc_beard", HEAD_C + Vector((0, -0.03, -0.06)), (0.085, 0.085, 0.07), "hair", seg=16, rings=10)
    cut_below(beard, HEAD_C.z - 0.045, keep_above=False)
    mo = prim("sphere", "mo", HEAD_C + Vector((0, -0.1, -0.038)), (0.032, 0.01, 0.009), "hair", seg=10, rings=6)
    out.append(join([beard, prim("sphere", "mo2", HEAD_C + Vector((0, -0.1, -0.038)), (0.03, 0.01, 0.008), "hair", seg=10, rings=6)], "Acc_beard"))
    mo.name = "Acc_moustache"
    mo.data.name = "Acc_moustache"
    out.append(mo)
    collar = prim("cyl", "Acc_collar", (0, 0.008, 1.535), (0.056, 0.058, 0.014), "acc_white", seg=16)
    out.append(collar)
    return out


def make_hoodie():
    """Hoodie extras in the shirt colour: the hood bunched behind the neck, a kangaroo pocket and
    two drawstrings (the body's shirt slot is the hoodie itself)."""
    hood = prim("sphere", "hood", (0, 0.085, 1.5), (0.13, 0.075, 0.085), "shirt", seg=16, rings=10)
    cut_below(hood, 1.43)
    rim = prim("torus_thick", "hood_rim", (0, 0.03, 1.5), (0.1, 0.08, 0.06), "shirt", rot=(0.3, 0, 0))
    pocket = prim("cube", "pocket", (0, -0.118, 1.06), (0.11, 0.018, 0.065), "shirt", smooth=False)
    for v in pocket.data.vertices:   # trapezoid, a little proud of the belly
        v.co.x *= 1.0 - (v.co.z - 1.0) * 1.2
    strings = [prim("cyl", "string", (s * 0.03, -0.105, 1.41), (0.004, 0.004, 0.06), "acc_white", seg=6) for s in (1, -1)]
    return [join([hood, rim, pocket] + strings, "Acc_hood")]


def make_everyday_pieces():
    """Tie and overall bib (torso, bound by height); phone (left hand) and a plastic shopping bag
    (right hand), rigid on the hand bones."""
    tie = prim("cube", "Acc_tie", (0, -0.128, 1.3), (0.022, 0.008, 0.13), "tie", smooth=False)
    for v in tie.data.vertices:   # wider at the bottom, following the chest
        v.co.x *= 1.0 + (1.36 - v.co.z) * 3.0
        v.co.y -= 0.012 * math.exp(-((v.co.z - 1.33) / 0.06) ** 2)
    knot = prim("cube", "knot", (0, -0.122, 1.44), (0.02, 0.01, 0.018), "tie", smooth=False)
    tie = join([tie, knot], "Acc_tie")
    bib = prim("cube", "bib", (0, -0.124, 1.16), (0.13, 0.012, 0.17), "overall", smooth=False)
    for v in bib.data.vertices:
        v.co.y -= 0.025 * math.exp(-((v.co.z - 1.2) / 0.12) ** 2)
    straps = [prim("cube", "strap", (s * 0.08, 0.0, 1.4), (0.022, 0.13, 0.012), "overall", rot=(0.0, 0, 0), smooth=False) for s in (1, -1)]
    pocket = prim("cube", "bib_pocket", (0, -0.14, 1.2), (0.06, 0.006, 0.05), "overall", smooth=False)
    overall = join([bib, pocket] + straps, "Acc_overall")
    phone = join([prim("cube", "phone", (0.29, -0.035, 0.84), (0.012, 0.035, 0.065), "acc_frame", smooth=False),
                  prim("cube", "screen", (0.277, -0.035, 0.84), (0.002, 0.03, 0.058), "phone_screen", smooth=False)], "Acc_phone")
    bag = prim("sphere", "bag", (-0.31, -0.025, 0.66), (0.05, 0.13, 0.14), "acc_white", seg=12, rings=8)
    for v in bag.data.vertices:
        v.co.z += 0.03 * math.sin(v.co.y * 40.0) * (1 if v.co.z < 0.66 else 0)   # crumpled
    stripe = prim("cube", "bag_stripe", (-0.31, -0.025, 0.7), (0.052, 0.125, 0.012), "bag_red", smooth=False)
    handle = prim("torus_thick", "bag_handle", (-0.31, -0.025, 0.82), (0.045, 0.045, 0.04), "acc_white", rot=(0, math.pi / 2, 0))
    shopbag = join([bag, stripe, handle], "Acc_shopbag")
    return [tie, overall], [(phone, "hand.L"), (shopbag, "hand.R")]


def make_body_accessories():
    """Chain and apron sit on the torso and bend with it."""
    chain = prim("torus_ring", "Acc_chain", (0, -0.015, 1.455), (0.088, 0.08, 0.088), "acc_gold", rot=(0.4, 0, 0))
    apron = prim("cube", "Acc_apron", (0, -0.125, 1.0), (0.15, 0.012, 0.3), "apron", smooth=False)
    for v in apron.data.vertices:  # follow the belly/chest curve a little
        v.co.y -= 0.02 * math.exp(-((v.co.z - 1.15) / 0.15) ** 2)
        v.co.x *= 1.0 + (1.0 - v.co.z) * 0.25
    return [chain, apron]


def cloth_uvs(obj, around=8, height=0.2):
    """Cylindrical UVs for printed cloth (house-dress prints): `around` repeats round the body
    and one repeat per 0.2 m of height; arms wrap around their own axis. Seams are fixed up
    per face so the print never smears."""
    while obj.data.uv_layers:
        obj.data.uv_layers.remove(obj.data.uv_layers[0])
    uv = obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        coords = []
        for li in poly.loop_indices:
            co = obj.data.vertices[obj.data.loops[li].vertex_index].co
            pc = poly.center
            if abs(pc.x) > 0.17 and 0.85 < pc.z < 1.45 and obj.name == "Body":
                # Wrap round the arm's own (slanted) axis: shoulder > elbow > wrist.
                t = max(0.0, min(1.0, (1.425 - co.z) / (1.425 - 0.94)))
                ax = 0.185 + (0.288 - 0.185) * t
                ay = -0.018 * t
                cx = ax if co.x > 0 else -ax
                u = (math.atan2(co.x - cx, co.y - ay) / (2 * math.pi)) * 4
            elif pc.z < 0.975 and obj.name == "Body":
                # Legs: once round each leg, mirrored, so u = 0.5 is the outer side of both
                # (tracksuit stripes) and the seam runs down the inside; denim scales it up.
                side = 1.0 if poly.center.x > 0 else -1.0
                u = ((math.atan2((co.x - side * 0.1) * side, co.y) + math.pi / 2) / (2 * math.pi)) % 1.0
            else:
                u = (math.atan2(co.x, co.y) / (2 * math.pi)) * around
            coords.append([u, co.z / height])
        us = [c[0] for c in coords]
        d = max(us) - min(us)
        span = around if d > around / 2 else (4 if d > 2 else (1 if d > 0.5 else 0))
        for c, li in zip(coords, poly.loop_indices):
            if span and c[0] < (max(us) + min(us)) / 2:
                c[0] += span
            uv.data[li].uv = c


def make_aunty_pieces():
    """The Mitchells Plain aunty look: a long house dress / maxi (Dress), bold gold hoops,
    curlers, a handbag in the left hand and a cardigan (torso + upper-arm sleeves; the forearm
    slot takes the cardigan colour in Godot). Returns (head pieces, other pieces with their bind)."""
    head = []
    hoops = []
    for s in (1, -1):
        hoops.append(prim("torus_thick", "hoop", HEAD_C + Vector((0.103 * s, 0.0, -0.058)), (0.026, 0.026, 0.026),
                          "acc_gold", rot=(0, math.pi / 2, 0)))
    head.append(join(hoops, "Acc_hoops"))
    curlers = []
    for k, a in enumerate((-0.55, -0.15, 0.25, 0.65, 1.05)):
        y = 0.118 * math.sin(a) + 0.005
        z = HEAD_C.z + 0.122 * math.cos(a) + 0.012
        curlers.append(prim("cyl", "curler", (0, y, z), (0.022, 0.022, 0.045), "acc_pink", seg=10, rot=(0, math.pi / 2, 0)))
        for sx in (1, -1):   # a row down each side
            if k in (1, 2, 3):
                curlers.append(prim("cyl", "curler", (0.09 * sx, y + 0.01, z - 0.045), (0.02, 0.02, 0.03), "acc_pink",
                                    seg=10, rot=(0, math.pi / 2, 0)))
    head.append(join(curlers, "Acc_curlers"))
    other = []
    # Long house dress: waist to just above the ankles, a little A-line.
    dress = prim("cone", "Dress", (0, 0.005, 0.6), (0.285, 0.255, 0.41), "dress", seg=28, r2=0.7)
    other.append((dress, "dress"))
    # Handbag held in the left hand (follows the arm swing).
    bag_body = prim("cube", "bag_body", (0.315, -0.03, 0.735), (0.032, 0.105, 0.075), "bag", smooth=False)
    flap = prim("cube", "bag_flap", (0.315, -0.03, 0.795), (0.035, 0.108, 0.02), "bag", smooth=False)
    clasp = prim("cube", "bag_clasp", (0.352, -0.03, 0.78), (0.004, 0.015, 0.012), "acc_gold", smooth=False)
    handle = prim("torus_thick", "bag_handle", (0.315, -0.03, 0.83), (0.06, 0.06, 0.045), "bag", rot=(0, math.pi / 2, 0))
    other.append((join([bag_body, flap, clasp, handle], "Acc_handbag"), "hand.L"))
    # Cardigan: an open-front knit shell over the torso, plus sleeves on the upper arms.
    shell = prim("cyl", "cardi_shell", (0, 0.003, 1.225), (0.192, 0.14, 0.235), "cardigan", seg=28)
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.normal.z) > 0.9 or (f.normal.y < -0.93)], context="FACES")
    bm.to_mesh(shell.data)
    bm.free()
    straps = [prim("cube", "cardi_shoulder", (s * 0.11, 0.0, 1.455), (0.075, 0.12, 0.025), "cardigan", smooth=False) for s in (1, -1)]
    other.append((join([shell] + straps, "Acc_cardigan"), "torso"))
    for side, s in (("L", 1), ("R", -1)):
        a = Vector((0.19 * s, 0.0, 1.43))
        b = Vector((0.25 * s, 0.01, 1.17))
        mid = (a + b) / 2
        d = (a - b).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(d).to_euler()
        sleeve = prim("cyl", "Acc_cardigan_arm" + side, mid, (0.07, 0.07, (a - b).length / 2 + 0.01), "cardigan", seg=14,
                      rot=tuple(rot))
        other.append((sleeve, "upper_arm." + side))
    return head, other


def bind_dress(obj, rig):
    """Long dress: the top follows the hips; lower down each side follows its thigh, and below
    the knee its shin too, so the hem swings with the stride."""
    groups = {n: obj.vertex_groups.new(name=n) for n in ("hips", "thigh.L", "thigh.R", "shin.L", "shin.R")}
    for v in obj.data.vertices:
        low = max(0.0, min(1.0, (0.97 - v.co.z) / 0.3))
        lateral = min(1.0, abs(v.co.x) / 0.12)
        front = max(0.0, min(1.0, -v.co.y / 0.12))   # the front drapes over the knees when sitting
        leg = low * min(1.0, 0.3 + 0.4 * lateral + 0.7 * front)
        knee = max(0.0, min(1.0, (0.5 - v.co.z) / 0.3)) * 0.5
        share = {"L": max(0.0, min(1.0, 0.5 + v.co.x / 0.12 * 0.5))}
        share["R"] = 1.0 - share["L"]
        groups["hips"].add([v.index], 1.0 - leg, "REPLACE")
        for side in ("L", "R"):
            w = leg * share[side]
            groups["thigh." + side].add([v.index], w * (1.0 - knee), "REPLACE")
            groups["shin." + side].add([v.index], w * knee, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig


def make_police_gear():
    """SAPS-inspired kit, matched to reference photos: navy baseball cap with a gold star badge,
    blue-grey body armour with shoulder straps and a front flap (POLICE lettering is added in Godot),
    black duty belt with a gold buckle and a holster on the right hip."""
    dome = prim("sphere", "pcap_dome", HEAD_C + Vector((0, 0.005, 0.03)), (0.109, 0.119, 0.124), "uniform", seg=20, rings=14)
    cut_below(dome, HEAD_C.z + 0.035)
    brim = prim("cyl", "pcap_brim", HEAD_C + Vector((0, -0.1, 0.04)), (0.078, 0.072, 0.006), "uniform", seg=16, rot=(-0.12, 0, 0))
    star = []
    for k in range(8):   # generic eight-point gold star badge (not the official emblem)
        a = k * math.pi / 4
        star.append(prim("cube", "ray", HEAD_C + Vector((math.cos(a) * 0.012, -0.121, 0.085 + math.sin(a) * 0.012)),
                         (0.006, 0.003, 0.016), "badge", rot=(0, a + math.pi / 2, 0), smooth=False))
    star.append(prim("sphere", "boss", HEAD_C + Vector((0, -0.124, 0.085)), (0.011, 0.004, 0.011), "badge", seg=10, rings=5))
    cap = join([dome, brim] + star, "Acc_police_cap")
    vest = prim("cyl", "vest_shell", (0, 0.0, 1.24), (0.184, 0.132, 0.21), "vest", seg=24)
    bm = bmesh.new()
    bm.from_mesh(vest.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.normal.z) > 0.9], context="FACES")
    bm.to_mesh(vest.data)
    bm.free()
    straps = [prim("cube", "strap", (s * 0.1, 0.0, 1.47), (0.04, 0.13, 0.025), "vest", smooth=False) for s in (1, -1)]
    flap = prim("cube", "vest_flap", (0, -0.136, 1.1), (0.15, 0.012, 0.07), "vest", smooth=False)
    vest = join([vest, flap] + straps, "Acc_police_vest")
    belt = prim("cyl", "belt_ring", (0, 0.0, 0.985), (0.158, 0.118, 0.028), "belt", seg=24)
    buckle = prim("cube", "buckle", (0, -0.12, 0.985), (0.03, 0.006, 0.022), "badge", smooth=False)
    holster = prim("cube", "holster", (-0.17, 0.02, 0.9), (0.03, 0.05, 0.09), "belt", smooth=False)
    pouch = prim("cube", "pouch", (0.165, -0.03, 0.95), (0.025, 0.04, 0.04), "belt", smooth=False)
    belt = join([belt, buckle, holster, pouch], "Acc_dutybelt")
    return [cap], [vest, belt]


# ----------------------------------------------------------------------------- skinning
def bind_rigid(obj, rig, bone):
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = rig
    m = obj.modifiers.new("Armature", "ARMATURE")
    m.object = rig


def bind_auto(obj, rig):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def bind_by_height(obj, rig):
    """Chest above 1.2 m, spine 1.05-1.2, hips below (for the apron and chain)."""
    groups = {n: obj.vertex_groups.new(name=n) for n in ("chest", "spine", "hips")}
    for v in obj.data.vertices:
        z = v.co.z
        w_chest = max(0.0, min(1.0, (z - 1.12) / 0.12))
        w_hips = max(0.0, min(1.0, (1.08 - z) / 0.12))
        w_spine = max(0.0, 1.0 - w_chest - w_hips)
        for n, w in (("chest", w_chest), ("spine", w_spine), ("hips", w_hips)):
            groups[n].add([v.index], w, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig


def bind_skirt(obj, rig):
    """Skirt follows hips and both thighs by height (auto weights tear a cone)."""
    groups = {n: obj.vertex_groups.new(name=n) for n in ("hips", "thigh.L", "thigh.R")}
    for v in obj.data.vertices:
        low = max(0.0, min(1.0, (0.95 - v.co.z) / 0.35))
        side = "thigh.L" if v.co.x > 0 else "thigh.R"
        lateral = min(1.0, abs(v.co.x) / 0.1)
        groups["hips"].add([v.index], 1.0 - low * lateral * 0.6, "REPLACE")
        groups[side].add([v.index], low * lateral * 0.6, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig


# ----------------------------------------------------------------------------- animation
def rest_rot(rig, bone):
    return rig.data.bones[bone].matrix_local.to_3x3().to_quaternion()


def set_rot(rig, bone, axis, angle):
    """Rotation about an armature-space axis ('X', 'Y', 'Z' or a vector), stored in bone space."""
    ax = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}.get(axis, axis) if isinstance(axis, str) else axis
    q_arm = Quaternion(ax, angle)
    r = rest_rot(rig, bone)
    pb = rig.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = r.inverted() @ q_arm @ r


def set_multi(rig, bone, rots):
    """Several armature-space rotations, applied in order."""
    q = Quaternion()
    for axis, angle in rots:
        ax = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[axis]
        q = Quaternion(ax, angle) @ q
    r = rest_rot(rig, bone)
    pb = rig.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = r.inverted() @ q @ r


def reset_pose(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
        pb.scale = Vector((1, 1, 1))


def key_all(rig, frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


# Front is -Y: a leg swinging forward rotates about +X by a negative angle... check: rotating the
# thigh (pointing down) about +X by +a moves its foot towards +Y (backwards). So forward = -a.
def pose_walk(rig, t, run=False):
    ph = t * 2 * math.pi
    s, c = math.sin(ph), math.cos(ph)
    swing = 0.62 if run else 0.42
    for side, sign in (("L", 1), ("R", -1)):
        leg = s * sign
        set_rot(rig, "thigh." + side, "X", -leg * swing)
        # Knee bends while the leg passes under the body and swings forward.
        lift = max(0.0, math.sin(ph + (0 if sign > 0 else math.pi) + 1.2))
        set_rot(rig, "shin." + side, "X", (1.25 if run else 0.75) * lift + 0.08)
        set_rot(rig, "foot." + side, "X", -0.25 * leg - (0.3 * lift if run else 0.15 * lift))
        arm = -leg
        set_multi(rig, "upper_arm." + side, [("X", -arm * (0.75 if run else 0.38)), ("Y", 0.0), ("Z", 0.08 * sign)])
        set_rot(rig, "forearm." + side, "X", -(1.35 if run else 0.25) - max(0.0, arm) * 0.25)
    bob = abs(c)
    rig.pose.bones["hips"].location = Vector((0, (0.05 if run else 0.025) * bob, 0))  # bone Y = up
    set_multi(rig, "hips", [("Z", s * 0.08)])
    set_multi(rig, "spine", [("X", -0.16 if run else -0.04), ("Z", -s * 0.06)])
    set_multi(rig, "chest", [("Z", -s * 0.07)])
    set_rot(rig, "neck", "X", 0.1 if run else 0.03)


def pose_idle(rig, t, extra=None):
    ph = t * 2 * math.pi
    breathe = math.sin(ph)
    sway = math.sin(ph * 0.5)
    set_multi(rig, "hips", [("Y", sway * 0.025)])
    rig.pose.bones["hips"].location = Vector((0, -0.004 + breathe * 0.002, 0))
    set_rot(rig, "chest", "X", -0.02 * breathe)
    set_multi(rig, "neck", [("X", 0.01 * breathe), ("Y", -sway * 0.02)])
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "upper_arm." + side, [("Y", 0.06 * sign), ("X", 0.02 * breathe)])
        set_rot(rig, "forearm." + side, "X", -0.18)
        set_rot(rig, "thigh." + side, "Y", -sway * 0.02 * sign)


def pose_talk(rig, t):
    pose_idle(rig, t)
    ph = t * 2 * math.pi
    set_multi(rig, "upper_arm.R", [("X", -0.35 - math.sin(ph * 2) * 0.12), ("Y", -0.15 - math.sin(ph) * 0.1)])
    set_multi(rig, "forearm.R", [("X", -1.15 - math.sin(ph * 2 + 0.6) * 0.25)])
    set_multi(rig, "hand.R", [("Y", math.sin(ph * 3) * 0.35)])
    set_multi(rig, "upper_arm.L", [("X", -0.12 + math.sin(ph + 1.3) * 0.08), ("Y", 0.06)])
    set_rot(rig, "forearm.L", "X", -0.75 - math.sin(ph + 1.0) * 0.25)
    set_multi(rig, "head", [("X", math.sin(ph * 2) * 0.05), ("Z", math.sin(ph) * 0.07)])


def pose_guard(rig, t):
    """Arms folded across the chest."""
    pose_idle(rig, t)
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "upper_arm." + side, [("Y", -0.22 * sign), ("X", -0.38)])
        set_multi(rig, "forearm." + side, [("Y", 1.5 * sign), ("X", -0.55)])
        set_multi(rig, "hand." + side, [("Y", 0.2 * sign)])
    set_multi(rig, "chest", [("X", 0.04)])
    set_multi(rig, "head", [("X", -0.05)])


def pose_idle_shift(rig, t):
    """Weight on the left leg, right knee relaxed, hips cocked (a slower, lazier idle)."""
    ph = t * 2 * math.pi
    breathe = math.sin(ph)
    rig.pose.bones["hips"].location = Vector((0.022, -0.012 + breathe * 0.002, 0))
    set_multi(rig, "hips", [("Y", 0.06)])
    set_multi(rig, "thigh.L", [("Y", -0.07)])
    set_multi(rig, "thigh.R", [("Y", -0.04), ("X", -0.12)])
    set_rot(rig, "shin.R", "X", 0.28)
    set_rot(rig, "foot.R", "X", -0.12)
    set_multi(rig, "spine", [("Y", -0.05)])
    set_rot(rig, "chest", "X", -0.02 * breathe)
    set_multi(rig, "neck", [("Y", -0.03), ("Z", math.sin(ph * 0.5) * 0.08)])
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "upper_arm." + side, [("Y", 0.08 * sign), ("X", 0.04 + 0.02 * breathe)])
        set_rot(rig, "forearm." + side, "X", -0.22)


def pose_idle_hips(rig, t):
    """Hands on the hips, elbows out."""
    pose_idle(rig, t)
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "upper_arm." + side, [("Y", -0.62 * sign), ("X", 0.2)])
        set_multi(rig, "forearm." + side, [("Y", 1.75 * sign), ("X", 0.35)])
        set_multi(rig, "hand." + side, [("Y", -0.3 * sign)])
    set_rot(rig, "chest", "X", -0.03)


def pose_phone(rig, t):
    """Left hand holding a phone to the ear, the head tilted to it."""
    pose_idle(rig, t)
    ph = t * 2 * math.pi
    set_multi(rig, "upper_arm.L", [("Y", -1.4), ("X", -0.6)])
    set_multi(rig, "forearm.L", [("Y", -2.45), ("X", -0.15)])
    set_multi(rig, "hand.L", [("Y", -0.3)])
    set_multi(rig, "head", [("Z", 0.12), ("X", math.sin(ph) * 0.04)])


def pose_sit(rig, t):
    """Seated on a 0.45 m bench/chair: the character's origin is the middle of the seat."""
    ph = t * 2 * math.pi
    breathe = math.sin(ph)
    rig.pose.bones["hips"].location = Vector((0, -0.43, 0.03))  # bone Y = up, bone Z = forward
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "thigh." + side, [("X", -1.52), ("Y", -0.06 * sign)])
        set_rot(rig, "shin." + side, "X", 1.42)
        set_rot(rig, "foot." + side, "X", 0.1)
        set_multi(rig, "upper_arm." + side, [("X", -0.42), ("Y", 0.08 * sign)])
        set_multi(rig, "forearm." + side, [("X", -0.65), ("Y", -0.25 * sign)])
    set_rot(rig, "spine", "X", 0.06)
    set_rot(rig, "chest", "X", 0.04 - 0.02 * breathe)
    set_multi(rig, "neck", [("X", -0.06), ("Y", math.sin(ph * 0.5) * 0.04)])


def pose_lean(rig, t):
    """Back against a wall behind (+Y in Blender), one foot up on it, hands in pockets."""
    ph = t * 2 * math.pi
    breathe = math.sin(ph)
    rig.pose.bones["hips"].location = Vector((0, -0.03, -0.05))
    set_rot(rig, "spine", "X", 0.1)
    set_rot(rig, "chest", "X", 0.03 - 0.02 * breathe)
    set_rot(rig, "neck", "X", -0.1)
    set_multi(rig, "thigh.L", [("X", -0.12), ("Y", -0.05)])
    set_rot(rig, "shin.L", "X", 0.05)
    set_multi(rig, "thigh.R", [("X", -0.55), ("Y", 0.08)])
    set_rot(rig, "shin.R", "X", 1.35)
    set_rot(rig, "foot.R", "X", -0.3)
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "upper_arm." + side, [("X", 0.22), ("Y", 0.12 * sign)])
        set_multi(rig, "forearm." + side, [("X", -0.45)])
    set_multi(rig, "head", [("Y", math.sin(ph * 0.5) * 0.05)])


def pose_wave(rig, t):
    pose_idle(rig, t)
    ph = t * 2 * math.pi
    set_multi(rig, "upper_arm.R", [("Y", 2.35), ("X", -0.35)])
    set_multi(rig, "forearm.R", [("Y", 0.55 + math.sin(ph * 2) * 0.35)])
    set_multi(rig, "hand.R", [("Y", math.sin(ph * 2 + 0.4) * 0.2)])
    set_multi(rig, "head", [("Z", -0.08), ("X", -0.04)])


def pose_kick(rig, t):
    """Right-foot kick: wind up (leg back), strike (leg forward), follow through, recover."""
    pose_idle(rig, t)
    # 0 -> 0.35 wind up, 0.35 -> 0.5 strike, 0.5 -> 1 recover
    if t < 0.35:
        k = t / 0.35
        swing = 0.7 * k
    elif t < 0.5:
        k = (t - 0.35) / 0.15
        swing = 0.7 - 1.9 * k
    else:
        k = (t - 0.5) / 0.5
        swing = -1.2 * (1.0 - k)
    set_rot(rig, "thigh.R", "X", swing)
    set_rot(rig, "shin.R", "X", max(0.0, swing) * 1.4 + 0.1)
    set_rot(rig, "thigh.L", "X", -0.12)
    set_rot(rig, "shin.L", "X", 0.25)
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "upper_arm." + side, [("Y", 0.55 * sign), ("X", swing * 0.4 * sign)])
    set_rot(rig, "spine", "X", 0.1 * max(0.0, -swing))


def pose_aim_pistol(rig, t):
    """Two-handed pistol aim straight ahead (upper body)."""
    pose_idle(rig, t)
    sway = math.sin(t * 2 * math.pi) * 0.015
    set_multi(rig, "upper_arm.R", [("X", -1.42 + sway), ("Y", 0.28)])
    set_multi(rig, "forearm.R", [("X", -0.12)])
    set_multi(rig, "upper_arm.L", [("X", -1.35 + sway), ("Y", -0.55)])
    set_multi(rig, "forearm.L", [("X", -0.2), ("Y", -0.35)])
    set_multi(rig, "chest", [("Z", 0.08)])
    set_multi(rig, "head", [("X", 0.04)])


def pose_aim_long(rig, t):
    """Shotgun at the shoulder: right hand at the grip, left hand forward on the pump."""
    pose_idle(rig, t)
    sway = math.sin(t * 2 * math.pi) * 0.012
    set_multi(rig, "upper_arm.R", [("X", -0.75 + sway), ("Y", 0.75)])
    set_multi(rig, "forearm.R", [("X", -0.95)])
    set_multi(rig, "upper_arm.L", [("X", -1.3 + sway), ("Y", -0.35)])
    set_multi(rig, "forearm.L", [("X", -0.25), ("Y", -0.5)])
    set_multi(rig, "chest", [("Z", 0.25)])
    set_multi(rig, "head", [("Z", -0.12), ("X", 0.06)])


def pose_hit(rig, t):
    """Flinch (one-shot): knocked back, arms up, recover."""
    k = math.sin(min(1.0, t * 1.6) * math.pi)
    pose_idle(rig, t)
    set_rot(rig, "spine", "X", 0.25 * k)
    set_rot(rig, "chest", "X", 0.2 * k)
    set_rot(rig, "head", "X", 0.3 * k)
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "upper_arm." + side, [("Y", 0.6 * k * sign), ("X", -0.4 * k)])
        set_rot(rig, "forearm." + side, "X", -0.9 * k)


def pose_down(rig, t):
    """Knocked down: on the back on the ground, slow breathing (no blood, no gore)."""
    breathe = math.sin(t * 2 * math.pi)
    rig.pose.bones["hips"].location = Vector((0, -0.8, 0.35))
    set_rot(rig, "hips", "X", -math.pi / 2)
    set_rot(rig, "chest", "X", -0.02 * breathe)
    set_multi(rig, "head", [("Z", 0.5)])
    for side, sign in (("L", 1), ("R", -1)):
        set_multi(rig, "upper_arm." + side, [("Y", 0.7 * sign)])
        set_rot(rig, "forearm." + side, "X", -0.4)
        set_multi(rig, "thigh." + side, [("Y", -0.12 * sign)])
    set_rot(rig, "shin.L", "X", 0.5)
    set_rot(rig, "thigh.L", "X", -0.3)


def bake_action(rig, name, frames, fn):
    reset_pose(rig)
    action = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = action
    for f in range(frames + 1):
        reset_pose(rig)
        fn(rig, f / frames)
        key_all(rig, f)
    for fc in action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    action.use_fake_user = True
    # Push to an NLA track so the exporter writes every action as its own animation.
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, action)
    rig.animation_data.action = None
    return action


# ----------------------------------------------------------------------------- build
rig = make_armature()
body = make_body()
add_hem_loops(body)
paint_body(body)
bind_auto(body, rig)
add_shape_keys(body)
head, face, blink, mouth = make_head()
for o in (head, face, blink, mouth, make_face_paint(head)):
    bind_rigid(o, rig, "head")
for side, sgn in (("L", 1), ("R", -1)):
    bind_rigid(make_fingers(side, sgn), rig, "hand." + side)
for piece in make_hair_pieces() + make_accessories():
    if piece.name == "Skirt":
        bind_skirt(piece, rig)
    else:
        bind_rigid(piece, rig, "head")
everyday_torso, everyday_hands = make_everyday_pieces()
for piece, bone in everyday_hands:
    bind_rigid(piece, rig, bone)
for piece in make_body_accessories() + make_hoodie() + everyday_torso:
    bind_by_height(piece, rig)
aunty_head, aunty_other = make_aunty_pieces()
for piece in aunty_head:
    bind_rigid(piece, rig, "head")
for piece, how in aunty_other:
    if how == "dress":
        bind_dress(piece, rig)
    elif how == "torso":
        bind_by_height(piece, rig)
    else:
        bind_rigid(piece, rig, how)
police_head, police_body = make_police_gear()
for piece in police_head:
    bind_rigid(piece, rig, "head")
for piece in police_body:
    bind_by_height(piece, rig)

bake_action(rig, "idle", 72, pose_idle)
bake_action(rig, "walk", 24, lambda r, t: pose_walk(r, t, False))
bake_action(rig, "run", 15, lambda r, t: pose_walk(r, t, True))
bake_action(rig, "idle_shift", 96, pose_idle_shift)
bake_action(rig, "idle_hips", 72, pose_idle_hips)
bake_action(rig, "talk", 72, pose_talk)
bake_action(rig, "phone", 72, pose_phone)
bake_action(rig, "guard", 72, pose_guard)
bake_action(rig, "sit", 96, pose_sit)
bake_action(rig, "lean", 96, pose_lean)
bake_action(rig, "wave", 24, pose_wave)
bake_action(rig, "kick", 14, pose_kick)
bake_action(rig, "aim_pistol", 48, pose_aim_pistol)
bake_action(rig, "aim_long", 48, pose_aim_long)
bake_action(rig, "hit", 12, pose_hit)
bake_action(rig, "down", 72, pose_down)
reset_pose(rig)

for o in scene.objects:
    if o.name == "Body":
        cloth_uvs(o, 6, 0.15)
    elif o.name == "Dress":
        cloth_uvs(o, 9, 0.17)
    elif o.name.startswith("Acc_cardigan"):
        cloth_uvs(o)
# Every other mesh gets a (flat) UV map: Godot's importer needs UVs to build tangents.
for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
    export_morph=True, export_skins=True, export_apply=False, export_yup=True,
    export_def_bones=False, export_optimize_animation_size=True)
print("WROTE", OUT, "verts", len(body.data.vertices))
