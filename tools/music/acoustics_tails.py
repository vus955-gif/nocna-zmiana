"""Room tails of shots and blasts (plan docs/superpowers/plans/2026-10-21-akustyka-ambient.md).

A shot in the game is two layers started together: the weapon's own dry
sound (assets/sfx, unchanged) and the tail of the room it rings in - "this
room after a bang", rendered here: an excitation of the bang's class
convolved with a synthetic impulse response of the room's acoustic profile,
the wet part only (the direct sound is the dry layer).

The profiles live in data/audio/acoustics.json (the game reads the same
file: reverb buses, how loud each tail plays). Per profile the "tail" block:
    rt60          reverberation time of the mid band (s)
    predelay_ms   gap between the bang and the first reflection
    early, early_ms, early_gain   first reflections: how many, over which span, how strong
    dark          share of the RT left to the highs (books and plaster soak them, glass does not)
    low           RT of the lows against the mids
    build_ms      how long the diffuse tail takes to swell
    flutter_ms, flutter_gain      flutter echo between parallel walls (galleries, corridors)
    echoes_ms, echo_gain          discrete echoes (the garden's far walls, the buildings across the street)
    modes_hz, modes_gain          resonances that ring on (a boxy storeroom, steel plates and pipes)

Classes (excitations): crack (pistol, rifle, harpoon, gatling), boom
(shotgun, flare gun, hwacha, a slammed door, a heavy thud) and blast (the
flare's burst, the guardians' slams, a wall coming down).

Output: build/audio_src/ambience/tails/tail_<profile>_<class>.wav (stereo,
16 bit; encode_ogg.py -> assets/ambience/tails/*.ogg). Every tail is
normalised to the same momentary loudness (TAIL_MOMENTARY, 400 ms blocks);
how loud it plays in the game is the profile's tail_db plus the sound's own
dB in the data file. Deterministic: the seed comes from the profile and class.

    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/music/gen_ambience.py tails
"""
import json
import zlib
from pathlib import Path

import numpy as np

import dsp
from dsp import SR, TAU, g_band, g_lowpass, g_mul, g_peak

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "audio" / "acoustics.json"
CLASSES = ("crack", "boom", "blast")
# momentary loudness (max over 400 ms blocks) of every tail file, LUFS
TAIL_MOMENTARY = -16.0
# true-peak ceiling of a tail file, dBFS
TAIL_CEILING = -1.5
# a tail ends where its envelope falls this far under its loudest moment
TAIL_FLOOR_DB = -62.0


def load_profiles(path=DATA):
    with open(path, encoding="utf-8") as f:
        return json.load(f)["profiles"]


def seed_of(*names):
    return zlib.crc32("|".join(names).encode("utf-8"))


# --- excitations -----------------------------------------------------------------

def _thump(n, f_start, f_end, tau, rng):
    """A low body thump: a sine falling in pitch, decaying."""
    t = np.arange(n) / SR
    f = f_end + (f_start - f_end) * np.exp(-t / (tau * 0.6))
    return np.sin(TAU * np.cumsum(f) / SR + rng.uniform(0, TAU)) * np.exp(-t / tau)


def excitation(kind, rng):
    """The bang that sets the room ringing (mono, peak 1)."""
    if kind == "crack":
        n = dsp.n_of(0.08)
        burst = dsp.bandpass(rng.standard_normal(n), 300.0, 9000.0) * dsp.env_exp(n, 0.0014, 0.0001)
        snap = dsp.highpass(rng.standard_normal(n), 2500.0) * dsp.env_exp(n, 0.0004, 0.00005)
        x = burst + snap * 0.5 + _thump(n, 140.0, 70.0, 0.016, rng) * 0.45
    elif kind == "boom":
        n = dsp.n_of(0.2)
        burst = dsp.lowpass(rng.standard_normal(n), 4200.0) * dsp.env_exp(n, 0.006, 0.0003)
        x = burst + _thump(n, 90.0, 45.0, 0.045, rng) * 0.9
    elif kind == "blast":
        n = dsp.n_of(0.6)
        rumble = dsp.lowpass(rng.standard_normal(n), 1800.0) * dsp.env_exp(n, 0.06, 0.002)
        crackle = np.zeros(n)
        for _ in range(28):   # debris and the fireball's crackle
            at = int(rng.uniform(0.0, 0.3) * SR)
            m = dsp.n_of(rng.uniform(0.002, 0.008))
            crackle[at:at + m] += dsp.bandpass(rng.standard_normal(m), 900.0, 7000.0) * dsp.env_exp(m, m / SR * 0.3) * rng.uniform(0.2, 0.8)
        x = rumble + crackle * 0.35 + _thump(n, 55.0, 26.0, 0.13, rng) * 1.1
    else:
        raise ValueError(f"unknown tail class {kind}")
    x = x - x.mean()
    return x / max(dsp.peak(x), 1e-12)


# --- the room ----------------------------------------------------------------------

def room_ir(tail, rng):
    """Wet stereo impulse response of a profile's 'tail' block: no direct
    sound, the first reflections after the predelay, a diffuse tail decaying
    per band, flutter, echoes and ringing modes as the profile asks. Unit
    energy per channel (before the extras)."""
    rt60 = float(tail["rt60"])
    pre = float(tail["predelay_ms"]) / 1000.0
    echoes = [float(e) / 1000.0 for e in tail.get("echoes_ms", [])]
    length = pre + rt60 * 1.35 + (max(echoes) * 1.6 if echoes else 0.0) + 0.05
    size = dsp.n_of(length)
    t = np.arange(size) / SR
    dark = float(tail.get("dark", 0.45))
    low = float(tail.get("low", 1.1))
    bands = [(20.0, 300.0, rt60 * low), (300.0, 2500.0, rt60), (2500.0, 7000.0, rt60 * (0.5 + dark * 0.5)),
             (7000.0, 20000.0, rt60 * max(dark, 0.08))]
    build = max(float(tail.get("build_ms", 15.0)) / 1000.0, 0.001)
    d0 = dsp.n_of(pre)
    e_lo, e_hi = (float(v) / 1000.0 for v in tail.get("early_ms", [2.0, 30.0]))
    ir = np.zeros((size, 2))
    for ch in range(2):
        white = rng.standard_normal(size)
        late = np.zeros(size)
        for lo, hi, rt in bands:
            late += dsp.fft_filter(white, g_band(lo, hi, 2)) * np.exp(-6.9078 * t / rt)
        late *= 1.0 - np.exp(-t / build)
        late = late / max(dsp.rms(late), 1e-12) * 0.02
        taps = np.zeros(size)
        for _ in range(int(tail.get("early", 10))):
            at = dsp.n_of(rng.uniform(e_lo, e_hi))
            if at < size:
                fall = np.exp(-6.9078 * (at / SR) / rt60)
                taps[at] += rng.choice([-1.0, 1.0]) * float(tail.get("early_gain", 0.5)) * fall * rng.uniform(0.55, 1.0)
        taps = dsp.fft_filter(taps, g_lowpass(3500.0 + 6000.0 * dark, 1))
        flutter_ms = float(tail.get("flutter_ms", 0.0))
        if flutter_ms > 0.0:
            # a flutter echo: the bang running back and forth between two parallel walls
            # (each pass a short burst: the wall smears it a little)
            period = flutter_ms / 1000.0
            train = np.zeros(size)
            burst_n = dsp.n_of(0.0025)
            # (strength against the diffuse tail's first moments: a flutter you hear)
            late_level = dsp.rms(late[dsp.n_of(0.01):dsp.n_of(0.06)])
            k = 1
            while k * period < rt60 * 0.8:
                at = dsp.n_of(k * period + rng.normal(0.0, 0.00025))
                if at + burst_n < size:
                    level = float(tail["flutter_gain"]) * late_level * 30.0 * np.exp(-6.9078 * k * period / (rt60 * 0.7))
                    train[at:at + burst_n] += rng.standard_normal(burst_n) * dsp.env_exp(burst_n, 0.0008, 0.0001) * level
                k += 1
            taps += dsp.fft_filter(train, g_band(350.0, 6500.0, 1))
        body = late + taps
        for k, delay in enumerate(echoes):
            # an echo off a far wall (ms after the bang): late, darker the farther, smeared a little
            at = max(dsp.n_of(delay - pre + rng.normal(0.0, 0.0015)), 0)
            m = dsp.n_of(0.03)
            smear = rng.standard_normal(m) * dsp.env_exp(m, 0.006, 0.0005)
            smear = dsp.fft_filter(smear, g_lowpass(max(3200.0 - 650.0 * k, 800.0), 2))
            smear = smear / max(dsp.peak(smear), 1e-12) * float(tail.get("echo_gain", 0.4)) * (0.72 ** k)
            end = min(at + m, size)
            body[at:end] += smear[:end - at] * (1.0 if ch == k % 2 else 0.8)
        modes = tail.get("modes_hz", [])
        if modes:
            # resonances that ring on (plates, pipes, a box of a room)
            ring = np.zeros(size)
            for f in modes:
                rt = rt60 * (0.85 if f > 400.0 else 1.0)
                for detune in (0.997, 1.003):
                    ring += np.sin(TAU * f * detune * t + rng.uniform(0, TAU)) * np.exp(-6.9078 * t / rt) * rng.uniform(0.5, 1.0)
            ring *= 1.0 - np.exp(-t / 0.004)
            ring = ring / max(dsp.rms(ring), 1e-12) * dsp.rms(late) * float(tail.get("modes_gain", 0.3)) * 2.0
            body += ring
        ir[d0:, ch] = body[:size - d0]
    ir /= np.sqrt(np.mean(np.sum(ir ** 2, axis=0)))
    return ir


def momentary_max(x):
    """Loudest 400 ms block (LUFS)."""
    z = dsp.loudness_blocks(x, block=0.4, overlap=0.75)
    return float(-0.691 + 10.0 * np.log10(np.max(z))) if z.size else -120.0


def trim(x, floor_db=TAIL_FLOOR_DB):
    """Cuts the tail where its 20 ms envelope stays under floor_db (relative
    to its loudest window) for good, then fades the last 150 ms."""
    x = dsp.stereo(x)
    w = dsp.n_of(0.02)
    power = np.sum(x ** 2, axis=1)
    c = np.concatenate([[0.0], np.cumsum(power)])
    env = (c[w:] - c[:-w]) / w
    top = np.max(env)
    loud = np.nonzero(env > top * 10.0 ** (floor_db / 10.0))[0]
    end = min(int(loud[-1]) + w if loud.size else x.shape[0], x.shape[0])
    return dsp.fade_edges(x[:end], 0.0005, 0.15)


def render_tail(profile_id, tail, kind):
    """The tail of [param kind] in a room of profile [param profile_id]
    (stereo, normalised to TAIL_MOMENTARY, under TAIL_CEILING)."""
    rng = np.random.default_rng(seed_of("tail", profile_id, kind))
    x = dsp.convolve(excitation(kind, rng), room_ir(tail, rng), cross=0.2)
    x = trim(x - x.mean(axis=0))
    x = x * dsp.db(TAIL_MOMENTARY - momentary_max(x))
    over = dsp.true_peak(x) - TAIL_CEILING
    if over > 0.0:
        x = x * dsp.db(-over)
    return x


def decay_time(x, lo=500.0, hi=2000.0, start_db=-5.0, end_db=-25.0):
    """Reverberation time from Schroeder's backward integration of the
    band [lo, hi]: the slope between start_db and end_db, extrapolated to
    -60 dB (T20 when -5..-25)."""
    m = dsp.mono(x)
    band = dsp.bandpass(m, lo, hi, 4)
    edc = np.cumsum(band[::-1] ** 2)[::-1]
    edc_db = 10.0 * np.log10(np.maximum(edc / edc[0], 1e-30))
    a = int(np.argmax(edc_db <= start_db))
    b = int(np.argmax(edc_db <= end_db))
    if b <= a:
        return 0.0
    t = np.arange(a, b) / SR
    slope = np.polyfit(t, edc_db[a:b], 1)[0]
    return -60.0 / slope if slope < 0 else 0.0


def onset(x, below_db=-40.0):
    """Seconds until the signal first rises within below_db of its peak."""
    m = np.max(np.abs(dsp.stereo(x)), axis=1)
    return int(np.argmax(m > np.max(m) * 10.0 ** (below_db / 20.0))) / SR


def main(names=()):
    out = dsp.intermediates_dir(ROOT) / "ambience" / "tails"
    profiles = load_profiles()
    for profile_id, prof in profiles.items():
        if names and profile_id not in names and "tails" not in names:
            continue
        for kind in CLASSES:
            x = render_tail(profile_id, prof["tail"], kind)
            path = out / f"tail_{profile_id}_{kind}.wav"
            dsp.write_wav(path, x, np.random.default_rng(3))
            print(f"  {path.name:<26} {x.shape[0] / SR:5.2f} s  mom-max {momentary_max(x):6.1f} LUFS  "
                  f"tp {dsp.true_peak(x):5.1f} dBFS  T20 {decay_time(x):4.2f} s (rt60 {prof['tail']['rt60']})  "
                  f"onset {onset(x) * 1000:5.1f} ms")
