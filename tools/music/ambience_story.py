"""The ambient story's sounds (plan docs/superpowers/plans/2026-10-21-akustyka-ambient.md, backlog #41).

Imported by gen_ambience.py (same conventions as ambience_floor1.py: mono
one-shots with their distance baked in, 40 s beds periodic by
construction). The StoryLayer of the game plays them sparsely, by zone and
by the night's phase (data/audio/ambient_story.json).

One-shots (oneshots/shot_<kind>_<n>):
    settle         the building settles: a dry crack of a beam or plaster, a joist groans
    vent_knock     a sheet-metal duct cooling: a pop, ticks, a bong running along the duct
    vent_surge     air surges through the ducts, a grille rattles, it dies down
    phantom_steps  someone walks in the next room and stops (or drags a foot) - nobody is there
    shift_stone    a stone figure turns on its plinth: grinding, a heavy settle
    shift_wood     a carved figure: creak, a knock of wood
    shift_metal    an armour settles: plates clink, a scrape, a clunk
    shift_soft     wax, cloth, a stuffed animal: a rustle, a soft creak, a padded thump
    whisper        unintelligible whispers (formants over breath), now and then two voices
    clock_chime    a clock in the next room chimes (rods, a little out of tune)
    clock_wind     somebody winds a clock: the key's ratchet, the case shut, it ticks
    siren          a siren somewhere in the city, through the windows
    tram           the last tram behind the wall: its bell, the rail joints, a squeal on the curve
    radio_chatter  the security base station: squelch, a garbled dispatcher, the squelch tail
    thunder        far thunder rolling over the city (rainy nights only)
Beds (bed_<name>):
    rain_glass     rain on the court's great glass roof, heard from the hall below
    rain_open      rain on the open roof: hiss, splashes, plinks on metal, a gurgling downpipe
"""
import numpy as np

import ambience_floor1 as f1
import dsp
import instruments as ins
from dsp import SR, TAU, g_band, g_highpass, g_lowpass, g_mul, g_peak

LOOP = f1.LOOP
N = f1.N


# --- helpers ---------------------------------------------------------------------

def place(n, *parts):
    """Mixes (at seconds, signal, gain) parts into n samples."""
    out = np.zeros(n)
    for at, sig, gain in parts:
        i = dsp.n_of(at)
        if i >= n:
            continue
        m = min(sig.shape[0], n - i)
        out[i:i + m] += sig[:m] * gain
    return out


def hit(f, ratios, amps, decays, seconds, rng):
    return dsp.partials(f, ratios, amps, decays, dsp.n_of(seconds), rng=rng)


def click(rng, lo=1500.0, hi=7000.0, seconds=0.002):
    m = max(dsp.n_of(seconds), 8)
    return dsp.bandpass(rng.standard_normal(m), lo, hi) * dsp.env_exp(m, seconds * 0.3, 0.00005)


def circular_scatter(rng, rate, kernel, gain_lo=0.2, gain_hi=1.0, wander_rate=0.06, depth=0.6):
    """A loop of [param rate] random impacts per second (Poisson) of
    [param kernel], their density swelling and easing (circular)."""
    density = 1.0 - depth + depth * (0.5 + 0.5 * dsp.wander(N, rng, wander_rate))
    hits = rng.uniform(0.0, 1.0, N) < rate / SR * density
    train = np.zeros(N)
    train[hits] = rng.uniform(gain_lo, gain_hi, int(hits.sum())) * rng.choice([-1.0, 1.0], int(hits.sum()))
    k = np.zeros(N)
    k[:kernel.shape[0]] = kernel
    return np.fft.irfft(np.fft.rfft(train) * np.fft.rfft(k), N)


# --- whispers and voices (formants over a source) ------------------------------------

VOWELS = {"a": (780, 1250, 2650), "e": (520, 1850, 2650), "i": (340, 2250, 3050), "o": (540, 950, 2500),
          "u": (380, 850, 2400), "y": (450, 1500, 2550)}


def formant_gain(f, formants, scale=1.0, voiced=False):
    """Spectral envelope of a vowel (three resonances, the third weaker)."""
    g = np.zeros_like(f)
    for i, (fc, amp) in enumerate(zip(formants, (1.0, 0.7, 0.35))):
        q = fc * scale / (90.0 + 40.0 * i)
        g += amp * g_peak(fc * scale, q)(f)
    return g * (g_lowpass(4500.0, 1)(f) if voiced else 1.0)


def syllables(rng, count, rate=4.5):
    """[(start s, length s, vowel, consonant)] of a phrase."""
    out = []
    at = 0.0
    for k in range(count):
        length = rng.uniform(0.11, 0.26) * (4.5 / rate)
        cons = rng.choice(["s", "sh", "h", "t", "k", "", "", "f"])
        out.append((at, length, str(rng.choice(list(VOWELS))), str(cons)))
        at += length + rng.uniform(0.02, 0.1)
        if rng.uniform() < 0.15:
            at += rng.uniform(0.15, 0.35)   # a breath between words
    return out


def speak(rng, sylls, source, scale=1.0, voiced=False, frame=0.012):
    """Overlap-add of formant-filtered frames of [param source] following
    the syllables' vowels (with glides between them), consonants on top."""
    total = sylls[-1][0] + sylls[-1][1] + 0.2
    n = dsp.n_of(total)
    src = dsp.pad_to(source, n)
    hop = dsp.n_of(frame)
    size = hop * 2
    win = np.hanning(size)
    nfft = 1 << int(np.ceil(np.log2(size * 2)))
    f = np.fft.rfftfreq(nfft, 1.0 / SR)
    vowel_at = np.zeros((n, 3))
    amp = np.zeros(n)
    prev = VOWELS["y"]
    for start, length, vowel, _cons in sylls:
        a, m = dsp.n_of(start), dsp.n_of(length)
        target = np.array(VOWELS[vowel], dtype=float)
        glide = np.clip(np.linspace(0.0, 2.5, m), 0.0, 1.0)[:, None]
        vowel_at[a:a + m] = np.array(prev)[None, :] * (1.0 - glide) + target[None, :] * glide
        amp[a:a + m] = dsp.env_ar(m, 0.025, 0.05) * rng.uniform(0.6, 1.0)
        prev = target
    out = np.zeros(n + size)
    for i in range(0, n - size, hop):
        mid = i + hop
        level = amp[mid]
        if level < 1e-4:
            continue
        seg = src[i:i + size] * win
        spec = np.fft.rfft(seg, nfft) * formant_gain(f, vowel_at[mid], scale, voiced)
        out[i:i + size] += np.fft.irfft(spec, nfft)[:size] * level
    out = out[:n]
    for start, length, _vowel, cons in sylls:   # consonants lead into their vowel
        if not cons:
            continue
        if cons == "s":
            c = dsp.bandpass(rng.standard_normal(dsp.n_of(0.09)), 4500.0, 9500.0) * dsp.env_ar(dsp.n_of(0.09), 0.03, 0.04)
        elif cons == "sh":
            c = dsp.bandpass(rng.standard_normal(dsp.n_of(0.1)), 2000.0, 5000.0) * dsp.env_ar(dsp.n_of(0.1), 0.03, 0.04)
        elif cons in ("t", "k"):
            m = dsp.n_of(0.03)
            c = dsp.bandpass(rng.standard_normal(m), 2500.0 if cons == "t" else 1400.0, 7000.0) * dsp.env_exp(m, 0.006, 0.0003)
        else:
            c = dsp.bandpass(rng.standard_normal(dsp.n_of(0.05)), 900.0, 6000.0) * dsp.env_ar(dsp.n_of(0.05), 0.015, 0.03)
        c = c / max(dsp.rms(c), 1e-12) * dsp.rms(out[out != 0.0]) * 0.6 if np.any(out) else c
        at = dsp.n_of(max(start - c.shape[0] / SR * 0.7, 0.0))
        m = min(c.shape[0], n - at)
        out[at:at + m] += c[:m]
    return out


def shot_whisper(rng, k=0):
    """Unintelligible whispers close by, in a stone hall; takes 1 and 3 have
    a second voice a little behind the first."""
    sylls = syllables(rng, int(rng.integers(5, 10)), rate=5.0)
    breath = dsp.noise(dsp.n_of(4.0), rng, g_mul(dsp.pink, g_highpass(300.0, 1)))
    out = speak(rng, sylls, breath, scale=rng.uniform(1.0, 1.12))
    if k % 2 == 1:
        second = speak(rng, syllables(rng, int(rng.integers(4, 8)), rate=5.5), dsp.noise(dsp.n_of(4.0), rng, dsp.pink), 1.18)
        n = max(out.shape[0], second.shape[0] + dsp.n_of(0.35))
        out = place(n, (0.0, out, 1.0), (0.35, second, 0.6))
    return _stone_room(dsp.highpass(out, 280.0, 2), rng)


def _stone_room(x, rng, rt60=1.9, wet=0.35):
    ir = dsp.make_ir(rt60, rng, 0.018, rt60 * 1.2, 0.35, early=12, early_span=0.05)
    wet_sig = dsp.mono(dsp.convolve(x, ir))
    return dsp.fade_edges(dsp.pad_to(x, wet_sig.shape[0]) * (1.0 - wet) + wet_sig * wet * 0.5, 0.005, 0.4)


def glottal(n, rng, f0=115.0):
    """A voiced source: a pulse train with jitter and a falling contour."""
    t = np.arange(n) / SR
    pitch = f0 * (1.0 + 0.08 * np.sin(TAU * 0.7 * t + rng.uniform(0, TAU))) * (1.0 - 0.1 * t / max(t[-1], 1e-9))
    pitch *= 1.0 + 0.01 * rng.standard_normal(n).cumsum() / np.sqrt(n)
    phase = np.cumsum(pitch) / SR
    saw = 2.0 * (phase % 1.0) - 1.0
    pulses = np.diff(np.concatenate([[0.0], np.floor(phase)])) * 1.0
    return dsp.lowpass(saw * 0.4 + pulses * 3.0, 3800.0, 1) + rng.standard_normal(n) * 0.03


def shot_radio_chatter(rng, k=0):
    """The security base station on the desk: the squelch opens, a garbled
    dispatcher, the squelch tail (take 3: a roger beep)."""
    sylls = syllables(rng, int(rng.integers(7, 13)), rate=6.0)
    total = sylls[-1][0] + sylls[-1][1] + 0.3
    voice = speak(rng, sylls, glottal(dsp.n_of(total + 0.5), rng, rng.uniform(100.0, 125.0)), voiced=True)
    voice = voice / max(dsp.peak(voice), 1e-12)
    squelch_open = dsp.bandpass(rng.standard_normal(dsp.n_of(0.09)), 300.0, 4000.0) * dsp.env_ar(dsp.n_of(0.09), 0.003, 0.03)
    static = dsp.bandpass(rng.standard_normal(dsp.n_of(total + 0.2)), 400.0, 3500.0) * 0.06
    tail = dsp.bandpass(rng.standard_normal(dsp.n_of(0.18)), 500.0, 5000.0) * dsp.env_ar(dsp.n_of(0.18), 0.002, 0.12)
    n = dsp.n_of(total + 0.8)
    parts = [(0.0, squelch_open, 0.9), (0.06, static, 1.0), (0.12, voice, 0.8), (0.12 + total, tail, 0.8)]
    if k == 2:
        m = dsp.n_of(0.12)
        parts.append((0.12 + total + 0.05, np.sin(TAU * 1050.0 * np.arange(m) / SR) * dsp.env_ar(m, 0.004, 0.01), 0.35))
    out = place(n, *parts)
    out = dsp.bandpass(np.tanh(out * 3.0) / 3.0, 350.0, 3000.0, 2)   # a small, overdriven speaker
    out = dsp.fft_filter(out, g_mul(g_peak(1400.0, 1.5), g_highpass(300.0, 1))) * 0.7 + out * 0.5
    ir = dsp.make_ir(0.45, rng, 0.004, 0.6, 0.4, early=10, early_span=0.015)   # the booth: small, dead
    wet = dsp.mono(dsp.convolve(out, ir))
    return dsp.fade_edges(dsp.pad_to(out, wet.shape[0]) * 0.8 + wet * 0.12, 0.002, 0.1)


# --- the building --------------------------------------------------------------------

def crack(rng, f_lo=400.0, f_hi=900.0):
    """A dry crack of wood or plaster: a transient and a short resonance."""
    m = dsp.n_of(0.25)
    snap = click(rng, 800.0, 9000.0, 0.003) * 1.5
    body = hit(rng.uniform(f_lo, f_hi), [1.0, 2.3, 3.7], [1.0, 0.5, 0.25], [0.06, 0.03, 0.02], 0.25, rng)
    return dsp.pad_to(snap, m) + body * 0.6


def shot_settle(rng, k=0):
    n = dsp.n_of(3.2)
    parts = [(0.0, crack(rng), 1.0)]
    if k == 0:   # plaster: a crack and a little dust trickling
        parts.append((0.08, f1.grain_stream(rng, 0.6, 400.0, 2000.0, 7000.0, 0.002) * dsp.env_ar(dsp.n_of(0.6), 0.05, 0.4), 0.25))
    elif k == 1:   # a beam: the crack, then the beam groans under the load
        parts.append((0.15, f1.creak_at(rng, 1.6, low=True) * 30.0, 0.6))
    else:   # a joist: two cracks and a deep knock
        parts += [(0.32, crack(rng, 300.0, 600.0), 0.7), (0.5, ins.big_drum(rng.uniform(60.0, 80.0), 0.6, rng, 0.8), 0.5)]
    return f1.far(place(n, *parts), rng, 3.2, 0.65, 3500.0)


def plate(rng, f0=None, length=0.8, decay=0.4):
    """Sheet metal: inharmonic plate modes."""
    f0 = f0 or rng.uniform(85.0, 140.0)
    ratios = [1.0, 1.59, 2.14, 2.3, 2.65, 2.92, 3.5, 4.1, 5.2]
    amps = [1.0, 0.8, 0.6, 0.55, 0.45, 0.4, 0.3, 0.25, 0.15]
    decays = [decay * (1.2 - 0.1 * i) for i in range(len(ratios))]
    return hit(f0 * rng.uniform(0.98, 1.02), ratios, amps, decays, length, rng)


def duct(x, rng, length_m=None, gain=0.55, repeats=8):
    """The sound runs back and forth along a duct: a metallic flutter."""
    period = 2.0 * (length_m or rng.uniform(4.0, 8.0)) / 343.0
    n = x.shape[0] + dsp.n_of(period * repeats)
    out = dsp.pad_to(x, n)
    for r in range(1, repeats):
        at = dsp.n_of(period * r)
        echo = dsp.lowpass(x, 5000.0 - 400.0 * r, 1) * gain ** r
        out[at:at + echo.shape[0]] += echo[:n - at]
    return out


def shot_vent_knock(rng, k=0):
    n = dsp.n_of(2.4)
    if k == 0:   # one pop of the sheet, ringing along the duct
        x = place(n, (0.0, click(rng, 600.0, 6000.0, 0.004), 1.2), (0.0, plate(rng), 0.6))
    elif k == 1:   # ticks: the duct contracting, faster, then slower, a last tock
        parts = []
        at = 0.0
        gaps = sorted(rng.uniform(0.07, 0.25, int(rng.integers(4, 7))))[::-1] + list(rng.uniform(0.15, 0.4, 2))
        for g in gaps:
            parts.append((at, click(rng, 900.0, 5000.0, 0.003), rng.uniform(0.4, 0.8)))
            parts.append((at, plate(rng, rng.uniform(300.0, 500.0), 0.2, 0.06), 0.2))
            at += g
        parts.append((at, plate(rng, None, 0.8, 0.3), 0.6))
        x = place(n, *parts)
    else:   # a deep bong and the grille rattles
        m = dsp.n_of(0.6)
        rattle = dsp.bandpass(rng.standard_normal(m), 1800.0, 5000.0) * (0.5 + 0.5 * np.sign(np.sin(TAU * 26.0 * np.arange(m) / SR)))
        x = place(n, (0.0, plate(rng, rng.uniform(55.0, 75.0), 1.4, 0.7), 1.0), (0.1, rattle * dsp.env_ar(m, 0.01, 0.4), 0.25))
    return f1.far(duct(x, rng), rng, 1.6, 0.4, 5000.0)


def shot_vent_surge(rng, k=0):
    seconds = rng.uniform(4.0, 5.0)
    n = dsp.n_of(seconds)
    t = np.arange(n) / SR
    rise = 1.0 / (1.0 + np.exp(-(t - 1.0) * 4.0))
    fall = 1.0 / (1.0 + np.exp((t - seconds + 1.6) * 2.5))
    swell = rise * fall
    air = dsp.fft_filter(rng.standard_normal(n), lambda f: (g_band(70.0, 1600.0, 1)(f) * dsp.pink(f) * 30.0
                                                           + g_peak(86.0, 6.0)(f) + 0.6 * g_peak(172.0, 8.0)(f)
                                                           + 0.3 * g_peak(258.0, 9.0)(f)))
    air = air / max(dsp.rms(air), 1e-12) * swell
    peak_at = int(np.argmax(swell))
    m = dsp.n_of(1.2)
    rattle = dsp.bandpass(rng.standard_normal(m), 2000.0, 5000.0) * (0.5 + 0.5 * np.sign(np.sin(TAU * rng.uniform(22.0, 30.0) * np.arange(m) / SR)))
    rattle *= dsp.env_ar(m, 0.3, 0.6)
    damper = ins.tom(rng.uniform(110.0, 150.0), 0.6, rng)[:dsp.n_of(0.3)]
    x = place(n, (0.0, damper, 0.4 if k == 0 else 0.0), (0.0, air, 0.35), (peak_at / SR - 0.4, rattle, 0.12))
    return f1.far(x, rng, 1.4, 0.35, 4000.0)


# --- steps that are not there ---------------------------------------------------------

def footstep(rng, level=1.0):
    heel = ins.tom(rng.uniform(150.0, 190.0), 0.7, rng)[:dsp.n_of(0.18)]
    scuff = dsp.bandpass(rng.standard_normal(dsp.n_of(0.05)), 1000.0, 4000.0) * dsp.env_ar(dsp.n_of(0.05), 0.01, 0.03)
    return place(dsp.n_of(0.25), (0.0, heel, 0.8 * level), (0.0, click(rng, 1500.0, 6000.0, 0.006), 0.4 * level),
                 (0.06, scuff, 0.25 * level))


def shot_phantom_steps(rng, k=0):
    n = dsp.n_of(5.2)
    parts = []
    if k == 0:   # an even walk coming closer, then it stops; a last shuffle
        at = 0.0
        steps = int(rng.integers(6, 9))
        for i in range(steps):
            parts.append((at, footstep(rng), 0.55 + 0.45 * i / steps))
            at += rng.uniform(0.5, 0.58)
        m = dsp.n_of(0.25)
        parts.append((at + 0.5, dsp.bandpass(rng.standard_normal(m), 600.0, 3000.0) * dsp.env_ar(m, 0.05, 0.15), 0.18))
    else:   # a step and a dragged foot, slower - not the gait of a guard
        at = 0.0
        for i in range(int(rng.integers(4, 6))):
            parts.append((at, footstep(rng), 0.9))
            m = dsp.n_of(rng.uniform(0.25, 0.4))
            drag = dsp.bandpass(rng.standard_normal(m), 250.0, 2200.0) * dsp.env_ar(m, 0.08, 0.15)
            parts.append((at + 0.3, drag, 0.35))
            at += rng.uniform(0.85, 1.05)
    return f1.far(place(n, *parts), rng, 1.8, 0.45, 2600.0)


# --- exhibits shifting -----------------------------------------------------------------

def grind(rng, seconds, lo=120.0, hi=1400.0):
    n = dsp.n_of(seconds)
    t = np.arange(n) / SR
    rate = rng.uniform(20.0, 45.0) * (1.0 + 0.3 * np.sin(TAU * rng.uniform(0.5, 1.5) * t))
    stick = 0.55 + 0.45 * np.abs(np.sin(np.pi * np.cumsum(rate) / SR)) ** 3
    x = dsp.fft_filter(rng.standard_normal(n), lambda f: g_band(lo, hi, 1)(f) * (0.4 + g_peak(180.0, 4.0)(f) + 0.7 * g_peak(430.0, 5.0)(f)
                                                                               + 0.5 * g_peak(910.0, 6.0)(f)))
    return x / max(dsp.rms(x), 1e-12) * stick * dsp.env_ar(n, 0.12, 0.2)


def shot_shift_stone(rng, k=0):
    g = grind(rng, rng.uniform(0.7, 1.3))
    thump = ins.big_drum(rng.uniform(80.0, 105.0), 0.8, rng, 0.7)
    grit = f1.grain_stream(rng, 0.5, 600.0, 1500.0, 6000.0, 0.002) * dsp.env_ar(dsp.n_of(0.5), 0.02, 0.4)
    end = g.shape[0] / SR
    x = place(dsp.n_of(end + 1.2), (0.0, g, 0.35), (end - 0.05, thump, 0.8 if k == 0 else 0.5), (end, grit, 0.25))
    return f1.far(x, rng, 2.4, 0.55, 2400.0)


def shot_shift_wood(rng, k=0):
    c = f1.creak_at(rng, rng.uniform(0.8, 1.4), low=k == 1) * 30.0
    knock = hit(rng.uniform(600.0, 900.0), [1.0, 2.4, 4.1], [1.0, 0.5, 0.2], [0.05, 0.03, 0.015], 0.2, rng)
    knock += dsp.pad_to(ins.tom(rng.uniform(250.0, 400.0), 0.7, rng)[:dsp.n_of(0.2)], knock.shape[0])
    end = c.shape[0] / SR
    x = place(dsp.n_of(end + 1.5), (0.0, c, 0.8), (end * 0.8, knock, 0.7), (end + 0.35, f1.creak_at(rng, 0.4) * 30.0, 0.3))
    return f1.far(x, rng, 2.0, 0.5, 3500.0)


def shot_shift_metal(rng, k=0):
    parts = []
    for i in range(int(rng.integers(4, 9))):
        f = rng.uniform(1200.0, 3200.0)
        parts.append((rng.uniform(0.0, 0.6) ** 1.5, hit(f, [1.0, 1.48, 2.1, 2.9], [1.0, 0.6, 0.4, 0.2],
                                                         [rng.uniform(0.08, 0.25), 0.08, 0.05, 0.03], 0.4, rng), rng.uniform(0.2, 0.7)))
    m = dsp.n_of(0.3)
    parts.append((0.15, dsp.bandpass(rng.standard_normal(m), 1500.0, 6000.0) * dsp.env_ar(m, 0.05, 0.15), 0.15))
    parts.append((0.65 if k == 0 else 0.4, ins.tom(rng.uniform(140.0, 180.0), 0.7, rng)[:dsp.n_of(0.3)], 0.6))
    return f1.far(place(dsp.n_of(1.8), *parts), rng, 2.2, 0.5, 5000.0)


def shot_shift_soft(rng, k=0):
    rustle = f1.grain_stream(rng, 0.7, 2500.0, 1500.0, 7000.0, 0.003) * dsp.env_ar(dsp.n_of(0.7), 0.15, 0.3)
    thump = dsp.lowpass(ins.big_drum(rng.uniform(90.0, 120.0), 0.5, rng, 0.5), 600.0)
    x = place(dsp.n_of(2.0), (0.0, rustle, 0.6), (0.25, f1.creak_at(rng, 0.6) * 18.0, 0.4 if k == 0 else 0.15), (0.6, thump, 0.6))
    return f1.far(x, rng, 2.0, 0.5, 3000.0)


# --- clocks ----------------------------------------------------------------------------

def rod(midi, rng, vel=0.8, length=3.0):
    """A chime rod (gong rod): inharmonic, a little out of tune."""
    f = dsp.hz(midi) * dsp.cents(rng.uniform(-12.0, 12.0))
    tone = hit(f, [1.0, 2.756, 5.404, 8.933], [1.0, 0.45, 0.2, 0.08], [2.4, 1.1, 0.5, 0.25], length, rng)
    return tone * vel + dsp.pad_to(click(rng, 1500.0, 6000.0, 0.002) * 0.3 * vel, tone.shape[0])


def shot_clock_chime(rng, k=0):
    """Four notes of a quarter chime, then the hour rod."""
    phrase = [69, 65, 67, 62] if k == 0 else [74, 69, 70, 65]
    parts = [(i * 0.6, rod(m, rng, rng.uniform(0.6, 0.9)), 1.0) for i, m in enumerate(phrase)]
    parts.append((len(phrase) * 0.6 + 0.9, rod(phrase[-1] - 12, rng, 0.9, 4.0), 1.0))
    return f1.far(place(dsp.n_of(8.0), *parts), rng, 2.4, 0.55, 4500.0)


def shot_clock_wind(rng, k=0):
    """Somebody winds a clock: the key's ratchet, turn by turn; the case
    closes; it ticks."""
    parts = []
    at = 0.0
    turns = int(rng.integers(5, 8))
    for t_i in range(turns):
        clicks = int(rng.integers(4, 7))
        gap = rng.uniform(0.06, 0.08) * (1.0 - 0.15 * t_i / turns)
        for c_i in range(clicks):
            tick = click(rng, 2000.0, 7000.0, 0.0015)
            tick = dsp.pad_to(tick, dsp.n_of(0.08)) + hit(rng.uniform(320.0, 380.0), [1.0, 2.1], [1.0, 0.4], [0.03, 0.02], 0.08, rng) * 0.25
            parts.append((at, tick, rng.uniform(0.5, 0.9)))
            at += gap
        at += rng.uniform(0.2, 0.32)
    door = ins.tom(rng.uniform(300.0, 380.0), 0.7, rng)[:dsp.n_of(0.2)] + dsp.pad_to(click(rng, 1000.0, 5000.0, 0.004), dsp.n_of(0.2))
    parts.append((at + 0.3, door, 0.7))
    if k == 0:
        for i in range(4):
            parts.append((at + 1.0 + i * 0.5, ins.clock_tick(i % 2 == 1, 0.6, rng), 0.5))
    return f1.far(place(dsp.n_of(at + 3.5), *parts), rng, 1.6, 0.45, 6000.0)


# --- the city --------------------------------------------------------------------------

def city(x, rng, rt60=3.0, cutoff=1800.0):
    """Far away in the city: dark, echoes off the buildings, a long tail."""
    x = dsp.lowpass(x, cutoff, 2)
    n = x.shape[0] + dsp.n_of(1.5)
    out = dsp.pad_to(x, n)
    for delay, g in ((0.12, 0.4), (0.31, 0.3), (0.55, 0.2)):
        at = dsp.n_of(delay)
        out[at:at + x.shape[0]] += dsp.lowpass(x, cutoff * 0.7, 1)[:n - at] * g
    return f1.far(out, rng, rt60, 0.6, cutoff)


def shot_siren(rng, k=0):
    seconds = 9.0
    n = dsp.n_of(seconds)
    t = np.arange(n) / SR
    if k == 0:   # a wail
        f = 620.0 + 480.0 * (0.5 - 0.5 * np.cos(TAU * t / rng.uniform(3.8, 4.6)))
    else:   # two tones
        f = np.where((t // 0.62) % 2 == 0, 440.0, 587.0) * 1.0
        f = dsp.box_smooth(f, dsp.n_of(0.01), circular=False)
    f = f * (1.0 - 0.03 * t / seconds)   # it drives away
    phase = np.cumsum(f) / SR
    tone = sum(np.sin(TAU * h * phase) / h for h in (1, 2, 3, 4, 5, 7))
    envelope = np.clip(t / 2.5, 0.0, 1.0) * np.clip((seconds - t) / 3.0, 0.0, 1.0)
    return city(tone * envelope * 0.5, rng, 3.2, 1600.0)


def shot_tram(rng, k=0):
    seconds = 10.0
    n = dsp.n_of(seconds)
    t = np.arange(n) / SR
    centre = seconds * rng.uniform(0.45, 0.55)
    swell = np.exp(-0.5 * ((t - centre) / 2.0) ** 2)
    rumble = dsp.fft_filter(rng.standard_normal(n), g_mul(dsp.brown, g_band(45.0, 300.0, 2)))
    rumble = rumble / max(dsp.rms(rumble), 1e-12) * swell
    parts = [(0.0, rumble, 0.5)]
    for j in range(int(rng.integers(4, 7))):   # rail joints: ta-dum
        at = centre - 3.0 + j * rng.uniform(1.1, 1.4)
        near = float(np.exp(-0.5 * ((at - centre) / 2.2) ** 2))
        for d in (0.0, 0.11):
            parts.append((at + d, ins.tom(rng.uniform(70.0, 95.0), 0.8, rng)[:dsp.n_of(0.25)], 0.5 * near))
            parts.append((at + d, click(rng, 300.0, 2500.0, 0.012), 0.6 * near))   # the wheel over the joint
    bell_at = 0.4 if k == 0 else centre - 0.5
    for d in (0.0, 0.32):
        parts.append((bell_at + d, hit(rng.uniform(1750.0, 1850.0), [1.0, 2.0, 2.76, 5.4], [1.0, 0.4, 0.5, 0.15],
                                       [0.9, 0.5, 0.4, 0.15], 1.2, rng), 0.35))
    if k == 0:   # the squeal on the curve
        m = dsp.n_of(1.6)
        tt = np.arange(m) / SR
        fs = rng.uniform(2800.0, 3300.0) * (1.0 + 0.01 * np.sin(TAU * 6.0 * tt)) * (1.0 + 0.004 * rng.standard_normal(m).cumsum() / np.sqrt(m))
        squeal = np.sin(TAU * np.cumsum(fs) / SR) * dsp.env_ar(m, 0.4, 0.6) * (0.7 + 0.3 * np.sin(TAU * 11.0 * tt))
        parts.append((centre - 0.3, squeal, 0.12))
    return city(place(n, *parts), rng, 2.6, 2400.0)


def shot_thunder(rng, k=0):
    seconds = rng.uniform(7.0, 9.0)
    n = dsp.n_of(seconds)
    parts = []
    if k == 0:   # nearer: it starts with a crackle
        m = dsp.n_of(0.4)
        parts.append((0.0, dsp.bandpass(rng.standard_normal(m), 300.0, 4000.0) * dsp.env_exp(m, 0.08, 0.002), 0.6))
    for _ in range(int(rng.integers(7, 13))):
        m = dsp.n_of(rng.uniform(0.6, 2.2))
        burst = dsp.lowpass(rng.standard_normal(m), rng.uniform(150.0, 600.0), 2) * dsp.env_ar(m, rng.uniform(0.05, 0.4), m / SR * 0.7)
        parts.append((rng.uniform(0.1, seconds * 0.55) ** 1.1, burst, rng.uniform(0.4, 1.0)))
    sub = dsp.fft_filter(rng.standard_normal(n), g_band(20.0, 90.0, 2))
    sub = sub / max(dsp.rms(sub), 1e-12) * dsp.env_ar(n, 0.5, seconds * 0.6) * 0.15
    x = place(n, *parts) + sub
    return f1.far(dsp.lowpass(x, 900.0, 1), rng, 3.5, 0.5, 1200.0)


SHOTS = {
    "settle": (3, shot_settle), "vent_knock": (3, shot_vent_knock), "vent_surge": (2, shot_vent_surge),
    "phantom_steps": (2, shot_phantom_steps), "shift_stone": (2, shot_shift_stone), "shift_wood": (2, shot_shift_wood),
    "shift_metal": (2, shot_shift_metal), "shift_soft": (2, shot_shift_soft), "whisper": (4, shot_whisper),
    "clock_chime": (2, shot_clock_chime), "clock_wind": (2, shot_clock_wind), "siren": (2, shot_siren), "tram": (2, shot_tram),
    "radio_chatter": (3, shot_radio_chatter), "thunder": (3, shot_thunder),
}
# peaks chosen so the loudest moment of every kind lands near -16 LUFS
# (momentary, 400 ms): the clicky ones (settle, clock_wind, shift_wood) may
# peak higher; ambient_story.json sets how loud each plays
SHOT_PEAK_DB = {"settle": -2.0, "vent_knock": -6.0, "vent_surge": -8.0, "phantom_steps": -8.0, "shift_stone": -6.0,
                "shift_wood": -3.0, "shift_metal": -6.0, "shift_soft": -8.0, "whisper": -7.0, "clock_chime": -9.0,
                "clock_wind": -2.5, "siren": -8.0, "tram": -5.0, "radio_chatter": -7.0, "thunder": -5.0}


# --- rain beds ---------------------------------------------------------------------------

def bed_rain_glass(rng):
    """Rain on the court's great glass roof, heard from the floor 20 m below:
    countless ticks on glass, a wash, runoff along the glazing bars, now and
    then a fat drop off a frame; it swells and eases."""
    m = dsp.n_of(0.012)
    tap = dsp.bandpass(rng.standard_normal(dsp.n_of(0.01)), 600.0, 2500.0) * dsp.env_exp(dsp.n_of(0.01), 0.002, 0.0001)
    layers = []
    for ch in range(2):
        # every pane rings at its own pitch: many kernels, so no tick pitch stands out as a whine
        drops = np.zeros(N)
        for _ in range(12):
            tick = dsp.bandpass(rng.standard_normal(m), 2500.0, 9000.0) * dsp.env_exp(m, 0.0012, 0.0001)
            tick += hit(rng.uniform(2600.0, 6200.0), [1.0, 1.7], [1.0, 0.4], [0.003, 0.002], 0.012, rng) * 0.3
            drops += circular_scatter(rng, 900.0 / 12, tick, 0.1, 1.0, 0.05, 0.5)
        layers.append(drops + circular_scatter(rng, 260.0, tap, 0.1, 0.8, 0.05, 0.5) * 0.7)
    drops = np.stack(layers, 1)
    wash = dsp.noise(N, rng, g_mul(g_band(900.0, 9000.0, 1), dsp.pink), 2) * 0.12
    g_n = dsp.n_of(0.003)
    grain = rng.standard_normal(g_n) * dsp.env_exp(g_n, 0.001, 0.0002)
    runoff = np.stack([dsp.bandpass(circular_scatter(rng, 1200.0, grain, 0.2, 1.0, 0.1, 0.5), 1500.0, 5000.0, circular=True)
                       for _ in range(2)], 1)
    runoff = runoff * (0.6 + 0.4 * dsp.wander(N, rng, 0.1, 2))
    fat = f1.scatter(rng, 14, lambda: f1.drip(rng), gains=(0.2, 0.6))
    body = dsp.noise(N, rng, g_mul(dsp.brown, g_band(80.0, 400.0, 2)), 2) * 0.08
    swell = (0.75 + 0.25 * dsp.wander(N, rng, 0.04))[:, None]
    x = (drops * 0.5 + wash + runoff * 0.25) * swell + fat * 0.4 + body
    return f1.room(x, rng, 3.8, 0.06, 0.45, 0.45)


def bed_rain_open(rng):
    """Rain on the open roof: hiss, splashes in puddles, plinks on the
    railings and the plant room's sheeting, a downpipe gurgling."""
    m = dsp.n_of(0.02)
    splash = dsp.bandpass(rng.standard_normal(m), 1000.0, 7000.0) * dsp.env_exp(m, 0.003, 0.0002)
    layers = []
    for ch in range(2):
        plinks = np.zeros(N)
        for _ in range(9):   # railings, sheeting, a bucket: each its own note
            plink = hit(rng.uniform(1600.0, 4200.0), [1.0, 1.52, 2.4], [1.0, 0.5, 0.25], [0.03, 0.02, 0.01], 0.05, rng)
            plinks += circular_scatter(rng, 2.0, plink, 0.2, 1.0)
        layers.append(circular_scatter(rng, 1400.0, splash, 0.1, 1.0, 0.05, 0.4) + plinks * 0.6)
    drops = np.stack(layers, 1)
    hiss = dsp.noise(N, rng, g_mul(g_band(300.0, 11000.0, 1), dsp.pink), 2) * 0.35
    gurgle_am = (0.5 + 0.5 * dsp.wander(N, rng, 3.0)) ** 2
    gurgle = dsp.noise(N, rng, lambda f: g_peak(260.0, 5.0)(f) + 0.7 * g_peak(410.0, 6.0)(f) + 0.4 * g_peak(640.0, 6.0)(f)) * gurgle_am
    gurgle = np.stack([gurgle * 0.25, gurgle * 0.08], 1)
    swell = (0.8 + 0.2 * dsp.wander(N, rng, 0.05))[:, None]
    x = (drops * 0.45 + hiss) * swell + gurgle
    return f1.room(x, rng, 0.6, 0.03, 0.4, 0.15)


BEDS = {"rain_glass": bed_rain_glass, "rain_open": bed_rain_open}
MONO_BEDS = set()
BED_LUFS = {"rain_glass": -33.0, "rain_open": -30.0}
