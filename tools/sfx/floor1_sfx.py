"""Floor I sound effects: locks, the wings' creatures, the six guardians.

numpy and the music tools' DSP (tools/music/dsp.py, instruments.py); run
through gen_sfx.py, which writes them next to the older effects in
assets/sfx/ (16-bit mono WAV, peak-normalised, LEVELS below). Each sound
draws from its own generator seeded with the CRC-32 of its name, so a run
gives the same files and adding a sound changes no other. Loops (LOOPS)
are rendered circularly (what rings past the end wraps onto the start) and
their .import gets loop_mode forward.

Weapons are not here (their own builder makes them).
"""
import sys
import zlib
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "music"))
import dsp  # noqa: E402
import instruments as ins  # noqa: E402
from dsp import SR, TAU, g_band, g_highpass, g_lowpass, g_mul, g_peak  # noqa: E402


def n_(seconds):
    return dsp.n_of(seconds)


def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode("utf-8")))


def put(out, at, sig, gain=1.0):
    """Mixes [param sig] into [param out] at [param at] s (clipped to its end)."""
    i = n_(at) if at > 0 else 0
    if i >= out.shape[0]:
        return out
    m = min(sig.shape[0], out.shape[0] - i)
    out[i:i + m] += sig[:m] * gain
    return out


def mx(*sigs):
    """Sum of signals of any lengths (padded to the longest)."""
    m = max(s.shape[0] for s in sigs)
    return sum(dsp.pad_to(s, m) for s in sigs)


def burst(rng, seconds, lo, hi, tau, attack=0.0004):
    m = n_(seconds)
    return dsp.bandpass(rng.standard_normal(m), lo, hi) * dsp.env_exp(m, tau, attack)


def thump(f0, f1, seconds, tau):
    m = n_(seconds)
    t = np.arange(m) / SR
    f = f1 + (f0 - f1) * np.exp(-t / max(seconds * 0.2, 0.01))
    return np.sin(TAU * np.cumsum(f) / SR) * dsp.env_exp(m, tau, 0.001)


def metal(rng, f0, ratios, amps, decays, seconds):
    return dsp.partials(f0, ratios, amps, decays, n_(seconds), rng=rng)


def clink(rng, f=None, level=1.0):
    f = f or rng.uniform(2200.0, 4200.0)
    ring = metal(rng, f, [1.0, 1.47, 2.09, 2.81], [1.0, 0.6, 0.4, 0.2], [0.05, 0.03, 0.02, 0.012], 0.15)
    return (ring + dsp.pad_to(burst(rng, 0.006, 2000.0, 9000.0, 0.001), ring.shape[0]) * 0.6) * level


def wood(rng, f0, seconds=0.4, level=1.0):
    plank = metal(rng, f0, [1.0, 2.6, 4.9, 7.4], [1.0, 0.5, 0.25, 0.1], [0.09, 0.04, 0.02, 0.01], seconds)
    knock = dsp.pad_to(burst(rng, 0.02, 300.0, 3000.0, 0.004), plank.shape[0])
    return (plank + knock * 0.6) * level


def rock(rng, f0=None, level=1.0):
    f0 = f0 or rng.uniform(70.0, 220.0)
    body = thump(f0 * 1.8, f0, 0.35, 0.06)
    grit = dsp.pad_to(burst(rng, 0.08, 400.0, 5000.0, 0.015), body.shape[0]) * 0.5
    return (body + grit) * level


def whoosh(rng, seconds, lo, hi, peak=0.45, power=2.0):
    m = n_(seconds)
    t = np.linspace(0.0, 1.0, m)
    shape = np.where(t < peak, (t / peak) ** power, ((1.0 - t) / (1.0 - peak)) ** (power * 0.8))
    sweep = np.exp(np.log(lo) + (np.log(hi) - np.log(lo)) * shape)
    return dsp.lowpass_sweep(rng.standard_normal(m), sweep, 2) * shape


def grind(rng, seconds, lo=80.0, hi=900.0, slip=11.0, depth=0.7):
    m = n_(seconds)
    t = np.arange(m) / SR
    rate = slip * (1.0 + 0.3 * np.sin(TAU * 0.7 * t + rng.uniform(0, TAU)))
    slipper = 1.0 - depth * (0.5 + 0.5 * np.sin(TAU * np.cumsum(rate) / SR)) ** 4
    return dsp.bandpass(rng.standard_normal(m), lo, hi) * slipper


def grains(rng, seconds, count, make, shape=None):
    out = np.zeros(n_(seconds))
    for _ in range(count):
        at = rng.uniform(0.0, seconds) if shape is None else seconds * shape(rng)
        put(out, at, make())
    return out


def space(x, rng, rt60=1.2, wet=0.3, dark=0.45):
    ir = dsp.mono(dsp.make_ir(rt60, rng, 0.012, rt60 * 1.1, dark, early=10, early_span=0.03))
    size = dsp.fast_len(x.shape[0] + ir.shape[0])
    w = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:x.shape[0] + ir.shape[0]]
    return dsp.pad_to(x, w.shape[0]) * (1.0 - wet) + w * wet * 0.4


def voice(rng, f0, seconds, formants, rasp=0.5, attack=0.15, release=0.4):
    """A throat: a pulse train gliding along [param f0] (Hz array or
    value) through vowel formants, roughened by noise (rasp)."""
    m = n_(seconds)
    f = np.broadcast_to(np.asarray(f0, dtype=float), (m,)) * (1.0 + 0.015 * dsp.wander(m, rng, 6.0))
    src = dsp.osc(f, m, "saw", rng.uniform()) * (1.0 - rasp * 0.5) + rng.standard_normal(m) * rasp * 0.5
    src *= 1.0 + 0.3 * np.sin(TAU * np.cumsum(np.full(m, rng.uniform(24.0, 34.0))) / SR) * rasp

    def shape(fr):
        g = np.full_like(fr, 0.03)
        for centre, amp, q in formants:
            g = g + amp * g_peak(centre, q)(fr)
        return g
    return dsp.fft_filter(src, shape) * dsp.env_ar(m, attack, release)


def loop_wrap(x, seconds):
    """Folds what rings past [param seconds] back onto the start (a loop's
    steady state)."""
    m = n_(seconds)
    out = np.zeros(m)
    for start in range(0, x.shape[0], m):
        seg = x[start:start + m]
        out[:seg.shape[0]] += seg
    return out


VOWEL_OH = [(450.0, 1.0, 5.0), (800.0, 0.6, 6.0), (2600.0, 0.15, 10.0)]
VOWEL_AH = [(700.0, 1.0, 5.0), (1150.0, 0.6, 6.0), (2700.0, 0.2, 10.0)]


# --- locks -----------------------------------------------------------------------

def lock_chain_break(rng):
    """The padlock's shackle snaps, the chain slithers down and piles up."""
    out = np.zeros(n_(1.6))
    put(out, 0.0, burst(rng, 0.05, 1500.0, 12000.0, 0.008), 1.2)
    put(out, 0.0, metal(rng, 1650.0, [1.0, 1.52, 2.33, 3.1], [1.0, 0.7, 0.5, 0.3], [0.25, 0.15, 0.1, 0.06], 0.6), 0.7)
    put(out, 0.0, thump(240.0, 120.0, 0.2, 0.05), 0.6)
    t = 0.06
    gap = 0.03
    for k in range(18):
        put(out, t, clink(rng, level=rng.uniform(0.4, 1.0) * (1.0 - k / 30.0)))
        t += gap * rng.uniform(0.6, 1.4)
        gap *= 1.08
    put(out, t, thump(160.0, 90.0, 0.25, 0.06), 0.5)
    for k in range(6):
        put(out, t + rng.uniform(0.0, 0.25), clink(rng, rng.uniform(1500.0, 2600.0), rng.uniform(0.2, 0.5)))
    return space(out, rng, 1.0, 0.25)


def lock_boards_hit(rng):
    """A blow on boarded-up planks: they boom, rattle on their nails, hold."""
    out = np.zeros(n_(0.7))
    put(out, 0.0, wood(rng, rng.uniform(120.0, 160.0), 0.5), 1.0)
    put(out, 0.0, thump(110.0, 70.0, 0.25, 0.05), 0.7)
    for k in range(4):
        put(out, 0.03 + k * 0.035, wood(rng, rng.uniform(300.0, 450.0), 0.15, 0.3))
    put(out, 0.08, ins.pluck(rng.uniform(80.0, 90.0), 0.3, rng, t60=0.3, bright=0.6) * 0.3)
    return space(out, rng, 0.8, 0.2)


def lock_boards_splinter(rng):
    """The planks give: a splintering crack, nails shriek out, boards clatter."""
    out = np.zeros(n_(1.8))
    put(out, 0.0, thump(140.0, 60.0, 0.4, 0.09), 1.0)
    put(out, 0.0, grains(rng, 0.35, 160, lambda: burst(rng, 0.006, 1200.0, 8000.0, 0.0015) * rng.uniform(0.2, 1.0)), 1.0)
    put(out, 0.0, burst(rng, 0.08, 600.0, 6000.0, 0.02), 0.9)
    for k in range(2):
        m = n_(0.25)
        t = np.arange(m) / SR
        f = rng.uniform(1600.0, 2600.0) * (1.0 - 0.3 * t / t[-1])
        squeal = np.sin(TAU * np.cumsum(f) / SR) * dsp.env_ar(m, 0.02, 0.1) * (0.6 + 0.4 * np.abs(np.sin(TAU * 40.0 * t)))
        put(out, 0.08 + 0.1 * k, squeal, 0.15)
    t0 = 0.35
    for k in range(5):
        put(out, t0, wood(rng, rng.uniform(150.0, 320.0), 0.35, rng.uniform(0.4, 0.8)))
        t0 += rng.uniform(0.12, 0.25)
    return space(out, rng, 1.0, 0.25)


def lock_wall_crack(rng):
    """A cracked wall takes a blow: a stony crack and a trickle of grit."""
    out = np.zeros(n_(1.2))
    put(out, 0.0, burst(rng, 0.04, 800.0, 7000.0, 0.008), 1.0)
    put(out, 0.0, rock(rng, 90.0), 0.9)
    put(out, 0.05, grains(rng, 0.9, 70, lambda: burst(rng, 0.004, 1500.0, 7000.0, 0.001) * rng.uniform(0.1, 0.5),
                          lambda r: r.beta(1.2, 3.0)), 0.6)
    return space(out, rng, 1.0, 0.25)


def lock_wall_collapse(rng):
    """The wall comes down: a blast of masonry, rocks tumbling, dust settling."""
    out = np.zeros(n_(3.2))
    put(out, 0.0, thump(80.0, 32.0, 1.2, 0.35), 1.2)
    put(out, 0.0, burst(rng, 0.3, 200.0, 5000.0, 0.08), 0.9)
    put(out, 0.0, dsp.lowpass(rng.standard_normal(n_(2.5)), 300.0) * dsp.env_exp(n_(2.5), 0.7, 0.02), 1.2)
    for k in range(30):
        put(out, 2.2 * rng.beta(1.3, 2.5), rock(rng, level=rng.uniform(0.3, 1.0)))
    put(out, 0.2, grains(rng, 2.8, 400, lambda: burst(rng, 0.004, 1000.0, 6000.0, 0.001) * rng.uniform(0.05, 0.4),
                         lambda r: r.beta(1.5, 3.0)), 0.6)
    dust = dsp.bandpass(rng.standard_normal(n_(3.0)), 2000.0, 8000.0) * dsp.env_ar(n_(3.0), 0.3, 2.0) * 0.05
    put(out, 0.1, dust)
    return space(out, rng, 1.6, 0.3)


def lock_seal_insert(rng):
    """A seal set into its recess: a heavy stone click, then a low hum of
    the old mechanism waking (D and A)."""
    out = np.zeros(n_(2.2))
    put(out, 0.0, rock(rng, 120.0), 1.0)
    put(out, 0.0, metal(rng, 900.0, [1.0, 1.7, 2.6], [1.0, 0.5, 0.3], [0.12, 0.06, 0.03], 0.4), 0.4)
    m = n_(1.9)
    t = np.arange(m) / SR
    hum = (np.sin(TAU * 73.42 * t) + 0.6 * np.sin(TAU * 110.0 * t) + 0.25 * np.sin(TAU * 146.83 * t * 1.002)) * dsp.env_ar(m, 0.5, 0.8) * 0.5
    shimmer = ins.glass(74, 1.2, 0.5, rng, attack=0.4, release=0.5)
    put(out, 0.15, hum, 0.5)
    put(out, 0.25, shimmer, 0.4)
    return space(out, rng, 1.8, 0.35)


def lock_seal_grind(rng):
    """A stone gate grinds open on its pivot and settles with a thud."""
    out = np.zeros(n_(4.0))
    g = grind(rng, 3.0, 60.0, 900.0, 9.0) * dsp.env_ar(n_(3.0), 0.4, 0.5)
    res = dsp.fft_filter(g, lambda f: 0.4 + g_peak(95.0, 4.0)(f) + 0.6 * g_peak(190.0, 5.0)(f))
    put(out, 0.0, res, 1.0)
    put(out, 0.0, dsp.lowpass(rng.standard_normal(n_(3.0)), 120.0) * dsp.env_ar(n_(3.0), 0.5, 0.5), 0.8)
    put(out, 0.2, grains(rng, 2.6, 40, lambda: burst(rng, 0.01, 1500.0, 6000.0, 0.002) * rng.uniform(0.1, 0.4)), 0.5)
    put(out, 3.0, thump(70.0, 40.0, 0.8, 0.2), 1.0)
    put(out, 3.0, rock(rng, 80.0), 0.6)
    return space(out, rng, 2.0, 0.35)


def lock_shutter_roll(rng):
    """A steel fire shutter: the relay clunks, the motor hums up, the slats
    rattle into the roll above, it stops with a clank."""
    out = np.zeros(n_(3.6))
    put(out, 0.0, burst(rng, 0.01, 2000.0, 9000.0, 0.002), 0.9)
    put(out, 0.0, thump(180.0, 90.0, 0.2, 0.04), 0.8)
    m = n_(3.0)
    t = np.arange(m) / SR
    motor = sum(a * np.sin(TAU * f * t * (1.0 + 0.02 * np.minimum(t / 0.5, 1.0))) for f, a in [(50.0, 0.6), (100.0, 1.0), (150.0, 0.4),
                                                                                                    (200.0, 0.3), (300.0, 0.15)])
    motor *= dsp.env_ar(m, 0.4, 0.15)
    put(out, 0.1, motor, 0.35)
    slats = np.zeros(m)
    rate = 22.0
    k = 0
    while k / rate < 2.85:
        at = k / rate + rng.normal(0, 0.002)
        put(slats, max(at, 0.0), mx(metal(rng, rng.uniform(900.0, 1400.0), [1.0, 1.9, 3.1], [1.0, 0.4, 0.2], [0.02, 0.012, 0.006], 0.06),
                                    thump(220.0, 150.0, 0.05, 0.012) * 0.5), rng.uniform(0.4, 0.8))
        k += 1
    put(out, 0.25, slats * dsp.env_ar(m, 0.4, 0.2), 0.5)
    put(out, 3.1, mx(metal(rng, 520.0, [1.0, 1.52, 2.4, 3.3], [1.0, 0.6, 0.4, 0.2], [0.3, 0.2, 0.1, 0.06], 0.5),
                     thump(140.0, 70.0, 0.3, 0.06)), 0.9)
    return space(out, rng, 1.1, 0.25)


def lock_power_on(rng):
    """Power comes back: a big relay slams, the mains hum swells, a lamp
    turns green with a beep."""
    out = np.zeros(n_(2.2))
    put(out, 0.0, burst(rng, 0.012, 1500.0, 9000.0, 0.003), 1.0)
    put(out, 0.0, thump(160.0, 70.0, 0.3, 0.06), 1.0)
    put(out, 0.03, metal(rng, 1300.0, [1.0, 1.6], [1.0, 0.4], [0.05, 0.03], 0.2), 0.4)
    m = n_(1.9)
    t = np.arange(m) / SR
    hum = sum(a * np.sin(TAU * f * t) for f, a in [(50.0, 0.7), (100.0, 1.0), (150.0, 0.5), (200.0, 0.25), (250.0, 0.2)])
    hum = dsp.fft_filter(np.tanh(2.0 * hum), g_lowpass(3000.0, 1)) * dsp.env_ar(m, 0.6, 0.5)
    put(out, 0.1, hum, 0.3)
    beep_m = n_(0.18)
    beep = np.sin(TAU * 1568.0 * np.arange(beep_m) / SR) * dsp.env_ar(beep_m, 0.005, 0.03)
    put(out, 0.9, beep, 0.25)
    return space(out, rng, 0.9, 0.2)


def lock_bolt_slide(rng):
    """A door bolt drawn back: a short scrape of iron and a clack home."""
    out = np.zeros(n_(0.7))
    m = n_(0.3)
    scrape = dsp.bandpass(rng.standard_normal(m), 1200.0, 6000.0) * dsp.env_ar(m, 0.05, 0.08) * (0.7 + 0.3 * np.sin(TAU * 60.0 * np.arange(m) / SR))
    put(out, 0.02, scrape, 0.5)
    put(out, 0.32, mx(metal(rng, 1900.0, [1.0, 1.5, 2.7], [1.0, 0.5, 0.3], [0.05, 0.03, 0.015], 0.2), thump(260.0, 160.0, 0.08, 0.02)), 1.0)
    return space(out, rng, 0.7, 0.2)


def lock_rope_snap(rng):
    """A taut rope parts: fibres tear faster and faster, a whip crack, the
    loose end whips away."""
    out = np.zeros(n_(1.3))
    t = 0.0
    gap = 0.05
    for k in range(24):   # fibres giving way faster and faster
        put(out, t, burst(rng, 0.004, 1500.0, 7000.0, 0.001), rng.uniform(0.2, 0.5))
        t += max(gap, 0.004)
        gap *= 0.88
    put(out, 0.36, burst(rng, 0.02, 800.0, 12000.0, 0.004), 1.4)
    put(out, 0.36, thump(300.0, 150.0, 0.1, 0.02), 0.4)
    put(out, 0.38, whoosh(rng, 0.5, 300.0, 3000.0, 0.25), 0.6)
    return space(out, rng, 1.2, 0.3)


def lock_counterweight(rng):
    """Far off, a counterweight drops: a rush of air, a heavy landing, its
    chain rattling and the bell above it ringing out."""
    out = np.zeros(n_(3.5))
    put(out, 0.0, whoosh(rng, 0.6, 150.0, 1200.0, 0.8), 0.4)
    put(out, 0.6, thump(90.0, 40.0, 0.8, 0.2), 1.0)
    put(out, 0.6, rock(rng, 110.0), 0.6)
    for k in range(10):
        put(out, 0.6 + k * 0.04 * rng.uniform(0.7, 1.3), clink(rng, rng.uniform(1500.0, 2800.0), 0.4 * (1.0 - k / 12.0)))
    put(out, 0.65, ins.church_bell(62.0, 0.8, rng, length=2.8), 0.6)
    out = dsp.fft_filter(out, g_lowpass(5000.0, 1))
    return space(out, rng, 2.0, 0.45, dark=0.35)


def lock_hook_pull(rng):
    """The harpoon line hauls on an iron eye: the rope creaks under load,
    something heavy drags across the floor, old wood groans."""
    out = np.zeros(n_(2.0))
    m = n_(1.4)
    t = np.arange(m) / SR
    rate = 18.0 * (1.0 + 0.8 * np.sin(np.pi * t / t[-1]))
    pulses = np.zeros(m)
    ph = np.cumsum(rate) / SR
    idx = np.searchsorted(ph, np.arange(1, int(ph[-1])))
    pulses[idx[idx < m]] = rng.uniform(0.5, 1.0, np.sum(idx < m))
    creak = dsp.fft_filter(pulses, lambda f: g_peak(420.0, 8.0)(f) + 0.7 * g_peak(980.0, 9.0)(f) + 0.3 * g_peak(2100.0, 10.0)(f))
    put(out, 0.0, creak * dsp.env_ar(m, 0.1, 0.3), 1.0)
    drag = grind(rng, 1.5, 70.0, 700.0, 14.0) * dsp.env_ar(n_(1.5), 0.3, 0.4)
    put(out, 0.3, drag, 0.8)
    put(out, 1.7, thump(120.0, 70.0, 0.3, 0.07), 0.6)
    return space(out, rng, 1.0, 0.25)


# --- creatures ---------------------------------------------------------------------

def mummy_groan(rng):
    """A dry, rasping moan out of linen and dust."""
    m = n_(1.7)
    t = np.arange(m) / SR
    f0 = 92.0 * (1.0 + 0.12 * np.sin(np.pi * t / t[-1])) * (1.0 - 0.15 * t / t[-1])
    v = voice(rng, f0, 1.7, VOWEL_OH, rasp=0.75, attack=0.25, release=0.6)
    dust = grains(rng, 1.7, 60, lambda: burst(rng, 0.004, 1500.0, 6000.0, 0.001) * rng.uniform(0.05, 0.2))
    return space(v + dust, rng, 0.9, 0.2)


def mummy_lash(rng):
    """The bandage whip: linen unrolls with a flutter, whistles and snaps."""
    out = np.zeros(n_(0.8))
    m = n_(0.45)
    t = np.arange(m) / SR
    flutter = dsp.bandpass(rng.standard_normal(m), 300.0, 3500.0) * (0.5 + 0.5 * np.abs(np.sin(TAU * 38.0 * t))) * dsp.env_ar(m, 0.1, 0.15)
    put(out, 0.0, flutter, 0.6)
    put(out, 0.1, whoosh(rng, 0.35, 400.0, 4500.0, 0.7), 0.9)
    put(out, 0.44, burst(rng, 0.015, 900.0, 7000.0, 0.004), 0.9)
    return space(out, rng, 0.7, 0.2)


def hit_linen(rng):
    """A blow on a mummy: a dull, dry thump into old linen, fibres tearing
    and a sprinkle of tomb dust."""
    out = np.zeros(n_(0.45))
    put(out, 0.0, thump(170.0, 85.0, 0.18, 0.035), 0.8)
    put(out, 0.0, dsp.bandpass(rng.standard_normal(n_(0.09)), 250.0, 2200.0) * dsp.env_exp(n_(0.09), 0.025, 0.002), 0.9)
    put(out, 0.01, grains(rng, 0.12, 26, lambda: burst(rng, 0.004, 1800.0, 7000.0, 0.0012) * rng.uniform(0.15, 0.6)), 0.7)
    put(out, 0.05, grains(rng, 0.3, 50, lambda: burst(rng, 0.003, 2500.0, 9000.0, 0.0008) * rng.uniform(0.04, 0.18),
                          lambda r: r.beta(1.2, 2.5)), 0.6)
    return space(out, rng, 0.5, 0.15)


def break_linen(rng):
    """A mummy falls apart: the bandaged body slumps with a cloth whump,
    dry bones clatter onto the floor, dust pours after."""
    out = np.zeros(n_(1.6))
    put(out, 0.0, thump(120.0, 55.0, 0.4, 0.09), 0.9)
    put(out, 0.0, dsp.bandpass(rng.standard_normal(n_(0.25)), 120.0, 1600.0) * dsp.env_ar(n_(0.25), 0.04, 0.5), 0.9)
    put(out, 0.0, grains(rng, 0.18, 40, lambda: burst(rng, 0.004, 1500.0, 6500.0, 0.0012) * rng.uniform(0.2, 0.7)), 0.8)
    t = 0.12
    for k in range(9):
        put(out, t, wood(rng, rng.uniform(700.0, 1500.0), 0.12, rng.uniform(0.25, 0.7) * (1.0 - k / 14.0)))
        t += rng.uniform(0.03, 0.09)
    put(out, 0.2, grains(rng, 1.2, 140, lambda: burst(rng, 0.004, 2000.0, 8000.0, 0.001) * rng.uniform(0.03, 0.15),
                         lambda r: r.beta(1.3, 3.0)), 0.7)
    return space(out, rng, 0.9, 0.22)


def scarab_swarm(rng):
    """A loop (2 s) of a scarab swarm: chitin clicks, scrabbling legs and a
    many-winged buzz."""
    seconds = 2.0
    m = n_(seconds)
    tl = dsp.Timeline(samples=m)
    for _ in range(int(seconds * 520)):
        c = burst(rng, 0.003, 2500.0, 9000.0, 0.0006) * rng.uniform(0.1, 1.0) ** 2
        tl.add(int(rng.uniform(0, m)), c, 1.0)
    clicks = dsp.mono(tl.buf)
    buzz = np.zeros(m)
    t = np.arange(m) / SR
    for k in range(9):
        f = round(rng.uniform(150.0, 260.0) * seconds) / seconds
        am = 0.5 + 0.5 * dsp.wander(m, rng, 3.0)
        buzz += np.sign(np.sin(TAU * f * t + rng.uniform(0, TAU))) * am * rng.uniform(0.3, 1.0)
    buzz = dsp.fft_filter(buzz, g_mul(g_band(150.0, 2500.0, 2), lambda f: 0.4 + g_peak(900.0, 2.0)(f)), circular=True)
    scrabble = dsp.noise(m, rng, g_band(800.0, 5000.0, 1)) * 0.15 * (0.6 + 0.4 * dsp.wander(m, rng, 8.0))
    return clicks * 1.0 + buzz / max(dsp.rms(buzz), 1e-9) * 0.12 + scrabble


def relief_crack(rng):
    """A relief splits from its wall: stone cracks, light hums up in it."""
    out = np.zeros(n_(1.3))
    for k in range(4):
        put(out, k * rng.uniform(0.08, 0.16), burst(rng, 0.03, 900.0, 8000.0, 0.006), rng.uniform(0.5, 1.0))
    put(out, 0.0, rock(rng, 110.0), 0.7)
    put(out, 0.1, grains(rng, 0.9, 50, lambda: burst(rng, 0.005, 1500.0, 7000.0, 0.001) * rng.uniform(0.1, 0.4)), 0.6)
    m = n_(1.0)
    t = np.arange(m) / SR
    glow = np.sin(TAU * np.cumsum(330.0 + 330.0 * t) / SR) * dsp.env_ar(m, 0.4, 0.3) * 0.15
    put(out, 0.2, glow)
    return space(out, rng, 1.0, 0.25)


def relief_scrape(rng):
    """Flat stone sliding against stone (out of the wall, or back into it)."""
    m = n_(1.1)
    g = grind(rng, 1.1, 150.0, 2500.0, 16.0, 0.6) * dsp.env_ar(m, 0.15, 0.3)
    return space(g + dsp.pad_to(rock(rng, 140.0), m) * 0.3, rng, 0.9, 0.2)


def _flap(rng, level=1.0):
    m = n_(0.18)
    t = np.arange(m) / SR
    whump = dsp.bandpass(rng.standard_normal(m), 200.0, 2500.0) * np.exp(-t / 0.05) * np.minimum(t / 0.01, 1.0)
    pages = dsp.bandpass(rng.standard_normal(m), 1500.0, 8000.0) * (0.5 + 0.5 * np.abs(np.sin(TAU * 120.0 * t))) * np.exp(-t / 0.06) * 0.4
    return (whump + pages) * level


def book_flap(rng):
    """One flying book: the cover claps, the pages flutter through the air."""
    out = np.zeros(n_(0.45))
    put(out, 0.0, wood(rng, rng.uniform(260.0, 340.0), 0.12, 0.4))
    put(out, 0.0, _flap(rng))
    put(out, 0.12, _flap(rng, 0.6))
    return space(out, rng, 0.6, 0.15)


def book_flock(rng):
    """A loop (2 s) of a flock of five books beating their covers."""
    seconds = 2.0
    m = n_(seconds)
    tl = dsp.Timeline(samples=m)
    for b in range(5):
        rate = round(rng.uniform(5.0, 8.0) * seconds) / seconds
        offset = rng.uniform(0.0, 1.0 / rate)
        level = rng.uniform(0.5, 1.0)
        for k in range(int(round(seconds * rate))):
            tl.add(n_(offset + k / rate) + int(rng.normal(0, 0.004) * SR), _flap(rng, level * rng.uniform(0.8, 1.0)), 1.0)
    rustle = dsp.noise(m, rng, g_band(1500.0, 7000.0, 1)) * 0.05
    return dsp.mono(tl.buf) + rustle


def fu_roar(rng):
    """A bronze lion roars: a throat through a hollow metal body that rings."""
    m = n_(1.9)
    t = np.arange(m) / SR
    f0 = 85.0 * (1.0 + 0.35 * np.sin(np.pi * np.minimum(t / 1.5, 1.0))) * (1.0 + 0.03 * np.sin(TAU * 7.0 * t))
    throat = voice(rng, f0, 1.9, VOWEL_AH, rasp=0.6, attack=0.12, release=0.7)
    body = dsp.fft_filter(throat, lambda f: 0.3 + g_peak(820.0, 18.0)(f) + 0.8 * g_peak(1370.0, 22.0)(f) + 0.6 * g_peak(2150.0, 25.0)(f)
                          + 0.4 * g_peak(3300.0, 28.0)(f))
    ring = metal(rng, 410.0, [1.0, 1.71, 2.47, 3.6], [1.0, 0.6, 0.4, 0.2], [0.9, 0.6, 0.4, 0.25], 1.9) * dsp.env_ar(m, 0.3, 0.6)
    return space(np.tanh(1.5 * (throat * 0.6 + body * 0.8)) + ring * 0.15, rng, 1.4, 0.3)


def totem_spit(rng):
    """A carved face spits a shard: a hollow wooden pop and a whistle."""
    out = np.zeros(n_(0.6))
    put(out, 0.0, wood(rng, 240.0, 0.25), 1.0)
    put(out, 0.0, burst(rng, 0.03, 600.0, 4000.0, 0.008), 0.7)
    m = n_(0.35)
    t = np.arange(m) / SR
    whistle = np.sin(TAU * np.cumsum(2400.0 - 900.0 * t / t[-1]) / SR) * dsp.env_ar(m, 0.02, 0.2)
    put(out, 0.04, whistle, 0.2)
    put(out, 0.04, whoosh(rng, 0.3, 800.0, 6000.0, 0.2), 0.4)
    return space(out, rng, 0.7, 0.2)


def jaguar_snarl(rng):
    """A wooden jaguar warrior snarls: a hissing, ripping growl and the creak
    of carved joints."""
    m = n_(1.0)
    t = np.arange(m) / SR
    f0 = 140.0 * (1.0 + 0.25 * np.sin(np.pi * t / t[-1]))
    growl = voice(rng, f0, 1.0, VOWEL_AH, rasp=0.85, attack=0.05, release=0.35)
    hiss = dsp.bandpass(rng.standard_normal(m), 2500.0, 8000.0) * dsp.env_ar(m, 0.03, 0.4) * 0.3
    creak = wood(rng, 330.0, 0.3, 0.3)
    return space(np.tanh(2.0 * growl) * 0.8 + hiss + dsp.pad_to(creak, m), rng, 0.8, 0.2)


def hit_wood(rng):
    """A blow on carved, painted cedar (a totem, a jaguar warrior): a hard,
    hollow knock, a splinter cracking and a few chips pattering down."""
    out = np.zeros(n_(0.4))
    put(out, 0.0, wood(rng, rng.uniform(190.0, 240.0), 0.22, 1.0))
    put(out, 0.0, thump(150.0, 95.0, 0.1, 0.025), 0.6)
    put(out, 0.004, burst(rng, 0.025, 1800.0, 8000.0, 0.006), 0.55)
    for k in range(4):
        put(out, 0.06 + 0.05 * k + rng.uniform(0.0, 0.03), wood(rng, rng.uniform(900.0, 1700.0), 0.06, rng.uniform(0.08, 0.2)))
    return space(out, rng, 0.5, 0.15)


def break_wood(rng):
    """A carved block gives way: the trunk cracks along its grain, splinters
    tear, chunks and chips knock onto the floor and settle."""
    out = np.zeros(n_(1.5))
    put(out, 0.0, thump(110.0, 55.0, 0.35, 0.08), 0.8)
    put(out, 0.0, burst(rng, 0.05, 900.0, 7000.0, 0.012), 0.9)
    t = 0.02
    for k in range(6):
        put(out, t, burst(rng, 0.03, 1500.0, 8000.0, 0.008), rng.uniform(0.3, 0.7) * (1.0 - k / 9.0))
        t += rng.uniform(0.015, 0.05)
    t = 0.18
    for k in range(10):
        put(out, t, wood(rng, rng.uniform(250.0, 900.0), 0.18, rng.uniform(0.25, 0.75) * (1.0 - k / 14.0)))
        t += rng.uniform(0.04, 0.12)
    put(out, 0.25, grains(rng, 1.0, 90, lambda: burst(rng, 0.004, 1500.0, 7000.0, 0.001) * rng.uniform(0.03, 0.15),
                          lambda r: r.beta(1.2, 3.0)), 0.6)
    return space(out, rng, 0.9, 0.22)


def fu_scrape(rng):
    """A bronze lion rakes the stone floor twice before it charges: claws of
    metal grinding, a ring of the hollow body, sparks crackling."""
    out = np.zeros(n_(0.85))
    for at in (0.0, 0.38):
        m = n_(0.28)
        t = np.arange(m) / SR
        drag = grind(rng, 0.28, 300.0, 4200.0, 26.0, 0.6) * dsp.env_ar(m, 0.02, 0.12)
        put(out, at, drag, 0.8)
        put(out, at, metal(rng, rng.uniform(380.0, 430.0), [1.0, 1.71, 2.47], [1.0, 0.5, 0.3], [0.35, 0.25, 0.15], 0.5), 0.12)
        put(out, at + 0.02, grains(rng, 0.25, 18, lambda: clink(rng, level=rng.uniform(0.05, 0.18))), 0.7)
        put(out, at, thump(90.0, 60.0, 0.15, 0.04), 0.5)
    return space(out, rng, 0.8, 0.2)


def hoplite_shield(rng):
    """A bronze hoplon takes a blow: a round plate booms and rings."""
    out = np.zeros(n_(0.9))
    put(out, 0.0, metal(rng, 290.0, [1.0, 1.59, 2.14, 2.3, 2.65, 2.92, 3.5], [1.0, 0.8, 0.6, 0.5, 0.4, 0.3, 0.2],
                        [0.45, 0.35, 0.25, 0.22, 0.18, 0.15, 0.1], 0.9), 0.8)
    put(out, 0.0, thump(160.0, 90.0, 0.2, 0.04), 0.8)
    put(out, 0.0, burst(rng, 0.02, 1500.0, 9000.0, 0.004), 0.6)
    return space(out, rng, 0.9, 0.2)


def hoplite_thrust(rng):
    """The spear thrust: a short, hard whoosh and the bronze tip's glint."""
    out = np.zeros(n_(0.55))
    put(out, 0.0, whoosh(rng, 0.3, 500.0, 6000.0, 0.6, 1.5), 1.0)
    put(out, 0.18, metal(rng, 3600.0, [1.0, 1.41, 2.2], [1.0, 0.5, 0.3], [0.12, 0.08, 0.05], 0.3), 0.15)
    return space(out, rng, 0.6, 0.15)


# --- guardians ----------------------------------------------------------------------

def colossus_grind(rng):
    """The seated colossus turns on its throne: granite grinding on granite,
    grit pouring off its shoulders."""
    out = np.zeros(n_(2.8))
    g = grind(rng, 2.4, 35.0, 600.0, 7.0, 0.8) * dsp.env_ar(n_(2.4), 0.4, 0.6)
    put(out, 0.0, dsp.fft_filter(g, lambda f: 0.5 + g_peak(60.0, 3.0)(f) + 0.5 * g_peak(130.0, 4.0)(f)), 1.0)
    put(out, 0.0, dsp.lowpass(rng.standard_normal(n_(2.4)), 90.0) * dsp.env_ar(n_(2.4), 0.5, 0.6), 1.0)
    put(out, 0.3, grains(rng, 2.3, 60, lambda: rock(rng, rng.uniform(200.0, 500.0), rng.uniform(0.05, 0.3))), 0.6)
    return space(out, rng, 2.2, 0.35)


def colossus_slam(rng):
    """A stone hand slams the floor: a deep blow, a crack, debris."""
    out = np.zeros(n_(2.2))
    put(out, 0.0, thump(70.0, 28.0, 1.4, 0.35), 1.4)
    put(out, 0.0, burst(rng, 0.12, 300.0, 6000.0, 0.03), 1.0)
    put(out, 0.0, dsp.lowpass(rng.standard_normal(n_(1.8)), 200.0) * dsp.env_exp(n_(1.8), 0.4, 0.005), 1.2)
    for k in range(14):
        put(out, 0.05 + 1.2 * rng.beta(1.2, 3.0), rock(rng, level=rng.uniform(0.2, 0.7)))
    return space(np.tanh(1.2 * out), rng, 2.0, 0.35)


def colossus_charge(rng):
    """The sun gathers in the colossus' eyes: a rising, beating chord of
    light (1.4 s - the attack's warning)."""
    m = n_(1.4)
    t = np.arange(m) / SR
    rise = (t / t[-1]) ** 1.5
    out = np.zeros(m)
    for ratio, a in [(1.0, 1.0), (1.5, 0.6), (2.0, 0.5), (3.0, 0.25), (4.02, 0.15)]:
        f = (180.0 + 520.0 * rise) * ratio
        out += a * np.sin(TAU * np.cumsum(f) / SR + rng.uniform(0, TAU))
    out *= rise * (0.8 + 0.2 * np.sin(TAU * (6.0 + 14.0 * rise) * t))
    shimmer = dsp.bandpass(rng.standard_normal(m), 3000.0, 10000.0) * rise ** 2 * 0.3
    return space(out * 0.4 + shimmer, rng, 1.6, 0.3)


def colossus_beam(rng):
    """The sun beam fires: a searing, sizzling roar of light with a hum
    under it."""
    m = n_(1.9)
    t = np.arange(m) / SR
    env = dsp.env_ar(m, 0.03, 0.6)
    sizzle = dsp.bandpass(rng.standard_normal(m), 1500.0, 9000.0) * (0.6 + 0.4 * dsp.wander(m, rng, 30.0))
    roar = dsp.bandpass(rng.standard_normal(m), 150.0, 1500.0)
    hum = sum(a * np.sin(TAU * f * t) for f, a in [(700.0, 1.0), (703.0, 0.8), (1400.0, 0.4), (2100.0, 0.2)])
    return space((sizzle * 0.5 + roar * 0.5 + hum * 0.25) * env, rng, 1.4, 0.3)


def lamassu_gust(rng):
    """The winged bull beats its wings: a great low gust with feathers in it."""
    out = np.zeros(n_(1.3))
    put(out, 0.0, whoosh(rng, 1.0, 80.0, 1400.0, 0.4), 1.0)
    m = n_(0.8)
    feathers = dsp.bandpass(rng.standard_normal(m), 1200.0, 6000.0) * (0.5 + 0.5 * np.abs(np.sin(TAU * 30.0 * np.arange(m) / SR))) \
        * dsp.env_ar(m, 0.2, 0.4)
    put(out, 0.15, feathers, 0.25)
    put(out, 0.0, thump(60.0, 35.0, 0.6, 0.2), 0.5)
    return space(out, rng, 1.6, 0.3)


def lamassu_stomp(rng):
    """A stone hoof stamps: the strike, a crack and the shockwave rolling out."""
    out = np.zeros(n_(2.0))
    put(out, 0.0, rock(rng, 100.0), 1.0)
    put(out, 0.0, burst(rng, 0.05, 800.0, 8000.0, 0.01), 0.8)
    m = n_(1.6)
    t = np.arange(m) / SR
    wave = np.sin(TAU * np.cumsum(55.0 * np.exp(-t / 0.5) + 25.0) / SR) * dsp.env_exp(m, 0.45, 0.01)
    put(out, 0.02, wave, 1.2)
    put(out, 0.05, dsp.lowpass(rng.standard_normal(m), 250.0) * dsp.env_exp(m, 0.5, 0.05), 0.8)
    return space(np.tanh(1.3 * out), rng, 1.8, 0.35)


def lamassu_charge(rng):
    """It paws the stone, then bellows and charges."""
    out = np.zeros(n_(1.8))
    for k in range(3):
        m = n_(0.18)
        scrape = dsp.bandpass(rng.standard_normal(m), 300.0, 4000.0) * dsp.env_ar(m, 0.03, 0.1)
        put(out, k * 0.3, scrape + rock(rng, 140.0)[:m] * 0.5, 0.7)
    m = n_(0.9)
    t = np.arange(m) / SR
    f0 = 70.0 * (1.0 + 0.4 * np.sin(np.pi * t / t[-1]))
    put(out, 0.85, np.tanh(2.0 * voice(rng, f0, 0.9, VOWEL_OH, rasp=0.6, attack=0.08, release=0.4)), 1.0)
    return space(out, rng, 1.6, 0.3)


def centaur_gallop(rng):
    """A loop (1.2 s, two strides) of marble hooves galloping on stone."""
    seconds = 1.2
    m = n_(seconds)
    tl = dsp.Timeline(samples=m)
    for stride in range(2):
        for k, at in enumerate([0.0, 0.09, 0.2, 0.28]):
            hoof = mx(thump(rng.uniform(190.0, 240.0), 120.0, 0.12, 0.025), burst(rng, 0.03, 1200.0, 7000.0, 0.005) * 1.6)
            tl.add(n_(stride * 0.6 + at) + int(rng.normal(0, 0.003) * SR), hoof, 1.0 if k in (0, 2) else 0.8)
    out = dsp.mono(tl.buf)
    ir = dsp.mono(dsp.make_ir(0.8, rng, 0.01, 0.6, 0.45))
    wet = np.real(np.fft.ifft(np.fft.fft(out) * np.fft.fft(dsp.pad_to(ir, m))))   # circular: the loop rings into itself
    return out + wet * 0.12


def centaur_javelin(rng):
    """A javelin thrown with all its weight: a rising rush and a whistle."""
    out = np.zeros(n_(0.9))
    put(out, 0.0, whoosh(rng, 0.7, 250.0, 5000.0, 0.35), 1.0)
    m = n_(0.6)
    t = np.arange(m) / SR
    whistle = np.sin(TAU * np.cumsum(1800.0 - 700.0 * t / t[-1]) / SR) * dsp.env_ar(m, 0.1, 0.35)
    put(out, 0.1, whistle, 0.12)
    return space(out, rng, 1.0, 0.2)


def orrery_gears(rng):
    """A loop (2 s) of the great orrery's brass works: ratchets, gear teeth
    and a low drive hum."""
    seconds = 2.0
    m = n_(seconds)
    t = np.arange(m) / SR
    tl = dsp.Timeline(samples=m)
    for rate, f, level in [(12.0, 2400.0, 0.6), (7.5, 1500.0, 0.8), (3.0, 900.0, 1.0)]:
        for k in range(int(round(seconds * rate))):
            tick = metal(rng, f * rng.uniform(0.97, 1.03), [1.0, 1.6, 2.4], [1.0, 0.5, 0.3], [0.025, 0.015, 0.01], 0.08)
            tl.add(n_(k / rate), tick, level * rng.uniform(0.8, 1.0))
    hum = sum(a * np.sin(TAU * round(f * seconds) / seconds * t) for f, a in [(55.0, 1.0), (110.0, 0.5), (165.0, 0.3)])
    grind_ = dsp.noise(m, rng, g_band(200.0, 1500.0, 1)) * 0.1 * (0.6 + 0.4 * np.sin(TAU * 0.5 * t) ** 2)
    return dsp.mono(tl.buf) + hum * 0.08 + grind_


def orrery_sweep(rng):
    """A brass arm sweeps the rotunda: a huge whoosh with a doppler hum."""
    m = n_(1.3)
    t = np.arange(m) / SR
    out = whoosh(rng, 1.3, 90.0, 2200.0, 0.5)
    f = 150.0 * (1.0 + 0.12 * np.tanh((0.65 - t) * 6.0))
    hum = (np.sin(TAU * np.cumsum(f) / SR) + 0.4 * np.sin(TAU * np.cumsum(2.0 * f) / SR)) * np.exp(-0.5 * ((t - 0.65) / 0.25) ** 2)
    return space(out + hum * 0.25, rng, 1.6, 0.3)


def samurai_glint(rng):
    """Light runs down the blade: a high steel 'shing' (0.6 s, the warning)."""
    m = n_(0.6)
    t = np.arange(m) / SR
    ring = metal(rng, 3100.0, [1.0, 1.33, 1.87, 2.6], [1.0, 0.7, 0.5, 0.3], [0.3, 0.25, 0.2, 0.12], 0.6)
    ring *= np.minimum(t / 0.08, 1.0)
    scrape = dsp.bandpass(rng.standard_normal(m), 4000.0, 12000.0) * dsp.env_ar(m, 0.06, 0.2) * 0.4
    return space(ring * 0.5 + scrape, rng, 0.8, 0.2)


def samurai_slash(rng):
    """The cut: a fast, thin whoosh and a ringing edge."""
    out = np.zeros(n_(0.6))
    put(out, 0.0, whoosh(rng, 0.25, 900.0, 9000.0, 0.55, 1.5), 1.0)
    put(out, 0.12, metal(rng, 2900.0, [1.0, 1.41, 2.3], [1.0, 0.5, 0.25], [0.18, 0.1, 0.06], 0.4), 0.25)
    return space(out, rng, 0.6, 0.15)


def samurai_volley(rng):
    """A volley from the teahouse roof: bows twang, arrows hiss past."""
    out = np.zeros(n_(1.6))
    for k in range(5):
        put(out, k * 0.03, ins.pluck(rng.uniform(52.0, 58.0), 0.6, rng, t60=0.3, bright=0.7), 0.3)
    for k in range(9):
        m = n_(0.35)
        t = np.arange(m) / SR
        f = rng.uniform(2200.0, 3200.0) * (1.0 - 0.25 * t / t[-1])
        whizz = (dsp.bandpass(rng.standard_normal(m), 1500.0, 7000.0) * 0.6 + np.sin(TAU * np.cumsum(f) / SR) * 0.1) \
            * np.exp(-0.5 * ((t - 0.17) / 0.07) ** 2)
        put(out, 0.25 + k * rng.uniform(0.05, 0.11), whizz, rng.uniform(0.5, 1.0))
    return space(out, rng, 1.0, 0.25)


def serpent_hiss(rng):
    """The serpent hisses from both heads."""
    m = n_(1.3)
    t = np.arange(m) / SR
    hiss = dsp.bandpass(rng.standard_normal(m), 2200.0, 9500.0) * (0.75 + 0.25 * np.sin(TAU * 9.0 * t)) * dsp.env_ar(m, 0.08, 0.5)
    breath = dsp.bandpass(rng.standard_normal(m), 300.0, 1500.0) * dsp.env_ar(m, 0.1, 0.4) * 0.3
    return space(hiss + breath, rng, 1.2, 0.25)


def serpent_rattle(rng):
    """Its mosaic scales shake: a dry clatter of turquoise tiles in bursts."""
    out = np.zeros(n_(1.3))
    for b in range(4):
        start = b * 0.28
        for k in range(int(rng.integers(18, 30))):
            at = start + 0.2 * rng.beta(1.5, 2.0)
            tile = metal(rng, rng.uniform(2200.0, 4800.0), [1.0, 2.3, 3.7], [1.0, 0.4, 0.2], [0.012, 0.008, 0.005], 0.04)
            put(out, at, mx(tile, burst(rng, 0.003, 2000.0, 9000.0, 0.0008) * 0.5), rng.uniform(0.3, 1.0))
    return space(out, rng, 0.9, 0.2)


def guardian_wake(rng):
    """Any guardian wakes: a deep groan of stone and bronze, a crack of dust,
    a low choral swell of the old spell."""
    out = np.zeros(n_(2.6))
    put(out, 0.0, thump(60.0, 30.0, 1.6, 0.5), 0.9)
    put(out, 0.0, grind(rng, 1.8, 40.0, 500.0, 6.0) * dsp.env_ar(n_(1.8), 0.6, 0.6), 0.8)
    put(out, 0.4, burst(rng, 0.05, 700.0, 7000.0, 0.012), 0.7)
    put(out, 0.3, ins.choir([50, 57, 62], 1.6, 0.8, rng, ins.VOWEL_O, attack=0.6, release=0.6).mean(axis=1), 0.9)
    return space(out, rng, 2.2, 0.35)


def guardian_crumble(rng):
    """A guardian falls apart: blocks split, shards rain, the rubble settles."""
    out = np.zeros(n_(3.4))
    for k in range(5):
        put(out, k * rng.uniform(0.15, 0.3), burst(rng, 0.06, 500.0, 7000.0, 0.015), rng.uniform(0.6, 1.0))
    put(out, 0.4, thump(75.0, 30.0, 1.3, 0.35), 1.2)
    for k in range(40):
        put(out, 0.3 + 2.4 * rng.beta(1.2, 2.5), rock(rng, level=rng.uniform(0.2, 0.9)))
    put(out, 0.5, grains(rng, 2.6, 300, lambda: burst(rng, 0.004, 1200.0, 7000.0, 0.001) * rng.uniform(0.05, 0.3),
                         lambda r: r.beta(1.3, 3.0)), 0.6)
    return space(np.tanh(1.2 * out), rng, 1.8, 0.35)


SOUNDS = {
    # locks (GateSpec kinds)
    "lock_chain_break": lock_chain_break, "lock_boards_hit": lock_boards_hit, "lock_boards_splinter": lock_boards_splinter,
    "lock_wall_crack": lock_wall_crack, "lock_wall_collapse": lock_wall_collapse, "lock_seal_insert": lock_seal_insert,
    "lock_seal_grind": lock_seal_grind, "lock_shutter_roll": lock_shutter_roll, "lock_power_on": lock_power_on,
    "lock_bolt_slide": lock_bolt_slide, "lock_rope_snap": lock_rope_snap, "lock_counterweight": lock_counterweight,
    "lock_hook_pull": lock_hook_pull,
    # the wings' creatures
    "mummy_groan": mummy_groan, "mummy_lash": mummy_lash, "hit_linen": hit_linen, "break_linen": break_linen,
    "scarab_swarm": scarab_swarm, "relief_crack": relief_crack,
    "relief_scrape": relief_scrape, "book_flap": book_flap, "book_flock": book_flock, "fu_roar": fu_roar,
    "totem_spit": totem_spit, "jaguar_snarl": jaguar_snarl, "hoplite_shield": hoplite_shield, "hoplite_thrust": hoplite_thrust,
    "hit_wood": hit_wood, "break_wood": break_wood, "fu_scrape": fu_scrape,
    # the guardians
    "colossus_grind": colossus_grind, "colossus_slam": colossus_slam, "colossus_charge": colossus_charge,
    "colossus_beam": colossus_beam, "lamassu_gust": lamassu_gust, "lamassu_stomp": lamassu_stomp,
    "lamassu_charge": lamassu_charge, "centaur_gallop": centaur_gallop, "centaur_javelin": centaur_javelin,
    "orrery_gears": orrery_gears, "orrery_sweep": orrery_sweep, "samurai_glint": samurai_glint,
    "samurai_slash": samurai_slash, "samurai_volley": samurai_volley, "serpent_hiss": serpent_hiss,
    "serpent_rattle": serpent_rattle, "guardian_wake": guardian_wake, "guardian_crumble": guardian_crumble,
}
LOOPS = {"scarab_swarm", "book_flock", "centaur_gallop", "orrery_gears"}
# dB under the peak (unlisted: 0); loops and small cues sit lower
LEVELS = {"hit_linen": -3.0, "scarab_swarm": -8.0, "book_flock": -6.0, "orrery_gears": -8.0, "centaur_gallop": -4.0, "lock_bolt_slide": -4.0,
          "lock_boards_hit": -2.0, "lock_wall_crack": -3.0, "lock_power_on": -2.0, "lock_hook_pull": -3.0, "book_flap": -4.0,
          "relief_scrape": -3.0, "hoplite_thrust": -3.0, "samurai_glint": -4.0, "samurai_slash": -2.0, "serpent_hiss": -3.0,
          "colossus_charge": -2.0, "lock_counterweight": -3.0, "totem_spit": -2.0}
LEVELS.update({"hit_wood": -3.0, "fu_scrape": -2.0})


def render(name):
    """The sound [param name] as a list of floats (gen_sfx.write's input)."""
    x = SOUNDS[name](rng_for(name))
    x = np.asarray(x, dtype=float)
    x = x - (x.mean() if name in LOOPS else 0.0)
    if not np.all(np.isfinite(x)):
        raise ValueError(f"{name}: not finite")
    if name not in LOOPS:
        x = trim(x)
        x = dsp.fade_edges(x, 0.0005, 0.05)
    return x.tolist()


def trim(x, floor_db=-54.0, tail=0.08):
    """Cuts the reverb tail where it has sunk [param floor_db] under the
    peak (smoothed over 10 ms), keeping [param tail] s for the fade."""
    env = dsp.box_smooth(np.abs(x), n_(0.005), circular=False)
    above = np.nonzero(env > dsp.peak(x) * 10.0 ** (floor_db / 20.0))[0]
    end = min(x.shape[0], (above[-1] if above.size else x.shape[0]) + n_(tail))
    return x[:end]


def mark_loop(wav_path):
    """The .import of a looping WAV: loop_mode forward over the whole file
    (an existing .import keeps its uid; Godot reimports on --import)."""
    import re
    path = Path(str(wav_path) + ".import")
    wanted = {"edit/loop_mode": "2", "edit/loop_begin": "0", "edit/loop_end": "-1"}
    if not path.exists():
        body = '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n\n'
        body += "force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\n"
        body += "edit/normalize=false\n" + "".join(f"{k}={v}\n" for k, v in wanted.items()) + "compress/mode=2\n"
        path.write_text(body, encoding="utf-8", newline="\n")
        return
    text = path.read_text(encoding="utf-8")
    for key, value in wanted.items():
        text = re.sub(rf"^{re.escape(key)}=.*$", f"{key}={value}", text, flags=re.MULTILINE)
    path.write_text(text, encoding="utf-8", newline="\n")
