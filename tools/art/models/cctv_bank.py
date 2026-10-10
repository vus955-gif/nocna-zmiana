"""The CCTV wall in the guards' room: a black steel rack with two rows of
three old CRT monitors over a desk with a sloped control panel (buttons,
toggle switches, a joystick, status LEDs). 1.5 x 0.62 m, 1.78 m tall.

Origin on the floor at the centre of the rack's back (wall at y = 0); it
faces -Y. Each screen is its own material slot, "cctv_screen_1" ...
"cctv_screen_6" (top row left -> right, then bottom row), with UVs 0..1
across the glass, so the game can give each one a camera viewport. By
default ArtLibrary shows the static "crt_cctv" picture on them."""
import numpy as np

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

W, DEPTH = 1.5, 0.5
DESK_Z = 0.76
SCREENS = [f"cctv_screen_{k}" for k in range(1, 7)]


def housing(ctx):
    return M.plastic(ctx, "plastic_black", 4.2, seed=441, rough=0.5, scuff=1.0)


def panel(ctx):
    s = M.enamel(ctx, "crt_grey", 3.6, seed=443, chip=0.5, gloss=0.4, under="steel")
    ink = M.text_marks(ctx, 0.006, 445, density=0.5) & (ctx.n[:, 2] > 0.3)
    s.use_ramp(M.P["cloth_white"], mask=ink, shade=np.full(ctx.N, 5.0))
    return s


FNS = {
    "rack": lambda c: M.enamel(c, "iron", 3.6, seed=447, chip=0.6, gloss=0.5, under="steel"),
    "housing": housing,
    "bezel": M.crt_glass,
    "panel": panel,
    "desk": M.wood_dark,
    "button": lambda c: M.plastic(c, "plastic_black", 2.4, seed=449, rough=0.4),
    "red": lambda c: M.plastic(c, "cloth_red", 4.5, seed=451, rough=0.35),
    "steel": lambda c: M.steel(c, seed=453, center=8.0, dent=0.0),
    "led_g": lambda c: M.glow(c, "led_green", 4.5, strength=1.0),
    "led_r": lambda c: M.glow(c, "lamp_red", 4.5, strength=1.0),
}


def _monitor(p, cx, cz, slot):
    w, h, d = 0.44, 0.37, 0.4
    y0 = -DEPTH + 0.06                                          # front face of the housing
    p.box((cx, y0 + d / 2, cz), (w, d, h), "housing", bevel=0.018)
    p.box((cx, y0 + d / 2 + 0.1, cz - 0.01), (w * 0.7, d * 0.6, h * 0.75), "housing", bevel=0.02)   # CRT neck
    p.box((cx, y0 - 0.004, cz + 0.01), (0.37, 0.01, 0.29), "bezel", bevel=0.006)
    kit.screen(p, (cx, y0 - 0.0095, cz + 0.01), 0.34, 0.26, slot, bulge=0.012)
    # knobs and a power LED under the screen
    for k in range(3):
        kit.seg(p, (cx + 0.12 + k * 0.025, y0 - 0.001, cz - 0.16), (cx + 0.12 + k * 0.025, y0 - 0.012, cz - 0.16),
                [(0.007, 0), (0.006, 1)], "button", segments=8)
    p.box((cx - 0.17, y0 - 0.003, cz - 0.16), (0.008, 0.006, 0.006), "led_g")


def build():
    p = Part("cctv_bank")
    # rack: four posts, shelves
    for sx in (-1, 1):
        for y in (-DEPTH + 0.02, -0.02):
            p.box((sx * (W / 2 - 0.02), y, 0.89), (0.04, 0.04, 1.78), "rack", bevel=0.004)
    for z in (DESK_Z + 0.44, DESK_Z + 0.02, 1.76):
        p.box((0, -DEPTH / 2, z), (W, DEPTH, 0.025), "rack", bevel=0.004)
    p.box((0, -0.01, 1.2), (W - 0.04, 0.02, 1.1), "rack")                               # back panel
    # desk slab sticking out in front, with a sloped control panel
    p.box((0, -DEPTH / 2 - 0.06, DESK_Z), (W + 0.04, DEPTH + 0.14, 0.04), "desk", bevel=0.008)
    slope = p.box((0, 0, 0), (W - 0.2, 0.2, 0.05), "panel", bevel=0.006)
    p.move(slope, T(0, -DEPTH - 0.02, DESK_Z + 0.055) @ R('X', 18))
    for sx in (-1, 1):
        p.box((sx * (W / 2 - 0.02), -DEPTH - 0.08, DESK_Z / 2), (0.04, 0.04, DESK_Z), "rack", bevel=0.004)
    p.box((0, -0.3, 0.12), (W - 0.1, 0.5, 0.02), "rack")                                # foot shelf
    # controls on the slope (panel frame: x across, y up the slope)
    m = T(0, -DEPTH - 0.02, DESK_Z + 0.055) @ R('X', 18) @ T(0, 0, 0.025)
    rng = np.random.default_rng(3)
    for i in range(10):
        for j in range(2):
            x = -0.55 + i * 0.07
            b = p.box((x, -0.04 + j * 0.06, 0.006), (0.03, 0.03, 0.012), "red" if (i + j) % 5 == 0 else "button",
                      bevel=0.003)
            p.move(b, m)
    for i in range(6):
        t = p.box((0, 0, 0), (0.008, 0.008, 0.03), "steel", bevel=0.002)
        p.move(t, m @ T(0.2 + i * 0.045, 0.02, 0.015) @ R('X', 25 if i % 2 else -25))
        led = p.box((0.2 + i * 0.045, -0.055, 0.003), (0.01, 0.008, 0.006), "led_g" if i % 3 else "led_r")
        p.move(led, m)
    stick = kit.seg(p, (0.55, 0.0, 0.0), (0.55, 0.0, 0.09), [(0.025, 0), (0.008, 0.2), (0.007, 0.8), (0.016, 1.0)],
                    "button", segments=8)
    p.move(stick, m)
    # the monitors
    k = 0
    for row, cz in enumerate((DESK_Z + 0.44 + 0.21, DESK_Z + 0.04 + 0.2)):
        for cx in (-0.47, 0.0, 0.47):
            _monitor(p, cx, cz, SCREENS[k])
            k += 1
    kinds = {s: s for s in SCREENS}
    return Model("cctv_bank", [p], FNS, kinds=kinds, ppm=128, ground=0.0, ao_dist=0.15, ao_rays=12, ao_stride=2,
                 preview_kinds={s: "crt_cctv" for s in SCREENS}, preview_elevation=10.0)
