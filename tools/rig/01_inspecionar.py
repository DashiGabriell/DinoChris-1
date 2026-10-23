"""Inspeciona o GLB do T-Rex e renderiza vistas ortograficas para orientacao.

Roda headless:
  blender --background --python tools/rig/01_inspecionar.py
"""
import bpy
import json
import math
import os
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GLB = os.path.join(RAIZ, "assets", "modelos", "jogador", "trexChris.glb")
SAIDA = os.path.join(RAIZ, "tools", "rig", "out")
os.makedirs(SAIDA, exist_ok=True)


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def importar():
    bpy.ops.import_scene.gltf(filepath=GLB)


def bbox_global(objetos):
    minimo = Vector((1e9, 1e9, 1e9))
    maximo = Vector((-1e9, -1e9, -1e9))
    for ob in objetos:
        if ob.type != "MESH":
            continue
        for canto in ob.bound_box:
            p = ob.matrix_world @ Vector(canto)
            for i in range(3):
                minimo[i] = min(minimo[i], p[i])
                maximo[i] = max(maximo[i], p[i])
    return minimo, maximo


def montar_cena(minimo, maximo):
    centro = (minimo + maximo) / 2.0
    tamanho = max(maximo - minimo) * 1.6

    mundo = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = mundo
    mundo.use_nodes = True
    fundo = mundo.node_tree.nodes.get("Background")
    fundo.inputs[0].default_value = (0.05, 0.05, 0.07, 1.0)
    fundo.inputs[1].default_value = 1.0

    sol_dados = bpy.data.lights.new("Sol", type="SUN")
    sol_dados.energy = 3.0
    sol = bpy.data.objects.new("Sol", sol_dados)
    bpy.context.collection.objects.link(sol)
    sol.rotation_euler = (math.radians(55), 0, math.radians(35))

    preench_dados = bpy.data.lights.new("Preench", type="SUN")
    preench_dados.energy = 1.2
    preench = bpy.data.objects.new("Preench", preench_dados)
    bpy.context.collection.objects.link(preench)
    preench.rotation_euler = (math.radians(70), 0, math.radians(200))

    cam_dados = bpy.data.cameras.new("Cam")
    cam_dados.type = "ORTHO"
    cam_dados.ortho_scale = tamanho
    cam = bpy.data.objects.new("Cam", cam_dados)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 24
    cena.cycles.use_denoising = False
    cena.render.resolution_x = 640
    cena.render.resolution_y = 640
    cena.render.film_transparent = False
    return cam, centro, tamanho


def apontar(cam, origem, alvo):
    direcao = (Vector(alvo) - Vector(origem)).normalized()
    cam.location = origem
    cam.rotation_euler = direcao.to_track_quat("-Z", "Y").to_euler()


def renderizar_views(cam, centro, tamanho):
    dist = tamanho * 1.5
    vistas = {
        "01_frente_negY": Vector((centro.x, centro.y - dist, centro.z)),
        "02_tras_posY": Vector((centro.x, centro.y + dist, centro.z)),
        "03_lado_posX": Vector((centro.x + dist, centro.y, centro.z)),
        "04_lado_negX": Vector((centro.x - dist, centro.y, centro.z)),
        "05_topo_posZ": Vector((centro.x, centro.y, centro.z + dist)),
    }
    for nome, pos in vistas.items():
        apontar(cam, pos, centro)
        bpy.context.scene.render.filepath = os.path.join(SAIDA, nome + ".png")
        bpy.ops.render.render(write_still=True)


def main():
    limpar()
    importar()

    objetos = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    dados = []
    for ob in objetos:
        mundo = ob.matrix_world
        minimo, maximo = bbox_global([ob])
        dados.append(
            {
                "nome": ob.name,
                "vertices": len(ob.data.vertices),
                "poligonos": len(ob.data.polygons),
                "min": [round(v, 3) for v in minimo],
                "max": [round(v, 3) for v in maximo],
                "centro": [round((minimo[i] + maximo[i]) / 2, 3) for i in range(3)],
                "dims": [round(maximo[i] - minimo[i], 3) for i in range(3)],
                "local_rot": [round(math.degrees(a), 2) for a in mundo.to_euler()],
                "materiais": [m.name for m in ob.data.materials],
            }
        )

    minimo, maximo = bbox_global(objetos)
    resumo = {
        "total_objetos": len(objetos),
        "bbox_min": [round(v, 3) for v in minimo],
        "bbox_max": [round(v, 3) for v in maximo],
        "dims": [round(maximo[i] - minimo[i], 3) for i in range(3)],
        "objetos": dados,
    }
    print("###JSON_INICIO###")
    print(json.dumps(resumo, indent=1))
    print("###JSON_FIM###")

    cam, centro, tamanho = montar_cena(minimo, maximo)
    renderizar_views(cam, centro, tamanho)


main()
