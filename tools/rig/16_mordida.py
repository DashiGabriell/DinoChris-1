"""Folha do clipe de ataque (mordida) em perfil."""
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
b.inputs["Base Color"].default_value = (0.75, 0.42, 0.2, 1)
b.inputs["Roughness"].default_value = 0.45
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        ob.data.materials.clear()
        ob.data.materials.append(clay)

bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
chao = bpy.context.active_object
mc = bpy.data.materials.new("chao")
mc.use_nodes = True
mc.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.45, 0.4, 1)
chao.data.materials.append(mc)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.34, 0.37, 0.45, 1)

for nome, energia, rot in (
    ("Key", 4.5, (math.radians(48), 0, math.radians(35))),
    ("Fill", 2.2, (math.radians(70), 0, math.radians(215))),
):
    ld = bpy.data.lights.new(nome, type="SUN")
    ld.energy = energia
    lo = bpy.data.objects.new(nome, ld)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = rot

cam_d = bpy.data.cameras.new("Cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 5.0
cam = bpy.data.objects.new("Cam", cam_d)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.samples = 28
cena.cycles.use_denoising = False
cena.render.resolution_x = 520
cena.render.resolution_y = 520

CENTRO = Vector((0, -0.5, 1.0))
pos = CENTRO + Vector((1.0, -0.28, 0.16)).normalized() * 8
cam.location = pos
cam.rotation_euler = (CENTRO - pos).normalized().to_track_quat("-Z", "Y").to_euler()

arm.animation_data_create()
acao = bpy.data.actions["Attack"]
arm.animation_data.action = acao
if hasattr(arm.animation_data, "action_slot") and len(acao.slots):
    arm.animation_data.action_slot = acao.slots[0]

pasta = os.path.join(C.SAIDA, "mordida")
os.makedirs(pasta, exist_ok=True)
for f in [0, 5, 8, 10, 13, 18]:
    cena.frame_set(f)
    cena.render.filepath = os.path.join(pasta, "m{:03d}.png".format(f))
    bpy.ops.render.render(write_still=True)

print("###OK###")
