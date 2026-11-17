"""Makes the Mixamo NPC bodies phone-friendly.  Run:  blender -b --factory-startup --python tools/blender/lighten_mixamo.py

Reads assets/models/characters/npc/source/<Name>.glb (the files as downloaded from Mixamo, With Skin, not imported by
Godot: there is a .gdignore) and writes assets/models/characters/npc/<Name>.glb:
  * every mesh except the eyelashes is decimated (skin weights are kept): about 45% of the triangles remain,
  * each material keeps only its Diffuse texture (the Specular, Glossiness, Normal and metallic inputs make the clothes
    shiny and cost texture reads on a phone), so the file is a fraction of the size.
The skeleton, bone names and animation-free layout are untouched: Remy's clips drive these bodies (RemyModel).
"""
import bpy, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "models", "characters", "npc", "source")
OUT = os.path.join(ROOT, "assets", "models", "characters", "npc")
NAMES = ["James", "Kate", "Leonard", "Louise", "Meegan"]
RATIO = 0.45          # share of the triangles that stay on skin, clothes and shoes
HAIR_RATIO = 0.5      # hair cards are thin: they are thinned less
KEEP_WHOLE = ("eyelash", "eyelass")   # tiny, and decimation would tear the lashes


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def decimate(obj, ratio):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    mod = obj.modifiers.new("Lighten", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)


def diffuse_only(mat):
    """Keep the Principled BSDF and its base colour image; unlink everything else."""
    if not mat.use_nodes:
        return
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return
    keep_input = {"Base Color", "Alpha"}
    for inp in bsdf.inputs:
        if inp.name in keep_input:
            continue
        for link in list(inp.links):
            nt.links.remove(link)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.9
    for n in list(nt.nodes):
        if n.type in {"TEX_IMAGE", "NORMAL_MAP", "SEPARATE_COLOR", "MATH", "MIX", "INVERT", "MAPPING", "TEX_COORD"}:
            outs = [l for o in n.outputs for l in o.links]
            if not outs:
                nt.nodes.remove(n)


def build(name):
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    before = after = 0
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        n = tris(obj)
        before += n
        low = obj.name.lower()
        if any(k in low for k in KEEP_WHOLE):
            after += n
        else:
            hair = "hair" in low or any("hair" in (s.material.name.lower() if s.material else "") for s in obj.material_slots)
            decimate(obj, HAIR_RATIO if hair else RATIO)
            after += tris(obj)
    for mat in bpy.data.materials:
        diffuse_only(mat)
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)
    out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="AUTO", export_apply=False,
                              export_skins=True, export_animations=False, export_yup=True)
    print("WROTE %s  triangles %d -> %d  (%s bytes)" % (out, before, after, os.path.getsize(out)))


for nm in NAMES:
    build(nm)
