"""Close-up do quadril na pose de passo largo (diagnostico de buracos)."""
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
b.inputs["Base Color"].default_value = (0.75, 0.42, 0.22, 1)
b.inputs["Roughness"].default_value = 0.45
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        ob.data.materials.clear()
        ob.data.materials.append(clay)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.38, 0.45, 1)

for nome, energia, rot in (
    ("Key", 5.0, (math.radians(45), 0, math.radians(25))),
    ("Fill", 3.0, (math.radians(75), 0, math.radians(230))),
    ("Top", 2.5, (math.radians(5), 0, math.radians(90))),
):
    ld = bpy.data.lights.new(nome, type="SUN")
    ld.energy = energia
    lo = bpy.data.objects.new(nome, ld)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = rot

cam_d = bpy.data.cameras.new("Cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 1.4
cam = bpy.data.objects.new("Cam", cam_d)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.samples = 40
cena.cycles.use_denoising = False
cena.render.resolution_x = 800
cena.render.resolution_y = 800

esq.reset()
esq.mover_hips(0, 0, -0.09)
esq.perna("L", (0.245, 0.14, 0.10), (0.245, 0.48, 0.03))
esq.perna("R", (-0.245, -0.24, 0.14), (-0.245, 0.10, 0.06))
esq.aplicar()

alvo = Vector((0.0, -0.15, 0.62))


def visao(nome, direcao, escala=1.4):
    cam_d.ortho_scale = escala
    pos = alvo + Vector(direcao).normalized() * 3
    cam.location = pos
    cam.rotation_euler = (alvo - pos).normalized().to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = os.path.join(C.SAIDA, nome + ".png")
    bpy.ops.render.render(write_still=True)


visao("60_quadril_frente", (0.0, 1.0, -0.05), 1.6)
visao("61_quadril_lado", (1.0, 0.1, 0.0), 1.6)
visao("62_quadril_baixo", (0.3, 0.5, -0.9), 1.8)

print("###OK###")
