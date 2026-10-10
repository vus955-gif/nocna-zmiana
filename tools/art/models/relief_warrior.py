"""Wojownik z reliefu: the flat Assyrian spearman who peels himself off the
palace wall. A slab of gypsum 1.9 m tall and 0.18 m thick, cut along the
outlines of the carved figure (the same drawing as the life-size spearman
of asy_relief_1m / asy_relief_wake, artlib.asy_panels.warrior_on): the
carved face toward the player, a fresh crystalline break on the back and
the edges, where he tore out of the wall. From the side he is a thin plank
(hits on the edge x0.5); from the front his frontal eye is the weak point.

Faces +Y in Blender = -Z in Godot. Origin on the floor under the body.
The drawing faces the viewer's right (toward Godot +X). Parts (flat slabs
layered front to back, pivots at the joints, turning about the slab normal
for the paper-doll walk):
    torso      root, the hips (0.00, 0.98)
    head       neck (-0.035, 1.47), child of torso; marker eye on its face
    arm_front  near shoulder, holds the spear; child of torso
    spear      the grip, child of arm_front (thrown: detach and fly it)
    arm_back   far shoulder; child of torso
    shield     the far fist, child of arm_back
    leg_front, leg_back   hips, root level (as the knight's legs)
"""
from artlib import asy, asy_mesh as AM, asy_relief as rl
from artlib import asy_figures as F
from artlib.geo import Part
from artlib.model import Model

PPM = 256
# slab depth of each part (Blender y back, front): the relief face is +Y
DEPTH = {
    "arm_back": (-0.09, 0.0), "leg_back": (-0.09, 0.01), "torso": (-0.09, 0.05), "head": (-0.08, 0.055),
    "leg_front": (-0.06, 0.07), "shield": (0.0, 0.08), "spear": (0.025, 0.06), "arm_front": (-0.02, 0.09),
}
PARENT = {"head": "torso", "arm_front": "torso", "arm_back": "torso", "spear": "arm_front", "shield": "arm_back"}


def drawing():
    R = rl.Relief(1.0, 2.32, PPM, u0=-0.45, v0=-0.04, seed=3)
    F.warrior(F.Pen(R, rl.Xf(0.0, 0.0, 1.0, 1), default=None))
    return R


def build():
    R = drawing()
    parts, fns = [], {}
    brk = lambda c: asy.gypsum_break(c, seed=511)
    for name in ["torso", "head", "arm_front", "spear", "arm_back", "shield", "leg_front", "leg_back"]:
        jx, jy = F.WARRIOR_JOINTS[name]
        p = Part(name, origin=(-jx, 0.0, jy), parent=PARENT.get(name))
        y0, y1 = DEPTH[name]
        for loop in rl.outlines(R, R.layers[name].mask, tol=0.0035):
            AM.prism(p, loop, y0, y1, "f_" + name, "edge", "back")
        fns["f_" + name] = asy.relief_material(asy.ReliefMaps(R, own=name), uv=AM.UV, center=9.2, grime=0.8)
        parts.append(p)
    fns["edge"] = brk
    fns["back"] = brk
    ex, ey = F.WARRIOR_EYE
    markers = [("eye", (-ex, DEPTH["head"][1] + 0.01, ey), "head")]
    return Model("relief_warrior", parts, fns, ppm=PPM, ground=0.0, ao_rays=10, ao_dist=0.12, ao_stride=2, front=1,
                 markers=markers, normal_strength=2.0, preview_yaws=(-25.0, 25.0, 88.0, 160.0),
                 preview_elevation=8.0, preview_closeup=((-0.1, 0.05, 1.66), 0.22))
