"""Checa bordas abertas (furos) nas malhas e renderiza close do quadril."""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import trex_comum as C
import trex_pose as P

bpy.ops.wm.open_mainfile(filepath=os.path.join(C.SAIDA, "trex_rig.blend"))
arm = bpy.data.objects["TRexRig"]

print("###BORDAS###")
for ob in bpy.context.scene.objects:
    if ob.type != "MESH":
        continue
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    abertas = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    nao_manifold = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    print("{:12s} bordas_abertas={:5d} nao_manifold={:4d}".format(ob.name, abertas, nao_manifold))
    bm.free()

# close do quadril: pose de passo
POSE = [("thigh_L", "X", -28), ("shin_L", "X", 42), ("foot_L", "X", -14),
        ("thigh_R", "X", 22), ("shin_R", "X", 4)]
P.limpar(arm)
for n, e, g in POSE:
    P.girar(arm, n, e, g)

clay = bpy.data.materials.new("clay")
clay.use_nodes = True
b = clay.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.75, 0.4, 0.2, 1)
b.inputs["Roughness"].default_value = 0.45
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        ob.data.materials.clear()
        ob.data.materials.append(clay)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.35, 0.42, 1)

for nome, energia, rot in (
    ("Key", 4.5, (math.radians(50), 0, math.radians(20))),
    ("Fill", 2.5, (math.radians(70), 0, math.radians(220))),
):
    ld = bpy.data.lights.new(nome, type="SUN")
    ld.energy = energia
    lo = bpy.data.objects.new(nome, ld)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = rot

cam_d = bpy.data.cameras.new("Cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 1.1
cam = bpy.data.objects.new("Cam", cam_d)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.samples = 32
cena.cycles.use_denoising = False
cena.render.resolution_x = 800
cena.render.resolution_y = 800

alvo = Vector((0.1, 0.05, 0.55))


def close(nome, direcao):
    pos = alvo + Vector(direcao).normalized() * 3
    cam.location = pos
    cam.rotation_euler = (alvo - pos).normalized().to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = os.path.join(C.SAIDA, nome + ".png")
    bpy.ops.render.render(write_still=True)


close("40_close_quadril_a", (0.6, -0.8, 0.15))
close("41_close_quadril_b", (1.0, -0.2, 0.05))
close("42_close_quadril_c", (0.2, -1.0, -0.1))

alvo2 = Vector((0.0, 0.95, 1.25))
cam_d.ortho_scale = 0.9


def close2(nome, direcao):
    pos = alvo2 + Vector(direcao).normalized() * 3
    cam.location = pos
    cam.rotation_euler = (alvo2 - pos).normalized().to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = os.path.join(C.SAIDA, nome + ".png")
    bpy.ops.render.render(write_still=True)


close2("43_close_pescoco", (0.8, -0.6, 0.2))

print("###OK###")
