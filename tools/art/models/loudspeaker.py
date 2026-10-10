"""Wall loudspeaker of the museum's System (the "Virtual Curator"): a modern
grey-white plastic box with a band of punched holes in its front (texture),
hung on a short steel U-bracket, a small amber standby lens at the lower
right. Deliberately new and plain among the 19th-century plaster: the
System was installed last month. 0.34 x 0.17 x 0.24 m.

Origin on the wall plane (y = 0) at the centre of the bracket plate; the
box hangs in front of it toward +Y (Godot -Z: the marker's front faces the
room, like every prop). Parts:
    loudspeaker  (0, 0, 0)   plate, bracket arms, housing, grille, lens
"""
import numpy as np

from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

W, H, D = 0.34, 0.24, 0.14      # the housing
PLATE, GAP = 0.012, 0.02        # wall plate, plate to housing (the bracket arms)
Y0 = PLATE + GAP                # back of the housing
PPM = 256                       # atlas texels per metre (the grille is drawn on this grid)


def shell(ctx):
    return M.plastic(ctx, "enamel_white", 5.4, seed=611, rough=0.62, scuff=0.35, speckle=0.3)


def grille(ctx):
    """The front plate: the same plastic with a band of punched holes, snapped
    to the texel grid (a 2 x 2 texel hole every 4 texels: crisp at 256 px/m,
    finer pitches alias into moire)."""
    s = shell(ctx)
    front = ctx.n[:, 1] > 0.7
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tu, tv = np.floor(u * PPM).astype(int), np.floor(v * PPM).astype(int)
    holes = front & (tu % 4 < 2) & (tv % 4 < 2) & (np.abs(u) < 0.14) & (np.abs(v) < 0.08)
    s.use_ramp(M.P["plastic_black"], mask=holes, shade=np.full(ctx.N, 2.2))
    s.height = s.height - holes * 0.0015
    s.rough = np.where(holes, 0.95, s.rough)
    return s


def steel(ctx):
    return M.steel(ctx, seed=613, center=6.8, dent=0.08, rust=0.15, polish=0.3)


FNS = {"shell": shell, "grille": grille, "steel": steel, "lens": M.lamp_warm}


def build():
    p = Part("loudspeaker")
    p.box((0, PLATE / 2, 0), (0.10, PLATE, 0.16), "steel", bevel=0.002)                 # wall plate
    for z in (-0.085, 0.085):                                                           # the U-bracket's arms
        p.box((0, PLATE + GAP / 2, z), (0.05, GAP + 0.004, 0.012), "steel", bevel=0.002)
    p.box((0, Y0 + D / 2, 0), (W, D, H), "shell", bevel=0.008)                          # housing
    p.box((0, Y0 + D + 0.002, 0), (W - 0.03, 0.006, H - 0.03), "grille", bevel=0.002)   # front plate, holes in the texture
    p.box((W / 2 - 0.03, Y0 + D + 0.006, -H / 2 + 0.025), (0.010, 0.004, 0.006), "lens")  # standby lens
    return Model("loudspeaker", [p], FNS, ppm=PPM, ground=None, ao_dist=0.08, ao_planes=(("y", 0.0),),
                 preview_elevation=8.0)
