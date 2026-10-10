"""Pixel-texture painter.

Material functions (see materials.py) are evaluated per texel on a context
(`Ctx`) that knows the texel's position, normal, tangent frame and how far it
is from sharp convex/concave edges. They return a `Surface`: indices into
hand-picked colour ramps (the limited palette), roughness, metalness, height
(for the normal map) and optional emission / subsurface masks.

Two entry points:
  paint_tile(fn, w_m, h_m, ppm)     -> tileable planar texture
  bake_atlas(parts, fn_by_slot, ...) -> unique atlas for a mesh (see bake.py)
"""
import numpy as np

from . import noise


class Surface:
    def __init__(self, n):
        self.n = n
        self.ramps = []
        self.ramp_id = np.zeros(n, dtype=np.int64)
        self.shade = np.zeros(n)
        self.rough = np.full(n, 0.8)
        self.metal = np.zeros(n)
        self.height = np.zeros(n)
        self.emit = None     # (n, 3) linear-ish colour * strength, or None
        self.sss = None      # (n,) 0..1 subsurface strength, or None
        self.alpha = None    # (n,) for glass-like maps
        self.albedo = None   # (n, 3) direct colour override (bypasses ramps)

    def use_ramp(self, ramp, mask=None, shade=None):
        """Registers a ramp and assigns it to the masked texels; returns its id."""
        rid = len(self.ramps)
        self.ramps.append(np.asarray(ramp, dtype=np.float64))
        if mask is None:
            self.ramp_id[:] = rid
            if shade is not None:
                self.shade[:] = shade
        else:
            self.ramp_id[mask] = rid
            if shade is not None:
                self.shade[mask] = shade[mask] if np.ndim(shade) else shade
        return rid

    def merge(self, sub, mask):
        """Copies a Surface computed on ctx.subset(mask) into this one."""
        idx = np.nonzero(mask)[0]
        offset = len(self.ramps)
        self.ramps.extend(sub.ramps)
        self.ramp_id[idx] = sub.ramp_id + offset
        self.shade[idx] = sub.shade
        self.rough[idx] = sub.rough
        self.metal[idx] = sub.metal
        self.height[idx] = sub.height
        for name, width in (("emit", 3), ("sss", 1), ("alpha", 1), ("albedo", 3)):
            src = getattr(sub, name)
            if src is None:
                continue
            dst = getattr(self, name)
            if dst is None:
                fill = np.nan if name == "albedo" else (1.0 if name == "alpha" else 0.0)
                dst = np.full((self.n, 3) if width == 3 else self.n, fill)
                setattr(self, name, dst)
            dst[idx] = src

    def colors(self):
        """Resolves ramp indices to sRGB colours (N, 3)."""
        if self.albedo is not None and not self.ramps:
            return self.albedo
        out = np.zeros((self.n, 3))
        for rid, ramp in enumerate(self.ramps):
            m = self.ramp_id == rid
            if not m.any():
                continue
            idx = np.clip(np.round(self.shade[m]), 0, len(ramp) - 1).astype(np.int64)
            out[m] = ramp[idx]
        if self.albedo is not None:
            has = ~np.isnan(self.albedo[:, 0])
            out[has] = self.albedo[has]
        return out


class Ctx:
    """Everything a material function may look at, for N texels."""

    def __init__(self, p, n, t, b, texel, seed=0, period=None):
        self.p = np.asarray(p, dtype=np.float64)
        self.n = np.asarray(n, dtype=np.float64)
        self.t = np.asarray(t, dtype=np.float64)
        self.b = np.asarray(b, dtype=np.float64)
        self.N = self.p.shape[0]
        self.texel = texel
        self.seed = seed
        self.period = period          # (px, py, pz) metres or None
        self.convex = np.full(self.N, np.inf)   # metres to nearest convex sharp edge
        self.concave = np.full(self.N, np.inf)  # metres to nearest concave sharp edge
        self.ao = np.ones(self.N)               # 1 = open, 0 = fully occluded
        self.curv = np.zeros(self.N)            # >0 convex bump, <0 crease (smooth meshes)
        self.long_u = np.ones(self.N, dtype=bool)  # island is longer along u
        self.tile = False
        self.part = np.zeros(self.N, dtype=np.int64)  # object index within a model
        self.uvm = self.p[:, [0, 2]].copy()     # unpacked UVs in metres (pattern space)

    def subset(self, mask):
        """A context restricted to the masked texels (for compositing materials)."""
        idx = np.nonzero(mask)[0]
        sub = Ctx(self.p[idx], self.n[idx], self.t[idx], self.b[idx], self.texel, self.seed, self.period)
        for name in ("convex", "concave", "ao", "curv", "long_u", "part", "uvm"):
            setattr(sub, name, getattr(self, name)[idx])
        sub.tile = self.tile
        sub.seed = self.seed + int(idx[0]) % 997 if len(idx) else self.seed
        return sub

    # --- noise helpers that respect tiling -------------------------------
    def _period(self, freq):
        if self.period is None:
            return None, freq
        freq = np.broadcast_to(np.asarray(freq, dtype=np.float64), (3,)).copy()
        per = []
        for i in range(3):
            if self.period[i] is None:
                per.append(None)
            else:
                cells = max(1, int(round(self.period[i] * freq[i])))
                freq[i] = cells / self.period[i]
                per.append(cells)
        return tuple(per), freq

    def fbm(self, freq, octaves=4, seed=0, p=None, gain=0.5):
        per, f = self._period(freq)
        q = (self.p if p is None else p) * f
        return noise.fbm(q, octaves, self.seed + seed, per, gain=gain)

    def ridged(self, freq, octaves=4, seed=0, p=None):
        per, f = self._period(freq)
        q = (self.p if p is None else p) * f
        return noise.ridged(q, octaves, self.seed + seed, per)

    def value(self, freq, seed=0, p=None):
        per, f = self._period(freq)
        q = (self.p if p is None else p) * f
        return noise.value(q, self.seed + seed, per)

    def worley(self, freq, seed=0, p=None, jitter=0.9):
        per, f = self._period(freq)
        q = (self.p if p is None else p) * f
        return noise.worley(q, self.seed + seed, per, jitter)

    def rand(self, seed=0):
        """Independent random value per texel (tiles trivially)."""
        return noise.white(self.N, self.seed * 7919 + seed)

    # --- edge helpers ------------------------------------------------------
    def edge(self, width_texels=1.0):
        """1 on texels within ``width`` texels of a convex sharp edge."""
        return (self.convex < width_texels * self.texel).astype(np.float64)

    def edge_soft(self, width_texels=3.0):
        return np.clip(1.0 - self.convex / (width_texels * self.texel), 0.0, 1.0)

    def cavity(self, width_texels=3.0):
        """Falloff 1 -> 0 away from concave sharp edges."""
        return np.clip(1.0 - self.concave / (width_texels * self.texel), 0.0, 1.0)

    def up(self):
        """Height coordinate (Blender Z up)."""
        return self.p[:, 2]

    def facing_up(self):
        return self.n[:, 2]


def combine(ctx, parts):
    """Evaluates several material functions on disjoint masks of one context."""
    s = Surface(ctx.N)
    for mask, fn in parts:
        mask = np.asarray(mask, dtype=bool)
        if mask.any():
            s.merge(fn(ctx.subset(mask)), mask)
    return s


def dither_step(value, rand, levels=1.0):
    """Adds ordered-ish noise before rounding so ramp bands break up by texel."""
    return value + (rand - 0.5) * levels


# --------------------------------------------------------------------------
# image-space helpers
# --------------------------------------------------------------------------

def normal_from_height(height, texel, strength=1.0, mask=None):
    """height (H, W) in metres -> tangent-space normal map (H, W, 3) in [0, 1].
    Row 0 is the top of the image (v = 1); green points up the image (OpenGL)."""
    h = height
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) / (2.0 * texel)
    dy = (np.roll(h, 1, axis=0) - np.roll(h, -1, axis=0)) / (2.0 * texel)
    if mask is not None:
        # do not create slopes against empty (unpainted) texels
        m_r = np.roll(mask, -1, axis=1) & np.roll(mask, 1, axis=1)
        m_u = np.roll(mask, 1, axis=0) & np.roll(mask, -1, axis=0)
        dx = np.where(m_r, dx, 0.0)
        dy = np.where(m_u, dy, 0.0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln, ny / ln, nz / ln], axis=-1) * 0.5 + 0.5


def dilate(img, mask, steps):
    """Grows painted texels (mask) outwards by ``steps`` texels (island padding)."""
    img = img.copy()
    mask = mask.copy()
    for _ in range(steps):
        grown = mask.copy()
        acc = np.zeros_like(img)
        cnt = np.zeros(mask.shape)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sm = np.roll(mask, (dy, dx), axis=(0, 1))
            si = np.roll(img, (dy, dx), axis=(0, 1))
            take = sm & ~mask
            acc[take] += si[take]
            cnt[take] += 1
            grown |= sm
        new = grown & ~mask
        img[new] = acc[new] / cnt[new][..., None] if img.ndim == 3 else acc[new] / cnt[new]
        mask = grown
    return img, mask


# --------------------------------------------------------------------------
# tileable textures
# --------------------------------------------------------------------------

def paint_tile(fn, w_m, h_m, ppm, seed=0, normal_strength=1.0):
    """Evaluates ``fn`` on a w_m x h_m metre plane at ``ppm`` pixels per metre.
    The plane is Blender's XZ plane seen from -Y: x = right, z = up.
    Returns dict of images: albedo (H,W,3), normal (H,W,3), orm (H,W,3),
    and optionally emit, alpha."""
    W = int(round(w_m * ppm))
    H = int(round(h_m * ppm))
    texel = 1.0 / ppm
    xs = (np.arange(W) + 0.5) * texel
    zs = h_m - (np.arange(H) + 0.5) * texel      # row 0 = top
    X, Z = np.meshgrid(xs, zs)
    N = W * H
    p = np.stack([X.ravel(), np.zeros(N), Z.ravel()], axis=1)
    n = np.tile([0.0, -1.0, 0.0], (N, 1))
    t = np.tile([1.0, 0.0, 0.0], (N, 1))
    b = np.tile([0.0, 0.0, 1.0], (N, 1))
    ctx = Ctx(p, n, t, b, texel, seed, period=(w_m, None, h_m))
    ctx.tile = True
    s = fn(ctx)
    return _images_from_surface(s, H, W, texel, normal_strength)


def _images_from_surface(s, H, W, texel, normal_strength, index=None, mask=None):
    def place(values, channels, fill=0.0):
        if index is None:
            return values.reshape(H, W, channels) if channels > 1 else values.reshape(H, W)
        shape = (H * W, channels) if channels > 1 else (H * W,)
        out = np.full(shape, fill, dtype=np.float64)
        out[index] = values
        return out.reshape(H, W, channels) if channels > 1 else out.reshape(H, W)

    albedo = place(s.colors(), 3)
    rough = place(np.clip(s.rough, 0.02, 1.0), 1, 1.0)
    metal = place(np.clip(s.metal, 0.0, 1.0), 1)
    height = place(s.height, 1)
    ao = place(np.ones(s.n), 1, 1.0)
    out = {"albedo": albedo, "height": height}
    out["normal"] = normal_from_height(height, texel, normal_strength, mask)
    out["orm"] = np.stack([ao, rough, metal], axis=-1)
    if s.emit is not None:
        out["emit"] = place(s.emit, 3)
    if s.sss is not None:
        out["sss"] = place(s.sss, 1)
    if s.alpha is not None:
        out["alpha"] = place(s.alpha, 1)
    return out
