"""QA em perfil com chao e sombra: mostra contato dos pes e distribuicao de peso.

blender --background --python tools/rig/13_qa.py
"""
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
b.inputs["Base Color"].default_value = (0.72, 0.38, 0.18, 1)
b.inputs["Roughness"].default_value = 0.5
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        ob.data.materials.clear()
        ob.data.materials.append(clay)

# chao
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
chao = bpy.context.active_object
mat_chao = bpy.data.materials.new("chao")
mat_chao.use_nodes = True
mc = mat_chao.node_tree.nodes["Principled BSDF"]
mc.inputs["Base Color"].default_value = (0.45, 0.47, 0.42, 1)
mc.inputs["Roughness"].default_value = 0.9
chao.data.materials.append(mat_chao)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.35, 0.42, 1)

for nome, energia, rot in (
    ("Key", 4.0, (math.radians(50), 0, math.radians(40))),
    ("Fill", 1.6, (math.radians(70), 0, math.radians(210))),
):
    ld = bpy.data.lights.new(nome, type="SUN")
    ld.energy = energia
    lo = bpy.data.objects.new(nome, ld)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = rot

cam_d = bpy.data.cameras.new("Cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 5.2
cam = bpy.data.objects.new("Cam", cam_d)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.samples = 20
cena.cycles.use_denoising = False
cena.render.resolution_x = 520
cena.render.resolution_y = 520

CENTRO = Vector((0, -0.45, 0.95))
pos = CENTRO + Vector((1.0, 0.06, 0.12)).normalized() * 8
cam.location = pos
cam.rotation_euler = (CENTRO - pos).normalized().to_track_quat("-Z", "Y").to_euler()

arm.animation_data_create()

QUADROS = {
    "Idle": [0, 30, 60],
    "Walk": [0, 4, 8, 12, 16, 23],
    "Run": [0, 3, 6, 10, 14],
    "Jump": [0, 5, 9, 13, 18, 24],
    "Attack": [0, 5, 9, 12, 16, 21],
    "Roar": [0, 8, 14, 22, 30, 38],
}

pasta = os.path.join(C.SAIDA, "qa2")
os.makedirs(pasta, exist_ok=True)

for clipe, quadros in QUADROS.items():
    acao = bpy.data.actions[clipe]
    arm.animation_data.action = acao
    if hasattr(arm.animation_data, "action_slot") and len(acao.slots):
        arm.animation_data.action_slot = acao.slots[0]
    for f in quadros:
        cena.frame_set(f)
        cena.render.filepath = os.path.join(pasta, "{}_{:03d}.png".format(clipe, f))
        bpy.ops.render.render(write_still=True)

print("###QA_OK###")
