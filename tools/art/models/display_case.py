"""Museum display case: panelled walnut cabinet with a brass-framed glass
vitrine on top, velvet display bed (top at z = 0.93, where artefacts stand)
and a warm lamp strip under the lid. 1.06 x 0.76 m, 1.56 m tall. Two
objects: "display_case" and "display_case_glass" (no shadows in game)."""
from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

W, D = 1.0, 0.7          # cabinet body
TOP = 0.9                # top of the cabinet slab
BED = 0.93               # top of the velvet bed
GH = 0.6                 # vitrine height
GW, GD = 0.96, 0.66      # vitrine footprint


def build():
    p = Part("display_case")
    g = Part("display_case_glass")
    # plinth (recessed toe) and body
    p.box((0, 0, 0.05), (W - 0.08, D - 0.08, 0.1), "wood_dark", bevel=0.006)
    p.box((0, 0, 0.1 + 0.36), (W, D, 0.72), "wood_dark", bevel=0.012)
    p.box((0, 0, 0.84), (W + 0.02, D + 0.02, 0.04), "wood_dark", bevel=0.008)       # upper moulding
    p.box((0, 0, 0.875), (W + 0.06, D + 0.06, 0.05), "wood_dark", bevel=0.014)     # top slab
    # raised panels on all four sides
    for sx, sy, w, h in ((0, -D / 2, 0.38, 0.48), (0, D / 2, 0.38, 0.48)):
        for x in (-0.23, 0.23):
            p.box((x, sy + (-0.012 if sy < 0 else 0.012), 0.47), (w, 0.024, h), "wood_dark", bevel=0.016)
    for sx in (-W / 2, W / 2):
        p.box((sx + (-0.012 if sx < 0 else 0.012), 0, 0.47), (0.024, 0.52, 0.48), "wood_dark", bevel=0.016)
    # brass escutcheon + label plaque on the front
    p.box((0, -D / 2 - 0.028, 0.74), (0.05, 0.008, 0.07), "brass", bevel=0.004)
    p.box((0, -D / 2 - 0.03, 0.8), (0.3, 0.008, 0.05), "brass", bevel=0.004)
    # velvet display bed
    p.box((0, 0, TOP + 0.015), (GW - 0.04, GD - 0.04, 0.03), "velvet", bevel=0.008)
    # vitrine: brass corner posts, bottom and top frames, lid
    z0, z1 = TOP, TOP + GH
    post = 0.03
    for x in (-GW / 2, GW / 2):
        for y in (-GD / 2, GD / 2):
            p.box((x, y, (z0 + z1) / 2), (post, post, GH), "brass", bevel=0.005)
    for z in (z0 + 0.012, z1 - 0.015):
        h = 0.024 if z < z1 - 0.1 else 0.03
        p.box((0, -GD / 2, z), (GW, post, h), "brass", bevel=0.005)
        p.box((0, GD / 2, z), (GW, post, h), "brass", bevel=0.005)
        p.box((-GW / 2, 0, z), (post, GD, h), "brass", bevel=0.005)
        p.box((GW / 2, 0, z), (post, GD, h), "brass", bevel=0.005)
    p.box((0, 0, z1 + 0.02), (GW + 0.05, GD + 0.05, 0.04), "wood_dark", bevel=0.01)   # lid
    p.box((0, 0, z1 + 0.05), (GW - 0.1, GD - 0.1, 0.02), "wood_dark", bevel=0.008)
    # lamp strip under the lid (front edge, pointing down)
    p.box((0, -GD / 2 + 0.06, z1 - 0.01), (GW - 0.12, 0.03, 0.012), "lamp_warm")
    # glass: four sides + top, inset a hair inside the posts
    e = 0.004
    x0, x1, y0, y1 = -GW / 2 + e, GW / 2 - e, -GD / 2 + e, GD / 2 - e
    zz0, zz1 = z0 + 0.024, z1 - 0.03
    faces = [
        ([(x0, y0, zz0), (x1, y0, zz0), (x1, y0, zz1), (x0, y0, zz1)], (0, -1, 0)),
        ([(x1, y1, zz0), (x0, y1, zz0), (x0, y1, zz1), (x1, y1, zz1)], (0, 1, 0)),
        ([(x0, y1, zz0), (x0, y0, zz0), (x0, y0, zz1), (x0, y1, zz1)], (-1, 0, 0)),
        ([(x1, y0, zz0), (x1, y1, zz0), (x1, y1, zz1), (x1, y0, zz1)], (1, 0, 0)),
    ]
    for pts, want in faces:
        f = g.poly(pts, "glass")[0]
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()
    return Model("display_case", [p, g],
                 {"wood_dark": M.wood_dark, "brass": M.brass, "velvet": M.velvet, "lamp_warm": M.lamp_warm},
                 kinds={"glass": "glass"}, ppm=128, ground=0.0, ao_dist=0.3)
