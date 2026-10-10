"""DSP building blocks for the procedural music and ambience of Nocna Zmiana.

numpy only (Blender's bundled Python has it, scipy is not needed). Filters
are zero-phase FFT filters; everything that runs over a whole loop can run
circularly, so the end of a loop flows into its start exactly as the game
plays it (reverb tails, compressor and limiter included): no seam, no click.

Conventions: mono signals are 1-D float arrays, stereo ones are (n, 2).
SR = 44100 everywhere.
"""
import wave

import numpy as np

SR = 44100
TAU = 2.0 * np.pi


# --- units -----------------------------------------------------------------

def n_of(seconds):
    return max(int(round(seconds * SR)), 1)


def hz(midi):
    return 440.0 * 2.0 ** ((np.asarray(midi, dtype=float) - 69.0) / 12.0)


def cents(c):
    return 2.0 ** (np.asarray(c, dtype=float) / 1200.0)


def db(value):
    return 10.0 ** (np.asarray(value, dtype=float) / 20.0)


def to_db(value):
    return 20.0 * np.log10(np.maximum(np.abs(value), 1e-12))


def fast_len(n):
    """Smallest m >= n whose prime factors are 2, 3, 5 and 7 (fast FFT)."""
    best = 1 << int(np.ceil(np.log2(max(n, 1))))
    p7 = 1
    while p7 < best:
        p5 = p7
        while p5 < best:
            p3 = p5
            while p3 < best:
                m = p3
                while m < n:
                    m *= 2
                best = min(best, m)
                p3 *= 3
            p5 *= 5
        p7 *= 7
    return best


def stereo(x):
    x = np.asarray(x, dtype=float)
    return np.stack([x, x], axis=1) if x.ndim == 1 else x


def mono(x):
    x = np.asarray(x, dtype=float)
    return x if x.ndim == 1 else x.mean(axis=1)


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)))) if np.size(x) else 0.0


def peak(x):
    return float(np.max(np.abs(x))) if np.size(x) else 0.0


def pad_to(x, n):
    x = np.asarray(x, dtype=float)
    if x.shape[0] >= n:
        return x[:n]
    extra = np.zeros((n - x.shape[0],) + x.shape[1:])
    return np.concatenate([x, extra])


# --- oscillators -----------------------------------------------------------

TABLE = 2048
_tables = {}


def _table(shape, harmonics):
    key = (shape, harmonics)
    table = _tables.get(key)
    if table is None:
        k = np.arange(1, harmonics + 1)
        if shape == "saw":
            amp = 1.0 / k
        elif shape == "square":
            amp = np.where(k % 2 == 1, 1.0 / k, 0.0)
        elif shape == "tri":
            amp = np.where(k % 2 == 1, 1.0 / k ** 2, 0.0) * np.where(((k - 1) // 2) % 2 == 0, 1.0, -1.0)
        elif shape == "pulse":   # 25 % pulse
            amp = np.sin(np.pi * k * 0.25) / k
        else:
            raise ValueError(shape)
        spec = np.zeros(TABLE // 2 + 1, dtype=complex)
        spec[k] = -1j * amp * TABLE / 2.0
        table = np.fft.irfft(spec, TABLE)
        table /= np.max(np.abs(table))
        _tables[key] = table
    return table


def phase_of(freq, n, phase0=0.0):
    """Phase in cycles. A scalar frequency gives an exact linear phase (so a
    drone whose frequency is a multiple of 1/loop_seconds is periodic)."""
    if np.isscalar(freq):
        return phase0 + float(freq) * np.arange(n) / SR
    inc = np.asarray(freq, dtype=float) / SR
    return np.cumsum(inc) - inc[0] + phase0


def osc(freq, n, shape="saw", phase0=0.0):
    """Band-limited oscillator (wavetable with harmonics below ~0.45 SR)."""
    ph = phase_of(freq, n, phase0)
    if shape == "sine":
        return np.sin(TAU * ph)
    fmax = float(np.max(freq))
    harmonics = max(1, min(TABLE // 2 - 1, int(SR * 0.45 / max(fmax, 1.0))))
    table = _table(shape, harmonics)
    pos = (ph % 1.0) * TABLE
    i0 = pos.astype(np.int64) % TABLE
    frac = pos - np.floor(pos)
    return table[i0] * (1.0 - frac) + table[(i0 + 1) % TABLE] * frac


def partials(f0, ratios, amps, decays, n, phases=None, detune_cents=0.0, rng=None):
    """Sum of decaying sine partials (bells, bars, tines, membranes).
    decays are time constants in seconds (inf = sustained)."""
    t = np.arange(n) / SR
    out = np.zeros(n)
    for i, (r, a, d) in enumerate(zip(ratios, amps, decays)):
        f = f0 * r
        if f >= SR * 0.47 or a == 0.0:
            continue
        if detune_cents and rng is not None:
            f *= cents(rng.uniform(-detune_cents, detune_cents))
        ph = phases[i] if phases is not None else (rng.uniform(0, 1) if rng is not None else 0.0)
        env = np.exp(-t / d) if np.isfinite(d) else 1.0
        out += a * env * np.sin(TAU * (f * t + ph))
    return out


# --- envelopes -------------------------------------------------------------

def ramp(n):
    """0..1 raised-cosine rise over n samples."""
    if n <= 0:
        return np.ones(0)
    return 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / n)


def env_ar(n, attack, release):
    """Smooth rise over attack s, hold, smooth fall over the last release s."""
    env = np.ones(n)
    a = min(n_of(attack), n)
    r = min(n_of(release), n)
    env[:a] *= ramp(a)
    if r > 0:
        env[n - r:] *= ramp(r)[::-1]
    return env


def env_exp(n, tau, attack=0.002):
    t = np.arange(n) / SR
    env = np.exp(-t / tau)
    a = min(n_of(attack), n)
    env[:a] *= ramp(a)
    return env


def env_adsr(n, attack, decay, sustain, release, gate=None):
    """ADSR; the gate (s) is where the release starts (default n - release)."""
    t = np.arange(n) / SR
    gate = (n / SR - release) if gate is None else gate
    env = np.where(t < attack, 0.5 - 0.5 * np.cos(np.pi * t / max(attack, 1e-4)),
                   sustain + (1.0 - sustain) * np.exp(-(t - attack) / max(decay, 1e-4)))
    level_at_gate = sustain + (1.0 - sustain) * np.exp(-max(gate - attack, 0.0) / max(decay, 1e-4))
    after = t >= gate
    env[after] = level_at_gate * np.exp(-(t[after] - gate) / max(release / 4.0, 1e-4))
    return env


def fade_edges(x, fade_in=0.002, fade_out=0.01):
    x = np.array(x, dtype=float)
    a = min(n_of(fade_in), x.shape[0])
    r = min(n_of(fade_out), x.shape[0])
    shape_in = ramp(a)
    shape_out = ramp(r)[::-1]
    if x.ndim == 2:
        shape_in = shape_in[:, None]
        shape_out = shape_out[:, None]
    x[:a] *= shape_in
    if r:
        x[-r:] *= shape_out
    return x


# --- filters (zero-phase, FFT) ----------------------------------------------

def fft_filter(x, gain, circular=False, pad=None):
    """Applies a real gain curve gain(f) (or an array over rfft bins).
    circular=True filters a loop as a loop; otherwise the signal is padded
    so tails are kept inside the output length only as far as it reaches."""
    x = np.asarray(x, dtype=float)
    n = x.shape[0]
    size = n if circular else fast_len(n + (pad if pad is not None else min(n, SR // 2)))
    spec = np.fft.rfft(x, size, axis=0)
    f = np.fft.rfftfreq(size, 1.0 / SR)
    g = gain(f) if callable(gain) else gain
    if spec.ndim == 2:
        g = np.asarray(g)[:, None]
    y = np.fft.irfft(spec * g, size, axis=0)
    return y[:n]


def g_lowpass(fc, order=2):
    return lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def g_highpass(fc, order=2):
    return lambda f: 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))


def g_band(lo, hi, order=2):
    return g_mul(g_highpass(lo, order), g_lowpass(hi, order))


def g_reso(fc, q):
    """Resonant 2-pole low-pass magnitude (q > 0.707 peaks at fc)."""
    return lambda f: 1.0 / np.sqrt((1.0 - (f / fc) ** 2) ** 2 + (f / (fc * q)) ** 2)


def g_peak(f0, q):
    """Narrow resonance (band-pass magnitude, 1 at f0)."""
    return lambda f: 1.0 / np.sqrt(1.0 + (q * (f / f0 - f0 / np.maximum(f, 1e-3))) ** 2)


def g_bell(f0, gain_db, octaves=1.0):
    return lambda f: 10.0 ** (gain_db / 20.0 * np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / f0) / octaves) ** 2))


def g_shelf_hi(f0, gain_db, slope=1.0):
    return lambda f: 10.0 ** (gain_db / 20.0 / (1.0 + (f0 / np.maximum(f, 1.0)) ** (2.0 * slope)))


def g_shelf_lo(f0, gain_db, slope=1.0):
    return lambda f: 10.0 ** (gain_db / 20.0 / (1.0 + (np.maximum(f, 1.0) / f0) ** (2.0 * slope)))


def g_mul(*gains):
    def g(f):
        out = np.ones_like(f)
        for item in gains:
            out = out * item(f)
        return out
    return g


def lowpass(x, fc, order=2, circular=False):
    return fft_filter(x, g_lowpass(fc, order), circular)


def highpass(x, fc, order=2, circular=False):
    return fft_filter(x, g_highpass(fc, order), circular)


def bandpass(x, lo, hi, order=2, circular=False):
    return fft_filter(x, g_band(lo, hi, order), circular)


def lowpass_sweep(x, cutoff, order=2, lo=30.0, hi=18000.0, bands=14):
    """Time-varying low-pass: the signal filtered at several fixed cutoffs,
    crossfaded per sample by [param cutoff] (Hz array). The zero-phase
    versions stay phase-aligned, so the blend behaves like one moving filter."""
    x = np.asarray(x, dtype=float)
    n = x.shape[0]
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), (n,))
    edges = np.geomspace(lo, hi, bands)
    pos = np.interp(np.log(np.clip(cutoff, lo, hi)), np.log(edges), np.arange(bands))
    i0 = np.clip(np.floor(pos).astype(int), 0, bands - 2)
    frac = pos - i0
    used = np.unique(np.concatenate([i0, i0 + 1]))
    versions = {int(b): fft_filter(x, g_lowpass(edges[b], order)) for b in used}
    out = np.zeros_like(x)
    for b in used:
        v = versions[int(b)]
        w = np.where(i0 == b, 1.0 - frac, 0.0) + np.where(i0 + 1 == b, frac, 0.0)
        out += v * (w if x.ndim == 1 else w[:, None])
    return out


# --- noise and modulation ---------------------------------------------------

def noise(n, rng, gain=None, channels=1):
    """Periodic noise (period n) shaped by gain(f), RMS 1 per channel."""
    size = n // 2 + 1
    spec = rng.standard_normal((size, channels)) + 1j * rng.standard_normal((size, channels))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    if gain is not None:
        spec *= gain(f)[:, None]
    spec[0] = 0.0
    x = np.fft.irfft(spec, n, axis=0)
    x /= np.maximum(np.sqrt(np.mean(x ** 2, axis=0)), 1e-12)
    return x[:, 0] if channels == 1 else x


def pink(f):
    return 1.0 / np.sqrt(np.maximum(f, 20.0))


def brown(f):
    return 1.0 / np.maximum(f, 20.0)


def wander(n, rng, rate_hz, channels=1):
    """Smooth random curve in -1..1, periodic over n (slow modulation)."""
    size = n // 2 + 1
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spec = (rng.standard_normal((size, channels)) + 1j * rng.standard_normal((size, channels)))
    spec *= np.exp(-0.5 * (f / rate_hz) ** 2)[:, None]
    spec[0] = 0.0
    x = np.fft.irfft(spec, n, axis=0)
    x /= np.maximum(np.max(np.abs(x), axis=0), 1e-12)
    return x[:, 0] if channels == 1 else x


def lfo(n, cycles, phase=0.0):
    """Sine LFO making a whole number of cycles over n samples (loop-safe)."""
    return np.sin(TAU * (cycles * np.arange(n) / n + phase))


# --- stereo, space ----------------------------------------------------------

def pan(x, position):
    """Equal-power pan of a mono signal; centre = 1.0 in both channels."""
    a = (np.clip(position, -1.0, 1.0) + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1) * np.sqrt(2.0)


def width(x, amount):
    """Mid/side width (0 = mono, 1 = unchanged, >1 wider)."""
    mid = (x[:, 0] + x[:, 1]) * 0.5
    side = (x[:, 0] - x[:, 1]) * 0.5 * amount
    return np.stack([mid + side, mid - side], axis=1)


def make_ir(rt60, rng, pre_delay=0.02, length=None, dark=0.45, low=1.15,
            early=12, early_span=0.06, early_gain=0.5, build=0.012):
    """Synthetic stereo room impulse response: early reflections and a
    decorrelated noise tail decaying per band (highs die sooner). Unit
    energy per channel."""
    size = n_of(length if length is not None else rt60 * 1.25)
    t = np.arange(size) / SR
    bands = [(20.0, 300.0, rt60 * low), (300.0, 2500.0, rt60), (2500.0, 7000.0, rt60 * (0.5 + dark * 0.5)),
             (7000.0, 20000.0, rt60 * dark)]
    ir = np.zeros((size, 2))
    delay = n_of(pre_delay)
    for ch in range(2):
        white = rng.standard_normal(size)
        tail = np.zeros(size)
        for lo, hi, rt in bands:
            tail += fft_filter(white, g_band(lo, hi, 2)) * np.exp(-6.9078 * t / rt)
        tail *= 1.0 - np.exp(-t / build)
        taps = np.zeros(size)
        for k in range(early):
            at = n_of(rng.uniform(0.002, early_span))
            if at < size:
                taps[at] += rng.choice([-1.0, 1.0]) * early_gain * np.exp(-at / SR / (early_span * 0.8)) * rng.uniform(0.5, 1.0)
        taps = lowpass(taps, 6000.0, 1)
        body = tail / max(rms(tail), 1e-12) * 0.02 + taps
        ir[delay:, ch] = body[:size - delay]
    ir /= np.sqrt(np.mean(np.sum(ir ** 2, axis=0)))
    return ir


def convolve(x, ir, circular=False, cross=0.25):
    """Stereo reverb: each output channel convolves a blend of both inputs
    with its own IR channel. circular=True treats x as a loop."""
    x = stereo(x)
    n = x.shape[0]
    size = n if circular else fast_len(n + ir.shape[0])
    if circular and ir.shape[0] > n:
        raise ValueError("impulse longer than the loop")
    out = np.zeros((size if not circular else n, 2))
    for ch in range(2):
        src = x[:, ch] * (1.0 - cross) + x[:, 1 - ch] * cross
        spec = np.fft.rfft(src, size) * np.fft.rfft(ir[:, ch], size)
        out[:, ch] = np.fft.irfft(spec, size)[:out.shape[0]]
    return out if circular else out[:n + ir.shape[0]]


# --- dynamics ---------------------------------------------------------------

def saturate(x, drive=1.0):
    """tanh saturation with unity gain for small signals."""
    return np.tanh(drive * x) / drive


def sliding_min(x, w, circular=True):
    """y[i] = min(x[i - w .. i + w]) (van Herk / Gil-Werman, O(n))."""
    n = x.shape[0]
    span = 2 * w + 1
    if circular:
        xp = np.concatenate([x[-w:], x, x[:w]]) if w > 0 else x.copy()
    else:
        xp = np.concatenate([np.full(w, x[0]), x, np.full(w, x[-1])])
    extra = (-xp.shape[0]) % span
    xp = np.concatenate([xp, np.full(extra + span, np.max(xp))])
    blocks = xp.reshape(-1, span)
    prefix = np.minimum.accumulate(blocks, axis=1).ravel()
    suffix = np.minimum.accumulate(blocks[:, ::-1], axis=1)[:, ::-1].ravel()
    return np.minimum(suffix[:n], prefix[span - 1:span - 1 + n])


def box_smooth(x, w, circular=True):
    """Centred moving average over 2w + 1 samples."""
    if w <= 0:
        return x.copy()
    span = 2 * w + 1
    xp = np.concatenate([x[-w:], x, x[:w]]) if circular else np.concatenate([np.full(w, x[0]), x, np.full(w, x[-1])])
    c = np.concatenate([[0.0], np.cumsum(xp)])
    return (c[span:] - c[:-span]) / span


def exp_smooth(x, tau, circular=True):
    """Causal one-pole smoothing (time constant tau s) via FFT convolution."""
    n = x.shape[0]
    k_len = min(n_of(tau * 7.0), n)
    kernel = np.exp(-np.arange(k_len) / (tau * SR))
    kernel /= kernel.sum()
    size = n if circular else fast_len(n + k_len)
    base = x if circular else np.concatenate([x, np.full(size - n, x[-1])])
    y = np.fft.irfft(np.fft.rfft(base, size) * np.fft.rfft(kernel, size), size)
    return y[:n]


def compress(x, threshold_db=-18.0, ratio=2.0, attack=0.01, release=0.15, knee_db=6.0, circular=True):
    """Glue compressor: RMS detection, soft knee, lookahead attack (a
    sliding minimum) and a smooth release."""
    x = stereo(x)
    return x * compress_gain(x, threshold_db, ratio, attack, release, knee_db, circular)[:, None]


def compress_gain(x, threshold_db=-18.0, ratio=2.0, attack=0.01, release=0.15, knee_db=6.0, circular=True):
    """The compressor's linear gain curve (apply it to linked stems)."""
    x = stereo(x)
    power = np.mean(x ** 2, axis=1)
    level = to_db(np.sqrt(np.maximum(exp_smooth(power, max(attack, 0.002), circular), 0.0)))
    over = level - threshold_db
    half = knee_db / 2.0
    slope = 1.0 - 1.0 / ratio
    reduction = np.where(over <= -half, 0.0,
                         np.where(over >= half, over * slope, slope * (over + half) ** 2 / (2.0 * knee_db)))
    w = n_of(attack)
    fast = box_smooth(sliding_min(-reduction, w, circular), w, circular)
    held = -exp_smooth(-fast, release, circular)
    return db(np.minimum(fast, held))


def duck(n, hits, depth_db=-6.0, attack=0.005, release=0.18, circular=True):
    """Gain curve (1 = untouched) dipping at each hit sample: sidechain-style
    pumping under a kick."""
    impulses = np.zeros(n)
    for h in hits:
        impulses[int(h) % n if circular else min(int(h), n - 1)] = 1.0
    k_len = n_of(release * 6.0)
    t = np.arange(k_len) / SR
    a = n_of(attack)
    kernel = np.exp(-t / release)
    kernel[:a] = ramp(a)
    size = n if circular else fast_len(n + k_len)
    shape = np.fft.irfft(np.fft.rfft(impulses, size) * np.fft.rfft(kernel, size), size)[:n]
    shape = np.clip(shape, 0.0, 1.0)
    return 1.0 - (1.0 - db(depth_db)) * shape


def limit(x, ceiling_db=-1.5, lookahead=0.004, release=0.06, circular=True):
    """Look-ahead peak limiter; never lets a sample above the ceiling."""
    x = stereo(x)
    ceiling = float(db(ceiling_db))
    y = x * limit_gain(x, ceiling_db, lookahead, release, circular)[:, None]
    return np.clip(y, -ceiling, ceiling)


def limit_gain(x, ceiling_db=-1.5, lookahead=0.004, release=0.06, circular=True):
    """The limiter's linear gain curve (apply it to linked stems)."""
    x = stereo(x)
    ceiling = float(db(ceiling_db))
    level = np.max(np.abs(x), axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(level, 1e-12))
    w = n_of(lookahead)
    g = box_smooth(sliding_min(need, w, circular), w, circular)
    slow = 1.0 - exp_smooth(1.0 - g, release, circular)
    return np.minimum(g, slow)


# --- loudness (ITU-R BS.1770-4) ----------------------------------------------

def _biquad_mag(b, a, f):
    w = TAU * f / SR
    z1 = np.exp(-1j * w)
    z2 = z1 * z1
    return np.abs((b[0] + b[1] * z1 + b[2] * z2) / (a[0] + a[1] * z1 + a[2] * z2))


def k_weighting(f):
    """|H| of the BS.1770 K filter at SR (libebur128's parametrisation)."""
    f0, g_db, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = np.tan(np.pi * f0 / SR)
    vh = 10.0 ** (g_db / 20.0)
    vb = vh ** 0.4996667741545416
    a0 = 1.0 + k / q + k * k
    shelf_b = [(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    shelf_a = [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]
    f1, q1 = 38.13547087602444, 0.5003270373238773
    k = np.tan(np.pi * f1 / SR)
    a1 = 1.0 + k / q1 + k * k
    hp_b = [1.0, -2.0, 1.0]
    hp_a = [1.0, 2.0 * (k * k - 1.0) / a1, (1.0 - k / q1 + k * k) / a1]
    return _biquad_mag(shelf_b, shelf_a, f) * _biquad_mag(hp_b, hp_a, f)


def loudness_blocks(x, block=0.4, overlap=0.75, circular=False):
    x = stereo(x)
    y = fft_filter(x, k_weighting, circular=True)
    size = n_of(block)
    hop = max(int(size * (1.0 - overlap)), 1)
    if circular:
        y = np.concatenate([y, y[:size]])
    power = np.sum(y ** 2, axis=1)
    c = np.concatenate([[0.0], np.cumsum(power)])
    starts = np.arange(0, y.shape[0] - size + 1, hop)
    return (c[starts + size] - c[starts]) / size


def lufs(x, circular=False):
    """Integrated loudness (LUFS) with the absolute and relative gates."""
    z = loudness_blocks(x, circular=circular)
    if z.size == 0:
        return -120.0
    loud = -0.691 + 10.0 * np.log10(np.maximum(z, 1e-20))
    keep = z[loud > -70.0]
    if keep.size == 0:
        return -120.0
    relative = -0.691 + 10.0 * np.log10(np.mean(keep)) - 10.0
    keep = z[(loud > -70.0) & (loud > relative)]
    return float(-0.691 + 10.0 * np.log10(np.mean(keep)))


def short_term_max(x, circular=False):
    z = loudness_blocks(x, block=3.0, overlap=0.9, circular=circular)
    return float(-0.691 + 10.0 * np.log10(np.max(z))) if z.size else -120.0


def true_peak(x, factor=4, chunk=1 << 16):
    """Peak of a 4x oversampled copy (FFT resampling per chunk), in dBFS."""
    x = stereo(x)
    best = 0.0
    margin = 256
    for start in range(0, x.shape[0], chunk):
        a = max(start - margin, 0)
        b = min(start + chunk + margin, x.shape[0])
        seg = x[a:b]
        m = seg.shape[0]
        spec = np.fft.rfft(seg, axis=0)
        up = np.fft.irfft(spec, m * factor, axis=0) * factor
        lo = (start - a) * factor
        hi = lo + (min(start + chunk, x.shape[0]) - start) * factor
        best = max(best, float(np.max(np.abs(up[lo:hi]))))
    return float(to_db(best))


# --- output -----------------------------------------------------------------

def seam_rotation(x, before=0.15, after=0.02, window=0.008):
    """Samples to start a loop file early (np.roll(x, k)): the file then
    begins k samples before the loop's downbeat, at the steadiest spot of
    the last [before .. after] s (least energy, highs weighted). A lossy
    encoder treats a file's first and last samples as edges; this keeps a
    transient on the downbeat away from them. Rotating a circular loop
    changes nothing musically."""
    x = stereo(x)
    n = x.shape[0]
    highs = fft_filter(x, g_highpass(3000.0, 2), circular=True)
    power = np.sum(x ** 2, axis=1) + 4.0 * np.sum(highs ** 2, axis=1)
    w = n_of(window)
    c = np.concatenate([[0.0], np.cumsum(np.concatenate([power[-w:], power, power[:w]]))])
    best_k, best = n_of(after), np.inf
    for k in range(n_of(after), n_of(before), 32):
        at = n - k + w   # index of loop sample n - k in the padded array
        energy = c[at + w] - c[at - w]
        if energy < best:
            best_k, best = k, energy
    return best_k


def rotate(x, k):
    """The loop starting k samples earlier (circular)."""
    return np.roll(np.asarray(x, dtype=float), k, axis=0)


def intermediates_dir(root):
    """build/audio_src/ with a .gdignore, so Godot never imports the WAV
    intermediates (only the encoded .ogg files in assets/)."""
    path = root / "build" / "audio_src"
    path.mkdir(parents=True, exist_ok=True)
    (path / ".gdignore").touch()
    return path


def to_pcm16(x, rng):
    """TPDF-dithered 16-bit samples."""
    x = stereo(x) if np.asarray(x).ndim == 2 else np.asarray(x, dtype=float)
    dither = (rng.random(x.shape) - rng.random(x.shape)) / 32768.0
    return np.clip(np.round((x + dither) * 32767.0), -32767, 32767).astype("<i2")


def write_wav(path, x, rng, channels=None):
    x = np.asarray(x, dtype=float)
    if channels == 1:
        x = mono(x)
    data = to_pcm16(x, rng)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1 if data.ndim == 1 else data.shape[1])
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(data.tobytes())


def read_wav(path):
    with wave.open(str(path), "rb") as src:
        frames = src.readframes(src.getnframes())
        data = np.frombuffer(frames, dtype="<i2").astype(float) / 32767.0
        ch = src.getnchannels()
    return data.reshape(-1, ch) if ch > 1 else data


# --- timeline ---------------------------------------------------------------

class Timeline:
    """Stereo buffer events are mixed into. A loop wraps everything that
    rings past its end back to its start (the steady state of looping);
    a one-shot grows to hold its tails."""

    def __init__(self, seconds=None, samples=None, loop=True):
        self.n = samples if samples is not None else n_of(seconds)
        self.loop = loop
        self.buf = np.zeros((self.n, 2))

    def add(self, at, sig, gain=1.0, pan_pos=0.0):
        """Mixes [param sig] (mono or stereo) in at sample [param at]."""
        sig = np.asarray(sig, dtype=float)
        if sig.ndim == 1:
            sig = pan(sig, pan_pos) if pan_pos else stereo(sig)
        sig = sig * gain
        at = int(at)
        m = sig.shape[0]
        if not self.loop:
            if at < 0:
                sig = sig[-at:]
                m = sig.shape[0]
                at = 0
            if at + m > self.buf.shape[0]:
                self.buf = np.concatenate([self.buf, np.zeros((at + m - self.buf.shape[0], 2))])
            self.buf[at:at + m] += sig
            return
        at %= self.n
        done = 0
        while done < m:
            room = min(self.n - at, m - done)
            self.buf[at:at + room] += sig[done:done + room]
            done += room
            at = 0

    def at_time(self, seconds):
        return n_of(seconds) if seconds > 0 else 0
