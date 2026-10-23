"""Floor I's roof, the plant deck: the air handlers (two of one model).

  roof_air_handler  a packaged air-handling unit of the 1960s on two steel
                    skids and rubber pads: a blue-grey enamelled cabinet of
                    three sections - the intake (louvres on its end and its
                    front, a filter door), the coil (access doors with
                    hinges and lever handles on both long faces) and the
                    fan (a round discharge on the roof under a wire guard,
                    the propeller below it); a rain cap along the top, the
                    makers' plate, the isolator and its conduit, a pipe
                    pair out of the back, grime below the louvres. 2.4 x
                    1.6 x 1.4 m (Godot x, y, z) = its greybox box (the box
                    is its collision); the top is flat round the middle
                    (a pickup lies on the first unit). 128 px/m.

Kit convention: origin = the middle of the footprint on the deck; built
front +Y in Blender (= Godot -Z).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import court_materials as CM
from artlib import kit as K
from artlib import materials as M
from artlib import roof_materials as RM
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither

L = 2.28                 # the cabinet's length (x)
D = 1.24                 # its depth (y)
SKID = 0.12              # the skids' height (the cabinet stands on them)
TOP = 1.53               # the cabinet's roof
INTAKE = (-L / 2, -0.52)     # the sections along x
COIL = (-0.52, 0.3)
FAN = (0.3, L / 2)
FAN_X = 0.72
FAN_R = 0.36


def skids(p):
    for sy in (-1, 1):
        y = sy * (D / 2 - 0.12)
        # a channel: two flanges and a web, toes outward
        p.box((0.0, y, 0.01), (L + 0.04, 0.1, 0.02), "skid")
        p.box((0.0, y, SKID - 0.01), (L + 0.04, 0.1, 0.02), "skid")
        p.box((0.0, y - sy * 0.045, SKID * 0.5), (L + 0.04, 0.012, SKID - 0.02), "skid")
        for x in (-L / 2 + 0.2, L / 2 - 0.2):
            p.box((x, y, 0.015), (0.16, 0.14, 0.03), "rubber")
    # cross members between the skids
    for x in (-0.8, 0.0, 0.8):
        p.box((x, 0.0, SKID - 0.03), (0.08, D - 0.32, 0.06), "skid")


def cabinet(p):
    z0 = SKID
    h = TOP - z0
    p.box((0.0, 0.0, z0 + h / 2), (L, D, h), "cabinet", bevel=0.012)
    # the frame's posts between the sections, standing proud of the panels
    for x in (INTAKE[1], COIL[1]):
        for sy in (-1, 1):
            p.box((x, sy * (D / 2 + 0.008), z0 + h / 2), (0.07, 0.02, h - 0.02), "cabinet")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (L / 2 - 0.02), sy * (D / 2 - 0.02), z0 + h / 2), (0.06, 0.06, h + 0.004), "cabinet")
    # the rain cap: a drip edge round the roof
    p.box((0.0, 0.0, TOP + 0.012), (L + 0.05, D + 0.05, 0.024), "cap", bevel=0.006)
    p.box((0.0, 0.0, z0 + 0.025), (L + 0.03, D + 0.03, 0.05), "skid")   # the base angle


def _louvres(p, center, width, height, normal, n=7):
    """A louvred intake on the face at ``center`` whose outward normal is
    ``normal`` (x or y): a dark backing on the face, a frame round it,
    slats tilted down and out standing proud of it."""
    cx, cy, cz = center
    nx, ny = normal
    if nx:
        p.box((cx + nx * 0.003, cy, cz), (0.006, width, height), "dark")
        for dz in (-1, 1):
            p.box((cx + nx * 0.025, cy, cz + dz * (height / 2 - 0.02)), (0.05, width + 0.04, 0.04), "cabinet")
        for dy in (-1, 1):
            p.box((cx + nx * 0.025, cy + dy * (width / 2), cz), (0.05, 0.04, height), "cabinet")
    else:
        p.box((cx, cy + ny * 0.003, cz), (width, 0.006, height), "dark")
        for dz in (-1, 1):
            p.box((cx, cy + ny * 0.025, cz + dz * (height / 2 - 0.02)), (width + 0.04, 0.05, 0.04), "cabinet")
        for dx in (-1, 1):
            p.box((cx + dx * (width / 2), cy + ny * 0.025, cz), (0.04, 0.05, height), "cabinet")
    pitch = (height - 0.08) / n
    for k in range(n):
        z = cz - height / 2 + 0.04 + pitch * (k + 0.5)
        if nx:
            f = p.box((0.0, 0.0, 0.0), (0.06, width - 0.02, 0.006), "louvre")
            p.move(f, Matrix.Translation((cx + nx * 0.026, cy, z)) @ Matrix.Rotation(nx * math.radians(40), 4, 'Y'))
        else:
            f = p.box((0.0, 0.0, 0.0), (width - 0.02, 0.06, 0.006), "louvre")
            p.move(f, Matrix.Translation((cx, cy + ny * 0.026, z)) @ Matrix.Rotation(-ny * math.radians(40), 4, 'X'))


def _door(p, x0, x1, sy, z0, z1, hinge_left=True):
    """An access door on the long face ``sy`` (proud by a hair), its hinges
    on one side, a lever handle on the other."""
    y = sy * (D / 2 + 0.006)
    p.box(((x0 + x1) / 2, y, (z0 + z1) / 2), (x1 - x0, 0.012, z1 - z0), "door")
    hx = x0 + 0.03 if hinge_left else x1 - 0.03
    for z in (z0 + 0.15, z1 - 0.15):
        K.seg(p, (hx, y + sy * 0.012, z - 0.05), (hx, y + sy * 0.012, z + 0.05), [(0.012, 0.0), (0.012, 1.0)], "steel",
              segments=6)
    lx = x1 - 0.08 if hinge_left else x0 + 0.08
    zm = (z0 + z1) / 2
    p.box((lx, y + sy * 0.012, zm), (0.04, 0.012, 0.1), "steel")
    p.box((lx, y + sy * 0.03, zm - 0.03), (0.022, 0.03, 0.14), "steel")


def sections(p):
    zm = (SKID + TOP) / 2
    # the intake: louvres on the end (-x) and on the front, a filter door at the back
    _louvres(p, (-L / 2 - 0.005, 0.0, zm + 0.08), D - 0.36, 0.86, (-1, 0))
    _louvres(p, ((INTAKE[0] + INTAKE[1]) / 2 + 0.03, D / 2 + 0.005, zm + 0.08), 0.5, 0.86, (0, 1))
    _door(p, INTAKE[0] + 0.1, INTAKE[1] - 0.06, -1, SKID + 0.12, TOP - 0.12, hinge_left=False)
    # the coil: a door on each long face
    for sy in (-1, 1):
        _door(p, COIL[0] + 0.06, COIL[1] - 0.06, sy, SKID + 0.1, TOP - 0.1, hinge_left=sy > 0)
    # the fan section: a bolted panel each side, the motor's door at the front
    _door(p, FAN[0] + 0.06, FAN[1] - 0.1, 1, SKID + 0.1, TOP - 0.1, hinge_left=True)
    p.box(((FAN[0] + FAN[1]) / 2 - 0.02, -(D / 2 + 0.006), zm), (FAN[1] - FAN[0] - 0.16, 0.012, TOP - SKID - 0.2), "door")


def fan(p):
    """The discharge on the roof: a round shroud striped for danger, the
    propeller in it, the wire guard over it (the top of the unit)."""
    z = TOP + 0.024
    shroud = [(FAN_R + 0.04, z), (FAN_R + 0.04, z + 0.02), (FAN_R + 0.01, z + 0.02), (FAN_R + 0.01, z)]
    f = p.lathe(shroud, "hazard", segments=20, cap_bottom=False, cap_top=False)
    p.move(f, Matrix.Translation((FAN_X, 0.0, 0.0)))
    p.lathe([(FAN_R + 0.012, z + 0.002), (0.0, z + 0.002)], "dark", segments=20, center=(FAN_X, 0.0, 0.0),
            cap_bottom=False, cap_top=False)
    # the propeller: a hub and four blades, pitched
    K.seg(p, (FAN_X, 0.0, z + 0.002), (FAN_X, 0.0, z + 0.03), [(0.07, 0.0), (0.07, 0.6), (0.03, 1.0)], "steel",
          segments=8)
    for k in range(4):
        a = math.tau * k / 4 + 0.3
        f = p.box((0.0, 0.0, 0.0), (FAN_R - 0.09, 0.1, 0.006), "blade")
        p.move(f, Matrix.Translation((FAN_X + math.cos(a) * (FAN_R * 0.5 + 0.02), math.sin(a) * (FAN_R * 0.5 + 0.02),
                                      z + 0.014)) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(math.radians(15), 4, 'X'))
    # the guard: two rings and four bars over the top
    zg = z + 0.032
    for r in (FAN_R + 0.02, FAN_R * 0.55):
        pts = [(FAN_X + r * math.cos(math.tau * k / 16), r * math.sin(math.tau * k / 16), zg) for k in range(17)]
        p.tube(pts, 0.007, "guard", sides=4, caps=False)
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        p.tube([(FAN_X + math.cos(a) * (FAN_R + 0.03), math.sin(a) * (FAN_R + 0.03), zg - 0.012),
                (FAN_X + math.cos(a) * 0.05, math.sin(a) * 0.05, zg + 0.004)], 0.007, "guard", sides=4)
    K.seg(p, (FAN_X, 0.0, zg - 0.004), (FAN_X, 0.0, zg + 0.01), [(0.05, 0.0), (0.05, 1.0)], "guard", segments=8)


def fittings(p):
    """The isolator and its conduit, the pipe pair out of the back, a duct
    collar into the deck, the makers' plate."""
    y = D / 2 + 0.01
    p.box((-0.26, y + 0.025, 1.06), (0.18, 0.05, 0.24), "isolator", bevel=0.008)
    p.box((-0.26 + 0.1, y + 0.04, 1.06), (0.03, 0.03, 0.12), "steel")
    p.tube([(-0.26, y + 0.02, 0.94), (-0.26, y + 0.02, 0.4), (-0.24, y + 0.02, 0.3), (-0.18, y + 0.02, 0.24),
            (0.2, y + 0.02, 0.24), (0.24, y + 0.015, 0.2), (0.24, y, 0.14)], 0.014, "steel", sides=6)
    # the pipe pair out of the back, down to the deck
    yb = -(D / 2 + 0.01)
    for k, x in enumerate((-0.1, 0.06)):
        p.tube([(x, yb + 0.02, 0.56), (x, yb - 0.03, 0.56), (x, yb - 0.04, 0.53), (x, yb - 0.04, 0.15), (x, yb - 0.04, 0.0)],
               0.026, "pipe" if k == 0 else "pipe_lag", sides=8)
    # the makers' plate on the coil section's front door
    p.box(((COIL[0] + COIL[1]) / 2 + 0.05, D / 2 + 0.014, TOP - 0.34), (0.22, 0.006, 0.12), "plate")


def build_unit():
    p = Part("roof_air_handler")
    skids(p)
    cabinet(p)
    sections(p)
    fan(p)
    fittings(p)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def enamel(ctx):
    """The cabinet's stove enamel: blue-grey, sun-chalked on top, screws
    along the panel edges, grime run down below the louvres."""
    s = RM.painted_plate(ctx, ramp="air_blue", center=5.6, seed=901, rust=0.7, runs=(SKID + 0.08,), run_len=0.06)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    side = np.abs(ctx.n[:, 1]) > 0.7
    # screws every 15 cm along the top and bottom of the long faces
    head = np.zeros(ctx.N, dtype=bool)
    for h in (SKID + 0.05, TOP - 0.035):
        m, _ = RM.dots(x, z - h, 0.15, 0.007)
        head |= side & m
    RM.rivet_rows(ctx, s, head, ramp="air_blue", shade=7.4)
    # grime below the intake (the air drawn in leaves its soot)
    soot = (x < INTAKE[1]) & (z < SKID + 0.6) & (ctx.fbm(np.array([6.0, 6.0, 1.5]), 2, 903) > -0.1)
    s.shade = np.where(soot & ~head, s.shade - 1.6, s.shade)
    RM.droppings(ctx, s, amount=0.5, seed=905)
    return s


def door(ctx):
    s = RM.painted_plate(ctx, ramp="air_blue", center=6.0, seed=911, rust=0.5)
    s.shade -= ctx.edge_soft(2.0) * 0.8
    return s


def plate(ctx):
    """The makers' plate: cast brass, lines of raised lettering bright on a
    tarnished ground, a tarnished rim."""
    s = M.brass(ctx, 923)
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    cx, cz = (COIL[0] + COIL[1]) / 2 + 0.05, TOP - 0.34
    face = ctx.n[:, 1] > 0.5
    inner = (np.abs(x - cx) < 0.095) & (np.abs(z - cz) < 0.045)
    letters = inner & (np.abs(np.mod(z - cz + 0.06, 0.03) - 0.015) < 0.006) & (ctx.fbm(np.array([90.0, 9.0, 9.0]), 1, 925) > -0.2)
    ground = face & ~letters
    s.use_ramp(P["brass_tarnish"], mask=ground, shade=np.full(ctx.N, 2.0) + _dither(ctx, 0.6, 927) + inner * 0.8)
    return s


def hazard(ctx):
    """Yellow and black hazard stripes on the fan's shroud."""
    s = RM.painted_plate(ctx, ramp="wing_egypt", center=6.2, seed=931, rust=0.6, fade=0.4)
    a = np.arctan2(ctx.p[:, 1], ctx.p[:, 0] - FAN_X)
    black = np.mod(a / (math.tau / 16) + ctx.p[:, 2] * 8.0, 1.0) < 0.5
    s.use_ramp(P["formline_black"], mask=black, shade=np.full(ctx.N, 2.4) + _dither(ctx, 0.8, 933))
    return s


def isolator(ctx):
    s = RM.painted_plate(ctx, ramp="formline_red", center=3.8, seed=941, rust=0.5, fade=0.3)
    return s


def pipe_lag(ctx):
    """Lagged pipe: canvas wrapping painted cream, bands of tape."""
    s = CM.dome_cream(ctx, 951, center=4.6)
    s.shade += np.where(np.abs(np.mod(ctx.p[:, 2], 0.2) - 0.1) < 0.012, -1.4, 0.0)
    return s


UNIT_FNS = {
    "cabinet": enamel, "cap": lambda c: RM.painted_plate(c, ramp="air_blue", center=6.6, seed=961, rust=0.9, fade=1.5),
    "door": door, "skid": lambda c: RM.roof_steel(c, 963, center=2.6, rust=1.0),
    "rubber": lambda c: CM.cast_iron(c, 965, center=1.4), "dark": lambda c: CM.cast_iron(c, 966, center=0.8),
    "louvre": lambda c: RM.painted_plate(c, ramp="air_blue", center=5.0, seed=967, rust=0.8),
    "steel": lambda c: RM.galvanised(c, 968, center=4.4), "guard": lambda c: RM.galvanised(c, 969, center=5.0),
    "blade": lambda c: RM.galvanised(c, 970, center=3.6), "pipe": lambda c: CM.cast_iron(c, 971, center=3.0),
    "pipe_lag": pipe_lag, "plate": plate, "isolator": isolator,
}


def build():
    return [kit("roof_air_handler", [build_unit()], UNIT_FNS, ppm=128, built_final=True, ground=0.0, ao_dist=0.3,
                ao_rays=10, ao_stride=2, preview_yaws=(-35.0, 35.0, 145.0, 215.0), preview_elevation=14.0)]
