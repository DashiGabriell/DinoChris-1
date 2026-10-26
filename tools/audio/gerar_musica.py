import math
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
TAU = 2.0 * math.pi
RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / "audio"

ACORDES = {
    "D": (38, (62, 66, 69)),
    "Bm": (47, (59, 62, 66)),
    "G": (43, (55, 59, 62)),
    "A": (45, (57, 61, 64)),
    "Em": (40, (52, 55, 59)),
    "F#m": (42, (54, 57, 61)),
}

PROGRESSAO_FASE = ["D", "Bm", "G", "A", "D", "Bm", "Em", "A",
                   "G", "A", "F#m", "Bm", "Em", "A", "D", "A"]
PROGRESSAO_MENU = PROGRESSAO_FASE[:8]
PROGRESSAO_GAME_OVER = ["D", "Bm", "G", "A", "G", "A", "D", "A"]

MELODIA_A = [
    (1, 0.00, 78, 0.75, 0.95), (1, 0.75, 81, 0.25, 0.78),
    (1, 1.50, 78, 0.50, 0.86), (1, 2.25, 74, 0.50, 0.88),
    (1, 3.00, 76, 0.50, 0.90), (1, 3.50, 78, 0.50, 0.82),
    (2, 0.00, 78, 0.50, 0.90), (2, 0.50, 83, 0.50, 0.84),
    (2, 1.25, 81, 0.75, 0.94), (2, 2.25, 78, 0.50, 0.84),
    (2, 3.00, 74, 0.50, 0.82), (2, 3.50, 76, 0.50, 0.86),
    (3, 0.00, 79, 0.50, 0.90), (3, 0.50, 83, 0.50, 0.84),
    (3, 1.00, 81, 0.50, 0.88), (3, 1.50, 79, 0.50, 0.82),
    (3, 2.00, 78, 0.75, 0.92), (3, 3.00, 79, 0.50, 0.84),
    (3, 3.50, 81, 0.50, 0.88),
    (4, 0.00, 81, 1.00, 0.98), (4, 1.00, 76, 0.50, 0.82),
    (4, 1.50, 78, 0.50, 0.86), (4, 2.25, 81, 1.00, 0.94),
    (4, 3.50, 79, 0.50, 0.80),
    (5, 0.00, 78, 0.50, 0.92), (5, 0.50, 81, 0.50, 0.84),
    (5, 1.25, 86, 0.75, 0.98), (5, 2.25, 81, 0.50, 0.88),
    (5, 3.00, 78, 0.50, 0.84), (5, 3.50, 76, 0.50, 0.78),
    (6, 0.00, 74, 0.50, 0.86), (6, 0.50, 78, 0.50, 0.84),
    (6, 1.25, 83, 0.75, 0.96), (6, 2.25, 81, 0.50, 0.86),
    (6, 3.00, 78, 0.50, 0.82), (6, 3.50, 76, 0.50, 0.80),
    (7, 0.00, 79, 0.50, 0.90), (7, 0.50, 76, 0.50, 0.82),
    (7, 1.25, 83, 0.75, 0.94), (7, 2.25, 79, 0.50, 0.86),
    (7, 3.00, 78, 0.50, 0.82), (7, 3.50, 76, 0.50, 0.84),
    (8, 0.00, 76, 0.50, 0.86), (8, 0.50, 79, 0.50, 0.84),
    (8, 1.25, 81, 1.25, 0.92), (8, 2.75, 79, 0.25, 0.76),
    (8, 3.00, 78, 0.50, 0.84), (8, 3.50, 76, 0.50, 0.80),
]

MELODIA_B = [
    (9, 0.00, 83, 0.50, 0.96), (9, 0.50, 86, 0.50, 0.88),
    (9, 1.00, 83, 0.50, 0.90), (9, 1.50, 81, 0.50, 0.84),
    (9, 2.00, 79, 1.00, 0.92), (9, 3.25, 81, 0.50, 0.84),
    (9, 3.75, 83, 0.25, 0.78),
    (10, 0.00, 81, 0.50, 0.94), (10, 0.50, 85, 0.50, 0.88),
    (10, 1.00, 81, 0.50, 0.88), (10, 1.50, 78, 0.50, 0.82),
    (10, 2.00, 76, 1.00, 0.88), (10, 3.25, 78, 0.25, 0.78),
    (10, 3.50, 81, 0.50, 0.86),
    (11, 0.00, 78, 0.50, 0.94), (11, 0.50, 81, 0.50, 0.86),
    (11, 1.00, 85, 0.75, 0.94), (11, 2.00, 81, 0.50, 0.86),
    (11, 2.50, 78, 0.50, 0.82), (11, 3.00, 81, 0.50, 0.86),
    (11, 3.50, 78, 0.50, 0.80),
    (12, 0.00, 83, 0.75, 0.96), (12, 1.00, 81, 0.50, 0.86),
    (12, 1.50, 78, 0.50, 0.82), (12, 2.00, 74, 1.00, 0.88),
    (12, 3.25, 76, 0.25, 0.78), (12, 3.50, 78, 0.50, 0.84),
    (13, 0.00, 76, 0.50, 0.92), (13, 0.50, 79, 0.50, 0.84),
    (13, 1.00, 83, 0.75, 0.96), (13, 2.00, 79, 0.50, 0.86),
    (13, 2.50, 76, 0.50, 0.80), (13, 3.00, 79, 0.50, 0.84),
    (13, 3.50, 83, 0.50, 0.86),
    (14, 0.00, 81, 0.50, 0.94), (14, 0.50, 85, 0.50, 0.88),
    (14, 1.00, 88, 1.00, 0.96), (14, 2.25, 85, 0.50, 0.84),
    (14, 2.75, 81, 0.50, 0.82), (14, 3.25, 78, 0.25, 0.78),
    (14, 3.50, 81, 0.50, 0.84),
    (15, 0.00, 78, 0.50, 0.94), (15, 0.50, 81, 0.50, 0.86),
    (15, 1.00, 86, 1.50, 1.00), (15, 2.75, 81, 0.25, 0.78),
    (15, 3.00, 78, 0.50, 0.84), (15, 3.50, 81, 0.50, 0.86),
    (16, 0.00, 81, 0.50, 0.94), (16, 0.50, 79, 0.50, 0.86),
    (16, 1.00, 76, 0.50, 0.84), (16, 1.50, 73, 0.50, 0.80),
    (16, 2.00, 69, 1.00, 0.86), (16, 3.25, 73, 0.25, 0.76),
    (16, 3.50, 76, 0.50, 0.82),
]

MELODIA_GAME_OVER = [
    (1, 0.00, 74, 1.00, 0.80), (1, 1.00, 78, 0.50, 0.72),
    (1, 1.50, 81, 0.50, 0.68), (1, 2.25, 78, 0.75, 0.72),
    (1, 3.25, 76, 0.50, 0.66),
    (2, 0.00, 78, 0.75, 0.76), (2, 1.00, 83, 0.50, 0.70),
    (2, 1.50, 81, 0.50, 0.66), (2, 2.25, 78, 0.75, 0.70),
    (2, 3.25, 74, 0.50, 0.62),
    (3, 0.00, 79, 0.75, 0.74), (3, 1.00, 83, 0.50, 0.70),
    (3, 1.50, 81, 0.50, 0.66), (3, 2.25, 79, 0.75, 0.70),
    (3, 3.25, 78, 0.50, 0.64),
    (4, 0.00, 76, 0.75, 0.72), (4, 1.00, 78, 0.50, 0.66),
    (4, 1.50, 81, 1.00, 0.72), (4, 2.75, 79, 0.25, 0.62),
    (4, 3.00, 76, 0.50, 0.66),
    (5, 0.00, 79, 1.00, 0.74), (5, 1.25, 78, 0.50, 0.66),
    (5, 2.00, 76, 1.00, 0.70), (5, 3.25, 74, 0.50, 0.62),
    (6, 0.00, 73, 0.50, 0.64), (6, 0.50, 76, 0.50, 0.66),
    (6, 1.00, 81, 0.75, 0.72), (6, 2.00, 79, 0.50, 0.66),
    (6, 2.50, 76, 0.50, 0.62), (6, 3.00, 73, 0.75, 0.66),
    (7, 0.00, 78, 0.75, 0.76), (7, 1.00, 81, 0.50, 0.70),
    (7, 1.50, 86, 1.25, 0.78), (7, 3.00, 83, 0.50, 0.68),
    (7, 3.50, 81, 0.50, 0.64),
    (8, 0.00, 81, 0.75, 0.72), (8, 1.00, 79, 0.50, 0.66),
    (8, 1.50, 76, 0.50, 0.64), (8, 2.00, 73, 1.25, 0.68),
    (8, 3.50, 76, 0.50, 0.62),
]


def mfreq(nota):
    return 440.0 * (2.0 ** ((nota - 69) / 12.0))


def envelope(n, ataque, decaimento):
    t = np.arange(n, dtype=np.float64) / SR
    subida = np.clip(t / max(ataque, 0.0001), 0.0, 1.0)
    return subida * np.exp(-decaimento * t)


def nota_marimba(nota, duracao, velocidade):
    n = max(1, int(duracao * SR))
    t = np.arange(n, dtype=np.float64) / SR
    f = mfreq(nota)
    env = envelope(n, 0.004, 5.2 + (90 - nota) * 0.025)
    som = (np.sin(TAU * f * t) +
           0.30 * np.sin(TAU * f * 4.01 * t) * np.exp(-9.0 * t) +
           0.09 * np.sin(TAU * f * 9.83 * t) * np.exp(-17.0 * t))
    return som * env * velocidade


def nota_flauta(nota, duracao, velocidade):
    n = max(1, int(duracao * SR))
    t = np.arange(n, dtype=np.float64) / SR
    f = mfreq(nota)
    vibrato = np.sin(TAU * 5.1 * t) * 0.005 * np.clip(t / 0.2, 0.0, 1.0)
    fase = TAU * f * (t + vibrato * t)
    env = envelope(n, 0.055, 1.2) * np.clip((duracao - t) / 0.10, 0.0, 1.0)
    som = (np.sin(fase) +
           0.16 * np.sin(2.0 * fase) +
           0.05 * np.sin(3.0 * fase))
    return som * env * velocidade


def nota_baixo(nota, duracao, velocidade):
    n = max(1, int(duracao * SR))
    t = np.arange(n, dtype=np.float64) / SR
    f = mfreq(nota)
    env = envelope(n, 0.012, 7.0)
    som = np.sin(TAU * f * t) + 0.18 * np.sin(TAU * f * 2.0 * t)
    return som * env * velocidade


def nota_ukulele(nota, duracao, velocidade, rng):
    n = max(1, int(duracao * SR))
    periodo = max(2, int(SR / mfreq(nota)))
    exc = rng.uniform(-1.0, 1.0, periodo)
    saida = np.empty(n, dtype=np.float64)
    atraso = exc.copy()
    for i in range(n):
        saida[i] = atraso[i % periodo]
        atraso[i % periodo] = 0.4975 * (atraso[i % periodo] + atraso[(i + 1) % periodo])
    env = envelope(n, 0.003, 3.2)
    return saida * env * velocidade


def nota_pad(nota, duracao, velocidade):
    n = max(1, int(duracao * SR))
    t = np.arange(n, dtype=np.float64) / SR
    f = mfreq(nota)
    env = np.clip(t / 0.45, 0.0, 1.0) * np.clip((duracao - t) / 0.55, 0.0, 1.0)
    som = (np.sin(TAU * f * t) +
           0.35 * np.sin(TAU * (f * 1.003) * t) +
           0.12 * np.sin(TAU * (f * 0.997) * t))
    return som * env * velocidade


def percussao(tipo, rng):
    if tipo == "kick":
        dur = 0.28
        n = int(dur * SR)
        t = np.arange(n, dtype=np.float64) / SR
        f0, f1 = 118.0, 44.0
        fase = TAU * (f0 * t + (f1 - f0) * t * t / (2.0 * dur))
        som = np.sin(fase) * np.exp(-16.0 * t)
        som[:int(0.006 * SR)] += rng.uniform(-1.0, 1.0, int(0.006 * SR)) * 0.35
        return som
    if tipo == "snare":
        dur = 0.19
        n = int(dur * SR)
        t = np.arange(n, dtype=np.float64) / SR
        ruido = rng.normal(0.0, 1.0, n)
        ruido = np.diff(ruido, prepend=0.0)
        som = ruido * np.exp(-24.0 * t) * 0.55
        som += np.sin(TAU * 188.0 * t) * np.exp(-35.0 * t) * 0.35
        return som
    if tipo == "shaker":
        dur = 0.075
        n = int(dur * SR)
        t = np.arange(n, dtype=np.float64) / SR
        ruido = rng.normal(0.0, 1.0, n)
        ruido = np.diff(ruido, prepend=0.0)
        return ruido * np.exp(-70.0 * t)
    if tipo == "tom":
        dur = 0.24
        n = int(dur * SR)
        t = np.arange(n, dtype=np.float64) / SR
        fase = TAU * (172.0 * t + (88.0 - 172.0) * t * t / (2.0 * dur))
        return np.sin(fase) * np.exp(-13.0 * t)
    if tipo == "wood":
        dur = 0.12
        n = int(dur * SR)
        t = np.arange(n, dtype=np.float64) / SR
        som = (np.sin(TAU * 920.0 * t) * 0.6 +
               np.sin(TAU * 1420.0 * t) * 0.25)
        return som * np.exp(-42.0 * t)
    return np.zeros(1)


def adicionar(buffer, inicio, som, ganho, pan, rng):
    n = len(buffer)
    inicio_amostra = int(round(inicio * SR))
    indices = (np.arange(len(som)) + inicio_amostra) % n
    esquerda = math.cos((pan + 1.0) * math.pi / 4.0)
    direita = math.sin((pan + 1.0) * math.pi / 4.0)
    buffer[indices, 0] += som * ganho * esquerda
    buffer[indices, 1] += som * ganho * direita


def reverb_circular(buffer):
    n = len(buffer)
    rng = np.random.default_rng(404)
    ir = np.zeros(n, dtype=np.float64)
    for atraso, ganho in ((0.013, 0.30), (0.021, 0.24), (0.034, 0.18),
                          (0.052, 0.13), (0.079, 0.09), (0.113, 0.06)):
        ir[int(atraso * SR)] += ganho
    cauda = int(0.55 * SR)
    t = np.arange(cauda, dtype=np.float64) / SR
    ruido = rng.normal(0.0, 1.0, cauda) * np.exp(-5.8 * t) * 0.028
    inicio = int(0.018 * SR)
    fim = min(n, inicio + cauda)
    ir[inicio:fim] += ruido[:fim - inicio]
    espectro = np.fft.rfft(ir)
    saida = buffer.copy()
    for canal in range(2):
        molhado = np.fft.irfft(np.fft.rfft(buffer[:, canal]) * espectro, n=n)
        saida[:, canal] += molhado * 0.42
    return saida


def normalizar(buffer, alvo_db, teto_db):
    pico = float(np.max(np.abs(buffer)))
    if pico <= 0.0:
        return buffer
    rms = float(np.sqrt(np.mean(buffer * buffer)))
    ganho = 10.0 ** (alvo_db / 20.0) / max(rms, 1e-9)
    teto = 10.0 ** (teto_db / 20.0)
    if pico * ganho > teto:
        ganho = teto / pico
    return buffer * ganho


def salvar_wav(buffer, caminho):
    dados = np.clip(buffer, -1.0, 1.0)
    inteiros = np.round(dados * 32767.0).astype("<i2")
    with wave.open(str(caminho), "wb") as arquivo:
        arquivo.setnchannels(2)
        arquivo.setsampwidth(2)
        arquivo.setframerate(SR)
        arquivo.writeframes(inteiros.tobytes())


def renderizar(nome, bpm, progressao, melodia, estilo):
    compassos = len(progressao)
    total_beats = compassos * 4.0
    spb = 60.0 / bpm
    total = int(round(total_beats * spb * SR))
    buffer = np.zeros((total, 2), dtype=np.float64)
    rng = np.random.default_rng(1234 + compassos * 17 + int(bpm))

    for barra, acorde in enumerate(progressao, start=1):
        raiz, notas = ACORDES[acorde]
        base = (barra - 1) * 4.0 * spb

        if estilo in ("fase", "calmo", "menu"):
            for beat, oitava in ((0.0, 0), (2.0, 0)):
                som = nota_baixo(raiz + oitava, 0.52 * spb * 4.0, 0.30)
                adicionar(buffer, base + beat * spb, som, 1.0, 0.0, rng)
            if estilo == "fase":
                som = nota_baixo(raiz + 12, 0.35 * spb, 0.20)
                adicionar(buffer, base + 3.5 * spb, som, 1.0, 0.0, rng)

            strums = (0.0, 1.5, 2.0, 3.5) if estilo == "fase" else (0.0, 2.5)
            for beat in strums:
                for i, nota in enumerate(notas):
                    som = nota_ukulele(nota, 0.48 * spb, 0.22, rng)
                    adicionar(buffer, base + beat * spb + i * 0.014, som, 1.0, -0.28, rng)

        if estilo in ("calmo", "menu", "game_over"):
            for i, nota in enumerate(notas):
                som = nota_pad(nota, 4.0 * spb, 0.11 if estilo != "game_over" else 0.14)
                adicionar(buffer, base, som, 1.0, (-0.35, 0.25)[i % 2], rng)

    for barra, beat, nota, duracao, velocidade in melodia:
        inicio = ((barra - 1) * 4.0 + beat) * spb
        dur_marimba = max(0.30, duracao * spb * 1.15)
        dur_flauta = max(0.16, duracao * spb * 0.94)
        som = nota_marimba(nota, dur_marimba, velocidade * (0.58 if estilo == "game_over" else 0.50))
        adicionar(buffer, inicio, som, 1.0, 0.08, rng)
        if estilo in ("fase", "calmo", "menu"):
            som = nota_flauta(nota, dur_flauta, velocidade * 0.34)
            adicionar(buffer, inicio, som, 1.0, -0.22, rng)
        if estilo == "fase" and nota >= 81:
            brilho = nota_marimba(nota + 12, 0.22, velocidade * 0.10)
            adicionar(buffer, inicio, brilho, 1.0, 0.42, rng)

    if estilo == "fase":
        for barra in range(1, compassos + 1):
            base = (barra - 1) * 4.0 * spb
            for beat in (0.0, 2.0):
                adicionar(buffer, base + beat * spb, percussao("kick", rng), 0.55, 0.0, rng)
            for beat in (1.0, 3.0):
                adicionar(buffer, base + beat * spb, percussao("snare", rng), 0.20, 0.12, rng)
            for passo in range(8):
                beat = passo * 0.5
                ganho = 0.10 if passo % 2 else 0.065
                adicionar(buffer, base + beat * spb, percussao("shaker", rng), ganho, -0.42, rng)
            adicionar(buffer, base + 1.5 * spb, percussao("wood", rng), 0.11, 0.48, rng)
            adicionar(buffer, base + 3.5 * spb, percussao("wood", rng), 0.09, 0.48, rng)
            if barra in (4, 8, 12, 16):
                for passo, beat in enumerate((3.0, 3.25, 3.5, 3.75)):
                    adicionar(buffer, base + beat * spb, percussao("tom", rng),
                              0.20 + passo * 0.025, -0.18 + passo * 0.12, rng)
    elif estilo == "calmo":
        for barra in range(1, compassos + 1):
            base = (barra - 1) * 4.0 * spb
            for beat in (0.0, 2.0):
                adicionar(buffer, base + beat * spb, percussao("kick", rng), 0.20, 0.0, rng)
            for beat in (0.0, 1.0, 2.0, 3.0):
                adicionar(buffer, base + beat * spb, percussao("shaker", rng), 0.045, -0.38, rng)
    elif estilo == "menu":
        for barra in range(1, compassos + 1):
            base = (barra - 1) * 4.0 * spb
            adicionar(buffer, base, percussao("kick", rng), 0.16, 0.0, rng)
            for passo in range(4):
                adicionar(buffer, base + passo * spb, percussao("shaker", rng), 0.035, 0.38, rng)
            adicionar(buffer, base + 2.5 * spb, percussao("wood", rng), 0.055, 0.46, rng)
    elif estilo == "game_over":
        for barra in range(1, compassos + 1):
            base = (barra - 1) * 4.0 * spb
            adicionar(buffer, base, percussao("kick", rng), 0.12, 0.0, rng)

    buffer = reverb_circular(buffer)
    fade = int(0.008 * SR)
    buffer[:fade] *= np.linspace(0.0, 1.0, fade)[:, None]
    buffer[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    alvo = {"fase": -17.5, "calmo": -20.0, "menu": -19.0, "game_over": -20.5}[estilo]
    buffer = normalizar(buffer, alvo, -1.2)
    total_ms = int(round(len(buffer) / SR * 1000.0))
    print(f"{nome}: {total_ms} ms, pico={np.max(np.abs(buffer)):.3f}")
    return buffer


def converter_para_ogg(wav, ogg):
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6",
        "-ar", str(SR), "-ac", "2", str(ogg)
    ], check=True)


def gerar(nome, bpm, progressao, melodia, estilo):
    buffer = renderizar(nome, bpm, progressao, melodia, estilo)
    with tempfile.TemporaryDirectory(prefix="dino_musica_") as pasta:
        wav = Path(pasta) / f"{nome}.wav"
        salvar_wav(buffer, wav)
        ogg = SAIDA / f"{nome}.ogg"
        converter_para_ogg(wav, ogg)
        print(f"  -> {ogg.relative_to(RAIZ)} ({ogg.stat().st_size // 1024} KB)")


def main():
    if not SAIDA.exists():
        SAIDA.mkdir(parents=True)
    gerar("musica_fase", 108.0, PROGRESSAO_FASE, MELODIA_A + MELODIA_B, "fase")
    gerar("musica_calmo", 92.0, PROGRESSAO_FASE, MELODIA_A + MELODIA_B, "calmo")
    gerar("musica_menu", 88.0, PROGRESSAO_MENU, MELODIA_A, "menu")
    gerar("musica_game_over", 84.0, PROGRESSAO_GAME_OVER, MELODIA_GAME_OVER, "game_over")
    return 0


if __name__ == "__main__":
    sys.exit(main())
