"""Analise numerica da anatomia: perfis por fatia para posicionar ossos.

blender --background --python tools/rig/03_analise.py
"""
import bpy
import json
import os
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GLB = os.path.join(RAIZ, "assets", "modelos", "jogador", "trexChris.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
malhas = [o for o in bpy.context.scene.objects if o.type == "MESH"]

pontos = []
for ob in malhas:
    m = ob.matrix_world
    for v in ob.data.vertices:
        pontos.append(m @ v.co)

xs = [p.x for p in pontos]
ys = [p.y for p in pontos]
zs = [p.z for p in pontos]
x0, x1 = min(xs), max(xs)
z0, z1 = min(zs), max(zs)
y0, y1 = min(ys), max(ys)
altura = z1 - z0
comprimento = x1 - x0

print("###RESUMO###")
print(json.dumps({
    "x": [round(x0, 4), round(x1, 4)],
    "y": [round(y0, 4), round(y1, 4)],
    "z": [round(z0, 4), round(z1, 4)],
    "altura": round(altura, 4),
    "comprimento": round(comprimento, 4),
    "largura": round(y1 - y0, 4),
}, indent=1))

# Perfil por fatia ao longo de X (0 = cauda, 1 = focinho)
fatias = 32
bins = [[] for _ in range(fatias)]
for p in pontos:
    i = min(fatias - 1, max(0, int((p.x - x0) / comprimento * fatias)))
    bins[i].append(p)

print("###PERFIL_X###")
print("bin  x_norm  n     z_min   z_max   z_med   y_min   y_max")
for i, b in enumerate(bins):
    if not b:
        continue
    zs_b = [p.z for p in b]
    ys_b = [p.y for p in b]
    print("{:3d}  {:.3f}  {:5d}  {:.4f}  {:.4f}  {:.4f}  {:.4f}  {:.4f}".format(
        i, (i + 0.5) / fatias, len(b), min(zs_b), max(zs_b), sum(zs_b) / len(zs_b), min(ys_b), max(ys_b)))

# Perfil vertical no torso (x normalizado 0.55 a 0.75)
torso = [p for p in pontos if 0.55 <= (p.x - x0) / comprimento <= 0.75]
print("###TORSO_VERTICAL###")
if torso:
    zs_t = sorted(p.z for p in torso)
    print("z min/med/max: {:.4f} {:.4f} {:.4f}".format(zs_t[0], zs_t[len(zs_t)//2], zs_t[-1]))

# Regiao das pernas: pontos abaixo de 35% da altura
corte = z0 + 0.35 * altura
pernas = [p for p in pontos if p.z < corte]
print("###PERNAS###")
print("pontos abaixo de z={:.4f}: {}".format(corte, len(pernas)))
lado_e = [p for p in pernas if p.y < (y0 + y1) / 2]
lado_d = [p for p in pernas if p.y >= (y0 + y1) / 2]
for nome, lado in (("esq_y_menor", lado_e), ("dir_y_maior", lado_d)):
    if not lado:
        continue
    xs_l = [p.x for p in lado]
    ys_l = [p.y for p in lado]
    zs_l = [p.z for p in lado]
    print(nome, "n={} x[{:.4f},{:.4f}] y[{:.4f},{:.4f}] z[{:.4f},{:.4f}]".format(
        len(lado), min(xs_l), max(xs_l), min(ys_l), max(ys_l), min(zs_l), max(zs_l)))

# Pe: pontos muito baixos
pe = [p for p in pontos if p.z < z0 + 0.06 * altura]
print("###PES###")
for nome, lado in (("esq", [p for p in pe if p.y < (y0 + y1) / 2]), ("dir", [p for p in pe if p.y >= (y0 + y1) / 2])):
    if not lado:
        continue
    xs_p = [p.x for p in lado]
    ys_p = [p.y for p in lado]
    print(nome, "n={} x[{:.4f},{:.4f}] medio_x={:.4f} medio_y={:.4f}".format(
        len(lado), min(xs_p), max(xs_p), sum(xs_p) / len(xs_p), sum(ys_p) / len(ys_p)))

# Cabeca: regiao x normalizado > 0.8, perfil vertical e horizontal
cabeca = [p for p in pontos if (p.x - x0) / comprimento > 0.78]
if cabeca:
    zs_c = [p.z for p in cabeca]
    ys_c = [p.y for p in cabeca]
    xs_c = [p.x for p in cabeca]
    print("###CABECA###")
    print("n={} x[{:.4f},{:.4f}] y[{:.4f},{:.4f}] z[{:.4f},{:.4f}]".format(
        len(cabeca), min(xs_c), max(xs_c), min(ys_c), max(ys_c), min(zs_c), max(zs_c)))
    # metade inferior da cabeca = mandibula
    z_med = (min(zs_c) + max(zs_c)) / 2
    mand = [p for p in cabeca if p.z < z_med]
    if mand:
        print("mandibula cand. z<{:.4f}: x[{:.4f},{:.4f}] z[{:.4f},{:.4f}]".format(
            z_med, min(p.x for p in mand), max(p.x for p in mand), min(p.z for p in mand), max(p.z for p in mand)))

print("###FIM###")
