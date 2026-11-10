"""Builds the weapons: assets/models/weapons/weapons.glb (stylised, generic, no real brands).

Run headless:  blender -b --factory-startup --python tools/blender/build_weapons.py
Each weapon's origin is where the right hand grips it; the barrel points -Y (Godot +Z).
  pistol  - service-style semi-automatic handgun
  shotgun - pump-action with a wooden fore-end and stock
Material slots: gunmetal, polymer, wood, sight.
"""
import math
import os

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "weapons", "weapons.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, rgb, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


M = {"gunmetal": mat("gunmetal", (0.05, 0.055, 0.06), 0.4, 0.8), "polymer": mat("polymer", (0.02, 0.02, 0.022), 0.8),
     "wood": mat("wood", (0.28, 0.13, 0.05), 0.7), "sight": mat("sight", (0.9, 0.9, 0.85), 0.5)}


def box(center, size, material, rot=(0, 0, 0), bevel=0.004):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    o = bpy.context.active_object
    o.scale = size
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.location = center
    bpy.ops.object.transform_apply(location=True)
    o.data.materials.append(M[material])
    if bevel:
        bv = o.modifiers.new("b", "BEVEL")
        bv.width, bv.segments = bevel, 1
        bpy.ops.object.modifier_apply(modifier=bv.name)
    return o


def tube(center, radius, length, material, seg=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=radius, depth=length, location=center, rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(M[material])
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def join(parts, name, x):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = o.data.name = name
    o.location.x = x
    return o


def pistol():
    p = [box((0, -0.06, 0.055), (0.028, 0.19, 0.032), "gunmetal")]                      # slide
    p.append(box((0, -0.055, 0.03), (0.026, 0.17, 0.022), "polymer"))                   # frame
    p.append(box((0, 0.0, -0.02), (0.026, 0.045, 0.1), "polymer", rot=(-0.25, 0, 0)))  # grip
    p.append(box((0, -0.04, 0.0), (0.008, 0.04, 0.004), "polymer"))                     # trigger guard
    p.append(tube((0, -0.16, 0.055), 0.006, 0.01, "polymer", 8))                        # muzzle
    p.append(box((0, -0.145, 0.075), (0.004, 0.006, 0.006), "sight"))
    return join(p, "pistol", 0)


def shotgun():
    p = [box((0, -0.05, 0.03), (0.04, 0.22, 0.06), "gunmetal")]                          # receiver
    p.append(tube((0, -0.45, 0.045), 0.012, 0.6, "gunmetal"))                           # barrel
    p.append(tube((0, -0.38, 0.018), 0.011, 0.45, "gunmetal"))                          # magazine tube
    p.append(box((0, -0.36, 0.02), (0.045, 0.18, 0.045), "wood"))                       # pump
    p.append(box((0, 0.01, -0.03), (0.032, 0.04, 0.08), "wood", rot=(-0.35, 0, 0)))    # grip
    p.append(box((0, 0.16, -0.02), (0.036, 0.26, 0.07), "wood", rot=(0.18, 0, 0)))     # stock
    p.append(box((0, -0.74, 0.062), (0.004, 0.008, 0.008), "sight"))
    return join(p, "shotgun", 1.0)


pistol()
shotgun()
for o in scene.objects:
    if o.type == "MESH" and not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("WROTE", OUT)
