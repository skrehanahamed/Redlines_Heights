"""Generates a seamless cloud texture: R = cumulus density, G = fine detail, B = wispy cirrus. Pure procedural (no external assets)."""
import numpy as np
from PIL import Image
N = 1024
rng = np.random.default_rng(7)

def spectral(beta, ax=1.0, ay=1.0, seed=0):
    r = np.random.default_rng(seed)
    fx = np.fft.fftfreq(N)[None, :] * ax
    fy = np.fft.fftfreq(N)[:, None] * ay
    f = np.sqrt(fx**2 + fy**2); f[0, 0] = 1
    amp = 1.0 / f**(beta / 2)
    amp[0, 0] = 0
    ph = np.exp(2j * np.pi * r.random((N, N)))
    n = np.real(np.fft.ifft2(amp * ph))
    n = (n - n.min()) / (n.max() - n.min())
    return n

def warp(a, b, k):
    ys, xs = np.mgrid[0:N, 0:N]
    xi = ((xs + (b - 0.5) * k) % N).astype(int)
    yi = ((ys + (a - 0.5) * k) % N).astype(int)
    return xi, yi

base = spectral(3.3, seed=1)
w1, w2 = spectral(3.0, seed=2), spectral(3.0, seed=3)
xi, yi = warp(w1, w2, 140)
cum = base[yi, xi]
cum = (cum - cum.mean()) / cum.std()
cum = np.clip(cum * 0.5 + 0.5, 0, 1)
detail = spectral(2.6, seed=4)
cirrus = spectral(2.4, ax=0.18, ay=1.0, seed=5)
cirrus = np.clip((cirrus - 0.5) * 3 + 0.5, 0, 1)
img = np.stack([cum, detail, cirrus], -1)
Image.fromarray((img * 255).astype(np.uint8)).save("assets/textures/sky_clouds.png")
print("ok")
