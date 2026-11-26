#!/usr/bin/env python3
"""Reshapes the modelled hull so that it fits the ship the game is built on.

The hull that came from the modelling service (models/source/hull.glb) is a
handsome thing, but its decks, rails and breaks are not where the game's ship
has hers (scripts/ship_layout.gd), and her waist is far too deep to see over.
This reads it, moves every point so that

  * the forecastle and quarterdeck breaks fall where the ship's do,
  * the three decks lie flat at the ship's deck heights (a finger above the
    code-built decks, which stay underneath as the floor that is walked on),
  * her sides stand at least as high as ShipLayout.rail_y everywhere (what
    stands higher is cut off at the rail by shaders/hull_shell.gdshader, so
    her sheer lines outside stay fair),
  * the inner face of the bulwark stands just inboard of the ship's side,

and writes models/ship/hull_fitted.glb in the ship's own measure: metres,
x to starboard, y up, z aft. Run it again whenever ship_layout.gd changes:

    python3 tools/fit_hull.py

Needs numpy. The numbers under "the ship" must match ship_layout.gd.
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "models/source/hull.glb"
FITTED = ROOT / "models/ship/hull_fitted.glb"

# --- the ship (scripts/ship_layout.gd) -------------------------------------
LENGTH, BOW_Z, STERN_Z, HALF_BEAM = 31.0, -16.0, 15.0, 4.0
WAIST_Y, FORECASTLE_Y, QUARTERDECK_Y = 3.15, 4.05, 5.25
FORECASTLE_BREAK_Z, QUARTERDECK_BREAK_Z = -7.5, 4.0
BULWARK = 1.05

# --- the model, as measured ------------------------------------------------
# It lies along its own x, bow toward -x, and is about 1.9 long.
KEEL_M = -0.2744
BREAK_FORE_M, BREAK_AFT_M = -0.407, 0.478     # where its decks step
# Along her length: model x -> ship z.
LENGTH_KNOTS_M = [-0.951, -0.795, BREAK_FORE_M, BREAK_AFT_M, 0.928, 0.951]
LENGTH_KNOTS_Z = [-16.3, -14.4, FORECASTLE_BREAK_Z, QUARTERDECK_BREAK_Z, 14.75, 15.3]
KEEL_Y = -1.71
DECK_LIFT = 0.02       # the modelled deck lies this far above the built one
RAIL_LIFT = 0.08      # her sides are fitted to stand this far above the rail, at least
SIDE_INSET = 0.30      # inner face of the bulwark, inboard of half_breadth
SIDE_THICK = 0.40
BULGE = 0.25           # how far the fullest part of the hull stands out beyond that
PLAIN_BEAM = 14.6      # metres per unit where the model has no bulwark to go by
STATIONS = 121


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def half_breadth(z):
    u = np.clip((z - BOW_Z) / LENGTH, 0.0, 1.0)
    bow = 1.0 - (1.0 - np.clip(u / 0.3, 0.0, 1.0)) ** 2.2
    stern = 1.0 - 0.22 * np.clip((u - 0.78) / 0.22, 0.0, 1.0) ** 2.0
    return HALF_BEAM * bow * stern


def deck_top(z):
    fore = 1.0 - smoothstep(FORECASTLE_BREAK_Z - 0.12, FORECASTLE_BREAK_Z + 0.12, z)
    aft = smoothstep(QUARTERDECK_BREAK_Z - 0.12, QUARTERDECK_BREAK_Z + 0.12, z)
    return WAIST_Y + (FORECASTLE_Y - WAIST_Y) * fore + (QUARTERDECK_Y - WAIST_Y) * aft


def rail_y(z):
    u = np.clip((z - BOW_Z) / LENGTH, 0.0, 1.0)
    return deck_top(z) + BULWARK + 0.45 * (np.abs(u - 0.5) * 2.0) ** 2.0


def read_glb(path):
    raw = path.read_bytes()
    json_len = struct.unpack("<I", raw[12:16])[0]
    doc = json.loads(raw[20:20 + json_len])
    binary = bytearray(raw[20 + json_len + 8:])
    return doc, binary


def view(doc, binary, accessor, dtype, width):
    acc = doc["accessors"][accessor]
    bv = doc["bufferViews"][acc["bufferView"]]
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    parts = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[acc["type"]]
    return np.frombuffer(binary, dtype=dtype, count=acc["count"] * parts,
                         offset=start).reshape(-1, width), start


def write_glb(path, doc, binary):
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    binary = bytes(binary) + b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    with open(path, "wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, total))
        out.write(struct.pack("<I4s", len(text), b"JSON"))
        out.write(text)
        out.write(struct.pack("<I4s", len(binary), b"BIN\0"))
        out.write(binary)


def scatter(points, tris, count, seed=1):
    """Points spread evenly over the surface, with the face normal at each."""
    rng = np.random.default_rng(seed)
    a, b, c = points[tris[:, 0]], points[tris[:, 1]], points[tris[:, 2]]
    normal = np.cross(b - a, c - a)
    area = np.linalg.norm(normal, axis=1)
    normal /= np.maximum(area, 1e-12)[:, None]
    pick = rng.choice(len(tris), count, p=area / area.sum())
    r1, r2 = np.sqrt(rng.random(count)), rng.random(count)
    w = np.stack([1 - r1, r1 * (1 - r2), r1 * r2], 1)
    return (points[tris[pick]] * w[:, :, None]).sum(1), normal[pick]


def fill(values):
    """Fills the gaps in a profile from its neighbours and takes out the jitter."""
    idx = np.arange(len(values))
    good = ~np.isnan(values)
    filled = np.interp(idx, idx[good], values[good])
    padded = np.pad(filled, 2, mode="edge")
    return np.median(np.stack([padded[i:i + len(values)] for i in range(5)]), axis=0)


class Profile:
    """What the model measures at each station along its length."""

    def __init__(self, points, tris):
        pts, nrm = scatter(points, tris, 3_000_000)
        x, y, z = pts.T
        wide = np.abs(z)
        inward = -nrm[:, 2] * np.sign(z)
        self.xs = np.linspace(-0.95, 0.95, STATIONS)
        half = 0.5 * (self.xs[1] - self.xs[0])
        n = STATIONS
        deck, rail, inner, outer, widest = (np.full(n, np.nan) for _ in range(5))
        for s, at in enumerate(self.xs):
            here = np.abs(x - at) < half
            widest[s] = wide[here].max()
            floor = here & (nrm[:, 1] > 0.85) & (wide < 0.10) & (y > -0.12)
            if floor.sum() > 200:
                counts, edges = np.histogram(y[floor], bins=80, range=(-0.12, 0.28))
                level = edges[counts.argmax()] + 0.0025
                deck[s] = np.median(y[floor & (np.abs(y - level) < 0.01)])
            else:
                continue
            side = here & (y > deck[s] + 0.03) & (wide > 0.08)
            faces_in = side & (inward > 0.6)
            faces_out = side & (inward < -0.6)
            if faces_in.sum() > 40 and faces_out.sum() > 40:
                inner[s] = np.median(wide[faces_in])
                outer[s] = np.percentile(wide[faces_out], 70)
                top = here & (nrm[:, 1] > 0.8) & (y > deck[s] + 0.03) \
                    & (wide > inner[s] - 0.006) & (wide < outer[s] + 0.01)
                if top.sum() > 50:
                    rail[s] = np.median(y[top])
        self.has_side = fill(np.where(np.isnan(inner), 0.0, 1.0))
        self.widest = fill(widest)
        self.inner = fill(inner)
        self.outer = np.maximum(fill(outer), self.inner + 0.01)
        self.rail = fill(rail)
        # Each deck is taken as one level surface per station, by region.
        fore = self.xs < BREAK_FORE_M
        aft = self.xs > BREAK_AFT_M
        mid = ~fore & ~aft
        self.deck = np.empty(n)
        for part in (fore, mid, aft):
            self.deck[part] = fill(deck[part])
        self.rail = np.maximum(self.rail, self.deck + 0.03)
        # How much taller the outside must be drawn, station by station, for
        # her side to reach the ship's rail; then eased out along her length
        # so that wales and planking run fair.
        ship_z = np.interp(self.xs, LENGTH_KNOTS_M, LENGTH_KNOTS_Z)
        need = (rail_y(ship_z) + RAIL_LIFT - KEEL_Y) / (self.rail - KEEL_M)
        reach = np.arange(-40, 41)
        bell = np.exp(-0.5 * (reach / 12.0) ** 2)
        eased = np.convolve(np.pad(need, 40, mode="edge"), bell / bell.sum(), mode="valid")
        self.rise = eased * min(1.08, float(np.max(need / eased)))

    def at(self, values, x):
        return np.interp(x, self.xs, values)

    def deck_at(self, x):
        out = np.empty_like(x)
        fore = x < BREAK_FORE_M
        aft = x > BREAK_AFT_M
        mid = ~fore & ~aft
        for part, keep in ((fore, self.xs < BREAK_FORE_M), (aft, self.xs > BREAK_AFT_M),
                           (mid, (self.xs >= BREAK_FORE_M) & (self.xs <= BREAK_AFT_M))):
            out[part] = np.interp(x[part], self.xs[keep], self.deck[keep])
        return out


def deck_level(x):
    return np.where(x < BREAK_FORE_M, FORECASTLE_Y,
                    np.where(x > BREAK_AFT_M, QUARTERDECK_Y, WAIST_Y)) + DECK_LIFT


def fit(profile, points, normals):
    """Moves model points (and their normals) into the ship's measure."""
    x, y, z = points.T
    wide = np.abs(z)
    ship_z = np.interp(x, LENGTH_KNOTS_M, LENGTH_KNOTS_Z)
    seg = np.clip(np.searchsorted(LENGTH_KNOTS_M, x) - 1, 0, len(LENGTH_KNOTS_M) - 2)
    km, kz = np.array(LENGTH_KNOTS_M), np.array(LENGTH_KNOTS_Z)
    along = (kz[seg + 1] - kz[seg]) / (km[seg + 1] - km[seg])

    inner = profile.at(profile.inner, x)
    outer = profile.at(profile.outer, x)
    widest = np.maximum(profile.at(profile.widest, x), outer + 0.004)
    rail = profile.at(profile.rail, x)
    deck = profile.deck_at(x)
    sided = profile.at(profile.has_side, x)
    rise = profile.at(profile.rise, x)

    # Across: the inner face of the bulwark goes to the ship's side.
    side_in = np.maximum(half_breadth(ship_z) - SIDE_INSET, 0.3)
    side_out = side_in + SIDE_THICK
    in_scale = side_in / inner
    wall_scale = SIDE_THICK / (outer - inner)
    bulge_scale = BULGE / (widest - outer)
    across = np.where(wide <= inner, wide * in_scale,
                      np.where(wide <= outer, side_in + (wide - inner) * wall_scale,
                               side_out + (wide - outer) * bulge_scale))
    across_scale = np.where(wide <= inner, in_scale,
                            np.where(wide <= outer, wall_scale, bulge_scale))
    across = sided * across + (1.0 - sided) * wide * PLAIN_BEAM
    across_scale = sided * across_scale + (1.0 - sided) * PLAIN_BEAM
    outside = np.clip((wide - inner) / (outer - inner), 0.0, 1.0)
    outside = sided * outside + (1.0 - sided)

    # Up: outside, keel to rail in one run; inside, keel to deck to rail.
    top = rail_y(ship_z) + RAIL_LIFT
    level = deck_level(x)
    out_scale = rise
    up_out = KEEL_Y + (y - KEEL_M) * out_scale
    below = (level - KEEL_Y) / (deck - KEEL_M)
    above = np.maximum(rise, (top - level) / (rail - deck))
    up_in = np.where(y < deck, KEEL_Y + (y - KEEL_M) * below, level + (y - deck) * above)
    in_scale_up = np.where(y < deck, below, above)
    up = up_in + (up_out - up_in) * outside
    up_scale = in_scale_up + (out_scale - in_scale_up) * outside

    # The decks themselves are laid dead flat.
    on_deck = (normals[:, 1] > 0.7) & (np.abs(y - deck) < 0.03) & (wide < inner + 0.004) \
        & (wide < widest - 0.02)
    up = np.where(on_deck, level, up)

    fitted = np.stack([-np.sign(z) * across, up, ship_z], 1)
    turned = np.stack([-normals[:, 2] / across_scale, normals[:, 1] / up_scale,
                       normals[:, 0] / along], 1)
    turned[on_deck] = (0.0, 1.0, 0.0)
    turned /= np.maximum(np.linalg.norm(turned, axis=1), 1e-9)[:, None]
    return fitted, turned


def main():
    doc, binary = read_glb(SOURCE)
    prim = doc["meshes"][0]["primitives"][0]
    points, at_points = view(doc, binary, prim["attributes"]["POSITION"], "<f4", 3)
    normals, at_normals = view(doc, binary, prim["attributes"]["NORMAL"], "<f4", 3)
    tris, _ = view(doc, binary, prim["indices"], "<u4", 3)
    points = points.astype(np.float64)
    normals = normals.astype(np.float64)

    profile = Profile(points, tris)
    fitted, turned = fit(profile, points, normals)

    binary[at_points:at_points + fitted.size * 4] = fitted.astype("<f4").tobytes()
    binary[at_normals:at_normals + turned.size * 4] = turned.astype("<f4").tobytes()
    acc = doc["accessors"][prim["attributes"]["POSITION"]]
    acc["min"] = [float(v) for v in fitted.astype(np.float32).min(0)]
    acc["max"] = [float(v) for v in fitted.astype(np.float32).max(0)]
    nacc = doc["accessors"][prim["attributes"]["NORMAL"]]
    nacc.pop("min", None)
    nacc.pop("max", None)
    write_glb(FITTED, doc, binary)
    print("wrote", FITTED.relative_to(ROOT), "bounds", acc["min"], acc["max"])
    return profile


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
