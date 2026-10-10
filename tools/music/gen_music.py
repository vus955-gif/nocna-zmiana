"""Procedural score of Nocna Zmiana (menu, exploration, tension, combat,
boss, stings). Deterministic: every track has its own seed.

Writes 44.1 kHz 16-bit stereo WAV intermediates to build/audio_src/music/
(gitignored); tools/music/encode_ogg.py (run in Blender) encodes them to
assets/music/*.ogg with their .import files. Loops are rendered circularly (what rings past the end of a loop is folded back onto
its start and every filter, reverb and limiter runs over the loop as a
loop), so each file loops without a seam. Stems of one family (explore +
explore_tension, combat + combat_hi, boss + boss_hi) share length, tempo
and dynamics so the game can layer them in sync.

Run with numpy (Blender's bundled Python has it), from the repo root:

    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/music/gen_music.py [track ...]

Loudness targets (BS.1770 integrated, sample peaks <= -1.5 dBFS):
menu -18, explore -22 (with tension -19), combat -18 (full -16.5),
boss -17.5 (full -16), stings about -17 / -19.

The whole chain (render, encode, import, seam check): tools/build_audio.sh.
"""
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import analyze  # noqa: E402
import dsp  # noqa: E402
import instruments as ins  # noqa: E402
from dsp import SR, db, g_bell, g_highpass, g_lowpass, g_mul, g_shelf_hi, g_shelf_lo  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
# WAV intermediates (never committed); encode_ogg.py turns them into assets/music/*.ogg
OUT = ROOT / "build" / "audio_src" / "music"

_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def m(name):
    """'Bb3' -> MIDI note number (A4 = 69)."""
    letter, rest, acc = name[0], name[1:], 0
    while rest and rest[0] in "#b":
        acc += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + _PC[letter] + acc


def ms(names):
    return [m(x) for x in names]


# chord symbol -> (root pitch class name, intervals)
CHORDS = {
    "Dm": ("D", [0, 3, 7]), "Bb": ("Bb", [0, 4, 7]), "Gm": ("G", [0, 3, 7]), "A": ("A", [0, 4, 7]),
    "A7": ("A", [0, 4, 7, 10]), "F": ("F", [0, 4, 7]), "C": ("C", [0, 4, 7]), "Em7b5": ("E", [0, 3, 6, 10]),
    "Eb": ("Eb", [0, 4, 7]), "D": ("D", [0, 4, 7]), "Cm": ("C", [0, 3, 7]),
}
# low string pad voicings
PAD = {
    "Dm": ["D2", "A2", "F3", "A3"], "Bb": ["Bb1", "F2", "D3", "F3"], "Gm": ["G1", "D2", "Bb2", "G3"],
    "A": ["A1", "E2", "C#3", "E3"], "A7": ["A1", "E2", "C#3", "G3"], "F": ["F2", "C3", "F3", "A3"],
    "C": ["C2", "G2", "E3", "G3"], "Em7b5": ["E2", "Bb2", "D3", "G3"], "Eb": ["Eb2", "Bb2", "G3", "Bb3"],
    "D": ["D2", "A2", "F#3", "A3"],
}


def root_midi(chord, low, high):
    """The chord's root placed in [low, high] (MIDI)."""
    pc = m(CHORDS[chord][0] + "4") % 12
    r = low + ((pc - low) % 12)
    return r if r <= high else r - 12


class Session:
    """A piece on a tempo grid: named buses (each one a Timeline with EQ,
    optional sidechain gain, reverb sends) grouped into stems."""

    def __init__(self, bpm, beats_per_bar, bars, seed, loop=True):
        spb = SR * 60.0 / bpm
        assert abs(spb - round(spb)) < 1e-9, "beat must be a whole number of samples"
        self.bpm = bpm
        self.spb = int(round(spb))
        self.bpb = beats_per_bar
        self.bars = bars
        self.n = bars * beats_per_bar * self.spb
        self.loop = loop
        self.rng = np.random.default_rng(seed)
        self.buses = {}
        self.irs = {}

    def at(self, bar, beat=0.0, jitter=0.0):
        pos = (bar * self.bpb + beat) * self.spb
        if jitter:
            pos += self.rng.normal(0.0, jitter) * SR
        return int(round(pos))

    def sec(self, beats):
        return beats * 60.0 / self.bpm

    def bus(self, name, stem="main", sends=None, eq=None, gain_db=0.0, stereo_width=1.0):
        self.buses[name] = {"tl": dsp.Timeline(samples=self.n, loop=self.loop), "stem": stem, "sends": sends or {},
                            "eq": eq, "gain": float(db(gain_db)), "width": stereo_width, "duck": None}

    def add(self, bus, at, sig, gain=1.0, pan=0.0):
        self.buses[bus]["tl"].add(at, sig, gain, pan)

    def duck(self, bus, hits, depth_db=-5.0, release=0.14):
        n = self.buses[bus]["tl"].buf.shape[0]
        self.buses[bus]["duck"] = dsp.duck(n, hits, depth_db, 0.004, release, self.loop)

    def reverb(self, name, **kw):
        self.irs[name] = dsp.make_ir(rng=self.rng, **kw)

    def render(self, verbose=True):
        length = self.n
        if not self.loop:
            length = max(b["tl"].buf.shape[0] for b in self.buses.values())
            length += max((ir.shape[0] for ir in self.irs.values()), default=0)
        stems, wet = {}, {}
        for name, b in self.buses.items():
            x = dsp.pad_to(b["tl"].buf, length)
            if not np.any(x):
                continue
            if b["eq"] is not None:
                x = dsp.fft_filter(x, b["eq"], circular=self.loop)
            if b["duck"] is not None:
                x = x * dsp.pad_to(b["duck"], length)[:, None] if not self.loop else x * b["duck"][:, None]
            if b["width"] != 1.0:
                x = dsp.width(x, b["width"])
            x = x * b["gain"]
            if verbose:
                print(f"    bus {name:<10} {dsp.lufs(x, circular=self.loop):6.1f} LUFS dry  peak {dsp.to_db(dsp.peak(x)):5.1f}")
            stems[b["stem"]] = stems.get(b["stem"], 0.0) + x
            for ir, amount in b["sends"].items():
                wet[(b["stem"], ir)] = wet.get((b["stem"], ir), 0.0) + x * amount
        for (stem, ir), x in wet.items():
            r = dsp.convolve(x, self.irs[ir], circular=self.loop)
            stems[stem] = stems[stem] + dsp.pad_to(r, length)
        return stems


def master(stems, target, loop=True, reference=None, glue=None, ceiling=-1.5):
    """Sets the loudness of the reference sum (default: every stem) to
    [param target] LUFS; glue compression and limiting are computed on
    that sum and applied to every stem alike (linked), then each stem gets
    a safety limit of its own."""
    names = list(stems)
    reference = reference or names
    if glue:
        ref = sum(stems[k] for k in reference)
        g = dsp.compress_gain(ref, circular=loop, **glue)
        stems = {k: v * g[:, None] for k, v in stems.items()}
    base = sum(stems[k] for k in reference)
    trim = target - dsp.lufs(base, circular=loop)
    for _ in range(4):
        ref = base * db(trim)
        lg = dsp.limit_gain(ref, ceiling, circular=loop)
        err = target - dsp.lufs(ref * lg[:, None], circular=loop)
        if abs(err) < 0.1:
            break
        trim += err
    lg = dsp.limit_gain(base * db(trim), ceiling, circular=loop)
    return {k: dsp.limit(v * db(trim) * lg[:, None], ceiling, circular=loop) for k, v in stems.items()}


def write(name, x, loop=True, seed=0):
    path = OUT / f"{name}.wav"
    dsp.write_wav(path, x, np.random.default_rng(seed + 7))
    print(analyze.format_report(analyze.report(dsp.read_wav(path), path.name, loop)))


# --- menu: "Nokturn dozorcy" -------------------------------------------------

MENU_PROG = (["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"]
             + ["Dm", "Bb", "Gm", "A", "Dm", "F", ("Gm", "A"), "Dm"]
             + ["Dm", "Bb", "Gm", "A", "Dm", "Bb", ("Gm", "A"), "Dm"]
             + ["F", "C", "Dm", "Bb", "Gm", "Dm", "Em7b5", "A7"]
             + ["F", "C", "Dm", "Bb", "Gm", "Dm", "Em7b5", "A7"]
             + ["Dm", "Bb", "Gm", "A", "Dm", "F", ("Gm", "A"), "Dm"]
             + ["Gm", "A", "Dm", "Dm"])

# (beat within the phrase, note, beats)
PHRASE_A = [(0, "A4", 1), (1, "D5", 1), (2, "F5", 1), (3, "F5", 2), (5, "D5", 1), (6, "E5", 1), (7, "D5", 1),
            (8, "Bb4", 1), (9, "C#5", 3), (12, "A4", 1), (13, "D5", 1), (14, "F5", 1), (15, "A5", 2), (17, "G5", 1),
            (18, "F5", 1), (19, "E5", 1), (20, "C#5", 1), (21, "D5", 3)]
PHRASE_A2 = [(0, "A4", 1), (1, "D5", 1), (2, "F5", 1), (3, "F5", 2), (5, "G5", 1), (6, "A5", 1), (7, "G5", 1),
             (8, "F5", 1), (9, "E5", 2), (11, "C#5", 1), (12, "D5", 1), (13, "F5", 1), (14, "A5", 1), (15, "D6", 2),
             (17, "C6", 1), (18, "Bb5", 1), (19, "A5", 1), (20, "E5", 1), (21, "D5", 3)]
PHRASE_B = [(0, "C5", 1), (1, "F5", 1), (2, "A5", 1), (3, "G5", 2), (5, "E5", 1), (6, "F5", 1), (7, "E5", 1),
            (8, "D5", 1), (9, "F5", 2), (11, "D5", 1), (12, "Bb4", 1), (13, "D5", 1), (14, "G5", 1), (15, "F5", 2),
            (17, "A4", 1), (18, "G5", 1), (19, "E5", 1), (20, "Bb4", 1), (21, "C#5", 1), (22, "E5", 1), (23, "G5", 1)]
PHRASE_B2 = PHRASE_B[:-3] + [(21, "C#5", 2), (23, "E5", 1)]
PHRASE_OUT = [(0, "G5", 1), (1, "F5", 1), (2, "D5", 1), (3, "E5", 2), (5, "C#5", 1), (6, "D5", 3), (9, "A4", 3)]


def chord_spans(prog, bpb):
    """[(start_beat, beats, chord)] with repeated chords merged."""
    spans = []
    for bar, item in enumerate(prog):
        parts = [(item[0], bpb - 1), (item[1], 1)] if isinstance(item, tuple) else [(item, bpb)]
        beat = bar * bpb
        for chord, beats in parts:
            if spans and spans[-1][2] == chord and spans[-1][0] + spans[-1][1] == beat:
                spans[-1] = (spans[-1][0], spans[-1][1] + beats, chord)
            else:
                spans.append((beat, beats, chord))
            beat += beats
    return spans


def chord_at(prog, bar, beat, bpb):
    item = prog[bar]
    if isinstance(item, tuple):
        return item[0] if beat < bpb - 1 else item[1]
    return item


def menu():
    s = Session(72, 3, 52, seed=101)
    rng = s.rng
    s.reverb("hall", rt60=3.3, pre_delay=0.035, dark=0.38, early=14, early_span=0.07)
    s.bus("box", sends={"hall": 0.55}, eq=g_mul(g_highpass(150.0, 2), g_shelf_hi(10000.0, -2.0)))
    s.bus("arp", sends={"hall": 0.6}, eq=g_mul(g_highpass(120.0, 2), g_shelf_hi(8000.0, -4.0)), gain_db=-6.0,
          stereo_width=1.2)
    s.bus("celesta", sends={"hall": 0.5}, eq=g_highpass(180.0, 2), gain_db=-2.0)
    s.bus("strings", sends={"hall": 0.7}, eq=g_mul(g_lowpass(6000.0, 1), g_highpass(35.0, 2)), gain_db=3.0)
    s.bus("cello", sends={"hall": 0.55}, gain_db=-1.0)
    s.bus("harp", sends={"hall": 0.6}, eq=g_highpass(90.0, 2), gain_db=10.0)
    s.bus("piano", sends={"hall": 0.5}, gain_db=1.0)
    s.bus("clock", sends={"hall": 0.3}, eq=g_highpass(400.0, 2))
    s.bus("dust", sends={"hall": 0.9})

    # strings pad: softer intro and outro
    for start, beats, chord in chord_spans(MENU_PROG, 3):
        bar = start // 3
        vel = 0.42 if bar < 8 or bar >= 48 else (0.6 if 24 <= bar < 40 else 0.5)
        s.add("strings", s.at(0, start), ins.strings(ms(PAD[chord]), s.sec(beats) + 0.3, vel, rng, attack=1.1, release=1.8))

    # music-box arpeggio (6 eighths a bar): root, fifth, octave, tenth, octave, fifth
    for bar in range(2, 52):
        if bar >= 50:
            break
        for step in range(6):
            chord = chord_at(MENU_PROG, bar, step / 2.0, 3)
            root = root_midi(chord, 50, 61)
            iv = CHORDS[chord][1]
            fifth = iv[2]
            third = iv[1]
            note = root + [0, fifth, 12, 12 + third, 12, fifth][step]
            vel = (0.55 if step == 0 else 0.42) * rng.uniform(0.9, 1.05) * (0.8 if bar < 4 else 1.0)
            s.add("arp", s.at(bar, step * 0.5, 0.004), ins.music_box(note, vel, rng), pan=rng.uniform(-0.25, 0.25))

    # melody
    def phrase(bus, bar0, notes, shift=0, vel=0.8, voice=ins.music_box, pan=0.05):
        for beat, name, beats in notes:
            v = vel * rng.uniform(0.9, 1.05)
            s.add(bus, s.at(bar0, beat, 0.005), voice(m(name) + shift, v, rng), pan=pan)

    phrase("box", 8, PHRASE_A)
    phrase("box", 16, PHRASE_A2)
    phrase("box", 24, PHRASE_B)
    phrase("box", 32, PHRASE_B2)
    phrase("box", 40, PHRASE_A, shift=12, vel=0.62)
    phrase("celesta", 40, PHRASE_A, vel=0.7, voice=ins.celesta, pan=-0.1)
    phrase("box", 48, PHRASE_OUT, vel=0.72)
    # celesta answers in the second B phrase (a sixth below the tune)
    phrase("celesta", 32, [(b, n, d) for b, n, d in PHRASE_B2 if b % 3 == 0], shift=-9, vel=0.45, voice=ins.celesta, pan=-0.3)

    # harp (Karplus-Strong): a rolled chord on each downbeat of the B phrases
    for bar in range(24, 40):
        chord = chord_at(MENU_PROG, bar, 0, 3)
        r = root_midi(chord, 55, 66)
        iv = CHORDS[chord][1]
        for k, note in enumerate([r, r + iv[2], r + 12, r + 12 + iv[1], r + 19]):
            s.add("harp", s.at(bar, 0) + dsp.n_of(0.055 * k), ins.harp(note, 0.5 - 0.04 * k, rng), pan=0.35)

    # cello countermelody
    counter_b = ["F3", "E3", "F3", "D3", "D3", "F3", "E3", "C#3"]
    for i, name in enumerate(counter_b):
        for base in (24, 32):
            s.add("cello", s.at(base + i), ins.cello(m(name), s.sec(3) - 0.05, 0.55, rng), pan=-0.35)
    counter_a3 = [("F3", 3), ("D3", 3), ("D3", 3), ("C#3", 3), ("D3", 3), ("C3", 3), ("Bb2", 2), ("A2", 1), ("D3", 3)]
    beat = 0
    for name, beats in counter_a3:
        s.add("cello", s.at(40, beat), ins.cello(m(name), s.sec(beats) - 0.05, 0.5, rng), pan=-0.35)
        beat += beats

    # soft piano roots on the downbeats of the tune's sections
    for bar in range(8, 48):
        chord = chord_at(MENU_PROG, bar, 0, 3)
        s.add("piano", s.at(bar, 0, 0.004), ins.piano(root_midi(chord, 38, 49), 0.42, s.sec(2.6), rng, bright=0.5), pan=-0.2)

    # a clock somewhere in the hall
    for beat in range(52 * 3):
        s.add("clock", s.at(0, beat), ins.clock_tick(beat % 2 == 1, 0.5, rng), pan=0.55)

    # dust in the moonlight: stray high celesta notes
    for bar in list(range(0, 2)) + list(range(49, 52)) + [5, 13, 21, 29, 37, 45]:
        for _ in range(2 if bar in (0, 1, 50, 51) else 1):
            chord = chord_at(MENU_PROG, bar, 0, 3)
            root = root_midi(chord, 84, 95)
            note = root + int(rng.choice(CHORDS[chord][1] + [12]))
            s.add("dust", s.at(bar, float(rng.choice([0.5, 1.0, 1.5, 2.0, 2.5]))), ins.celesta(note, 0.3, rng),
                  pan=rng.uniform(-0.8, 0.8))

    stems = s.render()
    out = master(stems, -18.0, glue={"threshold_db": -26.0, "ratio": 1.6, "attack": 0.02, "release": 0.4})
    write("menu", dsp.rotate(out["main"], dsp.seam_rotation(out["main"])), seed=101)


# --- exploration + tension: "ObchĂłd" ---------------------------------------

def loop_freq(f, n):
    """Nearest frequency that makes a whole number of cycles in n samples
    (a drone rendered at it is periodic: the loop cannot seam)."""
    seconds = n / SR
    return max(round(float(f) * seconds), 1) / seconds


def drone(n, midi, rng, shape="saw", detune=6.0, voices=2, cutoff=300.0, side=0.45):
    """Periodic drone: detuned voices in the middle, one more detuned voice
    per side for width (mono-safe: the channels stay correlated)."""
    f = loop_freq(dsp.hz(midi), n)
    centre = np.zeros(n)
    for v in range(voices):
        fv = loop_freq(f * float(dsp.cents(rng.uniform(-detune, detune))), n)
        centre += dsp.osc(fv, n, shape, rng.uniform()) / voices
    out = np.stack([centre, centre], axis=1)
    for ch in range(2):
        fv = loop_freq(f * float(dsp.cents(rng.uniform(-detune, detune))), n)
        out[:, ch] += side * dsp.osc(fv, n, shape, rng.uniform())
    return dsp.fft_filter(out, g_mul(g_lowpass(cutoff, 2), g_highpass(22.0, 2)), circular=True) / (1.0 + side)


def layer_gain(base, layer, target, loop=True):
    """Gain (dB) for [param layer] so base + layer measures target LUFS."""
    lo, hi = -40.0, 20.0
    for _ in range(30):
        mid = (lo + hi) / 2.0
        if dsp.lufs(base + layer * db(mid), circular=loop) < target:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2.0


EXPLORE_SECTIONS = [(0, 8, None), (8, 4, "Bb"), (12, 4, "Dm"), (16, 8, "Eb"), (24, 4, "Gm"), (28, 4, "A")]
DARK_PAD = {"Bb": ["Bb1", "F2", "D3"], "Dm": ["D2", "A2", "F3"], "Eb": ["Eb2", "Bb2", "G3"], "Gm": ["G2", "D3", "Bb3"],
            "A": ["A1", "E2", "C#3"]}


def explore():
    s = Session(60, 4, 32, seed=202)
    rng = s.rng
    n = s.n
    s.reverb("hall", rt60=3.0, pre_delay=0.03, dark=0.4)
    s.reverb("far", rt60=4.6, pre_delay=0.09, dark=0.3, early=6, early_span=0.12, early_gain=0.25)
    # exploration stem
    s.bus("drone", "explore", sends={"hall": 0.25}, eq=g_shelf_lo(70.0, -5.0), gain_db=-2.0)
    s.bus("pad", "explore", sends={"hall": 0.6}, eq=g_mul(g_lowpass(2200.0, 2), g_highpass(40.0, 2)))
    s.bus("piano", "explore", sends={"far": 1.3}, eq=g_mul(g_lowpass(3500.0, 1), g_highpass(90.0, 2)), gain_db=2.0)
    s.bus("bell", "explore", sends={"far": 1.2}, eq=g_lowpass(2500.0, 1), gain_db=-14.0)
    s.bus("clock", "explore", sends={"far": 0.8}, eq=g_mul(g_lowpass(4500.0, 1), g_highpass(500.0, 2)), gain_db=-8.0)
    s.bus("glass", "explore", sends={"hall": 0.9}, gain_db=-10.0)
    s.bus("air", "explore", sends={"hall": 0.3}, gain_db=-19.0, stereo_width=1.3)
    # tension stem
    s.bus("ostinato", "tension", sends={"hall": 0.35}, eq=g_mul(g_highpass(45.0, 2), g_lowpass(3500.0, 1)))
    s.bus("tremolo", "tension", sends={"hall": 0.6}, eq=g_mul(g_highpass(900.0, 2), g_bell(3500.0, 3.0, 0.8)),
          gain_db=-10.0)
    s.bus("heart", "tension", sends={"hall": 0.15}, gain_db=-4.0)
    s.bus("ticks", "tension", sends={"hall": 0.12}, eq=g_highpass(700.0, 2), gain_db=-14.0)
    s.bus("boom", "tension", sends={"far": 0.9}, gain_db=-5.0)
    s.bus("swell", "tension", sends={"hall": 0.5}, gain_db=-16.0, stereo_width=1.2)
    s.bus("pizz", "tension", sends={"hall": 0.35}, eq=g_highpass(60.0, 2), gain_db=5.0)

    # --- drone: D pedal, the museum's low breath
    # one centre voice: two detuned ones this low beat into a full notch every ~16 s
    low = drone(n, m("D1"), rng, "tri", 3.0, 1, 180.0, side=0.3)
    body = drone(n, m("D2"), rng, "saw", 7.0, 3, 260.0)
    sheen = drone(n, m("A2"), rng, "saw", 9.0, 2, 900.0)
    move = 0.5 + 0.5 * dsp.lfo(n, 5, 0.1)
    swell = 0.55 + 0.45 * (0.5 + 0.5 * dsp.lfo(n, 2, 0.75))
    s.add("drone", 0, (low * 0.5 + body * 0.5 * swell[:, None] + sheen * 0.14 * move[:, None]))

    # --- dark pad chords over the pedal
    for bar, bars, chord in EXPLORE_SECTIONS:
        if chord is None:
            continue
        s.add("pad", s.at(bar), ins.strings(ms(DARK_PAD[chord]), s.sec(bars * 4) - 0.5, 0.5, rng, attack=3.0,
                                                release=4.0, bright=0.7), 0.9)

    # --- a piano somewhere far away: fragments of the museum motif
    fragments = [(4, [(0, "A4", 1), (1, "D5", 1), (2, "F5", 1), (3, "E5", 3)]),
                 (13, [(0, "F5", 1), (1, "E5", 1), (2, "D5", 1), (3, "A4", 4)]),
                 (20, [(0, "G4", 1.5), (1.5, "Bb4", 0.5), (2, "D5", 1), (3, "Eb5", 4)]),
                 (26, [(0, "Bb4", 1), (1, "A4", 1), (2, "G4", 1), (3, "D5", 3)]),
                 (29, [(0, "C#5", 1), (1, "E5", 1), (2, "A5", 3)])]
    for bar, notes in fragments:
        for beat, name, beats in notes:
            s.add("piano", s.at(bar, beat, 0.012), ins.piano(m(name), 0.4 * rng.uniform(0.85, 1.05), s.sec(beats), rng,
                                                              bright=0.6), pan=0.3)
    for bar, name in [(0, "D2"), (16, "Eb2"), (24, "G1"), (28, "A1")]:
        s.add("piano", s.at(bar), ins.piano(m(name), 0.35, s.sec(4), rng, bright=0.4), pan=-0.2)

    # --- a clock in the next room (bars 8-15), a bell striking at the wrong hour (bar 16)
    for beat in range(8 * 4, 16 * 4):
        s.add("clock", s.at(0, beat), ins.clock_tick(beat % 2 == 1, 0.6, rng), pan=-0.6)
    for bar, beat in [(16, 0), (16, 3), (17, 2)]:
        s.add("bell", s.at(bar, beat), ins.church_bell(m("D3"), 0.8, rng), pan=0.4)

    # --- glass tones
    for bar, bars, name, pos in [(2, 5, "D6", -0.5), (16, 4, "A5", 0.5), (18, 6, "Bb5", -0.4), (28, 4, "C#6", 0.3)]:
        s.add("glass", s.at(bar), ins.glass(m(name), s.sec(bars * 4) - 1.0, 0.6, rng, attack=2.5, release=3.0), pan=pos)

    # --- air: wind in the skylights, far off (periodic noise, slow gusts)
    air = dsp.noise(n, rng, g_mul(dsp.g_band(350.0, 2600.0, 1), dsp.pink), 2)
    gust = 0.35 + 0.65 * (0.5 + 0.5 * dsp.wander(n, rng, 0.06))
    s.add("air", 0, air * gust[:, None])

    # --- tension: low spiccato ostinato on the D pedal
    patterns = {None: ["D2", "D2", "D3", "D2", "Eb2", "D2", "D3", "C2"], "Bb": ["D2", "D2", "D3", "D2", "Eb2", "D2", "D3", "C2"],
                "Dm": ["D2", "D2", "D3", "D2", "Eb2", "D2", "F2", "E2"], "Eb": ["D2", "Eb2", "D3", "Eb2", "D2", "Eb2", "D3", "Eb2"],
                "Gm": ["D2", "D2", "D3", "D2", "Eb2", "D2", "Bb2", "G2"], "A": ["A1", "A1", "A2", "A1", "Bb1", "A1", "A2", "G#1"]}
    stroke_cache = {}
    for bar0, bars, chord in EXPLORE_SECTIONS:
        for bar in range(bar0, bar0 + bars):
            for step, name in enumerate(patterns[chord]):
                key = (name, step % 2, int(rng.integers(0, 3)))
                if key not in stroke_cache:
                    stroke_cache[key] = ins.staccato(m(name), 0.22, 1.0, rng, bright=0.9)
                accent = 1.0 if step in (0, 4) else 0.72
                s.add("ostinato", s.at(bar, step * 0.5, 0.004), stroke_cache[key], accent * rng.uniform(0.9, 1.05),
                      pan=-0.15)
    # pizzicato (Karplus-Strong) tiptoeing on the off-beats of each section's first half: the sneak, with a wink
    tiptoe = {"Eb": ["Bb2", "Eb3", "G2", "D3"], "A": ["E2", "A2", "G#2", "C#3"]}
    for bar0, bars, chord in EXPLORE_SECTIONS:
        for bar in range(bar0, bar0 + min(bars, 4)):
            for k, name in enumerate(tiptoe.get(chord, ["A2", "D3", "A2", "Eb3"])):
                s.add("pizz", s.at(bar, k + 0.5, 0.006), ins.pizzicato(m(name), 0.8 * rng.uniform(0.85, 1.05), rng),
                      pan=0.3 if k % 2 else 0.1)
    # heartbeat under it, ticking clock on the eighths
    beat_cache = [ins.heartbeat(0.8, rng) for _ in range(3)]
    for beat in range(32 * 4):
        s.add("heart", s.at(0, beat), beat_cache[beat % 3], 1.0 if beat % 2 == 0 else 0.8)
    tick_cache = [ins.clock_tick(k % 2 == 1, 0.7, rng) for k in range(6)]
    for step in range(32 * 8):
        s.add("ticks", s.at(0, step * 0.5), tick_cache[step % 6], 1.0 if step % 2 == 0 else 0.7, pan=0.35)
    # tremolo strings (sul ponticello) in the second half of each section
    for bar, bars, names in [(4, 4, ["A4", "Bb4"]), (12, 4, ["A4", "Bb4"]), (20, 4, ["A4", "Bb4"]), (28, 4, ["G#4", "A4"])]:
        pad = ins.strings(ms(names), s.sec(bars * 4) - 1.0, 0.8, rng, attack=2.0, release=1.5, bright=1.8, voices=2)
        t = np.arange(pad.shape[0]) / SR
        trem = 0.55 + 0.45 * np.sin(dsp.TAU * 7.5 * t) ** 2
        s.add("tremolo", s.at(bar), pad * trem[:, None])
    # low booms at the section starts
    for bar in (0, 8, 16, 24):
        s.add("boom", s.at(bar), ins.big_drum(46.0, 0.9, rng, 2.0))
    # a swell rising back into the loop start
    swell_n = n_of_beats(s, 8)
    rise = dsp.noise(swell_n, rng, dsp.pink, 2)
    t = np.linspace(0.0, 1.0, swell_n)
    rise = np.stack([dsp.lowpass_sweep(rise[:, c], 300.0 + 6000.0 * t ** 2, 2) for c in range(2)], axis=1)
    s.add("swell", s.at(30), dsp.fade_edges(rise * (t ** 2.5)[:, None], 0.01, 0.04))

    stems = s.render()
    base = master({"explore": stems["explore"]}, -22.0)["explore"]
    boost = layer_gain(base, stems["tension"], -19.0)
    tension = dsp.limit(stems["tension"] * db(boost), -1.5)
    print(f"    tension layer at {boost:+.1f} dB; explore+tension {dsp.lufs(base + tension, circular=True):.1f} LUFS, "
          f"peak {dsp.to_db(dsp.peak(base + tension)):.1f} dBFS")
    k = dsp.seam_rotation(base + tension)   # one rotation per family: the stems stay in sync
    write("explore", dsp.rotate(base, k), seed=202)
    write("explore_tension", dsp.rotate(tension, k), seed=203)


def n_of_beats(s, beats):
    return int(round(beats * s.spb))


def master_family(stems, base, layer, base_target, full_target, glue=None, ceiling=-1.5, loop=True):
    """Base stem at base_target alone, base + layer at full_target; glue
    and the final limiter are linked (computed on the sum)."""
    if glue:
        g = dsp.compress_gain(stems[base] + stems[layer], circular=loop, **glue)
        stems = {k: v * g[:, None] for k, v in stems.items()}
    b = master({base: stems[base]}, base_target, loop=loop, ceiling=ceiling)[base]
    gain = layer_gain(b, stems[layer], full_target, loop)
    top = stems[layer] * db(gain)
    lg = dsp.limit_gain(b + top, ceiling, circular=loop)
    b, top = b * lg[:, None], top * lg[:, None]
    print(f"    {layer} at {gain:+.1f} dB; full mix {dsp.lufs(b + top, circular=loop):.1f} LUFS, "
          f"peak {dsp.to_db(dsp.peak(b + top)):.1f} dBFS")
    return b, dsp.limit(top, ceiling, circular=loop)


class Kit:
    """A few takes of every drum, used in turn (round robin)."""

    def __init__(self, rng, **makers):
        self.takes = {name: [make() for _ in range(count)] for name, (make, count) in makers.items()}
        self.turn = {name: 0 for name in makers}

    def __call__(self, name):
        takes = self.takes[name]
        self.turn[name] = (self.turn[name] + 1) % len(takes)
        return takes[self.turn[name]]


def step_at(s, bar, step):
    """Sample of a 16th-note step (4/4)."""
    return s.at(bar, step / 4.0)


COMBAT_PROG = ([["Dm", "Dm", "Bb", "A"]] * 4 + [["Dm", "Eb", "Dm", ("C", "A")]] * 4
               + [["Bb", "A", "Gm", "A"]] * 4 + [["Dm", "Eb", "Bb", "A"]] * 4)
COMBAT_BARS = [c for four in COMBAT_PROG for c in four]
RIFF = [0, 0, 12, None, 0, 10, 0, 0, 1, 0, 12, None, 0, 7, 5, 3]
MAJOR = {"Bb", "A", "Eb", "C", "D", "F", "A7"}


def stab_voicing(chord, dissonant=False):
    r = root_midi(chord, 45, 56)
    iv = CHORDS[chord][1]
    notes = [r, r + 7, r + 12, r + 12 + iv[1]]
    if dissonant:
        notes.append(r + 25)   # the flat ninth on top
    return notes


def combat():
    s = Session(140, 4, 64, seed=303)
    rng = s.rng
    s.reverb("room", rt60=1.1, pre_delay=0.008, dark=0.5, early=16, early_span=0.04, early_gain=0.6)
    s.reverb("hall", rt60=2.3, pre_delay=0.025, dark=0.45)
    for name, sends, gain, eq in [("kick", {"room": 0.12}, -2.0, g_mul(g_highpass(38.0, 2), g_shelf_lo(55.0, -3.0))),
                                  ("snare", {"room": 0.45, "hall": 0.15}, 0.0, g_mul(g_highpass(120.0, 2),
                                                                                    g_shelf_hi(4000.0, 3.0))),
                                  ("ticks", {"room": 0.2}, -6.0, g_highpass(900.0, 2)),
                                  ("toms", {"room": 0.4}, -5.0, None),
                                  ("timp", {"hall": 0.45}, -8.0, g_shelf_lo(90.0, -4.0)),
                                  ("taiko", {"room": 0.3, "hall": 0.3}, -7.0, g_shelf_lo(70.0, -3.0)),
                                  ("crash", {"hall": 0.35}, -9.0, g_highpass(400.0, 2)),
                                  ("bass", {"room": 0.08}, 1.0, g_mul(g_highpass(35.0, 2), g_shelf_lo(60.0, -3.0),
                                                                     g_bell(800.0, 3.0, 1.0), g_lowpass(4000.0, 1))),
                                  ("ost", {"hall": 0.25}, -4.0, g_mul(g_highpass(110.0, 2), g_bell(1800.0, 2.0, 1.0))),
                                  ("stabs", {"hall": 0.35}, -1.0, g_highpass(90.0, 2)),
                                  ("swells", {"hall": 0.5}, -2.0, g_highpass(40.0, 2))]:
        s.bus(name, "base", sends=sends, eq=eq, gain_db=gain)
    s.bus("lead", "hi", sends={"hall": 0.45}, eq=g_mul(g_highpass(180.0, 2), g_bell(2500.0, 2.0, 0.8)), gain_db=-6.0)
    s.bus("evil", "hi", sends={"hall": 0.4}, gain_db=-8.0)
    s.bus("anvil", "hi", sends={"hall": 0.4}, eq=g_highpass(500.0, 2), gain_db=-14.0)
    s.bus("perc_hi", "hi", sends={"room": 0.3, "hall": 0.3}, gain_db=-7.0)

    kit = Kit(rng, kick=(lambda: ins.kick(0.95, rng), 4), snare=(lambda: ins.snare(0.9, rng), 4),
              tick=(lambda: ins.clock_tick(False, 0.8, rng), 4), tock=(lambda: ins.clock_tick(True, 0.8, rng), 4),
              crash=(lambda: ins.crash(0.8, rng), 2), anvil=(lambda: ins.anvil(0.8, rng), 3),
              taiko=(lambda: ins.big_drum(52.0, 0.9, rng, 1.4), 4))
    toms = [ins.tom(f, 0.85, rng) for f in (190.0, 150.0, 118.0, 92.0)]
    kicks = []
    stroke_cache = {}

    def kick(bar, step, vel=1.0):
        at = step_at(s, bar, step)
        kicks.append(at)
        s.add("kick", at, kit("kick"), vel)

    for bar, chord in enumerate(COMBAT_BARS):
        section = bar // 16
        fill = bar % 4 == 3
        chord_now = chord[0] if isinstance(chord, tuple) else chord
        # --- drums
        if section == 2:   # half-time breakdown
            for st in (0, 10):
                kick(bar, st)
            s.add("snare", step_at(s, bar, 8), kit("snare"))
            for st, v in [(0, 1.0), (3, 0.6), (6, 0.8), (8, 0.7), (11, 0.6), (14, 0.8)]:
                s.add("taiko", step_at(s, bar, st), kit("taiko"), v)
        else:
            pattern = [0, 4, 8, 10, 12] if section == 3 else [0, 7, 8, 10]
            for st in pattern:
                if fill and st >= 12:
                    continue
                kick(bar, st, 1.0 if st in (0, 8) else 0.85)
            for st in (4, 12):
                if not (fill and st == 12):
                    s.add("snare", step_at(s, bar, st), kit("snare"))
            if section == 3:
                s.add("snare", step_at(s, bar, 15), kit("snare"), 0.35)   # ghost
        for st in range(16):
            name = "tick" if st % 2 == 0 else "tock"
            s.add("ticks", step_at(s, bar, st), kit(name), 1.0 if st % 4 == 0 else (0.7 if st % 2 == 0 else 0.5),
                  pan=0.3)
        if fill and bar != 63:
            for k, st in enumerate((12, 13, 14, 15)):
                s.add("toms", step_at(s, bar, st), toms[k], 0.9, pan=0.5 - k * 0.33)
        if bar % 16 == 0:
            s.add("crash", s.at(bar), kit("crash"), pan=-0.3)
        # timpani on the chord roots
        if bar % 2 == 0 or section == 3:
            s.add("timp", s.at(bar), ins.timpani(root_midi(chord_now, 36, 47), 0.85, rng), pan=-0.25)
        # --- low riff (16ths), long notes in the breakdown
        if section == 2:
            r = root_midi(chord_now, 33, 44)
            for beat, note in [(0, r), (2, r + 12)]:
                s.add("bass", s.at(bar, beat), ins.synth_bass(note, s.sec(1.8), 0.85, rng, drive=2.5))
            s.add("swells", s.at(bar), ins.brass(stab_voicing(chord_now), s.sec(3.6), 0.8, rng, bright=0.6,
                                                 attack=0.35, release=0.4), pan=0.0)
        else:
            for st, off in enumerate(RIFF):
                if off is None:
                    continue
                ch = chord[0] if isinstance(chord, tuple) and st < 8 else (chord[1] if isinstance(chord, tuple) else chord)
                r = root_midi(ch, 33, 44)
                if off == 3 and ch in MAJOR:
                    off = 4
                vel = 1.0 if st % 4 == 0 else 0.8
                s.add("bass", step_at(s, bar, st), ins.synth_bass(r + off, s.sec(0.22), vel, rng))
                key = (r + off, st % 4 == 0)
                if key not in stroke_cache:
                    stroke_cache[key] = ins.staccato(r + off + 12, 0.12, 1.0, rng, bright=1.3)
                s.add("ost", step_at(s, bar, st), stroke_cache[key], vel, pan=-0.2)
        # --- stabs in B and D
        if section in (1, 3):
            for st, steps in [(0, 2), (3, 1), (6, 2), (14, 2)]:
                ch = chord[0] if isinstance(chord, tuple) and st < 8 else (chord[1] if isinstance(chord, tuple) else chord)
                s.add("stabs", step_at(s, bar, st), ins.brass(stab_voicing(ch, st == 0 and bar % 4 == 0), s.sec(steps / 4.0),
                                                              0.9, rng, bright=1.1), pan=0.1)
        # --- hi: anvils on 2 and 4 (breakdown, finale), timpani eighths in the finale
        if section in (2, 3):
            for st in (4, 12):
                s.add("anvil", step_at(s, bar, st), kit("anvil"), pan=0.45)
        if section == 3:
            for st in range(0, 16, 2):
                s.add("perc_hi", step_at(s, bar, st), ins.tom(78.0, 0.7 if st % 4 else 0.95, rng), pan=-0.4)
    # finale fill (bar 63): snare roll into the loop start
    for k in range(16):
        s.add("snare", step_at(s, 63, k), kit("snare"), 0.3 + 0.7 * k / 15.0)
        if k % 2 == 0:
            s.add("toms", step_at(s, 63, k), toms[(k // 2) % 4], 0.6 + 0.3 * k / 15.0, pan=0.5 - (k // 2 % 4) * 0.33)
    for bus in ("bass", "ost", "stabs", "swells"):
        s.duck(bus, kicks, -5.0, 0.12)

    # --- the museum motif as a feral brass lead (hi)
    lead_b = [(16, [(0, "A4", 4), (4, "D5", 4), (8, "F5", 4), (12, "E5", 4)]),
              (17, [(0, "Eb5", 8), (8, "D5", 4), (12, "Bb4", 4)]),
              (18, [(0, "A4", 4), (4, "D5", 2), (6, "F5", 2), (8, "A5", 4), (12, "G5", 4)]),
              (19, [(0, "E5", 8), (8, "C#5", 8)]),
              (20, [(0, "A4", 4), (4, "D5", 4), (8, "F5", 4), (12, "E5", 4)]),
              (21, [(0, "Eb5", 8), (8, "D5", 4), (12, "Bb4", 4)]),
              (22, [(0, "A5", 4), (4, "G5", 4), (8, "F5", 4), (12, "E5", 4)]),
              (23, [(0, "D5", 16)])]
    lead_c = [(40, [(0, "D5", 8), (8, "F5", 8)]), (41, [(0, "E5", 16)]), (42, [(0, "D5", 8), (8, "Bb4", 8)]),
              (43, [(0, "C#5", 16)]), (44, [(0, "F5", 8), (8, "A5", 8)]), (45, [(0, "E5", 8), (8, "C#5", 8)]),
              (46, [(0, "Bb4", 8), (8, "D5", 8)]), (47, [(0, "E5", 16)])]
    lead_d1 = [(0, [(0, "D5", 2), (2, "D5", 2), (4, "A4", 2), (6, "D5", 2), (8, "F5", 4), (12, "E5", 4)]),
               (1, [(0, "Eb5", 6), (6, "D5", 2), (8, "Bb4", 4), (12, "G4", 4)]),
               (2, [(0, "F5", 4), (4, "D5", 4), (8, "Bb4", 2), (10, "C5", 2), (12, "D5", 4)]),
               (3, [(0, "E5", 8), (8, "C#5", 4), (12, "A4", 4)])]
    lead_d2 = lead_d1[:3] + [(3, [(0, "E5", 4), (4, "G5", 4), (8, "A5", 8)])]
    lead_d = []
    for base, phrase_ in [(48, lead_d1), (52, lead_d2), (56, lead_d1), (60, lead_d1[:3] + [(3, [(0, "A5", 8)])])]:
        lead_d += [(base + k, notes) for k, notes in phrase_]
    for block, doubled in [(lead_b, False), ([(b + 8, notes) for b, notes in lead_b], True), (lead_c, False), (lead_d, None)]:
        for bar, notes in block:
            for st, name, steps in notes:
                at = step_at(s, bar, st)
                s.add("lead", at, ins.lead(m(name), s.sec(steps / 4.0) * 0.95, 0.9, rng), pan=0.05)
                if doubled or (doubled is None and bar >= 56):
                    s.add("evil", at, ins.evil_box(m(name) + 12, 0.8, rng), pan=0.25)

    stems = s.render()
    base, hi = master_family(stems, "base", "hi", -18.0, -16.5,
                             glue={"threshold_db": -20.0, "ratio": 2.0, "attack": 0.01, "release": 0.12})
    k = dsp.seam_rotation(base + hi)
    write("combat", dsp.rotate(base, k), seed=303)
    write("combat_hi", dsp.rotate(hi, k), seed=304)


# --- boss: "Tyranozaur w rotundzie" -----------------------------------------

BOSS_PROG = (["Dm", "Dm", "Dm", "Dm", "Bb", "Bb", "A", "A"]
             + ["Dm", "Dm", "Eb", "Eb", "Dm", "Dm", "Bb", "A"] * 2
             + ["Dm", "Dm", "Bb", "Bb", "Eb", "Eb", "A", "A"] * 2
             + ["Dm", "Dm", "Eb", "Eb", "Bb", "Bb", "A", "A"] * 2)
# the T-Rex motif (2 bars): heavy low brass in octaves
REX_MOTIF = [(0, "D2", 1.0), (1, "D2", 0.5), (1.5, "Eb2", 0.5), (2, "D2", 2.0), (4, "C2", 1.0), (5, "Bb1", 1.0), (6, "A1", 2.0)]
BONES = ["D5", "A5", "D6", "A5", "G#5", "A5", "F5", "A5"]


def boss():
    s = Session(105, 4, 56, seed=404)
    rng = s.rng
    s.reverb("hall", rt60=3.6, pre_delay=0.04, dark=0.35, early=16, early_span=0.09)
    s.reverb("room", rt60=1.3, pre_delay=0.01, dark=0.5, early=14, early_span=0.05, early_gain=0.55)
    for name, sends, gain, eq in [("taiko", {"room": 0.3, "hall": 0.35}, -2.0, g_shelf_lo(60.0, -3.0)),
                                  ("timp", {"hall": 0.5}, -11.0, g_shelf_lo(80.0, -4.0)),
                                  ("kick", {"room": 0.15}, -3.0, g_mul(g_highpass(38.0, 2), g_shelf_lo(55.0, -3.0))),
                                  ("snare", {"room": 0.4, "hall": 0.25}, -2.0, g_mul(g_highpass(120.0, 2), g_shelf_hi(4000.0, 3.0))),
                                  ("crash", {"hall": 0.4}, -9.0, g_highpass(400.0, 2)),
                                  ("organ", {"hall": 0.6}, 0.0, g_mul(g_highpass(30.0, 2), g_shelf_lo(70.0, -4.0), g_shelf_hi(2000.0, 3.0))),
                                  ("brass", {"hall": 0.45}, 0.0, g_mul(g_highpass(45.0, 2), g_bell(700.0, 2.0, 1.0))),
                                  ("bass", {"room": 0.1}, -3.0, g_mul(g_highpass(35.0, 2), g_shelf_lo(60.0, -3.0),
                                                                     g_bell(700.0, 3.0, 1.0))),
                                  ("stabs", {"hall": 0.35}, -2.0, g_highpass(90.0, 2)),
                                  ("strings", {"hall": 0.5}, -6.0, g_highpass(100.0, 2))]:
        s.bus(name, "base", sends=sends, eq=eq, gain_db=gain)
    s.bus("choir", "hi", sends={"hall": 0.7}, eq=g_highpass(120.0, 2), gain_db=5.0)
    s.bus("bones", "hi", sends={"hall": 0.4}, eq=g_highpass(300.0, 2), gain_db=-13.0)
    s.bus("toms", "hi", sends={"room": 0.4, "hall": 0.2}, gain_db=-6.0)

    kit = Kit(rng, kick=(lambda: ins.kick(0.95, rng), 4), snare=(lambda: ins.snare(0.95, rng), 4),
              crash=(lambda: ins.crash(0.85, rng, 4.0), 2), taiko=(lambda: ins.big_drum(48.0, 0.95, rng, 1.8), 5),
              taiko_hi=(lambda: ins.big_drum(82.0, 0.8, rng, 1.0), 4))
    toms = [ins.tom(f, 0.85, rng) for f in (170.0, 132.0, 104.0, 84.0)]
    kicks = []

    def chord_of(bar):
        return BOSS_PROG[bar]

    # organ: the museum's great organ holds the harmony (two bars a chord)
    for start, beats, chord in chord_spans(BOSS_PROG, 4):
        bar = start // 4
        voicing = ms(PAD[chord])
        if bar >= 40:
            voicing = voicing + [n + 12 for n in voicing[1:]]
        s.add("organ", s.at(0, start), ins.organ(voicing, s.sec(beats) - 0.1, 0.8 if bar >= 40 else 0.65, rng))

    for bar in range(56):
        section = 0 if bar < 8 else (1 if bar < 24 else (2 if bar < 40 else 3))
        chord = chord_of(bar)
        root = root_midi(chord, 36, 47)
        # --- drums
        if section in (0, 1, 3):
            pattern = [(0, 1.0), (3, 0.7), (6, 0.85), (10, 0.7), (12, 0.9)] if section != 3 else [(0, 1.0), (8, 0.95), (11, 0.6)]
            for st, v in pattern:
                s.add("taiko", step_at(s, bar, st), kit("taiko"), v, pan=-0.15)
            for st in ([14, 15] if section != 3 else [4, 12]):
                s.add("taiko", step_at(s, bar, st), kit("taiko_hi"), 0.7, pan=0.3)
            if section >= 1:
                s.add("timp", s.at(bar), ins.timpani(root, 0.9, rng), pan=0.2)
                if section == 3:
                    s.add("timp", s.at(bar, 2), ins.timpani(root_midi(chord, 36, 47) + (7 if root < 42 else -5), 0.8, rng), pan=0.2)
        else:   # the charge: kick and snare drive, taiko under
            for st in (0, 3, 8, 10):
                at = step_at(s, bar, st)
                kicks.append(at)
                s.add("kick", at, kit("kick"), 1.0 if st in (0, 8) else 0.8)
            for st in (4, 12):
                s.add("snare", step_at(s, bar, st), kit("snare"))
            s.add("taiko", s.at(bar), kit("taiko"), 0.8)
            if bar % 2 == 0:
                s.add("timp", s.at(bar), ins.timpani(root, 0.85, rng), pan=0.2)
        if bar % 8 == 0 and bar >= 8:
            s.add("crash", s.at(bar), kit("crash"), pan=0.25)
        # --- low strings: tremolo bed in the awakening
        if bar in (0, 4):
            pad = ins.strings(ms(PAD[chord][:2]), s.sec(16) - 0.5, 0.8, rng, attack=1.5, release=1.5, bright=1.2, voices=2)
            t = np.arange(pad.shape[0]) / SR
            s.add("strings", s.at(bar), pad * (0.6 + 0.4 * np.sin(dsp.TAU * 6.5 * t) ** 2)[:, None])
        # --- the charge: bass eighths and off-beat stabs
        if section == 2:
            r = root_midi(chord, 26, 37)
            for k in range(8):
                note = r + (12 if k % 2 else 0)
                s.add("bass", s.at(bar, k * 0.5), ins.synth_bass(note, s.sec(0.4), 1.0 if k % 2 == 0 else 0.8, rng, drive=2.5))
            for st in (6, 14):
                s.add("stabs", step_at(s, bar, st), ins.brass(stab_voicing(chord, st == 6 and bar % 2 == 0), s.sec(0.4), 0.9, rng,
                                                              bright=1.0), pan=0.1)
        # --- hi: bones and toms
        if section == 2 or (section == 3 and bar < 54):
            for k, name in enumerate(BONES + BONES):
                note = m(name) + (root_midi(chord, 38, 49) - 38 if section == 3 else 0)
                s.add("bones", step_at(s, bar, k), ins.xylophone(note, 0.85 if k % 4 == 0 else 0.65, rng),
                      pan=0.4 if k % 2 else -0.2)
        if section == 3:
            for st in range(16):
                if st % 4 != 0:
                    s.add("toms", step_at(s, bar, st), toms[(st // 2) % 4], 0.5 + 0.3 * (st % 2), pan=0.5 - ((st // 2) % 4) * 0.33)

    # the motif: low brass in octaves (section 1), augmented in the finale
    for rep in range(8):
        bar0 = 8 + rep * 2
        for beat, name, beats in REX_MOTIF:
            notes = [m(name), m(name) + 12]
            s.add("brass", s.at(bar0, beat), ins.brass(notes, s.sec(beats) * 0.92, 0.95 if beat == 0 else 0.85, rng,
                                                        bright=0.8, attack=0.02, release=0.3, drive=2.2))
    for rep in range(3):
        bar0 = 40 + rep * 4
        for beat, name, beats in REX_MOTIF:
            notes = [m(name), m(name) + 12, m(name) + 19]
            s.add("brass", s.at(bar0, beat * 2), ins.brass(notes, s.sec(beats * 2) * 0.95, 0.95, rng, bright=1.0,
                                                            attack=0.05, release=0.5, drive=2.4))
    # build back into the loop: brass climbs, timpani roll
    for k, name in enumerate(["A1", "Bb1", "B1", "C#2"]):
        s.add("brass", s.at(52 + k // 2, (k % 2) * 2), ins.brass([m(name), m(name) + 12, m(name) + 19], s.sec(2) * 0.95,
                                                                 0.8 + 0.05 * k, rng, bright=1.1, attack=0.03, release=0.3))
    for k in range(32):
        s.add("timp", s.at(54, k / 4.0), ins.timpani(m("A1") if k % 2 else m("D2"), 0.35 + 0.6 * k / 31.0, rng, 1.2),
              pan=0.2 if k % 2 else -0.2)
    # choir (hi) from the charge to the end
    for start, beats, chord in chord_spans(BOSS_PROG[24:], 4):
        voicing = [n + 12 for n in ms(PAD[chord])[1:]]
        s.add("choir", s.at(24, start), ins.choir(voicing, s.sec(beats) - 0.2, 0.85, rng, ins.VOWEL_A if start // 4 % 4 < 2 else ins.VOWEL_O))
    for bus in ("bass", "stabs"):
        s.duck(bus, kicks, -5.0, 0.12)

    stems = s.render()
    base, hi = master_family(stems, "base", "hi", -17.5, -16.0,
                             glue={"threshold_db": -19.0, "ratio": 2.0, "attack": 0.012, "release": 0.15})
    k = dsp.seam_rotation(base + hi)
    write("boss", dsp.rotate(base, k), seed=404)
    write("boss_hi", dsp.rotate(hi, k), seed=405)


# --- stings -------------------------------------------------------------------

def victory():
    """Timpani roll, a D major hit (the Picardy third: the night is won),
    the lullaby motif in major on the music box, a long hall tail."""
    s = Session(120, 4, 4, seed=505, loop=False)
    rng = s.rng
    s.reverb("hall", rt60=3.4, pre_delay=0.035, dark=0.4)
    s.bus("timp", sends={"hall": 0.5}, gain_db=-10.0, eq=g_shelf_lo(80.0, -3.0))
    s.bus("brass", sends={"hall": 0.5}, gain_db=-1.0)
    s.bus("organ", sends={"hall": 0.6}, gain_db=-4.0)
    s.bus("box", sends={"hall": 0.6}, eq=g_highpass(150.0, 2), gain_db=-9.0)
    s.bus("crash", sends={"hall": 0.4}, gain_db=-10.0, eq=g_highpass(400.0, 2))
    s.bus("strings", sends={"hall": 0.6}, gain_db=-2.0)
    hit = s.at(0, 2.5)
    for k in range(20):
        at = int(k * hit / 20)
        s.add("timp", at, ins.timpani(m("A1") if k % 2 else m("D2"), 0.25 + 0.6 * k / 19.0, rng, 1.0), pan=0.2 if k % 2 else -0.2)
    s.add("timp", hit, ins.timpani(m("D2"), 1.0, rng, 3.5))
    s.add("crash", hit, ins.crash(0.9, rng, 4.0))
    s.add("brass", hit, ins.brass(ms(["D3", "A3", "D4", "F#4", "A4"]), 2.6, 0.95, rng, bright=1.2, attack=0.02, release=1.2))
    s.add("organ", hit, ins.organ(ms(["D2", "A2", "D3", "F#3", "A3", "D4"]), 3.2, 0.9, rng, release=1.5))
    s.add("strings", hit, ins.strings(ms(["D3", "F#3", "A3", "D4"]), 3.4, 0.7, rng, attack=0.3, release=2.0, bright=1.2))
    motif = [(0.0, "A5"), (0.25, "D6"), (0.5, "F#6"), (0.75, "E6"), (1.0, "D6"), (1.5, "A6")]
    for beat, name in motif:
        s.add("box", hit + s.at(0, 1.0 + beat), ins.music_box(m(name), 0.8, rng), pan=0.15)
    stems = s.render()
    out = master(stems, -17.0, loop=False)["main"]
    out = dsp.fade_edges(out[:dsp.n_of(8.0)], 0.001, 1.5)
    write("victory_sting", out, loop=False, seed=505)


def death():
    """The music box winds down: the lullaby slows, sags in pitch and
    stops with a clunk, over a dark swell."""
    s = Session(120, 4, 2, seed=606, loop=False)
    rng = s.rng
    s.reverb("hall", rt60=3.0, pre_delay=0.03, dark=0.35)
    s.bus("box", sends={"hall": 0.7}, eq=g_highpass(150.0, 2), gain_db=-4.0)
    s.bus("low", sends={"hall": 0.5}, gain_db=-4.0)
    s.bus("clunk", sends={"hall": 0.4}, gain_db=-6.0)
    notes = ["A5", "D6", "F6", "E6", "D6", "C#6", "D6", "A5"]
    at = 0.0
    gap = 0.2
    for k, name in enumerate(notes):
        sag = -6.0 * k * k / 7.0   # cents: the spring runs out
        tone = ins.music_box(m(name) + sag / 100.0, 0.8 - 0.05 * k, rng)
        s.add("box", dsp.n_of(at), tone, pan=0.1)
        at += gap
        gap *= 1.28
    stop = dsp.n_of(at + 0.15)
    click = ins.clock_tick(True, 1.0, rng)
    s.add("clunk", stop, ins.tom(70.0, 0.5, rng) * 0.6 + dsp.pad_to(click, dsp.n_of(0.6)) * 0.8)
    s.add("low", 0, ins.strings(ms(["D2", "A2", "D3"]), 2.2, 0.8, rng, attack=0.4, release=1.6, bright=0.6))
    s.add("low", 0, ins.timpani(m("D2"), 0.55, rng, 3.0))
    stems = s.render()
    out = master(stems, -19.0, loop=False)["main"]
    out = dsp.fade_edges(out[:dsp.n_of(5.5)], 0.001, 1.2)
    write("death_sting", out, loop=False, seed=606)


TRACKS = {"menu": menu, "explore": explore, "combat": combat, "boss": boss, "victory": victory, "death": death}


def all_tracks():
    """The lobby's score plus Floor I's (gen_wings.py): every name the
    command line takes. 'wings' renders all of Floor I."""
    import gen_wings   # noqa: E402  (imports this module back: kept out of the top level)
    tracks = dict(TRACKS)
    tracks.update(gen_wings.tracks())
    tracks["wings"] = lambda: [gen_wings.tracks()[k]() for k in ("walks", "guardians", "stings")]
    return tracks


def main(names):
    dsp.intermediates_dir(ROOT)
    tracks = all_tracks()
    for name in names or list(TRACKS) + ["wings"]:
        started = time.time()
        print(f"== {name}")
        tracks[name]()
        print(f"   ({time.time() - started:.1f} s)")


if __name__ == "__main__":
    main(sys.argv[1:])
