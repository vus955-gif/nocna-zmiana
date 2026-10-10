"""The upgrade terminal: the museum's old beige office computer on a steel
typing table. CRT monitor on a desktop case (two floppy slots, a power LED),
keyboard in front. 0.72 x 0.56 m table, the screen centre about 1.05 m up.

Origin on the floor under the table centre; faces -Y. The glass is its own
material slot "terminal_screen" with UVs 0..1 (for the upgrade menu viewport);
by default ArtLibrary shows the green "crt_terminal" picture on it."""
import numpy as np

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

TOP = 0.72


def beige(ctx):
    return M.plastic(ctx, "plastic_beige", 5.0, seed=461, rough=0.55, scuff=1.2)


def keys(ctx):
    s = M.plastic(ctx, "plastic_beige", 4.2, seed=463, rough=0.5, scuff=0.5)
    u, v = ctx.uvm[:, 0] / 0.019, ctx.uvm[:, 1] / 0.019
    gap = (np.mod(u, 1.0) < 0.14) | (np.mod(v, 1.0) < 0.14)
    s.shade[gap & (ctx.n[:, 2] > 0.5)] -= 2.6
    ink = M.text_marks(ctx, 0.0095, 465, density=0.35) & (ctx.n[:, 2] > 0.5) & ~gap
    s.use_ramp(M.P["hair"], mask=ink, shade=np.full(ctx.N, 2.0))
    return s


FNS = {
    "beige": beige,
    "keys": keys,
    "bezel": M.crt_glass,
    "slot": lambda c: M.plastic(c, "plastic_black", 1.5, seed=467, rough=0.6),
    "led": lambda c: M.glow(c, "led_green", 4.5),
    "table": lambda c: M.enamel(c, "crt_grey", 4.0, seed=469, chip=0.8, gloss=0.4, under="steel"),
    "top": M.wood_oak,
    "rubber": M.rubber,
}


def build():
    p = Part("terminal")
    # typing table: top, four tubular legs, a lower shelf
    p.box((0, 0, TOP - 0.015), (0.72, 0.56, 0.03), "top", bevel=0.006)
    p.box((0, 0, TOP - 0.045), (0.68, 0.52, 0.03), "table", bevel=0.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.seg(p, (sx * 0.32, sy * 0.23, 0.0), (sx * 0.32, sy * 0.23, TOP - 0.06), [(0.016, 0), (0.016, 1)],
                    "table", segments=8)
            p.box((sx * 0.32, sy * 0.23, 0.008), (0.03, 0.03, 0.016), "rubber", bevel=0.004)
    p.box((0, 0, 0.18), (0.64, 0.46, 0.015), "table", bevel=0.003)
    # desktop case
    p.box((0, 0.05, TOP + 0.06), (0.46, 0.38, 0.12), "beige", bevel=0.01)
    for k, z in enumerate((TOP + 0.085, TOP + 0.045)):
        p.box((0.1, -0.142, z), (0.14, 0.008, 0.028), "beige", bevel=0.003)
        p.box((0.1, -0.147, z), (0.1, 0.004, 0.006), "slot")
    p.box((-0.17, -0.142, TOP + 0.04), (0.012, 0.006, 0.008), "led")
    p.box((-0.12, -0.142, TOP + 0.04), (0.03, 0.008, 0.02), "slot", bevel=0.003)          # power switch
    # CRT monitor on top
    mz = TOP + 0.12
    p.box((0, 0.06, mz + 0.012), (0.24, 0.24, 0.024), "beige", bevel=0.006)               # swivel foot
    p.box((0, 0.05, mz + 0.2), (0.4, 0.34, 0.34), "beige", bevel=0.02)                    # front shell
    p.box((0, 0.24, mz + 0.19), (0.3, 0.2, 0.26), "beige", bevel=0.03)                    # back hump
    p.box((0, -0.123, mz + 0.21), (0.33, 0.01, 0.26), "bezel", bevel=0.008)
    kit.screen(p, (0, -0.128, mz + 0.21), 0.3, 0.225, "terminal_screen", bulge=0.012)
    p.box((0.15, -0.121, mz + 0.05), (0.01, 0.006, 0.008), "led")
    # keyboard
    kb = p.box((0, 0, 0), (0.44, 0.17, 0.03), "beige", bevel=0.006)
    keys_ = p.box((0, 0.006, 0.018), (0.4, 0.13, 0.01), "keys", bevel=0.002)
    p.move(kb + keys_, T(0, -0.2, TOP + 0.016) @ R('X', 5))
    return Model("terminal", [p], FNS, kinds={"terminal_screen": "terminal_screen"}, ppm=192, ground=0.0,
                 ao_dist=0.1, ao_rays=12, ao_stride=1, preview_kinds={"terminal_screen": "crt_terminal"},
                 preview_elevation=14.0)
