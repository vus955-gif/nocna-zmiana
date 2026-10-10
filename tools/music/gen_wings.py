"""Floor I score: the six wings' night walks, the guardians' theme and the
progress stings. The same lullaby (the menu's "Nokturn dozorcy", d minor)
runs through all of it, re-scaled per wing (modes.py) and dressed in the
wing's instruments (instruments.py). Every wing sits on the tonic D, so the
game can crossfade from one wing's walk to another's.

Tracks (WAV intermediates in build/audio_src/music/, see gen_music.py):
    explore_<wing> + explore_<wing>_tension   the night walk of a wing and
                                              its tension stem (one family)
    guardian_<wing> + guardian_<wing>_hi      the guardians' battle theme in
                                              the wing's colours (phase 2+:
                                              the hi stem)
    guardian_sting                            a guardian falls
    seal_sting, gate_sting                    a seal / shard picked up, a gate
                                              opened (laid over the music)
    wing_sting_<wing>                         a wing seen for the first time

Run through gen_music.py (shares its Session, mastering and writer):

    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/music/gen_music.py wings
    ... gen_music.py explore_egypt guardian_asia stings     (single pieces)

Loudness: walks -22 LUFS (with tension -19, like "Obchod"), guardians -18
(full -16.5), stings -19..-21 (the game ducks the music under them).
"""
import numpy as np

import dsp
import gen_music as gm
import instruments as ins
import modes as md
from dsp import SR, db, g_bell, g_highpass, g_lowpass, g_mul, g_shelf_hi, g_shelf_lo
from gen_music import Kit, Session, drone, layer_gain, m, master, master_family, ms, step_at, write


class Mix(Session):
    """A Session whose buses are levelled by loudness instead of by hand:
    before the mix every bus is set to its integrated loudness from
    [param levels] (LUFS, dry; a sparse line is measured where it plays),
    so the balance does not depend on how hot each synthesised voice
    comes out. Buses missing from the table keep their own level."""

    def __init__(self, bpm, beats_per_bar, bars, seed, levels, loop=True):
        super().__init__(bpm, beats_per_bar, bars, seed, loop)
        self.levels = levels

    def render(self, verbose=True):
        for name, b in self.buses.items():
            target = self.levels.get(name)
            x = b["tl"].buf
            if target is None or not np.any(x):
                continue
            b["tl"].buf = x * db(target - dsp.lufs(x, circular=self.loop))
        return super().render(verbose)


# dry loudness of each bus (LUFS) in a walk, a guardian theme and the stings
WALK_LEVELS = {
    # walk: beds, the wing's plucked voice, its lead, colours
    "drone": -27.0, "pad": -24.5, "sho": -25.0, "choir": -24.0, "strings": -25.0,
    "harp": -21.5, "lyre": -21.0, "kithara": -21.5, "koto": -21.5, "marimba": -21.5, "harpsi": -21.0,
    "ney": -20.0, "duduk": -20.5, "pan": -20.5, "shaku": -20.0, "clay": -20.5, "box": -20.5,
    "glass": -29.0, "bowl": -27.5, "celesta": -28.0, "clock": -31.0, "doum": -27.0, "drums": -27.5, "slit": -27.0,
    "rattle": -31.0,
    # tension: the pulse, low strings, colour
    "darbuka": -21.0, "frame": -22.0, "tympanon": -22.0, "taiko": -21.0, "slit_t": -21.0, "huehuetl": -22.5,
    "big": -23.0, "timp": -24.0, "sistrum": -28.0, "bronze": -28.0, "gourd": -27.5, "pon": -26.0, "ticks": -29.5,
    "ostinato": -21.5, "spiccato": -21.5, "trem": -24.5, "runs": -24.0, "tremolo": -27.5, "evil": -27.0,
    "conch": -25.0, "swell": -27.0,
}
GUARD_LEVELS = {"drums": -15.5, "low": -22.0, "bass": -19.5, "ost": -20.5, "pads": -21.5, "stabs": -21.0,
                "lead": -17.0, "lead2": -23.0, "choir": -21.0, "perc": -24.5}
STING_LEVELS = {"drum": -19.0, "brass": -18.0, "choir": -21.0, "cel": -21.5, "crash": -28.0, "glass": -26.0, "bowl": -24.0,
                "harp": -23.0, "organ": -22.0, "timp": -21.0, "strings": -22.0, "lead": -18.0, "pluck": -22.0,
                "drone": -26.0, "color": -25.0}


WINGS = ["egypt", "assyria", "greece", "enlightenment", "asia", "americas"]
MODE = {"egypt": "hijaz", "assyria": "kurd", "greece": "dorian", "enlightenment": "harmonic", "asia": "penta",
        "americas": "aeolian"}

# chord symbol -> (root, intervals); gen_music's chords plus the wings' own
CHORDS = dict(gm.CHORDS)
CHORDS.update({
    "Em": ("E", [0, 3, 7]), "G": ("G", [0, 4, 7]), "Am": ("A", [0, 3, 7]), "D5": ("D", [0, 7]), "C5": ("C", [0, 7]),
    "Eb5": ("Eb", [0, 7]), "A5": ("A", [0, 7]), "Bb5": ("Bb", [0, 7]), "Dsus": ("D", [0, 5, 7]), "Csus": ("C", [0, 5, 7]),
    "Gsus": ("G", [0, 5, 7]), "Aq": ("A", [0, 5, 10]),
})


def root(chord, low, high):
    """The chord's root placed in [low, high] (MIDI)."""
    pc = m(CHORDS[chord][0] + "4") % 12
    r = low + ((pc - low) % 12)
    return r if r <= high else r - 12


def tones(chord):
    return CHORDS[chord][1]


def voicing(chord, low=38):
    """Open four-note voicing from a root in [low, low + 11]."""
    r = root(chord, low, low + 11)
    iv = tones(chord)
    if len(iv) == 2:
        return [r, r + 7, r + 12, r + 19]
    if 7 not in iv:
        return [r, r + iv[2], r + iv[-1], r + 12 + iv[1]]
    third = iv[1]
    return [r, r + 7, r + 12 + third, r + 12 + iv[-1] if len(iv) > 3 else r + 19]


def arp(chord, low):
    """Chord tones climbing from a root in [low, low + 11] (two octaves)."""
    r = root(chord, low, low + 11)
    iv = tones(chord)
    third = iv[1] if len(iv) > 2 and iv[1] != 7 else (5 if 5 in iv else 7)
    return [r, r + 7, r + 12, r + 12 + third, r + 19, r + 24]


def pcs_of(chord):
    r = m(CHORDS[chord][0] + "4") % 12
    return {(r + i) % 12 for i in tones(chord)}


def sections_chord(sections, bar):
    for start, bars, chord in sections:
        if start <= bar < start + bars:
            return chord
    return sections[-1][2]


def check_line(name, notes, chord_at, bpb):
    """Prints held melody notes that clash with the chord under them
    (not a chord tone and a semitone or a tritone from one): the ears we
    do not have, for the strong beats."""
    clashes = []
    for at_beat, midi, beats in notes:
        bar, beat = divmod(at_beat, bpb)
        strong = beat == 0 or (bpb == 4 and beat == 2) or (bpb == 6 and beat == 3)
        if beats < 1.0 or not strong:
            continue
        chord = chord_at(int(bar))
        pcs = pcs_of(chord)
        pc = int(midi) % 12
        if pc in pcs:
            continue
        rough = any(((pc - c) % 12) in (1, 11, 6) for c in pcs)
        if rough:
            clashes.append(f"bar {int(bar)} beat {beat:g}: {midi} over {chord}")
    if clashes:
        print(f"    {name}: {len(clashes)} held clash(es): " + "; ".join(clashes[:6]))


def place(s, bus, bar, beat, notes, voice, mode, shift=0, unit=1.0, vel=0.8, pan=0.0, jitter=0.006, log=None):
    """Melody [(beat, step, beats)] from (bar, beat) through [param voice]
    (voice(midi, seconds, vel) -> signal) in the wing's mode."""
    rng = s.rng
    for b, step, beats in notes:
        midi = md.note(step, mode) + shift
        v = vel * rng.uniform(0.9, 1.05)
        s.add(bus, s.at(bar, beat + b * unit, jitter), voice(midi, s.sec(beats * unit), v), pan=pan)
        if log is not None:
            log.append((bar * s.bpb + beat + b * unit, midi, beats * unit))


def riser(s, bus, bar, beats, top=6000.0):
    """Filtered noise swelling into the loop start."""
    n = gm.n_of_beats(s, beats)
    rise = dsp.noise(n, s.rng, dsp.pink, 2)
    t = np.linspace(0.0, 1.0, n)
    rise = np.stack([dsp.lowpass_sweep(rise[:, c], 300.0 + top * t ** 2, 2) for c in range(2)], axis=1)
    s.add(bus, s.at(bar), dsp.fade_edges(rise * (t ** 2.5)[:, None], 0.01, 0.04))


def tremolo_pad(s, bus, bar, bars, names, rate=7.5, vel=0.8):
    pad = ins.strings(ms(names), s.sec(bars * s.bpb) - 1.0, vel, s.rng, attack=2.0, release=1.5, bright=1.8, voices=2)
    t = np.arange(pad.shape[0]) / SR
    s.add(bus, s.at(bar), pad * (0.55 + 0.45 * np.sin(dsp.TAU * rate * t) ** 2)[:, None])


def string_ostinato(s, bus, sections, pattern_of, steps_per_bar, step_beats, length=0.22, vel=1.0, pan=-0.15):
    """Low spiccato strings: pattern_of(chord, bar) -> note names per step."""
    cache = {}
    for start, bars, chord in sections:
        for bar in range(start, start + bars):
            for k, name in enumerate(pattern_of(chord, bar)):
                if name is None:
                    continue
                key = (name, int(s.rng.integers(0, 3)))
                if key not in cache:
                    cache[key] = ins.staccato(m(name), length, 1.0, s.rng, bright=0.9)
                accent = 1.0 if k % (steps_per_bar // 2 or 1) == 0 else 0.72
                s.add(bus, s.at(bar, k * step_beats, 0.004), cache[key], vel * accent * s.rng.uniform(0.9, 1.05), pan=pan)


def finish_walk(s, name, seed):
    """Masters a walk family like "Obchod": the walk at -22 LUFS, the
    tension stem so the pair measures -19 (the pair limited together: the
    game sums them), one seam rotation for both."""
    stems = s.render()
    base, tension = master_family(stems, "explore", "tension", -22.0, -19.0)
    k = dsp.seam_rotation(base + tension)
    write(f"explore_{name}", dsp.rotate(base, k), seed=seed)
    write(f"explore_{name}_tension", dsp.rotate(tension, k), seed=seed + 1)


# --- voices as voice(midi, seconds, vel) ---------------------------------------

def v_flute(rng, kind, **kw):
    return lambda midi, sec, vel: ins.flute(midi, max(sec * 0.96, 0.12), vel, rng, kind, **kw)


def v_pluck(rng, make):
    return lambda midi, sec, vel: make(midi, vel, rng)


def v_reed(rng, dark):
    return lambda midi, sec, vel: ins.reed(midi, max(sec * 0.95, 0.1), vel, rng, dark=dark)


# --- Egypt: "Piaski nocy" (Hijaz on D: D Eb F# G A Bb C) ----------------------

EGYPT_SECTIONS = [(0, 4, "D"), (4, 2, "D"), (6, 1, "Cm"), (7, 5, "D"), (12, 4, "Eb"), (16, 2, "Cm"), (18, 2, "D"), (20, 4, "Gm"), (24, 2, "Eb"),
                  (26, 2, "D")]


def walk_egypt():
    s = Mix(70, 4, 28, seed=1101, levels=WALK_LEVELS)
    rng = s.rng
    mode = "hijaz"
    n = s.n
    s.reverb("hall", rt60=3.4, pre_delay=0.04, dark=0.38, early=14, early_span=0.08)
    s.reverb("far", rt60=5.0, pre_delay=0.09, dark=0.3, early=6, early_span=0.12, early_gain=0.25)
    s.bus("drone", "explore", sends={"hall": 0.25}, eq=g_shelf_lo(70.0, -5.0))
    s.bus("pad", "explore", sends={"hall": 0.6}, eq=g_mul(g_lowpass(2000.0, 2), g_highpass(45.0, 2)))
    s.bus("harp", "explore", sends={"hall": 0.7}, eq=g_highpass(90.0, 2), stereo_width=1.1)
    s.bus("ney", "explore", sends={"far": 0.9, "hall": 0.3}, eq=g_mul(g_highpass(200.0, 2), g_shelf_hi(6000.0, -3.0)))
    s.bus("glass", "explore", sends={"hall": 0.9})
    s.bus("doum", "explore", sends={"far": 0.7}, eq=g_lowpass(900.0, 2))
    s.bus("darbuka", "tension", sends={"hall": 0.25}, eq=g_highpass(70.0, 2))
    s.bus("frame", "tension", sends={"hall": 0.3}, eq=g_shelf_lo(60.0, -3.0))
    s.bus("sistrum", "tension", sends={"hall": 0.4}, eq=g_highpass(2500.0, 2), stereo_width=1.2)
    s.bus("ostinato", "tension", sends={"hall": 0.35}, eq=g_mul(g_highpass(45.0, 2), g_lowpass(3200.0, 1)))
    s.bus("tremolo", "tension", sends={"hall": 0.6}, eq=g_mul(g_highpass(900.0, 2), g_bell(3500.0, 3.0, 0.8)))
    s.bus("swell", "tension", sends={"hall": 0.5}, stereo_width=1.2)

    # drone: D and A, the desert's low breath
    low = drone(n, m("D1"), rng, "tri", 3.0, 1, 170.0, side=0.3)
    body = drone(n, m("D2"), rng, "saw", 6.0, 3, 240.0)
    fifth = drone(n, m("A2"), rng, "saw", 8.0, 2, 700.0)
    breath = 0.55 + 0.45 * (0.5 + 0.5 * dsp.lfo(n, 3, 0.6))
    s.add("drone", 0, low * 0.5 + body * 0.45 * breath[:, None] + fifth * 0.12 * (0.5 + 0.5 * dsp.lfo(n, 4, 0.1))[:, None])

    for bar, bars, chord in EGYPT_SECTIONS:
        if bar == 0:
            continue
        s.add("pad", s.at(bar), ins.strings(voicing(chord, 38), s.sec(bars * 4) - 0.4, 0.5, rng, attack=2.5, release=3.5,
                                            bright=0.7), 0.9)
    # harp: slow rolled arpeggios, sparser in the intro and the Gm stretch
    for bar in range(28):
        chord = sections_chord(EGYPT_SECTIONS, bar)
        notes = arp(chord, 50)
        picks = [0, 1, 2, 3] if bar % 2 == 0 else [2, 4]
        if bar < 4 or 20 <= bar < 24:
            picks = [0, 2, 3] if bar % 2 == 0 else [4]
        for k, i in enumerate(picks):
            s.add("harp", s.at(bar, k * (4.0 / len(picks)), 0.008), ins.harp(notes[i], (0.5 if k == 0 else 0.4) * rng.uniform(0.9, 1.05), rng),
                  pan=0.35 - 0.1 * k)
    ney = v_flute(rng, "ney")
    line = []
    # the lullaby on the ney, in Hijaz (A D F# F# D Eb D Bb C | A D F# A G F# Eb C D)
    place(s, "ney", 4, 0, md.LULLABY_A[:9], ney, mode, vel=0.8, log=line)
    place(s, "ney", 8, 0, [(b - 12, st, d) for b, st, d in md.LULLABY_A[9:]], ney, mode, vel=0.85, log=line)
    calls = [(13, [(0, 10, 3), (3, 8, 1)]), (14, [(0, 5, 2), (2, 8, 2)]), (16, [(0, 6, 3), (3, 5, 1)]), (17, [(0, 8, 4)]),
             (18, [(0, 9, 2), (2, 7, 2)]), (26, [(b, st, d) for b, st, d in md.HEAD])]
    for bar, notes in calls:
        place(s, "ney", bar, 0, notes, ney, mode, vel=0.7, log=line)
    check_line("egypt ney", line, lambda b: sections_chord(EGYPT_SECTIONS, b), 4)
    for bar, bars, name, pos in [(2, 5, "D6", -0.5), (12, 4, "Bb5", 0.5), (20, 4, "G5", -0.4), (24, 4, "A5", 0.3)]:
        s.add("glass", s.at(bar), ins.glass(m(name), s.sec(bars * 4) - 1.0, 0.6, rng, attack=2.5, release=3.0), pan=pos)
    for bar in (0, 4, 12, 16, 20, 24):
        s.add("doum", s.at(bar), ins.frame_drum(66.0, 0.8, rng, "doum", ring=1.6), pan=-0.1)

    # --- tension: maqsum on the darbuka, a low frame drum, sistrum, low strings
    maqsum = [("doum", 0.0), ("tek", 0.5), ("tek", 1.5), ("doum", 2.0), ("tek", 3.0)]
    kit = Kit(rng, doum=(lambda: ins.frame_drum(108.0, 0.85, rng, "doum", ring=0.6), 3),
              tek=(lambda: ins.frame_drum(118.0, 0.8, rng, "tek"), 4), low=(lambda: ins.frame_drum(64.0, 0.9, rng, "doum"), 3),
              shake=(lambda: ins.rattle(0.8, rng, 0.18, "sistrum"), 3))
    for bar in range(28):
        for kind, beat in maqsum:
            s.add("darbuka", s.at(bar, beat, 0.003), kit(kind), 1.0 if kind == "doum" else 0.75, pan=0.2)
        if bar % 4 == 3:
            for beat in (3.5, 3.75):
                s.add("darbuka", s.at(bar, beat, 0.003), kit("tek"), 0.6, pan=0.25)
        s.add("frame", s.at(bar), kit("low"), pan=-0.2)
        for beat in (1.0, 3.0):
            s.add("sistrum", s.at(bar, beat, 0.004), kit("shake"), pan=-0.4)

    def pattern(chord, bar):
        r = root(chord, 38, 49)
        up = r + (1 if chord in ("D", "Eb") else 2)
        return [gm_name(r), gm_name(r), gm_name(r + 12), gm_name(r), gm_name(up), gm_name(r), gm_name(r + 10), gm_name(r + 7)]
    string_ostinato(s, "ostinato", EGYPT_SECTIONS, pattern, 8, 0.5)
    for bar, bars, names in [(8, 4, ["A4", "Bb4"]), (16, 4, ["G4", "A4"]), (24, 4, ["F#4", "G4"])]:
        tremolo_pad(s, "tremolo", bar, bars, names)
    riser(s, "swell", 26, 8)
    finish_walk(s, "egypt", 1101)


def gm_name(midi):
    """MIDI -> a note name gen_music.m() reads back (sharps)."""
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return f"{names[midi % 12]}{midi // 12 - 1}"


# --- Assyria: "Lwy Niniwy" (Kurd / Phrygian on D: D Eb F G A Bb C) ------------

ASSYRIA_SECTIONS = [(0, 4, "Dm"), (4, 2, "Dm"), (6, 1, "Bb"), (7, 3, "Dm"), (10, 2, "Eb"), (12, 4, "Dm"), (16, 4, "Cm"), (20, 4, "Bb"), (24, 2, "Eb"),
                    (26, 2, "Dm")]


def walk_assyria():
    s = Mix(72, 4, 28, seed=1201, levels=WALK_LEVELS)
    rng = s.rng
    mode = "kurd"
    n = s.n
    s.reverb("hall", rt60=3.0, pre_delay=0.03, dark=0.42, early=16, early_span=0.06, early_gain=0.55)
    s.reverb("far", rt60=4.4, pre_delay=0.08, dark=0.3, early=6, early_span=0.1, early_gain=0.25)
    s.bus("drone", "explore", sends={"hall": 0.2}, eq=g_shelf_lo(65.0, -4.0))
    s.bus("pad", "explore", sends={"hall": 0.55}, eq=g_mul(g_lowpass(1600.0, 2), g_highpass(40.0, 2)))
    s.bus("lyre", "explore", sends={"hall": 0.55}, eq=g_highpass(80.0, 2), stereo_width=1.1)
    s.bus("duduk", "explore", sends={"far": 0.8, "hall": 0.3}, eq=g_highpass(120.0, 2))
    s.bus("drums", "explore", sends={"hall": 0.35}, eq=g_mul(g_lowpass(1400.0, 2), g_shelf_lo(60.0, -2.0)))
    s.bus("frame", "tension", sends={"hall": 0.3}, eq=g_shelf_lo(55.0, -2.0))
    s.bus("big", "tension", sends={"hall": 0.35, "far": 0.3}, eq=g_shelf_lo(60.0, -3.0))
    s.bus("bronze", "tension", sends={"hall": 0.5}, eq=g_highpass(300.0, 2))
    s.bus("ostinato", "tension", sends={"hall": 0.3}, eq=g_mul(g_highpass(40.0, 2), g_lowpass(3000.0, 1)))
    s.bus("tremolo", "tension", sends={"hall": 0.55}, eq=g_mul(g_highpass(800.0, 2), g_bell(3200.0, 3.0, 0.8)))
    s.bus("swell", "tension", sends={"hall": 0.5}, stereo_width=1.2)

    low = drone(n, m("D1"), rng, "tri", 2.5, 1, 150.0, side=0.25)
    body = drone(n, m("D2"), rng, "saw", 5.0, 3, 210.0)
    sheen = drone(n, m("A2"), rng, "saw", 7.0, 2, 520.0)
    swell = 0.6 + 0.4 * (0.5 + 0.5 * dsp.lfo(n, 2, 0.3))
    s.add("drone", 0, low * 0.55 + body * 0.45 * swell[:, None] + sheen * 0.1 * (0.5 + 0.5 * dsp.lfo(n, 5, 0.7))[:, None])
    for bar, bars, chord in ASSYRIA_SECTIONS:
        s.add("pad", s.at(bar), ins.strings(voicing(chord, 38), s.sec(bars * 4) - 0.4, 0.45, rng, attack=2.8, release=3.5,
                                            bright=0.6), 0.9)
    # lyre: plucked chord tones on the beats, a lute-like stroke on each downbeat
    for bar in range(28):
        chord = sections_chord(ASSYRIA_SECTIONS, bar)
        notes = arp(chord, 50)
        if 4 <= bar < 10:
            picks = [(0, 0), (2, 2)]
        else:
            picks = [(0, 0), (1, 2), (2, 1), (3, 3)] if bar % 2 == 0 else [(0, 2), (2, 4)]
        for beat, i in picks:
            s.add("lyre", s.at(bar, beat, 0.007), ins.lyre(notes[i], 0.6 * rng.uniform(0.9, 1.05), rng), pan=-0.3)
    lyre_lead = v_pluck(rng, lambda midi, vel, r: ins.lyre(midi, vel, r))
    line = []
    place(s, "lyre", 4, 0, md.LULLABY_A, lyre_lead, mode, vel=0.85, pan=0.2, log=line)
    # the duduk's lament over Cm, Bb, Eb, Dm
    lament = [(16, [(0, 10, 4), (4, 8, 3), (7, 7, 1)]), (18, [(0, 6, 4), (4, 8, 4)]), (20, [(0, 9, 3), (3, 8, 1), (4, 7, 4)]),
              (22, [(0, 5, 6), (6, 2, 2)]), (24, [(0, 8, 2), (2, 10, 2), (4, 8, 4)]), (26, [(0, 7, 6)])]
    duduk = v_reed(rng, True)
    for bar, notes in lament:
        place(s, "duduk", bar, 0, notes, duduk, mode, shift=-12, vel=0.75, log=line)
    check_line("assyria lyre+duduk", line, lambda b: sections_chord(ASSYRIA_SECTIONS, b), 4)
    for bar in range(0, 28, 2):
        s.add("drums", s.at(bar), ins.frame_drum(58.0, 0.7, rng, "doum", ring=1.5), pan=-0.1)

    kit = Kit(rng, doum=(lambda: ins.frame_drum(72.0, 0.9, rng, "doum", ring=1.1), 4),
              tek=(lambda: ins.frame_drum(92.0, 0.75, rng, "tek"), 4), big=(lambda: ins.big_drum(44.0, 0.9, rng, 2.0), 3),
              bronze=(lambda: ins.anvil(0.8, rng, 640.0), 2))
    for bar in range(28):
        for kind, beat, v in [("doum", 0.0, 1.0), ("doum", 1.5, 0.75), ("tek", 2.0, 0.8), ("doum", 2.5, 0.85),
                              ("tek", 3.0, 0.7), ("tek", 3.5, 0.6)]:
            s.add("frame", s.at(bar, beat, 0.004), kit(kind), v, pan=0.15)
        if bar % 2 == 0:
            s.add("big", s.at(bar), kit("big"), pan=-0.1)
        if bar % 4 == 3:
            s.add("bronze", s.at(bar, 2.0), kit("bronze"), pan=0.45)

    def pattern(chord, bar):
        r = root(chord, 38, 49)
        return [gm_name(x) for x in (r, r, r + 12, r, r + 1, r, r + 7, r + 1)]
    string_ostinato(s, "ostinato", ASSYRIA_SECTIONS, pattern, 8, 0.5)
    for bar, bars, names in [(12, 4, ["A4", "Bb4"]), (20, 4, ["F4", "G4"]), (24, 4, ["D4", "Eb4"])]:
        tremolo_pad(s, "tremolo", bar, bars, names)
    riser(s, "swell", 26, 8)
    finish_walk(s, "assyria", 1201)


# --- Greece: "Marmur i ksiezyc" (D Dorian: D E F G A B C) ----------------------

GREECE_SECTIONS = [(0, 4, "Dm"), (4, 4, "G"), (8, 2, "Dm"), (10, 1, "G"), (11, 3, "Dm"), (14, 2, "C"), (16, 4, "Am"), (20, 2, "G"), (22, 2, "Dm")]


def walk_greece():
    s = Mix(60, 4, 24, seed=1301, levels=WALK_LEVELS)
    rng = s.rng
    mode = "dorian"
    n = s.n
    s.reverb("hall", rt60=3.8, pre_delay=0.05, dark=0.5, early=12, early_span=0.09)
    s.reverb("far", rt60=5.2, pre_delay=0.1, dark=0.45, early=6, early_span=0.12, early_gain=0.25)
    s.bus("drone", "explore", sends={"hall": 0.3}, eq=g_shelf_lo(70.0, -6.0))
    s.bus("choir", "explore", sends={"hall": 0.8}, eq=g_mul(g_highpass(180.0, 2), g_shelf_hi(5000.0, -2.0)),
          stereo_width=1.2)
    s.bus("kithara", "explore", sends={"hall": 0.6}, eq=g_highpass(70.0, 2), stereo_width=1.1)
    s.bus("pan", "explore", sends={"far": 1.0, "hall": 0.3}, eq=g_mul(g_highpass(250.0, 2), g_shelf_hi(7000.0, -3.0)))
    s.bus("glass", "explore", sends={"hall": 1.0})
    s.bus("tympanon", "tension", sends={"hall": 0.35}, eq=g_highpass(80.0, 2))
    s.bus("timp", "tension", sends={"hall": 0.45}, eq=g_shelf_lo(80.0, -4.0))
    s.bus("ostinato", "tension", sends={"hall": 0.35}, eq=g_mul(g_highpass(45.0, 2), g_lowpass(3500.0, 1)))
    s.bus("tremolo", "tension", sends={"hall": 0.6}, eq=g_mul(g_highpass(900.0, 2), g_bell(3800.0, 3.0, 0.8)))
    s.bus("swell", "tension", sends={"hall": 0.5}, stereo_width=1.2)

    low = drone(n, m("D2"), rng, "tri", 3.0, 2, 300.0, side=0.3)
    fifth = drone(n, m("A2"), rng, "tri", 4.0, 1, 500.0, side=0.3)
    s.add("drone", 0, low * 0.6 + fifth * 0.3)
    # the choir breathes the harmony, high and wordless
    for bar, bars, chord in GREECE_SECTIONS:
        notes = [x + 12 for x in voicing(chord, 50)[1:]]
        s.add("choir", s.at(bar), ins.choir(notes, s.sec(bars * 4) - 0.3, 0.55, rng, ins.VOWEL_U, attack=2.2, release=2.5,
                                            singers=3))
    for bar in range(24):
        chord = sections_chord(GREECE_SECTIONS, bar)
        notes = arp(chord, 50)
        picks = [(0, 0), (1, 2), (2, 3), (3, 1)] if bar % 2 == 0 else [(0, 2), (1.5, 4), (3, 3)]
        for beat, i in picks:
            s.add("kithara", s.at(bar, beat, 0.008), ins.lyre(notes[i], 0.6 * rng.uniform(0.9, 1.05), rng, big=True), pan=-0.25)
    panflute = v_flute(rng, "pan")
    line = []
    place(s, "pan", 8, 0, md.LULLABY_A, panflute, mode, vel=0.75, pan=0.15, log=line)
    answer = [(16, [(0, 11, 2), (2, 10, 2), (4, 8, 4)]), (18, [(0, 8, 2), (2, 11, 2), (4, 13, 4)]),
              (20, [(0, 14, 3), (3, 11, 1), (4, 10, 4)]), (22, [(0, 9, 2), (2, 7, 6)])]
    for bar, notes in answer:
        place(s, "pan", bar, 0, notes, panflute, mode, vel=0.65, pan=0.15, log=line)
    check_line("greece pan", line, lambda b: sections_chord(GREECE_SECTIONS, b), 4)
    for bar, bars, name, pos in [(0, 6, "A5", -0.5), (6, 4, "B5", 0.5), (12, 6, "E6", -0.3), (18, 4, "D6", 0.4)]:
        s.add("glass", s.at(bar), ins.glass(m(name), s.sec(bars * 4) - 1.0, 0.6, rng, attack=3.0, release=3.0), pan=pos)

    kit = Kit(rng, doum=(lambda: ins.frame_drum(132.0, 0.8, rng, "doum", ring=0.7), 3),
              tek=(lambda: ins.frame_drum(140.0, 0.7, rng, "tek"), 4))
    for bar in range(24):
        for kind, beat, v in [("doum", 0.0, 1.0), ("tek", 1.0, 0.7), ("tek", 1.5, 0.5), ("doum", 2.0, 0.85), ("tek", 3.0, 0.7),
                              ("tek", 3.5, 0.55)]:
            s.add("tympanon", s.at(bar, beat, 0.004), kit(kind), v, pan=0.2)
        if bar % 2 == 0:
            chord = sections_chord(GREECE_SECTIONS, bar)
            s.add("timp", s.at(bar), ins.timpani(root(chord, 38, 49), 0.8, rng), pan=-0.2)

    def pattern(chord, bar):
        r = root(chord, 38, 49)
        return [gm_name(x) for x in (r, r, r + 12, r, r + 2, r, r + 9, r + 7)]
    string_ostinato(s, "ostinato", GREECE_SECTIONS, pattern, 8, 0.5)
    for bar, bars, names in [(4, 4, ["A4", "B4"]), (12, 4, ["G4", "A4"]), (20, 4, ["E4", "F#4"])]:
        tremolo_pad(s, "tremolo", bar, bars, names)
    riser(s, "swell", 22, 8)
    finish_walk(s, "greece", 1301)


# --- Enlightenment: "Menuet dla automatow" (d minor, a baroque minuet) --------

ENL_PROG = (["Dm", "Dm", "A", "A"]
            + ["Dm", "Bb", "Gm", "A", "Dm", "F", ("Gm", "A"), "Dm"]
            + ["Dm", "Bb", "Gm", "A", "Dm", "Bb", ("Gm", "A"), "Dm"]
            + ["F", "C", "Dm", "Bb", "Gm", "Dm", "Em7b5", "A7"]
            + ["F", "C", "Dm", "Bb", "Gm", "Dm", "Em7b5", "A7"]
            + ["Dm", "Bb", "Gm", "A", "Dm", "F", ("Gm", "A"), "Dm"]
            + ["Gm", "A", "Dm", "Dm"])


def walk_enlightenment():
    s = Mix(90, 3, 48, seed=1401, levels=WALK_LEVELS)
    rng = s.rng
    s.reverb("room", rt60=1.6, pre_delay=0.015, dark=0.55, early=16, early_span=0.04, early_gain=0.6)
    s.reverb("hall", rt60=2.6, pre_delay=0.03, dark=0.45)
    s.bus("harpsi", "explore", sends={"room": 0.4, "hall": 0.2}, eq=g_highpass(60.0, 2), stereo_width=1.1)
    s.bus("box", "explore", sends={"hall": 0.5}, eq=g_mul(g_highpass(160.0, 2), g_shelf_hi(9000.0, -2.0)))
    s.bus("strings", "explore", sends={"hall": 0.6}, eq=g_mul(g_lowpass(4000.0, 1), g_highpass(40.0, 2)))
    s.bus("celesta", "explore", sends={"hall": 0.6}, eq=g_highpass(200.0, 2))
    s.bus("clock", "explore", sends={"room": 0.4}, eq=g_mul(g_lowpass(5000.0, 1), g_highpass(500.0, 2)))
    s.bus("spiccato", "tension", sends={"room": 0.3, "hall": 0.2}, eq=g_mul(g_highpass(45.0, 2), g_lowpass(3500.0, 1)))
    s.bus("timp", "tension", sends={"hall": 0.45}, eq=g_shelf_lo(80.0, -4.0))
    s.bus("ticks", "tension", sends={"room": 0.2}, eq=g_highpass(700.0, 2))
    s.bus("evil", "tension", sends={"hall": 0.5})
    s.bus("runs", "tension", sends={"room": 0.4}, eq=g_highpass(120.0, 2))
    s.bus("swell", "tension", sends={"hall": 0.5}, stereo_width=1.2)

    def chord_of(bar, beat=0.0):
        return gm.chord_at(ENL_PROG, bar, beat, 3)

    # harpsichord: bass on one, chords on two and three (the minuet's step)
    for bar in range(48):
        for beat in range(3):
            chord = chord_of(bar, beat)
            r = root(chord, 38, 49)
            if beat == 0:
                s.add("harpsi", s.at(bar, 0, 0.004), ins.harpsichord(r, 0.75, rng, hold=s.sec(1.0)), pan=-0.3)
                if bar % 2 == 1:
                    s.add("harpsi", s.at(bar, 0.5, 0.004), ins.harpsichord(r + 12, 0.5, rng, hold=s.sec(0.5)), pan=-0.3)
            elif bar >= 4:
                iv = tones(chord)
                upper = root(chord, 57, 68)
                for k, i in enumerate(iv[:3]):
                    s.add("harpsi", s.at(bar, beat, 0.003) + k * 40, ins.harpsichord(upper + i, 0.45, rng, hold=s.sec(0.6),
                                                                                     four_foot=0.0), pan=0.2)
    for start, beats, chord in gm.chord_spans(ENL_PROG, 3):
        bar = start // 3
        vel = 0.38 if bar < 4 or bar >= 44 else 0.5
        s.add("strings", s.at(0, start), ins.strings(ms(gm.PAD[chord]) if chord in gm.PAD else voicing(chord, 38),
                                                     s.sec(beats) + 0.3, vel, rng, attack=1.0, release=1.6, bright=0.8))

    def phrase(bus, bar0, notes, voice, shift=0, vel=0.8, pan=0.05):
        for beat, name, beats in notes:
            v = vel * rng.uniform(0.9, 1.05)
            s.add(bus, s.at(bar0, beat, 0.004), voice(m(name) + shift, v, beats), pan=pan)
    box = lambda midi, vel, beats: ins.music_box(midi, vel, rng)
    harp_voice = lambda midi, vel, beats: ins.harpsichord(midi, vel, rng, hold=s.sec(beats) * 0.95)
    phrase("box", 4, gm.PHRASE_A, box)
    phrase("box", 12, gm.PHRASE_A2, box)
    phrase("harpsi", 20, gm.PHRASE_B, harp_voice, vel=0.7, pan=0.25)
    phrase("box", 28, gm.PHRASE_B2, box, vel=0.75)
    phrase("harpsi", 28, gm.PHRASE_B2, harp_voice, shift=-12, vel=0.5, pan=0.25)
    phrase("harpsi", 36, gm.PHRASE_A, harp_voice, vel=0.65, pan=0.25)
    phrase("box", 36, [(b, n_, d) for b, n_, d in gm.PHRASE_A if b % 3 == 0], box, shift=12, vel=0.5, pan=-0.2)
    phrase("box", 44, gm.PHRASE_OUT, box, vel=0.72)
    for bar in (1, 3, 11, 19, 27, 35, 43, 46):
        chord = chord_of(bar)
        note = root(chord, 84, 95) + int(rng.choice(tones(chord)[:3] + [12]))
        s.add("celesta", s.at(bar, float(rng.choice([0.5, 1.5, 2.0]))), ins.celesta(note, 0.35, rng), pan=rng.uniform(-0.7, 0.7))
    for beat in range(48 * 3):
        s.add("clock", s.at(0, beat), ins.clock_tick(beat % 2 == 1, 0.5, rng), pan=0.6)

    # --- tension: the automata wind up
    def pattern(chord, bar):
        r = root(chord, 38, 49)
        return [gm_name(x) for x in (38, 38, 50, 38, 39 if bar % 2 else 37, 38)] if bar < 4 else \
            [gm_name(x) for x in (r, r, r + 12, r, r + 7, r)]
    string_ostinato(s, "spiccato", [(0, 48, None)], lambda c, bar: pattern(chord_of(bar), bar), 6, 0.5, length=0.18)
    for bar in range(48):
        chord = chord_of(bar)
        s.add("timp", s.at(bar), ins.timpani(root(chord, 38, 49), 0.8 if bar % 4 == 0 else 0.6, rng), pan=-0.2)
    tick_cache = [ins.clock_tick(k % 2 == 1, 0.8, rng) for k in range(6)]
    for step in range(48 * 6):
        s.add("ticks", s.at(0, step * 0.5), tick_cache[step % 6], 1.0 if step % 2 == 0 else 0.7, pan=-0.4)
    for bar0, notes in [(8, gm.PHRASE_A[:5]), (24, gm.PHRASE_B[:4]), (40, gm.PHRASE_A[9:14])]:
        for beat, name, beats in notes:
            s.add("evil", s.at(bar0, beat - notes[0][0]), ins.evil_box(m(name) + 12, 0.8, rng), pan=0.3)
    # broken-chord runs: the mechanism ticking faster (sixteenths, second half of each phrase)
    for bar in list(range(8, 12)) + list(range(16, 20)) + list(range(24, 28)) + list(range(32, 36)) + list(range(40, 44)):
        chord = chord_of(bar)
        notes = arp(chord, 62)
        for k in range(12):
            note = notes[[0, 1, 2, 3, 2, 1][k % 6]]
            s.add("runs", s.at(bar, k * 0.25, 0.002), ins.harpsichord(note, 0.45 if k % 4 else 0.6, rng, hold=s.sec(0.24),
                                                                       four_foot=0.0), pan=0.35)
    riser(s, "swell", 46, 6)
    finish_walk(s, "enlightenment", 1401)


# --- Asia: "Ogrod w nocy" (D minor pentatonic, koto and shakuhachi) -----------

ASIA_SECTIONS = [(0, 4, "Dsus"), (4, 4, "Dsus"), (8, 4, "Csus"), (12, 4, "Gsus"), (16, 4, "Aq"), (20, 4, "Dsus")]
SHO = {"Dsus": ["D4", "G4", "A4", "D5"], "Csus": ["C4", "F4", "G4", "C5"], "Gsus": ["G3", "C4", "D4", "G4"],
       "Aq": ["A3", "D4", "G4", "A4"]}


def walk_asia():
    s = Mix(60, 4, 24, seed=1501, levels=WALK_LEVELS)
    rng = s.rng
    mode = "penta"
    n = s.n
    s.reverb("hall", rt60=2.8, pre_delay=0.03, dark=0.45, early=12, early_span=0.06)
    s.reverb("far", rt60=4.8, pre_delay=0.1, dark=0.35, early=6, early_span=0.12, early_gain=0.25)
    s.bus("drone", "explore", sends={"hall": 0.3}, eq=g_shelf_lo(70.0, -6.0))
    s.bus("sho", "explore", sends={"hall": 0.7}, eq=g_mul(g_highpass(200.0, 2), g_lowpass(5000.0, 1)))
    s.bus("koto", "explore", sends={"hall": 0.5}, eq=g_highpass(90.0, 2), stereo_width=1.1)
    s.bus("shaku", "explore", sends={"far": 0.9, "hall": 0.3}, eq=g_mul(g_highpass(220.0, 2), g_shelf_hi(7000.0, -3.0)))
    s.bus("bowl", "explore", sends={"hall": 0.7}, eq=g_highpass(300.0, 2))
    s.bus("taiko", "tension", sends={"hall": 0.35, "far": 0.25}, eq=g_shelf_lo(60.0, -3.0))
    s.bus("pon", "tension", sends={"hall": 0.4}, eq=g_highpass(120.0, 2))
    s.bus("trem", "tension", sends={"hall": 0.4}, eq=g_highpass(120.0, 2))
    s.bus("ostinato", "tension", sends={"hall": 0.3}, eq=g_mul(g_highpass(40.0, 2), g_lowpass(3000.0, 1)))
    s.bus("swell", "tension", sends={"hall": 0.5}, stereo_width=1.2)

    s.add("drone", 0, drone(n, m("D2"), rng, "tri", 2.0, 2, 260.0, side=0.3) * 0.7
          + drone(n, m("A2"), rng, "tri", 3.0, 1, 400.0, side=0.3) * 0.3)
    for bar, bars, chord in ASIA_SECTIONS:
        s.add("sho", s.at(bar), ins.sho(ms(SHO[chord]), s.sec(bars * 4) - 0.5, 0.6, rng, attack=2.5, release=2.5))
    # koto: a falling figure each bar (the in-scale's Eb pressed out of D now and then)
    for bar in range(24):
        chord = sections_chord(ASIA_SECTIONS, bar)
        r = root(chord, 62, 73)
        figure = [(0.0, r + 12, 0.0), (0.5, r + 7, 0.0), (1.0, r + 5, 0.0), (2.0, r, 0.0)]
        if bar % 4 == 1:
            figure = [(0.0, r + 7, 0.0), (1.0, r + 12, 0.0), (1.5, r + 10, 0.0), (2.5, r + 7, 0.0), (3.0, r, 1.0 if r % 12 == 2 else 0.0)]
        if bar % 4 == 3:
            figure = [(0.0, r, 0.0), (2.0, r - 5, 0.0)]
        for beat, note, push in figure:
            s.add("koto", s.at(bar, beat, 0.008), ins.koto(note, 0.6 * rng.uniform(0.9, 1.05), rng, push=push), pan=-0.3)
    shaku = lambda midi, sec, vel: ins.flute(midi, max(sec * 0.97, 0.15), vel, rng, "shakuhachi",
                                            fall=-90.0 if sec > 1.5 else 0.0)
    line = []
    place(s, "shaku", 4, 0, md.LULLABY_A, shaku, mode, vel=0.75, pan=0.2, log=line)
    calls = [(14, [(0, 11, 3), (3, 10, 1), (4, 9, 4)]), (16, [(0, 7, 2), (2, 11, 6)]), (18, [(0, 10, 2), (2, 9, 2), (4, 7, 4)]),
             (21, [(0, 4, 2), (2, 7, 6)])]
    for bar, notes in calls:
        place(s, "shaku", bar, 0, notes, shaku, mode, vel=0.7, pan=0.2, log=line)
    check_line("asia shakuhachi", line, lambda b: sections_chord(ASIA_SECTIONS, b), 4)
    for bar, name in [(0, "A5"), (8, "D6"), (16, "G5"), (20, "D6")]:
        s.add("bowl", s.at(bar, 0.5), ins.bowl(m(name), 0.7, rng), pan=0.45)

    kit = Kit(rng, big=(lambda: ins.big_drum(50.0, 0.9, rng, 1.6), 3), small=(lambda: ins.big_drum(76.0, 0.7, rng, 0.9), 3),
              pon=(lambda: ins.frame_drum(215.0, 0.75, rng, "slap"), 3))
    for bar in range(24):
        s.add("taiko", s.at(bar), kit("big"), pan=-0.1)
        s.add("taiko", s.at(bar, 2.5), kit("small"), 0.7, pan=0.1)
        if bar % 2 == 1:
            s.add("taiko", s.at(bar, 3.5), kit("small"), 0.55, pan=0.1)
        for beat in (1.0, 3.0):
            s.add("pon", s.at(bar, beat, 0.006), kit("pon"), pan=0.35)
    # koto tremolo (rapid repeated notes) on the tonic and fifth
    for bar in range(24):
        chord = sections_chord(ASIA_SECTIONS, bar)
        r = root(chord, 62, 73)
        for k in range(16):
            if bar % 2 == 1 and k >= 8:
                break
            s.add("trem", s.at(bar, k * 0.25, 0.003), ins.koto(r if k < 8 else r + 7, 0.35 + 0.15 * (k % 4 == 0), rng), pan=0.3)

    def pattern(chord, bar):
        r = root(chord, 38, 49)
        return [gm_name(x) for x in (r, r, r + 12, r, r + 1 if r % 12 == 2 else r + 3, r, r + 10, r + 7)]
    string_ostinato(s, "ostinato", ASIA_SECTIONS, pattern, 8, 0.5)
    riser(s, "swell", 22, 8)
    finish_walk(s, "asia", 1501)


# --- Americas: "Weze i ogien" (D Aeolian, 6/8: marimba, clay flutes, slit drums)

AMERICAS_SECTIONS = [(0, 8, "Dm"), (8, 4, "Bb"), (12, 4, "C"), (16, 8, "Dm"), (24, 4, "Gm"), (28, 4, "Bb"), (32, 4, "C"),
                     (36, 8, "Dm"), (44, 4, "Am"), (48, 2, "Bb"), (50, 2, "C"), (52, 4, "Dm")]


def walk_americas():
    s = Mix(210, 6, 56, seed=1601, levels=WALK_LEVELS)   # eighth notes; a bar = 6/8 at a dotted quarter of 70
    rng = s.rng
    mode = "aeolian"
    n = s.n
    s.reverb("hall", rt60=2.9, pre_delay=0.03, dark=0.42, early=14, early_span=0.06)
    s.reverb("far", rt60=4.6, pre_delay=0.09, dark=0.3, early=6, early_span=0.12, early_gain=0.25)
    s.bus("drone", "explore", sends={"hall": 0.25}, eq=g_shelf_lo(70.0, -5.0))
    s.bus("marimba", "explore", sends={"hall": 0.4}, eq=g_highpass(70.0, 2), stereo_width=1.1)
    s.bus("clay", "explore", sends={"far": 0.9, "hall": 0.3}, eq=g_highpass(300.0, 2))
    s.bus("slit", "explore", sends={"far": 0.6}, eq=g_lowpass(2500.0, 1))
    s.bus("rattle", "explore", sends={"hall": 0.3}, eq=g_highpass(2000.0, 2))
    s.bus("slit_t", "tension", sends={"hall": 0.3}, eq=g_highpass(60.0, 2))
    s.bus("huehuetl", "tension", sends={"hall": 0.35}, eq=g_shelf_lo(60.0, -3.0))
    s.bus("gourd", "tension", sends={"hall": 0.3}, eq=g_highpass(2000.0, 2), stereo_width=1.2)
    s.bus("conch", "tension", sends={"far": 1.2}, eq=g_highpass(90.0, 2))
    s.bus("ostinato", "tension", sends={"hall": 0.3}, eq=g_mul(g_highpass(40.0, 2), g_lowpass(3000.0, 1)))
    s.bus("swell", "tension", sends={"hall": 0.5}, stereo_width=1.2)

    s.add("drone", 0, drone(n, m("D2"), rng, "saw", 5.0, 2, 220.0, side=0.35) * 0.6
          + drone(n, m("A2"), rng, "saw", 6.0, 1, 380.0, side=0.3) * 0.2)
    # marimba: 3+3 and 2+2+2 (hemiola) bars in turn, lighter in the intro
    for bar in range(56):
        chord = sections_chord(AMERICAS_SECTIONS, bar)
        notes = arp(chord, 50)
        if bar % 2 == 0:
            seq = [0, 1, 2, 3, 2, 1]
            accents = (0, 3)
        else:
            seq = [0, 3, 1, 2, 3, 4]
            accents = (0, 2, 4)
        intro = bar < 4 or 52 <= bar
        for k, i in enumerate(seq):
            if intro and k not in accents:
                continue
            v = (0.62 if k in accents else 0.42) * rng.uniform(0.92, 1.05)
            s.add("marimba", s.at(bar, k, 0.004), ins.marimba(notes[i], v, rng), pan=-0.2 + 0.08 * (k % 3))
    clay = v_flute(rng, "clay")
    line = []
    place(s, "clay", 16, 0, md.LULLABY_A, clay, mode, shift=12, unit=2.0, vel=0.7, pan=0.2, log=line)
    place(s, "clay", 36, 0, md.LULLABY_A[:9], clay, mode, shift=12, unit=2.0, vel=0.65, pan=-0.15, log=line)
    place(s, "clay", 40, 0, [(b - 12, st, d) for b, st, d in md.LULLABY_A[9:13]] + [(4, 9, 2), (6, 7, 6)], clay, mode, shift=12,
          unit=2.0, vel=0.65, pan=-0.15, log=line)
    check_line("americas clay", line, lambda b: sections_chord(AMERICAS_SECTIONS, b), 6)
    tongues = {"lo": 176.0, "hi": 236.0}
    kit = Kit(rng, lo=(lambda: ins.slit_drum(tongues["lo"], 0.8, rng), 3), hi=(lambda: ins.slit_drum(tongues["hi"], 0.75, rng), 3),
              big=(lambda: ins.big_drum(58.0, 0.9, rng, 1.4), 3), gourd=(lambda: ins.rattle(0.8, rng, 0.1), 4))
    for bar in range(56):
        if bar % 2 == 0:
            s.add("slit", s.at(bar, 0), kit("lo"), pan=-0.3)
            s.add("slit", s.at(bar, 3), kit("hi"), 0.8, pan=-0.25)
        if 16 <= bar < 44 and bar % 4 == 3:
            for k in (3, 4, 5):
                s.add("rattle", s.at(bar, k, 0.004), kit("gourd"), 0.6, pan=0.4)
    # --- tension
    for bar in range(56):
        for k, (name, v) in enumerate([("lo", 1.0), (None, 0), ("hi", 0.7), ("lo", 0.8), ("hi", 0.6), ("hi", 0.75)]):
            if name:
                s.add("slit_t", s.at(bar, k, 0.004), kit(name), v, pan=0.25)
        s.add("huehuetl", s.at(bar, 0), kit("big"), pan=-0.1)
        if bar % 2 == 1:
            s.add("huehuetl", s.at(bar, 3), kit("big"), 0.7, pan=-0.1)
        for k in range(6):
            s.add("gourd", s.at(bar, k, 0.005), kit("gourd"), 1.0 if k in (0, 3) else 0.55, pan=0.45 if k % 2 else 0.3)
    for bar in (0, 28):
        s.add("conch", s.at(bar, 1), ins.conch(m("D3"), 2.2, 0.85, rng), pan=-0.5)
        s.add("conch", s.at(bar + 2, 1), ins.conch(m("A2"), 1.6, 0.7, rng), pan=-0.45)

    def pattern(chord, bar):
        r = root(chord, 38, 49)
        steps = (r, None, r + 12, r, r + 7, r + 10) if bar % 2 == 0 else (r, r + 3, r + 7, r + 12, r + 7, r + 3)
        return [None if x is None else gm_name(x) for x in steps]
    string_ostinato(s, "ostinato", AMERICAS_SECTIONS, pattern, 6, 1.0, length=0.2)
    riser(s, "swell", 54, 12)
    finish_walk(s, "americas", 1601)


# --- the guardians' theme: "Straznik skrzydla" -----------------------------------
# One composition in scale steps; each wing plays it in its own mode and
# instruments. 120 BPM, 32 bars (64 s): awakening (0-3), riff A (4-11), the
# lullaby (12-19), climax (20-27), turnaround (28-31).

GUARD = {
    "egypt": {"A": ["D", "D", "Eb", "D", "D", "D", "Cm", "Eb"], "B": ["D", "D", "Gm", "Cm", "D", "D", "Cm", "D"],
              "turn": ["D", "D", "Eb", "Eb"], "seed": 1701},
    "assyria": {"A": ["Dm", "Dm", "Eb", "Dm", "Dm", "Dm", "Cm", "Eb"], "B": ["Dm", "Dm", "Gm", "Cm", "Dm", "Dm", "Cm", "Dm"],
                "turn": ["Dm", "Dm", "Eb", "Eb"], "seed": 1711},
    "greece": {"A": ["Dm", "Dm", "Em", "Dm", "Dm", "Dm", "C", "Am"], "B": ["Dm", "Dm", "G", "C", "Dm", "Dm", "Am", "Dm"],
               "turn": ["Dm", "Dm", "C", "Am"], "seed": 1721},
    "enlightenment": {"A": ["Dm", "Dm", "Em7b5", "Dm", "Dm", "Dm", "A7", "A7"], "B": ["Dm", "Dm", "Gm", "A", "Dm", "Dm", "A", "Dm"],
                      "turn": ["Dm", "Dm", "Em7b5", "A7"], "seed": 1731},
    "asia": {"A": ["D5", "D5", "F", "D5", "D5", "D5", "C5", "C5"], "B": ["Dm", "Dm", "Dm", "C5", "Dm", "Dm", "F", "Dm"],
             "turn": ["D5", "D5", "C5", "C5"], "seed": 1741},
    "americas": {"A": ["Dm", "Dm", "C", "Dm", "Dm", "Dm", "C", "C"], "B": ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "C", "Dm"],
                 "turn": ["Dm", "Dm", "C", "C"], "seed": 1751},
}
# the guardian motif, two bars each: (beat, step, beats)
M1 = [(0, 4, 1), (1, 7, 0.5), (1.5, 9, 0.5), (2, 8, 2), (4, 7, 1), (5, 6, 1), (6, 4, 2)]
M2 = [(0, 8, 1.5), (1.5, 7, 0.5), (2, 5, 2), (4, 6, 1), (5, 7, 3)]
M3 = [(0, 4, 1), (1, 7, 0.5), (1.5, 9, 0.5), (2, 11, 2), (4, 10, 1), (5, 9, 1), (6, 8, 2)]
M4 = [(0, 6, 1.5), (1.5, 10, 0.5), (2, 8, 2), (4, 8, 1), (5, 7, 1), (6, 5, 2)]
# the lullaby re-barred in 4/4 (bars 12-19)
LULL44 = [(0, 4, 1), (1, 7, 1), (2, 9, 2), (4, 9, 1), (5, 7, 1), (6, 8, 2), (8, 7, 2), (10, 5, 2), (12, 6, 4),
          (16, 4, 1), (17, 7, 1), (18, 9, 2), (20, 11, 2), (22, 10, 1), (23, 9, 1), (24, 8, 2), (26, 6, 2), (28, 7, 4)]


def guard_chord(spec, bar):
    if bar < 4:
        return spec["A"][0]
    if bar < 12:
        return spec["A"][bar - 4]
    if bar < 20:
        return spec["B"][bar - 12]
    if bar < 28:
        return spec["A"][bar - 20]
    return spec["turn"][bar - 28]


def mode_up(r, mode):
    """The mode's next pitch above MIDI [param r]."""
    pcs = sorted({(md.D4 + i) % 12 for i in md.MODES[mode]})
    for k in range(1, 12):
        if (r + k) % 12 in pcs:
            return r + k
    return r + 2


def guardian(wing):
    spec = GUARD[wing]
    mode = MODE[wing]
    s = Mix(120, 4, 32, seed=spec["seed"], levels=GUARD_LEVELS)
    rng = s.rng
    s.reverb("room", rt60=1.3, pre_delay=0.01, dark=0.5, early=16, early_span=0.05, early_gain=0.55)
    s.reverb("hall", rt60=2.8, pre_delay=0.03, dark=0.42, early=14, early_span=0.07)
    s.bus("drums", "base", sends={"room": 0.3, "hall": 0.25}, eq=g_shelf_lo(55.0, -2.0))
    s.bus("low", "base", sends={"room": 0.25, "hall": 0.3}, eq=g_shelf_lo(55.0, -3.0))
    s.bus("bass", "base", sends={"room": 0.1}, eq=g_mul(g_highpass(35.0, 2), g_shelf_lo(60.0, -3.0), g_lowpass(3500.0, 1)))
    s.bus("ost", "base", sends={"room": 0.2, "hall": 0.35}, eq=g_highpass(90.0, 2), stereo_width=1.1)
    s.bus("pads", "base", sends={"hall": 0.5}, eq=g_mul(g_highpass(45.0, 2), g_lowpass(4000.0, 1)))
    s.bus("stabs", "base", sends={"hall": 0.35}, eq=g_highpass(80.0, 2))
    s.bus("lead", "hi", sends={"hall": 0.45}, eq=g_highpass(150.0, 2))
    s.bus("lead2", "hi", sends={"hall": 0.45}, eq=g_highpass(150.0, 2))
    s.bus("choir", "hi", sends={"hall": 0.7}, eq=g_highpass(120.0, 2))
    s.bus("perc", "hi", sends={"room": 0.3, "hall": 0.2})

    # --- the wing's kit and voices
    big = lambda f0, vel, length=1.5: ins.big_drum(f0, vel, rng, length)
    if wing == "egypt":
        kit = Kit(rng, a=(lambda: ins.frame_drum(104.0, 0.9, rng, "doum", ring=0.7), 4), b=(lambda: ins.frame_drum(120.0, 0.85, rng, "tek"), 4),
                  big=(lambda: big(52.0, 0.95), 3), x=(lambda: ins.rattle(0.9, rng, 0.16, "sistrum"), 3),
                  fill=(lambda: ins.frame_drum(150.0, 0.8, rng, "slap"), 4))
        ost = lambda midi, vel: ins.harp(midi, vel, rng)
        lead = lambda midi, sec, vel: ins.reed(midi, max(sec * 0.92, 0.08), vel, rng)
        lead_shift, lead2 = 0, None
        stab = lambda notes, sec, vel: ins.brass(notes, sec, vel, rng, bright=0.9)
        vowel = ins.VOWEL_A
    elif wing == "assyria":
        kit = Kit(rng, a=(lambda: ins.frame_drum(70.0, 0.95, rng, "doum", ring=1.0), 4), b=(lambda: ins.frame_drum(90.0, 0.85, rng, "tek"), 4),
                  big=(lambda: big(44.0, 0.95, 2.0), 3), x=(lambda: ins.anvil(0.8, rng, 620.0), 3),
                  fill=(lambda: ins.frame_drum(96.0, 0.85, rng, "slap"), 4))
        ost = lambda midi, vel: ins.lyre(midi, vel * 1.4, rng)
        lead = lambda midi, sec, vel: ins.reed(midi, max(sec * 0.93, 0.08), vel, rng, dark=True)
        lead_shift, lead2 = -12, (lambda midi, sec, vel: ins.reed(midi, max(sec * 0.92, 0.08), vel * 0.7, rng))
        stab = lambda notes, sec, vel: ins.brass([x - 12 for x in notes], sec, vel, rng, bright=0.6)
        vowel = ins.VOWEL_O
    elif wing == "greece":
        kit = Kit(rng, a=(lambda: ins.frame_drum(136.0, 0.9, rng, "doum", ring=0.6), 4), b=(lambda: ins.frame_drum(140.0, 0.8, rng, "tek"), 4),
                  big=(lambda: ins.timpani(m("D2"), 0.95, rng, 2.0), 2), x=(lambda: ins.crash(0.6, rng, 2.5), 2),
                  fill=(lambda: ins.tom(140.0, 0.8, rng), 3))
        ost = lambda midi, vel: ins.lyre(midi, vel * 1.4, rng, big=True)
        lead = lambda midi, sec, vel: ins.brass([midi], max(sec * 0.92, 0.08), vel, rng, bright=1.2, attack=0.02, release=0.2)
        lead_shift, lead2 = 0, (lambda midi, sec, vel: ins.flute(midi, max(sec * 0.92, 0.1), vel * 0.8, rng, "pan"))
        stab = lambda notes, sec, vel: ins.brass(notes, sec, vel, rng, bright=1.0)
        vowel = ins.VOWEL_A
    elif wing == "enlightenment":
        kit = Kit(rng, a=(lambda: ins.timpani(m("D2"), 0.9, rng, 1.6), 3), b=(lambda: ins.snare(0.8, rng), 4),
                  big=(lambda: ins.timpani(m("A1"), 0.95, rng, 2.0), 2), x=(lambda: ins.clock_tick(False, 0.9, rng), 4),
                  fill=(lambda: ins.snare(0.7, rng), 4))
        ost = lambda midi, vel: ins.harpsichord(midi, vel, rng, hold=s.sec(0.48))
        lead = lambda midi, sec, vel: ins.organ([midi, midi - 12], max(sec * 0.95, 0.08), vel * 1.2, rng, release=0.15)
        lead_shift, lead2 = 0, (lambda midi, sec, vel: ins.evil_box(midi + 12, vel, rng))
        stab = lambda notes, sec, vel: ins.strings(notes, sec, vel, rng, attack=0.02, release=0.3, bright=1.4)
        vowel = ins.VOWEL_O
    elif wing == "asia":
        kit = Kit(rng, a=(lambda: big(56.0, 0.95, 1.4), 4), b=(lambda: big(150.0, 0.7, 0.5), 4), big=(lambda: big(46.0, 1.0, 2.0), 3),
                  x=(lambda: ins.frame_drum(215.0, 0.8, rng, "slap"), 4), fill=(lambda: big(110.0, 0.8, 0.7), 4))
        ost = lambda midi, vel: ins.koto(midi, vel * 1.2, rng)
        lead = lambda midi, sec, vel: ins.flute(midi, max(sec * 0.95, 0.1), vel, rng, "shakuhachi", fall=-60.0 if sec > 1.0 else 0.0)
        lead_shift, lead2 = 0, None
        stab = lambda notes, sec, vel: ins.strings(notes, sec, vel, rng, attack=0.02, release=0.3, bright=1.2)
        vowel = None
    else:   # americas
        kit = Kit(rng, a=(lambda: ins.slit_drum(176.0, 0.9, rng), 4), b=(lambda: ins.slit_drum(236.0, 0.85, rng), 4),
                  big=(lambda: big(58.0, 0.95, 1.6), 3), x=(lambda: ins.rattle(0.9, rng, 0.08), 4),
                  fill=(lambda: ins.slit_drum(300.0, 0.8, rng), 4))
        ost = lambda midi, vel: ins.marimba(midi, vel, rng)
        lead = lambda midi, sec, vel: ins.flute(midi, max(sec * 0.92, 0.08), vel, rng, "clay")
        lead_shift, lead2 = 12, None
        stab = lambda notes, sec, vel: ins.brass(notes, sec, vel, rng, bright=0.9)
        vowel = ins.VOWEL_A

    kicks = []
    for bar in range(32):
        chord = guard_chord(spec, bar)
        section = 0 if bar < 4 else (1 if bar < 12 else (2 if bar < 20 else (3 if bar < 28 else 4)))
        r = root(chord, 38, 49)
        # --- drums
        if section == 0:
            s.add("drums", s.at(bar), kit("big"), 0.8 + 0.05 * bar, pan=-0.1)
            if bar >= 2:
                s.add("drums", s.at(bar, 2.5), kit("big"), 0.7, pan=0.1)
                for beat in (1.0, 3.0):
                    s.add("drums", s.at(bar, beat), kit("b"), 0.6, pan=0.25)
        elif section == 2:
            s.add("drums", s.at(bar), kit("big"), pan=-0.1)
            s.add("drums", s.at(bar, 2), kit("b"), 0.9, pan=0.2)
            s.add("drums", s.at(bar, 3.5), kit("a"), 0.6, pan=0.15)
        else:
            for beat, name, v in [(0, "big", 1.0), (0.5, "a", 0.6), (1, "b", 0.85), (1.5, "a", 0.7), (2, "a", 0.9), (2.5, "big", 0.8),
                                  (3, "b", 0.9), (3.5, "a", 0.6)]:
                at = s.at(bar, beat, 0.002)
                s.add("drums", at, kit(name), v, pan=0.15 if name != "big" else -0.1)
                if name == "big":
                    kicks.append(at)
        if bar % 8 == 4 or bar == 20:
            s.add("perc", s.at(bar), kit("x"), pan=0.4)
        if section == 3 or (section == 1 and bar % 2 == 1):
            for beat in (1.0, 3.0) if section == 1 else (0.5, 1.0, 1.5, 2.5, 3.0, 3.5):
                s.add("perc", s.at(bar, beat, 0.003), kit("x"), 0.7, pan=-0.35)
        if bar == 31 or bar == 11 or bar == 27:
            for k in range(8 if bar != 31 else 16):
                st = (8 + k) if bar != 31 else k
                s.add("drums", step_at(s, bar, st), kit("fill"), 0.4 + 0.6 * k / (7 if bar != 31 else 15), pan=0.4 - 0.05 * k)
        # --- bass riff (8ths) / long notes
        if section in (1, 3, 4) or (section == 0 and bar >= 2):
            up = mode_up(r, mode)
            riff = [r, r, r + 12, r, up, r, r + 7, r + 12] if section != 4 else \
                [r, r + 12, r, mode_up(r, mode), mode_up(mode_up(r, mode), mode), r + 7, r + 12, r + 7]
            for k, note in enumerate(riff):
                v = 1.0 if k % 2 == 0 else 0.8
                s.add("bass", s.at(bar, k * 0.5, 0.002), ins.staccato(note, 0.2, 1.0, rng, bright=1.0), v, pan=-0.1)
                s.add("low", s.at(bar, k * 0.5), ins.synth_bass(note - 12, s.sec(0.4), v * 0.8, rng, drive=2.0))
        elif section == 2:
            for beat in (0, 2):
                s.add("low", s.at(bar, beat), ins.synth_bass(r - 12, s.sec(1.8), 0.85, rng, drive=1.6))
        # --- ostinato (the wing's plucked instrument)
        notes = arp(chord, 62)
        if section in (1, 3):
            seq = [0, 1, 2, 3, 2, 1, 4, 2]
            for k, i in enumerate(seq):
                s.add("ost", s.at(bar, k * 0.5, 0.003), ost(notes[i], 0.7 if k % 2 == 0 else 0.55), pan=0.3)
        elif section == 2:
            for k, i in enumerate([0, 2, 3, 4]):
                s.add("ost", s.at(bar, k, 0.004), ost(notes[i], 0.6), pan=0.3)
        else:
            for k, i in enumerate([0, 1, 2, 3] if bar < 30 else [0, 1, 2, 3, 4, 5, 4, 3]):
                beat = k * (1.0 if bar < 30 else 0.5)
                s.add("ost", s.at(bar, beat, 0.004), ost(notes[i], 0.55 + 0.05 * k), pan=0.3)
        # --- pads and stabs
        if section == 2:
            s.add("pads", s.at(bar), ins.strings(voicing(chord, 38), s.sec(4) + 0.2, 0.7, rng, attack=0.5, release=1.0, bright=0.9))
        if section in (1, 3) and bar % 2 == 0:
            s.add("stabs", s.at(bar), stab(voicing(chord, 50), s.sec(1.5), 0.85), pan=0.05)
            s.add("stabs", s.at(bar, 3.5), stab(voicing(chord, 50), s.sec(0.4), 0.7), pan=0.05)
    for bus in ("bass", "low"):
        s.duck(bus, kicks, -4.0, 0.12)

    # --- hi: the lead
    line = []
    for base_bar, shift in [(4, 0), (20, 12 if wing in ("greece", "enlightenment", "egypt") else 0)]:
        for k, motif in enumerate([M1, M2, M3, M4]):
            for beat, step, beats in motif:
                midi = md.note(step, mode) + lead_shift + shift
                at_bar = base_bar + 2 * k
                s.add("lead", s.at(at_bar, beat, 0.003), lead(midi, s.sec(beats), 0.9), pan=0.05)
                line.append(((at_bar) * 4 + beat, midi, beats))
                if lead2 is not None and base_bar == 20:
                    s.add("lead2", s.at(at_bar, beat, 0.003), lead2(midi + (12 if wing != "enlightenment" else 0), s.sec(beats), 0.8),
                          pan=-0.2)
    for beat, step, beats in LULL44:
        midi = md.note(step, mode) + lead_shift
        s.add("lead", s.at(12, beat, 0.004), lead(midi, s.sec(beats), 0.85), pan=0.05)
        line.append((12 * 4 + beat, midi, beats))
    check_line(f"guardian {wing} lead", line, lambda b: guard_chord(spec, b), 4)
    if wing == "americas":
        for bar in (4, 12, 20, 28):
            s.add("lead2", s.at(bar), ins.conch(m("D3"), s.sec(3), 0.9, rng), pan=-0.4)
    # choir (or the sho's cloud in Asia) over the awakening, the lullaby and the climax
    for bar in list(range(2, 4)) + list(range(12, 28)):
        chord = guard_chord(spec, bar)
        notes = [x + 12 for x in voicing(chord, 50)[1:]]
        if vowel is None:
            s.add("choir", s.at(bar), ins.sho(notes, s.sec(4) - 0.1, 0.7, rng, attack=0.4, release=0.8))
        else:
            s.add("choir", s.at(bar), ins.choir(notes, s.sec(4) - 0.1, 0.8, rng, vowel, attack=0.3, release=0.8))
    if wing == "asia":
        for bar in (4, 12, 20, 28):
            s.add("perc", s.at(bar), ins.bowl(m("D6"), 0.8, rng, 4.0), 1.5, pan=0.3)

    stems = s.render(verbose=False)
    base, hi = master_family(stems, "base", "hi", -18.0, -16.5,
                             glue={"threshold_db": -20.0, "ratio": 2.0, "attack": 0.01, "release": 0.12})
    k = dsp.seam_rotation(base + hi)
    write(f"guardian_{wing}", dsp.rotate(base, k), seed=spec["seed"])
    write(f"guardian_{wing}_hi", dsp.rotate(hi, k), seed=spec["seed"] + 1)


# --- stings -------------------------------------------------------------------

def _one_shot(s, target, seconds, name, seed, fade=1.2):
    stems = s.render(verbose=False)
    out = master(stems, target, loop=False)["main"]
    out = dsp.fade_edges(out[:dsp.n_of(seconds)], 0.001, fade)
    write(name, out, loop=False, seed=seed)


def guardian_fall():
    """A guardian falls: a drum stroke and the Phrygian sigh Eb -> D, the
    wing's spell breaking into an open D major, the lullaby's head on the
    celesta above it."""
    s = Mix(120, 4, 4, seed=1801, levels=STING_LEVELS, loop=False)
    rng = s.rng
    s.reverb("hall", rt60=3.4, pre_delay=0.035, dark=0.4)
    s.bus("drum", sends={"hall": 0.4}, eq=g_shelf_lo(60.0, -2.0))
    s.bus("brass", sends={"hall": 0.5})
    s.bus("choir", sends={"hall": 0.7}, eq=g_highpass(140.0, 2))
    s.bus("cel", sends={"hall": 0.6}, eq=g_highpass(200.0, 2))
    s.bus("crash", sends={"hall": 0.4}, eq=g_highpass(400.0, 2))
    s.add("drum", 0, ins.big_drum(46.0, 1.0, rng, 2.4))
    s.add("drum", 0, ins.timpani(m("D2"), 0.9, rng, 3.0))
    s.add("crash", 0, ins.crash(0.8, rng, 4.0))
    s.add("brass", 0, ins.brass(ms(["Eb3", "G3", "Bb3", "Eb4"]), 1.1, 0.9, rng, bright=0.8, attack=0.03, release=0.5))
    hit = dsp.n_of(1.2)
    s.add("brass", hit, ins.brass(ms(["D3", "A3", "D4", "F#4"]), 2.6, 0.8, rng, bright=0.7, attack=0.25, release=1.5))
    s.add("choir", hit, ins.choir(ms(["A4", "D5", "F#5"]), 2.8, 0.7, rng, ins.VOWEL_A, attack=0.5, release=1.6))
    for k, (beat, name) in enumerate([(0.0, "A5"), (0.25, "D6"), (0.5, "F#6"), (0.75, "E6"), (1.25, "D6")]):
        s.add("cel", hit + dsp.n_of(0.5 + beat), ins.celesta(m(name), 0.6, rng), pan=0.2)
    _one_shot(s, -18.0, 6.0, "guardian_sting", 1801)


def seal_sting():
    """A seal or a crystal shard in the hand: a glassy climb up D major
    (add 9), a struck bowl, a soft 'oo' swelling under it."""
    s = Mix(120, 4, 4, seed=1811, levels=STING_LEVELS, loop=False)
    rng = s.rng
    s.reverb("hall", rt60=3.0, pre_delay=0.03, dark=0.45)
    s.bus("cel", sends={"hall": 0.6}, eq=g_highpass(250.0, 2))
    s.bus("glass", sends={"hall": 0.8})
    s.bus("bowl", sends={"hall": 0.6}, eq=g_highpass(300.0, 2))
    s.bus("choir", sends={"hall": 0.8}, eq=g_highpass(160.0, 2))
    s.bus("harp", sends={"hall": 0.6}, eq=g_highpass(120.0, 2))
    for k, name in enumerate(["D5", "F#5", "A5", "E6", "F#6", "A6"]):
        at = dsp.n_of(0.09 * k)
        s.add("cel", at, ins.celesta(m(name), 0.75 - 0.05 * k, rng), pan=-0.3 + 0.12 * k)
        s.add("harp", at, ins.harp(m(name) - 12, 0.5, rng), pan=0.3 - 0.1 * k)
    s.add("bowl", dsp.n_of(0.55), ins.bowl(m("D6"), 0.8, rng, 4.0), pan=0.1)
    s.add("glass", dsp.n_of(0.2), ins.glass(m("A5"), 2.2, 0.6, rng, attack=0.4, release=1.2), pan=-0.2)
    s.add("choir", dsp.n_of(0.3), ins.choir(ms(["D4", "F#4", "A4", "D5"]), 2.4, 0.6, rng, ins.VOWEL_U, attack=0.6, release=1.2))
    _one_shot(s, -20.0, 4.5, "seal_sting", 1811, fade=1.0)


def gate_sting():
    """A gate gives way: a low swell climbing Bb - C - D under a timpani
    stroke, the way ahead in open fifths."""
    s = Mix(120, 4, 4, seed=1821, levels=STING_LEVELS, loop=False)
    rng = s.rng
    s.reverb("hall", rt60=3.2, pre_delay=0.04, dark=0.38)
    s.bus("brass", sends={"hall": 0.5}, eq=g_highpass(45.0, 2))
    s.bus("organ", sends={"hall": 0.6}, eq=g_shelf_lo(70.0, -3.0))
    s.bus("timp", sends={"hall": 0.5}, eq=g_shelf_lo(80.0, -3.0))
    s.bus("strings", sends={"hall": 0.6})
    for k, (t, notes, hold) in enumerate([(0.0, ["Bb2", "F3", "Bb3", "D4"], 0.55), (0.6, ["C3", "G3", "C4", "E4"], 0.55),
                                          (1.2, ["D3", "A3", "D4", "F#4"], 2.2)]):
        at = dsp.n_of(t)
        s.add("brass", at, ins.brass(ms(notes), hold, 0.75 + 0.08 * k, rng, bright=0.7 + 0.15 * k, attack=0.05, release=0.6))
        s.add("organ", at, ins.organ(ms(notes[:3]), hold, 0.7, rng, release=0.8))
        s.add("timp", at, ins.timpani(m(notes[0]), 0.6 + 0.15 * k, rng, 2.5))
    s.add("strings", dsp.n_of(1.2), ins.strings(ms(["A4", "D5"]), 2.2, 0.6, rng, attack=0.2, release=1.4, bright=1.1))
    _one_shot(s, -19.0, 4.5, "gate_sting", 1821, fade=1.2)


def wing_sting(wing):
    """A wing seen for the first time: its own instrument calls the
    lullaby's head in its scale over a drone, a drum and a plucked chord."""
    mode = MODE[wing]
    s = Mix(84, 4, 3, seed=1830 + WINGS.index(wing), levels=STING_LEVELS, loop=False)
    rng = s.rng
    s.reverb("hall", rt60=3.2, pre_delay=0.04, dark=0.4)
    s.bus("lead", sends={"hall": 0.6}, eq=g_highpass(150.0, 2))
    s.bus("pluck", sends={"hall": 0.6}, eq=g_highpass(80.0, 2))
    s.bus("drone", sends={"hall": 0.4}, eq=g_mul(g_lowpass(900.0, 2), g_highpass(35.0, 2)))
    s.bus("drum", sends={"hall": 0.4}, eq=g_shelf_lo(60.0, -2.0))
    s.bus("color", sends={"hall": 0.7}, eq=g_highpass(250.0, 2))
    head = [(0, 4, 0.75), (0.75, 7, 0.75), (1.5, 9, 0.75), (2.25, 8, 1.25), (3.5, 7, 3.0)]
    voices = {
        "egypt": (lambda midi, sec: ins.flute(midi, sec, 0.85, rng, "ney"), lambda midi: ins.harp(midi, 0.6, rng),
                  lambda: ins.frame_drum(70.0, 0.9, rng, "doum", ring=1.4), lambda: ins.rattle(0.8, rng, 0.25, "sistrum"), 0),
        "assyria": (lambda midi, sec: ins.reed(midi, sec, 0.8, rng, dark=True), lambda midi: ins.lyre(midi, 0.8, rng),
                    lambda: ins.big_drum(44.0, 0.9, rng, 2.0), lambda: ins.anvil(0.6, rng, 620.0), -12),
        "greece": (lambda midi, sec: ins.flute(midi, sec, 0.8, rng, "pan"), lambda midi: ins.lyre(midi, 0.8, rng, big=True),
                   lambda: ins.timpani(m("D2"), 0.8, rng, 2.5), lambda: ins.glass(m("A5"), 2.0, 0.6, rng, 0.5, 1.5), 0),
        "enlightenment": (lambda midi, sec: ins.music_box(midi, 0.85, rng), lambda midi: ins.harpsichord(midi, 0.7, rng),
                          lambda: ins.timpani(m("D2"), 0.7, rng, 2.0), lambda: ins.clock_tick(False, 0.8, rng), 12),
        "asia": (lambda midi, sec: ins.flute(midi, sec, 0.85, rng, "shakuhachi", fall=-80.0 if sec > 2 else 0.0),
                 lambda midi: ins.koto(midi, 0.7, rng), lambda: ins.big_drum(52.0, 0.9, rng, 1.6),
                 lambda: ins.bowl(m("A5"), 0.8, rng, 4.0), 0),
        "americas": (lambda midi, sec: ins.flute(midi, sec, 0.8, rng, "clay"), lambda midi: ins.marimba(midi, 0.7, rng),
                     lambda: ins.slit_drum(176.0, 0.9, rng), lambda: ins.rattle(0.8, rng, 0.3), 12),
    }
    lead, pluck_, drum, color, shift = voices[wing]
    s.add("drum", 0, drum())
    s.add("color", 0, color(), pan=0.4)
    chord = [md.note(0, mode) - 12, md.note(4, mode) - 12, md.note(7, mode) - 12, md.note(9, mode) - 12]
    for k, note in enumerate(chord):
        s.add("pluck", dsp.n_of(0.05 * k), pluck_(note), pan=-0.3 + 0.2 * k)
    n_drone = dsp.n_of(5.5)
    t = np.arange(n_drone) / SR
    hum = (np.sin(dsp.TAU * dsp.hz(m("D2")) * t) + 0.5 * np.sin(dsp.TAU * dsp.hz(m("A2")) * t)) * dsp.env_ar(n_drone, 0.6, 2.5)
    s.add("drone", 0, hum * 0.4)
    for beat, step, beats in head:
        midi = md.note(step, mode) + shift
        s.add("lead", s.at(0, 0.5 + beat), lead(midi, s.sec(beats) * 0.95), pan=0.1)
    _one_shot(s, -19.0, 6.0, f"wing_sting_{wing}", 1830 + WINGS.index(wing), fade=1.5)


WALKS = {"egypt": walk_egypt, "assyria": walk_assyria, "greece": walk_greece, "enlightenment": walk_enlightenment,
         "asia": walk_asia, "americas": walk_americas}


def stings():
    guardian_fall()
    seal_sting()
    gate_sting()
    for wing in WINGS:
        wing_sting(wing)


def tracks():
    """name -> renderer, for gen_music.py."""
    out = {f"explore_{w}": WALKS[w] for w in WINGS}
    out.update({f"guardian_{w}": (lambda w=w: guardian(w)) for w in WINGS})
    out["stings"] = stings
    out["walks"] = lambda: [WALKS[w]() for w in WINGS]
    out["guardians"] = lambda: [guardian(w) for w in WINGS]
    return out
