"""Instrument voices for the Nocna Zmiana score (numpy, see dsp.py).

Every voice returns a mono (n,) or stereo (n, 2) array that already holds
its natural tail, starting at the note onset. Voices take an rng so each
note differs a little (humanised), but a seeded rng keeps renders
repeatable. Physical models are simple modal / additive ones:
- music box: cantilevered steel tines (modes 1 : 6.27 : 17.55),
- celesta: FM bell with a soft hammer,
- piano: inharmonic strings, double decay, hammer thump,
- bells: church-bell partials (hum, prime, tierce, quint, nominal),
- timpani / drums: air-loaded membrane modes with a pitch glide,
- harp, pizzicato: Karplus-Strong strings (loss filter solved per note),
- strings, brass, organ, choir: detuned band-limited oscillators shaped
  by filters (formants for the choir, filter envelopes for the brass).
"""
import numpy as np

from dsp import (SR, TAU, cents, env_adsr, env_ar, env_exp, fade_edges, fft_filter, g_band, g_bell,
                 g_highpass, g_lowpass, g_mul, g_peak, g_shelf_hi, highpass, hz, lowpass, lowpass_sweep,
                 n_of, osc, pad_to, pan, partials, ramp, saturate, bandpass)


def _burst(rng, seconds, lo, hi, tau):
    n = n_of(seconds)
    return bandpass(rng.standard_normal(n), lo, hi) * env_exp(n, tau, 0.0005)


def crush(x, hold=4, bits=6):
    """Sample-and-hold decimation plus quantisation: the retro wink."""
    y = np.repeat(x[::hold], hold)[:x.shape[0]]
    q = 2.0 ** (bits - 1)
    return np.round(y * q) / q


# --- tuned percussion / keyboards ------------------------------------------

def music_box(midi, vel=0.8, rng=None, ring=None):
    f = float(hz(midi))
    tau = 1.5 * (440.0 / f) ** 0.45
    length = ring if ring is not None else min(max(tau * 4.0, 0.6), 5.0)
    n = n_of(length)
    tone = partials(f, [1.0, 6.267, 17.55, 34.39], [1.0, 0.55 * vel, 0.22 * vel, 0.08 * vel],
                    [tau, tau * 0.3, tau * 0.09, tau * 0.04], n, rng=rng)
    # a tine is never perfectly even: a faint neighbour mode beats slowly
    tone += 0.1 * partials(f * float(cents(rng.uniform(1.0, 2.5))), [1.0], [1.0], [tau * 0.7], n, rng=rng)
    pluck = pad_to(_burst(rng, 0.006, 2500.0, 9000.0, 0.0012), n) * 0.35
    out = (tone + pluck) * vel
    return fade_edges(out, 0.0005, 0.05)


def celesta(midi, vel=0.8, rng=None):
    f = float(hz(midi))
    tau = 1.3 * (440.0 / f) ** 0.4
    n = n_of(min(tau * 4.0 + 0.2, 5.0))
    t = np.arange(n) / SR
    index = 1.6 * vel * np.exp(-t / 0.04) + 0.3 * np.exp(-t / 0.5)
    carrier = np.sin(TAU * f * t + index * np.sin(TAU * 4.0 * f * t))
    body = carrier * np.exp(-t / tau) + 0.2 * np.sin(TAU * 2.0 * f * t) * np.exp(-t / (tau * 0.35))
    thump = pad_to(_burst(rng, 0.02, 200.0, 1500.0, 0.004), n) * 0.12
    return fade_edges((body + thump) * vel, 0.001, 0.05)


def piano(midi, vel=0.7, hold=1.5, rng=None, bright=1.0):
    """Felt-ish piano: inharmonic partials with double decay, pairs of
    slightly detuned strings, hammer thump, damper at the end of hold."""
    f = float(hz(midi))
    release = 0.35
    n = n_of(hold + release)
    t = np.arange(n) / SR
    count = int(min(28, (SR * 0.45) // f))
    b = 0.00018 * (f / 261.6) ** 0.8
    tau0 = 3.8 * (261.6 / f) ** 0.55
    out = np.zeros(n)
    for k in range(1, count + 1):
        fk = k * f * np.sqrt(1.0 + b * k * k)
        amp = (1.0 / k ** 1.15) * np.exp(-(k - 1) * (0.32 - 0.2 * vel * bright))
        tau = tau0 / (1.0 + 0.3 * (k - 1))
        env = 0.65 * np.exp(-t / (tau * 0.22)) + 0.35 * np.exp(-t / tau)
        beat = float(cents(rng.uniform(0.3, 1.2)))
        ph = rng.uniform(0, 1)
        out += amp * env * (np.sin(TAU * (fk * t + ph)) + 0.8 * np.sin(TAU * (fk * beat * t + ph + 0.1)))
    thump = pad_to(lowpass(rng.standard_normal(n_of(0.05)), 900.0) * env_exp(n_of(0.05), 0.008), n)
    out = out * 0.5 + thump * 0.06 * vel
    damp = np.ones(n)
    gate = n_of(hold)
    damp[gate:] = np.exp(-(t[gate:] - hold) / 0.07)
    out *= damp
    out = fft_filter(out, g_mul(g_lowpass(900.0 + 5000.0 * vel * bright, 1), g_highpass(35.0, 2)))
    return fade_edges(out * vel, 0.001, 0.02)


def church_bell(midi, vel=0.8, rng=None, length=7.0):
    """Hum, prime, tierce, quint, nominal and upper partials."""
    f = float(hz(midi))
    n = n_of(length)
    ratios = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166]
    amps = [0.55, 0.8, 0.5, 0.25, 0.65, 0.3, 0.2, 0.25, 0.12]
    decays = [5.5, 3.2, 2.6, 2.0, 1.8, 1.1, 0.9, 0.7, 0.45]
    tone = partials(f, ratios, amps, decays, n, rng=rng, detune_cents=2.0)
    strike = pad_to(_burst(rng, 0.03, 800.0, 6000.0, 0.006), n) * 0.3
    return fade_edges((tone + strike) * vel, 0.001, 0.2)


def glass(midi, hold, vel=0.5, rng=None, attack=0.8, release=1.5):
    """Glass-harmonica-like sine with a slow beat and soft tremolo."""
    f = float(hz(midi))
    n = n_of(hold + release)
    t = np.arange(n) / SR
    beat = rng.uniform(0.2, 0.5)
    tone = np.sin(TAU * f * t) + 0.7 * np.sin(TAU * (f + beat) * t + 1.0) + 0.08 * np.sin(TAU * 2 * f * t) + 0.03 * np.sin(TAU * 3 * f * t)
    trem = 1.0 + 0.12 * np.sin(TAU * rng.uniform(3.5, 4.5) * t)
    env = env_adsr(n, attack, 1.0, 1.0, release, gate=hold)
    return tone * trem * env * vel * 0.5


def xylophone(midi, vel=0.8, rng=None):
    """Hard-mallet bar with a dry 'bone' knock (the T-Rex's ribs)."""
    f = float(hz(midi))
    tau = 0.3 * (523.0 / f) ** 0.5
    n = n_of(tau * 5.0 + 0.05)
    bar = partials(f, [1.0, 3.0, 6.1], [1.0, 0.38 * vel, 0.14 * vel], [tau, tau * 0.25, tau * 0.1], n, rng=rng)
    click = pad_to(_burst(rng, 0.006, 2000.0, 8000.0, 0.001), n) * 0.35
    knock = pad_to(_burst(rng, 0.03, 700.0, 1800.0, 0.006), n) * 0.3
    return fade_edges((bar + click + knock) * vel, 0.0005, 0.03)


# --- drums -----------------------------------------------------------------

def timpani(midi, vel=0.8, rng=None, length=2.8):
    f = float(hz(midi))
    n = n_of(length)
    t = np.arange(n) / SR
    glide = 1.0 + 0.018 * np.exp(-t / 0.1)
    ph = np.cumsum(f * glide) / SR
    modes = [(1.0, 1.0, 1.9), (1.504, 0.5, 1.2), (1.742, 0.22, 0.5), (2.0, 0.34, 0.95), (2.245, 0.2, 0.6),
             (2.494, 0.14, 0.45), (2.8, 0.1, 0.3), (3.1, 0.06, 0.2)]
    body = np.zeros(n)
    for r, a, d in modes:
        body += a * (vel ** (0.5 + (r - 1.0))) * np.exp(-t / d) * np.sin(TAU * r * ph + rng.uniform(0, TAU))
    thud = np.sin(TAU * 0.62 * ph) * np.exp(-t / 0.09) * 0.35
    mallet = pad_to(lowpass(rng.standard_normal(n_of(0.04)), 1200.0 + 1500.0 * vel) * env_exp(n_of(0.04), 0.01), n)
    out = body + thud + mallet * 0.5
    return fade_edges(out * vel, 0.0007, 0.1)


def big_drum(f0=55.0, vel=0.9, rng=None, length=1.6):
    """Taiko-like ensemble drum: deep glide, skin slap."""
    n = n_of(length)
    t = np.arange(n) / SR
    pitch = f0 * (1.0 + 0.7 * np.exp(-t / 0.045))
    ph = np.cumsum(pitch) / SR
    body = np.sin(TAU * ph) * np.exp(-t / 0.42) + 0.35 * np.sin(TAU * 1.58 * ph) * np.exp(-t / 0.12)
    slap = pad_to(_burst(rng, 0.06, 250.0, 3500.0, 0.012), n)
    out = saturate(body * 1.2 + slap * 0.45 * vel, 1.4)
    return fade_edges(out * vel, 0.0005, 0.1)


def tom(f0=130.0, vel=0.8, rng=None):
    n = n_of(0.6)
    t = np.arange(n) / SR
    pitch = f0 * (1.0 + 0.45 * np.exp(-t / 0.035))
    ph = np.cumsum(pitch) / SR
    body = np.sin(TAU * ph) * np.exp(-t / 0.2) + 0.25 * np.sin(TAU * 1.5 * ph) * np.exp(-t / 0.08)
    skin = pad_to(_burst(rng, 0.04, 400.0, 5000.0, 0.008), n) * 0.4
    return fade_edges(saturate(body + skin, 1.3) * vel, 0.0005, 0.05)


def kick(vel=0.9, rng=None):
    n = n_of(0.5)
    t = np.arange(n) / SR
    pitch = 46.0 + 120.0 * np.exp(-t / 0.028)
    ph = np.cumsum(pitch) / SR
    body = np.sin(TAU * ph) * np.exp(-t / 0.26)
    click = pad_to(_burst(rng, 0.006, 1500.0, 9000.0, 0.0012), n) * 0.5
    return fade_edges(saturate(body * 1.3 + click, 1.8) * vel, 0.0003, 0.05)


def snare(vel=0.85, rng=None):
    n = n_of(0.45)
    t = np.arange(n) / SR
    tone = (np.sin(TAU * 188.0 * t) + 0.6 * np.sin(TAU * 332.0 * t + 1.0)) * np.exp(-t / 0.055)
    wires = bandpass(rng.standard_normal(n), 1800.0, 9500.0) * np.exp(-t / 0.15)
    crack = pad_to(_burst(rng, 0.005, 1000.0, 12000.0, 0.0012), n)
    return fade_edges(saturate(tone * 0.7 + wires * 0.55 + crack * 0.5, 1.5) * vel, 0.0003, 0.05)


def crash(vel=0.7, rng=None, length=3.5):
    n = n_of(length)
    t = np.arange(n) / SR
    hiss = bandpass(rng.standard_normal(n), 2800.0, 14000.0, 1) * (0.7 * np.exp(-t / 0.35) + 0.3 * np.exp(-t / 1.3))
    ring = partials(420.0, [1.0, 1.73, 2.61, 3.37, 4.52, 5.93], [0.3, 0.25, 0.22, 0.2, 0.15, 0.12],
                    [1.2, 1.0, 0.8, 0.7, 0.5, 0.4], n, rng=rng)
    return fade_edges((hiss + highpass(ring, 800.0) * 0.15) * vel, 0.0005, 0.3)


def clock_tick(tock=False, vel=0.8, rng=None):
    """Escapement: a metallic tick (or a lower wooden tock)."""
    n = n_of(0.09)
    f = rng.uniform(1900.0, 2050.0) if tock else rng.uniform(3100.0, 3300.0)
    ring = partials(f, [1.0, 1.47, 2.31], [1.0, 0.5, 0.25], [0.012, 0.008, 0.004], n, rng=rng)
    wood = pad_to(_burst(rng, 0.03, 500.0, 1600.0, 0.007), n) * (0.8 if tock else 0.3)
    click = pad_to(_burst(rng, 0.003, 3000.0, 12000.0, 0.0006), n) * 0.6
    return fade_edges((ring * 0.6 + wood + click) * vel, 0.0002, 0.02)


def anvil(vel=0.8, rng=None, f0=1180.0):
    n = n_of(1.4)
    ring = partials(f0 * float(cents(rng.uniform(-15, 15))), [1.0, 1.52, 2.71, 3.93, 5.17], [1.0, 0.6, 0.45, 0.3, 0.2],
                    [0.9, 0.6, 0.4, 0.28, 0.2], n, rng=rng)
    strike = pad_to(_burst(rng, 0.01, 1500.0, 12000.0, 0.002), n)
    return fade_edges((ring * 0.5 + strike * 0.6) * vel, 0.0003, 0.1)


def heartbeat(vel=0.7, rng=None):
    n = n_of(0.55)
    t = np.arange(n) / SR
    lub = np.sin(TAU * np.cumsum(62.0 + 25.0 * np.exp(-t / 0.03)) / SR) * np.exp(-t / 0.07)
    dub_at = n_of(0.24)
    dub = np.zeros(n)
    t2 = t[:n - dub_at]
    dub[dub_at:] = np.sin(TAU * np.cumsum(55.0 + 20.0 * np.exp(-t2 / 0.03)) / SR) * np.exp(-t2 / 0.06) * 0.7
    return fade_edges(lowpass(lub + dub, 180.0) * vel, 0.001, 0.05)


# --- sustained voices -------------------------------------------------------

def strings(notes, hold, vel=0.6, rng=None, attack=0.8, release=1.4, bright=1.0, voices=3, vibrato=0.0025,
            spread=0.6):
    """Bowed string section: per note and side a few detuned saws with
    delayed vibrato, a warm low-pass and body resonances."""
    notes = np.atleast_1d(notes)
    n = n_of(hold + release)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    fc_max = 0.0
    for m in notes:
        f = float(hz(m))
        fc_max = max(fc_max, f)
        for side in range(2):
            for v in range(voices):
                vib_rate = rng.uniform(4.6, 5.8)
                vib = 1.0 + vibrato * np.sin(TAU * vib_rate * t + rng.uniform(0, TAU)) * np.minimum(t / 0.7, 1.0)
                freq = f * float(cents(rng.uniform(-9.0, 9.0))) * vib
                out[:, side] += osc(freq, n, "saw", rng.uniform(0, 1)) / voices
    cutoff = min(900.0 + 2.2 * fc_max, 5200.0) * bright
    out = fft_filter(out, g_mul(g_lowpass(cutoff, 2), g_highpass(max(float(hz(min(notes))) * 0.6, 28.0), 2),
                                g_bell(420.0, 2.5, 0.8), g_bell(1250.0, 2.0, 0.6), g_bell(3000.0, 1.5, 0.6)))
    bow = bandpass(rng.standard_normal(n), 2000.0, 7000.0, 1) * 0.015 * bright
    out += bow[:, None]
    env = env_adsr(n, attack, 0.6, 0.85, release, gate=hold)
    out *= env[:, None]
    mid = out.mean(axis=1, keepdims=True)
    out = mid + (out - mid) * spread * 2.0
    return out * vel / max(len(notes), 1) ** 0.5


def staccato(midi, length=0.2, vel=0.8, rng=None, bright=1.0):
    """Short bowed stroke (spiccato) for ostinati."""
    f = float(hz(midi))
    n = n_of(length + 0.12)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(3):
        out += osc(f * float(cents(rng.uniform(-8, 8))), n, "saw", rng.uniform(0, 1)) / 3.0
    out += 0.5 * osc(f * 0.5, n, "sine")
    cutoff = (500.0 + 6.0 * f) * bright * (0.55 + 0.45 * np.exp(-t / 0.06))
    out = lowpass_sweep(out, cutoff, 2, bands=10)
    bite = pad_to(_burst(rng, 0.02, 1500.0, 6000.0, 0.004), n) * 0.15 * bright
    env = env_adsr(n, 0.008, 0.08, 0.55, 0.1, gate=length)
    return (out + bite) * env * vel


def synth_bass(midi, length=0.1, vel=0.9, rng=None, drive=3.0):
    """Driven low ostinato voice (saw + sub, snappy filter)."""
    f = float(hz(midi))
    n = n_of(length + 0.08)
    t = np.arange(n) / SR
    raw = 0.7 * osc(f * float(cents(-5)), n, "saw", rng.uniform()) + 0.7 * osc(f * float(cents(5)), n, "saw", rng.uniform())
    raw += 0.6 * osc(f, n, "sine")
    cutoff = 180.0 + 1800.0 * vel * np.exp(-t / 0.05) + 3.0 * f
    body = lowpass_sweep(raw, cutoff, 2, bands=10)
    env = env_adsr(n, 0.004, 0.09, 0.6, 0.06, gate=length)
    return saturate(body * env * 1.2, drive) * vel


def brass(notes, hold, vel=0.8, rng=None, bright=1.0, attack=0.015, release=0.18, drive=1.8):
    """Brass section stab or swell: scooped pitch, filter envelope, grit."""
    notes = np.atleast_1d(notes)
    n = n_of(hold + release)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    lowest = float(hz(min(notes)))
    for m in notes:
        f = float(hz(m))
        scoop = 1.0 - 0.025 * np.exp(-t / 0.035)
        for side in range(2):
            for v in range(2):
                vib = 1.0 + 0.002 * np.sin(TAU * rng.uniform(4.5, 5.5) * t) * np.minimum(t / 0.4, 1.0)
                out[:, side] += osc(f * float(cents(rng.uniform(-7, 7))) * scoop * vib, n, "saw", rng.uniform()) * 0.5
    cutoff = lowest * (1.5 + 7.0 * bright * vel * np.exp(-t / 0.13)) + 350.0 + 1500.0 * bright * vel
    for side in range(2):
        out[:, side] = lowpass_sweep(out[:, side], cutoff, 2, bands=12)
    env = env_adsr(n, attack, 0.25, 0.72, release, gate=hold)
    out = saturate(out * env[:, None] / len(notes) ** 0.5, drive)
    out = fft_filter(out, g_mul(g_highpass(lowest * 0.7, 2), g_bell(900.0, 2.0, 0.8)))
    return out * vel


def organ(notes, hold, vel=0.7, rng=None, ranks=None, release=0.35, chiff=1.0):
    """Pipe organ: several ranks (16', 8', 4', 2 2/3', 2', mixture), each
    pipe slightly off, ranks spread over the chests (stereo), wind chiff."""
    notes = np.atleast_1d(notes)
    ranks = ranks or [(0.5, 0.45), (1.0, 1.0), (2.0, 0.55), (3.0, 0.22), (4.0, 0.28), (6.0, 0.1), (8.0, 0.08)]
    n = n_of(hold + release)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    flutter = 1.0 + 0.004 * np.sin(TAU * rng.uniform(5.0, 6.5) * t)
    for m in notes:
        f = float(hz(m))
        for i, (mult, amp) in enumerate(ranks):
            fr = f * mult * float(cents(rng.uniform(-1.5, 1.5)))
            if fr > SR * 0.45:
                continue
            tone = np.sin(TAU * (fr * t + rng.uniform(0, 1))) + 0.15 * np.sin(TAU * (2 * fr * t))
            side = (i % 2) * 2 - 1
            out[:, 0] += tone * amp * (0.6 - 0.25 * side)
            out[:, 1] += tone * amp * (0.6 + 0.25 * side)
        if chiff:
            puff = bandpass(rng.standard_normal(n_of(0.09)), f * 1.5, f * 6.0 + 1500.0, 1) * env_exp(n_of(0.09), 0.025)
            out[:n_of(0.09)] += (puff * 0.25 * chiff)[:, None]
    env = env_adsr(n, 0.06, 0.2, 1.0, release, gate=hold)
    out *= (env * flutter)[:, None]
    return out * vel / (len(notes) ** 0.5 * 2.2)


VOWEL_A = [(730.0, 1.0, 8.0), (1090.0, 0.55, 10.0), (2440.0, 0.3, 14.0), (3400.0, 0.15, 16.0)]
VOWEL_O = [(500.0, 1.0, 8.0), (840.0, 0.6, 9.0), (2400.0, 0.12, 14.0), (3300.0, 0.08, 16.0)]


def choir(notes, hold, vel=0.6, rng=None, vowel=None, attack=0.6, release=1.2, singers=4):
    """Ensemble 'aah': detuned saws with vibrato through formant peaks."""
    notes = np.atleast_1d(notes)
    vowel = vowel or VOWEL_A
    n = n_of(hold + release)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for m in notes:
        f = float(hz(m))
        for side in range(2):
            for s in range(singers):
                vib = 1.0 + 0.0045 * np.sin(TAU * rng.uniform(4.8, 6.0) * t + rng.uniform(0, TAU))
                wobble = 1.0 + 0.002 * np.sin(TAU * rng.uniform(0.2, 0.5) * t + rng.uniform(0, TAU))
                out[:, side] += osc(f * float(cents(rng.uniform(-11, 11))) * vib * wobble, n, "saw", rng.uniform()) / singers
    breath = bandpass(rng.standard_normal((n, 2)), 1500.0, 6000.0, 1) * 0.03
    out = out + breath

    def formants(fr):
        g = np.full_like(fr, 0.04)
        for centre, amp, q in vowel:
            g = g + amp * g_peak(centre, q)(fr)
        return g * g_highpass(90.0, 2)(fr)
    out = fft_filter(out, formants)
    env = env_adsr(n, attack, 1.0, 1.0, release, gate=hold)
    return out * env[:, None] * vel / len(notes) ** 0.5


def lead(midi, hold, vel=0.8, rng=None, drive=2.2):
    """Brassy distorted lead for the combat motif."""
    f = float(hz(midi))
    n = n_of(hold + 0.15)
    t = np.arange(n) / SR
    vib = 1.0 + 0.004 * np.sin(TAU * 5.5 * t) * np.clip((t - 0.15) / 0.3, 0.0, 1.0)
    scoop = 1.0 - 0.03 * np.exp(-t / 0.03)
    raw = osc(f * vib * scoop * float(cents(-6)), n, "saw", rng.uniform()) + osc(f * vib * scoop * float(cents(6)), n, "saw", rng.uniform())
    raw += 0.5 * osc(f * 0.5 * vib, n, "square", rng.uniform())
    cutoff = f * (2.0 + 5.0 * np.exp(-t / 0.15)) + 900.0
    body = lowpass_sweep(raw, cutoff, 2, bands=12)
    env = env_adsr(n, 0.01, 0.2, 0.75, 0.12, gate=hold)
    return saturate(body * env, drive) * vel


def evil_box(midi, vel=0.8, rng=None):
    """The music box through a bit-crusher: the lullaby gone feral."""
    tone = music_box(midi, vel, rng, ring=1.2)
    return lowpass(crush(tone, 3, 5), 7000.0, 2) * 0.9


def pluck(midi, vel=0.8, rng=None, t60=1.5, bright=0.5, length=None):
    """Karplus-Strong string, vectorised one period at a time: a noise
    burst circulates in a delay line of one period through a two-tap loss
    filter ((1 - s) and s: the string's damping of highs). s and the loop
    gain are solved per note so the fundamental dies 60 dB in t60 s at any
    pitch (plain averaging, s = 0.5, would kill high notes far sooner).
    The integer delay is tuned exactly afterwards by resampling."""
    f = float(hz(midi))
    period = SR / f
    w0 = TAU * f / SR
    target = 0.001 ** (1.0 / max(t60 * f, 1e-3))   # loop gain per period at the fundamental
    averaged = abs(np.cos(w0 / 2.0))              # what s = 0.5 alone leaves
    if target < averaged:
        s, damping = 0.5, target / averaged
    else:
        c = (1.0 - target * target) / (2.0 * (1.0 - np.cos(w0)))
        s, damping = (1.0 - np.sqrt(max(1.0 - 4.0 * c, 0.0))) / 2.0, 0.99999
    size = max(int(np.floor(period - s)), 2)
    length = length if length is not None else min(t60 * 1.2 + 0.05, 6.0)
    total = n_of(length) + size * 2 + 2
    excitation = rng.uniform(-1.0, 1.0, size)
    excitation = fft_filter(excitation, g_lowpass(f * (1.5 + 14.0 * bright * vel), 1), pad=size)
    excitation -= excitation.mean()
    y = np.zeros(total + size)
    y[1:size + 1] = excitation
    start = size + 1
    while start < total:
        stop = min(start + size, total)
        span = stop - start
        y[start:stop] = damping * ((1.0 - s) * y[start - size:start - size + span] + s * y[start - size - 1:start - size - 1 + span])
        start = stop
    y = y[1:total]
    # the loss filter delays about s samples: the loop's period is size + s
    ratio = (size + s) / period
    positions = np.arange(n_of(length)) * ratio
    out = np.interp(positions, np.arange(y.shape[0]), y)
    return fade_edges(out * vel, 0.0005, 0.03)


def pizzicato(midi, vel=0.8, rng=None):
    """Plucked strings: a short Karplus-Strong string with a woody body."""
    f = float(hz(midi))
    string = pluck(midi, vel, rng, t60=0.55 * (110.0 / f) ** 0.25 + 0.25, bright=0.35)
    body = fft_filter(string, g_mul(g_bell(220.0, 4.0, 0.7), g_bell(480.0, 2.0, 0.6), g_highpass(45.0, 2), g_lowpass(3500.0, 1)))
    thump = pad_to(lowpass(rng.standard_normal(n_of(0.03)), 400.0) * env_exp(n_of(0.03), 0.006), body.shape[0])
    return body + thump * 0.08 * vel


def harp(midi, vel=0.7, rng=None):
    """Concert harp: a longer, brighter Karplus-Strong string."""
    f = float(hz(midi))
    return fft_filter(pluck(midi, vel, rng, t60=2.2 * (261.6 / f) ** 0.35, bright=0.45), g_highpass(60.0, 2))


def cello(midi, hold, vel=0.6, rng=None):
    """Solo cello line (one expressive voice, more vibrato)."""
    return strings([midi], hold, vel, rng, attack=0.35, release=0.9, bright=1.1, voices=1, vibrato=0.0045, spread=0.2)


# --- Floor I: the wings' instruments ------------------------------------------
# (appended: the voices above are untouched, so earlier renders stay byte-equal)

VOWEL_U = [(325.0, 1.0, 8.0), (700.0, 0.4, 9.0), (2530.0, 0.07, 14.0), (3500.0, 0.04, 16.0)]


def bend(x, cents_curve):
    """Pitch-bends [param x] by a cents curve (one value per output sample):
    the signal is read at a varying rate (resampling), so a string pressed
    behind its bridge or a sagging wind note keeps its timbre."""
    x = np.asarray(x, dtype=float)
    n = x.shape[0]
    rate = 2.0 ** (pad_to(np.asarray(cents_curve, dtype=float), n) / 1200.0)
    pos = np.minimum(np.cumsum(rate) - rate[0], n - 1)
    return np.interp(pos, np.arange(n), x)


# harmonic amplitudes, breath level, attack (s), vibrato depth (ratio), rate (Hz),
# vibrato delay (s), attack scoop (cents), fall at the end (cents)
_FLUTES = {
    "ney": ([1.0, 0.62, 0.38, 0.22, 0.12, 0.07, 0.04], 0.42, 0.14, 0.009, 5.2, 0.35, -70.0, 0.0),
    "shakuhachi": ([1.0, 0.45, 0.3, 0.14, 0.09, 0.05], 0.36, 0.09, 0.014, 4.4, 0.55, -45.0, -90.0),
    "clay": ([1.0, 0.1, 0.06, 0.02], 0.1, 0.05, 0.005, 5.8, 0.25, -25.0, 0.0),
    "pan": ([1.0, 0.18, 0.22, 0.05, 0.05], 0.3, 0.07, 0.004, 5.0, 0.4, -15.0, 0.0),
}


def flute(midi, hold, vel=0.7, rng=None, kind="ney", release=0.35, fall=None, grace=None):
    """End-blown and vessel flutes: a harmonic tone plus breath noise that
    gathers around the harmonics (an air jet over an edge), a scooped
    attack, delayed vibrato. kind: 'ney' (very breathy, slides in),
    'shakuhachi' (hard 'muraiki' breath attack, deep head-shake vibrato,
    a falling 'meri' at the end), 'clay' (ocarina: almost pure), 'pan'
    (panpipe: airy). [param grace]: semitones of a quick upper grace note
    at the start (an ornament), or None."""
    amps, breath, attack, vib_depth, vib_rate, vib_delay, scoop, end_fall = _FLUTES[kind]
    if fall is not None:
        end_fall = fall
    f = float(hz(midi))
    n = n_of(hold + release)
    t = np.arange(n) / SR
    cents_curve = scoop * np.exp(-t / 0.07)
    if grace:
        g = min(n_of(0.07), n)
        cents_curve[:g] += 100.0 * grace * (1.0 - ramp(g))
    if end_fall:
        tail = np.clip((t - (hold - 0.2)) / (0.2 + release), 0.0, 1.0)
        cents_curve = cents_curve + end_fall * tail ** 2
    vib = np.sin(TAU * vib_rate * t + rng.uniform(0, TAU)) * np.clip((t - vib_delay) / 0.4, 0.0, 1.0)
    freq = f * 2.0 ** (cents_curve / 1200.0) * (1.0 + vib_depth * vib)
    ph = np.cumsum(freq) / SR
    tone = np.zeros(n)
    for k, a in enumerate(amps, start=1):
        if k * f > SR * 0.45:
            break
        tone += a * np.sin(TAU * k * ph + rng.uniform(0, TAU))
    tone /= sum(amps) ** 0.5

    def jet(fr):
        g = np.full_like(fr, 0.05)
        for k in range(1, 7):
            g = g + (0.9 / k) * g_peak(k * f, 9.0)(fr)
        return g * g_mul(g_highpass(f * 0.8, 2), g_lowpass(min(9000.0, f * 9.0), 1))(fr)
    air = fft_filter(rng.standard_normal(n), jet)
    air /= max(float(np.sqrt(np.mean(air ** 2))), 1e-9)
    hiss = bandpass(rng.standard_normal(n), 2500.0, 9000.0, 1) * 0.15
    env = env_adsr(n, attack, 0.25, 0.85, release, gate=hold)
    swell = 1.0 + 0.08 * np.sin(TAU * rng.uniform(0.3, 0.6) * t)
    hard = kind == "shakuhachi"
    chiff = np.exp(-t / (0.05 if hard else 0.03)) * (1.6 if hard else 0.7) * np.minimum(t / 0.004, 1.0)
    out = tone * env * swell + (air + hiss) * breath * (env * 0.8 + chiff)
    return fade_edges(out * vel * 0.6, 0.002, 0.04)


def reed(midi, hold, vel=0.8, rng=None, dark=False, release=0.2):
    """Double reed: 'dark' is a duduk (soft, hollow), otherwise a mizmar /
    zurna (bright, nasal, piercing). A rich wave with a scoop and vibrato
    through nasal formants, a little breath."""
    f = float(hz(midi))
    n = n_of(hold + release)
    t = np.arange(n) / SR
    scoop = 1.0 - (0.018 if dark else 0.03) * np.exp(-t / 0.05)
    vib = 1.0 + (0.004 if dark else 0.006) * np.sin(TAU * rng.uniform(5.0, 6.2) * t) * np.clip((t - 0.2) / 0.3, 0.0, 1.0)
    freq = f * scoop * vib
    raw = osc(freq, n, "tri" if dark else "pulse", rng.uniform()) + 0.5 * osc(freq * float(cents(4.0)), n, "saw", rng.uniform())
    if dark:
        shape = g_mul(g_lowpass(1800.0, 2), lambda fr: 0.25 + g_peak(520.0, 3.0)(fr) + 0.5 * g_peak(1150.0, 4.0)(fr))
    else:
        shape = g_mul(g_highpass(f * 0.9, 2), lambda fr: 0.15 + 0.8 * g_peak(1250.0, 3.5)(fr) + g_peak(2700.0, 4.0)(fr)
                      + 0.4 * g_peak(4200.0, 5.0)(fr))
    body = fft_filter(raw, shape)
    breath = bandpass(rng.standard_normal(n), 1500.0, 7000.0, 1) * (0.08 if dark else 0.05)
    env = env_adsr(n, 0.09 if dark else 0.035, 0.2, 0.85, release, gate=hold)
    out = saturate(body * 1.4, 1.1 if dark else 1.6) * env + breath * env
    return fade_edges(out * vel * 0.7, 0.001, 0.03)


def lyre(midi, vel=0.7, rng=None, big=False):
    """Gut-strung lyre (big = kithara: longer strings, a deeper box): a
    dark Karplus-Strong string, a finger's pluck, the sound box."""
    f = float(hz(midi))
    t60 = (2.4 if big else 1.3) * (261.6 / f) ** 0.35
    string = pluck(midi, vel, rng, t60=t60, bright=0.38 if big else 0.3)
    box = g_mul(g_bell(210.0 if big else 280.0, 4.0, 0.8), g_bell(720.0 if big else 900.0, 3.0, 0.7),
                g_highpass(65.0, 2), g_lowpass(5200.0, 1))
    body = fft_filter(string, box)
    finger = pad_to(_burst(rng, 0.012, 600.0, 3000.0, 0.003), body.shape[0]) * 0.12 * vel
    return body + finger


def koto(midi, vel=0.7, rng=None, push=0.0, push_at=0.18):
    """Koto: silk strings plucked with ivory picks (tsume): a brighter
    Karplus-Strong string, the pick's click, the long body; [param push]
    semitones of an oshide press behind the bridge after push_at s."""
    f = float(hz(midi))
    string = pluck(midi, vel, rng, t60=2.4 * (261.6 / f) ** 0.3, bright=0.62)
    n = string.shape[0]
    if push:
        t = np.arange(n) / SR
        string = bend(string, 100.0 * push * np.clip((t - push_at) / 0.12, 0.0, 1.0))
    body = fft_filter(string, g_mul(g_bell(300.0, 3.0, 0.7), g_bell(1100.0, 2.0, 0.8), g_highpass(70.0, 2)))
    pick = pad_to(_burst(rng, 0.006, 2500.0, 9000.0, 0.0012), n) * 0.25 * vel
    return body + pick


def harpsichord(midi, vel=0.7, rng=None, hold=None, four_foot=0.45):
    """Harpsichord: an 8' string and a 4' string an octave up, plucked by
    quills (a bright Karplus-Strong string, a click), the soundboard;
    [param hold] s: the damper falls back with the jack's soft thump."""
    f = float(hz(midi))
    t60 = 3.0 * (261.6 / f) ** 0.45
    eight = pluck(midi, 1.0, rng, t60=t60, bright=0.95)
    four = pluck(midi + 12, 1.0, rng, t60=t60 * 0.7, bright=0.95) if four_foot else np.zeros(1)
    n = max(eight.shape[0], four.shape[0])
    out = pad_to(eight, n) + pad_to(four, n) * four_foot
    quill = pad_to(_burst(rng, 0.004, 1500.0, 9000.0, 0.0008), n) * 0.3
    out = fft_filter(out + quill, g_mul(g_highpass(55.0, 2), g_bell(180.0, 2.0, 0.8), g_bell(2600.0, 3.0, 1.0)))
    if hold is not None:
        stop = n_of(hold)
        if stop < n:
            t = np.arange(n - stop) / SR
            out[stop:] *= np.exp(-t / 0.035)
            thump = _burst(rng, 0.02, 200.0, 1200.0, 0.004) * 0.05
            out[stop:stop + thump.shape[0]] += thump[:n - stop]
            out = out[:min(n, stop + n_of(0.25))]
    return fade_edges(out * vel * 0.8, 0.0003, 0.02)


def marimba(midi, vel=0.7, rng=None):
    """Rosewood bar over a tuned tube: modes 1 : 3.93 : 9.2 (the bar is
    cut so its second mode sits two octaves up), the resonator holds the
    fundamental, a soft yarn mallet."""
    f = float(hz(midi))
    tau = 0.55 * (261.6 / f) ** 0.7
    n = n_of(min(tau * 5.0 + 0.1, 4.0))
    bar = partials(f, [1.0, 3.93, 9.2], [1.0, 0.32 * vel, 0.07 * vel], [tau, tau * 0.22, tau * 0.07], n, rng=rng)
    mallet = pad_to(lowpass(rng.standard_normal(n_of(0.012)), 1600.0 + 2500.0 * vel) * env_exp(n_of(0.012), 0.003), n)
    return fade_edges((bar + mallet * 0.3) * vel, 0.0005, 0.04)


def slit_drum(f0=180.0, vel=0.8, rng=None):
    """Teponaztli (slit log drum): a carved wooden tongue (inharmonic free
    bar modes) over the log's hollow; a rubber-tipped mallet."""
    n = n_of(0.9)
    t = np.arange(n) / SR
    tongue = partials(f0, [1.0, 2.76, 5.4], [1.0, 0.35, 0.12], [0.22, 0.07, 0.03], n, rng=rng)
    hollow = np.sin(TAU * f0 * 0.5 * t + rng.uniform(0, TAU)) * np.exp(-t / 0.13) * 0.5
    knock = pad_to(_burst(rng, 0.02, 300.0, 2500.0, 0.004), n) * 0.35
    out = saturate((tongue + hollow + knock) * 1.1, 1.3)
    return fade_edges(out * vel, 0.0004, 0.05)


def frame_drum(f0=80.0, vel=0.8, rng=None, stroke="doum", ring=1.0):
    """Frame drum (tar, bendir; a darbuka with a higher f0): 'doum' is the
    deep centre stroke (membrane modes, a glide), 'tek' the dry rim
    stroke, 'slap' a cupped open slap."""
    if stroke == "tek":
        n = n_of(0.25)
        ring_ = partials(f0 * 3.6, [1.0, 1.59, 2.14], [1.0, 0.5, 0.3], [0.05 * ring, 0.03, 0.02], n, rng=rng)
        click = pad_to(_burst(rng, 0.01, 1800.0, 9000.0, 0.0015), n)
        return fade_edges((ring_ * 0.6 + click) * vel, 0.0003, 0.03)
    n = n_of(1.2)
    t = np.arange(n) / SR
    doum = stroke == "doum"
    glide = 1.0 + (0.25 if doum else 0.1) * np.exp(-t / 0.03)
    ph = np.cumsum(f0 * glide) / SR
    tau = 0.38 * ring if doum else 0.12
    skin = np.zeros(n)
    for r, a, d in [(1.0, 1.0, 1.0), (1.59, 0.45, 0.5), (2.14, 0.3, 0.35), (2.3, 0.2, 0.3), (2.65, 0.15, 0.25)]:
        skin += a * np.exp(-t / (tau * d)) * np.sin(TAU * r * ph + rng.uniform(0, TAU))
    frame = partials(rng.uniform(280.0, 340.0), [1.0, 2.3], [1.0, 0.4], [0.06, 0.03], n, rng=rng) * 0.25
    hand = pad_to(_burst(rng, 0.03, 200.0, 2500.0 if doum else 6000.0, 0.006), n) * (0.3 if doum else 0.7)
    return fade_edges(saturate(skin + frame + hand, 1.2) * vel, 0.0004, 0.08)


def rattle(vel=0.7, rng=None, seconds=0.14, kind="gourd"):
    """Seeds in a gourd (a shake: grains of dry noise) or a sistrum (metal
    discs jingling on rods)."""
    metal = kind == "sistrum"
    n = n_of(seconds + (0.25 if metal else 0.05))
    out = np.zeros(n)
    count = int(rng.integers(8, 14)) if metal else int(rng.integers(14, 24))
    span = n_of(seconds)
    for _ in range(count):
        at = int(span * rng.beta(1.6, 2.6))
        if metal:
            g = partials(rng.uniform(3200.0, 6500.0), [1.0, 1.42, 2.13], [1.0, 0.6, 0.3], [0.06, 0.04, 0.025], n_of(0.2), rng=rng)
        else:
            g = bandpass(rng.standard_normal(n_of(0.006)), 2500.0, 9000.0) * env_exp(n_of(0.006), 0.0015)
        end = min(n, at + g.shape[0])
        out[at:end] += g[:end - at] * rng.uniform(0.4, 1.0)
    return fade_edges(out * vel * (0.3 if metal else 0.5), 0.0005, 0.03)


def bowl(midi, vel=0.7, rng=None, length=6.0):
    """Struck bowl bell (rin, singing bowl): inharmonic partials that beat
    slowly against their twins, a soft mallet."""
    f = float(hz(midi))
    n = n_of(length)
    ratios = [1.0, 2.71, 5.04, 8.0, 11.8]
    amps = [1.0, 0.55, 0.3, 0.14, 0.06]
    decays = [length * 0.55, length * 0.3, length * 0.16, length * 0.08, length * 0.04]
    tone = partials(f, ratios, amps, decays, n, rng=rng)
    twin = partials(f * float(cents(rng.uniform(2.0, 5.0))), ratios, amps, decays, n, rng=rng)
    strike = pad_to(_burst(rng, 0.02, 800.0, 5000.0, 0.004), n) * 0.15
    return fade_edges((tone + twin * 0.8 + strike) * vel * 0.4, 0.0008, 0.3)


def conch(midi, hold, vel=0.8, rng=None):
    """Conch shell trumpet: a blat that rises into its note and falls off,
    through the shell's one big resonance, with a rough buzz."""
    f = float(hz(midi))
    n = n_of(hold + 0.3)
    t = np.arange(n) / SR
    contour = -120.0 * np.exp(-t / 0.12) - 150.0 * np.clip((t - hold) / 0.3, 0.0, 1.0) ** 2
    freq = f * 2.0 ** (contour / 1200.0) * (1.0 + 0.012 * np.sin(TAU * 31.0 * t))
    raw = osc(freq, n, "saw", rng.uniform())
    body = fft_filter(raw, g_mul(lambda fr: 0.2 + g_peak(480.0, 2.5)(fr) + 0.6 * g_peak(1300.0, 3.0)(fr), g_lowpass(3500.0, 2)))
    breath = bandpass(rng.standard_normal(n), 600.0, 3000.0, 1) * 0.12
    env = env_adsr(n, 0.08, 0.3, 0.8, 0.25, gate=hold)
    return fade_edges(saturate(body * 1.5 + breath, 1.8) * env * vel * 0.6, 0.002, 0.05)


def sho(notes, hold, vel=0.5, rng=None, attack=1.2, release=1.5):
    """Mouth organ cluster (sho): free reeds, nearly pure with a reedy
    edge, a slow breath swell; a held cloud of fifths and seconds."""
    notes = np.atleast_1d(notes)
    n = n_of(hold + release)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for i, m in enumerate(notes):
        f = float(hz(m)) * float(cents(rng.uniform(-3.0, 3.0)))
        tone = np.sin(TAU * f * t + rng.uniform(0, TAU)) + 0.18 * np.sin(TAU * 2 * f * t) + 0.08 * np.sin(TAU * 3 * f * t)
        side = -0.4 + 0.8 * (i / max(len(notes) - 1, 1))
        out[:, 0] += tone * (0.6 - 0.3 * side)
        out[:, 1] += tone * (0.6 + 0.3 * side)
    env = env_adsr(n, attack, 0.5, 1.0, release, gate=hold) * (1.0 + 0.06 * np.sin(TAU * 0.25 * t))
    return out * env[:, None] * vel / len(notes) ** 0.5 * 0.5
