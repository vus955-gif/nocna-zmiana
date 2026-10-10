"""Floor I, Egypt wing kit: doorways, the great gate to Assyria and its seal
leaves, the boarded-up doorway to the Greek wing.

Doorcases follow hall_arch_4m: origin = the opening's floor centre on the
wall face, the doorcase on the room side (Godot -Z), the opening itself a
clear rectangle (leaves swing freely, the shell's reveal lines the passage).

  egypt_portal_4m       Egyptian doorway for a 4 x 4.5 m opening: jambs
                        1.0 m wide painted with a king offering and columns
                        of text, a torus roll round the frame, a lintel with
                        a winged sun disc in relief between two lines of
                        text, a cavetto cornice. 6.3 x 6.6 m.
  egypt_doorframe_2x2_8 the same for a 2 x 2.8 m door (side rooms): jambs
                        0.45 m with text columns and a cartouche. 3.2 x 4.1 m.
  egypt_portal_great    pylon gate for the 6 x 7.5 m passage from the
                        Colossus Hall to the Khorsabad Gate: battered jambs
                        2.2 m wide with two registers each (the king before
                        Ra-Horakhty and Anubis), a 1.5 m lintel with a great
                        winged disc, a 1.3 m cornice. 10.9 x 10.3 m.
  egypt_seal_door_l/_r  its leaves, 3.0 x 7.5 x 0.3 m each: cedar planks on
                        bronze straps with rivets, gilded edging, on the
                        meeting edge half of a sun-disc emblem round the seal
                        socket (marker SealSocket, on the left leaf, at the
                        socket's centre, 1.6 m up: where the Seal of the Sun
                        is set). Leaf frame as the kit's door leaves: origin =
                        centre of the leaf's base, decorated face +Z (room A,
                        the Colossus Hall), hinge on the outer edge (-X on the
                        left leaf, +X on the right one).
  egypt_boarded_doorway a 2 x 2.8 m doorway boarded up during works:
                        battens screwed into the reveals (the root part),
                        eight planks (plank_1 .. plank_8, each its own part,
                        pivot at its centre: knock them off one by one) and a
                        plywood sign "REMONT / ZAKAZ WSTĘPU" (part sign).
                        Origin = the opening's floor centre on the wall face;
                        the boards sit on the room side (Godot -Z).
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib import materials as M
from artlib import pixelfont
from artlib.archkit import front_prism, kit
from artlib.geo import Part
from artlib.materials import P, _dither, _wood_core, smoothstep
from artlib.painter import Surface


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def _ccw(pts):
    """Outline counter-clockwise as seen by the viewer at -Y (x right, z up)."""
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))
    return pts if area > 0 else list(reversed(pts))


def _cornice(p, x0, x1, z0, h, depth, slot_cove="cove"):
    """Cavetto cornice from x0 to x1 standing on z0 (viewer at -Y), its ends
    closed; returns the cove length (for the leaf tips)."""
    s = h / 1.0
    roll = [(0.0, z0)]
    for i in range(0, 9):
        a = -math.pi / 2 + math.pi * i / 8
        roll.append((-0.06 * s - 0.07 * s * math.cos(a), z0 + 0.07 * s + 0.07 * s * math.sin(a)))
    roll.append((-0.06 * s, z0 + 0.14 * s))
    p.extrude(roll, x0, x1, "torus", caps=True)
    cove = []
    for i in range(10):
        a = math.pi / 2 * i / 9
        cove.append((-0.06 * s - (depth - 0.1 * s) * (1.0 - math.cos(a)), z0 + 0.14 * s + 0.72 * s * math.sin(a) ** 1.15))
    p.extrude([(0.0, z0 + 0.14 * s)] + cove + [(0.0, cove[-1][1])], x0, x1, slot_cove, caps=True)
    top = cove[-1][1]
    p.extrude([(0.0, top), (-depth - 0.04, top), (-depth - 0.04, z0 + h), (0.0, z0 + h)], x0 - 0.04, x1 + 0.04,
              "sandstone", caps=True)
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(cove, cove[1:]))


def _roll_frame(p, x_out, z_top, r, y):
    """Torus roll up the outer edges and across under the cornice."""
    path = [(-x_out, 0.0), (-x_out, z_top), (x_out, z_top), (x_out, 0.0)]
    prof = [(0.0, 0.0), (r * 0.7, -0.3 * r), (r * 1.0, -r), (r * 0.7, -1.7 * r), (0.0, -2.0 * r)]
    p.sweep(prof, path, "torus", y0=y)


def winged_disc(p, cx, cz, y, span, slot_disc="disc", slot_wing="wing", slot_cobra="cobra"):
    """The winged sun disc of Horus of Behdet in low relief on a face at
    depth y (viewer at -Y): a disc, two uraei hanging from it, two wings
    curving down to their tips. ``span`` = wing tip to wing tip."""
    r = span * 0.075
    disc = p.lathe([(0.0, 0.0), (r, 0.0), (r, 0.04 * span / 4), (r * 0.85, 0.07 * span / 4), (0.0, 0.08 * span / 4)],
                   slot_disc, segments=20)
    p.move(disc, Matrix.Translation((cx, y, cz)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    half = span / 2
    for sx in (-1, 1):
        pts = []
        top = [(r * 0.9, 0.15 * r), (half * 0.35, 0.55 * r), (half * 0.7, 0.62 * r), (half, 0.35 * r)]
        bot = [(half * 0.96, -0.1 * r), (half * 0.7, -0.4 * r), (half * 0.4, -0.75 * r), (r * 0.9, -0.95 * r)]
        for x, z in top + bot:
            pts.append((cx + sx * x, cz + z))
        front_prism(p, _ccw(pts), 0.03 * span / 4, slot_wing, y_back=y + 0.01)
        cob = p.lathe([(r * 0.18, 0.0), (r * 0.2, r * 0.5), (r * 0.28, r * 0.85), (r * 0.15, r * 1.05), (0.0, r * 1.1)],
                      slot_cobra, segments=8)
        p.move(cob, Matrix.Translation((cx + sx * r * 1.05, y - 0.03 * span / 4, cz - r * 1.6)))


def jambs_lintel(p, OW, OH, jw, lh, depth, batter=0.0):
    """Two jambs (optionally battered: the outer edge leans in) and the
    lintel over the opening, on the wall face (viewer at -Y)."""
    for sx in (-1, 1):
        xi = sx * OW / 2
        xo = sx * (OW / 2 + jw)
        out = [(xi, 0.0), (xo, 0.0), (xo - sx * batter, OH + lh), (xi, OH + lh)]
        front_prism(p, _ccw(out), depth, "jamb", bevel=0.02)
    front_prism(p, [(-OW / 2, OH), (OW / 2, OH), (OW / 2, OH + lh), (-OW / 2, OH + lh)], depth, "lintel", bevel=0.02)


def portal(name, OW, OH, jw, lh, ch, depth, batter=0.0, disc_span=None):
    p = Part(name)
    jambs_lintel(p, OW, OH, jw, lh, depth, batter)
    x_out = OW / 2 + jw
    ctop = OH + lh
    cove = _cornice(p, -x_out - 0.12, x_out + 0.12 - 0.0, ctop, ch, depth + ch * 0.55)
    winged_disc(p, 0.0, OH + lh * 0.52, -depth, disc_span or (OW * 0.75))
    return p, cove


def seal_leaf(side):
    """One leaf, built in its final frame (front = -Y = Godot +Z)."""
    W, H, T = 3.0, 7.5, 0.3
    name = "egypt_seal_door_l" if side < 0 else "egypt_seal_door_r"
    p = Part(name)
    p.box((0.0, 0.0, H / 2), (W, T, H), "cedar", bevel=0.01)
    # gilded edging round both faces
    for fy in (-1, 1):
        y = fy * (T / 2 + 0.012)
        for x0, x1, z0, z1 in ((-W / 2, W / 2, 0.0, 0.12), (-W / 2, W / 2, H - 0.12, H),
                               (-W / 2, -W / 2 + 0.12, 0.0, H), (W / 2 - 0.12, W / 2, 0.0, H)):
            p.box(((x0 + x1) / 2, y, (z0 + z1) / 2), (x1 - x0, 0.025, z1 - z0), "gilt", bevel=0.006)
        # bronze straps with rivets
        for z in (0.55, 3.3, 4.6):
            p.box((0.0, y, z), (W - 0.26, 0.03, 0.26), "bronze", bevel=0.008)
            for k in range(7):
                x = -W / 2 + 0.3 + k * (W - 0.6) / 6
                rv = p.lathe([(0.035, 0.0), (0.03, 0.02), (0.0, 0.03)], "bronze", segments=5, cap_bottom=False)
                p.move(rv, Matrix.Translation((x, y + fy * 0.015, z)) @ Matrix.Rotation(math.radians(-90 * fy), 4, 'X'))
    # the front's emblems, half of each on this leaf (the seam at the inner
    # edge: +X for the left leaf, -X for the right one)
    seam = W / 2 if side < 0 else -W / 2
    dirx = -1.0 if side < 0 else 1.0
    yb = -T / 2 - 0.01
    # the sun: gilded rays round the seal socket, 1.6 m up
    cz = 1.6
    R = 1.05
    n = 14
    for i in range(n):
        a0 = -math.pi / 2 + math.pi * i / n
        a1 = -math.pi / 2 + math.pi * (i + 1) / n
        r0, r1 = 0.42, R * 1.22 if i % 2 == 0 else R * 0.95
        pts = [(seam + dirx * r0 * math.cos(a0), cz + r0 * math.sin(a0)),
               (seam + dirx * r1 * math.cos((a0 + a1) / 2), cz + r1 * math.sin((a0 + a1) / 2)),
               (seam + dirx * r0 * math.cos(a1), cz + r0 * math.sin(a1))]
        front_prism(p, _ccw(pts), 0.03, "gilt", y_back=yb)
    ring = []
    for i in range(n + 1):
        a = -math.pi / 2 + math.pi * i / n
        ring.append((seam + dirx * 0.44 * math.cos(a), cz + 0.44 * math.sin(a)))
    inner = [(seam + dirx * 0.3 * math.cos(-math.pi / 2 + math.pi * i / n), cz + 0.3 * math.sin(-math.pi / 2 + math.pi * i / n))
             for i in range(n + 1)]
    for i in range(n):
        front_prism(p, _ccw([ring[i], ring[i + 1], inner[i + 1], inner[i]]), 0.05, "gilt", y_back=yb)
    pts = [(seam, cz - 0.3)] + inner[1:-1] + [(seam, cz + 0.3)]
    front_prism(p, _ccw(pts), 0.012, "socket", y_back=-T / 2 - 0.004)
    # the winged sun over the door: half a disc at the seam, one wing out to the edge
    wz = 6.35
    rd = 0.42
    half = [(seam, wz - rd)] + [(seam + dirx * rd * math.cos(-math.pi / 2 + math.pi * i / 10),
                                 wz + rd * math.sin(-math.pi / 2 + math.pi * i / 10)) for i in range(1, 10)] + [(seam, wz + rd)]
    front_prism(p, _ccw(half), 0.06, "gilt", y_back=yb)
    span = W - 0.25
    wing = [(seam + dirx * 0.38, wz + 0.2), (seam + dirx * span * 0.45, wz + 0.48), (seam + dirx * span * 0.8, wz + 0.5),
            (seam + dirx * span, wz + 0.28), (seam + dirx * span * 0.96, wz - 0.06), (seam + dirx * span * 0.7, wz - 0.3),
            (seam + dirx * span * 0.4, wz - 0.5), (seam + dirx * 0.38, wz - 0.42)]
    front_prism(p, _ccw(wing), 0.035, "wing", y_back=yb)
    cobra = p.lathe([(0.07, 0.0), (0.075, 0.2), (0.11, 0.34), (0.06, 0.42), (0.0, 0.44)], "cobra", segments=8)
    p.move(cobra, Matrix.Translation((seam + dirx * 0.5, yb - 0.06, wz - 0.82)))
    return p


def boarded():
    rng = random.Random(9)
    OW, OH = 2.0, 2.8
    root = Part("egypt_boarded_doorway")
    for sx in (-1, 1):
        root.box((sx * (OW / 2 - 0.05), -0.05, OH / 2 + 0.05), (0.1, 0.08, OH + 0.1), "batten", bevel=0.008)
    root.box((0.0, -0.05, OH - 0.05), (OW, 0.08, 0.1), "batten", bevel=0.008)
    parts = [root]
    heights = [0.3, 0.74, 1.18, 1.62, 2.06, 2.5]
    k = 1
    for z in heights:
        tilt = rng.uniform(-4.0, 4.0)
        ln = OW + rng.uniform(0.15, 0.35)
        pl = Part(f"plank_{k}", origin=(rng.uniform(-0.05, 0.05), -0.105, z), parent="egypt_boarded_doorway")
        f = pl.box((0.0, 0.0, 0.0), (ln, 0.025, rng.uniform(0.22, 0.27)), "plank", bevel=0.004)
        pl.move(f, Matrix.Translation(pl.origin) @ Matrix.Rotation(math.radians(tilt), 4, 'Y'))
        parts.append(pl)
        k += 1
    for sgn in (-1, 1):
        ln = math.hypot(OW, OH - 0.4)
        ang = math.degrees(math.atan2(OH - 0.4, OW)) * sgn
        pl = Part(f"plank_{k}", origin=(0.0, -0.135 - (0.03 if sgn > 0 else 0.0), OH / 2), parent="egypt_boarded_doorway")
        f = pl.box((0.0, 0.0, 0.0), (ln, 0.025, 0.18), "plank", bevel=0.004)
        pl.move(f, Matrix.Translation(pl.origin) @ Matrix.Rotation(math.radians(-ang), 4, 'Y'))
        parts.append(pl)
        k += 1
    sign = Part("sign", origin=(0.0, -0.19, 1.55), parent="egypt_boarded_doorway")
    f = sign.box((0.0, 0.0, 0.0), (0.92, 0.012, 0.44), "sign", bevel=0.003)
    sign.move(f, Matrix.Translation(sign.origin) @ Matrix.Rotation(math.radians(2.5), 4, 'Y'))
    parts.append(sign)
    return parts


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _jamb_canvas(w, h, seed, facing_right, crown, registers=1, small=False):
    """A jamb face: a red dado, then (registers of) the king offering toward
    the opening under columns of text, or for narrow jambs text columns with
    a cartouche."""
    c = np.zeros((h, w), dtype=np.int16)
    c[h - 20:h] = EP.INK["red"]
    c[h - 22:h - 20] = EP.INK["black"]
    import random as _r
    rng = _r.Random(seed)
    if small:
        n = max(1, (w - 2) // 12)
        cols = EP.text_columns(n, (h - 30) // 11, seed, col_w=12, cell=10, gap=1, cartouches=0.25)
        x = (w - cols.shape[1]) // 2
        c[4:4 + cols.shape[0], x:x + cols.shape[1]] = np.where(cols > 0, cols, c[4:4 + cols.shape[0], x:x + cols.shape[1]])
        return c
    reg_h = (h - 26) // registers
    for k in range(registers):
        base = h - 26 - k * reg_h
        fig_h = int(reg_h * 0.62)
        if registers > 1:
            gods = ("falcon", "jackal")
            EP.figure(c, int(w * (0.3 if facing_right else 0.7)), base - 4, fig_h, pose="adore", sex="m",
                      flip=not facing_right, seed=seed + k, crown=crown)
            EP.figure(c, int(w * (0.78 if facing_right else 0.22)), base - 4, int(fig_h * 0.94), pose="seated",
                      head=gods[k % 2], flip=facing_right, seed=seed + k + 3)
        else:
            EP.figure(c, int(w * (0.42 if facing_right else 0.58)), base - 4, fig_h, pose="adore", sex="m",
                      flip=not facing_right, seed=seed + k, crown=crown)
        bb = EP.block_border(w, 6)
        c[base - reg_h + 2:base - reg_h + 8] = bb
        rows = max(1, (reg_h - fig_h - 18) // 11)
        n = max(1, (w - 4) // 12)
        cols = EP.text_columns(n, rows, seed + 10 + k, col_w=12, cell=10, gap=1, cartouches=0.15)
        y = base - reg_h + 10
        x = (w - cols.shape[1]) // 2
        c[y:y + cols.shape[0], x:x + cols.shape[1]] = np.where(cols > 0, cols, c[y:y + cols.shape[0], x:x + cols.shape[1]])
    return c


def _lintel_canvas(w, h, seed, gap):
    c = np.zeros((h, w), dtype=np.int16)
    bb = EP.block_border(w, 6)
    c[0:6] = bb
    c[h - 6:h] = bb
    line = EP.text_line(w, seed)
    y = (h - 10) // 2
    clear = (w - gap) // 2
    c[y:y + 10, :clear] = np.where(line[:, :clear] > 0, line[:, :clear], 0)
    c[y:y + 10, w - clear:] = np.where(line[:, w - clear:] > 0, line[:, w - clear:], 0)
    return c


def portal_paint(OW, OH, jw, lh, seed, crown="khepresh", registers=1, small=False):
    """Front faces of the jambs and the lintel get their canvases (sunk and
    painted); everything else is sandstone. The model is built facing -Y and
    turned, so on its front faces u = the pre-turn x."""
    cache = {}

    def fn(ctx):
        s = E.sandstone(ctx, seed, center=6.0, strata=0.6)
        front = ctx.n[:, 1] > 0.9
        u = ctx.uvm[:, 0]
        z = ctx.p[:, 2]
        codes = np.full(ctx.N, -1, np.int16)
        rims = np.zeros(ctx.N, np.int16)
        tx = ctx.texel
        wpx = int(round(jw / tx))
        hpx = int(round(OH / tx))
        if "l" not in cache:
            cache["l"] = _jamb_canvas(wpx, hpx, seed, True, crown, registers, small)
            cache["r"] = _jamb_canvas(wpx, hpx, seed + 50, False, crown, registers, small)
            lw = int(round((OW + 2 * jw) / tx))
            cache["t"] = _lintel_canvas(lw, int(round(lh / tx)), seed + 7, int(round(OW * 0.8 / tx)))
        for key, u0, v0, mask in (("l", -OW / 2 - jw, 0.0, front & (u < -OW / 2) & (z < OH)),
                                  ("r", OW / 2, 0.0, front & (u > OW / 2) & (z < OH)),
                                  ("t", -OW / 2 - jw, OH, front & (z >= OH) & (z < OH + lh))):
            if not mask.any():
                continue
            c, r = E.sample(cache[key], u[mask], z[mask], tx, u0=u0, v0=v0)
            codes[mask] = c
            rims[mask] = r
        return E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.35, relief=-0.003)
    return fn


def wing_paint(ctx, seed=83):
    """Feathers of the winged disc: red coverts in scales, a blue band, long
    green primaries with dark quills."""
    s = E.sandstone(ctx, seed, center=6.0, strata=0.2)
    ix, iy = E.px(ctx)
    z = ctx.p[:, 2]
    zr = (z - z.min()) / max(z.max() - z.min(), 1e-6)
    codes = np.full(ctx.N, EP.INK["green"], np.int16)
    codes[zr > 0.45] = EP.INK["blue"]
    codes[zr > 0.72] = EP.INK["red"]
    quill = (zr <= 0.45) & (np.mod(ix, 4) == 0)
    codes[quill] = EP.INK["outline"]
    scale = (zr > 0.72) & (np.mod(ix + (iy // 3) * 2, 4) == 0)
    codes[scale] = EP.INK["yellow"]
    front = np.abs(ctx.n[:, 1]) > 0.5
    codes = np.where(front, codes, EP.INK["yellow"]).astype(np.int16)
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.25)


def wing_gilt(ctx, seed=87):
    """Gilded bronze wing on the seal leaves: rows of coverts and long
    primaries chased into the gold."""
    s = E.gold_leaf(ctx, seed)
    ix, iy = E.px(ctx)
    z = ctx.p[:, 2]
    zr = (z - z.min()) / max(z.max() - z.min(), 1e-6)
    quill = (zr <= 0.5) & (np.mod(ix, 5) == 0)
    row = (zr > 0.5) & ((np.mod(iy, 6) == 0) | (np.mod(ix + (iy // 6) * 3, 6) == 0))
    s.shade[quill | row] -= 2.5
    s.height = s.height - (quill | row) * 0.0015
    return s


def disc_paint(ctx, seed=89):
    s = Surface(ctx.N)
    s.use_ramp(P["eg_red"], shade=4.6 + ctx.fbm(8.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1)
               + ctx.edge(1.0) * 1.2 - (1.0 - ctx.ao) * 2.0)
    rim = ctx.edge_soft(3.0) > 0.3
    s.use_ramp(P["gold"], mask=rim, shade=np.full(ctx.N, 6.5))
    s.metal = np.where(rim, 1.0, 0.0)
    s.rough = np.where(rim, 0.3, 0.6)
    return s


def cobra_paint(ctx, seed=97):
    s = E.faience(ctx, seed, ramp="eg_green", center=3.8)
    return s


def cedar(ctx, seed=101):
    """Dark cedar planks (vertical boards 0.25 m), oiled."""
    s = _wood_core(ctx, P["timber"], 4.6, seed, ring_freq=6.0, contrast=1.1)
    u = ctx.uvm[:, 0]
    seam = (np.mod(u + 1e-4, 0.25) < ctx.texel) & (np.abs(ctx.n[:, 1]) > 0.5)
    s.shade[seam] -= 2.4
    s.shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.rough = np.full(ctx.N, 0.55)
    s.height = s.height - seam * 0.002
    return s


def socket_paint(ctx, seed=103):
    s = Surface(ctx.N)
    r = np.hypot(ctx.p[:, 0] - np.round(ctx.p[:, 0] / 1.5) * 1.5, ctx.p[:, 2] - 1.6)
    inner = r < 0.22
    s.use_ramp(P["bronze_metal"], shade=2.6 + ctx.fbm(20.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1))
    s.use_ramp(P["eg_black"], mask=inner, shade=np.full(ctx.N, 0.5) + _dither(ctx, 0.6, seed + 2))
    s.metal = np.where(inner, 0.0, 0.9)
    s.rough = np.where(inner, 0.8, 0.35)
    s.height = inner * -0.01
    return s


def pine(ctx, seed=107, center=5.4):
    s = _wood_core(ctx, P["pine_worn"], center, seed, ring_freq=9.0)
    s.shade -= ctx.cavity(3.0) * 1.5 + (1.0 - ctx.ao) * 3.0
    s.shade += ctx.edge(1.0) * 1.2
    s.rough = np.full(ctx.N, 0.8)
    return s


def plank(ctx, seed=109):
    """Rough builder's planks with nail heads near the ends and a splash of
    whitewash."""
    s = pine(ctx, seed, center=6.6)
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    front = np.abs(ctx.n[:, 1]) > 0.5
    nail = front & (np.mod(np.floor(u / ctx.texel), 37) < 2) & (np.mod(np.floor(v / ctx.texel), 13) < 2)
    s.use_ramp(P["iron"], mask=nail, shade=np.full(ctx.N, 5.0))
    splash = front & (ctx.fbm(3.0, 3, seed + 1) > 0.62)
    s.use_ramp(P["eg_white"], mask=splash & ~nail, shade=np.full(ctx.N, 4.0) + _dither(ctx, 0.8, seed + 2))
    return s


_SIGN = {}


def sign_paint(ctx, seed=113):
    """Plywood sign, stencilled REMONT in red and ZAKAZ WSTĘPU in black."""
    s = Surface(ctx.N)
    s.use_ramp(P["pine_worn"], shade=6.2 + ctx.fbm(9.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1)
               - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.85)
    front = ctx.n[:, 1] > 0.5
    if "big" not in _SIGN:
        _SIGN["big"] = pixelfont.trim(pixelfont.render("REMONT", bold=True))
        _SIGN["small"] = pixelfont.trim(pixelfont.render("ZAKAZ WSTĘPU"))
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    cu = np.median(u[front]) if front.any() else 0.0
    cv = np.median(v[front]) if front.any() else 0.0
    big = pixelfont.stamp(ctx, _SIGN["big"], cu, cv + 0.06, scale=2) & front
    small = pixelfont.stamp(ctx, _SIGN["small"], cu, cv - 0.12, scale=1) & front
    s.use_ramp(P["enamel_red"], mask=big, shade=np.full(ctx.N, 5.0) + _dither(ctx, 0.6, seed + 2))
    s.use_ramp(P["eg_black"], mask=small, shade=np.full(ctx.N, 1.5))
    return s


def build():
    sand = lambda c: E.sandstone(c, 121, center=6.0)  # noqa: E731
    common = {"sandstone": sand, "torus": E.binding, "wing": wing_paint, "disc": disc_paint, "cobra": cobra_paint}
    out = []
    p, cove = portal("egypt_portal_4m", 4.0, 4.5, 1.0, 1.1, 0.95, 0.32)
    _roll_frame(p, 3.0, 5.6, 0.07, -0.32)
    out.append(kit("egypt_portal_4m", [p], {**common, "jamb": portal_paint(4.0, 4.5, 1.0, 1.1, 131),
                                             "lintel": portal_paint(4.0, 4.5, 1.0, 1.1, 131),
                                             "cove": lambda c, L=cove: E.leaves(c, cove_len=L)},
                   wall=True, ao_dist=0.5))
    p, cove = portal("egypt_doorframe_2x2_8", 2.0, 2.8, 0.45, 0.6, 0.6, 0.22, disc_span=1.8)
    _roll_frame(p, 1.45, 3.4, 0.05, -0.22)
    pp = portal_paint(2.0, 2.8, 0.45, 0.6, 137, small=True)
    out.append(kit("egypt_doorframe_2x2_8", [p], {**common, "jamb": pp, "lintel": pp,
                                                  "cove": lambda c, L=cove: E.leaves(c, cove_len=L)},
                   wall=True, ao_dist=0.4))
    p, cove = portal("egypt_portal_great", 6.0, 7.5, 2.2, 1.5, 1.3, 0.6, batter=0.3, disc_span=7.5)
    pg = portal_paint(6.0, 7.5, 2.2, 1.5, 139, registers=2)
    out.append(kit("egypt_portal_great", [p], {**common, "jamb": pg, "lintel": pg,
                                               "cove": lambda c, L=cove: E.leaves(c, cove_len=L)},
                   wall=True, ao_dist=0.6, ao_stride=4))
    door_fns = {"cedar": cedar, "bronze": M.bronze, "gilt": E.gold_leaf, "socket": socket_paint,
                "wing": wing_gilt, "cobra": cobra_paint}
    out.append(kit("egypt_seal_door_l", [seal_leaf(-1)], door_fns, ppm=96, ground=0.0, built_final=True,
                   ao_dist=0.3, markers=[("SealSocket", (1.5, -0.165, 1.6), None)]))
    out.append(kit("egypt_seal_door_r", [seal_leaf(1)], door_fns, ppm=96, ground=0.0, built_final=True,
                   ao_dist=0.3, preview=False))
    out.append(kit("egypt_boarded_doorway", boarded(), {"batten": pine, "plank": plank, "sign": sign_paint},
                   ppm=128, wall=True, ao_dist=0.25))
    return out
