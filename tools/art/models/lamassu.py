"""Lamassu, guardian of the Assyrian wing (spec 7.4): a human-headed winged
bull ~4 m to the top of its crown, alabaster with traces of paint (black
beard and hair, red crown band, painted eyes) and bronze accents
(earrings, crown rosettes). Charges, beats its wings, stomps, leaps.

Faces +Y in Blender = -Z in Godot. Origin on the floor under the body.
Parts (Godot node names), pivots at the joints (Blender x, y, z):
    body                     (0, 0, 1.9)            root
    head                     neck (0, 1.22, 2.6)    child of body: face, ears, beard, hair
    headdress                crown base             child of head: the horned crown (breakable)
    wing_l, wing_r           wing roots (-+0.54, 0.68, 2.18), children of body: inner plates
    wing_l_tip, wing_r_tip   the wing joint, children of wing_*: outer plates (breakable)
    tail                     (0, -1.46, 2.0), child of body
    thigh_fl/fr/bl/br        shoulders / hips, children of body
    shin_*                   knees / hocks, children of thigh_*
    hoof_*                   fetlocks, children of shin_*
Markers: face (weak point x1.5, on the face), crown (on the crown),
contact_fl/fr/bl/br (hoof soles, children of hoof_*).
Texture sets: lamassu, lamassu_cracked (glowing cracks: phases 2-3).
Wings spread for the gust by turning wing_* about Godot Z (out and up,
~-70 / +70 degrees) and wing_*_tip about its own joint.
"""
from mathutils import Vector

from artlib import lamassu as L
from artlib.geo import Part
from artlib.model import Model

PPM = 112


def build():
    s = 1.0
    body = Part("body", origin=L.BODY)
    L._clay(body, L.body_clay(s), 3200, "stone", 0.05)
    head = Part("head", origin=L.NECK, parent="body")
    crown = Part("headdress", origin=(0.0, L.HEAD_C.y, L.CROWN_BASE), parent="head")
    L.head_parts(head, crown, s)
    parts = [body, head, crown]
    R = L.wing_relief(PPM)
    for sx, nm in ((-1, "wing_l"), (1, "wing_r")):
        o, A, B, N = L.wing_frame(sx, s)
        w = Part(nm, origin=tuple(o), parent="body")
        joint = o + A * L.WING_SPLIT + B * L.WING_JOINT_B
        t = Part(nm + "_tip", origin=tuple(joint), parent=nm)
        L.wing_parts(w, t, sx, s, R)
        parts += [w, t]
    tail = Part("tail", origin=L.TAIL_ROOT, parent="body")
    L.tail(tail, s)
    parts.append(tail)
    markers = []
    for k, pts in L.LEGS.items():
        front = k[0] == "f"
        th = Part("thigh_" + k, origin=pts[0], parent="body")
        sh = Part("shin_" + k, origin=pts[1], parent="thigh_" + k)
        ho = Part("hoof_" + k, origin=pts[2], parent="shin_" + k)
        L.leg(None, pts, s, front, parts=(th, sh, ho))
        parts += [th, sh, ho]
        markers.append(("contact_" + k, pts[3], "hoof_" + k))
    markers.append(("face", (0.0, L.HEAD_C.y + 0.31, L.HEAD_C.z + 0.03), "head"))
    markers.append(("crown", (0.0, L.HEAD_C.y, L.CROWN_BASE + 0.4), "headdress"))
    ident = lambda ctx: ctx.p
    fns = L.materials(ident, s, R)
    cracked = L.materials(ident, s, R, cracked=True)
    for part in (body, head):
        L.unwrap(part)
    organic = ()
    return Model("lamassu", parts, fns, ppm=PPM, organic=organic, ground=0.0, ao_rays=8, ao_dist=0.35, ao_stride=2,
                 front=1, markers=markers, variants={"lamassu_cracked": cracked}, normal_strength=2.0,
                 preview_closeup=((0.0, 1.75, 3.25), 0.75))
