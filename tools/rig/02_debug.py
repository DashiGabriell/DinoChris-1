"""Renders de diagnostico com material clay: enquadramento correto e varias vistas.

blender --background --python tools/rig/02_debug.py
"""
import bpy
import math
import os
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GLB = os.path.join(RAIZ, "assets", "modelos", "jogador", "trexChris.glb")
SAIDA = os.path.join(RAIZ, "tools", "rig", "out")
os.makedirs(SAIDA, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

malhas = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bbox(objetos):
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for ob in objetos:
        for c in ob.bound_box:
            p = ob.matrix_world @ Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], p[i])
                mx[i] = max(mx[i], p[i])
    return mn, mx


mn, mx = bbox(malhas)
centro = (mn + mx) / 2
dim = mx - mn
print("###BBOX###", [round(v, 4) for v in mn], [round(v, 4) for v in mx], [round(v, 4) for v in dim])

clay = bpy.data.materials.new("clay")
clay.use_nodes = True
bsdf = clay.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.65, 0.35, 0.2, 1)
bsdf.inputs["Roughness"].default_value = 0.55

for ob in malhas:
    ob.data.materials.clear()
    ob.data.materials.append(clay)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.38, 0.45, 1)
mundo.node_tree.nodes["Background"].inputs[1].default_value = 0.7

for nome, energia, rot in (
    ("Key", 4.0, (math.radians(50), 0, math.radians(40))),
    ("Fill", 2.0, (math.radians(65), 0, math.radians(210))),
    ("Rim", 3.0, (math.radians(115), 0, math.radians(120))),
):
    ld = bpy.data.lights.new(nome, type="SUN")
    ld.energy = energia
    lo = bpy.data.objects.new(nome, ld)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = rot

cam_d = bpy.data.cameras.new("Cam")
cam_d.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cam_d)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.samples = 32
cena.cycles.use_denoising = False
cena.render.resolution_x = 800
cena.render.resolution_y = 800

maior = max(dim)
cam_d.ortho_scale = maior * 1.18
dist = maior * 3


def vista(nome, pos, alvo=None, orto=True):
    alvo = alvo or centro
    cam_d.type = "ORTHO" if orto else "PERSP"
    if not orto:
        cam_d.lens = 50
    cam.location = pos
    d = (Vector(alvo) - Vector(pos)).normalized()
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = os.path.join(SAIDA, nome + ".png")
    bpy.ops.render.render(write_still=True)


vista("10_clay_frente_negY", centro + Vector((0, -dist, 0)))
vista("11_clay_lado_posX", centro + Vector((dist, 0, 0)))
vista("12_clay_lado_negX", centro + Vector((-dist, 0, 0)))
vista("13_clay_topo", centro + Vector((0, 0, dist)))
vista("14_clay_tresp", centro + Vector((dist * 0.7, -dist * 0.7, dist * 0.45)), orto=False)
vista("15_clay_tresp_outro", centro + Vector((-dist * 0.7, -dist * 0.7, dist * 0.45)), orto=False)

print("###OK###")
