"""Floor I, the Great Court: the balcony round the north half of the drum
(y = 7) and the stair kit that climbs to it, in the court's style: smooth
Portland parapet walls with a moulded cap and a brass handrail (the British
Museum's stairs round the Reading Room have solid white balustrades), pale
limestone steps.

  court_balcony_seg       22.5 degrees of the balcony ring (place like the
                          drum segments: origin = drum centre, rotation.y =
                          k * 22.5, k = -4 .. 4 for the north half): the
                          slab from the drum face (apothem 12.26) out to the
                          16.5 m apothem, walking surface "tile:limestone_court"
                          at y = 7.0, panelled soffit at 6.6, entablature
                          fascia on the outer edge, solid parapet 1.05 m.
  court_balcony_seg_open  the same without the parapet (where a stair lands).
  court_parapet_2m / _1m  straight solid parapet, origin = centre of its base
                          on the walking surface, runs along X, 0.32 thick
                          (balcony ends, stair landings).
  court_stair_step        one limestone step 3 m wide (riser 7 / 47 =
                          0.149 m, tread 0.40 m) in the frame of
                          StairsSpec.frame(): origin = bottom of the riser,
                          middle; -Z (Godot) up the flight; step i at
                          (0, i * rise, -i * 0.4). Scale X for other widths.
  court_stair_parapet_4m  raked solid parapet for 4 m of run (10 treads,
                          1.49 m of rise) with cap and handrails on both
                          faces; same frame, centred 0.16 m outside the
                          flight's side plane; one per 10 steps at
                          (x, 1.49 k, -4 k).
  court_stair_mass        unit wedge under the steps (tile field
                          "tile:portland_ashlar"): scale to (width, total
                          rise, run), like stair_wedge.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import court as C
from artlib import court_materials as CM
from artlib import materials as M
from artlib.archkit import kit, orient_out
from artlib.geo import Part

RISE, TREAD = 7.0 / 47, 0.40
SLOPE = RISE / TREAD
DEPTH = 16.5 - C.A_OUT            # balcony depth from the drum face (4.24)
TOP = C.BALCONY                   # walking surface 7.0
WALL_T = 0.32
WALL_H = 1.05


def parapet_profile(z0, height=WALL_H, t=WALL_T):
    """Section (y, z) of the solid parapet: plinth band, smooth wall, cap
    moulding overhanging both faces; y from 0 (outer face) inward to t."""
    h = height
    return [(0.0, z0), (0.0, z0 + 0.12), (0.02, z0 + 0.14), (0.02, z0 + h - 0.12), (-0.03, z0 + h - 0.08),
            (-0.05, z0 + h - 0.02), (-0.05, z0 + h), (t / 2, z0 + h + 0.05), (t + 0.05, z0 + h),
            (t + 0.05, z0 + h - 0.02), (t + 0.03, z0 + h - 0.08), (t - 0.02, z0 + h - 0.12), (t - 0.02, z0 + 0.14),
            (t, z0 + 0.12), (t, z0)]


def balcony_seg(open_side=False):
    p = Part("court_balcony_seg_open" if open_side else "court_balcony_seg")
    H = C.HALF
    D = DEPTH
    # walking surface (world-mapped floor tile) and soffit
    C.quad(p, [(-H, 0.0, TOP), (H, 0.0, TOP), (H, -D, TOP), (-H, -D, TOP)], "floor", (0, 0, 1))
    C.quad(p, [(-H, 0.0, TOP - 0.4), (H, 0.0, TOP - 0.4), (H, -D + 0.12, TOP - 0.4), (-H, -D + 0.12, TOP - 0.4)],
           "soffit", (0, 0, -1))
    # fascia on the outer edge: architrave, frieze, cornice lip (0.8 tall)
    z = TOP - 0.8
    prof = [(-D + 0.12, z + 0.4), (-D + 0.12, z + 0.06), (-D, z), (-D - 0.08, z), (-D - 0.08, z + 0.16),
            (-D - 0.1, z + 0.18), (-D - 0.1, z + 0.36), (-D - 0.06, z + 0.4), (-D - 0.06, z + 0.66),
            (-D - 0.14, z + 0.7), (-D - 0.18, z + 0.76), (-D - 0.18, z + 0.8), (-D + 0.1, z + 0.8)]
    p.extrude(prof, -H, H, "portland", caps=False)
    # guttae under the fascia
    n = int(round(2 * H / 0.55))
    for k in range(n):
        x = -H + (k + 0.5) * 2 * H / n
        p.box((x, -D - 0.04, z - 0.03), (0.12, 0.07, 0.06), "portland", bevel=0.01)
    if not open_side:
        # parapet on the outer edge (outer face flush with the fascia line)
        prof = [(-D - 0.02 + y, zz) for y, zz in parapet_profile(TOP)]
        faces = p.extrude([(y, zz) for y, zz in prof], -H, H, "parapet", caps=False)
        orient_out(faces, (0.0, -D + WALL_T / 2 - 0.02, TOP + 0.5))
        # brass handrail on the inner face, on short brackets
        p.tube([(-H, -D + WALL_T + 0.08, TOP + 0.88), (H, -D + WALL_T + 0.08, TOP + 0.88)], 0.025, "brass", sides=8,
               caps=False)
        for x in (-H * 0.5, H * 0.5):
            p.box((x, -D + WALL_T + 0.04, TOP + 0.84), (0.03, 0.09, 0.03), "brass")
    C.drop_end_faces(p)
    C.wedge(p)
    return p


def _soffit(ctx):
    """Portland soffit with two sunk panels per segment (painted)."""
    s = CM.portland(ctx)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    r = np.hypot(x, y)
    a = np.arctan2(x, y)
    tx = ctx.texel
    d = r - C.A_OUT
    panel = (d > 0.5) & (d < DEPTH - 0.5) & (np.abs(a) < C.ALPHA - 0.04)
    rim = panel & ((np.abs(d - 0.5) < tx * 1.5) | (np.abs(d - (DEPTH - 0.5)) < tx * 1.5)
                   | (np.abs(np.abs(a) - (C.ALPHA - 0.04)) * r < tx * 1.5))
    s.shade = np.where(panel, s.shade - 0.8, s.shade)
    s.shade = np.where(rim, s.shade - 1.5, s.shade)
    return s


def _parapet(ctx):
    s = CM.portland(ctx, center=7.0)
    return s


BALC_FNS = {"soffit": _soffit, "portland": CM.portland, "parapet": _parapet, "brass": M.brass}
BALC_KINDS = {"floor": "tile:limestone_court"}


# --------------------------------------------------------------------------
# straight parapets
# --------------------------------------------------------------------------

def parapet(W):
    p = Part(f"court_parapet_{'2m' if W == 2.0 else '1m'}")
    prof = [(y - WALL_T / 2, z) for y, z in parapet_profile(0.0)]
    faces = p.extrude(prof, -W / 2, W / 2, "parapet", caps=True)
    orient_out(faces, (0.0, 0.0, 0.5))
    for sy in (-1, 1):
        p.tube([(-W / 2, sy * (WALL_T / 2 + 0.08), 0.88), (W / 2, sy * (WALL_T / 2 + 0.08), 0.88)], 0.025, "brass",
               sides=8, caps=False)
        p.box((0.0, sy * (WALL_T / 2 + 0.04), 0.84), (0.03, 0.09, 0.03), "brass")
    return p


# --------------------------------------------------------------------------
# stairs (StairsSpec.frame: Blender +Y = up the flight, built final)
# --------------------------------------------------------------------------

def step(W=3.0):
    p = Part("court_stair_step")
    r = RISE
    prof = [(0.0, 0.0), (0.0, r - 0.03), (-0.01, r - 0.025), (-0.025, r - 0.015), (-0.03, r - 0.005),
            (-0.025, r), (TREAD, r)]
    p.extrude(prof, -W / 2, W / 2, "step", caps=True)
    return p


def stair_parapet(L=4.0):
    p = Part("court_stair_parapet_4m")
    top = 0.25
    prof = [(y - WALL_T / 2, z) for y, z in parapet_profile(-0.45, height=WALL_H + 0.45)]
    faces = p.extrude([(y, z + top) for y, z in prof], 0.0, L, "parapet", caps=False)
    orient_out(faces, (L / 2, 0.0, 0.6))
    # run along +Y and rake
    p.move(faces, Matrix.Rotation(math.radians(90), 4, 'Z'))
    for v in {v for f in faces for v in f.verts}:
        v.co.z += SLOPE * v.co.y
    for sx in (-1, 1):
        rail = p.tube([(sx * (WALL_T / 2 + 0.08), 0.0, top + 0.88), (sx * (WALL_T / 2 + 0.08), L, top + 0.88 + SLOPE * L)],
                      0.025, "brass", sides=8, caps=False)
        for yb in (L * 0.25, L * 0.75):
            p.box((sx * (WALL_T / 2 + 0.04), yb, top + 0.84 + SLOPE * yb), (0.09, 0.03, 0.03), "brass")
    return p


def mass():
    p = Part("court_stair_mass")
    a, b = -0.5, 0.5
    pts = {"f0": (a, 0.0, 0.0), "f1": (b, 0.0, 0.0), "b0": (a, 1.0, 0.0), "b1": (b, 1.0, 0.0),
           "t0": (a, 1.0, 1.0), "t1": (b, 1.0, 1.0)}
    for keys, want in ((["f0", "f1", "t1", "t0"], (0, -0.7, 0.7)), (["b0", "t0", "t1", "b1"], (0, 1, 0)),
                       (["f0", "t0", "b0"], (-1, 0, 0)), (["f1", "b1", "t1"], (1, 0, 0))):
        f = p.poly([pts[k] for k in keys], "field")[0]
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()
    return p


def _step(ctx):
    s = A.limestone(ctx, center=7.0)
    # worn nosing: the front edge polished
    s.rough = np.where(ctx.edge_soft(3.0) > 0.2, 0.35, s.rough)
    return s


def build():
    out = [
        kit("court_balcony_seg", [balcony_seg(False)], BALC_FNS, kinds=BALC_KINDS, built_final=True, ppm=64,
            ground=None, ao_dist=0.4, preview_yaws=(0.0, 30.0, 160.0, 200.0), preview_elevation=12.0),
        kit("court_balcony_seg_open", [balcony_seg(True)], BALC_FNS, kinds=BALC_KINDS, built_final=True, ppm=64,
            ground=None, ao_dist=0.4, preview=False),
        kit("court_parapet_2m", [parapet(2.0)], {"parapet": _parapet, "brass": M.brass}, ppm=64, ao_dist=0.2),
        kit("court_parapet_1m", [parapet(1.0)], {"parapet": _parapet, "brass": M.brass}, ppm=64, ao_dist=0.2,
            preview=False),
        kit("court_stair_step", [step()], {"step": _step}, built_final=True, ppm=64, ao_dist=0.2),
        kit("court_stair_parapet_4m", [stair_parapet()], {"parapet": _parapet, "brass": M.brass}, built_final=True,
            ppm=64, ground=None, ao_dist=0.2),
        kit("court_stair_mass", [mass()], {}, kinds={"field": "tile:portland_ashlar"}, built_final=True,
            preview=False),
    ]
    return out
