"""Monta folha de contato das poses de QA."""
import os
from PIL import Image, ImageDraw

SAIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "qa")
CLIPES = {
    "Idle": [0, 22, 45, 68],
    "Walk": [0, 8, 15, 23],
    "Run": [0, 5, 10, 15],
    "Jump": [0, 6, 13, 19, 25],
    "Attack": [0, 5, 10, 14, 20],
    "Roar": [0, 8, 16, 26, 34],
}

max_cols = max(len(v) for v in CLIPES.values())
largura, altura = 400, 400
rotulo = 44
folha = Image.new("RGB", (largura * max_cols, (altura + rotulo) * len(CLIPES)), (22, 24, 30))
desenho = ImageDraw.Draw(folha)

for linha, (clipe, quadros) in enumerate(CLIPES.items()):
    y0 = linha * (altura + rotulo)
    desenho.text((10, y0 + 14), clipe, fill=(255, 220, 150))
    for col, f in enumerate(quadros):
        caminho = os.path.join(SAIDA, "{}_{:03d}.png".format(clipe, f))
        if not os.path.exists(caminho):
            continue
        im = Image.open(caminho).convert("RGB")
        folha.paste(im, (col * largura, y0 + rotulo))
        desenho.text((col * largura + 8, y0 + rotulo + 6), "f%d" % f, fill=(200, 200, 200))

destino = os.path.join(os.path.dirname(SAIDA), "folha_qa.png")
folha.save(destino)
print(destino)
