"""Gallery portrait (the portrait enemy, and ordinary paintings): a gilded
baroque frame with sculpted acanthus corners, shells on the sides and a
crest, round a 0.72 x 0.9 m canvas. Ten canvases are painted by
artlib/canvas.py: six period portraits (their eyes all sit at the same
place) and four harmless pictures.

Mounting: origin on the wall plane (y = 0) at the canvas centre; the
picture faces -Y in Blender = +Z in Godot, like the other props. Hang it
with its origin on the wall; the frame is 0.98 x 1.16 m, 0.12 m deep.
Parts:
    frame    (0, 0, 0)                 the gilded frame (closed at the back)
    canvas   (0, 0, 0)                 the painting, UV 0..1; material "canvas_<name>"
    eyes     (0, -0.0315, 0.195)       two almond eye patches 1.5 mm in front of the
                                       canvas; material "portrait_eyes"
Marker: WeakPoint (0, -0.032, 0.195) between the eyes (child of eyes).

Canvases (texture sets; swap the canvas material by name):
    portraits:  canvas_aristocrat (default), canvas_lady_fan, canvas_general,
                canvas_child_dog, canvas_bishop, canvas_merchant
    harmless:   canvas_landscape, canvas_seascape, canvas_still_life,
                canvas_flowers (hide the "eyes" part on these)
    ArtLibrary.instance(&"portrait", {"canvas_aristocrat": "canvas_bishop"})
Moving eyes: give the instance its own materials (ArtLibrary.own_materials)
and slide the "portrait_eyes" material's uv1_offset: x -0.2 .. +0.2 moves
the irises to the viewer's right .. left, y -0.08 .. +0.08 moves them down
.. up (Godot UVs grow downward). 0 = looking straight out of the picture.
"""
import math

import numpy as np

from artlib import canvas, kit, sculpt
from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model
from artlib.sculpt import blob

CW, CH = canvas.CANVAS_W, canvas.CANVAS_H
FW = 0.13                   # frame width
CANVAS_Y = -0.03            # canvas plane (3 cm off the wall)
EYES_Y = CANVAS_Y - 0.0015
PROFILE = [(0.042, -0.006), (0.064, 0.0), (0.074, 0.022), (0.098, 0.04), (0.104, 0.062), (0.092, 0.084),
           (0.074, 0.098), (0.08, 0.114), (0.058, FW), (0.0, FW), (0.0, 0.02)]


def gold(ctx, seed=651):
    """Gilding: gold leaf, rubbed through to the red bole only on the most
    worn edges."""
    s = M.brass(ctx, seed, ramp="gold", tarnish_amount=1.0, grain=0.5)
    s.shade += 0.6
    worn = (ctx.edge_soft(2.5) > 0.5) & (ctx.fbm(14.0, 2, seed + 5) > 0.45)
    s.use_ramp(M.P["bole"], mask=worn, shade=np.full(ctx.N, 1.0) + M._dither(ctx, 1.5, seed + 6))
    s.metal = np.where(worn, 0.0, s.metal)
    s.rough = np.where(worn, 0.6, s.rough)
    return s


def moulding(ctx):
    """The carved bands of the swept frame, in its (along, across) metre
    UVs: pearls on the sight edge, flutes in the cove, egg-and-dart on the
    torus, a rope twist on the outer bead."""
    s = gold(ctx, seed=653)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    fu = np.mod(u / 0.012, 1.0) - 0.5
    pearl = (v < 0.021) & (fu ** 2 + ((v - 0.0105) / 0.012) ** 2 < 0.17)
    pearl_gap = (v < 0.021) & ~pearl
    flute = (v > 0.026) & (v < 0.045) & (np.mod(u / 0.008, 1.0) < 0.35)
    eu = np.mod(u / 0.036, 1.0) - 0.5
    ev = (v - 0.101) / 0.019
    ring = np.sqrt(eu ** 2 / 0.1 + ev ** 2)
    ridge = (v > 0.08) & (v < 0.122)
    egg = ridge & (ring < 0.85)
    outline = ridge & (ring >= 0.85) & (ring < 1.15)
    dart = ridge & (np.abs(eu) > 0.42) & (np.abs(ev) < 0.8)
    rope = (v > 0.15) & (v < 0.19) & (np.mod((u + v * 1.4) / 0.014, 1.0) < 0.28)
    s.shade += pearl * (1.0 + (fu < 0) * 0.8) + egg * (0.8 - ev * 0.8)
    s.shade -= pearl_gap * 2.0 + flute * 2.2 + outline * 2.6 + dart * 1.6 + rope * 2.2
    s.height = s.height + pearl * 0.0012 + egg * 0.001 - flute * 0.0008 - outline * 0.0008 - rope * 0.0008
    return s


FNS = {"gold": gold, "moulding": moulding}


def _ornament_blobs():
    """Acanthus corners, shells mid-side, a crest on top: flat clay relief
    lying on the frame's ridge (y ~ -0.1)."""
    b = []
    ox, oz = CW / 2 + 0.066, CH / 2 + 0.066
    y = -0.104
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = sx * ox, sz * oz
            b.append(blob((cx, y - 0.008, cz), (0.046, 0.024, 0.046)))                        # boss
            b.append(blob((cx - sx * 0.006, y - 0.028, cz - sz * 0.006), (0.021, 0.014, 0.021)))
            for k, (dx, dz) in enumerate(((1, 0), (0, 1))):
                for j, (off, ln, w) in enumerate(((0.085, 0.062, 0.026), (0.16, 0.045, 0.018))):
                    px, pz = cx - sx * dx * off, cz - sz * dz * off
                    b.append(blob((px, y - 0.004, pz), (ln if dx else w, 0.013, w if dx else ln)))
                    b.append(blob((px - sx * dx * ln * 0.8, y - 0.01, pz - sz * dz * ln * 0.8), 0.011))
            for a in (0.15, 0.5, 0.85):                                                  # leaf fingers outward
                ang = math.pi / 2 * a
                px, pz = cx + sx * math.cos(ang) * 0.06, cz + sz * math.sin(ang) * 0.06
                b.append(blob((px, y + 0.002, pz), (0.018, 0.012, 0.018)))
    # shells mid-side (and a larger crest on top)
    for cx, cz, ux, uz, scale in ((0, oz, 0, 1, 1.35), (0, -oz, 0, -1, 1.0), (ox, 0, 1, 0, 1.0), (-ox, 0, -1, 0, 1.0)):
        b.append(blob((cx, y - 0.008, cz), (0.022 * scale, 0.016, 0.022 * scale)))
        for k in range(5):
            a = (k - 2) * 0.42
            dx = ux * math.cos(a) - uz * math.sin(a)
            dz = ux * math.sin(a) + uz * math.cos(a)
            px, pz = cx + dx * 0.035 * scale, cz + dz * 0.035 * scale
            rot = (0.0, -math.degrees(math.atan2(dz, dx)), 0.0)
            b.append(blob((px, y - 0.003, pz), (0.026 * scale, 0.011, 0.009 * scale), rot=rot))
        for s in (-1, 1):                                                                 # scrolls either side
            px, pz = cx + uz * s * 0.07 * scale, cz + ux * s * 0.07 * scale
            b.append(blob((px, y, pz), (0.03 if uz else 0.012, 0.01, 0.012 if uz else 0.03)))
            b.append(blob((px + uz * s * 0.03, y - 0.008, pz + ux * s * 0.03), 0.012))
    return b


def _eyes(p):
    """Two almond patches with UVs into the eye texture (locked, 0..1 over
    EYE_TEX_W x EYE_TEX_H round each eye)."""
    faces = []
    for sx in (-1, 1):
        ex, ez = sx * canvas.EYE_DX, canvas.EYE_Y
        pts = []
        for d in np.linspace(-1, 1, 7):
            pts.append((d, (1 - d * d) * 1.05))
        for d in np.linspace(1, -1, 7)[1:-1]:
            pts.append((d, -(1 - d * d) * 0.85))
        verts, uvs = [], []
        for d, h in pts:
            x = ex + d * canvas.EYE_W / 2 * 0.95
            z = ez + h * canvas.EYE_H / 2 * 0.9
            verts.append(p.bm.verts.new((x, EYES_Y, z)))
            uvs.append((0.5 + (x - ex) / canvas.EYE_TEX_W, 0.5 + (z - ez) / canvas.EYE_TEX_H))
        f = p._face(verts, "eyes", smooth=False)
        f.normal_update()
        if f.normal.y > 0:
            f.normal_flip()
        for loop in f.loops:
            loop[p.uv].uv = uvs[verts.index(loop.vert)]
        f[p.lock] = 1
        faces.append(f)
    return faces


def build():
    frame = Part("frame")
    x0, x1, z0, z1 = -CW / 2, CW / 2, -CH / 2, CH / 2
    frame.sweep(PROFILE, [(x0, z0), (x0, z1), (x1, z1), (x1, z0)], "moulding", closed=True, uv_break=3.6)
    me = sculpt.metaball_mesh(_ornament_blobs(), resolution=0.0055)
    sculpt.cut(me, [((0, -0.07, 0), (0, 1, 0))])
    me = sculpt.decimate(me, 1500)
    sculpt.into_part(frame, me, "gold")
    cnv = Part("canvas")
    kit.screen(cnv, (0.0, CANVAS_Y, 0.0), CW, CH, "canvas", bulge=0.0, nx=1, ny=1)
    eyes = Part("eyes", origin=(0.0, EYES_Y, canvas.EYE_Y))
    _eyes(eyes)
    textures = {"canvas_" + n: canvas.paint(n) for n in canvas.ALL}
    textures["portrait_eyes"] = canvas.eye_texture()
    sheet = canvas.contact_sheet({n: textures["canvas_" + n]["albedo"] for n in canvas.ALL}, canvas.ALL, scale=2)
    return Model("portrait", [frame, cnv, eyes], FNS, kinds={"canvas": "canvas_aristocrat", "eyes": "portrait_eyes"},
                 ppm=256, ground=None, ao_dist=0.06, ao_rays=12, ao_stride=2,
                 markers=[("WeakPoint", (0.0, EYES_Y - 0.0005, canvas.EYE_Y), "eyes")],
                 textures=textures, sheets={"portrait_canvases": sheet}, preview_elevation=6.0,
                 preview_yaws=(-30.0, 0.0, 35.0, 60.0),
                 preview_extra=[("face", (0.0, CANVAS_Y, canvas.EYE_Y - 0.03), 0.16, 0.0, 0.0),
                                ("corner", (CW / 2 + 0.06, -0.08, CH / 2 + 0.06), 0.14, -25.0, 15.0)])
