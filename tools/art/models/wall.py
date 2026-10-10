"""Modular gallery wall, 6 m high, decorated side facing -Y (Godot +Z), wall
plane at y = 0, module spans x = 0..W. Stack modules side by side; inner room
corners work because the mouldings simply interpenetrate (a natural mitre).

  z 0.00-0.20   dark marble skirting with a small cap
  z 0.24-1.12   walnut wainscot: rails, stiles every metre, chunky raised panels
  z 1.12-1.21   chair rail
  z 1.21-5.08   silk damask wallpaper
  z 5.06-5.11   picture rail
  z 5.11-5.40   plaster frieze
  z 5.40-6.00   plaster cornice with a dentil course

Variants: wall_4m, wall_2m and wall_window_4m (arched opening 2 x 3.5 m with
a 0.5 m deep plaster reveal, architrave, keystone and a stone sill; the iron
window itself is the separate model "window").
"""
import math
import zlib

from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

H = 6.0
PAPER0 = 1.21
PAPER1 = 5.08
SILL = 1.30
SPRING = 3.8
RADIUS = 1.0
DEPTH = 0.5

FNS = {
    "marble_dark": M.marble_dark,
    "wood_dark": M.wood_dark,
    "wallpaper": M.wallpaper,
    "plaster": M.plaster,
}


def _facing(p, pts, mat, want):
    """Polygon whose normal is flipped to point along ``want`` (x, y, z)."""
    f = p.poly(pts, mat)[0]
    f.normal_update()
    if f.normal.dot(want) < 0:
        f.normal_flip()
    return f


def _lower(p, W):
    # skirting + cap
    p.box((W / 2, -0.018, 0.1), (W, 0.036, 0.2), "marble_dark", bevel=0.006)
    p.extrude([(0.0, 0.2), (-0.048, 0.2), (-0.048, 0.215), (-0.034, 0.24), (0.0, 0.24)], 0.0, W, "marble_dark", caps=False)
    # wainscot ground, rails and stiles
    p.box((W / 2, -0.01, 0.68), (W, 0.02, 0.88), "wood_dark")
    p.box((W / 2, -0.029, 0.285), (W, 0.018, 0.09), "wood_dark", bevel=0.005)
    p.box((W / 2, -0.029, 1.07), (W, 0.018, 0.1), "wood_dark", bevel=0.005)
    n = int(round(W))
    for k in range(n + 1):
        x0 = max(0.0, k - 0.06)
        x1 = min(W, k + 0.06)
        p.box(((x0 + x1) / 2, -0.029, 0.675), (x1 - x0, 0.018, 0.69), "wood_dark", bevel=0.004)
    for k in range(n):
        p.box((k + 0.5, -0.03, 0.675), (0.78, 0.024, 0.6), "wood_dark", bevel=0.02)
    # chair rail
    p.extrude([(0.0, 1.12), (-0.05, 1.12), (-0.062, 1.14), (-0.062, 1.17), (-0.046, 1.195), (-0.02, 1.21), (0.0, 1.21)],
              0.0, W, "wood_dark", caps=False)


def _upper(p, W):
    # picture rail, frieze, cornice with dentils
    p.extrude([(0.0, 5.06), (-0.03, 5.06), (-0.042, 5.08), (-0.03, 5.11), (0.0, 5.11)], 0.0, W, "wood_dark", caps=False)
    _facing(p, [(0, 0, 5.11), (W, 0, 5.11), (W, 0, 5.4), (0, 0, 5.4)], "plaster", (0, -1, 0))
    prof = [(0.0, 5.40), (-0.035, 5.40), (-0.035, 5.46), (-0.075, 5.48), (-0.075, 5.53), (-0.115, 5.55),
            (-0.115, 5.63), (-0.14, 5.645), (-0.2, 5.7), (-0.26, 5.77), (-0.31, 5.86), (-0.35, 5.89),
            (-0.35, 5.95), (-0.385, 5.965), (-0.385, 6.0), (0.0, 6.0)]
    p.extrude(prof, 0.0, W, "plaster", caps=False)
    k = 0
    x = 0.05
    while x < W - 0.02:
        p.box((x, -0.135, 5.59), (0.05, 0.04, 0.07), "plaster", bevel=0.006)
        x += 0.1
        k += 1


def _paper(p, W):
    _facing(p, [(0, 0, PAPER0), (W, 0, PAPER0), (W, 0, PAPER1), (0, 0, PAPER1)], "wallpaper", (0, -1, 0))


def _paper_with_arch(p, W):
    ox0, ox1 = W / 2 - RADIUS, W / 2 + RADIUS
    cx = W / 2
    _facing(p, [(0, 0, PAPER0), (ox0, 0, PAPER0), (ox0, 0, PAPER1), (0, 0, PAPER1)], "wallpaper", (0, -1, 0))
    _facing(p, [(ox1, 0, PAPER0), (W, 0, PAPER0), (W, 0, PAPER1), (ox1, 0, PAPER1)], "wallpaper", (0, -1, 0))
    _facing(p, [(ox0, 0, PAPER0), (ox1, 0, PAPER0), (ox1, 0, SILL), (ox0, 0, SILL)], "wallpaper", (0, -1, 0))
    # spandrels: fan between the arch and the rectangle above the springing line
    top = PAPER1
    corner = math.atan2(top - SPRING, RADIUS)
    angles = sorted(set([i * math.pi / 16 for i in range(17)] + [corner, math.pi - corner]))
    def boundary(a):
        dx, dz = math.cos(a), math.sin(a)
        ts = []
        if dx > 1e-9:
            ts.append(RADIUS / dx)
        if dx < -1e-9:
            ts.append(-RADIUS / dx)
        if dz > 1e-9:
            ts.append((top - SPRING) / dz)
        t = min(ts)
        return (cx + dx * t, 0.0, SPRING + dz * t)
    for a0, a1 in zip(angles[:-1], angles[1:]):
        A0 = (cx + RADIUS * math.cos(a0), 0.0, SPRING + RADIUS * math.sin(a0))
        A1 = (cx + RADIUS * math.cos(a1), 0.0, SPRING + RADIUS * math.sin(a1))
        B0, B1 = boundary(a0), boundary(a1)
        pts = [A0, A1, B1, B0]
        if abs(B0[0] - B1[0]) > 1e-6 and abs(B0[2] - B1[2]) > 1e-6:
            # the fan crosses a rectangle corner: add it
            c = (ox1 if a0 < math.pi / 2 else ox0, 0.0, top)
            pts = [A0, A1, B1, c, B0]
        _facing(p, pts, "wallpaper", (0, -1, 0))
    return angles


def _opening(p, W):
    ox0, ox1 = W / 2 - RADIUS, W / 2 + RADIUS
    cx = W / 2
    # reveal: jambs and arched soffit (plaster)
    _facing(p, [(ox0, 0, SILL), (ox0, DEPTH, SILL), (ox0, DEPTH, SPRING), (ox0, 0, SPRING)], "plaster", (1, 0, 0))
    _facing(p, [(ox1, 0, SILL), (ox1, DEPTH, SILL), (ox1, DEPTH, SPRING), (ox1, 0, SPRING)], "plaster", (-1, 0, 0))
    n = 16
    for i in range(n):
        a0 = i * math.pi / n
        a1 = (i + 1) * math.pi / n
        P0 = (cx + RADIUS * math.cos(a0), SPRING + RADIUS * math.sin(a0))
        P1 = (cx + RADIUS * math.cos(a1), SPRING + RADIUS * math.sin(a1))
        mid = (a0 + a1) / 2
        _facing(p, [(P0[0], 0, P0[1]), (P1[0], 0, P1[1]), (P1[0], DEPTH, P1[1]), (P0[0], DEPTH, P0[1])],
                "plaster", (-math.cos(mid), 0, -math.sin(mid)))
    # stone sill projecting into the room
    p.box((cx, (DEPTH - 0.09) / 2, SILL - 0.045), (2 * RADIUS + 0.2, DEPTH + 0.09, 0.09), "marble_dark", bevel=0.012)
    # architrave following the opening, and a keystone
    path = [(ox0, SILL), (ox0, SPRING)]
    for i in range(1, 16):
        a = math.pi - i * math.pi / 16
        path.append((cx + RADIUS * math.cos(a), SPRING + RADIUS * math.sin(a)))
    path += [(ox1, SPRING), (ox1, SILL)]
    prof = [(0.0, 0.0), (0.04, 0.0), (0.04, 0.03), (0.055, 0.05), (0.055, 0.1), (0.035, 0.13), (0.0, 0.13)]
    p.sweep(prof, path, "plaster")
    p.box((cx, -0.05, SPRING + RADIUS + 0.08), (0.2, 0.1, 0.3), "plaster", bevel=0.012)


def _module(name, W, window=False):
    p = Part(name)
    _lower(p, W)
    if window:
        _paper_with_arch(p, W)
        _opening(p, W)
    else:
        _paper(p, W)
    _upper(p, W)
    # zlib.crc32, not hash(): Python randomises str hashes per process
    return Model(name, [p], FNS, ppm=64, ground=0.0, ao_dist=0.5, seed=zlib.crc32(name.encode()) % 97)


def build():
    return [_module("wall_4m", 4.0), _module("wall_2m", 2.0), _module("wall_window_4m", 4.0, window=True)]
