"""Reexporta o GLB a partir de trex_anim.blend (sem regerar animacoes).

blender --background --python tools/rig/12_exportar.py
"""
import bpy
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import trex_comum as C

bpy.ops.wm.open_mainfile(filepath=os.path.join(C.SAIDA, "trex_anim.blend"))
arm = bpy.data.objects["TRexRig"]
if arm.animation_data:
    arm.animation_data.action = None

print("###ACOES###", [a.name for a in bpy.data.actions])

bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=os.path.join(C.RAIZ, "assets", "modelos", "jogador", "trexChrisAnim.glb"),
    export_format="GLB",
    use_selection=False,
    export_apply=False,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_bake_animation=False,
    export_anim_single_armature=True,
    export_optimize_animation_size=False,
    export_yup=True,
)
print("###EXPORTADO###")
