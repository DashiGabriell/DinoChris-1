"""Gera as animacoes do T-Rex (Idle, Walk, Run, Jump, Attack, Roar) e exporta GLB.

Convencao de eixos (espaco do armature):
  +Y frente, +X direita do personagem, +Z cima.
  Rotacao +X no tronco levanta o focinho; -X abaixa.
  Rotacao +X na mandibula FECHA a boca (a pose de repouso ja vem aberta).

blender --background --python tools/rig/11_anim.py
"""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import trex_comum as C
from trex_esqueleto import Esqueleto, cor

bpy.ops.wm.open_mainfile(filepath=os.path.join(C.SAIDA, "trex_rig.blend"))
arm = bpy.data.objects["TRexRig"]
esq = Esqueleto(arm)

FPS = 30
TAU = math.pi * 2.0
X_ESQ = 0.245
X_DIR = -0.245
CHAO = 0.10
Y_BASE = -0.045

bpy.context.scene.render.fps = FPS


# ------------------------------------------------------------------ helpers
def corpo(dz=0.0, dy=0.0, dx=0.0, pitch=0.0, yaw=0.0, roll=0.0,
          s1=0.0, s2=0.0, pescoco=0.0, cabeca_x=0.0, cabeca_z=0.0,
          mandibula=34.0, cauda_z=0.0, cauda_x=0.0, braco=0.0,
          cauda_onda=0.0, cauda_fase=0.0):
    esq.reset()
    esq.mover_hips(dx, dy, dz, pitch, yaw, roll)
    esq.girar("spine_01", "X", s1)
    esq.girar("spine_02", "X", s2)
    esq.girar("neck", "X", pescoco)
    esq.girar("head", "X", cabeca_x)
    esq.girar("head", "Z", cabeca_z)
    esq.girar("jaw", "X", mandibula)
    for i in range(4):
        esq.girar("tail_0%d" % (i + 1), "X", cauda_x * (1.0 - i * 0.15))
        onda = cauda_z + cauda_onda * math.sin(cauda_fase - i * 0.7)
        esq.girar("tail_0%d" % (i + 1), "Z", onda * (1.0 - i * 0.12))
    esq.girar("upperarm_L", "X", braco)
    esq.girar("upperarm_R", "X", braco)
    esq.girar("forearm_L", "X", braco * 0.4)
    esq.girar("forearm_R", "X", braco * 0.4)


def pe(lado, x, y, z):
    esq.perna(lado, (x, y, z), (x, y + 0.34, z - 0.075))


def passada(esq, lado, fase, x, base_y, passo, altura, fracao_contato=0.62):
    """Fase 0..1 de um passo: contato arrastando para tras, balanco para frente."""
    p = fase % 1.0
    if p < fracao_contato:
        u = p / fracao_contato
        y = base_y + passo - 2.0 * passo * u
        z = CHAO
    else:
        u = (p - fracao_contato) / (1.0 - fracao_contato)
        y = base_y - passo + 2.0 * passo * u
        z = CHAO + altura * math.sin(math.pi * u)
    pe(lado, x, y, z)


# ------------------------------------------------------------------ clipes
def idle(t):
    resp = math.sin(TAU * t)
    corpo(dz=-0.055 + 0.010 * resp,
          dx=0.010 * math.sin(TAU * t + 0.4),
          yaw=1.5 * math.sin(TAU * t),
          roll=1.2 * math.sin(TAU * t + 0.4),
          s1=1.5 + 1.0 * resp,
          s2=1.0 + 0.6 * resp,
          pescoco=6.0 - 1.2 * resp,
          cabeca_x=5.0 - 1.5 * resp,
          cabeca_z=3.5 * math.sin(TAU * t * 0.5),
          mandibula=36.0 + 2.0 * math.sin(TAU * t * 2.0),
          cauda_x=-3.0,
          cauda_onda=4.5, cauda_fase=TAU * t,
          braco=4.0 * math.sin(TAU * t + 1.0))
    pe("L", X_ESQ, Y_BASE, CHAO)
    pe("R", X_DIR, Y_BASE, CHAO)


def andar(t):
    corpo(dz=-0.060 - 0.014 * math.cos(2 * TAU * t),
          dx=0.018 * math.sin(TAU * t),
          yaw=4.0 * math.sin(TAU * t),
          roll=3.0 * math.sin(TAU * t),
          s1=2.0, s2=1.0,
          pescoco=6.0,
          cabeca_x=4.0 + 1.0 * math.sin(2 * TAU * t),
          cabeca_z=-1.5 * math.sin(TAU * t),
          mandibula=35.0,
          cauda_x=-4.0,
          cauda_onda=7.0, cauda_fase=TAU * t + 0.5,
          braco=9.0 * math.sin(TAU * t + math.pi))
    passada(esq, "L", t, X_ESQ, Y_BASE, 0.17, 0.11)
    passada(esq, "R", t + 0.5, X_DIR, Y_BASE, 0.17, 0.11)


def correr(t):
    corpo(dz=-0.070 + 0.045 * math.sin(2 * TAU * t + math.pi),
          pitch=-7.0,
          yaw=5.0 * math.sin(TAU * t),
          roll=4.0 * math.sin(TAU * t),
          s1=3.0, s2=2.0,
          pescoco=16.0,
          cabeca_x=9.0,
          cabeca_z=-2.0 * math.sin(TAU * t),
          mandibula=26.0,
          cauda_x=-5.0,
          cauda_onda=8.0, cauda_fase=TAU * t + 0.8,
          braco=16.0 * math.sin(TAU * t + math.pi))
    passada(esq, "L", t, X_ESQ, -0.03, 0.26, 0.24, fracao_contato=0.42)
    passada(esq, "R", t + 0.5, X_DIR, -0.03, 0.26, 0.24, fracao_contato=0.42)


def pulo(t):
    dz = cor([(0, -0.055), (0.14, -0.22), (0.30, 0.05), (0.48, 0.20),
              (0.62, 0.10), (0.76, -0.20), (0.88, -0.10), (1, -0.055)], t)
    pitch = cor([(0, 0), (0.14, -10), (0.30, 8), (0.48, 6), (0.64, -3),
                 (0.78, -12), (1, 0)], t)
    pesc = cor([(0, 6), (0.14, -8), (0.30, 14), (0.48, 10), (0.72, -6), (1, 6)], t)
    cab = cor([(0, 4), (0.14, -10), (0.30, 14), (0.50, 8), (0.76, -14), (1, 4)], t)
    mand = cor([(0, 36), (0.14, 36), (0.34, 14), (0.50, 6), (0.72, 30), (1, 36)], t)
    altura_pe = cor([(0, 0), (0.22, 0), (0.34, 0.28), (0.50, 0.36),
                     (0.66, 0.14), (0.78, 0), (1, 0)], t)
    avanco = cor([(0, 0), (0.26, -0.04), (0.50, -0.14), (0.72, 0.04), (1, 0)], t)
    cauda = cor([(0, -3), (0.14, 6), (0.34, -8), (0.52, -9), (0.78, 6), (1, -3)], t)
    braco = cor([(0, 0), (0.14, -22), (0.32, 40), (0.5, 34), (0.78, -12), (1, 0)], t)

    corpo(dz=dz, pitch=pitch, s1=pitch * 0.3, pescoco=pesc,
          cabeca_x=cab, mandibula=mand, cauda_x=cauda, braco=braco)
    pe("L", X_ESQ, Y_BASE + avanco, CHAO + altura_pe)
    pe("R", X_DIR, Y_BASE + avanco, CHAO + altura_pe)


def ataque(t):
    dy = cor([(0, 0), (0.18, -0.10), (0.34, 0.14), (0.50, 0.16), (0.66, 0.09), (0.86, 0), (1, 0)], t)
    dz = cor([(0, -0.055), (0.18, -0.085), (0.34, -0.05), (0.5, -0.045), (1, -0.055)], t)
    pitch = cor([(0, 0), (0.18, 6), (0.34, -9), (0.5, -7), (0.7, -2), (1, 0)], t)
    s1 = cor([(0, 0), (0.18, -8), (0.32, 9), (0.46, 12), (0.66, 4), (1, 0)], t)
    pesc = cor([(0, 6), (0.16, -12), (0.30, 0), (0.38, 17), (0.52, 12), (0.78, 4), (1, 6)], t)
    cab = cor([(0, 4), (0.16, -15), (0.30, 2), (0.38, 19), (0.52, 10), (0.78, 4), (1, 4)], t)
    mand = cor([(0, 36), (0.16, 6), (0.30, 2), (0.38, 32), (0.44, 36), (0.58, 33), (0.74, 36), (1, 36)], t)
    cauda = cor([(0, -3), (0.18, 6), (0.36, -7), (0.55, -5), (0.8, 0), (1, -3)], t)
    braco = cor([(0, 0), (0.18, -18), (0.36, 22), (0.55, 14), (1, 0)], t)
    frente = cor([(0, 0), (0.20, -0.05), (0.36, 0.10), (0.56, 0.10), (0.84, 0), (1, 0)], t)

    corpo(dz=dz, dy=dy, pitch=pitch, s1=s1, pescoco=pesc, cabeca_x=cab,
          mandibula=mand, cauda_x=cauda, braco=braco)
    pe("L", X_ESQ, Y_BASE + frente, CHAO)
    pe("R", X_DIR, Y_BASE - frente * 0.3, CHAO)


def rugido(t):
    dz = cor([(0, -0.055), (0.16, -0.11), (0.32, -0.045), (0.72, -0.045), (0.9, -0.055), (1, -0.055)], t)
    pitch = cor([(0, 0), (0.16, -4), (0.34, 6), (0.72, 5), (0.9, 0), (1, 0)], t)
    s1 = cor([(0, 0), (0.16, 7), (0.32, -6), (0.72, -5), (0.9, 0), (1, 0)], t)
    pesc = cor([(0, 6), (0.16, -10), (0.32, 20), (0.72, 18), (0.9, 6), (1, 6)], t)
    cab = cor([(0, 4), (0.16, -12), (0.34, 24), (0.72, 21), (0.9, 4), (1, 4)], t)
    mand = cor([(0, 34), (0.16, 36), (0.32, 2), (0.42, 0), (0.74, 0), (0.92, 34), (1, 34)], t)
    cauda = cor([(0, -3), (0.16, 6), (0.32, -9), (0.72, -8), (0.9, -3), (1, -3)], t)
    braco = cor([(0, 0), (0.16, -10), (0.34, 16), (0.72, 12), (0.9, 0), (1, 0)], t)

    tremor = 0.0
    if 0.34 < t < 0.74:
        tremor = math.sin(TAU * 11.0 * t) * 2.6

    corpo(dz=dz, pitch=pitch, s1=s1, pescoco=pesc, cabeca_x=cab + tremor,
          cabeca_z=tremor * 0.6, mandibula=mand + tremor * 1.2, cauda_x=cauda,
          braco=braco, cauda_onda=5.0, cauda_fase=TAU * t * 1.5)
    pe("L", X_ESQ, Y_BASE, CHAO)
    pe("R", X_DIR, Y_BASE, CHAO)


# ------------------------------------------------------------------ geracao
def curvas(action):
    lista = []
    for camada in action.layers:
        for faixa in camada.strips:
            bags = getattr(faixa, "channelbags", None)
            if bags is not None and len(bags):
                for cb in bags:
                    lista.extend(cb.fcurves)
            else:
                for slot in action.slots:
                    try:
                        cb = faixa.channelbag(slot)
                    except Exception:
                        cb = None
                    if cb:
                        lista.extend(cb.fcurves)
    return lista


def criar(nome, quadros, funcao, passo=2):
    arm.animation_data_create()
    action = bpy.data.actions.new(nome)
    action.use_fake_user = True
    arm.animation_data.action = action
    if hasattr(arm.animation_data, "action_slot"):
        try:
            slot = action.slots.new(id_type="OBJECT", name=nome)
            arm.animation_data.action_slot = slot
        except Exception:
            pass

    for f in range(0, quadros + 1, passo):
        funcao(f / quadros)
        esq.aplicar()
        esq.chaves(f)

    for fc in curvas(action):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.handle_left_type = "AUTO_CLAMPED"
            kp.handle_right_type = "AUTO_CLAMPED"
    print("###CLIPE### {} quadros=0..{} curvas={}".format(nome, quadros, len(curvas(action))))
    return action


acoes = [
    criar("Idle", 90, idle, 3),
    criar("Walk", 30, andar, 2),
    criar("Run", 20, correr, 1),
    criar("Jump", 27, pulo, 1),
    criar("Attack", 24, ataque, 1),
    criar("Roar", 42, rugido, 1),
]

arm.animation_data.action = None  # exporta TODAS as acoes, inclusive a que estava ativa
bpy.context.scene.frame_start = 0
bpy.context.scene.frame_end = 90

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(C.SAIDA, "trex_anim.blend"))
print("###SALVO###")

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
