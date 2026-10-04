"""Synthesise the Islas Battle sound effects (gunshots, explosions, pickups)."""
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 22050
rng = np.random.default_rng(3)
OUT = 'assets/audio/battle/'


def t(sec):
    return np.arange(int(sec * SR)) / SR


def noise(sec):
    return rng.standard_normal(int(sec * SR))


def filt(x, kind, f, order=2):
    return sosfilt(butter(order, f, kind, fs=SR, output='sos'), x)


def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), 200)
    x[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(OUT + name + '.wav', SR, (x * 32767).astype(np.int16))


def gunshot(length, low, high, decay, thump_f, thump, crack=0.0):
    tt = t(length)
    n = noise(length)
    body = filt(n, 'band', [low, high]) * np.exp(-tt / decay)
    boom = np.sin(2 * np.pi * thump_f * tt * np.exp(-tt * 6)) * np.exp(-tt / (decay * 1.4)) * thump
    snap = filt(noise(length), 'high', 3000) * np.exp(-tt / 0.006) * crack
    # A little echo off the hills.
    x = body + boom + snap
    d = int(0.09 * SR)
    echo = np.zeros_like(x)
    echo[d:] = x[:-d] * 0.25
    return filt(x + filt(echo, 'low', 1500), 'low', 9000)


save('pistol', gunshot(0.35, 400, 5000, 0.045, 140, 0.8, 0.5))
save('rifle', gunshot(0.28, 300, 4500, 0.04, 110, 1.0, 0.6), 0.75)
save('shotgun', gunshot(0.6, 150, 3500, 0.09, 80, 1.6, 0.4))
save('sniper', gunshot(0.9, 200, 6000, 0.08, 70, 1.4, 1.2))

# Rocket launch: a whoosh that rises.
tt = t(0.8)
whoosh = filt(noise(0.8), 'band', [300, 2500]) * np.minimum(1, tt / 0.05) * np.exp(-tt / 0.35)
save('rpg', whoosh + gunshot(0.8, 100, 1500, 0.05, 60, 1.2), 0.8)

# Explosion: deep rumble with crackle.
tt = t(1.8)
rumble = filt(noise(1.8), 'low', 400, 4) * np.exp(-tt / 0.45) * 3
crackle = filt(noise(1.8), 'band', [800, 4000]) * np.exp(-tt / 0.15)
boom = np.sin(2 * np.pi * 50 * tt * np.exp(-tt * 2)) * np.exp(-tt / 0.3) * 2
save('explosion', rumble + crackle + boom)

# Hit marker: a short bright tick.
tt = t(0.08)
save('hit', np.sin(2 * np.pi * 1800 * tt) * np.exp(-tt / 0.015) + np.sin(2 * np.pi * 2700 * tt) * np.exp(-tt / 0.01) * 0.5, 0.6)

# You got hit: a dull thud.
tt = t(0.25)
save('hurt', filt(noise(0.25), 'low', 300) * np.exp(-tt / 0.05) + np.sin(2 * np.pi * 90 * tt) * np.exp(-tt / 0.06), 0.8)

# Pickup: a quick rising chime.
tt = t(0.35)
chime = sum(np.sin(2 * np.pi * f * tt) * np.exp(-(tt - d) / 0.12) * (tt >= d) for f, d in [(880, 0), (1320, 0.06), (1760, 0.12)])
save('pickup', chime, 0.5)

# Reload: two metallic clicks.
tt = t(0.45)
click = np.zeros_like(tt)
for d in (0.0, 0.3):
    m = tt >= d
    click[m] += filt(noise(0.45), 'band', [1500, 6000])[: m.sum()] * np.exp(-(tt[m] - d) / 0.012)
save('reload', click, 0.6)

# Empty gun: a dry click.
tt = t(0.1)
save('empty', filt(noise(0.1), 'band', [2000, 7000]) * np.exp(-tt / 0.01), 0.5)

# Knock out: a low "whomp" and sparkle.
tt = t(0.6)
save('knock', np.sin(2 * np.pi * (300 - 200 * tt) * tt) * np.exp(-tt / 0.2) + sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.25) * 0.3 for f in (1500, 2250)), 0.6)

# Victory fanfare.
tt = t(2.2)
notes = [(523, 0), (659, 0.18), (784, 0.36), (1047, 0.6)]
fan = np.zeros_like(tt)
for f, d in notes:
    m = tt >= d
    env = np.exp(-(tt[m] - d) / (0.9 if f == 1047 else 0.3))
    fan[m] += (np.sin(2 * np.pi * f * tt[m]) + 0.4 * np.sin(4 * np.pi * f * tt[m]) + 0.2 * np.sin(6 * np.pi * f * tt[m])) * env
save('victory', fan, 0.6)
