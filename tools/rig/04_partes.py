"""Identifica cada parte do modelo por cor e mede pernas/cabeca.

blender --background --python tools/rig/04_partes.py
"""
import bpy
import math
import os
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GLB = os.path.join(RAIZ, "assets", "modelos", "jogador", "trexChris.glb")
SAIDA = os.path.join(RAIZ, "tools", "rig", "out")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
malhas = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def procurar(prefixo):
    for ob in malhas:
        if ob.name.startswith(prefixo):
            return ob
    return None


cores = {
    "mesh_12_199": (1.0, 0.1, 0.1),   # torso ?
    "mesh_12_202": (0.1, 1.0, 0.1),   # perna ?
    "mesh_12_201": (0.1, 0.3, 1.0),   # perna ?
    "mesh_12_195": (1.0, 1.0, 0.0),   # cabeca ?
    "mesh_12_196": (1.0, 0.1, 1.0),   # mandibula ?
    "mesh_12_200": (0.0, 1.0, 1.0),   # braco ?
    "mesh_12_198": (1.0, 0.5, 0.0),   # braco ?
    "mesh_12_197": (1.0, 1.0, 1.0),   # cauda ?
    "mesh_12_393": (0.0, 0.0, 0.0),   # olho ?
    "mesh_12_392": (0.3, 0.0, 0.3),   # olho ?
}

for ob in malhas:
    chave = None
    for k in cores:
        if ob.name.startswith(k):
            chave = k
            break
    cor = cores.get(chave, (0.5, 0.5, 0.5))
    mat = bpy.data.materials.new("m_" + ob.name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*cor, 1)
    bsdf.inputs["Roughness"].default_value = 0.4
    bsdf.inputs["Emission Color"].default_value = (*cor, 1)
    bsdf.inputs["Emission Strength"].default_value = 0.55
    ob.data.materials.clear()
    ob.data.materials.append(mat)

todos = [bpy.context.scene.objects[o.name] for o in malhas]
mn = Vector((1e9, 1e9, 1e9))
mx = Vector((-1e9, -1e9, -1e9))
for ob in todos:
    for c in ob.bound_box:
        p = ob.matrix_world @ Vector(c)
        for i in range(3):
            mn[i] = min(mn[i], p[i])
            mx[i] = max(mx[i], p[i])
centro = (mn + mx) / 2
dim = mx - mn
maior = max(dim)

mundo = bpy.data.worlds.new("W")
bpy.context.scene.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.02, 0.03, 1)

cam_d = bpy.data.cameras.new("Cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = maior * 1.2
cam = bpy.data.objects.new("Cam", cam_d)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.samples = 24
cena.cycles.use_denoising = False
cena.render.resolution_x = 900
cena.render.resolution_y = 900


def vista(nome, desloc):
    pos = centro + Vector(desloc) * maior * 3
    cam.location = pos
    d = (centro - pos).normalized()
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = os.path.join(SAIDA, nome + ".png")
    bpy.ops.render.render(write_still=True)


vista("20_partes_lado", (1, 0.001, 0))
vista("21_partes_tresp", (0.9, -0.9, 0.5))

# --- medidas finas das pernas ---
print("###PERNAS_DETALHE###")
for nome in ("mesh_12_202", "mesh_12_201"):
    ob = procurar(nome)
    if not ob:
        continue
    m = ob.matrix_world
    pts = [m @ v.co for v in ob.data.vertices]
    zmin = min(p.z for p in pts)
    zmax = max(p.z for p in pts)
    print("--- {}  z[{:.4f},{:.4f}]".format(nome, zmin, zmax))
    fatias = 12
    for i in range(fatias):
        a = zmin + (zmax - zmin) * i / fatias
        b = zmin + (zmax - zmin) * (i + 1) / fatias
        sel = [p for p in pts if a <= p.z < b]
        if not sel:
            continue
        print("  z[{:.4f},{:.4f}] n={:4d} x[{:.4f},{:.4f}] xmed={:.4f} ymed={:.4f}".format(
            a, b, len(sel), min(p.x for p in sel), max(p.x for p in sel),
            sum(p.x for p in sel) / len(sel), sum(p.y for p in sel) / len(sel)))

# --- cabeca e mandibula ---
print("###CABECA_DETALHE###")
for nome in ("mesh_12_195", "mesh_12_196"):
    ob = procurar(nome)
    if not ob:
        continue
    m = ob.matrix_world
    pts = [m @ v.co for v in ob.data.vertices]
    print("--- {}".format(nome))
    print("  x[{:.4f},{:.4f}] y[{:.4f},{:.4f}] z[{:.4f},{:.4f}] n={}".format(
        min(p.x for p in pts), max(p.x for p in pts),
        min(p.y for p in pts), max(p.y for p in pts),
        min(p.z for p in pts), max(p.z for p in pts), len(pts)))
    # perfil ao longo de x
    xs = [p.x for p in pts]
    xmin, xmax = min(xs), max(xs)
    for i in range(8):
        a = xmin + (xmax - xmin) * i / 8
        b = xmin + (xmax - xmin) * (i + 1) / 8
        sel = [p for p in pts if a <= p.x < b]
        if not sel:
            continue
        print("  x[{:.4f},{:.4f}] n={:4d} z[{:.4f},{:.4f}] zmed={:.4f}".format(
            a, b, len(sel), min(p.z for p in sel), max(p.z for p in sel),
            sum(p.z for p in sel) / len(sel)))

# --- cauda ---
print("###CAUDA_DETALHE###")
ob = procurar("mesh_12_197")
if ob:
    m = ob.matrix_world
    pts = [m @ v.co for v in ob.data.vertices]
    xs = [p.x for p in pts]
    xmin, xmax = min(xs), max(xs)
    for i in range(8):
        a = xmin + (xmax - xmin) * i / 8
        b = xmin + (xmax - xmin) * (i + 1) / 8
        sel = [p for p in pts if a <= p.x < b]
        if not sel:
            continue
        print("  x[{:.4f},{:.4f}] n={:4d} zmed={:.4f} ymed={:.4f}".format(
            a, b, len(sel), sum(p.z for p in sel) / len(sel), sum(p.y for p in sel) / len(sel)))

# --- bracos ---
print("###BRACOS_DETALHE###")
for nome in ("mesh_12_200", "mesh_12_198"):
    ob = procurar(nome)
    if not ob:
        continue
    m = ob.matrix_world
    pts = [m @ v.co for v in ob.data.vertices]
    print("--- {}".format(nome))
    print("  x[{:.4f},{:.4f}] y[{:.4f},{:.4f}] z[{:.4f},{:.4f}]".format(
        min(p.x for p in pts), max(p.x for p in pts),
        min(p.y for p in pts), max(p.y for p in pts),
        min(p.z for p in pts), max(p.z for p in pts)))

print("###FIM###")
