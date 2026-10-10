"""The System's voice: Kokoro's dry take made machine-like (offline, deterministic).

Level 0 = untouched. Level 1 = machine: the pitch movement is squashed toward
the line's median and snapped to whole semitones (the flat, stepped announcer
intonation) plus a faint metallic comb. Level 2 = broken: level 1, then seeded
glitches — pitch jumps on a few syllables, stutters at quiet points, short
dropouts.

Plain numpy: a YIN pitch tracker (track_f0) and TD-PSOLA (pitch-synchronous
overlap-add) change the pitch without touching the timbre or the timing. The
WORLD vocoder (pyworld) was the first choice; it needs a compiler with the
Windows SDK, which this PC does not have. resynthesize() is the one seam: a
WORLD backend (harvest/cheaptrick/d4c/synthesize) would replace just that.
"""
import numpy as np

FRAME_MS = 5.0
WINDOW_MS = 40.0                 # YIN analysis window (> 2 periods at F0_MIN)
F0_MIN, F0_MAX = 60.0, 500.0
YIN_THRESHOLD = 0.15             # the first dip of the normalized difference below this = the period
YIN_VOICED_MAX = 0.35            # no dip this deep = unvoiced
GATE_DB = -38.0                  # frames quieter than this (re the loudest) are unvoiced
MIN_VOICED_FRAMES = 3
UNVOICED_HOP_MS = 5.0            # mark spacing where there is no pitch
SQUASH = {1: 0.25, 2: 0.35}      # share of the original pitch movement that survives
COMB_MS, COMB_MIX = 1.6, 0.12
JUMPS = (-7, -5, 3, 5, 7)        # semitones of a level-2 pitch jump
_CHUNK = 256


# --- analysis -----------------------------------------------------------------

def track_f0(x, sr, frame_period=FRAME_MS):
    """YIN pitch track: (f0 in Hz per frame, 0 = unvoiced; frame times in s)."""
    x = np.asarray(x, dtype=np.float64)
    hop = int(round(sr * frame_period / 1000.0))
    win = int(round(sr * WINDOW_MS / 1000.0))
    tau_min, tau_max = int(sr / F0_MAX), int(np.ceil(sr / F0_MIN))
    n = len(x) // hop + 1
    t = np.arange(n) * hop / sr
    seg_len = win + tau_max
    xp = np.concatenate([np.zeros(win // 2), x, np.zeros(seg_len)])
    nfft = 1 << int(np.ceil(np.log2(seg_len)))
    taus = np.arange(tau_max + 1)
    f0 = np.zeros(n)
    energy = np.zeros(n)
    for start in range(0, n, _CHUNK):
        rows = np.arange(start, min(n, start + _CHUNK))
        seg = xp[(rows * hop)[:, None] + np.arange(seg_len)[None, :]]
        a = seg[:, :win]
        acf = np.fft.irfft(np.conj(np.fft.rfft(a, nfft)) * np.fft.rfft(seg, nfft), nfft)[:, :tau_max + 1]
        sq = np.concatenate([np.zeros((len(rows), 1)), np.cumsum(seg ** 2, axis=1)], axis=1)
        e1 = sq[:, win]
        e2 = sq[:, win:win + tau_max + 1] - sq[:, :tau_max + 1]
        d = np.maximum(e1[:, None] + e2 - 2.0 * acf, 0.0)
        cmnd = d * taus / np.maximum(np.cumsum(d, axis=1), 1e-12)
        cmnd[:, 0] = 1.0
        energy[rows] = np.sqrt(e1 / win)
        for k, row in enumerate(rows):
            f0[row] = _pick_period(cmnd[k], tau_min, tau_max, sr)
    f0[energy < energy.max() * 10 ** (GATE_DB / 20)] = 0.0
    return _clean(f0), t


def _pick_period(cmnd, tau_min, tau_max, sr):
    below = np.flatnonzero(cmnd[tau_min:tau_max] < YIN_THRESHOLD)
    if len(below):
        tau = tau_min + below[0]
        while tau + 1 < tau_max and cmnd[tau + 1] < cmnd[tau]:
            tau += 1
    else:
        tau = tau_min + int(np.argmin(cmnd[tau_min:tau_max]))
        if cmnd[tau] > YIN_VOICED_MAX:
            return 0.0
    a, b, c = cmnd[tau - 1], cmnd[tau], cmnd[tau + 1]
    denom = a - 2.0 * b + c
    shift = 0.5 * (a - c) / denom if denom > 1e-12 else 0.0
    return sr / (tau + float(np.clip(shift, -1.0, 1.0)))


def _clean(f0):
    """Fills 1-frame holes, drops voiced islands shorter than MIN_VOICED_FRAMES, medians outliers."""
    out = f0.copy()
    for i in range(1, len(out) - 1):
        if out[i] == 0.0 and out[i - 1] > 0.0 and out[i + 1] > 0.0:
            out[i] = 0.5 * (out[i - 1] + out[i + 1])
    for s, e in _runs(out > 0.0):
        if e - s < MIN_VOICED_FRAMES:
            out[s:e] = 0.0
        else:
            seg = out[s:e]
            padded = np.concatenate([seg[:2][::-1], seg, seg[-2:][::-1]])
            out[s:e] = np.median(np.lib.stride_tricks.sliding_window_view(padded, 5), axis=1)
    return out


def _runs(mask):
    """(start, end) of every run of True."""
    edges = np.flatnonzero(np.diff(np.concatenate([[0], mask.astype(np.int8), [0]])))
    return list(zip(edges[::2], edges[1::2]))


# --- the machine intonation -----------------------------------------------------

def flatten_pitch(f0, level, rng):
    voiced = f0 > 0
    if not voiced.any():
        return f0
    ref = float(np.median(f0[voiced]))
    semis = np.round(12.0 * np.log2(f0[voiced] / ref) * SQUASH[level])
    out = f0.copy()
    out[voiced] = ref * 2.0 ** (semis / 12.0)
    if level >= 2:
        frames = np.flatnonzero(voiced)
        for _ in range(max(1, len(frames) // 400)):      # about one jump per 2 s of voicing
            start = int(rng.choice(frames))
            seg = out[start:start + int(rng.integers(16, 40))]
            seg[seg > 0] *= 2.0 ** (int(rng.choice(JUMPS)) / 12.0)
    return out


# --- resynthesis (TD-PSOLA) -------------------------------------------------------

def resynthesize(x, sr, f0, t, new_f0):
    """[param x] with its pitch moved from [param f0] to [param new_f0] (per frame), same length."""
    hop = int(round(sr * FRAME_MS / 1000.0))
    marks = pitch_marks(x, sr, f0, hop)
    ratio = np.ones(len(f0))
    voiced = (f0 > 0) & (new_f0 > 0)
    ratio[voiced] = new_f0[voiced] / f0[voiced]
    frame_of = np.minimum(np.round(np.arange(len(x)) / hop).astype(int), len(f0) - 1)
    return _psola(x, marks, ratio[frame_of])


def pitch_marks(x, sr, f0, hop):
    """One mark per period (on the waveform's peak) where voiced, every UNVOICED_HOP_MS elsewhere."""
    n = len(x)
    smooth = _lowpass(x, sr, 1000.0)
    unvoiced_hop = int(round(sr * UNVOICED_HOP_MS / 1000.0))
    frames = np.arange(len(f0))
    marks = []
    cursor = 0
    for s, e in _runs(f0 > 0):
        s0, s1 = max(0, s * hop - hop // 2), min(n, e * hop - hop // 2)
        if s1 - s0 < 2:
            continue
        marks.extend(range(cursor, s0, unvoiced_hop))
        period = lambda m: sr / np.interp(m / hop, frames[s:e], f0[s:e])
        t0 = int(period(s0))
        m = s0 + int(np.argmax(smooth[s0:min(s1, s0 + max(t0, 2))]))
        while m < s1:
            marks.append(m)
            p = period(m)
            lo, hi = m + int(0.7 * p), min(s1, m + int(1.3 * p) + 1)
            if lo >= s1 or hi <= lo:
                m = s1 + max(int(0.7 * p), 1)
                break
            m = lo + int(np.argmax(smooth[lo:hi]))
        cursor = min(max(m, s1), n)
    marks.extend(range(cursor, n, unvoiced_hop))
    marks = np.unique(np.asarray(marks, dtype=int))
    return marks[(marks >= 0) & (marks < n)]


def _lowpass(x, sr, cutoff):
    spec = np.fft.rfft(x)
    spec[np.fft.rfftfreq(len(x), 1.0 / sr) > cutoff] = 0.0
    return np.fft.irfft(spec, len(x))


def _psola(x, marks, ratio):
    """Pitch-synchronous OLA: Hann grains of two periods around the analysis marks,
    laid down at target marks spaced by the source period / ratio; the window
    sum normalizes the level (raising the pitch packs grains closer)."""
    n = len(x)
    y = np.zeros(n)
    wsum = np.zeros(n)
    if len(marks) < 2:
        return x.copy()
    spacing = np.diff(marks)
    forward = np.append(spacing, spacing[-1])
    backward = np.concatenate([[spacing[0]], spacing])
    half = np.maximum(np.minimum(forward, backward), 8)
    t_out = float(marks[0])
    while t_out < n:
        i = int(np.searchsorted(marks, t_out))
        if i >= len(marks) or (i > 0 and t_out - marks[i - 1] < marks[i] - t_out):
            i -= 1
        c, p = int(marks[i]), int(half[i])
        grain = _slice(x, c - p, c + p) * np.hanning(2 * p)
        pos = int(round(t_out))
        _add(y, grain, pos - p)
        _add(wsum, np.hanning(2 * p), pos - p)
        t_out += forward[i] / ratio[min(pos, n - 1)]
    return y / np.maximum(wsum, 0.35)


def _slice(x, a, b):
    out = np.zeros(b - a)
    lo, hi = max(a, 0), min(b, len(x))
    if hi > lo:
        out[lo - a:hi - a] = x[lo:hi]
    return out


def _add(dst, grain, at):
    lo, hi = max(at, 0), min(at + len(grain), len(dst))
    if hi > lo:
        dst[lo:hi] += grain[lo - at:hi - at]


# --- colour and damage ------------------------------------------------------------

def comb(y, sr):
    d = int(sr * COMB_MS / 1000)
    out = y.copy()
    out[d:] += COMB_MIX * y[:-d]
    return out


def glitch(y, sr, rng):
    """Two stutters (a 60-90 ms grain repeated) at quiet points, two 25 ms dropouts."""
    out = y.copy()
    hop = int(0.01 * sr)
    env = np.sqrt(np.convolve(out ** 2, np.ones(hop) / hop, mode="same"))
    quiet = np.flatnonzero(env < 0.25 * env.max())
    for _ in range(2):
        if len(quiet) == 0:
            break
        at = int(rng.choice(quiet))
        grain = int(rng.uniform(0.06, 0.09) * sr)
        if at + grain < len(out):
            out = np.concatenate([out[:at], np.tile(out[at:at + grain], int(rng.integers(2, 4))), out[at:]])
        quiet = quiet[quiet < at]
    drop = int(0.025 * sr)
    for _ in range(2):
        at = int(rng.integers(0, max(1, len(out) - drop)))
        out[at:at + drop] = 0.0
    return out


def process(wav, sr, level, seed):
    if level <= 0:
        return wav
    rng = np.random.default_rng(seed)
    x = np.asarray(wav, dtype=np.float64)
    f0, t = track_f0(x, sr)
    y = resynthesize(x, sr, f0, t, flatten_pitch(f0, level, rng))
    y = comb(y, sr)
    if level >= 2:
        y = glitch(y, sr, rng)
    return y.astype(np.float32)
