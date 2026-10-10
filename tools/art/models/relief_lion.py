"""Lew z reliefu: the great walking lion of the Lion Room slabs, torn off
the wall as a flat enemy (wolf behaviour: stalk, pounce). A gypsum slab
~1 m tall to the top of the mane and 0.16 m thick, cut along the carved
outlines (the same drawing as asy_relief_2m_lions / asy_relief_wake_lion),
carved face to the player, fresh break on the back and edges.

Faces +Y in Blender = -Z in Godot, the drawing looks to the viewer's right
(Godot +X). Origin on the floor under the body. Part names as the wolf's
(body, head, jaw, leg_fl, leg_fr, leg_bl, leg_br, tail) so a wolf-like rig
can drive it; but the legs turn about the SLAB NORMAL (Godot Z), the lion
being a paper cut-out. leg_fl / leg_bl are the near (front) legs.
    body    root (0.12, 0.66)          head  neck (-0.42, 0.80), with the mane
    jaw     hinge, child of head       tail  root, child of body
    leg_*   shoulders / hips, children of body
Marker eye (weak point) on the head's face.
"""
from artlib import asy, asy_mesh as AM, asy_relief as rl
from artlib import asy_figures as F
from artlib.geo import Part
from artlib.model import Model

PPM = 256
DEPTH = {
    "leg_fr": (-0.08, 0.0), "leg_br": (-0.08, 0.0), "tail": (-0.06, 0.02), "body": (-0.08, 0.045),
    "leg_bl": (-0.04, 0.075), "leg_fl": (-0.04, 0.075), "head": (-0.06, 0.08), "jaw": (-0.05, 0.06),
}
PARENT = {"head": "body", "jaw": "head", "tail": "body", "leg_fl": "body", "leg_fr": "body", "leg_bl": "body",
          "leg_br": "body"}


def drawing():
    R = rl.Relief(2.32, 1.18, PPM, u0=-1.22, v0=-0.04, seed=5)
    F.lion(F.Pen(R, rl.Xf(0.0, 0.0, 1.0, 1), default=None), pose="walk")
    return R


def build():
    R = drawing()
    parts, fns = [], {}
    brk = lambda c: asy.gypsum_break(c, seed=513)
    for name in ["body", "head", "jaw", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br"]:
        jx, jy = F.LION_JOINTS[name]
        p = Part(name, origin=(-jx, 0.0, jy), parent=PARENT.get(name))
        y0, y1 = DEPTH[name]
        for loop in rl.outlines(R, R.layers[name].mask, tol=0.0035):
            AM.prism(p, loop, y0, y1, "f_" + name, "edge", "back")
        fns["f_" + name] = asy.relief_material(asy.ReliefMaps(R, own=name), uv=AM.UV, center=9.2, grime=0.8)
        parts.append(p)
    fns["edge"] = brk
    fns["back"] = brk
    ex, ey = F.LION_EYE
    markers = [("eye", (-ex, DEPTH["head"][1] + 0.01, ey), "head")]
    return Model("relief_lion", parts, fns, ppm=PPM, ground=0.0, ao_rays=10, ao_dist=0.12, ao_stride=2, front=1,
                 markers=markers, normal_strength=2.0, preview_yaws=(-25.0, 25.0, 88.0, 160.0),
                 preview_elevation=10.0, preview_closeup=((-0.68, 0.05, 0.86), 0.25))
