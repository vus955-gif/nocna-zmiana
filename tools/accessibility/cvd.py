"""Colour-vision helpers (Machado, Oliveira & Fernandes 2009, severity 1.0, linear RGB)
and a search for HUD palettes. Offline tool: the results are typed into
src/style/colour_vision.gd and checked there by tests."""
import itertools, math, random, colorsys, sys
import numpy as np

M = {
    "prot": np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    "deut": np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    "trit": np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
    "norm": np.eye(3),
}


def to_lin(c):
    c = np.asarray(c, dtype=float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(np.asarray(c, dtype=float), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def sim(c, mode):
    return to_srgb(M[mode] @ to_lin(c))


def lab(c):
    l = to_lin(c)
    x = (0.4124564 * l[0] + 0.3575761 * l[1] + 0.1804375 * l[2]) / 0.95047
    y = (0.2126729 * l[0] + 0.7151522 * l[1] + 0.0721750 * l[2])
    z = (0.0193339 * l[0] + 0.1191920 * l[1] + 0.9503041 * l[2]) / 1.08883
    def f(t):
        return t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116
    fx, fy, fz = f(x), f(y), f(z)
    return np.array([116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)])


def de(a, b, mode="norm"):
    return float(np.linalg.norm(lab(sim(a, mode)) - lab(sim(b, mode))))


def lum(c):
    l = to_lin(c)
    return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]


def contrast(a, b, mode="norm"):
    la, lb = lum(sim(a, mode)), lum(sim(b, mode))
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


ENAMEL = np.array([0.05, 0.043, 0.036])
CHANNEL = np.array([0.025, 0.02, 0.018])

ORIG = {
    "taser": (0.4, 0.8, 1.0), "pistol": (0.3, 0.45, 1.0), "shotgun": (0.92, 0.12, 0.1), "gatling": (0.72, 0.85, 0.25),
    "flare": (1.0, 0.42, 0.05), "rifle_hunt": (0.2, 0.72, 0.36), "harpoon": (0.2, 0.78, 0.85), "hwacha": (0.68, 0.36, 0.95),
}
MEDKIT = (1.0, 0.96, 0.9)


def report(name, colors, mode):
    cs = list(colors.values())
    mn = 1e9
    pair = None
    for (ka, a), (kb, b) in itertools.combinations(colors.items(), 2):
        d = de(a, b, mode)
        if d < mn:
            mn, pair = d, (ka, kb)
    worst_contrast = min(contrast(c, ENAMEL, mode) for c in cs)
    print(f"{name:10s} {mode}: min dE {mn:5.1f} {pair}  worst contrast vs enamel {worst_contrast:4.1f}")


if __name__ == "__main__":
    allw = dict(ORIG)
    allw["medkit"] = MEDKIT
    for mode in ("norm", "deut", "prot", "trit"):
        report("original", allw, mode)
