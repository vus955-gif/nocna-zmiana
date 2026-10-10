"""Coffered ceiling module, 2 x 2 m: walnut beams with stepped mouldings
round a recessed plaster field and a gilded rosette. Origin at a corner of
the module on the ceiling plane; everything hangs below it (down to 0.28 m)
and faces down. Tile modules edge to edge (each carries half a beam)."""
import math

from mathutils import Matrix

from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

S = 2.0
EDGE = 0.16      # half beam width carried by each module


def build():
    p = Part("ceiling_2m")
    # built like a wall (x right, z up, viewer at -Y) then turned to face down
    lo, hi = EDGE, S - EDGE
    path = [(lo, lo), (lo, hi), (hi, hi), (hi, lo)]
    prof = [(0.0, 0.0), (0.05, 0.0), (0.05, 0.025), (0.12, 0.025), (0.12, 0.05), (0.25, 0.05),
            (0.28, 0.075), (0.28, EDGE)]
    beams = p.sweep(prof, path, "wood_dark", closed=True)
    field = p.poly([(lo, 0.0, lo), (hi, 0.0, lo), (hi, 0.0, hi), (lo, 0.0, hi)], "plaster")
    field[0].normal_update()
    if field[0].normal.y > 0:
        field[0].normal_flip()
    # rosette: a stepped boss in the middle of the field
    ros = p.lathe([(0.0, 0.0), (0.2, 0.0), (0.2, 0.02), (0.15, 0.04), (0.12, 0.045), (0.07, 0.07),
                   (0.03, 0.09), (0.0, 0.095)], "gold", segments=16, cap_bottom=False)
    p.move(ros, Matrix.Translation((S / 2, 0.0, S / 2)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    everything = list(p.bm.faces)
    p.move(everything, Matrix.Translation((0.0, S, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    # after the turn: x stays, wall-z became -y (shifted back to 0..2), the
    # viewer side (-Y) became down (-Z)
    return Model("ceiling_2m", [p], {"wood_dark": M.wood_dark, "plaster": M.plaster, "gold": M.gold},
                 ppm=64, ground=None, ao_dist=0.35, preview_elevation=-40.0)
