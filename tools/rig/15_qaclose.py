"""Close-ups de QA: cabeca no rugido e corpo no pulo."""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import trex_comum as C

bpy.ops.wm.open_mainfile(filepath=os.path.join(C.SAIDA, "trex_anim.blend"))
arm = bpy.data.objects["TRexRig"]

clay = bpy.data.materials.new("clay")
clay.use_nodes = True
b = clay.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.75, 0.4, 0.2, 1)
b.inputs["Roughness"].default_value = 0.5
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        ob.data.materials.clear()
        ob.data.materials.append(clay)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.34, 0.37, 0.44, 1)

for nome, energia, rot in (
    ("Key", 5.0, (math.radians(50), 0, math.radians(30))),
    ("Fill", 3.0, (math.radians(70), 0, math.radians(220))),
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
cena.cycles.samples = 40
cena.cycles.use_denoising = False
cena.render.resolution_x = 820
cena.render.resolution_y = 820

arm.animation_data_create()


def usar(clipe, quadro):
    acao = bpy.data.actions[clipe]
    arm.animation_data.action = acao
    if hasattr(arm.animation_data, "action_slot") and len(acao.slots):
        arm.animation_data.action_slot = acao.slots[0]
    cena.frame_set(quadro)


def foto(nome, alvo, direcao, escala):
    cam_d.ortho_scale = escala
    pos = Vector(alvo) + Vector(direcao).normalized() * 6
    cam.location = pos
    cam.rotation_euler = (Vector(alvo) - pos).normalized().to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = os.path.join(C.SAIDA, nome + ".png")
    bpy.ops.render.render(write_still=True)


usar("Roar", 22)
foto("70_rugido_cabeca", (0.0, 1.35, 1.6), (0.9, -0.5, 0.25), 1.6)
foto("71_rugido_cabeca_baixo", (0.0, 1.35, 1.45), (0.5, -0.3, -0.6), 1.7)

usar("Roar", 0)
foto("72_idle_cabeca", (0.0, 1.35, 1.45), (0.9, -0.5, 0.25), 1.6)

usar("Jump", 13)
foto("73_pulo_13", (0.0, -0.4, 1.1), (1.0, 0.05, 0.12), 5.0)

usar("Run", 6)
foto("74_corrida_06", (0.0, -0.4, 1.1), (1.0, 0.05, 0.12), 5.0)

print("###OK###")
