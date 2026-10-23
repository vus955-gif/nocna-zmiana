"""Procedural sound effects for Nocna Zmiana (stages 1a, 2a, 2c-1, lobby world and the content pass).

Writes 16-bit mono WAV files to assets/sfx/. Standard library only. The
random generator is re-seeded with each sound's name, so every run produces
the same files and adding a sound never changes the existing ones. Every
file peaks at PEAK, then LEVELS turns some down so the mix reads right: the
guard's weapons loudest, cues (enemy notice, pickup) clearly below them.
Run from the repo root (names after the script: only those sounds):

    python tools/sfx/gen_sfx.py [name ...]

Floor I's locks, creatures and guardians come from floor1_sfx.py (numpy;
Blender's Python has it): python tools/sfx/gen_sfx.py floor1
Names must match Sfx.SOUNDS in src/fx/sfx.gd (the lobby world's sounds:
WorldSounds.NAMES in src/world/world_sounds.gd; the dawn's birds:
Ambience.DAWN_BIRDS in src/audio/ambience.gd).
"""
import math
import random
import sys
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "assets" / "sfx"
PEAK = 0.9   # about -0.9 dBFS
rng = random.Random()


def n(seconds):
    return max(int(seconds * RATE), 1)


def noise(length):
    return [rng.uniform(-1.0, 1.0) for _ in range(length)]


def lowpass(samples, cutoff):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    return [x - low for x, low in zip(samples, lowpass(samples, cutoff))]


def env_exp(length, decay, attack=0.002):
    """Quick attack, exponential decay (decay = time constant in seconds)."""
    a = n(attack)
    return [min(i / a, 1.0) * math.exp(-i / (decay * RATE)) for i in range(length)]


def env_hump(length, peak=0.4):
    """Rise to a peak (fraction of the length), then fall to zero."""
    p = max(int(length * peak), 1)
    return [i / p if i < p else max(0.0, 1.0 - (i - p) / max(length - p, 1)) for i in range(length)]


def sweep(length, f0, f1, shape="sine"):
    """Oscillator gliding exponentially from f0 to f1 Hz."""
    out, phase = [], 0.0
    for i in range(length):
        f = f0 * (f1 / f0) ** (i / length)
        phase += 2.0 * math.pi * f / RATE
        if shape == "sine":
            out.append(math.sin(phase))
        elif shape == "square":
            out.append(1.0 if math.sin(phase) >= 0.0 else -1.0)
        else:
            out.append((phase / math.pi) % 2.0 - 1.0)
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def mix(*layers):
    """Sum (samples, gain) layers of any lengths."""
    out = [0.0] * max(len(s) for s, _ in layers)
    for s, g in layers:
        for i, x in enumerate(s):
            out[i] += x * g
    return out


def delay(samples, seconds):
    return [0.0] * n(seconds) + samples


def fade_out(samples, seconds=0.005):
    """Ramp the tail to silence, so a sound cut short doesn't click."""
    out = list(samples)
    length = min(n(seconds), len(out))
    for i in range(length):
        out[-1 - i] *= i / length
    return out


def drive(samples, amount):
    """Soft saturation: squashes the peaks so the body of a shot hits harder."""
    loudest = max(abs(x) for x in samples) or 1.0
    return [math.tanh(amount * x / loudest) for x in samples]


def echo(samples, seconds=0.07, feedback=0.3, taps=3):
    """Cheap room: a few decaying repeats."""
    d = n(seconds)
    out = samples + [0.0] * (d * taps)
    for t in range(1, taps + 1):
        g = feedback ** t
        for i, x in enumerate(samples):
            out[i + d * t] += x * g
    return out


def grains(seconds, count, make):
    """Scatter short sounds over a time span (crumbling, clatter)."""
    out = [0.0] * n(seconds)
    for _ in range(count):
        g = make()
        start = rng.randint(0, max(len(out) - len(g), 0))
        for i, x in enumerate(g):
            if start + i < len(out):
                out[start + i] += x
    return out


# --- building blocks -------------------------------------------------------

def thump(seconds, f0, f1, decay):
    length = n(seconds)
    return mul(sweep(length, f0, f1), env_exp(length, decay))


def crack(seconds, cutoff, decay):
    length = n(seconds)
    return mul(highpass(noise(length), cutoff), env_exp(length, decay, 0.0005))


def rumble(seconds, cutoff, decay):
    length = n(seconds)
    return mul(lowpass(noise(length), cutoff), env_exp(length, decay))


def clang(seconds, freqs, decay):
    length = n(seconds)
    tone = mix(*[(sweep(length, f, f * 0.995), 1.0 / (k + 1)) for k, f in enumerate(freqs)])
    return mul(tone, env_exp(length, decay, 0.0005))


def whoosh(seconds, low, high, peak=0.4):
    length = n(seconds)
    return mul(lowpass(highpass(noise(length), low), high), env_hump(length, peak))


def blip(seconds, freq):
    length = n(seconds)
    return fade_out(mul(sweep(length, freq, freq), env_exp(length, seconds * 0.5)))


def taser():
    length = n(0.35)
    buzz = sweep(length, 95, 85, "square")
    hiss = highpass(noise(length), 3000)
    gate, level, step = [], 1.0, n(0.006)
    for i in range(length):
        if i % step == 0:
            level = rng.choice([0.25, 0.6, 1.0])
        gate.append(level)
    return drive(mul(mix((buzz, 0.45), (hiss, 0.55)), mul(gate, env_exp(length, 0.25))), 2.0)


def growl():
    length = n(0.6)
    wobble = [0.6 + 0.4 * math.sin(2.0 * math.pi * 28.0 * i / RATE) for i in range(length)]
    return mul(mul(lowpass(noise(length), 420), wobble), env_hump(length, 0.3))


def hurt():
    length = n(0.3)
    voice = lowpass(mul(sweep(length, 220, 140, "saw"), env_exp(length, 0.12)), 900)
    return mix((thump(0.3, 90, 40, 0.1), 1.0), (voice, 0.5))


def notice():
    length = n(0.45)
    return mul(mix((sweep(length, 180, 420), 1.0), (sweep(length, 360, 840), 0.3)), env_hump(length, 0.7))


def bell(seconds, freq, decay):
    """Soft glassy bell: a sine with two inharmonic partials."""
    return clang(seconds, [freq, freq * 2.76, freq * 5.4], decay)


def dust():
    """A small magic chime: two bell notes a fifth apart and a sparkle."""
    sparkle = grains(0.3, 6, lambda: blip(0.025, rng.uniform(3500, 5500)))
    return mix((bell(0.5, 1568, 0.12), 1.0), (delay(bell(0.45, 2349, 0.1), 0.045), 0.7), (sparkle, 0.12))


def lantern():
    """Warm and reassuring: a rising arpeggio over a soft thump."""
    notes = [(523, 0.0), (659, 0.07), (784, 0.14), (1047, 0.21)]
    layers = [(delay(bell(0.7, f, 0.2), t), 0.8) for f, t in notes]
    return mix((thump(0.3, 140, 70, 0.08), 0.6), *layers)


def buy():
    """Till-like: a mechanical clack, then a bright two-note bell."""
    clack = mix((crack(0.03, 2500, 0.006), 1.0), (thump(0.08, 300, 120, 0.02), 0.6))
    return echo(mix((clack, 0.9), (delay(bell(0.6, 1319, 0.14), 0.05), 0.8), (delay(bell(0.6, 1976, 0.14), 0.12), 0.7)), 0.09, 0.2, 2)


def deny():
    """Two short low buzzes."""
    length = n(0.11)
    buzz = lowpass(mul(sweep(length, 150, 140, "square"), env_exp(length, 0.08, 0.004)), 1600)
    return mix((buzz, 1.0), (delay(buzz, 0.14), 1.0))


def alarm():
    """An old wind-up alarm clock: a hammer rattling on two bells, twice."""
    length = n(0.75)
    tone = mix((sweep(length, 2350, 2350), 1.0), (sweep(length, 3170, 3170), 0.6), (sweep(length, 4620, 4620), 0.3))
    rattle = [0.35 + 0.65 * max(0.0, math.sin(2.0 * math.pi * 21.0 * i / RATE)) ** 3 for i in range(length)]
    ring = mul(mul(tone, rattle), env_hump(length, 0.08))
    return mix((ring, 1.0), (delay(ring, 0.95), 1.0))


# --- stage 2c-1: marble bust and the T-Rex skeleton ------------------------

def bandpass(samples, low, high):
    return lowpass(highpass(samples, low), high)


def osc(length, freq_at, shape="saw"):
    """Oscillator whose frequency follows freq_at(t) (t = seconds)."""
    out, phase = [], 0.0
    for i in range(length):
        phase += 2.0 * math.pi * freq_at(i / RATE) / RATE
        if shape == "sine":
            out.append(math.sin(phase))
        else:
            out.append((phase / math.pi) % 2.0 - 1.0)
    return out


def env_adsr(length, attack, release):
    """Linear rise over attack, hold, linear fall over the last release (s)."""
    a, r = n(attack), n(release)
    return [min(i / a, 1.0, (length - i) / r) for i in range(length)]


def flutter(length, rate, depth):
    """Amplitude wobble: 1 - depth .. 1 at rate Hz (throat rattle, grinding)."""
    return [1.0 - depth * 0.5 * (1.0 + math.sin(2.0 * math.pi * rate * i / RATE)) for i in range(length)]


def roar(seconds, base, rise):
    """Deep layered roar: a vibrating saw throat, a rattling growl, a hissing
    screech on top and a hall's echo."""
    length = n(seconds)
    peak = seconds * 0.35
    pitch = lambda t: base * (1.0 + rise * math.sin(math.pi * min(t / seconds, 1.0))) * (1.0 + 0.04 * math.sin(2.0 * math.pi * 7.0 * t))
    throat = lowpass(osc(length, pitch), 700)
    under = lowpass(osc(length, lambda t: pitch(t) * 0.5), 300)
    growl_layer = mul(lowpass(noise(length), 520), flutter(length, 31.0, 0.7))
    screech = mul(bandpass(noise(length), 1300, 3200), flutter(length, 13.0, 0.5))
    body = mix((throat, 1.0), (under, 0.8), (growl_layer, 0.9), (screech, 0.18))
    shaped = mul(drive(body, 1.8), env_adsr(length, peak * 0.6, seconds * 0.45))
    return echo(shaped, 0.11, 0.35, 4)


def grind():
    length = n(0.7)
    crunch = [0.3 + 0.7 * abs(math.sin(2.0 * math.pi * 17.0 * i / RATE + 3.0 * math.sin(2.0 * math.pi * 3.0 * i / RATE))) for i in range(length)]
    stone = mul(bandpass(noise(length), 250, 1600), crunch)
    return mul(mix((stone, 1.0), (grains(0.7, 18, lambda: crack(0.02, 2500, 0.004)), 0.35)), env_hump(length, 0.5))


def bone_clack():
    f = rng.uniform(600, 1400)
    return mix((clang(0.06, [f, f * 1.7], 0.012), 1.0), (crack(0.03, 1800, 0.004), 0.6))


def heartbeat():
    lub = thump(0.2, 70, 38, 0.06)
    dub = delay(thump(0.2, 62, 34, 0.05), 0.2)
    hum = mul(sweep(n(0.5), 880, 860), env_hump(n(0.5), 0.3))
    return mix((lub, 1.0), (dub, 0.7), (hum, 0.05))


def glass_shatter(seconds, count):
    tinkle = grains(seconds, count, lambda: clang(0.12, [rng.uniform(2500, 6000), rng.uniform(4000, 8000)], 0.03))
    return mix((crack(0.15, 2500, 0.03), 1.0), (tinkle, 0.7), (thump(0.4, 120, 40, 0.12), 0.8))


# --- lobby world: secrets, notes, artifacts, CCTV (src/world) ---------------

def secret_chime():
    """A secret found: a soft low gong, then A-C-E-G# climbing and hanging
    in the air (eerie, with a wink) and a few sparkles."""
    gong = clang(1.6, [110, 110 * 2.41, 110 * 3.9], 0.5)
    notes = [(440, 0.12), (523, 0.24), (659, 0.36), (831, 0.5)]
    layers = [(delay(bell(1.2, f, 0.35), t), 0.6) for f, t in notes]
    sparkle = delay(grains(0.8, 10, lambda: blip(0.03, rng.uniform(3000, 6000))), 0.45)
    return echo(mix((gong, 0.7), (sparkle, 0.1), *layers), 0.13, 0.3, 3)


def paper():
    """A sheet of paper picked up and unfolded: dry crackles, two swishes."""
    crinkle = grains(0.45, 26, lambda: mul(bandpass(noise(n(0.02)), 1500, 6000), env_exp(n(0.02), 0.006, 0.001)))
    swish = mix((whoosh(0.22, 800, 5000, 0.4), 1.0), (delay(whoosh(0.18, 1000, 6000, 0.5), 0.2), 0.7))
    return mix((crinkle, 0.8), (swish, 0.5))


def wall_slide():
    """A hidden panel: a latch clack, a long stone-on-stone grind, a thud."""
    length = n(1.3)
    scrape = mul(mul(bandpass(noise(length), 120, 900), flutter(length, 9.0, 0.5)), env_adsr(length, 0.15, 0.3))
    latch = mix((crack(0.03, 2000, 0.006), 1.0), (thump(0.1, 180, 90, 0.03), 0.8))
    thud = delay(thump(0.5, 70, 35, 0.12), 1.25)
    return echo(mix((latch, 0.8), (delay(scrape, 0.08), 1.0), (thud, 0.9)), 0.09, 0.25, 3)


def grille():
    """A vent grille: two screws squeak loose, then the grille clanks."""
    def squeak():
        length = n(0.12)
        return lowpass(mul(sweep(length, rng.uniform(1800, 2400), rng.uniform(2600, 3200), "saw"), env_hump(length, 0.5)), 5000)
    clank = delay(mix((clang(0.4, [520, 1310, 2150], 0.08), 1.0), (crack(0.03, 2500, 0.005), 0.6)), 0.45)
    return mix((squeak(), 0.35), (delay(squeak(), 0.2), 0.3), (clank, 1.0))


def padlock():
    """A padlock shot off: a sharp crack, the shackle pinging away, bits."""
    ping = delay(clang(0.5, [2900, 4400, 6100], 0.1), 0.02)
    bits = delay(grains(0.5, 6, lambda: clang(0.08, [rng.uniform(2500, 5000)], 0.02)), 0.12)
    return mix((crack(0.08, 1500, 0.015), 1.0), (clang(0.3, [700, 1650], 0.06), 0.7), (ping, 0.6), (bits, 0.4))


def artifact():
    """Something old and warm in the hand: a low hum swelling under a
    G-B-D-F# bell chord and a trail of sparkles."""
    length = n(1.4)
    hum = mul(mix((sweep(length, 196, 196), 1.0), (sweep(length, 294, 294), 0.5)), env_adsr(length, 0.25, 0.9))
    chord = [(392, 0.0), (494, 0.06), (587, 0.12), (740, 0.18)]
    bells = [(delay(bell(1.1, f, 0.3), t), 0.55) for f, t in chord]
    sparkle = grains(1.0, 14, lambda: blip(0.03, rng.uniform(3500, 7000)))
    return mix((hum, 0.35), (sparkle, 0.08), *bells)


def keys():
    """A ring of old keys jangling."""
    jangle = grains(0.5, 9, lambda: clang(0.12, [rng.uniform(2200, 4200), rng.uniform(4500, 7000)], 0.03))
    return mix((jangle, 1.0), (thump(0.08, 300, 150, 0.02), 0.2))


def cctv_switch():
    """A CRT channel change: a relay click and a burst of static."""
    length = n(0.3)
    static = mul(highpass(noise(length), 1200), env_exp(length, 0.08, 0.001))
    return mix((crack(0.02, 3000, 0.003), 1.0), (static, 0.6), (blip(0.04, 3925), 0.05))


def drawer():
    """A wooden till drawer: a rolling rub, a stop, loose coins rattling."""
    length = n(0.4)
    rub = mul(bandpass(noise(length), 300, 1800), env_hump(length, 0.3))
    stop = delay(thump(0.12, 160, 80, 0.03), 0.38)
    coins = delay(grains(0.3, 5, lambda: clang(0.06, [rng.uniform(3000, 5000)], 0.015)), 0.4)
    return mix((rub, 0.8), (stop, 1.0), (coins, 0.3))


def locker():
    """A steel locker: the key turns, the hinge creaks, the door bangs."""
    turn = mix((crack(0.02, 2500, 0.004), 1.0), (delay(crack(0.03, 1800, 0.006), 0.08), 0.8))
    length = n(0.35)
    creak = delay(mul(lowpass(sweep(length, 380, 520, "saw"), 1500), mul(flutter(length, 23.0, 0.6), env_hump(length, 0.4))), 0.15)
    bang = delay(clang(0.4, [240, 610, 1180], 0.09), 0.5)
    return mix((turn, 0.7), (creak, 0.5), (bang, 1.0))


# --- the court café (plan 2026-10-10-kawiarnia-zmeczenie) ---------------------

def cafe_flap():
    """The counter flap: the hinge creaks as the slab lifts, the panel knocks,
    then the marble clacks down."""
    length = n(0.4)
    creak = mul(lowpass(sweep(length, 300, 430, "saw"), 1400), mul(flutter(length, 19.0, 0.55), env_hump(length, 0.35)))
    knock = delay(thump(0.14, 150, 70, 0.03), 0.3)
    clack = delay(mix((clang(0.09, [2600, 4100], 0.02), 1.0), (crack(0.02, 3000, 0.004), 0.6)), 0.5)
    return mix((creak, 0.6), (knock, 0.7), (clack, 1.0))


def espresso():
    """A coffee poured: the pump hums, steam hisses out of the group head,
    the cup fills drip by drip, the cup is set down with a clink."""
    length = n(1.6)
    hiss = mul(bandpass(noise(length), 1800, 6500), env_hump(length, 0.35))
    pump = mul(lowpass(sweep(length, 48, 54, "saw"), 200), env_hump(length, 0.3))
    drips = delay(grains(0.7, 9, lambda: mix((blip(0.015, rng.uniform(1900, 2600)), 1.0), (crack(0.01, 2500, 0.003), 0.4))), 0.75)
    clink = delay(clang(0.08, [3900, 5300], 0.02), 1.45)
    return mix((hiss, 0.9), (pump, 0.5), (drips, 0.5), (clink, 0.6))



# --- the museum's story (plan 2026-10-21-opowiesc-muzeum) ----------------------

def dial_click():
    """A brass dial or a clockwork key turned one notch: a light tick and a
    tiny ring."""
    return mix((crack(0.02, 4000, 0.003), 0.8), (clang(0.12, [3100, 4700, 6900], 0.025), 0.5))


def automaton_song():
    """The singing bird automaton: six short chirps, a breath, one long trill
    (six planets, then the sun), the clockwork whirring under it all."""
    def chirp(seconds, f0, f1):
        length = n(seconds)
        tone = osc(length, lambda t: f0 * (f1 / f0) ** (t / seconds) * (1.0 + 0.02 * math.sin(2.0 * math.pi * 38.0 * t)), "sine")
        return mul(tone, env_hump(length, 0.25))
    layers = []
    for k in range(6):
        layers.append((delay(chirp(0.13, 2700 + 60 * k, 3500 + 40 * k), 0.15 + 0.3 * k), 0.8))
    trill_at, trill_len = 2.15, 1.5
    length = n(trill_len)
    trill = mul(osc(length, lambda t: 3100.0 + (350.0 if math.sin(2.0 * math.pi * 17.0 * t) > 0.0 else 0.0), "sine"), env_adsr(length, 0.05, 0.5))
    layers.append((delay(trill, trill_at), 0.75))
    whirr_len = n(trill_at + trill_len + 0.1)
    whirr = mul(bandpass(noise(whirr_len), 700, 2500), mul(flutter(whirr_len, 14.0, 0.8), env_adsr(whirr_len, 0.05, 0.3)))
    layers.append((whirr, 0.12))
    return mix(*layers)


# --- the night in the lobby: fuses, the grate, the crystal, the clock --------

def relay():
    """A big relay slams, the building's hum sags and dies."""
    clack = mix((crack(0.05, 1800, 0.012), 1.0), (thump(0.25, 180, 60, 0.07), 1.0), (clang(0.3, [410, 980], 0.08), 0.4))
    length = n(1.6)
    hum = mul(mix((sweep(length, 100, 38, "saw"), 0.6), (sweep(length, 200, 76), 0.4)), env_adsr(length, 0.01, 1.3))
    return mix((clack, 1.0), (lowpass(hum, 500), 0.55), (delay(crack(0.03, 2000, 0.01), 0.35), 0.5))


def gate_jam():
    """Old iron lifts with a scrape, then stops dead with a clank."""
    length = n(0.8)
    scrape = mul(bandpass(noise(length), 300, 2200), mul(flutter(length, 23.0, 0.6), env_hump(length, 0.6)))
    stop = delay(mix((clang(0.9, [180, 420, 710, 1130], 0.25), 1.0), (thump(0.3, 110, 45, 0.08), 0.8)), 0.72)
    return echo(mix((scrape, 0.8), (stop, 1.0)), 0.09, 0.3, 3)


def gate_open():
    """The jammed leaves break free and roll aside in their tracks."""
    length = n(2.4)
    roll = mul(lowpass(noise(length), 700), mul(flutter(length, 9.0, 0.5), env_adsr(length, 0.2, 0.5)))
    ticks = grains(2.4, 14, lambda: clang(0.12, [rng.uniform(300, 700), rng.uniform(900, 1500)], 0.04))
    start = mix((clang(0.8, [150, 380, 640], 0.2), 1.0), (crack(0.05, 1500, 0.01), 0.7))
    end = delay(mix((clang(1.0, [120, 330, 590], 0.3), 1.0), (thump(0.4, 90, 40, 0.1), 0.8)), 2.3)
    return echo(mix((start, 0.9), (roll, 0.8), (ticks, 0.35), (end, 0.9)), 0.1, 0.3, 3)


def door_slam():
    """Heavy double doors bang shut down the hall."""
    bang = mix((thump(0.6, 95, 35, 0.14), 1.0), (crack(0.08, 900, 0.02), 0.7), (rumble(0.5, 400, 0.15), 0.6))
    return echo(mix((bang, 1.0), (delay(bang, 0.09), 0.7)), 0.13, 0.35, 4)


def witching_bell():
    """A tower clock far off strikes three."""
    toll = mix((bell(2.2, 196, 0.9), 1.0), (bell(2.2, 392, 0.6), 0.35), (thump(0.4, 90, 60, 0.15), 0.4))
    return echo(mix((toll, 1.0), (delay(toll, 1.3), 0.9), (delay(toll, 2.6), 0.8)), 0.17, 0.35, 4)


def dawn_chime():
    """Morning: a soft rising arpeggio and a breath of air."""
    notes = [(392, 0.0), (523, 0.25), (659, 0.5), (784, 0.75), (1047, 1.0)]
    layers = [(delay(bell(1.6, f, 0.5), t), 0.7) for f, t in notes]
    return mix((whoosh(2.4, 200, 2500, 0.5), 0.15), *layers)


def crystal_rise():
    """The crystal tears free: a glassy shimmer climbing up."""
    length = n(1.2)
    rise = mul(mix((sweep(length, 440, 1760), 1.0), (sweep(length, 660, 2640), 0.5)), env_hump(length, 0.7))
    sparkle = grains(1.2, 16, lambda: blip(0.03, rng.uniform(3000, 6500)))
    return echo(mix((rise, 0.7), (sparkle, 0.35), (thump(0.3, 70, 40, 0.1), 0.5)), 0.1, 0.3, 3)


# --- content: gatling, flare gun, raptor, portrait, upgrades ----------------

def loopable(samples, length_s, xfade_s=0.08):
    """Cut exactly length_s out of a longer take so it loops without a seam:
    the extra tail is crossfaded into the head."""
    length, x = n(length_s), n(xfade_s)
    out = list(samples[:length])
    for i in range(min(x, len(samples) - length)):
        t = i / x
        out[i] = samples[length + i] * (1.0 - t) + samples[i] * t
    return out


def wrap_add(buffer, samples, start):
    """Add samples into a loop buffer, wrapping past its end."""
    size = len(buffer)
    for i, x in enumerate(samples):
        buffer[(start + i) % size] += x


def gatling_shot():
    """One round of the belt: a short dry crack with a low punch."""
    body = mix((crack(0.05, rng.uniform(1300, 1800), 0.01), 1.0), (thump(0.08, rng.uniform(150, 175), 60, 0.018), 0.9),
               (rumble(0.09, 900, 0.022), 0.5))
    return drive(body, 2.5)


def gatling_rattle():
    """Exactly one second of fire at 14 rounds a second, as a loop."""
    buffer = [0.0] * n(1.0)
    step = len(buffer) / 14.0
    for k in range(14):
        wrap_add(buffer, mul(gatling_shot(), [rng.uniform(0.8, 1.0)] * n(0.09)), int(k * step) + rng.randint(0, 60))
    # the mechanism under the shots: ratchet and gears
    gears = mul(bandpass(noise(len(buffer)), 500, 2600), [0.45 + 0.55 * abs(math.sin(math.pi * 14.0 * i / RATE)) for i in range(len(buffer))])
    return mix((buffer, 1.0), (gears, 0.12))


def gatling_spin():
    """The barrels whirring at full speed (loop, 0.5 s): a geared hum with a
    click every time a barrel locks in (14 a second)."""
    length = n(0.62)
    hum = lowpass(osc(length, lambda t: 110.0, "saw"), 600)
    clicks = [0.35 + 0.65 * max(0.0, math.sin(2.0 * math.pi * 14.0 * i / RATE)) ** 8 for i in range(length)]
    ratchet = mul(bandpass(noise(length), 1500, 4500), clicks)
    whine = mul(osc(length, lambda t: 660.0, "sine"), [1.0] * length)
    return loopable(mix((hum, 0.6), (ratchet, 0.5), (whine, 0.08)), 0.5, 0.1)


def gatling_crank():
    """Grab the crank: a clunk, then ratchet clicks speeding up over a motor
    whir that rises into the spin loop's pitch."""
    length = n(0.5)
    clicks, t, gap = [], 0.02, 0.11
    while t < 0.48:
        clicks.append(t)
        t += gap
        gap = max(gap * 0.8, 1.0 / 14.0)
    ratchet = [0.0] * length
    for at in clicks:
        wrap_add(ratchet, mix((crack(0.03, 2200, 0.005), 1.0), (clang(0.04, [rng.uniform(1600, 2600)], 0.01), 0.4)), n(at))
    whir = mul(lowpass(osc(length, lambda s: 45.0 + 65.0 * min(s / 0.45, 1.0), "saw"), 500), env_adsr(length, 0.3, 0.05))
    clunk = mix((thump(0.12, 140, 70, 0.03), 1.0), (clang(0.1, [700, 1150], 0.03), 0.5))
    return mix((clunk, 0.9), (ratchet, 0.7), (whir, 0.6))


def gatling_stop():
    """Letting go: the whir winds down and the barrels clack to a halt."""
    length = n(0.75)
    whir = mul(lowpass(osc(length, lambda s: 110.0 * (1.0 - 0.7 * min(s / 0.7, 1.0)), "saw"), 500), env_exp(length, 0.3))
    clicks = [0.3 + 0.7 * max(0.0, math.sin(2.0 * math.pi * (14.0 - 10.0 * i / length) * i / RATE)) ** 8 for i in range(length)]
    ratchet = mul(mul(bandpass(noise(length), 1500, 4500), clicks), env_exp(length, 0.3))
    return mix((whir, 0.7), (ratchet, 0.5), (delay(clang(0.08, [900, 1500], 0.02), 0.62), 0.5))


def flare_fire():
    """A flare pistol: a hollow pop, then the hiss of the burning flare."""
    pop = mix((thump(0.18, 190, 70, 0.04), 1.0), (crack(0.05, 1200, 0.01), 0.6))
    hiss = mul(bandpass(noise(n(0.6)), 1500, 7000), env_hump(n(0.6), 0.2))
    return mix((drive(pop, 2.0), 1.0), (hiss, 0.45))


def flare_burn():
    """A flare catching: sizzle and crackle."""
    length = n(0.9)
    sizzle = mul(highpass(noise(length), 3000), env_hump(length, 0.15))
    crackle = grains(0.9, 24, lambda: crack(0.012, 2500, 0.003))
    return mix((sizzle, 0.6), (crackle, 0.5), (thump(0.1, 220, 90, 0.02), 0.4))


def flare_blast():
    """A small whump of fire."""
    return echo(mix((thump(0.45, 120, 38, 0.1), 1.0), (rumble(0.5, 700, 0.12), 0.8),
                    (grains(0.5, 12, lambda: crack(0.02, 2000, 0.005)), 0.4)), 0.07, 0.25, 2)


def chain_link():
    f = rng.uniform(1800, 3400)
    return clang(0.09, [f, f * 1.63, f * 2.4], 0.018)


def chain_clank():
    """A punch on the chain: links rattle and strain."""
    return mix((grains(0.3, 6, chain_link), 1.0), (thump(0.1, 160, 70, 0.025), 0.6))


def chain_break():
    """The chain snaps and slithers to the floor."""
    snap = mix((crack(0.06, 1500, 0.01), 1.0), (clang(0.4, [620, 1010, 1730], 0.09), 0.8))
    fall = delay(grains(0.9, 18, chain_link), 0.08)
    return echo(mix((snap, 1.0), (fall, 0.7), (delay(thump(0.2, 110, 50, 0.05), 0.75), 0.5)), 0.08, 0.25, 2)


def raptor_hiss():
    """The leap warning: a sharp throaty hiss with a bony rattle."""
    length = n(0.36)
    hiss = mul(bandpass(noise(length), 2200, 7500), mul(flutter(length, 38.0, 0.45), env_hump(length, 0.25)))
    rattle = grains(0.3, 5, bone_clack)
    return mix((hiss, 1.0), (rattle, 0.25))


def raptor_screech():
    """A raptor notices the guard: a shrill, bird-like screech."""
    length = n(0.5)
    pitch = lambda t: 900.0 + 900.0 * math.sin(math.pi * min(t / 0.5, 1.0)) ** 0.7
    voice = bandpass(osc(length, pitch), 600, 4000)
    rasp = mul(bandpass(noise(length), 1500, 5000), flutter(length, 45.0, 0.6))
    return mul(mix((voice, 0.8), (rasp, 0.5)), env_hump(length, 0.3))


def portrait_creak():
    """A frame pulling out of the wall: old wood creaks, canvas tears."""
    length = n(0.7)
    stick = [0.25 + 0.75 * max(0.0, math.sin(2.0 * math.pi * (9.0 + 6.0 * i / length) * i / RATE)) ** 6 for i in range(length)]
    creak = mul(bandpass(osc(length, lambda t: 75.0 + 30.0 * math.sin(2.0 * math.pi * 3.0 * t), "saw"), 250, 2500), mul(stick, env_hump(length, 0.5)))
    rip = delay(mul(bandpass(noise(n(0.35)), 1200, 5000), mul(flutter(n(0.35), 60.0, 0.7), env_hump(n(0.35), 0.2))), 0.3)
    return mix((creak, 1.0), (rip, 0.5))


def suspicion():
    """An exhibit notices something: a dry creak of the old body and a low,
    rising hum, like a question - quieter than the call-out (notice)."""
    length = n(0.5)
    hum = mul(lowpass(sweep(length, 70, 118, "saw"), 520), env_hump(length, 0.7))
    stick = [0.3 + 0.7 * max(0.0, math.sin(2.0 * math.pi * 14.0 * i / RATE)) ** 8 for i in range(n(0.22))]
    creak = mul(bandpass(osc(n(0.22), lambda t: 140.0 + 40.0 * t, "saw"), 300, 2200), mul(stick, env_hump(n(0.22), 0.3)))
    return mix((hum, 1.0), (creak, 0.45))


def paint_spit():
    """A wet gob of paint spat out."""
    blorp = mul(sweep(n(0.2), 320, 110), env_exp(n(0.2), 0.06))
    wet = mul(bandpass(noise(n(0.25)), 400, 2500), env_hump(n(0.25), 0.2))
    return mix((blorp, 1.0), (wet, 0.6), (whoosh(0.3, 500, 3000, 0.3), 0.3))


def paint_splat():
    """Paint hitting the floor or the guard."""
    splat = mix((thump(0.16, 210, 70, 0.04), 1.0), (mul(lowpass(noise(n(0.2)), 1800), env_exp(n(0.2), 0.05)), 0.9))
    drops = grains(0.35, 7, lambda: mul(sweep(n(0.03), rng.uniform(700, 1400), 300), env_exp(n(0.03), 0.01)))
    return mix((splat, 1.0), (drops, 0.3))


def hit_canvas():
    """A shot through stretched canvas into a gilded frame: a drum-like thud
    and a wooden knock."""
    return mix((thump(0.15, 180, 95, 0.035), 1.0), (mul(bandpass(noise(n(0.08)), 500, 2200), env_exp(n(0.08), 0.02)), 0.7),
               (clang(0.07, [880, 1460], 0.015), 0.35))


def break_canvas():
    """A portrait torn apart: frame splinters and ripping canvas."""
    splinters = grains(0.6, 18, lambda: mix((crack(0.03, 1500, 0.006), 1.0), (clang(0.04, [rng.uniform(500, 1100)], 0.01), 0.4)))
    rip = mul(bandpass(noise(n(0.5)), 1000, 4500), mul(flutter(n(0.5), 55.0, 0.7), env_hump(n(0.5), 0.3)))
    return mix((splinters, 1.0), (rip, 0.6), (thump(0.25, 140, 60, 0.06), 0.6))


def second_wind_beat():
    """Two slow, heavy heartbeats under a thin ringing."""
    beat = mix((thump(0.26, 62, 30, 0.07), 1.0), (delay(thump(0.24, 55, 28, 0.06), 0.24), 0.75))
    ring = mul(sweep(n(1.8), 1320, 1300), env_hump(n(1.8), 0.1))
    return mix((beat, 1.0), (delay(beat, 0.85), 0.8), (ring, 0.04))


def ear_warn():
    """Keen ear: a soft rush from behind and a small tick."""
    return mix((whoosh(0.22, 800, 5000, 0.7), 1.0), (delay(blip(0.04, 1250), 0.15), 0.5))


# --- the night's soundtrack: dawn (played by Ambience, see DAWN_BIRDS) -----

def chirp(seconds, f0, f1, trill=0.0, rate=38.0):
    """One far bird note: a whistle gliding f0 -> f1, trilled by `trill`."""
    length = n(seconds)
    freq = lambda t: f0 * (f1 / f0) ** (t / seconds) * (1.0 + trill * math.sin(2.0 * math.pi * rate * t))
    return mul(osc(length, freq, "sine"), env_hump(length, 0.25))


def bird_song(kind):
    """A short phrase of one of three birds."""
    if kind == "warble":   # a robin-ish run of tumbling notes
        notes = []
        t = 0.0
        for _ in range(rng.randint(4, 7)):
            f = rng.uniform(2800, 4600)
            notes.append((delay(chirp(rng.uniform(0.06, 0.12), f, f * rng.uniform(0.8, 1.25), 0.04), t), 1.0))
            t += rng.uniform(0.09, 0.16)
        return mix(*notes)
    if kind == "call":     # a tit's two-note "tee-chu", twice
        high, low = rng.uniform(4800, 5600), rng.uniform(3300, 3800)
        pair = mix((chirp(0.11, high, high * 0.97), 1.0), (delay(chirp(0.13, low, low * 0.95), 0.16), 0.9))
        return mix((pair, 1.0), (delay(pair, 0.42), 0.85))
    # a sparrow's dry cheeps
    cheeps = []
    for k in range(rng.randint(2, 4)):
        f = rng.uniform(3600, 4400)
        cheeps.append((delay(chirp(0.05, f * 1.1, f * 0.85, 0.08, 60.0), k * rng.uniform(0.12, 0.2)), 1.0))
    return mix(*cheeps)


def dawn_birds():
    """Morning: a few birds far off, beyond the skylights, sparse and soft."""
    total = 7.5
    out = [0.0] * n(total)
    t = rng.uniform(0.2, 0.6)
    while t < total - 1.4:
        song = bird_song(rng.choice(["warble", "call", "cheep"]))
        gain = rng.uniform(0.45, 1.0)
        start = n(t)
        for i, x in enumerate(song):
            if start + i < len(out):
                out[start + i] += x * gain
        t += rng.uniform(0.7, 1.5)
    far = bandpass(out, 1800, 6500)
    air = mul(bandpass(noise(len(far)), 300, 2500), [0.04] * len(far))
    swell = env_adsr(len(far), 1.2, 2.0)
    return echo(mul(mix((far, 1.0), (air, 1.0)), swell), 0.12, 0.3, 3)



# --- Floor I: the three new weapons, the gate locks, the upgrade terminal ---
def rifle_hunt():
    """A big-game rifle: a hard supersonic crack, a deep punch, a long tail
    rolling down the gallery."""
    shot = mix((crack(0.16, 2600, 0.025), 1.0), (thump(0.5, 130, 34, 0.12), 1.0), (rumble(0.9, 700, 0.25), 0.8))
    return echo(drive(shot, 3.2), 0.11, 0.4, 5)


def rifle_bolt():
    """The bolt worked: up-clack, a steel slide back, forward, down-clack."""
    def clack(f):
        return mix((crack(0.03, f, 0.006), 1.0), (clang(0.06, [f * 0.9, f * 1.6], 0.015), 0.5))
    slide = mul(bandpass(noise(n(0.12)), 1800, 6000), env_hump(n(0.12), 0.5))
    return mix((clack(2600), 0.9), (delay(slide, 0.06), 0.5), (delay(clack(2100), 0.17), 0.8),
               (delay(slide, 0.26), 0.45), (delay(clack(3000), 0.4), 0.9))


def harpoon_fire():
    """A whaling gun: a heavy black-powder boom, the line whipping out."""
    boom = drive(mix((thump(0.6, 95, 30, 0.16), 1.0), (crack(0.12, 900, 0.03), 0.8), (rumble(0.7, 500, 0.2), 0.9)), 2.6)
    line = delay(mul(bandpass(noise(n(0.5)), 900, 3500), mul(env_hump(n(0.5), 0.25), flutter(n(0.5), 31.0, 0.6))), 0.05)
    return echo(mix((boom, 1.0), (line, 0.45)), 0.09, 0.3, 3)


def harpoon_thunk():
    """The harpoon bites: a heavy wooden-iron thunk with a ringing shaft."""
    return mix((thump(0.3, 150, 60, 0.07), 1.0), (crack(0.05, 1300, 0.01), 0.7), (clang(0.35, [430, 690, 1150], 0.1), 0.35))


def hook_pull():
    """The line snaps taut and drags something heavy."""
    taut = mul(bandpass(noise(n(0.45)), 300, 1400), mul(env_hump(n(0.45), 0.2), flutter(n(0.45), 17.0, 0.5)))
    return mix((crack(0.04, 1800, 0.008), 0.8), (taut, 1.0), (delay(thump(0.3, 90, 45, 0.08), 0.12), 0.7))


def hwacha_fire():
    """One fire-arrow leaving its tube: a spitting hiss and a sharp whoosh."""
    hiss = mul(bandpass(noise(n(0.45)), 1200, 8000), env_exp(n(0.45), 0.15))
    return mix((hiss, 1.0), (whoosh(0.35, 400, 3500, 0.2), 0.8), (crack(0.03, 2400, 0.006), 0.6))


def hwacha_pop():
    """A fire-arrow bursting: a small crackling bang."""
    return echo(mix((thump(0.3, 160, 55, 0.06), 1.0), (crack(0.07, 1600, 0.015), 0.8),
                    (grains(0.35, 10, lambda: crack(0.02, 2600, 0.005)), 0.5)), 0.06, 0.2, 2)




def wall_hit():
    """A shot on cracked masonry: a dull knock and trickling grit."""
    grit = grains(0.4, 8, lambda: crack(0.015, 3000, 0.004))
    return mix((thump(0.15, 140, 70, 0.04), 1.0), (grit, 0.4))






def weight_thud():
    """A counterweight lands: a heavy iron thud and a short rattle."""
    return echo(mix((thump(0.7, 75, 28, 0.2), 1.0), (clang(0.5, [210, 370, 610], 0.12), 0.45),
                    (rumble(0.6, 400, 0.15), 0.7)), 0.1, 0.3, 3)




def bolt_rattle():
    """A bolted door shaken from the wrong side."""
    knock = lambda: mix((thump(0.12, 120, 70, 0.03), 1.0), (clang(0.08, [700, 1200], 0.02), 0.4))
    return mix((knock(), 1.0), (delay(knock(), 0.11), 0.8), (delay(knock(), 0.2), 0.6))




def power_dead():
    """No power: a dead button click, a relay that does not catch."""
    return mix((crack(0.03, 2200, 0.005), 1.0), (delay(blip(0.04, 220), 0.06), 0.25))


def gate_swing():
    """A heavy door or gate swings open: a long hinge creak and a soft
    knock as it stops."""
    length = n(1.0)
    creak = mul(osc(length, lambda t: 210 + 120 * t + 25 * math.sin(t * 40.0), "saw"), env_hump(length, 0.35))
    creak = mul(bandpass(creak, 300, 2500), flutter(length, 23.0, 0.4))
    return mix((creak, 0.7), (delay(thump(0.3, 120, 60, 0.07), 0.95), 0.8))


def upgrade_forge():
    """An upgrade fitted: a bright anvil ting over a warm chime."""
    return echo(mix((clang(0.9, [1320, 2140, 3500], 0.3), 0.8), (bell(1.2, 880, 0.6), 0.6), (crack(0.02, 3500, 0.004), 0.5)),
                0.09, 0.3, 3)


def radio_click(tail_s, tail_decay, second_click):
    """A walkie-talkie's push-to-talk: a 4 ms click (an impulse in a puff of
    noise), then a squelch tail of 400-3000 Hz noise dying away."""
    click_len = n(0.004)
    click = mul(mix((noise(click_len), 1.0), ([1.0] + [0.0] * (click_len - 1), 1.5)), env_exp(click_len, 0.0015, 0.0002))
    tail = mul(bandpass(noise(n(tail_s)), 400, 3000), env_exp(n(tail_s), tail_decay, 0.003))
    layers = [(click, 1.0), (delay(tail, 0.004), 0.55)]
    if second_click:
        layers.append((delay(click, tail_s - 0.004), 0.5))
    return mix(*layers)


def radio_click_in():
    """Heniek keys the radio: click, 110 ms of squelch fading out."""
    return radio_click(0.11, 0.035, False)


def radio_click_out():
    """He lets go: click, a shorter-lived 180 ms squelch, a quieter click at the end."""
    return radio_click(0.18, 0.045, True)


SOUNDS = {
    "pistol": lambda: echo(drive(mix((crack(0.12, 1500, 0.02), 0.8), (thump(0.25, 160, 45, 0.06), 1.0), (rumble(0.3, 900, 0.07), 0.6)), 3.0), 0.06, 0.25, 3),
    "shotgun": lambda: echo(drive(mix((crack(0.2, 900, 0.04), 0.9), (thump(0.5, 110, 30, 0.14), 1.0), (rumble(0.6, 600, 0.16), 0.9)), 3.0), 0.08, 0.3, 4),
    "taser": taser,
    "punch": lambda: whoosh(0.18, 300, 2500, 0.35),
    "punch_hit": lambda: mix((thump(0.2, 120, 45, 0.05), 1.0), (crack(0.05, 2000, 0.008), 0.5)),
    "reload": lambda: mix((crack(0.04, 2500, 0.006), 1.0), (clang(0.08, [2400, 3700], 0.02), 0.4),
                          (delay(crack(0.04, 2200, 0.006), 0.28), 0.9), (delay(clang(0.1, [1900, 3100], 0.025), 0.28), 0.4)),
    "empty": lambda: crack(0.03, 3000, 0.004),
    "swing": lambda: whoosh(0.3, 150, 1200, 0.45),
    "hurt": hurt,
    "dash": lambda: whoosh(0.25, 500, 4000, 0.3),
    "notice": notice,
    "growl": growl,
    "hit_marker": lambda: clang(0.05, [3200], 0.01),
    "kill": lambda: mix((clang(0.12, [1800, 2700], 0.03), 1.0), (thump(0.12, 200, 90, 0.04), 0.8)),
    "pickup": lambda: mix((blip(0.07, 880), 1.0), (delay(blip(0.09, 1320), 0.07), 1.0)),
    "block": lambda: mix((clang(0.5, [420, 1030, 1650, 2380], 0.15), 1.0), (crack(0.05, 2000, 0.01), 0.6)),
    "hit_wax": lambda: mix((thump(0.15, 260, 110, 0.04), 1.0), (rumble(0.15, 1200, 0.04), 0.7)),
    "break_wax": lambda: mix((thump(0.35, 180, 60, 0.1), 1.0), (grains(0.5, 14, lambda: rumble(0.05, 1500, 0.015)), 0.6)),
    "hit_sawdust": lambda: mix((rumble(0.2, 700, 0.06), 1.0), (crack(0.08, 3000, 0.02), 0.2)),
    "break_sawdust": lambda: mix((rumble(0.5, 500, 0.15), 1.0), (grains(0.6, 20, lambda: crack(0.02, 1500, 0.006)), 0.4)),
    "hit_marble": lambda: mix((crack(0.08, 2500, 0.01), 1.0), (clang(0.12, [1900, 3100], 0.025), 0.6)),
    "break_marble": lambda: grains(0.7, 26, lambda: mix((crack(0.04, 2000, 0.008), 1.0),
                                                        (clang(0.06, [rng.uniform(1500, 3500)], 0.015), 0.5))),
    "hit_metal": lambda: mix((clang(0.35, [620, 1480, 2330], 0.08), 1.0), (crack(0.03, 3000, 0.005), 0.5)),
    "break_metal": lambda: grains(0.8, 10, lambda: clang(0.3, [rng.uniform(400, 900), rng.uniform(1200, 2500)], 0.07)),
    # stage 2a: the night loop and the menus
    "dust": dust,
    "lantern": lantern,
    "buy": buy,
    "deny": deny,
    "interact": lambda: mix((crack(0.02, 2800, 0.004), 1.0), (delay(crack(0.03, 1800, 0.006), 0.05), 0.7), (thump(0.06, 220, 120, 0.015), 0.5)),
    "alarm": alarm,
    "ui_move": lambda: blip(0.03, 1760),
    "ui_confirm": lambda: mix((blip(0.05, 988), 1.0), (delay(blip(0.08, 1480), 0.05), 1.0)),
    "ui_back": lambda: mix((blip(0.05, 1175), 1.0), (delay(blip(0.08, 784), 0.05), 1.0)),
    # stage 2c-1
    "shard_fire": lambda: mix((whoosh(0.35, 600, 5000, 0.25), 1.0), (crack(0.05, 2200, 0.01), 0.7)),
    "shard_break": lambda: grains(0.35, 12, lambda: mix((crack(0.03, 2500, 0.006), 1.0),
                                                       (clang(0.05, [rng.uniform(2000, 4000)], 0.012), 0.5))),
    "bust_grind": grind,
    "trex_roar": lambda: roar(2.2, 78.0, 0.35),
    "trex_bellow": lambda: roar(0.95, 92.0, 0.25),
    "trex_step": lambda: mix((thump(0.6, 55, 28, 0.16), 1.0), (rumble(0.6, 250, 0.2), 0.8), (bone_clack(), 0.15)),
    "trex_scrape": lambda: mul(mix((bandpass(noise(n(0.35)), 700, 4000), 1.0),
                                   (grains(0.35, 10, lambda: crack(0.02, 2000, 0.005)), 0.6)), env_hump(n(0.35), 0.3)),
    "trex_impact": lambda: echo(mix((thump(0.9, 70, 25, 0.25), 1.0), (crack(0.2, 900, 0.05), 0.8), (rumble(1.0, 500, 0.3), 0.9),
                                    (grains(1.0, 16, lambda: crack(0.04, 1500, 0.01)), 0.5)), 0.12, 0.3, 4),
    "tail_whoosh": lambda: lowpass(whoosh(0.55, 90, 900, 0.4), 500),
    "bone_hit": bone_clack,
    "bone_rattle": lambda: grains(0.6, 22, bone_clack),
    "bone_collapse": lambda: echo(mix((grains(1.8, 60, bone_clack), 1.0), (grains(1.8, 8, lambda: thump(0.3, 90, 40, 0.08)), 0.7)), 0.1, 0.3, 3),
    "crystal_hit": lambda: mix((clang(0.35, [2800, 4100, 5600], 0.08), 1.0), (crack(0.04, 3000, 0.006), 0.6)),
    "crystal_pulse": heartbeat,
    "crystal_shatter": lambda: echo(glass_shatter(1.4, 40), 0.1, 0.3, 3),
    "rubble": lambda: mix((thump(0.5, 80, 30, 0.12), 1.0), (rumble(0.8, 600, 0.2), 0.8), (grains(0.8, 20, lambda: crack(0.03, 1500, 0.008)), 0.6)),
    # lobby world (src/world/world_sounds.gd)
    "secret": secret_chime,
    "paper": paper,
    "wall_slide": wall_slide,
    "grille": grille,
    "padlock": padlock,
    "artifact": artifact,
    "keys": keys,
    "cctv_switch": cctv_switch,
    "drawer": drawer,
    "locker": locker,
    "cafe_flap": cafe_flap,
    "espresso": espresso,
    # the museum's story: the curios
    "dial_click": dial_click,
    "automaton_song": automaton_song,
    # content: gatling, flare gun, raptor, portrait, upgrades
    "gatling_crank": gatling_crank,
    "gatling_spin": gatling_spin,
    "gatling_rattle": gatling_rattle,
    "gatling_stop": gatling_stop,
    "flare_fire": flare_fire,
    "flare_burn": flare_burn,
    "flare_blast": flare_blast,
    "glass_break": lambda: mix((glass_shatter(0.9, 34), 1.0), (delay(grains(0.6, 8, lambda: clang(0.1, [rng.uniform(3000, 6500)], 0.03)), 0.3), 0.4)),
    "chain_clank": chain_clank,
    "chain_break": chain_break,
    "raptor_hiss": raptor_hiss,
    "raptor_screech": raptor_screech,
    "portrait_creak": portrait_creak,
    "paint_spit": paint_spit,
    "paint_splat": paint_splat,
    "hit_canvas": hit_canvas,
    "break_canvas": break_canvas,
    "heartbeat": second_wind_beat,
    "ear_warn": ear_warn,
    # the night in the lobby
    "fuse_take": lambda: mix((clang(0.1, [2200, 3500], 0.02), 0.8), (crack(0.02, 3000, 0.004), 0.6), (delay(blip(0.08, 1175), 0.05), 0.5)),
    "fuse_insert": lambda: mix((thump(0.2, 220, 90, 0.05), 1.0), (crack(0.04, 2200, 0.008), 0.9), (delay(clang(0.15, [1400, 2100], 0.04), 0.06), 0.6)),
    "relay": relay,
    "gate_jam": gate_jam,
    "gate_open": gate_open,
    "door_slam": door_slam,
    "witching_bell": witching_bell,
    "dawn_chime": dawn_chime,
    "crystal_rise": crystal_rise,
    # exhibit perception: something caught its attention
    "suspicion": suspicion,
    # the night's soundtrack (the Ambience autoload plays it, not Sfx)
    "dawn_birds": dawn_birds,
    # Floor I: weapons, gate locks, the upgrade terminal
    "rifle_hunt": rifle_hunt,
    "rifle_bolt": rifle_bolt,
    "harpoon_fire": harpoon_fire,
    "harpoon_thunk": harpoon_thunk,
    "hook_pull": hook_pull,
    "hwacha_fire": hwacha_fire,
    "hwacha_pop": hwacha_pop,
    "wall_hit": wall_hit,
    "weight_thud": weight_thud,
    "bolt_rattle": bolt_rattle,
    "power_dead": power_dead,
    "upgrade_forge": upgrade_forge,
    "gate_swing": gate_swing,
    # the voice: Heniek's walkie-talkie keyed and released (VoiceDirector)
    "radio_click_in": radio_click_in,
    "radio_click_out": radio_click_out,
}

# Loops (the game plays them with loop_mode forward): no fade-out at the end.
LOOPS = {"gatling_spin", "gatling_rattle"}


# Level (dB) under PEAK, per sound; unlisted sounds stay at 0.
LEVELS = {
    "notice": -7.0,
    "pickup": -5.0,
    "break_wax": -2.0,
    "dust": -9.0,
    "lantern": -3.0,
    "buy": -3.0,
    "deny": -8.0,
    "interact": -8.0,
    "alarm": -4.0,
    "ui_move": -14.0,
    "ui_confirm": -9.0,
    "ui_back": -10.0,
    "shard_fire": -3.0,
    "shard_break": -3.0,
    "bust_grind": -3.0,
    "trex_scrape": -4.0,
    "bone_hit": -4.0,
    "bone_rattle": -3.0,
    "crystal_hit": -3.0,
    "crystal_pulse": -9.0,
    "secret": -3.0,
    "paper": -8.0,
    "wall_slide": -2.0,
    "grille": -5.0,
    "padlock": -3.0,
    "artifact": -4.0,
    "keys": -8.0,
    "cctv_switch": -10.0,
    "drawer": -6.0,
    "locker": -5.0,
    "cafe_flap": -6.0,
    "espresso": -9.0,
    "dial_click": -10.0,
    "automaton_song": -6.0,
    "gatling_spin": -12.0,
    "gatling_crank": -5.0,
    "gatling_stop": -7.0,
    "gatling_rattle": -1.5,
    "flare_burn": -6.0,
    "flare_blast": -1.0,
    "chain_clank": -3.0,
    "raptor_hiss": -2.0,
    "raptor_screech": -5.0,
    "portrait_creak": -3.0,
    "paint_spit": -3.0,
    "paint_splat": -4.0,
    "hit_canvas": -2.0,
    "heartbeat": -3.0,
    "ear_warn": -8.0,
    "fuse_take": -5.0,
    "fuse_insert": -3.0,
    "dawn_chime": -3.0,
    "crystal_rise": -2.0,
    "dawn_birds": -6.0,
    "rifle_bolt": -5.0,
    "harpoon_thunk": -2.0,
    "hook_pull": -3.0,
    "hwacha_fire": -4.0,
    "hwacha_pop": -2.0,
    "wall_hit": -4.0,
    "bolt_rattle": -4.0,
    "power_dead": -8.0,
    "upgrade_forge": -3.0,
    "gate_swing": -4.0,
    "suspicion": -9.0,
    "radio_click_in": -6.0,
    "radio_click_out": -6.0,
}


def write(name, samples, level_db=0.0):
    OUT.mkdir(parents=True, exist_ok=True)
    loudest = max(abs(x) for x in samples) or 1.0
    gain = PEAK * 10.0 ** (level_db / 20.0) / loudest
    data = [x * gain for x in samples]
    if name not in LOOPS:
        data = fade_out(data, 0.01)
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in data)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


def main(names=()):
    """gen_sfx.py [name ...]: every sound, or only the named ones ('floor1'
    = all of Floor I's: tools/sfx/floor1_sfx.py, needs numpy)."""
    for name, make in SOUNDS.items():
        if names and name not in names:
            continue
        rng.seed(name)
        write(name, make(), LEVELS.get(name, 0.0))
        print("wrote", name)
    try:
        import floor1_sfx
    except ImportError as error:   # no numpy: the older sounds are done
        print("Floor I sounds skipped:", error)
        return
    LOOPS.update(floor1_sfx.LOOPS)
    for name in floor1_sfx.SOUNDS:
        if names and name not in names and "floor1" not in names:
            continue
        write(name, floor1_sfx.render(name), floor1_sfx.LEVELS.get(name, 0.0))
        if name in floor1_sfx.LOOPS:
            floor1_sfx.mark_loop(OUT / f"{name}.wav")
        print("wrote", name)


if __name__ == "__main__":
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    main(sys.argv[1:])
