"""Lista os contornos abertos (boundary loops) de cada malha, com centro e tamanho."""
import bpy
import bmesh
import os
import sys
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import trex_comum as C

bpy.ops.wm.open_mainfile(filepath=os.path.join(C.SAIDA, "trex_rig.blend"))

for ob in bpy.context.scene.objects:
    if ob.type != "MESH":
        continue
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    visitadas = set()
    loops = []
    for e in bm.edges:
        if len(e.link_faces) != 1 or e in visitadas:
            continue
        # percorre o contorno
        fila = [e]
        contorno = []
        while fila:
            atual = fila.pop()
            if atual in visitadas:
                continue
            visitadas.add(atual)
            contorno.append(atual)
            for v in atual.verts:
                for e2 in v.link_edges:
                    if e2 not in visitadas and len(e2.link_faces) == 1:
                        fila.append(e2)
        if len(contorno) < 3:
            continue
        pontos = []
        for e in contorno:
            pontos.append(e.verts[0].co)
            pontos.append(e.verts[1].co)
        centro = sum(pontos, Vector()) / len(pontos)
        tam = max((p - centro).length for p in pontos)
        loops.append((len(contorno), tam, centro))
    loops.sort(key=lambda x: -x[0])
    print("### {} loops_abertos={} ".format(ob.name, len(loops)))
    for n, tam, c in loops[:4]:
        print("   bordas={:4d} raio={:.3f} centro=({:.2f},{:.2f},{:.2f})".format(n, tam, c.x, c.y, c.z))
    bm.free()

print("###FIM###")
