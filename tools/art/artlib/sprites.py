"""Small hand-made images that are not surface textures: the dust mote
billboard sprite sheet and the default pictures for CRT screens (the game
may replace a screen's texture with a live viewport).

All deterministic (seeded numpy), written by tools/art/build_textures.py.
"""
import numpy as np

from . import materials as M


def dust_mote(frames=4, size=16):
    """4 frames of a small glowing mote, 16 x 16 px each, side by side
    (RGBA, straight alpha). A 2-px hot core, a soft round glow and a
    4-point twinkle whose arms grow and shrink over the frames. Use it
    additive and unshaded on a billboard; h_frames = 4."""
    ramp = M.P["dust"]
    out = np.zeros((size, size * frames, 4))
    c = (size - 1) / 2.0
    yy, xx = np.mgrid[0:size, 0:size]
    dx, dy = xx - c, yy - c
    r = np.hypot(dx, dy)
    for f in range(frames):
        arm = [2.5, 4.5, 6.5, 4.5][f % 4]
        glow = np.clip(1.0 - r / (3.2 + 0.4 * (f % 2)), 0.0, 1.0) ** 1.6
        cross = ((np.abs(dx) < 0.6) & (np.abs(dy) < arm)) | ((np.abs(dy) < 0.6) & (np.abs(dx) < arm))
        twinkle = cross * np.clip(1.0 - np.maximum(np.abs(dx), np.abs(dy)) / (arm + 0.5), 0.0, 1.0)
        v = np.clip(glow * 0.85 + twinkle * 0.9, 0.0, 1.0)
        core = r < 1.2
        v[core] = 1.0
        # quantise onto the ramp (pixel-art bands), alpha follows brightness
        idx = np.clip(np.round(v * (len(ramp) - 1)), 0, len(ramp) - 1).astype(int)
        rgb = ramp[idx]
        alpha = np.clip(np.round(v * 6) / 6, 0.0, 1.0)
        tile = np.concatenate([rgb, alpha[..., None]], axis=-1)
        tile[alpha <= 0.0] = 0.0
        out[:, f * size:(f + 1) * size] = tile
    return out


def _glyph_rows(rng, cols, rows, fill=0.7):
    """Blocky pseudo-text: random 3x5 glyphs laid out in lines."""
    img = np.zeros((rows * 7, cols * 4))
    for r in range(rows):
        n = int(cols * (0.4 + 0.6 * rng.random())) if rng.random() < fill else 0
        for c in range(n):
            if rng.random() < 0.15:
                continue                         # a space
            g = rng.random((5, 3)) < 0.55
            img[r * 7 + 1:r * 7 + 6, c * 4:c * 4 + 3] = g
    return img


def crt_picture(kind, w=160, h=120, seed=0):
    """Default screen picture (4:3), RGB in [0, 1]; the same image is used as
    albedo and emission. ``kind`` "cctv": grey surveillance feed with a dim
    corridor, scanlines, noise and an OSD (camera number, REC dot, time);
    "terminal": green phosphor text with a title bar and a cursor."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / (w - 1), yy / (h - 1)
    vign = np.clip(1.0 - (((u - 0.5) * 1.6) ** 2 + ((v - 0.5) * 1.8) ** 2) * 0.55, 0.0, 1.0)
    scan = np.where(yy % 2 == 0, 1.0, 0.72)
    if kind == "cctv":
        ramp = M.P["crt_grey"]
        # a gallery corridor in one-point perspective seen from a ceiling
        # camera: floor with tile lines, side walls with lamp pools, a far
        # doorway, a display case on the left
        cx, cy = 0.55, 0.38
        du, dv = u - cx, v - cy
        back = (np.abs(du) < 0.1) & (np.abs(dv) < 0.09)
        floor = (dv > 0.09) & (np.abs(du) < dv * 1.15)
        ceiling = (dv < -0.09) & (np.abs(du) < -dv * 1.15)
        base = np.full((h, w), 2.6)                                           # walls
        base = np.where(ceiling, 1.4, base)
        depth = 0.09 / np.maximum(np.abs(dv), 0.09)
        tiles = (np.mod(1.0 / np.maximum(dv, 0.01) * 0.35, 1.0) < 0.12) | (np.mod(du / np.maximum(dv, 0.01) * 3.0, 1.0) < 0.08)
        base = np.where(floor, 4.2 - depth * 1.5 - tiles * 1.2, base)
        base = np.where(back, 3.2, base)
        door = (np.abs(du + 0.02) < 0.035) & (dv > -0.04) & (dv < 0.09)
        base = np.where(door, 0.6, base)
        for lx, ly in ((0.12, 0.25), (0.93, 0.27), (0.33, 0.33), (0.76, 0.34)):
            base += np.clip(1.0 - np.hypot((u - lx) * 1.3, v - ly) / 0.12, 0, 1) * 2.5 * ~floor
        case = (u > 0.14) & (u < 0.3) & (v > 0.55) & (v < 0.8)
        base = np.where(case, 1.0, base)
        base = np.where(case & (v < 0.575), 5.5, base)
        base += (rng.random((h, w)) - 0.5) * 1.1
        shade = base * vign * scan
        img = ramp[np.clip(np.round(shade), 0, len(ramp) - 1).astype(int)]
        osd = _glyph_rows(rng, 9, 1, fill=1.0)
        img[4:4 + osd.shape[0], 5:5 + osd.shape[1]][osd > 0] = ramp[-1]
        t = _glyph_rows(rng, 11, 1, fill=1.0)
        img[h - 11:h - 11 + t.shape[0], w - 5 - t.shape[1]:w - 5][t > 0] = ramp[-2]
        rec = (np.hypot(xx - (w - 12), yy - 8) < 3.2)
        img[rec] = M.P["lamp_red"][5]
    else:
        ramp = M.P["phosphor"]
        shade = np.full((h, w), 1.2) + (rng.random((h, w)) - 0.5) * 0.6
        txt = _glyph_rows(rng, (w - 12) // 4, (h - 24) // 7, fill=0.8)
        th, tw = txt.shape
        shade[16:16 + th, 6:6 + tw] += txt * 5.5
        shade[3:11, 3:w - 3] = 6.0                                     # title bar
        title = _glyph_rows(rng, 14, 1, fill=1.0)
        region = shade[3:3 + title.shape[0], 8:8 + title.shape[1]]
        region[title[:region.shape[0], :region.shape[1]] > 0] = 1.0
        shade[h - 14:h - 8, 8:12] = 7.5                                # cursor
        shade = shade * vign * scan
        img = ramp[np.clip(np.round(shade), 0, len(ramp) - 1).astype(int)]
    return img
