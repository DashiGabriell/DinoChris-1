"""Utilidades de pose: girar ossos no espaco do armature e mirar alvos."""
import bpy
from mathutils import Matrix, Vector


def atualizar():
    bpy.context.view_layer.update()


def girar(arm, nome, eixo, graus, acumular=True):
    """Gira o osso `nome` em torno do proprio head, no espaco do armature."""
    pb = arm.pose.bones[nome]
    loc = pb.matrix.translation.copy()
    R = Matrix.Rotation(__import__("math").radians(graus), 4, eixo)
    alvo = Matrix.Translation(loc) @ R @ Matrix.Translation(-loc) @ pb.matrix
    pb.matrix = alvo
    atualizar()


def mirar(arm, nome, destino):
    """Aponta o eixo Y do osso para um ponto no espaco do armature."""
    pb = arm.pose.bones[nome]
    M = pb.matrix.copy()
    origem = M.translation.copy()
    d = (Vector(destino) - origem)
    if d.length < 1e-6:
        return
    d.normalize()
    # base atual: Y = direcao do osso, X e Z mantidos o mais proximo possivel
    y = d
    x = M.to_3x3().col[0].normalized()
    x = (x - y * x.dot(y))
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
        x = (x - y * x.dot(y))
    x.normalize()
    z = y.cross(x).normalized()
    x = z.cross(y).normalized()
    nova = Matrix((
        (x.x, y.x, z.x, origem.x),
        (x.y, y.y, z.y, origem.y),
        (x.z, y.z, z.z, origem.z),
        (0, 0, 0, 1),
    ))
    pb.matrix = nova
    atualizar()


def limpar(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    atualizar()


def posicao_osso(arm, nome):
    return arm.pose.bones[nome].matrix.translation.copy()


def ponta_osso(arm, nome):
    pb = arm.pose.bones[nome]
    return (pb.matrix @ Vector((0, pb.bone.length, 0)))
