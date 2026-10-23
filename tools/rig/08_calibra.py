"""Calibra a pose base com IK: pes plantados, mandibula fechada, inclinacoes.

blender --background --python tools/rig/08_calibra.py
"""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import trex_comum as C
from trex_esqueleto import Esqueleto

bpy.ops.wm.open_mainfile(filepath=os.path.join(C.SAIDA, "trex_rig.blend"))
arm = bpy.data.objects["TRexRig"]
esq = Esqueleto(arm)

clay = bpy.data.materials.new("clay")
clay.use_nodes = True
b = clay.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.72, 0.38, 0.18, 1)
b.inputs["Roughness"].default_value = 0.5
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        ob.data.materials.clear()
        ob.data.materials.append(clay)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.30, 0.33, 0.40, 1)

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
cam_d.type = "ORTHO"
cam_d.ortho_scale = 4.6
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


def render(nome, direcao, distancia=6.5):
    pos = CENTRO + Vector(direcao).normalized() * distancia
    cam.location = pos
    cam.rotation_euler = (CENTRO - pos).normalized().to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = os.path.join(C.SAIDA, nome + ".png")
    bpy.ops.render.render(write_still=True)


X_ESQ = 0.245
X_DIR = -0.245
Y_BASE = -0.06


def pes(esq, yl=Y_BASE, yr=Y_BASE, zl=0.10, zr=0.10):
    esq.perna("L", (X_ESQ, yl, zl), (X_ESQ, yl + 0.34, zl - 0.075))
    esq.perna("R", (X_DIR, yr, zr), (X_DIR, yr + 0.34, zr - 0.075))


def neutral(esq, dz=-0.08):
    esq.reset()
    esq.mover_hips(0, 0, dz)
    pes(esq)


# A: neutro com IK
neutral(esq)
esq.aplicar()
render("50_neutro_ik", (1.1, -0.6, 0.5))
render("51_neutro_ik_frente", (0.0, 1.0, 0.12))

# B: mandibula fechada
neutral(esq)
esq.girar("jaw", "X", 38)
esq.aplicar()
render("52_mandibula_fechada", (1.1, -0.6, 0.5))

# C: cabeca para cima + cauda erguida
neutral(esq)
esq.girar("neck", "X", 12)
esq.girar("head", "X", 18)
esq.girar("tail_01", "X", -14)
esq.girar("tail_02", "X", -8)
esq.aplicar()
render("53_cabeca_cima", (1.1, -0.6, 0.5))

# D: inclinacao do corpo para frente
neutral(esq)
esq.mover_hips(0, 0, -0.08, pitch=10)
pes(esq, yl=0.02, yr=0.02)
esq.girar("head", "X", -10)
esq.aplicar()
render("54_corpo_frente", (1.1, -0.6, 0.5))

# E: passo largo
esq.reset()
esq.mover_hips(0, 0, -0.09)
esq.perna("L", (X_ESQ, 0.14, 0.10), (X_ESQ, 0.48, 0.03))
esq.perna("R", (X_DIR, -0.24, 0.14), (X_DIR, 0.10, 0.06))
esq.aplicar()
render("55_passo_largo", (1.1, -0.6, 0.5))
render("55_passo_largo_b", (0.0, 1.0, 0.12))

print("###OK###")
