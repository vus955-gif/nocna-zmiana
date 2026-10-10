"""Lobby kit, main hall: the horizontal limestone bands of the hall walls,
in 4 / 2 / 1 / 0.5 m run modules (x = -W/2 .. W/2, wall plane z = 0, the
mouldings on the room side, Godot -Z). The flat wall field between the
bands is not a mesh: it is the shell wall with the tile material
"limestone_rustic" (ground storey) or "limestone_ashlar" (upper storey).

  hall_plinth_*      base course 0-1.0 m: verde toe, limestone block with
                     head joints every metre, moulded cap. Origin on the
                     floor (datum = floor).
  hall_string_*      string course, 0.45 m, hanging from its datum (origin
                     at its TOP): y = 6 on open walls, y = 5.6 under a
                     balcony slab (it must not enter the slab).
  hall_cornice_*     entablature under the 14 m ceiling, 1.5 m: three
                     fasciae, frieze, dentils, modillions every 0.5 m,
                     corona and cyma. Origin at its TOP (datum = ceiling).
  hall_upper_base_*  0.35 m base course of the balcony level (datum = the
                     balcony floor, y = 6).

Variant texture sets (same mesh and UVs): armory_plinth_* (grey sandstone
for the armory's rubble walls).
"""
from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import LENGTHS, kit, moulding
from artlib.geo import Part


def _jointed(pitch=1.0, base=A.limestone):
    """Limestone with a dark head joint every ``pitch`` metres along the run
    (vertical faces only)."""
    def fn(ctx):
        s = base(ctx)
        u = ctx.uvm[:, 0]
        vertical = abs(ctx.n[:, 2]) < 0.5
        m = ((u + 1e-4) % pitch < ctx.texel) & vertical
        s.shade[m] -= 2.4
        return s
    return fn


def _sandstone(ctx):
    s = M.stone(ctx)
    return s


def plinth(W):
    p = Part("hall_plinth")
    moulding(p, [(-0.1, 0.0), (-0.1, 0.16), (-0.085, 0.18), (-0.07, 0.18)], W, "marble_dark")
    moulding(p, [(-0.07, 0.18), (-0.07, 0.82), (-0.08, 0.84), (-0.11, 0.86), (-0.11, 0.9), (-0.085, 0.93),
                 (-0.06, 0.96), (-0.04, 0.98), (-0.04, 1.0), (0.0, 1.0)], W, "limestone")
    return p


def upper_base(W):
    p = Part("hall_upper_base")
    moulding(p, [(-0.07, 0.0), (-0.07, 0.1), (-0.06, 0.12), (-0.05, 0.12)], W, "marble_dark")
    moulding(p, [(-0.05, 0.12), (-0.05, 0.26), (-0.065, 0.28), (-0.065, 0.3), (-0.035, 0.33), (-0.02, 0.35),
                 (0.0, 0.35)], W, "limestone")
    return p


def string_course(W):
    p = Part("hall_string")
    moulding(p, [(0.0, -0.45), (-0.04, -0.45), (-0.04, -0.41), (-0.07, -0.39), (-0.09, -0.35), (-0.1, -0.3),
                 (-0.1, -0.13), (-0.13, -0.11), (-0.19, -0.09), (-0.24, -0.07), (-0.24, -0.035), (-0.21, -0.02),
                 (0.0, 0.0)], W, "limestone")
    return p


def cornice(W):
    p = Part("hall_cornice")
    moulding(p, [(0.0, -1.5), (-0.03, -1.5), (-0.03, -1.33), (-0.05, -1.31), (-0.05, -1.16), (-0.07, -1.14),
                 (-0.07, -1.07), (-0.1, -1.04), (-0.1, -1.0), (-0.07, -0.98), (-0.07, -0.58), (-0.09, -0.56),
                 (-0.12, -0.53), (-0.12, -0.44), (-0.17, -0.43), (-0.2, -0.41), (-0.2, -0.4), (-0.6, -0.4),
                 (-0.63, -0.37), (-0.63, -0.22), (-0.67, -0.18), (-0.73, -0.1), (-0.78, -0.05), (-0.78, 0.0),
                 (0.0, 0.0)], W, "limestone")
    # dentils under the bed moulding
    n = int(round(W / 0.125))
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        p.box((x, -0.145, -0.475), (0.065, 0.05, 0.1), "limestone", bevel=0.006)
    # modillions under the corona: a scrolled block and its tail
    m = int(round(W / 0.5))
    for k in range(m):
        x = -W / 2 + (k + 0.5) * W / m
        p.box((x, -0.39, -0.46), (0.13, 0.36, 0.12), "limestone", bevel=0.015)
        p.box((x, -0.52, -0.53), (0.13, 0.1, 0.14), "limestone", bevel=0.02)
        p.box((x, -0.26, -0.51), (0.11, 0.1, 0.1), "limestone", bevel=0.02)
    return p


def build():
    out = []
    jointed = _jointed()
    for W, tag in LENGTHS:
        show = tag == "4m"
        out.append(kit(f"hall_plinth_{tag}", [plinth(W)], {"marble_dark": M.marble_dark, "limestone": jointed},
                       wall=True, variants={f"armory_plinth_{tag}": {"marble_dark": M.marble_dark,
                                                                     "limestone": _jointed(1.0, _sandstone)}},
                       preview=show))
        out.append(kit(f"hall_upper_base_{tag}", [upper_base(W)], {"marble_dark": M.marble_dark, "limestone": jointed},
                       wall=True, preview=show))
        out.append(kit(f"hall_string_{tag}", [string_course(W)], {"limestone": jointed}, wall=True, ground=None,
                       preview=show))
        out.append(kit(f"hall_cornice_{tag}", [cornice(W)], {"limestone": A.limestone}, wall=True, ground=None,
                       ceiling=0.0, ao_dist=0.5, preview=show))
    return out
