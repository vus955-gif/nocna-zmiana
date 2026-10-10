"""Floor I ambience: the zones' room tones and their distant one-shots.

Imported by gen_ambience.py (same conventions: 40 s beds that are periodic
by construction - noise over the loop's own spectrum, tones at whole
cycles per loop, events wrapped around the loop - and mono one-shots with
their distance baked in). Every bed and shot has its own seed.

Beds (bed_<name>):
    glass_wind    wind over the court's great glass roof, panes singing, steel ticks
    city_hum      the city at night beyond the walls (mono)
    stone_deep    the low resonance of big stone halls (mono)
    sand_trickle  sand trickling from cracks
    crack_wind    wind whistling through cracks and doorways
    cedar_creak   cedar beams creaking overhead
    fire          a brazier / torches: roar, crackle, pops
    airy_hall     marble air: near silence with a soft high breath
    drips         far drips with long echoes
    clocks        many clocks ticking at their own rates
    library       a wooden library: warm room tone, pages, settling wood
    chimes        wind chimes (D minor pentatonic) in gusts
    garden        water from a bamboo spout, crickets under an open sky
    paper_rustle  paper lanterns stirring in a draft
    far_drums     slit drums and a big drum, far off, in phrases
    boiler        the basement's boiler: burner roar, pump, ticking pipes, gurgle
    roof_wind     wind on the roof: gusts, whistling stays, rattling panes
One-shots (oneshots/shot_<kind>_<n>): glass, sand, stone, beam, drip, page,
clock_strike, chimes, bamboo, bell, drum, ember, steam, pane, car.
"""
import numpy as np

import dsp
import instruments as ins
from dsp import SR, TAU, g_band, g_bell, g_highpass, g_lowpass, g_mul, g_peak

LOOP = 40.0
N = dsp.n_of(LOOP)


def lf(f):
    return max(round(f * LOOP), 1) / LOOP


def tone(f, phase=0.0):
    return np.sin(TAU * (lf(f) * np.arange(N) / SR + phase))


def gust(rng, rate=0.08, floor=0.25, power=2.0):
    """0..1 periodic gust curve."""
    return floor + (1.0 - floor) * (0.5 + 0.5 * dsp.wander(N, rng, rate)) ** power


def scatter(rng, count, make, pans=(-0.8, 0.8), gains=(0.5, 1.0), times=None):
    """A loop timeline with [param count] events from make() at random
    places (or at [param times] in s), wrapped around the loop."""
    tl = dsp.Timeline(samples=N)
    for k in range(count):
        at = dsp.n_of(times[k]) if times is not None else int(rng.uniform(0, N))
        tl.add(at, make(), rng.uniform(*gains), pan_pos=rng.uniform(*pans))
    return tl.buf


def room(x, rng, rt60, pre=0.02, dark=0.4, wet=0.5, early=10, span=0.04):
    ir = dsp.make_ir(rt60, rng, pre, rt60 * 1.2, dark, early=early, early_span=span)
    return x * (1.0 - wet) + dsp.convolve(x, ir, circular=True) * wet


def grain_stream(rng, seconds, density, lo=2500.0, hi=9000.0, length=0.002):
    """Tiny noise grains at [param density] per second (sand, paper)."""
    n = dsp.n_of(seconds)
    out = np.zeros(n)
    count = int(density * seconds)
    g_n = max(dsp.n_of(length), 8)
    for _ in range(count):
        at = int(rng.uniform(0, n - g_n))
        g = rng.standard_normal(g_n) * dsp.env_exp(g_n, length * 0.35, 0.0002)
        out[at:at + g_n] += g * rng.uniform(0.2, 1.0)
    return dsp.bandpass(out, lo, hi)


# --- beds ----------------------------------------------------------------------

def bed_glass_wind(rng):
    g = gust(rng, 0.07, 0.2)
    whoosh = dsp.noise(N, rng, g_mul(g_band(140.0, 1300.0, 1), dsp.pink), 2) * g[:, None]
    sing = np.zeros(N)
    for f, a in [(1870.0, 1.0), (2440.0, 0.7), (3150.0, 0.5), (1210.0, 0.4)]:
        band = dsp.noise(N, rng, g_peak(f, 60.0))
        sing += band * a
    sing *= (g ** 3) * 0.12
    ticks = scatter(rng, 9, lambda: dsp.partials(rng.uniform(2800.0, 5200.0), [1.0, 1.7, 2.9], [1.0, 0.5, 0.3],
                                                 [0.02, 0.012, 0.008], dsp.n_of(0.12), rng=rng), gains=(0.08, 0.25))
    far = room(np.stack([sing, sing * 0.85], 1) + ticks, rng, 4.5, 0.08, 0.35, 0.7)
    body = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(500.0, 1), g_highpass(30.0, 2)), 2) * 0.2
    return whoosh * 0.6 + far * 1.4 + body


def bed_city_hum(rng):
    rumble = dsp.noise(N, rng, g_mul(dsp.brown, g_band(28.0, 260.0, 2)))
    swells = np.zeros(N)
    for k in range(4):
        centre = rng.uniform(0, LOOP)
        width = rng.uniform(3.0, 6.0)
        t = (np.arange(N) / SR - centre + LOOP / 2) % LOOP - LOOP / 2
        swells += np.exp(-0.5 * (t / width) ** 2) * rng.uniform(0.5, 1.0)
    hiss = dsp.noise(N, rng, g_mul(g_band(350.0, 1600.0, 2), dsp.pink)) * (0.15 + swells)
    hum = (tone(50.0) * 0.15 + tone(100.0) * 0.08)
    return rumble * (0.8 + 0.2 * dsp.wander(N, rng, 0.05)) + hiss * 0.35 + hum


def bed_stone_deep(rng):
    modes = dsp.noise(N, rng, lambda f: g_peak(43.0, 9.0)(f) + 0.8 * g_peak(61.0, 10.0)(f) + 0.6 * g_peak(87.0, 11.0)(f)
                      + 0.3 * g_peak(129.0, 12.0)(f))
    breath = 0.6 + 0.4 * (0.5 + 0.5 * dsp.lfo(N, 2, 0.3))
    air = dsp.noise(N, rng, g_mul(dsp.brown, g_band(25.0, 300.0, 2))) * 0.4
    return modes * breath + air


def bed_sand_trickle(rng):
    tl = dsp.Timeline(samples=N)
    for k in range(7):
        seconds = rng.uniform(1.5, 4.5)
        stream = grain_stream(rng, seconds, rng.uniform(600.0, 1800.0), 2200.0, 8500.0, 0.0018)
        shape = dsp.env_ar(stream.shape[0], seconds * 0.3, seconds * 0.4)
        tl.add(int(rng.uniform(0, N)), stream * shape, rng.uniform(0.4, 1.0), pan_pos=rng.uniform(-0.8, 0.8))
    hiss = dsp.noise(N, rng, g_mul(g_band(2500.0, 8000.0, 1), dsp.pink), 2) * 0.04
    return room(tl.buf, rng, 1.8, 0.03, 0.4, 0.35) + hiss


def bed_crack_wind(rng):
    g = gust(rng, 0.09, 0.15, 2.5)
    out = np.zeros((N, 2))
    for k, (f, side) in enumerate([(640.0, -0.5), (910.0, 0.4), (1330.0, 0.1)]):
        wob = 1.0 + 0.04 * dsp.wander(N, rng, 0.15)
        # a whistle: narrow noise band whose centre wanders with the gust
        ph = np.cumsum(f * wob * (0.97 + 0.06 * g)) / SR
        cycles = ph[-1]
        ph *= round(cycles) / cycles
        whistle = np.sin(TAU * ph) * (0.6 + 0.4 * dsp.noise(N, rng, g_lowpass(30.0, 1)) * 0.3)
        gate = np.clip((g - (0.35 + 0.15 * k)) * 3.0, 0.0, 1.0) ** 2
        out += dsp.pan(whistle * gate * 0.05, side)
    rush = dsp.noise(N, rng, g_mul(g_band(300.0, 2500.0, 1), dsp.pink), 2) * g[:, None] * 0.5
    return room(out, rng, 2.5, 0.05, 0.35, 0.5) + rush


def creak_at(rng, seconds=None, low=False):
    seconds = seconds or rng.uniform(0.8, 2.2)
    n = dsp.n_of(seconds)
    t = np.arange(n) / SR
    rate = rng.uniform(12.0, 26.0) * (1.0 + rng.uniform(0.4, 1.2) * np.sin(np.pi * t / seconds) ** 2)
    phase = np.cumsum(rate) / SR
    pulses = np.zeros(n)
    idx = np.searchsorted(phase, np.arange(1, int(phase[-1])))
    pulses[idx[idx < n]] = rng.uniform(0.5, 1.0, np.sum(idx < n))
    f1 = rng.uniform(140.0, 220.0) if low else rng.uniform(260.0, 380.0)
    res = lambda f: (g_peak(f1, 7.0)(f) + 0.8 * g_peak(f1 * rng.uniform(2.2, 2.6), 9.0)(f)
                     + 0.4 * g_peak(f1 * rng.uniform(4.5, 5.5), 10.0)(f))
    return dsp.fft_filter(pulses + rng.standard_normal(n) * 0.01, res) * dsp.env_ar(n, 0.1, 0.3)


def bed_cedar_creak(rng):
    beams = scatter(rng, 9, lambda: creak_at(rng, low=rng.uniform() < 0.5), gains=(0.3, 1.0))
    settle = scatter(rng, 4, lambda: ins.tom(rng.uniform(90.0, 140.0), 0.4, rng)[:dsp.n_of(0.4)], gains=(0.1, 0.3))
    tone_ = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(600.0, 1), g_highpass(30.0, 2)), 2) * 0.02
    return room(beams * 40.0 + settle * 2.0, rng, 2.8, 0.04, 0.4, 0.55, early=14, span=0.06) + tone_


def bed_fire(rng):
    flicker = 0.7 + 0.3 * dsp.wander(N, rng, 1.5)
    roar = dsp.noise(N, rng, g_mul(dsp.brown, g_band(70.0, 700.0, 1)), 2) * flicker[:, None]
    tl = dsp.Timeline(samples=N)
    count = int(LOOP * 9)
    for _ in range(count):
        m = dsp.n_of(rng.uniform(0.002, 0.008))
        c = dsp.bandpass(rng.standard_normal(m), rng.uniform(1200.0, 3000.0), rng.uniform(4000.0, 9000.0)) * dsp.env_exp(m, 0.0015, 0.0002)
        tl.add(int(rng.uniform(0, N)), c, rng.uniform(0.1, 1.0) ** 2, pan_pos=rng.uniform(-0.6, 0.6))
    for _ in range(12):
        pop = ins.tom(rng.uniform(250.0, 600.0), 0.5, rng)[:dsp.n_of(0.12)] * 0.6
        pop = pop + dsp.pad_to(dsp.bandpass(rng.standard_normal(dsp.n_of(0.02)), 1500.0, 8000.0) * dsp.env_exp(dsp.n_of(0.02), 0.004), pop.shape[0])
        tl.add(int(rng.uniform(0, N)), pop, rng.uniform(0.4, 1.0), pan_pos=rng.uniform(-0.5, 0.5))
    hiss = dsp.noise(N, rng, g_mul(g_band(2000.0, 7000.0, 1), dsp.pink), 2) * 0.05 * flicker[:, None]
    return roar * 0.3 + room(tl.buf * 3.0, rng, 0.9, 0.01, 0.5, 0.25) + hiss * 2.0


def bed_airy_hall(rng):
    air = dsp.noise(N, rng, g_mul(g_band(1200.0, 9000.0, 1), dsp.pink), 2)
    breath = 0.7 + 0.3 * (0.5 + 0.5 * dsp.wander(N, rng, 0.04))
    low = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(250.0, 1), g_highpass(30.0, 2)), 2) * 0.6
    far = room(air * 0.4, rng, 5.0, 0.1, 0.6, 0.8)
    return far * breath[:, None] + low * 0.15


def drip(rng, f=None):
    """A water drop: a bubble ringing with a rising chirp."""
    f = f or rng.uniform(900.0, 2200.0)
    n = dsp.n_of(0.12)
    t = np.arange(n) / SR
    freq = f * (1.0 + 0.6 * t / t[-1])
    s = np.sin(TAU * np.cumsum(freq) / SR) * np.exp(-t / 0.025)
    return s + dsp.pad_to(dsp.bandpass(rng.standard_normal(dsp.n_of(0.004)), 2000.0, 9000.0) * 0.2, n)


def bed_drips(rng):
    tl = dsp.Timeline(samples=N)
    for source in range(3):
        period = LOOP / int(rng.integers(9, 18))
        f = rng.uniform(900.0, 2000.0)
        pan_ = rng.uniform(-0.8, 0.8)
        offset = rng.uniform(0, period)
        for k in range(int(round(LOOP / period))):
            if rng.uniform() < 0.15:
                continue
            at = dsp.n_of(offset + k * period + rng.normal(0, period * 0.05))
            tl.add(at, drip(rng, f * rng.uniform(0.95, 1.05)), rng.uniform(0.4, 1.0), pan_pos=pan_)
    tone_ = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(400.0, 1), g_highpass(30.0, 2)), 2) * 0.05
    return room(tl.buf * 2.0, rng, 4.0, 0.06, 0.35, 0.75) + tone_


def bed_clocks(rng):
    tl = dsp.Timeline(samples=N)
    # rate (Hz), level, pan, tock pitch: a longcase, two mantel clocks, a carriage clock
    for rate, level, pan_, low in [(0.5, 1.0, -0.6, True), (1.0, 0.75, 0.4, False), (2.0, 0.45, -0.2, False),
                                   (1.25, 0.5, 0.7, False), (4.0, 0.2, 0.1, False)]:
        takes = [ins.clock_tick(k % 2 == 1 or low, 0.8, rng) for k in range(6)]
        if low:
            takes = [dsp.fft_filter(x, g_lowpass(1800.0, 1)) for x in takes]
        count = int(round(LOOP * rate))
        offset = rng.uniform(0, 1.0 / rate)
        for k in range(count):
            at = dsp.n_of(offset + k / rate) + int(rng.normal(0, 0.001) * SR)
            tl.add(at, takes[k % 6], level * (1.0 if k % 2 == 0 else 0.85), pan_pos=pan_)
    tone_ = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(500.0, 1), g_highpass(30.0, 2)), 2) * 0.05
    return room(tl.buf, rng, 1.1, 0.01, 0.5, 0.35, early=14, span=0.03) + tone_


def page_rustle(rng, seconds=None):
    seconds = seconds or rng.uniform(0.3, 0.9)
    stream = grain_stream(rng, seconds, rng.uniform(250.0, 600.0), 900.0, 7000.0, 0.006)
    swish = dsp.bandpass(rng.standard_normal(stream.shape[0]), 600.0, 4000.0) * 0.15
    return (stream + swish) * dsp.env_ar(stream.shape[0], seconds * 0.2, seconds * 0.5)


def bed_library(rng):
    tone_ = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(450.0, 1), g_highpass(28.0, 2)), 2)
    pages = scatter(rng, 7, lambda: page_rustle(rng), gains=(0.15, 0.4))
    wood = scatter(rng, 4, lambda: creak_at(rng, rng.uniform(0.4, 0.9)), gains=(0.08, 0.2))
    return tone_ * 0.12 + room(pages * 2.5 + wood * 2.0, rng, 1.2, 0.015, 0.7, 0.4)


CHIME_NOTES = [74, 77, 79, 81, 84, 86]   # D5 F5 G5 A5 C6 D6


def chime(rng, midi=None, vel=0.8):
    f = float(dsp.hz(midi if midi is not None else int(rng.choice(CHIME_NOTES))))
    n = dsp.n_of(3.5)
    tone_ = dsp.partials(f, [1.0, 2.756, 5.404, 8.933], [1.0, 0.5, 0.25, 0.1], [1.6, 0.8, 0.35, 0.15], n, rng=rng)
    click = dsp.pad_to(dsp.bandpass(rng.standard_normal(dsp.n_of(0.003)), 3000.0, 10000.0) * 0.3, n)
    return dsp.fade_edges((tone_ + click) * vel, 0.0003, 0.2)


def bed_chimes(rng):
    tl = dsp.Timeline(samples=N)
    for k in range(5):
        t0 = rng.uniform(0, LOOP)
        for j in range(int(rng.integers(3, 9))):
            at = dsp.n_of(t0 + rng.uniform(0, 2.5))
            tl.add(at, chime(rng, vel=rng.uniform(0.3, 1.0)), 1.0, pan_pos=rng.uniform(-0.6, 0.6))
    for _ in range(4):
        tl.add(int(rng.uniform(0, N)), chime(rng, vel=rng.uniform(0.2, 0.4)), 1.0, pan_pos=rng.uniform(-0.6, 0.6))
    breeze = dsp.noise(N, rng, g_mul(g_band(400.0, 3000.0, 1), dsp.pink), 2) * gust(rng, 0.1)[:, None] * 0.05
    return room(tl.buf, rng, 2.2, 0.03, 0.45, 0.4) + breeze


def bed_garden(rng):
    tl = dsp.Timeline(samples=N)
    for _ in range(int(LOOP * 22)):
        tl.add(int(rng.uniform(0, N)), drip(rng, rng.uniform(500.0, 1600.0)) * 0.6, rng.uniform(0.1, 0.6),
               pan_pos=rng.uniform(-0.25, 0.05))
    water = dsp.noise(N, rng, g_mul(g_band(400.0, 5000.0, 1), dsp.pink), 2) * 0.06
    crickets = dsp.Timeline(samples=N)
    for c, (f, pan_) in enumerate([(4600.0, 0.6), (4950.0, -0.7), (4300.0, 0.3)]):
        m = dsp.n_of(0.012)
        pulse = np.sin(TAU * f * np.arange(m) / SR) * np.hanning(m)
        chirp = np.zeros(dsp.n_of(0.16))
        for p in range(4):
            at = dsp.n_of(p * 0.034)
            chirp[at:at + m] += pulse
        period = rng.uniform(0.55, 0.8)
        active = 0.5 + 0.5 * dsp.wander(N, rng, 0.03)
        t = 0.0
        while t < LOOP - 0.2:
            if active[dsp.n_of(t)] > 0.35:
                crickets.add(dsp.n_of(t), chirp, rng.uniform(0.6, 1.0), pan_pos=pan_)
            t += period * rng.uniform(0.97, 1.03)
    return room(tl.buf, rng, 0.8, 0.01, 0.5, 0.25) + water + room(crickets.buf, rng, 1.5, 0.02, 0.5, 0.3) * 0.25


def bed_paper_rustle(rng):
    g = gust(rng, 0.08, 0.1, 2.5)
    rustle = dsp.noise(N, rng, g_mul(g_band(800.0, 6000.0, 1), dsp.pink), 2)
    crinkle = scatter(rng, 18, lambda: page_rustle(rng, rng.uniform(0.15, 0.4)), gains=(0.1, 0.3))
    return (rustle * 0.15 * g[:, None] + crinkle * g[:, None] ** 0.5)


def bed_far_drums(rng):
    tl = dsp.Timeline(samples=N)
    for phrase_at in (rng.uniform(1.0, 3.0), rng.uniform(21.0, 24.0)):
        beat = 60.0 / rng.uniform(96.0, 112.0) / 2.0
        pattern = [("lo", 1.0), (None, 0), ("hi", 0.7), ("lo", 0.8), ("hi", 0.6), ("hi", 0.75)] * 6
        for k, (kind, v) in enumerate(pattern):
            at = dsp.n_of(phrase_at + k * beat)
            if kind:
                tl.add(at, ins.slit_drum(176.0 if kind == "lo" else 236.0, 0.8, rng), v * rng.uniform(0.85, 1.05), pan_pos=-0.3)
            if k % 6 == 0:
                tl.add(at, ins.big_drum(58.0, 0.9, rng, 1.4), 0.8, pan_pos=0.2)
    far = dsp.fft_filter(tl.buf, g_lowpass(1600.0, 1), circular=True)
    return room(far, rng, 4.5, 0.1, 0.3, 0.8)


def bed_boiler(rng):
    burner = dsp.noise(N, rng, g_mul(dsp.brown, g_band(55.0, 500.0, 2)), 2) * (0.75 + 0.25 * dsp.wander(N, rng, 0.8))[:, None]
    pump = tone(24.5) * 0.4 + tone(49.0) * 0.5 + tone(73.5) * 0.25 + tone(147.0) * 0.1
    pump = pump * (1.0 + 0.1 * np.sin(TAU * lf(1.5) * np.arange(N) / SR))
    ticks = scatter(rng, 26, lambda: dsp.partials(rng.uniform(700.0, 1600.0), [1.0, 2.4], [1.0, 0.4], [0.03, 0.01],
                                                  dsp.n_of(0.1), rng=rng), gains=(0.05, 0.25))
    gurgle = dsp.Timeline(samples=N)
    for _ in range(3):
        t0 = rng.uniform(0, LOOP)
        for j in range(int(rng.integers(10, 25))):
            gurgle.add(dsp.n_of(t0 + j * rng.uniform(0.04, 0.12)), drip(rng, rng.uniform(250.0, 600.0)), rng.uniform(0.1, 0.4),
                       pan_pos=0.5)
    knocks = scatter(rng, 3, lambda: ins.anvil(0.5, rng, rng.uniform(300.0, 450.0))[:dsp.n_of(0.6)], gains=(0.05, 0.15))
    return burner * 0.7 + np.stack([pump, pump * 0.9], 1) * 0.6 + room(ticks + gurgle.buf + knocks, rng, 1.2, 0.01, 0.2, 0.4)


def bed_roof_wind(rng):
    g = gust(rng, 0.12, 0.2, 2.0)
    wind = dsp.noise(N, rng, g_mul(g_band(90.0, 4000.0, 1), dsp.pink), 2) * g[:, None]
    stays = np.zeros(N)
    for f in (820.0, 1240.0):
        stays += dsp.noise(N, rng, g_peak(f, 80.0)) * 0.15
    stays *= g ** 3
    tl = dsp.Timeline(samples=N)
    for k in range(10):
        t0 = rng.uniform(0, LOOP)
        if g[dsp.n_of(t0) % N] < 0.5:
            continue
        rattle_n = dsp.n_of(rng.uniform(0.2, 0.6))
        rate = rng.uniform(13.0, 21.0)
        for j in range(int(rattle_n / SR * rate)):
            hit = dsp.partials(rng.uniform(1800.0, 3200.0), [1.0, 1.6, 2.7], [1.0, 0.6, 0.3], [0.02, 0.012, 0.006], dsp.n_of(0.06), rng=rng)
            hit = hit + dsp.pad_to(ins.tom(rng.uniform(180.0, 260.0), 0.3, rng)[:dsp.n_of(0.05)] * 0.5, hit.shape[0])
            tl.add(dsp.n_of(t0 + j / rate), hit, rng.uniform(0.3, 0.8), pan_pos=rng.uniform(-0.7, 0.7))
    return wind * 0.6 + np.stack([stays, stays * 0.8], 1) + tl.buf * 0.4


BEDS = {"glass_wind": bed_glass_wind, "city_hum": bed_city_hum, "stone_deep": bed_stone_deep, "sand_trickle": bed_sand_trickle,
        "crack_wind": bed_crack_wind, "cedar_creak": bed_cedar_creak, "fire": bed_fire, "airy_hall": bed_airy_hall,
        "drips": bed_drips, "clocks": bed_clocks, "library": bed_library, "chimes": bed_chimes, "garden": bed_garden,
        "paper_rustle": bed_paper_rustle, "far_drums": bed_far_drums, "boiler": bed_boiler, "roof_wind": bed_roof_wind}
MONO_BEDS = {"city_hum", "stone_deep"}
BED_LUFS = {"glass_wind": -33.0, "city_hum": -38.0, "stone_deep": -37.0, "sand_trickle": -37.0, "crack_wind": -35.0,
            "cedar_creak": -36.0, "fire": -34.0, "airy_hall": -40.0, "drips": -38.0, "clocks": -34.0, "library": -38.0,
            "chimes": -36.0, "garden": -34.0, "paper_rustle": -40.0, "far_drums": -36.0, "boiler": -32.0, "roof_wind": -30.0}


# --- one-shots -------------------------------------------------------------------

def far(x, rng, rt60=2.8, wet=0.7, cutoff=2200.0):
    ir = dsp.make_ir(rt60, rng, 0.05, rt60 * 1.1, 0.3)
    dry = dsp.fft_filter(x, g_lowpass(cutoff, 1))
    wet_sig = dsp.mono(dsp.convolve(dry, ir))
    out = dsp.pad_to(dry, wet_sig.shape[0]) * (1.0 - wet) + wet_sig * wet * 0.35
    return dsp.fade_edges(out, 0.001, 0.3)


def shot_glass(rng):
    n = dsp.n_of(1.6)
    out = np.zeros(n)
    for k in range(int(rng.integers(2, 6))):
        at = dsp.n_of(rng.uniform(0.0, 0.9))
        hit = dsp.partials(rng.uniform(2200.0, 4800.0), [1.0, 1.52, 2.4, 3.3], [1.0, 0.6, 0.4, 0.2], [0.08, 0.05, 0.03, 0.02],
                           dsp.n_of(0.4), rng=rng)
        out[at:at + hit.shape[0]] += hit[:n - at] * rng.uniform(0.3, 1.0)
    out += dsp.pad_to(creak_at(rng, 0.6) * 0.3, n)
    return far(out, rng, 4.0, 0.7, 7000.0)


def shot_sand(rng):
    seconds = rng.uniform(1.5, 3.0)
    stream = grain_stream(rng, seconds, rng.uniform(1500.0, 3000.0), 1800.0, 8000.0, 0.002)
    shape = dsp.env_ar(stream.shape[0], 0.2, seconds * 0.6) * (0.6 + 0.4 * np.linspace(1, 0, stream.shape[0]))
    return far(stream * shape, rng, 2.2, 0.5, 9000.0)


def shot_stone(rng):
    n = dsp.n_of(2.0)
    t = np.arange(n) / SR
    grind_len = dsp.n_of(rng.uniform(0.6, 1.2))
    grind = dsp.bandpass(rng.standard_normal(grind_len), 120.0, 1400.0) * (0.6 + 0.4 * np.abs(np.sin(TAU * rng.uniform(7.0, 13.0)
                                                                                                   * np.arange(grind_len) / SR)))
    grind *= dsp.env_ar(grind_len, 0.15, 0.2)
    out = np.zeros(n)
    out[:grind_len] += grind
    clack = ins.big_drum(rng.uniform(80.0, 120.0), 0.8, rng, 0.6)[:dsp.n_of(0.6)]
    at = grind_len
    out[at:at + clack.shape[0]] += clack[:n - at] * 0.8
    del t
    return far(out, rng, 3.0, 0.7, 1800.0)


def shot_beam(rng):
    return far(creak_at(rng, rng.uniform(1.4, 2.4), low=True) * 1.5, rng, 2.8, 0.6, 2500.0)


def shot_drip(rng):
    out = dsp.pad_to(drip(rng), dsp.n_of(0.3))
    if rng.uniform() < 0.6:
        second = drip(rng)
        at = dsp.n_of(rng.uniform(0.08, 0.2))
        out[at:at + second.shape[0]] += second[:out.shape[0] - at] * 0.5
    return far(out, rng, 4.5, 0.8, 6000.0)


def shot_page(rng):
    out = page_rustle(rng, rng.uniform(0.6, 1.2))
    if rng.uniform() < 0.5:   # and the book falls over
        thud = ins.big_drum(rng.uniform(110.0, 150.0), 0.6, rng, 0.4)[:dsp.n_of(0.4)]
        out = np.concatenate([out, thud * 0.8])
    return far(out, rng, 1.6, 0.5, 6000.0)


def shot_clock_strike(rng, k=0):
    """A clock somewhere strikes: a few bell strokes (or, once, a cuckoo)."""
    if k == 2:
        n = dsp.n_of(2.0)
        out = np.zeros(n)
        for j in range(2):
            for i, f in enumerate((800.0, 640.0)):
                m = dsp.n_of(0.22)
                tt = np.arange(m) / SR
                coo = np.sin(TAU * f * tt) * dsp.env_ar(m, 0.02, 0.12) + 0.2 * np.sin(TAU * 2 * f * tt) * dsp.env_ar(m, 0.02, 0.1)
                at = dsp.n_of(j * 0.7 + i * 0.26)
                out[at:at + m] += coo
        return far(dsp.fft_filter(out, g_band(400.0, 3000.0, 1)), rng, 1.6, 0.5, 5000.0)
    strokes = int(rng.integers(2, 5))
    n = dsp.n_of(strokes * 1.2 + 2.5)
    out = np.zeros(n)
    pitch = rng.uniform(70.0, 80.0)
    for j in range(strokes):
        b = ins.church_bell(pitch, 0.7, rng, length=2.5)
        at = dsp.n_of(j * 1.2)
        out[at:at + b.shape[0]] += b[:n - at]
    return far(out, rng, 2.2, 0.55, 5000.0)


def shot_chimes(rng):
    n = dsp.n_of(3.5)
    out = np.zeros(n)
    for j in range(int(rng.integers(5, 11))):
        c = chime(rng, vel=rng.uniform(0.3, 1.0))
        at = dsp.n_of(rng.uniform(0.0, 1.6))
        out[at:at + c.shape[0]] += c[:n - at]
    return far(out, rng, 1.8, 0.4, 9000.0)


def shot_bamboo(rng):
    """Shishi-odoshi: water fills the bamboo arm, it tips and clacks back
    against the stone."""
    n = dsp.n_of(1.8)
    out = np.zeros(n)
    pour = grain_stream(rng, 0.5, 900.0, 600.0, 4000.0, 0.004) * 0.3
    out[:pour.shape[0]] += pour
    clack = dsp.partials(rng.uniform(520.0, 640.0), [1.0, 2.3, 3.9], [1.0, 0.5, 0.2], [0.09, 0.04, 0.02], dsp.n_of(0.5), rng=rng)
    clack += dsp.pad_to(dsp.bandpass(rng.standard_normal(dsp.n_of(0.01)), 800.0, 5000.0) * 0.6, clack.shape[0])
    at = dsp.n_of(0.55)
    out[at:at + clack.shape[0]] += clack[:n - at]
    return far(out, rng, 1.4, 0.35, 8000.0)


def shot_bell(rng):
    """A temple bell (bonsho), struck once with a log, far away."""
    f = rng.uniform(55.0, 70.0)
    n = dsp.n_of(7.0)
    tone_ = dsp.partials(f, [1.0, 2.0, 2.52, 3.05, 4.1, 5.4], [1.0, 0.6, 0.4, 0.3, 0.15, 0.08],
                         [6.0, 4.0, 2.5, 1.8, 1.0, 0.6], n, rng=rng, detune_cents=3.0)
    thud = dsp.pad_to(ins.big_drum(f * 1.3, 0.6, rng, 0.5), n) * 0.3
    return far(tone_ + thud, rng, 3.0, 0.5, 2000.0)


def shot_drum(rng):
    n = dsp.n_of(3.0)
    out = np.zeros(n)
    beat = rng.uniform(0.16, 0.22)
    for k, (kind, v) in enumerate([("lo", 1.0), ("hi", 0.7), ("hi", 0.6), ("lo", 0.9), (None, 0), ("lo", 0.8), ("hi", 0.6),
                                   ("lo", 1.0)][:int(rng.integers(4, 9))]):
        if kind:
            d = ins.slit_drum(176.0 if kind == "lo" else 236.0, v, rng)
            at = dsp.n_of(k * beat)
            out[at:at + d.shape[0]] += d[:n - at]
    return far(out, rng, 3.5, 0.75, 1500.0)


def shot_ember(rng):
    n = dsp.n_of(1.0)
    out = np.zeros(n)
    pop = ins.tom(rng.uniform(300.0, 500.0), 0.8, rng)[:dsp.n_of(0.15)]
    out[:pop.shape[0]] += pop
    for _ in range(int(rng.integers(10, 30))):
        m = dsp.n_of(0.004)
        c = dsp.bandpass(rng.standard_normal(m), 1500.0, 8000.0) * dsp.env_exp(m, 0.001)
        at = dsp.n_of(rng.uniform(0.0, 0.8) ** 2)
        out[at:at + m] += c * rng.uniform(0.2, 0.8)
    return far(out, rng, 1.0, 0.3, 9000.0)


def shot_steam(rng):
    seconds = rng.uniform(1.0, 2.2)
    n = dsp.n_of(seconds)
    hiss = dsp.bandpass(rng.standard_normal(n), 1500.0, 9000.0) * dsp.env_ar(n, 0.05, seconds * 0.6)
    valve = dsp.pad_to(ins.clock_tick(True, 1.0, rng), n) * 0.5
    return far(hiss + valve, rng, 1.6, 0.5, 9000.0)


def shot_pane(rng):
    n = dsp.n_of(1.2)
    out = np.zeros(n)
    rate = rng.uniform(12.0, 20.0)
    for j in range(int(rng.integers(5, 12))):
        hit = dsp.partials(rng.uniform(1800.0, 3000.0), [1.0, 1.6, 2.7], [1.0, 0.6, 0.3], [0.03, 0.015, 0.008], dsp.n_of(0.08), rng=rng)
        hit += dsp.pad_to(ins.tom(rng.uniform(170.0, 240.0), 0.4, rng)[:dsp.n_of(0.06)] * 0.6, hit.shape[0])
        at = dsp.n_of(j / rate)
        out[at:at + hit.shape[0]] += hit[:n - at] * rng.uniform(0.5, 1.0)
    return far(out, rng, 1.5, 0.4, 7000.0)


def shot_car(rng):
    """A car passing on the street outside: tyres and an engine swelling
    and fading behind the walls."""
    seconds = rng.uniform(4.0, 6.0)
    n = dsp.n_of(seconds)
    t = np.arange(n) / SR
    swell = np.exp(-0.5 * ((t - seconds * 0.5) / (seconds * 0.18)) ** 2)
    tyres = dsp.bandpass(rng.standard_normal(n), 300.0, 2500.0) * swell
    f = rng.uniform(32.0, 42.0) * (1.0 + 0.06 * np.tanh((seconds * 0.5 - t) * 2.0))
    engine = np.sin(TAU * np.cumsum(f) / SR) + 0.5 * np.sin(TAU * 2 * np.cumsum(f) / SR)
    return far(tyres * 0.5 + engine * swell * 0.4, rng, 1.8, 0.4, 1200.0)


SHOTS = {
    "glass": (3, shot_glass), "sand": (3, shot_sand), "stone": (3, shot_stone), "beam": (2, shot_beam), "drip": (3, shot_drip),
    "page": (3, shot_page), "clock_strike": (3, shot_clock_strike), "chimes": (2, shot_chimes), "bamboo": (2, shot_bamboo),
    "bell": (2, shot_bell), "drum": (3, shot_drum), "ember": (2, shot_ember), "steam": (2, shot_steam), "pane": (2, shot_pane),
    "car": (2, shot_car),
}
SHOT_PEAK_DB = {"glass": -8.0, "sand": -8.0, "stone": -5.0, "beam": -6.0, "drip": -9.0, "page": -8.0, "clock_strike": -6.0,
                "chimes": -8.0, "bamboo": -6.0, "bell": -5.0, "drum": -6.0, "ember": -7.0, "steam": -8.0, "pane": -7.0,
                "car": -6.0}
