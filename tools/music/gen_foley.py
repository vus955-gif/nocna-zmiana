"""Procedural footsteps and body foley for Nocna Zmiana.

Writes mono 44.1 kHz WAVs to assets/sfx/steps/ (dry: rooms add their
reverb in the game). Several takes per set; the Footsteps node picks them
in turn and jitters the pitch.

    step_<surface>_<n>   the guard's leather-soled shoes: heel then toe
                         (stone = marble / stone / concrete, wood, carpet, metal)
    land_<surface>_<n>   both feet after a jump or a drop
    jump_<n>             push-off: scuff and a cloth swish
    gear_<n>             the key ring on the guard's belt (running)
    wax_<n>              a wax figure's sticky, heavy shuffle
    wolf_<n>             a stuffed wolf's pads with claws ticking (hard floors)
    wolf_soft_<n>        the same pads on carpet
    knight_<n>           an armour's sabaton: a heavy boot and plates clanking
    raptor_<n>           a raptor skeleton: bone knock and claw ticks

    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/music/gen_foley.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dsp  # noqa: E402
import instruments as ins  # noqa: E402
from dsp import SR, db, g_band, g_bell, g_highpass, g_lowpass, g_mul, g_peak  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sfx" / "steps"


def burst(rng, seconds, lo, hi, tau, attack=0.0005):
    n = dsp.n_of(seconds)
    return dsp.bandpass(rng.standard_normal(n), lo, hi) * dsp.env_exp(n, tau, attack)


def place(out, at, sig, gain=1.0):
    i = dsp.n_of(at)
    end = min(out.shape[0], i + sig.shape[0])
    out[i:end] += sig[:end - i] * gain


def contact(rng, surface, force):
    """One impact of a sole on a surface (force 0..1)."""
    n = dsp.n_of(0.35)
    out = np.zeros(n)
    if surface == "stone":
        place(out, 0.0, burst(rng, 0.02, 1800.0, 9000.0, 0.0015), 0.8 * force)
        place(out, 0.0, dsp.lowpass(rng.standard_normal(dsp.n_of(0.06)), 700.0) * dsp.env_exp(dsp.n_of(0.06), 0.012), 0.9 * force)
        ring = dsp.partials(rng.uniform(2600.0, 3400.0), [1.0, 1.6], [1.0, 0.5], [0.02, 0.012], dsp.n_of(0.08), rng=rng)
        place(out, 0.0, ring, 0.08 * force)
    elif surface == "wood":
        knock = dsp.fft_filter(rng.standard_normal(dsp.n_of(0.12)) * dsp.env_exp(dsp.n_of(0.12), 0.01),
                               lambda f: g_peak(rng.uniform(190, 250), 5.0)(f) + 0.7 * g_peak(rng.uniform(420, 520), 6.0)(f)
                               + 0.25 * g_band(900.0, 3000.0, 1)(f))
        place(out, 0.0, knock, 1.4 * force)
        place(out, 0.0, burst(rng, 0.01, 1500.0, 6000.0, 0.0012), 0.35 * force)
    elif surface == "carpet":
        thud = dsp.lowpass(rng.standard_normal(dsp.n_of(0.1)), 500.0) * dsp.env_ar(dsp.n_of(0.1), 0.006, 0.08)
        place(out, 0.0, thud, 1.0 * force)
        place(out, 0.005, burst(rng, 0.06, 1000.0, 4000.0, 0.02, 0.01), 0.08 * force)
    elif surface == "metal":
        clang = dsp.partials(rng.uniform(550.0, 800.0), [1.0, 2.31, 3.7, 5.2, 6.9], [1.0, 0.8, 0.6, 0.4, 0.25],
                             [0.09, 0.06, 0.04, 0.03, 0.02], dsp.n_of(0.3), rng=rng)
        place(out, 0.0, clang, 0.35 * force)
        place(out, 0.0, burst(rng, 0.015, 2000.0, 9000.0, 0.002), 0.5 * force)
        place(out, 0.0, dsp.lowpass(rng.standard_normal(dsp.n_of(0.05)), 400.0) * dsp.env_exp(dsp.n_of(0.05), 0.01), 0.7 * force)
        for k in range(int(rng.integers(2, 4))):   # the grate rattles in its frame
            place(out, rng.uniform(0.02, 0.07), burst(rng, 0.01, 1500.0, 6000.0, 0.002), 0.25 * force)
    return out


def step(rng, surface, heavy=1.0):
    n = dsp.n_of(0.45)
    out = np.zeros(n)
    place(out, 0.0, contact(rng, surface, 0.95 * heavy))
    place(out, rng.uniform(0.035, 0.07), contact(rng, surface, 0.5 * heavy))           # toe
    if surface != "carpet":
        place(out, rng.uniform(0.07, 0.11), burst(rng, 0.05, 2000.0, 7000.0, 0.012, 0.004), 0.06)   # scuff
    if surface == "wood" and rng.random() < 0.35:
        from gen_ambience import creak
        place(out, 0.05, dsp.highpass(creak(rng, rng.uniform(0.18, 0.3)), 250.0), 0.12)
    return out


def land(rng, surface):
    n = dsp.n_of(0.6)
    out = np.zeros(n)
    place(out, 0.0, contact(rng, surface, 1.0))
    place(out, rng.uniform(0.012, 0.03), contact(rng, surface, 0.85))
    place(out, 0.0, dsp.lowpass(rng.standard_normal(dsp.n_of(0.15)), 250.0) * dsp.env_exp(dsp.n_of(0.15), 0.035), 1.2)
    place(out, 0.01, jingle(rng, 0.12, 5), 0.12)
    place(out, 0.0, swish(rng, 0.12), 0.25)
    return out


def swish(rng, seconds):
    n = dsp.n_of(seconds)
    return dsp.bandpass(rng.standard_normal(n), 500.0, 3500.0, 1) * dsp.env_ar(n, seconds * 0.4, seconds * 0.55)


def jingle(rng, seconds, count):
    n = dsp.n_of(seconds + 0.1)
    out = np.zeros(n)
    for _ in range(count):
        f = rng.uniform(3200.0, 6500.0)
        hit = dsp.partials(f, [1.0, 1.52, 2.8], [1.0, 0.6, 0.3], [0.05, 0.03, 0.015], dsp.n_of(0.1), rng=rng)
        place(out, rng.uniform(0.0, seconds), hit, rng.uniform(0.3, 1.0))
    return out


def jump(rng):
    n = dsp.n_of(0.3)
    out = np.zeros(n)
    place(out, 0.0, burst(rng, 0.06, 1500.0, 6000.0, 0.015, 0.003), 0.3)
    place(out, 0.0, contact(rng, "carpet", 0.5), 0.8)
    place(out, 0.02, swish(rng, 0.2), 0.6)
    place(out, 0.03, jingle(rng, 0.1, 4), 0.1)
    return out


def wax(rng):
    """Heavy, soft and sticky: a slow drag, a thump, the peel of a sole."""
    n = dsp.n_of(0.6)
    out = np.zeros(n)
    drag_n = dsp.n_of(rng.uniform(0.22, 0.32))
    drag = dsp.bandpass(rng.standard_normal(drag_n), 200.0, 1800.0, 1) * dsp.env_ar(drag_n, 0.07, 0.1)
    place(out, 0.0, drag, 0.35)
    thud = dsp.lowpass(rng.standard_normal(dsp.n_of(0.12)), 300.0) * dsp.env_ar(dsp.n_of(0.12), 0.01, 0.1)
    place(out, 0.06, thud, 1.0)
    peel = dsp.fft_filter(rng.standard_normal(dsp.n_of(0.03)) * dsp.env_exp(dsp.n_of(0.03), 0.003), g_peak(rng.uniform(1200, 1800), 4.0))
    place(out, rng.uniform(0.18, 0.28), peel, 0.25)
    return out


def wolf(rng, claws=True):
    n = dsp.n_of(0.3)
    out = np.zeros(n)
    pad = dsp.lowpass(rng.standard_normal(dsp.n_of(0.05)), 450.0) * dsp.env_ar(dsp.n_of(0.05), 0.004, 0.04)
    place(out, 0.0, pad, 0.8)
    place(out, rng.uniform(0.01, 0.03), pad[::-1] * 0.5, 0.5)   # the other paw
    if claws:
        for k in range(int(rng.integers(1, 4))):
            click = burst(rng, 0.006, 3000.0, 9000.0, 0.0008)
            place(out, rng.uniform(0.0, 0.035), click, rng.uniform(0.3, 0.6))
    else:
        place(out, 0.0, burst(rng, 0.03, 800.0, 3000.0, 0.008, 0.003), 0.05)
    return out


def knight(rng):
    n = dsp.n_of(0.55)
    out = np.zeros(n)
    boot = dsp.lowpass(rng.standard_normal(dsp.n_of(0.12)), 400.0) * dsp.env_exp(dsp.n_of(0.12), 0.03)
    place(out, 0.0, boot, 1.0)
    place(out, 0.0, contact(rng, "stone", 0.7), 0.6)
    for k in range(int(rng.integers(3, 6))):   # plates knocking against each other
        f = rng.uniform(900.0, 2600.0)
        plate = dsp.partials(f, [1.0, 1.41, 2.2, 3.1], [1.0, 0.7, 0.4, 0.25], [0.12, 0.08, 0.05, 0.03], dsp.n_of(0.25), rng=rng)
        place(out, rng.uniform(0.0, 0.07), plate, rng.uniform(0.12, 0.3))
    place(out, 0.01, jingle(rng, 0.15, 12) * 0.5, 0.25)   # mail
    return out


def raptor(rng):
    """A raptor skeleton's foot: a dry bone knock, two claws ticking, little
    body (it is all bones)."""
    n = dsp.n_of(0.25)
    out = np.zeros(n)
    knock = dsp.fft_filter(rng.standard_normal(dsp.n_of(0.05)) * dsp.env_exp(dsp.n_of(0.05), 0.006),
                           lambda f: g_peak(rng.uniform(900, 1300), 6.0)(f) + 0.6 * g_peak(rng.uniform(1900, 2600), 8.0)(f))
    place(out, 0.0, knock, 1.0)
    for k in range(2):
        place(out, rng.uniform(0.004, 0.03), burst(rng, 0.005, 3500.0, 10000.0, 0.0007), rng.uniform(0.35, 0.6))
    place(out, 0.0, dsp.lowpass(rng.standard_normal(dsp.n_of(0.04)), 500.0) * dsp.env_exp(dsp.n_of(0.04), 0.008), 0.35)
    return out


SETS = {
    # name: (count, maker, peak dBFS)
    "step_stone": (6, lambda r: step(r, "stone"), -3.0),
    "step_wood": (6, lambda r: step(r, "wood"), -3.0),
    "step_carpet": (6, lambda r: step(r, "carpet"), -9.0),
    "step_metal": (6, lambda r: step(r, "metal"), -2.0),
    "land_stone": (2, lambda r: land(r, "stone"), -1.0),
    "land_wood": (2, lambda r: land(r, "wood"), -1.0),
    "land_carpet": (2, lambda r: land(r, "carpet"), -5.0),
    "land_metal": (2, lambda r: land(r, "metal"), -1.0),
    "jump": (2, jump, -8.0),
    "gear": (4, lambda r: jingle(r, 0.12, 6), -12.0),
    "wax": (5, wax, -4.0),
    "wolf": (6, lambda r: wolf(r, True), -6.0),
    "wolf_soft": (4, lambda r: wolf(r, False), -9.0),
    "knight": (6, knight, -2.0),
    "raptor": (6, raptor, -5.0),
}


def main():
    for name, (count, make, peak_db) in SETS.items():
        for k in range(count):
            rng = np.random.default_rng(sum(map(ord, name)) * 7907 + k)
            x = make(rng)
            x = x - x.mean()
            x = dsp.fft_filter(x, g_highpass(40.0, 2))
            last = np.nonzero(np.abs(x) > dsp.peak(x) * 1e-3)[0]
            x = x[:last[-1] + dsp.n_of(0.01)] if last.size else x
            x = dsp.fade_edges(x, 0.0003, 0.02) * db(peak_db) / max(dsp.peak(x), 1e-9)
            path = OUT / f"{name}_{k + 1}.wav"
            dsp.write_wav(path, x, np.random.default_rng(3), channels=1)
        print(f"  {name:<12} x{count}  {x.shape[0] / SR:5.2f} s")


if __name__ == "__main__":
    main()
