"""Floor I score helpers and stings. The wings' music itself (the zones'
four-stem loops) is gen_biomes.py, the guardians' themes guardians.py; this
module keeps what they share: the chord table and voicings, the guardian
motif (M1-M4) and the lullaby re-barred in 4/4, the guardians' harmony per
wing, the melody clash check, and the progress stings:

    guardian_sting                            a guardian falls
    seal_sting, gate_sting                    a seal / shard picked up, a gate
                                              opened (laid over the music)
    wing_sting_<wing>                         a wing seen for the first time

Run through gen_music.py (shares its Session, mastering and writer):

    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/music/gen_music.py stings

Loudness: stings -19..-21 LUFS (the game ducks the music under them).
"""
import numpy as np

import dsp
import gen_music as gm
import instruments as ins
import modes as md
from dsp import SR, db, g_highpass, g_lowpass, g_mul, g_shelf_lo
from gen_music import Session, m, master, ms, write


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
    "F5": ("F", [0, 7]), "G5": ("G", [0, 7]), "Bb4": ("Bb", [0, 5]), "A4": ("A", [0, 5]),
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


def stings():
    guardian_fall()
    seal_sting()
    gate_sting()
    for wing in WINGS:
        wing_sting(wing)


def tracks():
    """name -> renderer, for gen_music.py."""
    return {"stings": stings}
