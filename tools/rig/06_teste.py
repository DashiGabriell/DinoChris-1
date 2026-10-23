"""Testes de deformacao: poses extremas e renders para inspecao visual.

blender --background --python tools/rig/06_teste.py
"""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import trex_comum as C
import trex_pose as P

bpy.ops.wm.open_mainfile(filepath=os.path.join(C.SAIDA, "trex_rig.blend"))
arm = bpy.data.objects["TRexRig"]

clay = bpy.data.materials.new("clay")
clay.use_nodes = True
b = clay.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.7, 0.36, 0.18, 1)
b.inputs["Roughness"].default_value = 0.5
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        ob.data.materials.clear()
        ob.data.materials.append(clay)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.30, 0.33, 0.40, 1)
mundo.node_tree.nodes["Background"].inputs[1].default_value = 0.8

for nome, energia, rot in (
    ("Key", 4.5, (math.radians(52), 0, math.radians(35))),
    ("Fill", 2.0, (math.radians(68), 0, math.radians(215))),
    ("Rim", 3.5, (math.radians(110), 0, math.radians(130))),
):
    ld = bpy.data.lights.new(nome, type="SUN")
    ld.energy = energia
    lo = bpy.data.objects.new(nome, ld)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = rot

cam_d = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_d)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.samples = 24
cena.cycles.use_denoising = False
cena.render.resolution_x = 720
cena.render.resolution_y = 720

CENTRO = Vector((0, -0.35, 0.95))


def render(nome, direcao, distancia=6.5, orto=True):
    pos = CENTRO + Vector(direcao).normalized() * distancia
    cam.location = pos
    d = (CENTRO - pos).normalized()
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    if orto:
        cam_d.type = "ORTHO"
        cam_d.ortho_scale = 4.6
    else:
        cam_d.type = "PERSP"
        cam_d.lens = 55
    cena.render.filepath = os.path.join(C.SAIDA, nome + ".png")
    bpy.ops.render.render(write_still=True)


def aplicar(poses):
    P.limpar(arm)
    for nome, eixo, graus in poses:
        P.girar(arm, nome, eixo, graus)


POSE_PASSO = [
    ("spine_01", "X", 4), ("neck", "X", 10), ("head", "X", -6), ("jaw", "X", 8),
    ("thigh_L", "X", -28), ("shin_L", "X", 42), ("foot_L", "X", -14),
    ("thigh_R", "X", 22), ("shin_R", "X", 4),
    ("upperarm_L", "X", 25), ("upperarm_R", "X", 25),
    ("tail_01", "X", -10), ("tail_02", "X", 8),
]

POSE_EXTREMO = [
    ("hips", "X", -8), ("spine_01", "X", 10), ("spine_02", "X", 8),
    ("neck", "X", 18), ("head", "X", -12), ("jaw", "X", 40),
    ("thigh_L", "X", -42), ("shin_L", "X", 68), ("foot_L", "X", -20),
    ("thigh_R", "X", 30), ("shin_R", "X", -12),
    ("upperarm_L", "X", 45), ("forearm_L", "X", 35),
    ("upperarm_R", "X", 45), ("forearm_R", "X", 35),
    ("tail_01", "X", -18), ("tail_02", "X", 14), ("tail_03", "X", 12),
]

POSE_CABECA = [
    ("neck", "Z", 22), ("head", "Z", 30), ("jaw", "X", 45),
    ("spine_02", "Z", 8), ("tail_01", "Z", -18), ("tail_02", "Z", -14),
]

for nome, poses in (("30_passo", POSE_PASSO), ("31_extremo", POSE_EXTREMO), ("32_cabeca", POSE_CABECA)):
    aplicar(poses)
    render(nome + "_a", (1.1, -0.6, 0.55))
    render(nome + "_b", (0.05, -1.0, 0.35))
    render(nome + "_c", (1.0, 0.15, 0.25))

P.limpar(arm)
render("33_repouso_a", (1.1, -0.6, 0.55))
render("33_repouso_b", (0.05, -1.0, 0.35))
render("33_repouso_c", (0.0, 1.0, 0.12))
render("33_repouso_d", (0.0, -1.0, 0.12))

print("###OK###")
