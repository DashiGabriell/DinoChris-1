"""Constroi armature + skin do T-Rex e salva tools/rig/out/trex_rig.blend

blender --background --python tools/rig/05_rig.py
"""
import bpy
import math
import os
import sys
from mathutils import Vector, Matrix

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import trex_comum as C

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=C.GLB)

malhas = [o for o in bpy.context.scene.objects if o.type == "MESH"]

# --- 1. tirar do hierarchy do Sketchfab e aplicar transformacoes ---
for ob in bpy.context.scene.objects:
    ob.select_set(False)

for ob in malhas:
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for ob in malhas:
    ob.select_set(False)

# --- 2. normalizar: metros, Z up, +Y frente, pes no chao, quadril na origem ---
M = (
    Matrix.Translation(Vector((C.ESCALA * C.YC, -C.ESCALA * C.HIP_X, -C.ESCALA * C.GROUND)))
    @ Matrix.Rotation(math.radians(90), 4, "Z")
    @ Matrix.Scale(C.ESCALA, 4)
)
for ob in malhas:
    ob.data.transform(M)
    ob.data.update()

malhas_map = {}
for chave, ob in C.mapear_malhas().items():
    malhas_map[chave] = ob

# ajustes de simetria na malha
for chave, deslocamento in C.AJUSTES_MALHA.items():
    ob = malhas_map.get(chave)
    if not ob:
        continue
    for v in ob.data.vertices:
        v.co += Vector(deslocamento)
    ob.data.update()

# --- 3. armature ---
dados_arm = bpy.data.armatures.new("TRexArmature")
arm = bpy.data.objects.new("TRexRig", dados_arm)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")

criados = {}
for nome, pai, head, tail, conectado in C.OSSOS:
    eb = dados_arm.edit_bones.new(nome)
    eb.head = C.p(*head)
    eb.tail = C.p(*tail)
    eb.roll = 0.0
    if pai:
        eb.parent = criados[pai]
        eb.use_connect = bool(conectado)
    criados[nome] = eb
bpy.ops.object.mode_set(mode="OBJECT")

print("###OSSOS###")
for b in dados_arm.bones:
    print("{:12s} head=({:.3f},{:.3f},{:.3f}) tail=({:.3f},{:.3f},{:.3f}) len={:.3f}".format(
        b.name, b.head_local.x, b.head_local.y, b.head_local.z,
        b.tail_local.x, b.tail_local.y, b.tail_local.z, (b.tail_local - b.head_local).length))

# --- 4. skinning ao longo da cadeia de ossos ---
segmentos = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in dados_arm.bones}

for chave, ob in malhas_map.items():
    spec = C.CADEIAS[chave]
    nomes = spec["ossos"]
    pontos = [segmentos[nomes[0]][0]] + [segmentos[n][1] for n in nomes]
    larguras = spec["larguras"]
    pai = spec["pai"]
    largura_pai = spec["largura_pai"]

    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    todos_nomes = list(dict.fromkeys(nomes + ([pai] if pai else [])))
    grupos = {nome: ob.vertex_groups.new(name=nome) for nome in todos_nomes}

    for v in ob.data.vertices:
        pesos = C.pesos_cadeia(
            v.co, pontos, nomes, larguras, pai, largura_pai,
            spec.get("ancora"), spec.get("ancora_raio", 0.0), spec.get("ancora_forca", 0.0),
        )
        for nome, w in pesos.items():
            grupos[nome].add([v.index], w, "REPLACE")

    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    ob.parent = arm

# --- 5. renomear para nomes legiveis ---
for chave, ob in malhas_map.items():
    ob.name = C.NOMES_AMIGAVEIS.get(chave, ob.name)

arm.show_in_front = True
dados_arm.display_type = "OCTAHEDRAL"

# --- 6. diagnostico ---
print("###MALHAS###")
for ob in bpy.context.scene.objects:
    if ob.type != "MESH":
        continue
    soma_zero = 0
    for v in ob.data.vertices:
        if not v.groups:
            soma_zero += 1
    print("{:12s} verts={:6d} grupos={:2d} sem_peso={}".format(
        ob.name, len(ob.data.vertices), len(ob.vertex_groups), soma_zero))

os.makedirs(C.SAIDA, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(C.SAIDA, "trex_rig.blend"))
print("###SALVO###")
