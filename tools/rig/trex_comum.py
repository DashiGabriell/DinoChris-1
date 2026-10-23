"""Constantes e utilidades compartilhadas do rig do T-Rex.

Coordenadas originais (modelo pequeno, ~4,3 cm) -> metros finais:
  X final = -(y - YC) * ESCALA      (largura)
  Y final =  (x - HIP_X) * ESCALA   (frente = +Y, padrao Blender p/ glTF)
  Z final =  (z - GROUND) * ESCALA  (altura, pes em 0)
"""
import bpy
import math
import os
from mathutils import Vector, Matrix

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GLB = os.path.join(RAIZ, "assets", "modelos", "jogador", "trexChris.glb")
PASTA = os.path.join(RAIZ, "tools", "rig")
SAIDA = os.path.join(PASTA, "out")

YC = -0.0552          # centro lateral do corpo
GROUND = -0.0177      # z do chao
ALTURA_MODELO = 0.0207
ALVO_ALTURA = 1.9     # metros
ESCALA = ALVO_ALTURA / ALTURA_MODELO
HIP_X = -0.0015       # x do quadril (origem do personagem)


def p(x, y, z):
    return Vector((-(y - YC) * ESCALA, (x - HIP_X) * ESCALA, (z - GROUND) * ESCALA))


# nome, pai, head, tail, conectado   (coordenadas originais)
OSSOS = [
    ("root",      None,       (-0.0015, YC, -0.0177), (-0.0015, YC, -0.0120), False),
    ("hips",      "root",     (-0.0035, YC, -0.0090), (0.0005, YC, -0.0083), False),
    ("spine_01",  "hips",     (0.0005, YC, -0.0083), (0.0035, YC, -0.0076), True),
    ("spine_02",  "spine_01", (0.0035, YC, -0.0076), (0.0065, YC, -0.0066), True),
    ("neck",      "spine_02", (0.0065, YC, -0.0066), (0.0085, YC, -0.0052), True),
    ("head",      "neck",     (0.0085, YC, -0.0052), (0.0155, YC, -0.0030), True),
    ("jaw",       "head",     (0.0088, YC, -0.0028), (0.0146, YC, -0.0074), False),

    ("tail_01",   "hips",     (-0.0045, YC, -0.0088), (-0.0105, YC, -0.0042), False),
    ("tail_02",   "tail_01",  (-0.0105, YC, -0.0042), (-0.0165, YC, -0.0022), True),
    ("tail_03",   "tail_02",  (-0.0165, YC, -0.0022), (-0.0220, YC, -0.0011), True),
    ("tail_04",   "tail_03",  (-0.0220, YC, -0.0011), (-0.0270, YC, -0.0005), True),

    # perna esquerda (mesh_12_202)
    ("thigh_L",   "hips",     (-0.0050, -0.0578, -0.0088), (-0.0042, -0.0578, -0.0128), False),
    ("shin_L",    "thigh_L",  (-0.0042, -0.0578, -0.0128), (-0.0032, -0.0578, -0.0166), True),
    ("foot_L",    "shin_L",   (-0.0032, -0.0578, -0.0166), (0.0010, -0.0578, -0.0175), True),
    ("toe_L",     "foot_L",   (0.0010, -0.0578, -0.0175), (0.0020, -0.0578, -0.0176), True),

    # perna direita (mesh_12_201)
    ("thigh_R",   "hips",     (-0.0062, -0.0525, -0.0088), (-0.0076, -0.0525, -0.0118), False),
    ("shin_R",    "thigh_R",  (-0.0076, -0.0525, -0.0118), (-0.0088, -0.0525, -0.0148), True),
    ("foot_R",    "shin_R",   (-0.0088, -0.0525, -0.0148), (-0.0052, -0.0525, -0.0159), True),
    ("toe_R",     "foot_R",   (-0.0052, -0.0525, -0.0159), (-0.0042, -0.0525, -0.0160), True),

    # bracos
    ("upperarm_L", "spine_02", (0.0040, -0.0565, -0.0072), (0.0050, -0.0565, -0.0096), False),
    ("forearm_L",  "upperarm_L", (0.0050, -0.0565, -0.0096), (0.0058, -0.0565, -0.0114), True),
    ("upperarm_R", "spine_02", (0.0040, -0.0533, -0.0072), (0.0050, -0.0533, -0.0096), False),
    ("forearm_R",  "upperarm_R", (0.0050, -0.0533, -0.0096), (0.0058, -0.0533, -0.0114), True),
]

# malha -> ossos permitidos no peso por distancia
PERMISSOES = {
    "mesh_12_199": ["hips", "spine_01", "spine_02", "neck", "tail_01"],
    "mesh_12_195": ["head", "neck"],
    "mesh_12_196": ["jaw"],
    "mesh_12_197": ["tail_01", "tail_02", "tail_03", "tail_04", "hips"],
    "mesh_12_202": ["thigh_L", "shin_L", "foot_L", "toe_L", "hips"],
    "mesh_12_201": ["thigh_R", "shin_R", "foot_R", "toe_R", "hips"],
    "mesh_12_200": ["upperarm_R", "forearm_R", "spine_02"],
    "mesh_12_198": ["upperarm_L", "forearm_L", "spine_02"],
    "mesh_12_393": ["head"],
    "mesh_12_392": ["head"],
}

NOMES_AMIGAVEIS = {
    "mesh_12_199": "Corpo",
    "mesh_12_195": "Cabeca",
    "mesh_12_196": "Mandibula",
    "mesh_12_197": "Cauda",
    "mesh_12_202": "Perna_Esq",
    "mesh_12_201": "Perna_Dir",
    "mesh_12_200": "Braco_Dir",
    "mesh_12_198": "Braco_Esq",
    "mesh_12_393": "Olho_1",
    "mesh_12_392": "Olho_2",
}

# Deslocamentos aplicados na malha antes do skinning (metros, espaco final).
# A perna direita veio 0,26 m para fora do centro; trazemos para a simetria.
AJUSTES_MALHA = {
    "mesh_12_201": (0.257, 0.0, 0.0),
}


def distancia_segmento(pt, a, b):
    ab = b - a
    comprimento2 = ab.length_squared
    if comprimento2 < 1e-12:
        return (pt - a).length
    t = max(0.0, min(1.0, (pt - a).dot(ab) / comprimento2))
    return (pt - (a + ab * t)).length


def achar(prefixo):
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH" and ob.name.startswith(prefixo):
            return ob
    return None


# ---------------------------------------------------------------- skinning
# Cada malha vira uma cadeia de ossos; o peso sai da posicao do vertice
# projetada ao longo da cadeia (arc length), com transicao suave nas juntas.
CADEIAS = {
    "mesh_12_199": {"ossos": ["hips", "spine_01", "spine_02", "neck"],
                    "larguras": [0.16, 0.14, 0.12], "pai": None, "largura_pai": 0.0},
    "mesh_12_195": {"ossos": ["neck", "head"], "larguras": [0.22],
                    "pai": None, "largura_pai": 0.0},
    "mesh_12_196": {"ossos": ["jaw"], "larguras": [], "pai": None, "largura_pai": 0.0},
    "mesh_12_197": {"ossos": ["tail_01", "tail_02", "tail_03", "tail_04"],
                    "larguras": [0.14, 0.12, 0.10], "pai": "hips", "largura_pai": 0.10,
                    "ancora": "hips", "ancora_raio": 0.30, "ancora_forca": 0.55},
    "mesh_12_202": {"ossos": ["thigh_L", "shin_L", "foot_L", "toe_L"],
                    "larguras": [0.10, 0.055, 0.04], "pai": "hips", "largura_pai": 0.10,
                    "ancora": "hips", "ancora_raio": 0.34, "ancora_forca": 0.95},
    "mesh_12_201": {"ossos": ["thigh_R", "shin_R", "foot_R", "toe_R"],
                    "larguras": [0.10, 0.055, 0.04], "pai": "hips", "largura_pai": 0.10,
                    "ancora": "hips", "ancora_raio": 0.34, "ancora_forca": 0.95},
    "mesh_12_200": {"ossos": ["upperarm_R", "forearm_R"], "larguras": [0.05],
                    "pai": "spine_02", "largura_pai": 0.06,
                    "ancora": "spine_02", "ancora_raio": 0.14, "ancora_forca": 0.75},
    "mesh_12_198": {"ossos": ["upperarm_L", "forearm_L"], "larguras": [0.05],
                    "pai": "spine_02", "largura_pai": 0.06,
                    "ancora": "spine_02", "ancora_raio": 0.14, "ancora_forca": 0.75},
    "mesh_12_393": {"ossos": ["head"], "larguras": [], "pai": None, "largura_pai": 0.0},
    "mesh_12_392": {"ossos": ["head"], "larguras": [], "pai": None, "largura_pai": 0.0},
}


def _suave(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def projetar_cadeia(co, pontos):
    """Distancia e posicao (arc length) do ponto projetado na poligonal."""
    melhor_d = 1e18
    melhor_s = 0.0
    acumulado = 0.0
    for i in range(len(pontos) - 1):
        a, b = pontos[i], pontos[i + 1]
        ab = b - a
        comp = ab.length
        if comp < 1e-9:
            continue
        t = max(0.0, min(1.0, (co - a).dot(ab) / (comp * comp)))
        d = (co - (a + ab * t)).length
        s = acumulado + t * comp
        if d < melhor_d:
            melhor_d = d
            melhor_s = s
        acumulado += comp
    return melhor_d, melhor_s


def pesos_cadeia(co, pontos, nomes, larguras, pai=None, largura_pai=0.0,
                 ancora=None, ancora_raio=0.0, ancora_forca=0.0):
    """Pesos de skinning ao longo da cadeia, com juntas suavizadas."""
    comprimentos = [(pontos[i + 1] - pontos[i]).length for i in range(len(pontos) - 1)]
    acumulados = [0.0]
    for c in comprimentos:
        acumulados.append(acumulados[-1] + c)
    s = projetar_cadeia(co, pontos)[1]
    total_bone = acumulados[-1]

    pesos = {}
    for i, nome in enumerate(nomes):
        inicio = acumulados[i]
        fim = acumulados[i + 1] if i + 1 < len(comprimentos) + 1 else total_bone
        # entrada suave
        if i == 0:
            entra = 1.0
        else:
            w = larguras[i - 1]
            entra = _suave((s - (inicio - w)) / (2 * w)) if w > 1e-6 else 1.0
        # saida suave
        if i == len(nomes) - 1:
            sai = 1.0
        else:
            w = larguras[i]
            sai = 1.0 - _suave((s - (fim - w)) / (2 * w)) if w > 1e-6 else 0.0
        peso = max(0.0, min(entra, sai))
        if peso > 1e-4:
            pesos[nome] = peso

    if pai and largura_pai > 1e-6:
        mistura = 1.0 - _suave(s / largura_pai)
        if mistura > 1e-4:
            for k in list(pesos):
                pesos[k] *= (1.0 - mistura)
            pesos[pai] = pesos.get(pai, 0.0) + mistura

    # ancora radial: prende a raiz do membro ao osso pai que fica por dentro do corpo
    if ancora and ancora_raio > 1e-6:
        alvo = pontos[0]
        d = (co - alvo).length
        alpha = (1.0 - _suave(d / ancora_raio)) * ancora_forca
        if alpha > 1e-4:
            for k in list(pesos):
                pesos[k] *= (1.0 - alpha)
            pesos[ancora] = pesos.get(ancora, 0.0) + alpha

    soma = sum(pesos.values())
    if soma <= 1e-9:
        return {nomes[0]: 1.0}
    return {k: v / soma for k, v in pesos.items() if v > 1e-4}


def mapear_malhas():
    """Retorna {'mesh_12_199': obj, ...} pelos prefixos conhecidos."""
    resultado = {}
    for chave in PERMISSOES:
        ob = achar(chave)
        if ob:
            resultado[chave] = ob
    return resultado
