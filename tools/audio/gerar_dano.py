import math
import wave
from pathlib import Path

import numpy as np

SR = 44100
DURACAO = 0.42
TAU = 2.0 * math.pi
RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / "audio" / "dano.wav"


def escrever_wav(caminho: Path, amostras: np.ndarray) -> None:
    dados = np.clip(amostras, -1.0, 1.0)
    pcm = (dados * 32767.0).astype("<i2")
    with wave.open(str(caminho), "wb") as arquivo:
        arquivo.setnchannels(1)
        arquivo.setsampwidth(2)
        arquivo.setframerate(SR)
        arquivo.writeframes(pcm.tobytes())


t = np.arange(int(SR * DURACAO)) / SR
rng = np.random.default_rng(20261026)

f_impacto = 38.0 + 120.0 * np.exp(-t * 18.0)
fase_impacto = TAU * np.cumsum(f_impacto) / SR
impacto = np.sin(fase_impacto) * np.exp(-t * 12.0) * 0.8

ruido = rng.standard_normal(t.size)
ruido = np.convolve(ruido, np.ones(5) / 5.0, mode="same")
estalo = ruido * np.exp(-t * 40.0) * 0.35

f_boing = 190.0 + 330.0 * np.exp(-t * 5.5)
vibrato = 1.0 + 0.018 * np.sin(TAU * 9.0 * t)
fase_boing = TAU * np.cumsum(f_boing * vibrato) / SR
boing = (
    np.sin(fase_boing) + 0.25 * np.sin(2.0 * fase_boing)
) * np.exp(-t * 6.5) * 0.48

mistura = impacto + estalo + boing
mistura -= float(np.mean(mistura))
mistura = np.tanh(mistura * 1.15)
entrada = np.minimum(1.0, t / 0.004)
saida = np.minimum(1.0, (DURACAO - t) / 0.06)
mistura *= entrada * saida
pico = float(np.max(np.abs(mistura)))
if pico > 0.0:
    mistura *= 0.85 / pico

SAIDA.parent.mkdir(parents=True, exist_ok=True)
escrever_wav(SAIDA, mistura)
print(f"{SAIDA.name}: {DURACAO:.2f}s, pico {20.0 * math.log10(0.85):.1f} dBFS, {SAIDA.stat().st_size} bytes")
