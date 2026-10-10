"""Lobby kit, main hall: the doorcases of the three 4 x 4.5 m wing doors
(hall -> gallery, armory, diorama; double swing doors, 2 m deep walls).

  hall_arch_4m        rusticated doorcase on the hall face: verde-toed base
                      blocks, quoined jambs (alternate long and short
                      courses of 0.5 m), a moulded architrave round the
                      opening, a flat arch of nine voussoirs with a carved
                      keystone and a hood cornice. 6.6 m wide, 5.5 m tall:
                      it stays under the 5.6 m balcony soffit. Origin = the
                      opening's floor centre on the wall face; the opening
                      itself stays a clear rectangle, so door leaves swing
                      freely.
  hall_door_reveal_4m lining of the passage through the wall: panelled
                      jambs with a plinth, a soffit with two sunk panels
                      and rosettes. Origin = centre of the passage floor
                      (the Door frame); size 4 x 4.5 x 2 m, stretch Z to
                      other wall thicknesses.
"""
import math

from mathutils import Matrix

from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import front_prism, kit
from artlib.geo import Part

OW, OH = 4.0, 4.5


def arch():
    p = Part("hall_arch")
    hw = OW / 2
    # base blocks with a verde toe
    for sx in (-1, 1):
        x0, x1 = hw, hw + 1.1
        cx = sx * (x0 + x1) / 2
        p.box((cx, -0.07, 0.09), (x1 - x0 + 0.08, 0.14, 0.18), "marble_dark", bevel=0.012)
        p.box((cx, -0.07, 0.6), (x1 - x0, 0.14, 0.84), "limestone", bevel=0.02)
        p.box((cx, -0.085, 1.04), (x1 - x0 + 0.06, 0.17, 0.08), "limestone", bevel=0.02)
    # quoined jambs: seven courses above the base
    for k in range(7):
        z0 = 1.08 + k * (OH - 1.08) / 7
        z1 = 1.08 + (k + 1) * (OH - 1.08) / 7
        width = 1.1 if k % 2 == 0 else 0.75
        for sx in (-1, 1):
            cx = sx * (hw + width / 2)
            p.box((cx, -0.06, (z0 + z1) / 2), (width - 0.01, 0.12, z1 - z0 - 0.012), "limestone", bevel=0.035)
    # architrave round the opening (jambs + head)
    path = [(-hw, 0.0), (-hw, OH), (hw, OH), (hw, 0.0)]
    prof = [(0.0, 0.0), (0.09, 0.0), (0.09, 0.03), (0.12, 0.05), (0.12, 0.1), (0.1, 0.13), (0.1, 0.17),
            (0.0, 0.18)]
    p.sweep(prof, path, "limestone")
    # flat arch: nine voussoirs radiating from a point below the lintel
    C = (0.0, OH - 2.6)
    top = OH + 0.8
    n = 9
    for i in range(n):
        xa = -hw + i * OW / n
        xb = -hw + (i + 1) * OW / n
        ka = (top - C[1]) / (OH - C[1])
        key = i == n // 2
        ztop = top + (0.18 if key else 0.0)
        kb = (ztop - C[1]) / (OH - C[1])
        gap = 0.006
        outline = [(xa + gap, OH), (xb - gap, OH), (xb * kb - gap, ztop), (xa * kb + gap, ztop)]
        if not key:
            outline = [(xa + gap, OH), (xb - gap, OH), (xb * ka - gap, top), (xa * ka + gap, top)]
        front_prism(p, outline, 0.26 if key else 0.13, "limestone", bevel=0.02)
    # keystone scroll: a console face on the key block
    p.box((0.0, -0.3, OH + 0.35), (0.2, 0.1, 0.5), "limestone", bevel=0.03)
    p.lathe([(0.0, -0.06), (0.07, -0.06), (0.09, 0.0), (0.07, 0.06), (0.0, 0.06)], "limestone", segments=10,
            center=(0.0, -0.36, OH + 0.12))
    # fillers beside the skewbacks and the frieze behind the arch
    for sx in (-1, 1):
        front_prism(p, [(sx * hw, OH), (sx * (hw + 1.1), OH), (sx * (hw + 1.1), top), (sx * hw * ka, top)]
                    if sx > 0 else
                    [(sx * (hw + 1.1), OH), (sx * hw, OH), (sx * hw * ka, top), (sx * (hw + 1.1), top)],
                    0.1, "limestone", bevel=0.015)
    # hood cornice over everything
    p.extrude([(0.0, top), (-0.14, top), (-0.14, top + 0.04), (-0.18, top + 0.07), (-0.24, top + 0.1),
               (-0.28, top + 0.15), (-0.28, top + 0.2), (-0.2, top + 0.23), (0.0, top + 0.26)],
              -(hw + 1.25), hw + 1.25, "limestone", caps=True)
    return p


def reveal():
    """Built in the door frame: x across, y along the passage (depth), z up."""
    p = Part("hall_door_reveal")
    hw, D = OW / 2, 2.0
    for sx in (-1, 1):
        x = sx * hw
        # plinth and a raised panel on each jamb face (facing the passage axis)
        p.box((x - sx * 0.04, 0.0, 0.45), (0.08, D - 0.2, 0.9), "limestone", bevel=0.015)
        p.box((x - sx * 0.02, 0.0, 0.94), (0.04, D - 0.12, 0.08), "limestone", bevel=0.01)
        p.box((x - sx * 0.03, 0.0, 2.7), (0.06, D - 0.5, 3.1), "limestone", bevel=0.03)
        p.box((x - sx * 0.05, 0.0, 2.7), (0.04, D - 0.8, 2.8), "panel", bevel=0.02)
    # soffit: two sunk panels with rosettes
    for sy in (-1, 1):
        cy = sy * D / 4
        p.box((0.0, cy, OH - 0.03), (OW - 0.3, D / 2 - 0.2, 0.06), "limestone", bevel=0.02)
        p.box((0.0, cy, OH - 0.07), (OW - 0.7, D / 2 - 0.45, 0.04), "panel", bevel=0.015)
        ros = p.lathe([(0.0, 0.0), (0.16, 0.0), (0.16, 0.02), (0.12, 0.05), (0.07, 0.07), (0.0, 0.09)], "gold",
                      segments=12, cap_bottom=False)
        p.move(ros, Matrix.Translation((0.0, cy, OH - 0.09)) @ Matrix.Rotation(math.radians(180), 4, 'X'))
    return p


def _panel(ctx):
    s = A.limestone(ctx)
    s.shade -= 0.6
    return s


def build():
    fns = {"limestone": A.limestone, "marble_dark": M.marble_dark}
    return [kit("hall_arch_4m", [arch()], fns, wall=True, ao_dist=0.5),
            kit("hall_door_reveal_4m", [reveal()], {"limestone": A.limestone, "panel": _panel, "gold": M.gold},
                planes=(("x", -OW / 2), ("x", OW / 2), ("z", OH)), ao_dist=0.4)]
