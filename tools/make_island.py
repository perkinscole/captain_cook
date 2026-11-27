#!/usr/bin/env python3
"""Makes the island's ground: tools/make_island.py -> terrain/island_*.

The island is the worn-down stump of a volcano, like Tahiti, and the way to
get ground that looks like that is to wear it down. This raises a block of
land inside an invented coastline and lets rivers cut it for a long time
(the "stream power" rule that geomorphologists use: a stream cuts faster
the more water it carries and the steeper it runs), with softer and harder
rock in patches. What comes out has what real eroded islands have: valleys
that branch like trees, knife ridges between them, steep headwalls, and
streams that flatten as they near the sea. Round it goes a low plain and a
beach, and beyond that the seabed shelving away.

It then works out, once, the things that would cost too much to work out
while the game runs: how much open sky each spot sees, where the mountains
throw their shadows in the (fixed) sunlight, and where the water runs.

Writes, for scripts/island.gd and shaders/terrain.gdshader:
  terrain/island_height.bin   SIZE x SIZE heights in metres, 32-bit floats
  terrain/island_masks.bin    SIZE x SIZE x 4 bytes: open sky, sunlight,
                              running water, how hard the rock is
  terrain/island.json         the measures, the coastline and the waterfalls

Needs numpy, scipy and numba.   python3 tools/make_island.py [seed]
"""
import heapq
import json
import sys
from pathlib import Path

import numpy as np
from numba import njit
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "terrain"

SEED = int(sys.argv[1]) if len(sys.argv) > 1 else 1769
WORK = 512            # the grid the rivers are run on
SIZE = 1024           # the grid that is written
SPAN = 1024.0         # metres across
BASE_RADIUS = 300.0
PEAK = 168.0          # height of the highest summit
PLAIN_FROM = 0.84     # share of the way to the shore where the plain begins
SHIELD_FOOT = 0.90    # where the old volcano's flank met the plain
VENT = (120.0, 70.0)  # how broad the summits were
CUT = 0.018           # how fast the streams cut
AREA_POWER = 0.5      # how much faster a big stream cuts than a small one
CREEP = 0.02          # how fast soil creeps
ROUNDS = 25           # how long the rivers run, in tens of steps
PLAIN_HEIGHT = 10.0
COAST_SAMPLES = 180
SUN = (-0.730, 0.454, -0.511)   # toward the sun (scripts/atmosphere.gd)


def spectral_noise(rng, n, roughness):
    """Smooth random ground from filtered white noise; about -1..1."""
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spectrum = (rng.normal(size=(n, n)) + 1j * rng.normal(size=(n, n))) / f ** roughness
    spectrum[0, 0] = 0.0
    field = np.fft.ifft2(spectrum).real
    return field / np.abs(field).max()


def band_noise(rng, n, wavelength_px):
    """Random ground with features of about one size."""
    field = ndimage.gaussian_filter(rng.normal(size=(n, n)), wavelength_px / 2.5, mode="wrap")
    return field / np.abs(field).max()


def coast_radii(rng):
    a = np.arange(COAST_SAMPLES) * 2.0 * np.pi / COAST_SAMPLES
    r = np.full(COAST_SAMPLES, BASE_RADIUS)
    for k in range(1, 9):
        r += 62.0 / k ** 0.85 * rng.uniform(0.5, 1.0) * np.sin(k * a + rng.uniform(0, 2 * np.pi))
    return np.clip(r, 205.0, 395.0)


@njit(cache=True)
def run_rivers(h, uplift, hardness, land, steps, dt, cell, m_exp, creep):
    n = h.shape[0]
    count = n * n
    flat = h.ravel()
    area = np.zeros(count)
    recv = np.zeros(count, np.int64)
    dist = np.ones(count)
    for _ in range(steps):
        order = np.argsort(flat)
        for idx in range(count):
            i = idx // n
            j = idx % n
            recv[idx] = idx
            if not land[i, j]:
                continue
            best = 0.0
            for di in range(-1, 2):
                for dj in range(-1, 2):
                    if di == 0 and dj == 0:
                        continue
                    ii = i + di
                    jj = j + dj
                    if ii < 0 or jj < 0 or ii >= n or jj >= n:
                        continue
                    d = cell * np.sqrt(di * di + dj * dj)
                    s = (h[i, j] - h[ii, jj]) / d
                    if s > best:
                        best = s
                        recv[idx] = ii * n + jj
                        dist[idx] = d
        area[:] = cell * cell
        for k in range(count - 1, -1, -1):
            idx = order[k]
            if recv[idx] != idx:
                area[recv[idx]] += area[idx]
        for k in range(count):
            idx = order[k]
            i = idx // n
            j = idx % n
            if not land[i, j]:
                continue
            r = recv[idx]
            if r == idx:
                flat[idx] += uplift[i, j] * dt      # a hollow fills until it spills
                continue
            cut = hardness[i, j] * area[idx] ** m_exp * dt / dist[idx]
            flat[idx] = (flat[idx] + uplift[i, j] * dt + cut * flat[r]) / (1.0 + cut)
        # Soil creeps downhill, which rounds the sharpest edges a little.
        for i in range(1, n - 1):
            for j in range(1, n - 1):
                if land[i, j]:
                    lap = h[i - 1, j] + h[i + 1, j] + h[i, j - 1] + h[i, j + 1] - 4.0 * h[i, j]
                    h[i, j] += creep * lap
    return area.reshape(n, n), recv.copy()


@njit(cache=True)
def fill_hollows(h, land):
    """Raises every hollow just enough that water runs out of it to the sea."""
    n = h.shape[0]
    out = np.full((n, n), 1e9)
    heap = [(0.0, 0, 0)]
    heap.pop()
    for i in range(n):
        for j in range(n):
            if not land[i, j]:
                out[i, j] = h[i, j]
                edge = False
                for di, dj in ((0, 1), (1, 0), (0, -1), (-1, 0)):
                    ii = i + di
                    jj = j + dj
                    if 0 <= ii < n and 0 <= jj < n and land[ii, jj]:
                        edge = True
                if edge:
                    heapq.heappush(heap, (h[i, j], i, j))
    while len(heap) > 0:
        level, i, j = heapq.heappop(heap)
        for di, dj in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            ii = i + di
            jj = j + dj
            if 0 <= ii < n and 0 <= jj < n and land[ii, jj] and out[ii, jj] > 1e8:
                out[ii, jj] = max(h[ii, jj], level + 0.002)
                heapq.heappush(heap, (out[ii, jj], ii, jj))
    return out


@njit(cache=True)
def settle(h, land, cell, steepest, rounds):
    """Lets anything steeper than rock can stand slump down."""
    n = h.shape[0]
    for _ in range(rounds):
        for i in range(1, n - 1):
            for j in range(1, n - 1):
                if not land[i, j]:
                    continue
                for di, dj in ((0, 1), (1, 0), (0, -1), (-1, 0)):
                    drop = h[i, j] - h[i + di, j + dj] - steepest * cell
                    if drop > 0.0:
                        h[i, j] -= 0.25 * drop
                        if land[i + di, j + dj]:
                            h[i + di, j + dj] += 0.25 * drop
    return h


def shifted(field, dx, dy):
    return np.roll(np.roll(field, -dy, axis=0), -dx, axis=1)


def open_sky(h, cell):
    """How much of the sky each spot sees, 0..1, from how high the ground
    stands round about it."""
    total = np.zeros_like(h)
    directions = 16
    for d in range(directions):
        a = 2 * np.pi * d / directions
        horizon = np.zeros_like(h)
        for reach in (1, 2, 3, 5, 8, 12, 18, 26, 38, 55, 80, 115, 160):
            dx, dy = int(round(np.cos(a) * reach)), int(round(np.sin(a) * reach))
            if dx == 0 and dy == 0:
                continue
            rise = (shifted(h, dx, dy) - h) / (cell * np.hypot(dx, dy))
            horizon = np.maximum(horizon, rise)
        total += 1.0 - horizon / np.sqrt(1.0 + horizon * horizon)
    return total / directions


def sunlight(h, cell):
    """1 where the sun reaches, 0 in the shadow of higher ground."""
    flat = np.hypot(SUN[0], SUN[2])
    ux, uz = SUN[0] / flat, SUN[2] / flat
    climb = SUN[1] / flat
    over = np.full_like(h, -1e9)
    reach = 1.0
    while reach < 700.0:
        dx, dy = int(round(ux * reach / cell)), int(round(uz * reach / cell))
        blocker = shifted(h, dx, dy) - h - climb * cell * np.hypot(dx, dy)
        over = np.maximum(over, blocker / (cell * np.hypot(dx, dy)) ** 0.5)
        reach *= 1.06
        reach += 0.5
    return 1.0 - np.clip(over / 1.2 + 0.5, 0.0, 1.0)


def main():
    rng = np.random.default_rng(SEED)
    cell = SPAN / WORK
    axis = (np.arange(WORK) + 0.5) * cell - SPAN / 2
    x, z = np.meshgrid(axis, axis)
    radii = coast_radii(rng)
    angle = np.mod(np.arctan2(z, x), 2 * np.pi)
    shore = np.interp(angle, np.arange(COAST_SAMPLES + 1) * 2 * np.pi / COAST_SAMPLES,
                      np.append(radii, radii[0]))
    t = np.hypot(x, z) / shore
    land = t < 1.0

    # The old volcano before the rivers had their way: a broad shield with
    # a main summit and two lesser ones, its flanks sloping to the plain.
    def dome(cx, cz, width):
        return np.exp(-((x - cx) ** 2 + (z - cz) ** 2) / (2 * width * width))
    def at(bearing, share):
        return np.cos(bearing) * BASE_RADIUS * share, np.sin(bearing) * BASE_RADIUS * share
    # Summits stand in a broken ring round a sunken middle (the old crater,
    # breached on one side where its river got out), as on Tahiti.
    ring = [(2.2, 0.40, 1.0, 62.0), (3.6, 0.36, 0.78, 50.0), (5.2, 0.42, 0.9, 58.0),
            (0.6, 0.38, 0.7, 48.0), (4.4, 0.55, 0.55, 40.0), (1.3, 0.56, 0.5, 38.0)]
    vents = np.maximum.reduce([tall * dome(*at(bearing, share), width)
                               for bearing, share, tall, width in ring])
    shield = np.clip(1.0 - (t / SHIELD_FOOT) ** 2.2, 0.0, 1.0)
    lumps = 1.0 + 0.30 * band_noise(rng, WORK, 110) + 0.16 * band_noise(rng, WORK, 40)
    h = shield ** 0.7 * (0.38 + 0.62 * vents) * lumps
    crater = dome(*at(3.0, 0.05), 46.0) + 0.8 * dome(*at(-1.2, 0.22), 34.0)
    h *= 1.0 - 0.6 * np.clip(crater, 0.0, 1.0)
    h = 100.0 * h / h.max()
    h += (2.5 * spectral_noise(rng, WORK, 1.5) + 2.5) * shield ** 0.3
    h = np.where(land, h, 0.0)
    hardness = CUT * np.exp(0.8 * band_noise(rng, WORK, 45) + 0.4 * band_noise(rng, WORK, 12))
    uplift = np.zeros_like(h)
    area = None
    for _ in range(ROUNDS):
        h = fill_hollows(h, land)
        area, _ = run_rivers(h, uplift, hardness, land, 10, 1.0, cell, AREA_POWER, CREEP)
    h *= (PEAK - PLAIN_HEIGHT) / h.max()
    h = settle(h, land, cell, 1.5, 30)

    # --- the finer grid --------------------------------------------------
    grow = SIZE // WORK
    fine = SPAN / SIZE
    h = np.maximum(ndimage.zoom(h, grow, order=3, mode="nearest"), 0.0)
    water = ndimage.zoom(np.log10(area / (cell * cell)), grow, order=1, mode="nearest")
    rock = ndimage.zoom(hardness, grow, order=1, mode="nearest")
    axis = (np.arange(SIZE) + 0.5) * fine - SPAN / 2
    x, z = np.meshgrid(axis, axis)
    angle = np.mod(np.arctan2(z, x), 2 * np.pi)
    shore = np.interp(angle, np.arange(COAST_SAMPLES + 1) * 2 * np.pi / COAST_SAMPLES,
                      np.append(radii, radii[0]))
    t = np.hypot(x, z) / shore
    # Broken rock on the steep ground: gullies and ribs too small for the rivers.
    gy, gx = np.gradient(h, fine)
    steep = np.clip((np.hypot(gx, gy) - 0.45) / 0.8, 0.0, 1.0)
    ribs = 1.0 - np.abs(spectral_noise(rng, SIZE, 1.3))
    h += steep * (3.2 * (ribs - 0.6) + 1.0 * band_noise(rng, SIZE, 5))
    h += 0.25 * band_noise(rng, SIZE, 9) * np.clip(h / 6.0, 0.0, 1.0)
    h = np.maximum(h, 0.0)
    # The plain and the beach lie under it all; the seabed shelves away outside.
    inland = np.clip((1.0 - t) / (1.0 - PLAIN_FROM), 0.0, 1.0)
    lumps = 1.0 + 0.12 * band_noise(rng, SIZE, 14) * (1.0 - inland)
    plain = PLAIN_HEIGHT * inland ** 1.3 * lumps
    h = np.where(t < 1.0, h * np.clip((1.0 - t) / 0.12, 0.0, 1.0) + plain, -(t - 1.0) * 60.0)

    sky = open_sky(h, fine)
    sun = ndimage.gaussian_filter(sunlight(h, fine), 1.2)
    water = np.where(t < 1.0, water, 0.0)

    # --- waterfalls: the steepest stretches of the biggest streams --------
    falls = []
    gy, gx = np.gradient(h, fine)
    slope = np.hypot(gx, gy)
    score = np.where((water > 2.4) & (slope > 0.9) & (h > 25.0), water * slope, 0.0)
    for _ in range(5):
        i, j = np.unravel_index(score.argmax(), score.shape)
        if score[i, j] <= 0.0:
            break
        path = []
        ci, cj = i, j
        for _ in range(4):                       # a little way back up the stream
            window = h[ci - 2:ci + 3, cj - 2:cj + 3] * (water[ci - 2:ci + 3, cj - 2:cj + 3] > 2.2)
            di, dj = np.unravel_index(window.argmax(), window.shape)
            if window[di, dj] <= h[ci, cj]:
                break
            ci, cj = ci - 2 + di, cj - 2 + dj
        for _ in range(60):                      # and down to where it levels out
            path.append([float(axis[cj]), float(h[ci, cj]), float(axis[ci])])
            window = h[ci - 2:ci + 3, cj - 2:cj + 3]
            di, dj = np.unravel_index(window.argmin(), window.shape)
            if window[di, dj] >= h[ci, cj] - 0.2:
                break
            drop = (h[ci, cj] - window[di, dj]) / (fine * max(np.hypot(di - 2, dj - 2), 1.0))
            ci, cj = ci - 2 + di, cj - 2 + dj
            if drop < 0.35 and len(path) > 6:
                break
        if len(path) > 5 and path[0][1] - path[-1][1] > 12.0:
            falls.append(path)
        ii, jj = np.ogrid[:SIZE, :SIZE]
        score[(ii - i) ** 2 + (jj - j) ** 2 < 90 ** 2] = 0.0

    low, high = float(h.min()), float(h.max())
    OUT.mkdir(exist_ok=True)
    h.astype("<f4").tofile(OUT / "island_height.bin")
    masks = np.stack([
        np.clip(sky, 0.0, 1.0), np.clip(sun, 0.0, 1.0),
        np.clip(water / 4.5, 0.0, 1.0), np.clip(rock / 1.2, 0.0, 1.0)], axis=-1)
    (masks * 255.0 + 0.5).astype(np.uint8).tofile(OUT / "island_masks.bin")
    (OUT / "island.json").write_text(json.dumps({
        "seed": SEED, "size": SIZE, "span": SPAN, "lowest": low, "highest": high,
        "plain_from": PLAIN_FROM, "coast": [round(float(r), 2) for r in radii],
        "waterfalls": [[[round(v, 2) for v in p] for p in path] for path in falls],
    }))
    print("island: heights %.1f..%.1f m, %d waterfalls" % (low, high, len(falls)))


if __name__ == "__main__":
    main()
