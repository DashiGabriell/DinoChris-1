"""Solver de pose em espaco de armature: FK proprio + IK de 2 ossos para as pernas.

Nao depende do depsgraph: calcula matrix_basis na mao, o que permite gerar
centenas de frames sem update de cena a cada osso.
"""
import math
from mathutils import Matrix, Vector


class Esqueleto:
    def __init__(self, arm):
        self.arm = arm
        self.rest = {}
        self.parente = {}
        self.comprimento = {}
        self.offset = {}
        for b in arm.data.bones:
            self.rest[b.name] = b.matrix_local.copy()
            self.parente[b.name] = b.parent.name if b.parent else None
            self.comprimento[b.name] = (b.tail_local - b.head_local).length
        for nome, pai in self.parente.items():
            if pai:
                self.offset[nome] = self.rest[pai].inverted() @ self.rest[nome]
            else:
                self.offset[nome] = self.rest[nome].copy()
        self.basis = {n: Matrix.Identity(4) for n in self.rest}

    # ------------------------------------------------------------ nucleo
    def reset(self):
        for n in self.basis:
            self.basis[n] = Matrix.Identity(4)

    def matriz(self, nome):
        pai = self.parente[nome]
        if pai is None:
            return self.offset[nome] @ self.basis[nome]
        return self.matriz(pai) @ self.offset[nome] @ self.basis[nome]

    def definir(self, nome, M):
        pai = self.parente[nome]
        if pai is None:
            base = self.offset[nome]
        else:
            base = self.matriz(pai) @ self.offset[nome]
        self.basis[nome] = base.inverted() @ M

    def girar(self, nome, eixo, graus):
        if abs(graus) < 1e-6:
            return
        M = self.matriz(nome)
        cabeca = M.translation.copy()
        R = Matrix.Rotation(math.radians(graus), 4, eixo)
        self.definir(nome, Matrix.Translation(cabeca) @ R @ Matrix.Translation(-cabeca) @ M)

    def mirar(self, nome, alvo, ref_x=Vector((1, 0, 0))):
        M = self.matriz(nome)
        cabeca = M.translation.copy()
        d = Vector(alvo) - cabeca
        if d.length < 1e-6:
            return
        y = d.normalized()
        x = Vector(ref_x)
        x = x - y * x.dot(y)
        if x.length < 1e-4:
            x = Vector((0, 1, 0))
            x = x - y * x.dot(y)
        x.normalize()
        z = x.cross(y).normalized()
        x = y.cross(z).normalized()
        self.definir(nome, Matrix((
            (x.x, y.x, z.x, cabeca.x),
            (x.y, y.y, z.y, cabeca.y),
            (x.z, y.z, z.z, cabeca.z),
            (0, 0, 0, 1),
        )))

    # ------------------------------------------------------------ corpo
    def mover_hips(self, dx=0.0, dy=0.0, dz=0.0, pitch=0.0, yaw=0.0, roll=0.0):
        self.girar("hips", "X", pitch)
        self.girar("hips", "Z", yaw)
        self.girar("hips", "Y", roll)
        M = self.matriz("hips")
        M = Matrix.Translation(Vector((dx, dy, dz))) @ M
        self.definir("hips", M)

    def perna(self, lado, tornozelo, ponta_pe, frente=Vector((0, 1, 0))):
        coxa = "thigh_" + lado
        canela = "shin_" + lado
        pe = "foot_" + lado
        H = self.matriz(coxa).translation.copy()
        L1 = self.comprimento[coxa]
        L2 = self.comprimento[canela]
        A = Vector(tornozelo)
        dv = A - H
        d = dv.length
        if d < 1e-6:
            return
        d = max(abs(L1 - L2) + 1e-3, min(L1 + L2 - 2e-3, d))
        direcao = dv.normalized()
        A = H + direcao * d
        a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
        h = math.sqrt(max(0.0, L1 * L1 - a * a))
        polo = Vector(frente) - direcao * Vector(frente).dot(direcao)
        if polo.length < 1e-5:
            polo = Vector((0, 1, 0))
        polo.normalize()
        joelho = H + direcao * a + polo * h
        self.mirar(coxa, joelho)
        self.mirar(canela, A)
        self.mirar(pe, ponta_pe)

    # ------------------------------------------------------------ saida
    def aplicar(self):
        for nome, M in self.basis.items():
            pb = self.arm.pose.bones[nome]
            pb.rotation_mode = "QUATERNION"
            pb.matrix_basis = M

    def chaves(self, frame):
        for pb in self.arm.pose.bones:
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)


def cor(pontos, t):
    """Interpolacao suave (smoothstep) numa lista de (tempo, valor)."""
    if t <= pontos[0][0]:
        return pontos[0][1]
    if t >= pontos[-1][0]:
        return pontos[-1][1]
    for i in range(len(pontos) - 1):
        t0, v0 = pontos[i]
        t1, v1 = pontos[i + 1]
        if t0 <= t <= t1:
            x = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
            x = x * x * (3 - 2 * x)
            return v0 + (v1 - v0) * x
    return pontos[-1][1]
