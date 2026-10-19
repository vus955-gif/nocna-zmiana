"""Metal and electronic voices for the biome score (numpy, see dsp.py).

The guitars are modelled the way they are recorded: a picked string gives a
clean "DI" signal (Karplus-Strong, instruments.pluck), and the amplifier
runs over a whole bus, because distortion has to act on the sum of the
strings (a power chord's intermodulation is the sound of metal):

    string_di / chord_di  ->  bus  ->  amp()  ->  cab (inside amp)  ->  mix

amp(): pre-EQ (tight low cut, a mid hump like a tube screamer pedal), two
asymmetric tanh stages at 4x oversampling (FFT resampling, so a loop stays
a loop and the clipping does not alias), a scooped tone stack and a 4x12
cabinet curve. Everything is circular on loops.

Drums: a metal kit (kick with a beater click, cracking snare, toms, a
six-square-oscillator hi-hat, ride, crash, china), an industrial kick, a
gated snare. Synths: supersaw lead, reese and pluck basses, analog pad.
Culture: oud, shamisen (sawari buzz), aulos (melody pipe + drone pipe),
the Aztec death whistle, struck pipes and steam for the boiler room.

Every voice returns mono (n,) or stereo (n, 2) starting at the onset with
its tail; a seeded rng keeps renders repeatable.
"""
import numpy as np

import dsp
import instruments as ins
from dsp import (SR, TAU, bandpass, cents, env_adsr, env_exp, fade_edges, fft_filter, g_band, g_bell, g_highpass,
                 g_lowpass, g_mul, g_peak, g_shelf_hi, highpass, hz, lowpass, lowpass_sweep, n_of, osc, pad_to,
                 partials, ramp, saturate)


def _burst(rng, seconds, lo, hi, tau):
    n = n_of(seconds)
    return bandpass(rng.standard_normal(n), lo, hi) * env_exp(n, tau, 0.0003)


def _norm(x, level=1.0):
    p = dsp.peak(x)
    return x * (level / p) if p > 0 else x


# --- guitar strings (DI) --------------------------------------------------------

def string_di(midi, hold, vel=0.9, rng=None, mute=0.0, bright=0.6, sustain=1.0, pick=0.13):
    """One picked string, clean (before the amp). [param mute] 0..1 is the
    palm on the strings at the bridge: a shorter, darker ring. The string
    is damped [param hold] s after the pick (a fret hand lifting) with a
    short fall, so the amp's gain never lifts a tail it should not. [param
    pick]: where the pick strikes (fraction of the string): the comb notch
    that gives a pick its 'edge'."""
    f = float(hz(midi))
    open_t60 = 2.6 * sustain * (110.0 / f) ** 0.3
    mute_t60 = 0.16 + 0.04 * (110.0 / f) ** 0.5
    t60 = float(np.exp(np.log(open_t60) * (1.0 - mute) + np.log(mute_t60) * mute))
    br = bright * (1.0 - 0.55 * mute)
    length = hold + 0.035
    x = ins.pluck(midi, 1.0, rng, t60=t60, bright=br, length=length + 0.01)
    d = max(int(round(SR / f * pick)), 1)
    x = x - 0.6 * np.concatenate([np.zeros(d), x[:-d]])
    n = x.shape[0]
    t = np.arange(n) / SR
    damp = np.ones(n)
    gate = min(n_of(hold), n)
    damp[gate:] = np.exp(-(t[gate:] - hold) / 0.008)
    x = x * damp
    click = pad_to(_burst(rng, 0.004, 1800.0, 8000.0, 0.0008), n) * 0.12 * (1.0 - 0.5 * mute)
    return fade_edges(_norm(x + click) * vel, 0.0003, 0.012)


# chord shapes: semitones over the root (strings, low to high)
SHAPES = {"1": [0], "5": [0, 7], "5o": [0, 7, 12], "b5": [0, 6], "4": [0, 5], "m": [0, 7, 12, 15], "M": [0, 7, 12, 16],
          "oct": [0, 12], "sus2": [0, 7, 14], "add9": [0, 7, 14, 15], "Madd9": [0, 7, 14, 16], "maj7": [0, 7, 11, 16],
          "m9": [0, 7, 10, 14, 15]}


def chord_di(root, shape, hold, vel=0.9, rng=None, mute=0.0, strum=0.004, bright=0.6, up=False):
    """A chord on adjacent strings (SHAPES), strummed down (or up) over
    [param strum] s per string, each string a hair off the others."""
    offsets = SHAPES[shape] if isinstance(shape, str) else list(shape)
    order = offsets[::-1] if up else offsets
    parts = []
    for k, off in enumerate(order):
        delay = n_of(strum * k * rng.uniform(0.7, 1.3)) if k else 0
        tone = string_di(root + off + rng.uniform(-0.03, 0.03), max(hold - delay / SR, 0.03),
                         vel * (1.0 if k == 0 else 0.85), rng, mute, bright)
        parts.append((delay, tone))
    n = max(d + p.shape[0] for d, p in parts)
    out = np.zeros(n)
    for d, p in parts:
        out[d:d + p.shape[0]] += p
    return out / len(offsets) ** 0.35


# --- the amp -----------------------------------------------------------------------

def _over(x, factor):
    """FFT resampling up by [param factor] (circular: a loop stays a loop)."""
    n = x.shape[0]
    spec = np.fft.rfft(x)
    return np.fft.irfft(spec, n * factor) * factor


def _under(y, factor, n):
    spec = np.fft.rfft(y)[:n // 2 + 1]
    return np.fft.irfft(spec, n) / factor


def _filter_at(y, rate, gain):
    spec = np.fft.rfft(y)
    f = np.fft.rfftfreq(y.shape[0], 1.0 / rate)
    return np.fft.irfft(spec * gain(f), y.shape[0])


def _gauss_level(x):
    """A robust level of a sparse signal: the RMS where it plays."""
    a = np.abs(x)
    loud = a[a > 1e-4 * (np.max(a) or 1.0)]
    return float(np.sqrt(np.mean(loud ** 2))) if loud.size else 1.0


def amp(x, drive=1.0, tight=90.0, mid=760.0, mid_db=6.0, scoop_db=-4.0, presence_db=4.5, cab=6800.0, bias=0.22,
        oversample=4, circular=True, level=0.25):
    """High-gain amplifier and 4x12 cabinet over a whole guitar bus (mono
    (n,) or stereo (n, 2), each channel alone). The input is levelled to
    its playing RMS first, so [param drive] means the same for a sparse
    riff and a dense one. circular=True treats the bus as a loop."""
    x = np.asarray(x, dtype=float)
    if x.ndim == 2:
        return np.stack([amp(x[:, c], drive, tight, mid, mid_db, scoop_db, presence_db, cab, bias, oversample, circular,
                             level) for c in range(2)], axis=1)
    n = x.shape[0]
    if not np.any(x):
        return x.copy()
    pad = 0 if circular else n_of(0.3)
    if pad:
        x = np.concatenate([x, np.zeros(pad)])
    x = x / (_gauss_level(x) * 4.0)
    pre = fft_filter(x, g_mul(g_highpass(tight, 2), g_bell(mid, mid_db, 0.9), g_lowpass(6500.0, 1)), circular=True)
    rate = SR * oversample
    up = _over(pre, oversample)
    g1 = 7.0 * drive
    y = np.tanh(g1 * up + bias) - np.tanh(bias)
    y = _filter_at(y, rate, g_mul(g_highpass(35.0, 1), g_lowpass(9000.0, 1)))
    y = y / (np.percentile(np.abs(y), 99.5) or 1.0)
    g2 = 2.6 * drive ** 0.5
    y = np.tanh(g2 * y + bias * 0.6) - np.tanh(bias * 0.6)
    y = _under(y, oversample, x.shape[0])
    stack = g_mul(g_highpass(75.0, 2), g_bell(115.0, 3.0, 0.8), g_bell(450.0, scoop_db, 1.1), g_bell(1500.0, 1.5, 0.6),
                  g_bell(2900.0, presence_db, 0.6), g_lowpass(cab, 3), g_bell(8000.0, -3.0, 0.4))
    y = fft_filter(y, stack, circular=True)
    y = y - np.mean(y)
    y = y[:n]
    return y / (_gauss_level(y) or 1.0) * level


def clean_amp(x, bright=1.0, chorus=0.0, circular=True, cycles=None):
    """A clean channel: a touch of tube warmth, bright EQ, optional chorus
    (a modulated short delay; [param cycles] = LFO turns over the loop, so a
    loop stays periodic). Mono in, stereo out."""
    x = np.asarray(x, dtype=float)
    n = x.shape[0]
    if not np.any(x):
        return np.zeros((n, 2))
    x = x / (_gauss_level(x) * 3.0)
    y = np.tanh(1.3 * x) / 1.3
    y = fft_filter(y, g_mul(g_highpass(90.0, 2), g_bell(220.0, -2.0, 0.8), g_shelf_hi(2500.0, 2.0 * bright),
                            g_lowpass(9000.0, 1)), circular=circular)
    if not chorus:
        return dsp.stereo(y)
    turns = cycles if cycles is not None else max(int(round(n / SR * 0.6)), 1)
    out = np.zeros((n, 2))
    idx = np.arange(n, dtype=float)
    for c, phase in ((0, 0.0), (1, 0.25)):
        delay = (0.009 + 0.0025 * np.sin(TAU * (turns * idx / n + phase))) * SR
        pos = idx - delay
        if circular:
            pos = np.mod(pos, n)
            i0 = np.floor(pos).astype(np.int64)
            frac = pos - i0
            wet = y[i0 % n] * (1.0 - frac) + y[(i0 + 1) % n] * frac
        else:
            wet = np.interp(pos, idx, y, left=0.0)
        out[:, c] = y * (1.0 - 0.4 * chorus) + wet * 0.6 * chorus
    return out


def bass_amp(x, drive=1.0, circular=True):
    """Bass rig: a little drive (2x oversampled), the clank at 800 Hz, a
    tight sub."""
    x = np.asarray(x, dtype=float)
    n = x.shape[0]
    if not np.any(x):
        return x.copy()
    x = x / (_gauss_level(x) * 3.0)
    up = _over(x, 2)
    y = np.tanh(2.2 * drive * up) / (2.2 * drive) ** 0.5
    y = _under(y, 2, n)
    y = fft_filter(y, g_mul(g_highpass(50.0, 2), g_bell(90.0, 1.0, 0.8), g_bell(800.0, 4.5, 0.7), g_lowpass(4200.0, 2)),
                   circular=circular)
    y = y - np.mean(y)
    return y / (_gauss_level(y) or 1.0) * 0.25


def bass_di(midi, hold, vel=0.9, rng=None, mute=0.0):
    """Picked bass string (DI) with a sine under it (the low end a pick
    leaves thin)."""
    f = float(hz(midi))
    x = string_di(midi, hold, 1.0, rng, mute=mute, bright=0.45, sustain=0.8, pick=0.18)
    n = x.shape[0]
    t = np.arange(n) / SR
    sub = np.sin(TAU * f * t + rng.uniform(0, TAU)) * env_adsr(n, 0.004, 0.25, 0.7, 0.03, gate=hold) * 0.2
    return fade_edges(_norm(x + sub) * vel, 0.0005, 0.012)


def lead_di(midi, hold, vel=0.9, rng=None, vibrato=0.35, scoop=0.0, bend_to=None, bend_at=0.5, glide=0.0):
    """A sustained lead note (DI) with vibrato (semitone fraction) after a
    delay, an optional scoop up into the note and a bend toward [param
    bend_to] semitones from [param bend_at] (fraction of the note)."""
    x = string_di(midi, hold, 1.0, rng, mute=0.0, bright=0.7, sustain=2.2, pick=0.1)
    n = x.shape[0]
    t = np.arange(n) / SR
    curve = np.zeros(n)
    if scoop:
        curve += -100.0 * scoop * np.exp(-t / 0.05)
    if bend_to is not None:
        start = hold * bend_at
        curve += 100.0 * bend_to * np.clip((t - start) / 0.12, 0.0, 1.0)
    if glide:
        curve += 100.0 * glide * np.clip(t / max(hold, 0.05), 0.0, 1.0)
    if vibrato:
        onset = np.clip((t - min(0.25, hold * 0.4)) / 0.3, 0.0, 1.0)
        curve += 100.0 * vibrato * 0.5 * np.sin(TAU * rng.uniform(5.2, 6.2) * t) * onset
    if np.any(curve):
        x = ins.bend(x, curve)
    return x * vel


# --- drums ---------------------------------------------------------------------------

def kick(vel=0.9, rng=None, tight=1.0, click=1.0, f_end=58.0):
    """Metal kick: a beater click (the 'trigger' tick that cuts through
    guitars), a fast pitch drop, a short body (double kicks stay apart)."""
    n = n_of(0.32)
    t = np.arange(n) / SR
    pitch = f_end + 120.0 * np.exp(-t / 0.018)
    ph = np.cumsum(pitch) / SR
    body = np.sin(TAU * ph) * np.exp(-t / (0.11 * tight))
    sub = np.sin(TAU * f_end * 0.98 * t) * np.exp(-t / (0.2 * tight)) * 0.05 * ramp_on(n, 0.01)
    beater = pad_to(_burst(rng, 0.004, 2500.0, 9000.0, 0.0007), n) * 0.9
    tick = np.sin(TAU * 3800.0 * t) * np.exp(-t / 0.0018) * 0.35
    out = saturate(body * 1.3 + sub + (beater + tick) * click * 1.5, 1.6)
    return fade_edges(_norm(out) * vel, 0.0002, 0.03)


def ramp_on(n, seconds):
    env = np.ones(n)
    a = min(n_of(seconds), n)
    env[:a] = ramp(a)
    return env


def snare(vel=0.9, rng=None, body=1.0, crack=1.0, tone=195.0):
    """Metal snare: shell modes with a pitch drop, bright wires, a crack."""
    n = n_of(0.42)
    t = np.arange(n) / SR
    drop = 1.0 + 0.15 * np.exp(-t / 0.012)
    shell = (np.sin(TAU * np.cumsum(tone * drop) / SR) + 0.55 * np.sin(TAU * np.cumsum(tone * 1.62 * drop) / SR + 1.0)) \
        * np.exp(-t / 0.075)
    wires = bandpass(rng.standard_normal(n), 1600.0, 10000.0) * (0.7 * np.exp(-t / 0.11) + 0.3 * np.exp(-t / 0.22))
    snap = pad_to(_burst(rng, 0.006, 2500.0, 14000.0, 0.0012), n) * 1.4
    out = saturate(shell * 0.75 * body + wires * 0.6 + snap * crack, 1.7)
    return fade_edges(_norm(out) * vel, 0.0002, 0.04)


def gated_snare(vel=0.9, rng=None, gate=0.24):
    """1980s gated snare: the snare plus a dense room tail cut at [param
    gate] s (darksynth)."""
    dry = snare(vel, rng, body=1.2, crack=0.8, tone=180.0)
    n = n_of(gate + 0.05)
    t = np.arange(n) / SR
    tail = bandpass(rng.standard_normal(n), 300.0, 7000.0, 1) * np.exp(-t / 0.5)
    shut = np.ones(n)
    g = n_of(gate)
    shut[g:] = np.exp(-(t[g:] - gate) / 0.006)
    tail = lowpass(tail * shut, 6000.0, 1)
    out = pad_to(dry, max(dry.shape[0], n)) + pad_to(tail, max(dry.shape[0], n)) * 0.45
    return fade_edges(_norm(out) * vel, 0.0002, 0.03)


def tom(f0=110.0, vel=0.85, rng=None, length=0.7):
    n = n_of(length)
    t = np.arange(n) / SR
    pitch = f0 * (1.0 + 0.35 * np.exp(-t / 0.03))
    ph = np.cumsum(pitch) / SR
    body = np.sin(TAU * ph) * np.exp(-t / 0.28) + 0.3 * np.sin(TAU * 1.58 * ph) * np.exp(-t / 0.09)
    skin = pad_to(_burst(rng, 0.01, 800.0, 7000.0, 0.002), n) * 0.5
    return fade_edges(_norm(saturate(body + skin, 1.4)) * vel, 0.0002, 0.05)


_HAT = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]


def hihat(kind="closed", vel=0.7, rng=None):
    """Six square oscillators at inharmonic ratios (the analog cymbal)
    through a high band, plus noise: 'closed', 'open', 'pedal'."""
    decay = {"closed": 0.045, "open": 0.42, "pedal": 0.06}[kind]
    n = n_of(decay * 5.0 + 0.02)
    t = np.arange(n) / SR
    scale = rng.uniform(1.55, 1.65)
    metal = sum(osc(fq * scale, n, "square", rng.uniform()) for fq in _HAT) / 6.0
    hiss = rng.standard_normal(n) * 0.6
    x = fft_filter(metal + hiss, g_mul(g_highpass(6500.0, 3), g_lowpass(15000.0, 1), g_bell(9500.0, 3.0, 0.5)))
    env = np.exp(-t / decay)
    if kind == "pedal":
        env *= ramp_on(n, 0.004)
    return fade_edges(_norm(x * env) * vel, 0.0002, 0.01)


def ride(vel=0.7, rng=None, bell=0.3, length=2.4):
    """Ride: a 'ping' over a wash; [param bell] mixes in the cup."""
    n = n_of(length)
    t = np.arange(n) / SR
    ping = partials(rng.uniform(420.0, 450.0), [1.0, 2.18, 3.41, 4.95, 6.31, 7.73, 9.6],
                    [0.5, 0.45, 0.4, 0.35, 0.3, 0.22, 0.18], [1.2, 1.0, 0.9, 0.7, 0.6, 0.5, 0.4], n, rng=rng)
    wash = bandpass(rng.standard_normal(n), 3500.0, 13000.0, 1) * (0.5 * np.exp(-t / 0.08) + 0.5 * np.exp(-t / 1.1))
    cup = partials(rng.uniform(780.0, 820.0), [1.0, 2.7, 5.1], [1.0, 0.5, 0.3], [1.4, 0.8, 0.5], n, rng=rng)
    stick = pad_to(_burst(rng, 0.003, 3000.0, 12000.0, 0.0008), n)
    out = highpass(ping, 1500.0) * 0.35 + wash * 0.35 + cup * bell * 0.3 + stick * 0.5
    return fade_edges(_norm(out) * vel, 0.0002, 0.2)


def crash(vel=0.8, rng=None, length=3.2, china=False):
    """Crash (or a china: trashier, shorter, a mid bark): a cloud of
    inharmonic partials over two noise decays."""
    n = n_of(length * (0.6 if china else 1.0))
    t = np.arange(n) / SR
    count = 26
    fr = np.sort(rng.uniform(450.0, 9000.0, count))
    cloud = np.zeros(n)
    for fq in fr:
        d = rng.uniform(0.4, 1.6) * (0.6 if china else 1.0) * (1500.0 / fq) ** 0.3
        cloud += np.sin(TAU * fq * t + rng.uniform(0, TAU)) * np.exp(-t / d) * rng.uniform(0.4, 1.0)
    cloud /= count ** 0.5
    lo, hi = (1200.0, 9000.0) if china else (3000.0, 15000.0)
    hiss = bandpass(rng.standard_normal(n), lo, hi, 1) * (0.6 * np.exp(-t / 0.25) + 0.4 * np.exp(-t / (0.9 if china else 1.4)))
    out = highpass(cloud, 900.0 if not china else 600.0) * 0.6 + hiss * 0.7
    if china:
        out = saturate(out * 2.0, 2.0)
    stick = pad_to(_burst(rng, 0.004, 2000.0, 12000.0, 0.001), n) * 0.6
    return fade_edges(_norm(out + stick) * vel, 0.0003, 0.25)


def industrial_kick(vel=0.95, rng=None):
    """A drum machine kick through a fuzz: long, hard, distorted."""
    n = n_of(0.45)
    t = np.arange(n) / SR
    pitch = 54.0 + 160.0 * np.exp(-t / 0.025)
    body = np.sin(TAU * np.cumsum(pitch) / SR) * np.exp(-t / 0.18)
    click = pad_to(_burst(rng, 0.006, 1500.0, 7000.0, 0.0012), n)
    out = np.tanh(3.5 * (body + 0.5 * click)) / np.tanh(3.5)
    out = lowpass(out, 5000.0, 2)
    return fade_edges(_norm(out) * vel, 0.0002, 0.04)


def clap(vel=0.8, rng=None):
    """Hand clap: three quick noise bursts then a short tail."""
    n = n_of(0.3)
    out = np.zeros(n)
    for k, at in enumerate((0.0, 0.009, 0.018)):
        b = _burst(rng, 0.012, 900.0, 6000.0, 0.003)
        a = n_of(at)
        out[a:a + b.shape[0]] += b * (0.7 + 0.15 * k)
    t = np.arange(n) / SR
    tail = bandpass(rng.standard_normal(n), 1000.0, 5000.0) * np.exp(-t / 0.07) * np.clip((t - 0.02) / 0.002, 0, 1)
    return fade_edges(_norm(out + tail * 0.5) * vel, 0.0002, 0.03)


# --- synths -----------------------------------------------------------------------------

def supersaw(midi, hold, vel=0.8, rng=None, voices=7, detune=18.0, bright=1.0, attack=0.01, release=0.25,
             vibrato=0.0, glide_from=None):
    """Supersaw lead / chord voice ([param midi] a note or a list of them):
    detuned saws spread over the stereo field, a filter that opens on the
    attack, a little drive."""
    notes = [float(x) for x in np.atleast_1d(midi)]
    f = float(hz(min(notes)))
    n = n_of(hold + release)
    t = np.arange(n) / SR
    pitch = np.ones(n)
    if glide_from is not None:
        pitch = 2.0 ** ((glide_from - notes[0]) / 12.0 * np.exp(-t / 0.04))
    if vibrato:
        pitch = pitch * (1.0 + vibrato * 0.0058 * np.sin(TAU * 5.6 * t) * np.clip((t - 0.2) / 0.3, 0, 1))
    out = np.zeros((n, 2))
    for note in notes:
        fn = float(hz(note))
        for v in range(voices):
            d = detune * (2.0 * v / max(voices - 1, 1) - 1.0) * rng.uniform(0.85, 1.0)
            tone = osc(fn * float(cents(d)) * pitch, n, "saw", rng.uniform())
            side = (v % 2) * 2 - 1 if v else 0
            out[:, 0] += tone * (0.6 - 0.35 * side)
            out[:, 1] += tone * (0.6 + 0.35 * side)
    out /= (voices * len(notes)) ** 0.5
    cutoff = np.minimum(f * (3.0 + 6.0 * bright * np.exp(-t / 0.15)) + 1200.0 * bright, 16000.0)
    out = np.stack([lowpass_sweep(out[:, c], cutoff, 2, bands=12) for c in range(2)], axis=1)
    env = env_adsr(n, attack, 0.3, 0.8, release, gate=hold)
    return saturate(out * env[:, None] * 1.2, 1.5) * vel


def reese(midi, hold, vel=0.8, rng=None, cutoff=700.0, drive=1.6, release=0.06):
    """Reese bass: two saws a dozen cents apart (the slow phasing), a sine
    sub, low-passed and driven."""
    f = float(hz(midi))
    n = n_of(hold + release)
    t = np.arange(n) / SR
    raw = osc(f * float(cents(-11.0)), n, "saw", rng.uniform()) + osc(f * float(cents(11.0)), n, "saw", rng.uniform())
    raw = raw * 0.5 + 0.8 * np.sin(TAU * f * t + rng.uniform(0, TAU))
    body = lowpass(raw, cutoff, 3)
    env = env_adsr(n, 0.004, 0.2, 0.85, release, gate=hold)
    return saturate(body * env * 1.3, drive) * vel


def synth_pluck(midi, vel=0.7, rng=None, decay=0.22, bright=1.0, square=0.4):
    """Plucky synth (arpeggios): saw + square, a snapping filter envelope."""
    f = float(hz(midi))
    n = n_of(min(decay * 5.0 + 0.05, 2.5))
    t = np.arange(n) / SR
    raw = osc(f * float(cents(-4)), n, "saw", rng.uniform()) + square * osc(f * float(cents(4)), n, "square", rng.uniform())
    cutoff = 250.0 + f * 1.5 + 5200.0 * bright * vel * np.exp(-t / 0.05)
    body = lowpass_sweep(raw, cutoff, 2, bands=10)
    return fade_edges(body * np.exp(-t / decay) * ramp_on(n, 0.002) * vel * 0.7, 0.0005, 0.03)


def analog_pad(notes, hold, vel=0.6, rng=None, attack=1.2, release=2.0, cutoff=1400.0, motion=0.3):
    """Analog-style pad: two detuned saws per note and side, a slowly
    breathing low-pass."""
    notes = np.atleast_1d(notes)
    n = n_of(hold + release)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for midi in notes:
        f = float(hz(midi))
        for side in range(2):
            for _ in range(2):
                out[:, side] += osc(f * float(cents(rng.uniform(-9, 9))), n, "saw", rng.uniform()) * 0.5
    breathe = cutoff * (1.0 + motion * np.sin(TAU * rng.uniform(0.08, 0.15) * t + rng.uniform(0, TAU)))
    out = np.stack([lowpass_sweep(out[:, c], breathe, 2, bands=8) for c in range(2)], axis=1)
    env = env_adsr(n, attack, 1.0, 1.0, release, gate=hold)
    return out * env[:, None] * vel / len(notes) ** 0.5


def sub_bass(midi, hold, vel=0.8, rng=None, release=0.08):
    """Pure low sine with a soft second harmonic (the electronic floor)."""
    f = float(hz(midi))
    n = n_of(hold + release)
    t = np.arange(n) / SR
    x = np.sin(TAU * f * t) + 0.12 * np.sin(TAU * 2 * f * t)
    return x * env_adsr(n, 0.01, 0.2, 0.9, release, gate=hold) * vel


# --- culture ---------------------------------------------------------------------------

def oud(midi, vel=0.75, rng=None, ring=1.0):
    """Oud: a fretless short-necked lute, its plectrum (risha) bright, the
    pear-shaped bowl warm; a short ring, so tremolo picking reads."""
    f = float(hz(midi))
    string = ins.pluck(midi, vel, rng, t60=0.9 * ring * (196.0 / f) ** 0.3, bright=0.55)
    body = fft_filter(string, g_mul(g_bell(160.0, 4.0, 0.7), g_bell(450.0, 3.0, 0.8), g_bell(2400.0, 2.0, 0.8),
                                    g_highpass(70.0, 2)))
    pick = pad_to(_burst(rng, 0.004, 2000.0, 8000.0, 0.0008), body.shape[0]) * 0.18 * vel
    return body + pick


def shamisen(midi, vel=0.8, rng=None):
    """Shamisen: a bright string whose bridge lets it buzz against the
    neck (sawari: the nonlinear 'zzz' over the note), the bachi slapping
    the skin as it plucks."""
    f = float(hz(midi))
    s = ins.pluck(midi, 1.0, rng, t60=0.85 * (220.0 / f) ** 0.25, bright=0.85)
    p = dsp.peak(s) or 1.0
    buzz = np.sign(s) * np.maximum(np.abs(s) - 0.35 * p, 0.0)
    buzz = highpass(buzz, 1800.0, 2) * 2.5
    n = s.shape[0]
    t = np.arange(n) / SR
    skin = np.sin(TAU * 170.0 * t) * np.exp(-t / 0.025) * 0.5 + pad_to(_burst(rng, 0.012, 400.0, 3500.0, 0.003), n) * 0.6
    out = fft_filter(s + buzz + skin, g_mul(g_highpass(110.0, 2), g_bell(500.0, 2.0, 0.8), g_bell(3000.0, 3.0, 0.8)))
    return fade_edges(_norm(out) * vel, 0.0002, 0.03)


def aulos(midi, hold, vel=0.8, rng=None, drone=62, drone_level=0.45):
    """Aulos: two reed pipes blown at once, one playing the tune, the other
    holding a drone (D4); bright and buzzy, the pipes a few cents apart."""
    tune = ins.reed(midi, hold, vel, rng, dark=False)
    hum = ins.reed(drone + rng.uniform(0.04, 0.08), hold, vel * drone_level, rng, dark=False)
    n = max(tune.shape[0], hum.shape[0])
    out = pad_to(tune, n) + pad_to(hum, n)
    return fft_filter(out, g_mul(g_shelf_hi(4200.0, -3.0), g_bell(1800.0, 2.0, 0.7)))


def death_whistle(hold, vel=0.9, rng=None, pitch=1900.0):
    """Aztec death whistle: air forced through a narrow duct into a
    chamber - a turbulent scream: noise in wandering resonances, a pitched
    whine that glides up and sags, a rough fast flutter, swelling and
    dying like a breath."""
    n = n_of(hold + 0.35)
    t = np.arange(n) / SR
    chaos = dsp.wander(n, rng, 18.0)
    glide = 1.0 + 0.25 * np.clip(t / 0.25, 0, 1) - 0.18 * np.clip((t - hold * 0.6) / max(hold * 0.4, 0.05), 0, 1)
    freq = pitch * glide * (1.0 + 0.045 * chaos)
    whine = np.sin(TAU * np.cumsum(freq) / SR) + 0.4 * np.sin(TAU * np.cumsum(freq * 1.98) / SR)
    air = rng.standard_normal(n)
    band = (fft_filter(air, g_peak(pitch * 1.1, 4.0)) * 1.0 + fft_filter(air, g_peak(pitch * 0.55, 3.0)) * 0.6
            + fft_filter(air, g_band(900.0, 6000.0, 1)) * 0.35)
    flutter = 1.0 + 0.6 * dsp.wander(n, rng, 45.0)
    env = env_adsr(n, 0.12, 0.3, 0.85, 0.3, gate=hold)
    out = (whine * 0.5 * (1.0 + 0.5 * chaos) + band / (dsp.rms(band) or 1.0) * 0.6) * flutter * env
    out = saturate(out * 1.5, 2.2)
    return fade_edges(_norm(highpass(out, 400.0, 2)) * vel, 0.002, 0.05)


def pipe_hit(f0=420.0, vel=0.8, rng=None, length=1.4, dull=0.0):
    """A struck steel pipe or girder: free-bar modes (1 : 2.76 : 5.40 :
    8.93), a hard strike, a little grit; [param dull] shortens it (a
    rusty one)."""
    n = n_of(length)
    f0 *= float(cents(rng.uniform(-20, 20)))
    k = 1.0 - 0.7 * dull
    ring = partials(f0, [1.0, 2.756, 5.404, 8.933, 13.34], [1.0, 0.7, 0.45, 0.3, 0.18],
                    [0.9 * k, 0.55 * k, 0.32 * k, 0.2 * k, 0.12 * k], n, rng=rng)
    strike = pad_to(_burst(rng, 0.008, 1500.0, 12000.0, 0.0015), n)
    return fade_edges(_norm(saturate(ring * 0.8 + strike * 0.7, 1.4)) * vel, 0.0002, 0.08)


def steam(seconds, vel=0.6, rng=None, attack=0.05):
    """A hiss of steam from a valve."""
    n = n_of(seconds + 0.2)
    x = bandpass(rng.standard_normal(n), 2000.0, 11000.0, 1)
    env = env_adsr(n, attack, 0.2, 0.7, 0.2, gate=seconds) * (1.0 + 0.15 * dsp.wander(n, rng, 8.0))
    return fade_edges(x * env * vel * 0.3, 0.002, 0.05)


def riser(seconds, rng, top=7000.0, channels=2):
    """Noise swelling and opening up toward its end (into a downbeat)."""
    n = n_of(seconds)
    x = dsp.noise(n, rng, dsp.pink, channels)
    t = np.linspace(0.0, 1.0, n)
    cut = 250.0 + top * t ** 2
    if channels == 2:
        x = np.stack([lowpass_sweep(x[:, c], cut, 2) for c in range(2)], axis=1)
        return fade_edges(x * (t ** 2.5)[:, None], 0.01, 0.03)
    return fade_edges(lowpass_sweep(x, cut, 2) * t ** 2.5, 0.01, 0.03)


def reverse_cymbal(seconds, vel=0.7, rng=None):
    """A crash played backwards: swells into the next downbeat."""
    c = crash(vel, rng, length=seconds + 0.2)
    c = c[:n_of(seconds)][::-1]
    return fade_edges(c, 0.05, 0.004)
