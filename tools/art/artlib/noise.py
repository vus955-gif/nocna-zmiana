"""Deterministic, vectorised noise for procedural pixel textures (numpy only).

Every function takes points as an (N, 3) float array and an integer seed.
Lattice noises accept an optional per-axis ``period`` (in lattice cells), so a
texture that spans an integer number of cells tiles seamlessly.
"""
import numpy as np

_M1 = np.uint32(0x8DA6B343)
_M2 = np.uint32(0xD8163841)
_M3 = np.uint32(0xCB1AB31F)
_MIX = np.uint32(0x5BD1E995)


def _u32(a):
    return (np.asarray(a, dtype=np.int64) & 0xFFFFFFFF).astype(np.uint32)


def hash3(ix, iy, iz, seed=0):
    """uint32 hash of integer lattice coordinates."""
    h = _u32(ix) * _M1 ^ _u32(iy) * _M2 ^ _u32(iz) * _M3 ^ np.uint32((seed * 0x9E3779B9 + 0x7F4A7C15) & 0xFFFFFFFF)
    h ^= h >> np.uint32(13)
    h *= _MIX
    h ^= h >> np.uint32(15)
    h *= _MIX
    h ^= h >> np.uint32(16)
    return h


def hash_float(ix, iy, iz, seed=0):
    """Uniform float in [0, 1) per lattice cell."""
    return hash3(ix, iy, iz, seed).astype(np.float64) / 4294967296.0


def rand_cells(ids, seed=0):
    """Uniform float in [0, 1) for arbitrary integer ids (e.g. tile numbers)."""
    ids = np.asarray(ids)
    return hash_float(ids, ids * 7 + 3, ids * 13 + 5, seed)


def _wrap(c, period, axis):
    if period is None:
        return c
    p = period[axis] if isinstance(period, (tuple, list)) else period
    if p is None:
        return c
    return np.mod(c, int(round(p)))


def _fade(t):
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def perlin(p, seed=0, period=None):
    """Gradient noise in roughly [-1, 1]."""
    p = np.asarray(p, dtype=np.float64)
    pi = np.floor(p).astype(np.int64)
    pf = p - pi
    w = _fade(pf)
    out = np.zeros(p.shape[0])
    for dx in (0, 1):
        wx = w[:, 0] if dx else 1.0 - w[:, 0]
        cx = _wrap(pi[:, 0] + dx, period, 0)
        for dy in (0, 1):
            wy = w[:, 1] if dy else 1.0 - w[:, 1]
            cy = _wrap(pi[:, 1] + dy, period, 1)
            for dz in (0, 1):
                wz = w[:, 2] if dz else 1.0 - w[:, 2]
                cz = _wrap(pi[:, 2] + dz, period, 2)
                gx = hash_float(cx, cy, cz, seed) * 2.0 - 1.0
                gy = hash_float(cx, cy, cz, seed + 101) * 2.0 - 1.0
                gz = hash_float(cx, cy, cz, seed + 202) * 2.0 - 1.0
                dot = gx * (pf[:, 0] - dx) + gy * (pf[:, 1] - dy) + gz * (pf[:, 2] - dz)
                out += wx * wy * wz * dot
    return out * 1.6


def value(p, seed=0, period=None):
    """Smooth value noise in [0, 1]."""
    p = np.asarray(p, dtype=np.float64)
    pi = np.floor(p).astype(np.int64)
    w = _fade(p - pi)
    out = np.zeros(p.shape[0])
    for dx in (0, 1):
        wx = w[:, 0] if dx else 1.0 - w[:, 0]
        cx = _wrap(pi[:, 0] + dx, period, 0)
        for dy in (0, 1):
            wy = w[:, 1] if dy else 1.0 - w[:, 1]
            cy = _wrap(pi[:, 1] + dy, period, 1)
            for dz in (0, 1):
                wz = w[:, 2] if dz else 1.0 - w[:, 2]
                cz = _wrap(pi[:, 2] + dz, period, 2)
                out += wx * wy * wz * hash_float(cx, cy, cz, seed)
    return out


def _scaled_period(period, f):
    if period is None:
        return None
    if isinstance(period, (tuple, list)):
        return tuple(None if a is None else a * f for a in period)
    return period * f


def fbm(p, octaves=4, seed=0, period=None, lacunarity=2.0, gain=0.5, base=perlin):
    """Fractal sum of ``base`` noise. With perlin the result is roughly [-1, 1]."""
    p = np.asarray(p, dtype=np.float64)
    total = np.zeros(p.shape[0])
    amp = 1.0
    norm = 0.0
    f = 1.0
    for i in range(octaves):
        total += amp * base(p * f, seed + i * 17, _scaled_period(period, f))
        norm += amp
        amp *= gain
        f *= lacunarity
    return total / norm


def ridged(p, octaves=4, seed=0, period=None):
    """1 - |fbm|: bright thin ridges (marble veins, cracks)."""
    return 1.0 - np.abs(fbm(p, octaves, seed, period))


def worley(p, seed=0, period=None, jitter=0.9):
    """Cellular noise. Returns (F1, F2, cell_id) where cell_id is a random float per cell."""
    p = np.asarray(p, dtype=np.float64)
    pi = np.floor(p).astype(np.int64)
    pf = p - pi
    f1 = np.full(p.shape[0], 1e9)
    f2 = np.full(p.shape[0], 1e9)
    cid = np.zeros(p.shape[0])
    for dx in (-1, 0, 1):
        cx = _wrap(pi[:, 0] + dx, period, 0)
        for dy in (-1, 0, 1):
            cy = _wrap(pi[:, 1] + dy, period, 1)
            for dz in (-1, 0, 1):
                cz = _wrap(pi[:, 2] + dz, period, 2)
                ox = dx + 0.5 + (hash_float(cx, cy, cz, seed) - 0.5) * jitter
                oy = dy + 0.5 + (hash_float(cx, cy, cz, seed + 1) - 0.5) * jitter
                oz = dz + 0.5 + (hash_float(cx, cy, cz, seed + 2) - 0.5) * jitter
                d = np.sqrt((ox - pf[:, 0]) ** 2 + (oy - pf[:, 1]) ** 2 + (oz - pf[:, 2]) ** 2)
                closer = d < f1
                f2 = np.where(closer, f1, np.minimum(f2, d))
                cid = np.where(closer, hash_float(cx, cy, cz, seed + 3), cid)
                f1 = np.where(closer, d, f1)
    return f1, f2, cid


def white(n_or_shape, seed=0):
    """Per-texel white noise in [0, 1) from a seeded generator."""
    rng = np.random.default_rng(seed)
    return rng.random(n_or_shape)


def texel_noise(p, texel, seed=0, period=None):
    """Blocky white noise quantised to the texel grid of a point set (stable per texel)."""
    q = np.floor(np.asarray(p) / texel + 1e-6).astype(np.int64)
    per = None
    if period is not None:
        per = tuple(None if a is None else int(round(a / texel)) for a in period)
        q = np.stack([_wrap(q[:, i], per, i) for i in range(3)], axis=1)
    return hash_float(q[:, 0], q[:, 1], q[:, 2], seed)
