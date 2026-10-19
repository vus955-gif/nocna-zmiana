"""Arranging the biome score (gen_biomes.py): a Band session, drum
patterns, riffs, melodies in scale steps and the mastering of a zone's
four stems.

A zone's music is one loop in four stems, all the same length and started
together by the game (Music: one family), so every change of intensity
lands on the beat and on the harmony:

    explore   the calm walk (in the genre, listenable for minutes)
    tension   laid over explore (drums, bass, a pulse)
    combat    the heavy version, played alone (explore and tension fade
              out under it in the same bar)
    hi        laid over combat (lead, choir, extra percussion)

Mastering: explore -22 LUFS, explore + tension -19, combat -18,
combat + hi -16.5 (the game's levels), sample peaks <= -1.5 dBFS; the
limiter of each pair runs on the pair's sum (the game sums them) and one
seam rotation keeps all four in sync.

Notation
- Drum patterns: one string per instrument and bar, one character per
  step (16 = sixteenths in 4/4, 12 = triplet eighths...): 'X' accent,
  'x' normal, 'o' soft, 'g' ghost, '.' rest.
- Riffs: [(step16, steps, note, art)]; note = semitones over D2 (0 = D2,
  the drop-D low string) or a (note, shape) pair for chords (metal.SHAPES);
  art: 'pm' palm mute, 'open', 'ring' (let ring to the next event).
- Melodies: [(beat, scale_step, beats)] in a wing's mode (modes.note: step
  0 = D4, 7 = D5).
"""
import numpy as np

import dsp
import gen_music as gm
import gen_wings as gw
import instruments as ins
import metal
import modes as md
from dsp import db, g_bell, g_highpass, g_mul, g_shelf_hi
from gen_music import m

STEMS = ("explore", "tension", "combat", "hi")
TARGETS = {"explore": -22.0, "explore+tension": -19.0, "combat": -18.0, "combat+hi": -16.5}
D2 = 38
VEL = {"X": 1.0, "x": 0.85, "o": 0.62, "g": 0.38}


class Band(gm.Session):
    """A Session whose buses
    - may feed several stems ([param feeds]: stem -> dB),
    - may run a processor over their whole track first ([param process]:
      the guitar amp, a chorus...; it gets the (n, 2) buffer),
    - are levelled by loudness after processing: [param level] LUFS (or
      the session's [param levels] table by bus name), measured where the
      bus plays (BS.1770 gating leaves its silences out)."""

    def __init__(self, bpm, beats_per_bar, bars, seed, levels=None, loop=True):
        super().__init__(bpm, beats_per_bar, bars, seed, loop)
        self.levels = levels or {}
        # bar -> chord name (gen_wings.CHORDS), set by a piece: melodies are checked against it
        self.chord_of = None

    def bus(self, name, stem="explore", sends=None, eq=None, gain_db=0.0, stereo_width=1.0, feeds=None, process=None,
            level=None):
        super().bus(name, stem, sends, eq, gain_db, stereo_width)
        b = self.buses[name]
        b["feeds"] = feeds if feeds is not None else {stem: 0.0}
        b["process"] = process
        b["level"] = level

    def step(self, bar, step, jitter=0.0, per_beat=4):
        """Sample of [param step] (sixteenths by default) in [param bar]."""
        return self.at(bar, step / float(per_beat), jitter)

    def render(self, verbose=True):
        stems, wet = {}, {}
        for name in list(self.buses):
            b = self.buses[name]
            x = b["tl"].buf
            if x is None or not np.any(x):
                continue
            if b["process"] is not None:
                x = b["process"](x)
            if b["eq"] is not None:
                x = dsp.fft_filter(x, b["eq"], circular=self.loop)
            x = dsp.stereo(x)
            if b["duck"] is not None:
                x = x * b["duck"][:, None]
            if b["width"] != 1.0:
                x = dsp.width(x, b["width"])
            target = b["level"] if b["level"] is not None else self.levels.get(name)
            if target is not None:
                x = x * db(target - dsp.lufs(x, circular=self.loop))
            x = x * b["gain"]
            if verbose:
                print(f"    bus {name:<10} {dsp.lufs(x, circular=self.loop):6.1f} LUFS  peak {dsp.to_db(dsp.peak(x)):5.1f}"
                      f"  -> {', '.join(b['feeds'])}")
            for stem, gain in b["feeds"].items():
                y = x * db(gain)
                stems[stem] = stems.get(stem, 0.0) + y
                for ir, amount in b["sends"].items():
                    wet[(stem, ir)] = wet.get((stem, ir), 0.0) + y * amount
            b["tl"].buf = None   # a bus is ~70 MB: free it once mixed
        for (stem, ir), x in wet.items():
            stems[stem] = stems[stem] + dsp.convolve(x, self.irs[ir], circular=self.loop)
        return stems


# --- harmony -------------------------------------------------------------------------

def chord_root(name, low=D2, high=D2 + 11):
    """Root of chord [param name] (gen_music.CHORDS, gen_wings.CHORDS) in
    [low, high]."""
    return gw.root(name, low, high)


def chord_arp(chord, low, count=6):
    """The chord's own tones (sevenths and flat fifths included) climbing
    from its root in [low, low + 11]: [param count] notes."""
    r = gw.root(chord, low, low + 11)
    iv = sorted(set(gw.tones(chord)))
    return [r + 12 * octave + i for octave in range(4) for i in iv][:count]


def progression(sections):
    """[(start_bar, bars, [chord per bar] or chord)] -> chord per bar."""
    out = []
    for _start, bars, chords in sections:
        seq = chords if isinstance(chords, list) else [chords]
        for k in range(bars):
            out.append(seq[k % len(seq)])
    return out


def section_of(sections, bar):
    """The section tag of [param bar] in [(start, bars, tag)]."""
    for start, bars, tag in sections:
        if start <= bar < start + bars:
            return tag
    return sections[-1][2]


# --- drums ---------------------------------------------------------------------------

class Drummer:
    """Plays drum patterns from a kit: name -> (bus, maker, takes, pan).
    Every hit takes the next take (round robin), velocity humanised; kicks
    are collected for sidechain ducking."""

    def __init__(self, s, rng, kit):
        self.s = s
        self.rng = rng
        self.map = {}
        self.takes = {}
        self.turn = {}
        for name, (bus, make, count, pan) in kit.items():
            self.map[name] = (bus, pan)
            self.takes[name] = [make() for _ in range(count)]
            self.turn[name] = 0
        self.kicks = []

    def hit(self, name, at, vel=1.0, pan=None):
        bus, default_pan = self.map[name]
        takes = self.takes[name]
        self.turn[name] = (self.turn[name] + 1) % len(takes)
        self.s.add(bus, at, takes[self.turn[name]], vel * self.rng.uniform(0.93, 1.03),
                   pan=default_pan if pan is None else pan)
        if name in ("kick", "ikick"):
            self.kicks.append(at)

    def bar(self, bar, pattern, vel=1.0, jitter=0.0025, only=None, skip=()):
        """Plays one bar of [param pattern] (instrument -> step string)."""
        for name, line in pattern.items():
            if name not in self.map or name in skip or (only is not None and name not in only):
                continue
            steps = len(line)
            for k, ch in enumerate(line):
                if ch in VEL:
                    beat = k * self.s.bpb / steps
                    self.hit(name, self.s.at(bar, beat, jitter), VEL[ch] * vel)

    def fill(self, bar, names, start_step=8, steps=8, vel=(0.5, 1.0), per_beat=4):
        """A run of hits over the end of a bar (toms down, snare roll...):
        [param names] used in turn."""
        for k in range(steps):
            v = vel[0] + (vel[1] - vel[0]) * k / max(steps - 1, 1)
            self.hit(names[k % len(names)], self.s.step(bar, start_step + k, 0.002, per_beat), v)


def pattern(**lines):
    """pattern(kick='x...x...', snare='....x...') -> dict (a shorthand)."""
    return dict(lines)


# --- guitars -------------------------------------------------------------------------

class Guitarist:
    """Plays riffs as double-tracked guitar: [param takes] independent
    performances (different strings' noise, timing, a hair of tuning),
    panned over [param pans] on one bus (the amp then runs per channel:
    each side its own amp). DI notes are cached per (note, art, steps,
    side)."""

    def __init__(self, s, bus, rng, pans=(-1.0, 1.0), mute=0.92, bright=0.6, bass=False, transpose=0):
        self.s = s
        self.bus = bus
        self.rng = rng
        self.pans = pans
        self.mute = mute
        self.bright = bright
        self.bass = bass
        self.transpose = transpose
        self.cache = {}

    def _di(self, note, art, hold, side):
        shape = None
        if isinstance(note, tuple):
            note, shape = note
        midi = D2 + note + self.transpose
        key = (midi, shape, art, round(hold, 4), side, int(self.rng.integers(0, 2)))
        sig = self.cache.get(key)
        if sig is None:
            mute = self.mute if art == "pm" else 0.0
            if self.bass:
                sig = metal.bass_di(midi, hold, 0.9, self.rng, mute=mute * 0.7)
            elif shape is None:
                sig = metal.string_di(midi, hold, 0.9, self.rng, mute=mute, bright=self.bright)
            else:
                sig = metal.chord_di(midi, shape, hold, 0.9, self.rng, mute=mute, bright=self.bright)
            self.cache[key] = sig
        return sig

    def riff(self, bar, riff, vel=1.0, jitter=0.003, per_beat=4, gap=0.9):
        """Plays [param riff] from [param bar] (steps may run past the bar)."""
        unit = 60.0 / self.s.bpm / per_beat
        for step, steps, note, art in riff:
            if note is None:
                continue
            hold = steps * unit * (gap if art != "ring" else 1.02)
            if art == "pm":
                hold = min(hold, steps * unit * 0.85)
            accent = 1.0 if art != "pm" else 0.9
            for side, pan in enumerate(self.pans):
                at = self.s.step(bar, step, jitter, per_beat)
                self.s.add(self.bus, at, self._di(note, art, hold, side), vel * accent * self.rng.uniform(0.94, 1.02), pan=pan)

    def tremolo(self, bar, notes, per_beat=4, vel=0.9, start=0, art="pm"):
        """Tremolo picking: [param notes] = [(steps, note)] each repeated
        on every step (16ths at per_beat=4, 32nds at 8)."""
        at = start
        events = []
        for steps, note in notes:
            for k in range(steps):
                events.append((at + k, 1, note, art))
            at += steps
        self.riff(bar, events, vel, 0.002, per_beat, gap=0.95)


def lead_line(s, bus, bar, notes, mode, rng, shift=0, unit=1.0, vel=0.9, pan=0.0, vibrato=0.35, bend_long=True,
              voice=None, alter=None):
    """A lead melody [(beat, step, beats)] in [param mode] on the lead
    guitar (DI: the bus' amp makes it scream), or on [param voice]
    (voice(midi, seconds, vel) -> signal). Long notes get a bend up into
    them."""
    _check(s, bus, bar, notes, mode, shift, unit, alter)
    for k, (beat, step, beats) in enumerate(notes):
        midi = md.note(step, mode) + shift
        if alter and (int(step) % 7) in alter:
            midi += alter[int(step) % 7]
        sec = s.sec(beats * unit)
        v = vel * rng.uniform(0.92, 1.03)
        if voice is not None:
            sig = voice(midi, sec * 0.97, v)
        else:
            scoop = 0.5 if (bend_long and beats * unit >= 2.0 and k % 2 == 0) else 0.0
            sig = metal.lead_di(midi, sec * 0.98, v, rng, vibrato=vibrato if beats * unit >= 1.0 else 0.1, scoop=scoop)
        s.add(bus, s.at(bar, beat * unit, 0.004), sig, pan=pan)


# --- processors --------------------------------------------------------------------

def rhythm_amp(drive=1.0, **kw):
    return lambda x: metal.amp(x, drive=drive, **kw)


def lead_amp(drive=0.85):
    return lambda x: metal.amp(dsp.mono(x), drive=drive, tight=200.0, mid=950.0, mid_db=7.0, scoop_db=-1.0,
                               presence_db=2.0, cab=6500.0)


def clean_chorus(chorus=0.6, bright=1.0):
    return lambda x: metal.clean_amp(dsp.mono(x), bright=bright, chorus=chorus)


def bass_rig(drive=1.0):
    return lambda x: metal.bass_amp(dsp.mono(x), drive=drive)


# --- mastering ---------------------------------------------------------------------

GLUE = {"threshold_db": -20.0, "ratio": 2.0, "attack": 0.01, "release": 0.12}


def master_quad(stems, glue=None):
    """A zone's four stems mastered (TARGETS): the walk pair and the fight
    pair each limited on its sum, one seam rotation for all four (they stay
    in sync). Returns [explore, tension, combat, hi]."""
    stems = dict(stems)
    for stem in STEMS:
        if stem not in stems:
            stems[stem] = np.zeros_like(next(iter(stems.values())))
    explore, tension = gm.master_family({k: stems[k] for k in ("explore", "tension")}, "explore", "tension",
                                        TARGETS["explore"], TARGETS["explore+tension"])
    combat, hi = gm.master_family({k: stems[k] for k in ("combat", "hi")}, "combat", "hi", TARGETS["combat"],
                                  TARGETS["combat+hi"], glue=glue or GLUE)
    # dense loops (sixteenths at 180 BPM): look a little further back for the quietest spot
    k = dsp.seam_rotation(explore + tension + combat + hi, before=0.4)
    return [dsp.rotate(x, k) for x in (explore, tension, combat, hi)]


def zone_names(zone):
    return [f"explore_{zone}", f"explore_{zone}_tension", f"combat_{zone}", f"combat_{zone}_hi"]


def master_zone(stems, zone, seed, glue=None):
    """Masters a zone's four stems and writes explore_<zone>,
    explore_<zone>_tension, combat_<zone>, combat_<zone>_hi."""
    names = zone_names(zone)
    for i, (name, x) in enumerate(zip(names, master_quad(stems, glue))):
        gm.write(name, x, seed=seed + i)
    return names


def master_guardian(stems, wing, seed):
    """Masters a guardian theme (base -18 LUFS, base + hi -16.5)."""
    base, hi = gm.master_family(stems, "base", "hi", -18.0, -16.5,
                                glue={"threshold_db": -20.0, "ratio": 2.0, "attack": 0.01, "release": 0.12})
    k = dsp.seam_rotation(base + hi, before=0.4)
    gm.write(f"guardian_{wing}", dsp.rotate(base, k), seed=seed)
    gm.write(f"guardian_{wing}_hi", dsp.rotate(hi, k), seed=seed + 1)


# --- notation -----------------------------------------------------------------------

def parse_riff(text):
    """Riff string -> [(step, steps, note, art)] (see the module doc)."""
    tokens = text.split()
    events = []
    for k, tok in enumerate(tokens):
        if tok in ("-", "."):
            if tok == "-" and events:
                step, steps, note, art = events[-1]
                if step + steps == k:
                    events[-1] = (step, steps + 1, note, art)
            continue
        if tok == "p":
            events.append((k, 1, 0, "pm"))
        elif tok.startswith("p") and tok[1:].lstrip("-").isdigit():
            events.append((k, 1, int(tok[1:]), "pm"))
        elif tok.startswith("r:"):
            events.append((k, 1, int(tok[2:]), "ring"))
        elif ":" in tok:
            shape, note = tok.split(":")
            art = "pm" if shape.startswith("p") else "open"
            events.append((k, 1, (int(note), shape.lstrip("p") or "5"), art))
        else:
            events.append((k, 1, int(tok), "open"))
    return events


def bass_of(events, octave=-12):
    """The bass doubling a riff: the lowest note of every event."""
    out = []
    for step, steps, note, art in events:
        root = note[0] if isinstance(note, tuple) else note
        out.append((step, steps, root + octave, art))
    return out


def shift_events(events, steps):
    return [(s + steps, n, note, art) for s, n, note, art in events]


def scale_run(mode, steps):
    """Scale steps (modes.note numbering) -> semitones over D2."""
    return [md.note(st, mode) - D2 for st in steps]


# --- shared voices --------------------------------------------------------------------

def v_flute(rng, kind, **kw):
    return lambda midi, sec, vel: ins.flute(midi, max(sec * 0.96, 0.12), vel, rng, kind, **kw)


def v_reed(rng, dark):
    return lambda midi, sec, vel: ins.reed(midi, max(sec * 0.95, 0.1), vel, rng, dark=dark)


def melody(s, bus, bar, notes, voice, mode, shift=0, unit=1.0, vel=0.8, pan=0.0, jitter=0.005, alter=None):
    """[(beat, step, beats)] through voice(midi, seconds, vel) in [param
    mode]; [param alter] maps a scale step's degree (0..6) to a semitone
    change (the double harmonic's raised seventh in Egypt's leads)."""
    rng = s.rng
    _check(s, bus, bar, notes, mode, shift, unit, alter)
    for beat, step, beats in notes:
        midi = md.note(step, mode) + shift
        if alter and (int(step) % 7) in alter:
            midi += alter[int(step) % 7]
        s.add(bus, s.at(bar, beat * unit, jitter), voice(midi, s.sec(beats * unit), vel * rng.uniform(0.9, 1.04)), pan=pan)


def _check(s, bus, bar, notes, mode, shift, unit, alter):
    """Prints the melody's held notes that clash with the chord under them
    on a strong beat (gen_wings.check_line: the ears we do not have), when
    the session knows its harmony ([member Band.chord_of])."""
    chord_of = getattr(s, "chord_of", None)
    if chord_of is None:
        return
    line = []
    for beat, step, beats in notes:
        midi = md.note(step, mode) + shift + ((alter or {}).get(int(step) % 7, 0))
        at = bar * s.bpb + beat * unit
        if abs(at - round(at)) < 1e-6:
            line.append((int(round(at)), midi, beats * unit))
    gw.check_line(f"{bus} @{bar}", line, lambda b: chord_of(b % s.bars), s.bpb)


def drone_bed(s, low=0.3, fifth=True, cutoff=260.0, shape="saw"):
    """The zone's low D: a sub D1 ([param low]), a breathing D2 and a faint
    A2 (periodic: loop-safe)."""
    n = s.n
    rng = s.rng
    lo = gm.drone(n, m("D1"), rng, "tri", 3.0, 1, 170.0, side=0.3)
    body = gm.drone(n, m("D2"), rng, shape, 6.0, 3, cutoff)
    out = lo * low + body * 0.45 * (0.6 + 0.4 * (0.5 + 0.5 * dsp.lfo(n, 3, 0.6)))[:, None]
    if fifth:
        out = out + gm.drone(n, m("A2"), rng, shape, 8.0, 2, cutoff * 2.5) * 0.12 * (0.5 + 0.5 * dsp.lfo(n, 4, 0.1))[:, None]
    return out


def zone_reverbs(s, space, rt60, pre_delay, dark, early=14, early_span=0.07, early_gain=0.5):
    """'room' (short: drums, guitars), 'space' (the zone's own acoustic,
    after its reverb preset), 'far' (distant voices)."""
    s.reverb("room", rt60=0.9, pre_delay=0.008, dark=0.5, early=16, early_span=0.035, early_gain=0.6)
    s.reverb("space", rt60=rt60, pre_delay=pre_delay, dark=dark, early=early, early_span=early_span, early_gain=early_gain)
    s.reverb("far", rt60=rt60 * 1.35, pre_delay=pre_delay + 0.05, dark=dark * 0.8, early=6, early_span=0.12, early_gain=0.25)


def metal_kit(rng, toms=(150.0, 115.0, 88.0), kick_click=1.0, bus_kick="kick", bus_snare="snare", bus_cym="cym",
              bus_toms="toms"):
    """The standard kit -> Drummer kit dict (name: (bus, maker, takes, pan))."""
    return {
        "kick": (bus_kick, lambda: metal.kick(0.95, rng, click=kick_click), 4, 0.0),
        "snare": (bus_snare, lambda: metal.snare(0.95, rng), 4, 0.05),
        "hat": (bus_cym, lambda: metal.hihat("closed", 0.8, rng), 4, 0.35),
        "open": (bus_cym, lambda: metal.hihat("open", 0.8, rng), 2, 0.35),
        "ride": (bus_cym, lambda: metal.ride(0.75, rng), 3, -0.35),
        "bell": (bus_cym, lambda: metal.ride(0.8, rng, bell=1.0), 2, -0.35),
        "crash": (bus_cym, lambda: metal.crash(0.85, rng), 2, -0.5),
        "crash2": (bus_cym, lambda: metal.crash(0.85, rng), 2, 0.5),
        "china": (bus_cym, lambda: metal.crash(0.85, rng, china=True), 2, 0.55),
        "t1": (bus_toms, lambda: metal.tom(toms[0], 0.9, rng), 2, 0.4),
        "t2": (bus_toms, lambda: metal.tom(toms[1], 0.9, rng), 2, 0.0),
        "t3": (bus_toms, lambda: metal.tom(toms[2], 0.9, rng), 2, -0.4),
    }


def metal_buses(s, stem="combat", room=0.18, space=0.12, kick_eq=None, feeds=None):
    """kick / snare / cym / toms buses of a kit (combat by default)."""
    feeds = feeds or {stem: 0.0}
    s.bus("kick", stem, sends={"room": room * 0.5}, eq=kick_eq or g_mul(g_highpass(45.0, 2), g_bell(3800.0, 3.0, 0.7)),
          feeds=feeds, gain_db=-1.5)
    s.bus("snare", stem, sends={"room": room * 1.8, "space": space}, eq=g_mul(g_highpass(110.0, 2), g_bell(4500.0, 2.0, 0.8)),
          feeds=feeds)
    s.bus("cym", stem, sends={"room": room, "space": space * 0.6}, eq=g_mul(g_highpass(450.0, 2), g_shelf_hi(7000.0, 1.5)),
          feeds=feeds)
    s.bus("toms", stem, sends={"room": room * 1.5, "space": space}, eq=g_highpass(60.0, 2), feeds=feeds)


# drum grooves (16 steps)
G_THRASH = {"kick": "X.x...x.X.x...x.", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."}
G_DOUBLE = {"kick": "xxxxxxxxxxxxxxxx", "snare": "....X.......X...", "ride": "x.x.x.x.x.x.x.x."}
G_BLAST = {"kick": "xxxxxxxxxxxxxxxx", "snare": "x.x.x.x.x.x.x.x.", "crash": "x...x...x...x..."}
G_HALF = {"kick": "X.....x...x.....", "snare": "........X.......", "china": "x...x...x...x..."}
G_DBEAT = {"kick": "X.x.X.x.X.x.X.x.", "snare": "..X...X...X...X.", "ride": "x.x.x.x.x.x.x.x."}
