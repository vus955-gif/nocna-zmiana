"""Procedural ambience of Nocna Zmiana: room-tone layers and one-shots.

WAV intermediates go to build/audio_src/ambience/ (gitignored);
tools/music/encode_ogg.py encodes them to assets/ambience/ as Ogg Vorbis.

Beds (bed_<layer>, stereo or mono, 40 s loops): every layer is
periodic by construction (noise synthesised over the loop's own spectrum,
tones at whole cycles per loop, modulation at whole cycles or periodic
random curves), so a loop has no seam. The Ambience autoload mixes layers
per zone:
    hall_air      big airy room tone + wind in the skylights
    gallery_room  quiet room tone (galleries, small rooms)
    mains_hum     faint 50 Hz electrical hum (electric)
    fluorescent   tube buzz at 100 Hz with its ballast rattle (electric)
    cctv          monitor whine, fans, a hard drive now and then (electric)
    clock         the security room's wall clock (tick-tock, 1 Hz)
    hvac          air handling in the corridors (electric)
    dread         blackout: sub rumble, a beating low drone, groans
Electric layers go silent in a blackout; dread comes in.

One-shots (oneshots/shot_<kind>_<n>, mono): distant
thuds, wood creaks, far doors, falling objects, pipe knocks, glass
tinkles, metal groans and far footsteps, each with the space baked in
(they are heard from far away), placed in 3D around the listener.

Floor I's zones add their own beds and one-shots (ambience_floor1.py).
The ambient story's sounds and the rain beds come from ambience_story.py
('story'), the room tails of shots and blasts from acoustics_tails.py ('tails').

    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/music/gen_ambience.py [name ...]
    (names of beds or one-shot kinds; 'floor1' = all of Floor I's; 'story' = the ambient story's
    sounds and rain; 'tails' = the room tails; none = everything)
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import acoustics_tails  # noqa: E402
import ambience_floor1 as floor1  # noqa: E402
import ambience_story as story  # noqa: E402
import analyze  # noqa: E402
import dsp  # noqa: E402
import instruments as ins  # noqa: E402
from dsp import SR, TAU, db, g_band, g_bell, g_highpass, g_lowpass, g_mul, g_peak  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
# WAV intermediates (never committed); encode_ogg.py turns them into assets/ambience/**/*.ogg
OUT = ROOT / "build" / "audio_src" / "ambience"
LOOP = 40.0
N = dsp.n_of(LOOP)

# beds with no real stereo image (electrical hums) are written mono: half the size
MONO_BEDS = {"mains_hum", "fluorescent", "cctv"}
# integrated loudness of each bed file (the zone mix adds its own gains)
BED_LUFS = {"hall_air": -31.0, "gallery_room": -37.0, "mains_hum": -41.0, "fluorescent": -34.0, "cctv": -38.0,
            "clock": -35.0, "hvac": -32.0, "dread": -31.0}


def lf(f):
    """Loop-periodic frequency."""
    return max(round(f * LOOP), 1) / LOOP


def tone(f, phase=0.0):
    return np.sin(TAU * (lf(f) * np.arange(N) / SR + phase))


def cyc(k, phase=0.0):
    return dsp.lfo(N, k, phase)


def bed_hall_air(rng):
    room = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(1400.0, 1), g_highpass(35.0, 2)), 2)
    body = dsp.noise(N, rng, g_mul(g_band(90.0, 500.0, 1), dsp.pink), 2) * 0.5
    gust = 0.25 + 0.75 * (0.5 + 0.5 * dsp.wander(N, rng, 0.08)) ** 2
    wind = dsp.noise(N, rng, g_mul(g_band(260.0, 1500.0, 2), dsp.pink), 2) * gust[:, None]
    whistle_f = 760.0 + 70.0 * dsp.wander(N, rng, 0.05)
    cycles = whistle_f.sum() / SR
    whistle_f *= round(cycles) / cycles   # a whole number of cycles per loop: periodic
    phase = np.cumsum(whistle_f) / SR
    whistle = (np.sin(TAU * phase) + 0.25 * np.sin(TAU * 2.0 * phase)) * (gust ** 2) * 0.05
    far = dsp.convolve(wind * 0.6 + np.stack([whistle, whistle * 0.8], 1), dsp.make_ir(4.5, rng, 0.06, 5.0, 0.3), circular=True)
    return room * 0.5 + body * 0.35 + far * 0.8 + wind * 0.15


def bed_gallery_room(rng):
    room = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(700.0, 1), g_highpass(30.0, 2)), 2)
    hiss = dsp.noise(N, rng, g_mul(dsp.pink, g_band(1500.0, 7000.0, 1)), 2) * 0.05
    breath = 0.8 + 0.2 * cyc(3, 0.2)
    return (room + hiss) * breath[:, None]


def bed_mains_hum(rng):
    hum = sum(a * tone(50.0 * k, rng.uniform()) for k, a in [(1, 1.0), (2, 0.6), (3, 0.45), (4, 0.2), (5, 0.18), (7, 0.08)])
    wobble = 1.0 + 0.08 * dsp.wander(N, rng, 0.3)
    hum = hum * wobble
    return np.stack([hum, hum * 0.9], 1)


def bed_fluorescent(rng):
    t = np.arange(N) / SR
    # ballast buzz: a raspy, nearly square 100 Hz (magnetostriction), mostly heard in the mids
    base = np.tanh(7.0 * np.sin(TAU * lf(100.0) * t)) + 0.4 * np.abs(np.sin(TAU * lf(50.0) * t))
    buzz = dsp.fft_filter(base - base.mean(), g_mul(g_highpass(350.0, 2), g_bell(2400.0, 6.0, 1.0), g_lowpass(7000.0, 2)),
                          circular=True)
    buzz /= dsp.rms(buzz)
    rattle = dsp.fft_filter(np.sign(np.sin(TAU * lf(100.0) * t)) * 0.3, g_band(3000.0, 9000.0, 2), circular=True)
    hum = tone(100.0) * 0.8 + tone(200.0) * 0.3
    flicker = np.ones(N)
    for _ in range(3):   # a tube fighting to stay lit
        at = int(rng.uniform(0.1, 0.9) * N)
        span = dsp.n_of(rng.uniform(0.15, 0.4))
        dip = 1.0 - 0.6 * np.abs(np.sin(np.linspace(0, np.pi * rng.integers(3, 7), span)))
        flicker[at:at + span] *= dip[:flicker[at:at + span].shape[0]]
    whine = tone(11800.0) * 0.015
    mono_bed = (buzz * 0.5 + rattle * 0.15 + hum * 0.2 + whine) * flicker
    return np.stack([mono_bed, dsp.fft_filter(mono_bed, g_lowpass(6000.0, 1), circular=True) * 0.9], 1)


def bed_cctv(rng):
    t = np.arange(N) / SR
    whine = tone(15625.0) * 0.02 + tone(15625.0 * 0.5) * 0.004
    hum = tone(50.0) * 0.3 + tone(100.0) * 0.5 + tone(150.0) * 0.15
    blade = lf(23.0)
    fan_am = 1.0 + 0.25 * np.sin(TAU * blade * t)
    fan = dsp.noise(N, rng, g_mul(g_band(700.0, 3200.0, 2), dsp.pink)) * fan_am * 0.4
    fan += (tone(blade * 7) * 0.2 + tone(blade * 14) * 0.08)
    drive = np.zeros(N)
    for _ in range(9):   # a recorder's disk seeking now and then
        at = int(rng.uniform(0, 1) * (N - SR))
        for k in range(int(rng.integers(3, 9))):
            click = dsp.n_of(rng.uniform(0.004, 0.02)) * k
            seg = dsp.bandpass(rng.standard_normal(dsp.n_of(0.004)), 1500.0, 7000.0) * dsp.env_exp(dsp.n_of(0.004), 0.001)
            drive[at + click:at + click + seg.shape[0]] += seg * 0.25
    left = whine + hum * 0.4 + fan + drive
    right = whine * 0.8 + hum * 0.4 + fan * 0.8 + drive * 0.5
    return np.stack([left, right], 1)


def bed_clock(rng):
    out = dsp.Timeline(samples=N)
    ticks = [ins.clock_tick(k % 2 == 1, 0.8, rng) for k in range(8)]
    for sec in range(int(LOOP)):
        out.add(dsp.n_of(sec) + int(rng.normal(0, 0.0015) * SR), ticks[sec % 8], 1.0 if sec % 2 == 0 else 0.85, pan_pos=0.35)
    room = dsp.make_ir(0.5, rng, 0.004, 0.8, 0.5, early=10, early_span=0.02, early_gain=0.7)
    return out.buf * 0.8 + dsp.convolve(out.buf, room, circular=True) * 0.35


def bed_hvac(rng):
    rumble = dsp.noise(N, rng, g_mul(dsp.brown, g_lowpass(260.0, 2), g_highpass(25.0, 2)), 2)
    duct = dsp.noise(N, rng, lambda f: g_peak(86.0, 6.0)(f) + 0.6 * g_peak(172.0, 8.0)(f) + 0.3 * g_peak(344.0, 9.0)(f), 2) * 0.5
    blade = lf(9.25)
    t = np.arange(N) / SR
    fan = (tone(blade * 12) * 0.3 + tone(blade * 24) * 0.12) * (1.0 + 0.1 * np.sin(TAU * blade * t))
    grille = dsp.noise(N, rng, g_mul(g_band(900.0, 5000.0, 1), dsp.pink), 2) * 0.12
    surge = 0.85 + 0.15 * cyc(2, 0.3)
    return (rumble * 0.8 + duct + grille + fan[:, None] * 0.4) * surge[:, None]


def bed_dread(rng):
    sub = dsp.noise(N, rng, g_mul(g_band(18.0, 75.0, 2), dsp.brown), 2)
    swell = 0.35 + 0.65 * (0.5 + 0.5 * dsp.wander(N, rng, 0.05)) ** 2
    drone = tone(36.71) * 0.5 + tone(38.89, 0.3) * 0.45 + tone(73.42) * 0.12   # D1 against Eb1: a slow sour beat
    groans = np.zeros(N)
    for _ in range(3):
        at = int(rng.uniform(0, 1) * N)
        length = dsp.n_of(rng.uniform(2.5, 4.5))
        f0 = rng.uniform(55.0, 90.0)
        glide = f0 * (1.0 + 0.35 * np.sin(np.linspace(0, np.pi, length)) * rng.choice([-1, 1]) * 0.5)
        g = np.sin(TAU * np.cumsum(glide) / SR) + 0.4 * np.sin(TAU * 2.03 * np.cumsum(glide) / SR)
        g = dsp.fft_filter(g, g_mul(g_peak(f0 * 2.0, 3.0), g_lowpass(500.0, 1))) * dsp.env_ar(length, 1.0, 1.5)
        idx = (at + np.arange(length)) % N
        groans[idx] += g * 0.5
    breath_env = (0.5 + 0.5 * cyc(6, 0.1)) ** 3
    breath = dsp.noise(N, rng, g_mul(g_band(250.0, 900.0, 2), dsp.pink), 2) * breath_env[:, None] * 0.25
    far = dsp.convolve(np.stack([groans, groans * 0.7], 1), dsp.make_ir(4.0, rng, 0.05, 4.5, 0.3), circular=True)
    return sub * swell[:, None] * 0.3 + np.stack([drone, drone], 1) * 0.2 + far * 1.2 + breath * 2.0


BEDS = {"hall_air": bed_hall_air, "gallery_room": bed_gallery_room, "mains_hum": bed_mains_hum,
        "fluorescent": bed_fluorescent, "cctv": bed_cctv, "clock": bed_clock, "hvac": bed_hvac, "dread": bed_dread}


# --- one-shots ------------------------------------------------------------

def far_space(x, rng, rt60=2.8, wet=0.7, cutoff=2200.0):
    """Distance: darker, a big late reverb, little direct sound."""
    ir = dsp.make_ir(rt60, rng, 0.05, rt60 * 1.1, 0.3)
    dry = dsp.fft_filter(x, g_lowpass(cutoff, 1))
    wet_sig = dsp.mono(dsp.convolve(dry, ir))
    out = dsp.pad_to(dry, wet_sig.shape[0]) * (1.0 - wet) + wet_sig * wet * 0.35
    return dsp.fade_edges(out, 0.001, 0.3)


def shot_thud(rng):
    body = ins.big_drum(rng.uniform(38.0, 60.0), 1.0, rng, 1.2)
    debris = np.zeros(dsp.n_of(1.2))
    for _ in range(int(rng.integers(0, 6))):
        at = dsp.n_of(rng.uniform(0.05, 0.6))
        k = ins.tom(rng.uniform(300.0, 700.0), rng.uniform(0.1, 0.3), rng)[:dsp.n_of(0.3)]
        debris[at:at + k.shape[0]] += k[:debris.shape[0] - at]
    return far_space(body + debris * 0.5, rng, 3.0, 0.75, 1200.0)


def creak(rng, seconds=None):
    """Stick-slip wood: an irregular pulse train through board resonances."""
    seconds = seconds or rng.uniform(0.6, 1.6)
    n = dsp.n_of(seconds)
    t = np.arange(n) / SR
    rate = rng.uniform(18.0, 35.0) * (1.0 + rng.uniform(0.5, 1.5) * np.sin(np.pi * t / seconds) ** 2)
    rate *= 1.0 + 0.15 * np.sin(TAU * rng.uniform(1.5, 4.0) * t)
    phase = np.cumsum(rate) / SR
    pulses = np.zeros(n)
    idx = np.searchsorted(phase, np.arange(1, int(phase[-1])))
    pulses[idx[idx < n]] = rng.uniform(0.5, 1.0, np.sum(idx < n))
    res = lambda f: (g_peak(rng.uniform(280, 380), 7.0)(f) + 0.8 * g_peak(rng.uniform(650, 900), 9.0)(f)
                     + 0.5 * g_peak(rng.uniform(1300, 1900), 10.0)(f))
    body = dsp.fft_filter(pulses + dsp.bandpass(rng.standard_normal(n), 400.0, 3000.0) * 0.02, res)
    return body * dsp.env_ar(n, 0.08, 0.2)


def shot_creak(rng):
    return far_space(creak(rng), rng, 1.6, 0.45, 4500.0)


def shot_door(rng, kind):
    n = dsp.n_of(2.0)
    out = np.zeros(n)
    if kind == 0:   # latch and slam
        latch = ins.clock_tick(True, 1.0, rng)
        out[:latch.shape[0]] += latch * 0.6
        slam = ins.big_drum(rng.uniform(70.0, 95.0), 1.0, rng, 1.0)
        at = dsp.n_of(0.12)
        out[at:at + slam.shape[0]] += slam[:n - at]
    elif kind == 1:   # hinge squeal, then a soft close
        length = dsp.n_of(1.1)
        t = np.arange(length) / SR
        f = rng.uniform(700.0, 1000.0) * (1.0 + 0.4 * t / t[-1]) * (1.0 + 0.03 * np.sin(TAU * 9.0 * t))
        ph = np.cumsum(f) / SR
        squeal = (np.sin(TAU * ph) + 0.5 * np.sin(TAU * 2 * ph) + 0.25 * np.sin(TAU * 3 * ph)) * dsp.env_ar(length, 0.15, 0.3)
        squeal *= 0.6 + 0.4 * np.abs(np.sin(TAU * 13.0 * t))
        out[:length] += squeal * 0.25 + creak(rng, 1.1)[:length] * 0.5
        close = ins.big_drum(110.0, 0.5, rng, 0.8)
        at = dsp.n_of(1.25)
        out[at:at + close.shape[0]] += close[:n - at] * 0.7
    else:   # something heavy shut far away
        slam = ins.big_drum(rng.uniform(50.0, 65.0), 1.0, rng, 1.6)
        out[:slam.shape[0]] += slam[:n]
    return far_space(out, rng, 3.2, 0.8, 1600.0)


def shot_fall(rng, kind):
    n = dsp.n_of(1.6)
    out = np.zeros(n)
    at = 0.0
    gap = rng.uniform(0.12, 0.2)
    level = 1.0
    for k in range(int(rng.integers(4, 8))):
        if kind == 0:   # a tin can / a bucket
            hit = ins.anvil(level, rng, rng.uniform(500.0, 900.0))[:dsp.n_of(0.6)]
        elif kind == 1:   # a wooden block tumbling
            hit = ins.tom(rng.uniform(380.0, 520.0), level, rng)[:dsp.n_of(0.3)]
        elif kind == 2:   # a book or a frame, flat on the floor
            hit = ins.big_drum(rng.uniform(90.0, 140.0), level, rng, 0.5)
            if k > 0:
                break
        else:   # porcelain
            hit = ins.xylophone(rng.uniform(88.0, 100.0), level, rng)
        i = dsp.n_of(at)
        if i + hit.shape[0] > n:
            break
        out[i:i + hit.shape[0]] += hit
        at += gap
        gap *= rng.uniform(0.55, 0.75)
        level *= rng.uniform(0.45, 0.7)
    return far_space(out, rng, 2.4, 0.6, 3500.0)


def shot_pipe(rng):
    n = dsp.n_of(1.8)
    out = np.zeros(n)
    at = 0.0
    f = rng.uniform(260.0, 420.0)
    for k in range(int(rng.integers(3, 6))):
        hit = ins.anvil(rng.uniform(0.5, 1.0), rng, f * rng.uniform(0.97, 1.03))[:dsp.n_of(0.5)]
        i = dsp.n_of(at)
        out[i:i + hit.shape[0]] += hit[:n - i]
        at += rng.uniform(0.12, 0.35)
    return far_space(dsp.lowpass(out, 2500.0), rng, 2.0, 0.55, 3000.0)


def shot_tinkle(rng):
    n = dsp.n_of(1.2)
    out = np.zeros(n)
    for k in range(int(rng.integers(3, 7))):
        f = rng.uniform(2500.0, 5500.0)
        hit = dsp.partials(f, [1.0, 2.32, 4.25], [1.0, 0.5, 0.25], [0.12, 0.06, 0.03], dsp.n_of(0.4), rng=rng)
        i = dsp.n_of(rng.uniform(0.0, 0.5))
        out[i:i + hit.shape[0]] += hit * rng.uniform(0.3, 1.0)
    return far_space(out, rng, 1.8, 0.5, 8000.0)


def shot_groan(rng):
    length = dsp.n_of(rng.uniform(2.0, 3.2))
    t = np.arange(length) / SR
    f0 = rng.uniform(70.0, 120.0)
    glide = f0 * (1.0 - 0.25 * t / t[-1]) * (1.0 + 0.02 * np.sin(TAU * 5.0 * t))
    ph = np.cumsum(glide) / SR
    g = sum(a * np.sin(TAU * k * ph + rng.uniform(0, TAU)) for k, a in [(1, 1.0), (2.03, 0.6), (3.1, 0.4), (4.4, 0.25), (6.2, 0.15)])
    g *= 0.6 + 0.4 * (0.5 + 0.5 * np.sin(TAU * rng.uniform(6.0, 11.0) * t))
    g = dsp.fft_filter(g, g_mul(g_peak(f0 * 3.0, 2.0), g_lowpass(1200.0, 1))) * dsp.env_ar(length, 0.6, 0.9)
    return far_space(g, rng, 3.5, 0.7, 1200.0)


def shot_steps(rng):
    """Footsteps far away that are not the guard's."""
    n = dsp.n_of(3.2)
    out = np.zeros(n)
    at = rng.uniform(0.0, 0.2)
    for k in range(int(rng.integers(4, 7))):
        heel = ins.tom(rng.uniform(140.0, 190.0), 0.6, rng)[:dsp.n_of(0.2)]
        click = dsp.bandpass(rng.standard_normal(dsp.n_of(0.01)), 1500.0, 6000.0) * dsp.env_exp(dsp.n_of(0.01), 0.002)
        i = dsp.n_of(at)
        out[i:i + heel.shape[0]] += heel * 0.8
        out[i:i + click.shape[0]] += click * 0.5
        at += rng.uniform(0.48, 0.62)
    return far_space(out, rng, 3.0, 0.75, 1800.0)


SHOTS = {
    "thud": (4, shot_thud),
    "creak": (5, shot_creak),
    "door": (3, lambda rng, k: shot_door(rng, k)),
    "fall": (4, lambda rng, k: shot_fall(rng, k)),
    "pipe": (2, shot_pipe),
    "tinkle": (2, shot_tinkle),
    "groan": (2, shot_groan),
    "steps": (2, shot_steps),
}
SHOT_PEAK_DB = {"thud": -4.0, "creak": -6.0, "door": -4.0, "fall": -5.0, "pipe": -6.0, "tinkle": -9.0, "groan": -5.0,
                "steps": -6.0}


def main(names=()):
    dsp.intermediates_dir(ROOT)
    beds = dict(BEDS, **floor1.BEDS, **story.BEDS)
    mono_beds = MONO_BEDS | floor1.MONO_BEDS | story.MONO_BEDS
    bed_lufs = dict(BED_LUFS, **floor1.BED_LUFS, **story.BED_LUFS)
    shots = dict(SHOTS, **floor1.SHOTS, **story.SHOTS)
    peaks = dict(SHOT_PEAK_DB, **floor1.SHOT_PEAK_DB, **story.SHOT_PEAK_DB)

    def wanted(name, floor1_set, story_set):
        return (not names or name in names or ("floor1" in names and name in floor1_set)
                or ("story" in names and name in story_set))
    for name, make in beds.items():
        if not wanted(name, floor1.BEDS, story.BEDS):
            continue
        rng = np.random.default_rng(sum(map(ord, name)) * 7919)
        x = dsp.stereo(make(rng))
        x = x - x.mean(axis=0)
        x = x * db(bed_lufs[name] - dsp.lufs(x, circular=True))
        x = dsp.limit(x, -6.0)
        x = dsp.rotate(x, dsp.seam_rotation(x))   # file edges away from a tick or a knock
        path = OUT / f"bed_{name}.wav"
        dsp.write_wav(path, x, np.random.default_rng(1), channels=1 if name in mono_beds else None)
        print(analyze.format_report(analyze.report(dsp.read_wav(path), path.name, True)))
    for kind, (count, make) in shots.items():
        if not wanted(kind, floor1.SHOTS, story.SHOTS):
            continue
        for k in range(count):
            rng = np.random.default_rng(sum(map(ord, kind)) * 104729 + k)
            try:
                x = make(rng, k)
            except TypeError:
                x = make(rng)
            x = dsp.mono(x)
            x = x - x.mean()
            x = dsp.fade_edges(x, 0.001, 0.2) * db(peaks[kind]) / max(dsp.peak(x), 1e-9)
            path = OUT / "oneshots" / f"shot_{kind}_{k + 1}.wav"
            dsp.write_wav(path, x, np.random.default_rng(2), channels=1)
            print(f"  {path.name:<22} {x.shape[0] / SR:5.2f} s  peak {dsp.to_db(dsp.peak(x)):5.1f} dBFS")
    if not names or "tails" in names:
        acoustics_tails.main(names)


if __name__ == "__main__":
    main(sys.argv[1:])
