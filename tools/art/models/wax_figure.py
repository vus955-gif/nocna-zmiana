"""The wax figure enemy: a Napoleonic officer from the waxworks. Navy coat
with a red plastron and gold buttons, epaulettes, red sash, white breeches,
black riding boots and a bicorne worn sideways. Wax face with glass eyes,
wax hands with drips.

Faces +Y in Blender = -Z in Godot (the Enemy forward direction). Origin on
the floor between the feet. Seven separate objects so the game can gib it,
each with its pivot at the joint (Godot node names = object names):
    torso  (pivot 0, 0, 0.95)   head (0, 0, 1.47)    hat (0, 0, 1.62)
    arm_l  (-0.19, 0, 1.40)     arm_r (0.19, 0, 1.40)
    leg_l  (-0.1, 0, 0.92)      leg_r (0.1, 0, 0.92)
Matches the collider/hurtboxes of src/enemies/wax_figure.gd: body capsule
r 0.35 h 1.75; torso hurtbox around y 0.72; head weak point (sphere r 0.22)
centred at y 1.55, the top of the silhouette under the hat.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.model import Model
from artlib.painter import Surface
from artlib.sculpt import blob

HEAD_C = Vector((0.0, 0.0, 1.555))   # head centre (weak point)
SHOULDER = 0.19
HIP = 0.1


def T(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


def R(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


# --------------------------------------------------------------------------
# head: metaball clay, face toward -Y while sculpting, then turned to +Y
# --------------------------------------------------------------------------

def _head_blobs():
    return [
        blob((0, 0.012, 0.022), (0.082, 0.094, 0.096)),
        blob((0, -0.024, -0.018), (0.07, 0.066, 0.078)),
        blob((0, -0.03, -0.062), (0.06, 0.052, 0.04)),
        blob((0, -0.062, -0.078), (0.026, 0.02, 0.022), kind="BALL"),
        blob((0, -0.075, 0.022), (0.066, 0.02, 0.016)),
        blob((0, -0.089, -0.008), (0.014, 0.022, 0.027), rot=(-12, 0, 0)),
        blob((0, -0.099, -0.021), (0.013, 0.012, 0.011), kind="BALL"),
        blob((0.046, -0.06, -0.018), (0.03, 0.027, 0.028)),
        blob((-0.046, -0.06, -0.018), (0.03, 0.027, 0.028)),
        blob((0, -0.078, -0.048), (0.024, 0.012, 0.008)),
        blob((0.03, -0.088, 0.004), (0.015, 0.012, 0.009), neg=True, stiff=1.6),
        blob((-0.03, -0.088, 0.004), (0.015, 0.012, 0.009), neg=True, stiff=1.6),
        blob((0.029, -0.079, 0.003), 0.0105, kind="BALL", stiff=2.4),   # glass eyes
        blob((-0.029, -0.079, 0.003), 0.0105, kind="BALL", stiff=2.4),
        blob((0, -0.088, -0.056), (0.02, 0.007, 0.003), neg=True, stiff=1.2),
        blob((0.086, 0.004, -0.004), (0.01, 0.02, 0.028)),
        blob((-0.086, 0.004, -0.004), (0.01, 0.02, 0.028)),
        # hair: a combed-forward cap and sideburns
        blob((0, 0.02, 0.055), (0.088, 0.098, 0.07)),
        blob((0, -0.05, 0.07), (0.07, 0.04, 0.03), rot=(20, 0, 0)),
        blob((0.075, -0.018, -0.02), (0.012, 0.022, 0.036)),
        blob((-0.075, -0.018, -0.02), (0.012, 0.022, 0.036)),
        # neck
        blob((0, 0.004, -0.115), (0.05, 0.05, 0.07)),
        # melted wax running off the jaw and the left cheek
        blob((0.028, -0.062, -0.095), (0.006, 0.006, 0.02), stiff=1.8),
        blob((0.028, -0.061, -0.12), 0.0085, kind="BALL", stiff=1.8),
        blob((-0.018, -0.066, -0.09), (0.005, 0.005, 0.014), stiff=1.8),
        blob((-0.018, -0.066, -0.106), 0.007, kind="BALL", stiff=1.8),
        blob((0.05, -0.064, -0.045), (0.005, 0.005, 0.016), stiff=1.8),
    ]


def _head(part):
    me = sculpt.metaball_mesh(_head_blobs(), resolution=0.0045)
    sculpt.cut(me, [((0, 0, -0.16), (0, 0, -1))])
    me = sculpt.decimate(me, 2400)
    sculpt.into_part(part, me, "wax_head", transform=T(*HEAD_C) @ R('Z', 180))


def wax_head(ctx):
    """Wax skin + painted hair, brows, glass eyes, lips and blush, placed by
    position in head space (x right, y back, z up; the face looks at -y)."""
    s = M.wax(ctx)
    q = ctx.p - np.array(HEAD_C)
    x = -q[:, 0]
    y = -q[:, 1]
    z = q[:, 2]
    ax = np.abs(x)
    hair = ((z > 0.045 - np.clip(y, 0, 0.1) * 0.9) & (y > -0.075)) | ((y > 0.02) & (z > -0.07))
    hair |= (ax > 0.064) & (z > -0.058) & (z < 0.03) & (y > -0.045) & (y < 0.0)
    hair &= z > -0.1
    s.use_ramp(M.P["hair"], mask=hair, shade=2.4 + ctx.fbm(60.0, 2, 3) * 1.4 + np.clip(ctx.curv, 0, 1) * 1.5
               - (1 - ctx.ao) * 2.5)
    arch = 0.021 + 0.004 - ((ax - 0.031) / 0.02) ** 2 * 0.004
    brow = (ax > 0.013) & (ax < 0.05) & (np.abs(z - arch) < 0.0035) & (y < -0.06)
    s.use_ramp(M.P["hair"], mask=brow, shade=np.full(ctx.N, 2.0))
    for ex in (0.029, -0.029):
        d = np.sqrt((x - ex) ** 2 + ((z - 0.003) * 1.25) ** 2)
        front = y < -0.078
        sclera = front & (d < 0.0095)
        s.use_ramp(M.P["eye"], mask=sclera, shade=np.full(ctx.N, 3.0))
        iris = front & (d < 0.0068)
        s.use_ramp(M.P["eye"], mask=iris, shade=np.full(ctx.N, 2.0))
        pupil = front & (d < 0.0032)
        s.use_ramp(M.P["eye"], mask=pupil, shade=np.full(ctx.N, 0.0))
        s.rough = np.where(sclera, 0.04, s.rough)
        glint = front & (np.abs(x - ex - 0.0025) < 0.002) & (np.abs(z - 0.006) < 0.002)
        s.use_ramp(M.P["eye"], mask=glint, shade=np.full(ctx.N, 3.0))
        s.sss = np.where(sclera, 0.0, s.sss)
        # upper lid line
        lid = front & (np.abs(d - 0.0105) < 0.0018) & (z > 0.003)
        s.use_ramp(M.P["wax"], mask=lid, shade=np.full(ctx.N, 2.0))
    lip = (ax < 0.021) & (np.abs(z + 0.052) < 0.0085) & (y < -0.07)
    s.use_ramp(M.P["wax_lip"], mask=lip, shade=2.2 + ctx.fbm(40.0, 2, 5) * 0.6 + np.clip(ctx.curv, 0, 1))
    blush = (np.sqrt((ax - 0.047) ** 2 + ((z + 0.024) * 1.3) ** 2) < 0.019) & (y < -0.04) & ~hair
    blush &= ctx.rand(9) > 0.35
    s.use_ramp(M.P["wax_blush"], mask=blush, shade=4.2 + ctx.fbm(30.0, 2, 7) * 0.6 + np.clip(ctx.curv, 0, 1))
    # a hairline crack running from the brow down the cheek, and a chipped spot
    xc = 0.022 + (0.07 - z) * 0.26 + 0.004 * np.sin(z * 190.0) + 0.002 * np.sin(z * 530.0)
    crack = (np.abs(x - xc) < 0.0017) & (z > -0.04) & (z < 0.075) & (y < -0.035) & ~hair
    s.use_ramp(M.P["wax"], mask=crack, shade=np.full(ctx.N, 1.0))
    chip = (np.sqrt((x - 0.052) ** 2 + (z + 0.03) ** 2) < 0.009) & (y < -0.035)
    s.use_ramp(M.P["wax"], mask=chip & ~crack, shade=3.4 + ctx.rand(11) * 1.2)
    s.rough = np.where(crack | chip, 0.8, s.rough)
    s.height = s.height - crack * 0.0008 - chip * 0.0012
    return s


# --------------------------------------------------------------------------
# costume
# --------------------------------------------------------------------------

def _torso(p):
    sq = (1.0, 0.7)
    # coat body: waist -> chest -> sloping shoulders -> neck
    p.lathe([(0.158, 0.9), (0.152, 0.96), (0.165, 1.08), (0.195, 1.22), (0.212, 1.32), (0.205, 1.38),
             (0.16, 1.425), (0.09, 1.45), (0.0, 1.455)], "coat", segments=16, squash=sq, cap_bottom=True)
    # skirt and tails: flared lathe, front cut away to show the breeches
    tails = p.lathe([(0.16, 0.96), (0.175, 0.86), (0.19, 0.74), (0.2, 0.62), (0.2, 0.56)], "coat",
                    segments=16, squash=(1.0, 0.78), cap_bottom=False, cap_top=False)
    import bmesh
    front = [f for f in tails if f.calc_center_median().y > 0.06]
    bmesh.ops.delete(p.bm, geom=front, context='FACES')
    # red plastron with two rows of gold buttons, white waistcoat below
    p.box((0, 0.118, 1.2), (0.2, 0.03, 0.36), "cloth_red", bevel=0.012)
    for k in range(6):
        z = 1.33 - k * 0.055
        for x in (-0.07, 0.07):
            p.box((x, 0.136, z), (0.018, 0.012, 0.018), "gold", bevel=0.005)
    p.box((0, 0.1, 0.97), (0.18, 0.03, 0.08), "cloth_white", bevel=0.01)
    # sash with a knot and tassels on the left hip
    p.lathe([(0.162, 0.93), (0.168, 0.95), (0.168, 1.0), (0.158, 1.02)], "cloth_red", segments=16, squash=sq,
            cap_bottom=False, cap_top=False)
    p.box((-0.15, 0.06, 0.97), (0.06, 0.06, 0.07), "cloth_red", bevel=0.015)
    for dx in (-0.022, 0.022):          # apart: overlapping clay gave run-to-run AO ties
        p.lathe([(0.0, 0.0), (0.02, 0.02), (0.014, 0.1), (0.0, 0.11)], "gold", segments=8,
                center=(-0.16 + dx, 0.07, 0.83))
    # sabre in its scabbard, hanging from the left hip and swept back
    sabre = []
    sabre += p.box((0, 0, -0.36), (0.022, 0.045, 0.72), "leather", bevel=0.006)          # scabbard
    for z in (-0.03, -0.25, -0.7):
        sabre += p.box((0, 0, z), (0.028, 0.052, 0.035), "gold", bevel=0.005)          # lockets, chape
    sabre += p.box((0, -0.005, 0.07), (0.02, 0.028, 0.11), "leather", bevel=0.006)     # grip
    sabre += p.box((0, 0.02, 0.01), (0.026, 0.07, 0.014), "gold", bevel=0.004)         # cross guard
    sabre += p.tube([(0, 0.05, 0.01), (0, 0.05, 0.08), (0, 0.02, 0.13), (0, -0.005, 0.13)], 0.007, "gold", sides=5)
    p.move(sabre, T(-0.19, -0.04, 0.9) @ R('X', -32) @ R('Z', 8))
    # high red collar
    p.lathe([(0.075, 1.42), (0.078, 1.5), (0.07, 1.51)], "cloth_red", segments=14, squash=(1.0, 0.9),
            cap_bottom=False, cap_top=False)
    # epaulettes: gold boards and fringes
    for sx in (-1, 1):
        board = p.lathe([(0.0, 0.0), (0.075, 0.0), (0.08, 0.015), (0.062, 0.03), (0.0, 0.033)], "gold",
                        segments=12, squash=(1.0, 0.75))
        p.move(board, T(sx * 0.185, 0.0, 1.425) @ R('Y', sx * 20))
        strap = p.box((0, 0, 0), (0.1, 0.045, 0.012), "gold", bevel=0.004)
        p.move(strap, T(sx * 0.12, 0.0, 1.448) @ R('Y', sx * 16))
        for k in range(9):
            a = math.radians(-80 + k * 20)
            x = sx * (0.185 + 0.075 * math.cos(a) * 0.95)
            y = 0.056 * math.sin(a)
            top = 1.425 - (0.075 * math.cos(a)) * math.sin(math.radians(20))
            p.tube([(x, y, top), (x + sx * 0.014, y, top - 0.065)], 0.009, "gold", sides=5)


def _arm(p, sx):
    """Arm hanging from the shoulder pivot, reaching forward, elbow bent."""
    shoulder = Vector((sx * SHOULDER, 0.0, 1.40))
    up_rot = R("X", 16) @ R("Y", sx * 2)
    up = p.lathe([(0.062, 0.0), (0.06, -0.08), (0.052, -0.2), (0.046, -0.3)], "coat", segments=10)
    p.move(up, T(*shoulder) @ up_rot)
    # shoulder ball: keeps the sleeve closed however the arm is turned
    r = 0.058
    p.lathe([(0.0, -r), (r * 0.7, -r * 0.7), (r, 0.0), (r * 0.7, r * 0.7), (0.0, r)], "coat", segments=10,
            center=(shoulder.x, shoulder.y, shoulder.z - 0.012))
    elbow = shoulder + up_rot.to_3x3() @ Vector((0, 0, -0.3))
    fore = p.lathe([(0.047, 0.02), (0.043, -0.1), (0.04, -0.2), (0.045, -0.21), (0.058, -0.215),
                    (0.058, -0.285), (0.05, -0.29)], "coat", segments=10)
    rot = R("X", 40) @ R("Y", sx * 4)
    p.move(fore, T(*elbow) @ rot)
    # the last band of the forearm lathe is the red cuff: repaint by slot
    cuff = [f for f in fore if f.calc_center_median().z < (T(*elbow) @ rot @ Vector((0, 0, -0.205))).z]
    red = p.slot("cloth_red")
    for f in cuff:
        f.material_index = red
    wrist = elbow + rot.to_3x3() @ Vector((0, 0, -0.29))
    # wax hand: clay mitten, palm toward the back (-Y) so that it faces down
    # when the arm is raised to reach; claws curl toward the palm
    hb = [
        blob((0, 0, -0.045), (0.042, 0.02, 0.05)),
        blob((0, -0.004, -0.1), (0.04, 0.016, 0.035)),
        blob((sx * -0.042, -0.012, -0.05), (0.012, 0.012, 0.03), rot=(0, sx * 25, 0)),
        blob((0, 0.005, 0.0), (0.03, 0.025, 0.02)),
    ]
    for k, fx in enumerate((-0.028, -0.009, 0.01, 0.028)):
        long = 0.008 if k in (1, 2) else 0.0
        hb.append(blob((fx * 1.1, -0.014, -0.125 - long), (0.009, 0.01, 0.022), rot=(30, 0, 0)))
        hb.append(blob((fx * 1.2, -0.034, -0.15 - long), (0.008, 0.009, 0.016), rot=(70, 0, 0)))
    hb.append(blob((0.0, -0.035, -0.17), (0.004, 0.004, 0.012), stiff=1.8))           # a wax drip
    me = sculpt.metaball_mesh(hb, resolution=0.004)
    me = sculpt.decimate(me, 500)
    sculpt.into_part(p, me, "wax", transform=T(*wrist) @ rot @ R('X', 10))


def _leg(p, sx):
    hip = Vector((sx * HIP, 0.0, 0.92))
    thigh = p.lathe([(0.085, 0.02), (0.082, -0.05), (0.07, -0.2), (0.058, -0.36), (0.054, -0.42)],
                    "cloth_white", segments=10, cap_bottom=False)
    p.move(thigh, T(*hip) @ R('Y', sx * 3))
    # riding boot: flared top over the knee, calf, ankle
    boot = p.lathe([(0.064, -0.34), (0.07, -0.37), (0.068, -0.4), (0.056, -0.48), (0.058, -0.6),
                    (0.05, -0.72), (0.042, -0.8), (0.044, -0.86), (0.05, -0.9)], "leather", segments=10)
    p.move(boot, T(*hip) @ R('Y', sx * 3))
    foot = p.box((0, 0.045, 0.0), (0.1, 0.24, 0.08), "leather", bevel=0.022)
    p.move(foot, T(hip.x + sx * 0.012, 0.02, 0.0375) @ R("Z", -sx * 5))
    heel = p.box((0, 0, 0), (0.085, 0.08, 0.03), "leather", bevel=0.008)
    p.move(heel, T(hip.x + sx * 0.008, -0.07, 0.015))


def _hat(p):
    """Bicorne worn sideways: a crescent that is thick in the middle and thin
    at the points, gold edging along the top, a cockade on the front."""
    import bmesh
    n = 16
    half = 0.25
    outline = []
    for i in range(n + 1):                      # bottom edge, left -> right
        x = -half + 2 * half * i / n
        outline.append((x, 0.018 * (abs(x) / half) ** 2))
    for i in range(n - 1, 0, -1):               # top edge, right -> left
        x = -half + 2 * half * i / n
        t = 1.0 - (abs(x) / half) ** 1.6
        outline.append((x, 0.035 + 0.14 * t ** 0.7))
    faces = p.ngon_prism([(x, z) for x, z in outline], -0.04, 0.04, "leather", bevel=0.006)
    # prism was built along Z: stand it up (outline in XZ, thickness along Y)
    p.move(faces, R('X', 90))
    for v in {v for f in faces for v in f.verts}:
        k = 1.0 - (abs(v.co.x) / half) * 0.65
        v.co.y *= k
    p.move(faces, T(0, 0, 1.625))
    # gold edging along the top edge, front and back
    top = [(x, z) for x, z in outline[n + 1:]]
    for side in (1, -1):
        pts = [(x, side * 0.04 * (1.0 - (abs(x) / half) * 0.65), 1.625 + z) for x, z in top]
        p.tube(pts, 0.006, "gold", sides=5)
    # cockade: red ring with a white centre and a gold loop
    ck = p.lathe([(0.0, 0.0), (0.035, 0.0), (0.038, 0.008), (0.0, 0.01)], "cloth_red", segments=12)
    p.move(ck, T(0.07, 0.034, 1.72) @ R('X', -90))
    c2 = p.lathe([(0.0, 0.0), (0.016, 0.0), (0.017, 0.006), (0.0, 0.007)], "cloth_white", segments=10)
    p.move(c2, T(0.07, 0.042, 1.72) @ R('X', -90))
    loop = p.box((0, 0, 0), (0.012, 0.012, 0.09), "gold", bevel=0.003)
    p.move(loop, T(0.07, 0.046, 1.735))


def build():
    torso = Part("torso", origin=(0, 0, 0.95))
    _torso(torso)
    head = Part("head", origin=(0, 0, 1.47))
    _head(head)
    hat = Part("hat", origin=(0, 0, 1.62))
    _hat(hat)
    arm_l = Part("arm_l", origin=(-SHOULDER, 0, 1.40))
    _arm(arm_l, -1)
    arm_r = Part("arm_r", origin=(SHOULDER, 0, 1.40))
    _arm(arm_r, 1)
    leg_l = Part("leg_l", origin=(-HIP, 0, 0.92))
    _leg(leg_l, -1)
    leg_r = Part("leg_r", origin=(HIP, 0, 0.92))
    _leg(leg_r, 1)
    fns = {
        "wax_head": wax_head, "wax": M.wax, "coat": M.coat, "cloth_red": M.cloth_red,
        "cloth_white": M.cloth_white, "leather": M.leather, "gold": M.gold,
    }
    return Model("wax_figure", [torso, head, hat, arm_l, arm_r, leg_l, leg_r], fns, ppm=256, ao_stride=1,
                 organic=("head", "arm_l", "arm_r"), ground=0.0, ao_dist=0.18, ao_rays=12, front=1,
                 preview_yaws=(-30.0, 30.0, 90.0, 200.0), preview_closeup=((0.0, 0.05, 1.6), 0.2))
