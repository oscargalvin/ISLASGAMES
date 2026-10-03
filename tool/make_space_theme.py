"""Synthesise an original, soothing ambient space loop for Space Adventure."""
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt
from scipy.io import wavfile

SR = 44100
BPM = 66
BEAT = 60 / BPM
BAR = BEAT * 4
BARS = 16
LOOP = BAR * BARS
N = int(LOOP * SR)
rng = np.random.default_rng(42)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# D major, dreamy lydian-ish colours. Each chord lasts 2 bars.
D, E, Fs, G, A, B, Cs = 62, 64, 66, 67, 69, 71, 73
chords = [
    [D - 12, A - 12, Fs, A, Cs + 0, E + 12],      # Dmaj9
    [B - 24, Fs - 12, D, A, B, E + 12],           # Bm11
    [G - 24, D - 12, B - 12, Fs, A, Cs + 12],     # Gmaj7#11-ish
    [A - 24, E - 12, B - 12, D, E, B],            # A sus/add9
] * 2

L = np.zeros(N + SR * 6)
R = np.zeros(N + SR * 6)


def env_adsr(n, a, r):
    t = np.arange(n) / SR
    e = np.minimum(1, t / a) * np.minimum(1, (n / SR - t) / r)
    return np.clip(e, 0, 1)


# ---- Pads: soft detuned sines + a touch of filtered saw
lp = butter(2, 1400, 'low', fs=SR, output='sos')
for ci, chord in enumerate(chords):
    start = int(ci * 2 * BAR * SR)
    length = int((2 * BAR + 2.5) * SR)
    t = np.arange(length) / SR
    e = env_adsr(length, 2.2, 2.6)
    for k, note in enumerate(chord):
        f = midi(note)
        voice = np.zeros(length)
        for det in (-0.12, 0.0, 0.13):
            ff = f * 2 ** (det / 12)
            ph = rng.uniform(0, 2 * np.pi)
            voice += np.sin(2 * np.pi * ff * t + ph)
            # Gentle saw for warmth
            voice += 0.18 * (2 * ((ff * t + ph / 6.28) % 1) - 1)
        voice = sosfilt(lp, voice)
        vib = 1 + 0.15 * np.sin(2 * np.pi * (0.1 + 0.03 * k) * t)
        amp = (0.05 if note < 50 else 0.032) * vib
        pan = 0.5 + 0.35 * np.sin(k * 1.9)
        seg = voice * e * amp
        L[start:start + length] += seg * (1 - pan)
        R[start:start + length] += seg * pan

# ---- Sub bass: chord roots, very soft
for ci, chord in enumerate(chords):
    start = int(ci * 2 * BAR * SR)
    length = int((2 * BAR + 1.5) * SR)
    t = np.arange(length) / SR
    root = chord[0]
    while root > 45:
        root -= 12
    s = np.sin(2 * np.pi * midi(root) * t) * env_adsr(length, 1.5, 1.8) * 0.09
    L[start:start + length] += s
    R[start:start + length] += s

# ---- Twinkly bells: a slow, gentle pentatonic melody with echoes
scale = [D, E, Fs, A, B, D + 12, E + 12, Fs + 12, A + 12]
melody_rng = np.random.default_rng(7)
idx = 4
for step in range(int(LOOP / (BEAT / 2))):
    if melody_rng.random() > 0.42:
        continue
    idx = int(np.clip(idx + melody_rng.integers(-2, 3), 0, len(scale) - 1))
    note = scale[idx] + 12
    start = int(step * BEAT / 2 * SR)
    length = int(3.5 * SR)
    t = np.arange(length) / SR
    f = midi(note)
    bell = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.01 * t)
            + 0.12 * np.sin(2 * np.pi * f * 3.98 * t))
    bell *= np.exp(-t * 1.6) * np.minimum(1, t / 0.004) * 0.055
    pan = 0.25 + 0.5 * melody_rng.random()
    for echo in range(4):
        d = int(echo * BEAT * 0.75 * SR)
        g = 0.55 ** echo
        p = pan if echo % 2 == 0 else 1 - pan
        s0, s1 = start + d, start + d + length
        if s1 > len(L):
            continue
        L[s0:s1] += bell * g * (1 - p)
        R[s0:s1] += bell * g * p

# ---- Faint shimmer of "space air"
noise = rng.normal(size=len(L))
bp = butter(2, [3000, 7000], 'band', fs=SR, output='sos')
air = sosfilt(bp, noise) * 0.004
swell = 0.5 + 0.5 * np.sin(2 * np.pi * np.arange(len(L)) / SR / (LOOP / 2))
L += air * swell
R += np.roll(air, 1234) * swell

# ---- Big soft reverb (synthetic impulse response)
ir_len = int(4.0 * SR)
tt = np.arange(ir_len) / SR
irL = rng.normal(size=ir_len) * np.exp(-tt * 1.5)
irR = rng.normal(size=ir_len) * np.exp(-tt * 1.5)
irL /= np.sqrt(np.sum(irL ** 2))
irR /= np.sqrt(np.sum(irR ** 2))
wetL = fftconvolve(L, irL)[:len(L)]
wetR = fftconvolve(R, irR)[:len(R)]
L = L * 0.6 + wetL * 0.55
R = R * 0.6 + wetR * 0.55

# ---- Wrap the tail around so the loop is seamless
outL = L[:N].copy()
outR = R[:N].copy()
tail = len(L) - N
outL[:tail] += L[N:]
outR[:tail] += R[N:]

out = np.stack([outL, outR], axis=1)
out /= np.max(np.abs(out)) / 0.7
wavfile.write('space_theme.wav', SR, (out * 32767).astype(np.int16))
print('loop seconds', LOOP)
