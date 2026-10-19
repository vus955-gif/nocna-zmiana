"""The pickups' colour language, shared with the game (backlog #11, #43).

Per pickup model: its colour (sRGB hex; src/weapons/weapon_palette.gd has
the same numbers - the weapon's HUD slot colour, the rim light, the greybox -
and tests/unit/test_weapon_palette.gd keeps the two files in step) and the
slot digit of the weapon it feeds (WeaponHolder.SLOT_ORDER + 1; the medkit
carries none).

Helpers for the model scripts:
    rgb(name)                 the colour as (3,) sRGB floats
    ramp(name, ...)           a seven-step pixel ramp (dark -> light) of it; register()
                              puts every ramp into materials.P as "pk_<name>" so the
                              stock material functions (plastic, paint, cardboard)
                              can take it by name
    digit(name)               the bold slot digit as a trimmed pixelfont bitmap
    face_uv(point, normal)    geo.box_project's (u, v) of a point on a face with this
                              dominant normal (to centre a stamp on a moved lid)
    accent(s, mask, name, k)  the emissive accent: the colour at strength k on a mask
    glow(s, mask, k)          the surface's own colours emitted at strength k on a mask
                              (a print that is seen in the dark without shining)
"""
import numpy as np

from artlib import materials as M
from artlib import pixelfont

PALETTE = {
    "ammo_pistol": ("#4d73ff", "2"),         # blued steel; the blue cartridge boxes of the thirties
    "ammo_shells": ("#eb1f1a", "3"),         # red hulls
    "ammo_rifle": ("#b8d940", "4"),          # the olive crate's stencil, lit
    "ammo_flares": ("#ff6b0d", "5"),         # signal orange, with white bands
    "ammo_rifle_hunt": ("#33b85c", "6"),     # hunter green card
    "ammo_harpoon": ("#33c7d9", "7"),        # sea: the whalers' painted marks
    "ammo_hwacha": ("#ad5cf2", "8"),         # violet-dyed paper and silk
    "medkit": ("#fff5e6", ""),               # white enamel (the one white pickup)
}
## How strongly a print / stencil / band emits its own colour (the exhibit
## shader gives an awake pickup x1.2 of ArtLibrary's emission 1.0): seen in
## the dark, no lamp. Digits and tags a little more.
PRINT = 0.3
MARK = 0.5


def rgb(name):
    h = PALETTE[name][0]
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)])


def ramp(name, steps=7, lo=0.14, hi=1.0, lift=0.18):
    """Pixel ramp (dark -> light) of the model's colour: the colour scaled
    down to ``lo`` (the darks a little desaturated), up to ``hi``, the
    brightest step lifted toward white by ``lift``."""
    c = rgb(name)
    grey = c.mean()
    out = []
    for t in np.linspace(lo, hi, steps):
        k = (t - lo) / (hi - lo)
        out.append((c * (0.85 + 0.15 * k) + grey * (0.15 - 0.15 * k)) * t)
    out[-1] = c * hi + (1.0 - c * hi) * lift
    return np.clip(np.array(out), 0.0, 1.0)


def register():
    """materials.P["pk_<name>"] = ramp(name) for every pickup."""
    for name in PALETTE:
        M.P.setdefault("pk_" + name, ramp(name))


def digit(name, bold=True):
    return pixelfont.trim(pixelfont.render(PALETTE[name][1], bold=bold))


def face_uv(point, normal):
    """box_project's (u, v) in metres of ``point`` on a face whose dominant
    normal is ``normal`` (both in model space)."""
    x, y, z = point
    ax, ay, az = abs(normal[0]), abs(normal[1]), abs(normal[2])
    if az >= ax and az >= ay:
        return (x, y) if normal[2] >= 0 else (-x, y)
    if ax >= ay:
        return (y, z) if normal[0] >= 0 else (-y, z)
    return (-x, z) if normal[1] >= 0 else (x, z)


def _emit(s):
    if s.emit is None:
        s.emit = np.zeros((s.n, 3))
    return s.emit


def accent(s, mask, name, strength=MARK):
    """The colour of ``name`` emitted at ``strength`` where ``mask``."""
    _emit(s)[mask] = rgb(name) * strength


def glow(s, mask, strength=PRINT):
    """The surface's own colours emitted at ``strength`` where ``mask``."""
    e = _emit(s)
    e[mask] = s.colors()[mask] * strength


def white(s, mask, strength=MARK):
    """A pale mark (a cream digit, a white band) emitted at ``strength``."""
    _emit(s)[mask] = np.array([1.0, 0.97, 0.92]) * strength


register()
