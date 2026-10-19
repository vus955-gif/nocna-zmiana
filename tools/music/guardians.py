"""The guardians' battle theme ("Straznik skrzydla") in each wing's own
band: the same composition (the guardian motif M1-M4 and the lullaby,
gen_wings) played by the wing's zone band (biomes_west / biomes_east: its
tempo, scale, riffs, kit and culture's voices), arranged as a boss fight:

    wake    hits on the downbeats, a swell        (the guardian rises)
    riff    the wing's riff with the full kit
    motif   the guardian motif on the lead over the riff
    lull    the lullaby on the wing's own voice over a half-time crush
    climax  double kick / blasts, the motif an octave up, the choir
    turn    a fill into the loop, stopping a beat's half before it

Two stems (Music: guardian_<wing> + guardian_<wing>_hi; hi from phase 2
or a hot fight): base -18 LUFS, with hi -16.5. Lengths are whole seconds
(the engine reports them exactly): 60-72 s.

    "$PY" tools/music/gen_music.py guardian_egypt      (or: guardians)
"""
import band
import biomes_east as east
import biomes_west as west
import gen_wings as gw
import instruments as ins
import metal
from band import G_BLAST, G_DOUBLE, G_HALF, G_THRASH, Band, Drummer, Guitarist, bass_of, melody, parse_riff, v_reed
from dsp import g_highpass, g_lowpass, g_mul, g_shelf_lo
from gen_music import m

D2 = band.D2


def _egypt_riff(chord, bar):
    return west.EGYPT_RIFF.get(chord if chord != "D" or bar % 2 == 0 else "D2", west.EGYPT_RIFF["D"])


def _assyria_riff(chord, bar):
    return west.ASSYRIA_RIFF.get(chord, west.ASSYRIA_RIFF["Dm"])


def _greece_riff(chord, bar):
    return west.gallop(gw.root(chord, D2, D2 + 11) - D2)


def _enl_riff(chord, bar):
    r = gw.root(chord, D2, D2 + 11) - D2
    th = east.third_of(chord)
    fifth = 6 if chord == "Em7b5" else 7
    head = "b5" if chord == "Em7b5" else "5"
    return f"{head}:{r} - p{r} {r + th} p{r} {r + fifth} p{r} {r + 12} {head}:{r} - p{r} {r + fifth} p{r} {r + th} p{r} {r + fifth}"


def _asia_riff(chord, bar):
    key = {"D5": "D5", "Dm": "D5", "F": "F5", "C5": "C5"}.get(chord, "D5")
    return east.ASIA_RIFF[("penta", key)]


def _americas_riff(chord, bar):
    return west.americas_riff(chord, "A")


# per wing: tempo, form (bars per part), its riff, the lead's voice, the kit's colour
WINGS = {
    "egypt": {"bpm": 150, "form": [("wake", 4), ("riff", 8), ("motif", 8), ("lull", 8), ("climax", 8), ("turn", 4)],
              "riff": _egypt_riff, "seed": 3101},
    "assyria": {"bpm": 90, "form": [("wake", 2), ("riff", 4), ("motif", 8), ("lull", 4), ("climax", 4), ("turn", 2)],
                "riff": _assyria_riff, "seed": 3201},
    "greece": {"bpm": 180, "form": [("wake", 4), ("riff", 8), ("motif", 8), ("lull", 8), ("climax", 16), ("turn", 4)],
               "riff": _greece_riff, "seed": 3301},
    "enlightenment": {"bpm": 140, "form": [("wake", 2), ("riff", 8), ("motif", 8), ("lull", 8), ("climax", 8), ("turn", 8)],
                      "riff": _enl_riff, "seed": 3401},
    "asia": {"bpm": 144, "form": [("wake", 2), ("riff", 8), ("motif", 8), ("lull", 8), ("climax", 8), ("turn", 2)],
             "riff": _asia_riff, "seed": 3501},
    "americas": {"bpm": 100, "form": [("wake", 2), ("riff", 6), ("motif", 8), ("lull", 4), ("climax", 8), ("turn", 2)],
                 "riff": _americas_riff, "seed": 3601},
}
# the last bar's sixteenth where the band stops: a breath before the loop's
# downbeat (a lossy encoder rebuilds a file's first samples worst)
STOP = 14
MOTIF = gw.M1 + [(b + 8, st, d) for b, st, d in gw.M2] + [(b + 16, st, d) for b, st, d in gw.M3] + \
    [(b + 24, st, d) for b, st, d in gw.M4]


def _voices(wing, rng):
    """The wing's lead voice (voice(midi, seconds, vel)) and colour hit."""
    if wing == "egypt":
        return v_reed(rng, False), (lambda: ins.rattle(0.9, rng, 0.16, "sistrum"))
    if wing == "assyria":
        return v_reed(rng, True), (lambda: ins.anvil(0.8, rng, 620.0))
    if wing == "greece":
        return (lambda midi, sec, vel: metal.aulos(midi, max(sec * 0.95, 0.1), vel, rng)), (lambda: metal.crash(0.7, rng))
    if wing == "enlightenment":
        return (lambda midi, sec, vel: ins.organ([midi, midi + 12], max(sec * 0.96, 0.1), vel * 1.2, rng, release=0.15)), \
            (lambda: ins.clock_tick(False, 0.9, rng))
    if wing == "asia":
        return (lambda midi, sec, vel: ins.flute(midi, max(sec * 0.96, 0.12), vel, rng, "shakuhachi",
                                                 fall=-60.0 if sec > 1.0 else 0.0)), \
            (lambda: ins.frame_drum(215.0, 0.8, rng, "slap"))
    return (lambda midi, sec, vel: ins.flute(midi, max(sec * 0.95, 0.1), vel, rng, "clay")), (lambda: ins.rattle(0.9, rng, 0.08))


def _culture_kit(wing, rng):
    """The wing's drum on top of the kit (bus 'eth')."""
    if wing == "egypt":
        return {"a": ("eth", lambda: ins.frame_drum(108.0, 0.9, rng, "doum", ring=0.6), 3, 0.2),
                "b": ("eth", lambda: ins.frame_drum(122.0, 0.8, rng, "tek"), 4, 0.3)}
    if wing == "assyria":
        return {"a": ("eth", lambda: ins.big_drum(50.0, 1.0, rng, 1.6), 3, 0.0),
                "b": ("eth", lambda: ins.frame_drum(92.0, 0.8, rng, "tek"), 4, 0.3)}
    if wing == "greece":
        return {"a": ("eth", lambda: ins.timpani(m("D2"), 0.9, rng, 1.8), 2, -0.2),
                "b": ("eth", lambda: ins.frame_drum(140.0, 0.8, rng, "tek"), 4, 0.3)}
    if wing == "enlightenment":
        return {"a": ("eth", lambda: ins.timpani(m("D2"), 0.9, rng, 1.6), 2, -0.2),
                "b": ("eth", lambda: ins.timpani(m("A1"), 0.85, rng, 1.6), 2, 0.2)}
    if wing == "asia":
        return {"a": ("eth", lambda: ins.big_drum(52.0, 1.0, rng, 1.3), 4, -0.15),
                "b": ("eth", lambda: ins.big_drum(82.0, 0.8, rng, 0.7), 4, 0.2)}
    return {"a": ("eth", lambda: ins.slit_drum(176.0, 0.9, rng), 3, 0.3),
            "b": ("eth", lambda: metal.tom(124.0, 0.85, rng), 3, -0.3)}


def guardian_theme(wing):
    spec = WINGS[wing]
    chords = gw.GUARD[wing]
    mode = gw.MODE[wing]
    form = []
    at = 0
    for part, bars in spec["form"]:
        form.append((at, bars, part))
        at += bars
    total = at
    s = Band(spec["bpm"], 4, total, seed=spec["seed"], levels={
        "kick": -19.5, "snare": -20.5, "cym": -27.0, "toms": -23.5, "gtr": -16.5, "bass": -19.5, "eth": -23.0,
        "pad": -25.0, "lead": -18.5, "voice": -20.5, "choir": -22.5, "colour": -27.0,
    })
    rng = s.rng
    band.zone_reverbs(s, "arena", rt60=2.6, pre_delay=0.03, dark=0.42, early=14, early_span=0.07)
    band.metal_buses(s, stem="base", room=0.18, space=0.14)
    s.bus("gtr", "base", sends={"room": 0.12}, process=band.rhythm_amp(1.1), stereo_width=0.9)
    s.bus("bass", "base", sends={"room": 0.04}, process=band.bass_rig(1.1))
    s.bus("eth", "base", sends={"room": 0.3, "space": 0.2}, eq=g_mul(g_highpass(48.0, 2), g_shelf_lo(70.0, -2.0)))
    s.bus("pad", "base", sends={"space": 0.5}, eq=g_mul(g_highpass(60.0, 2), g_lowpass(4000.0, 1)))
    s.bus("lead", "hi", sends={"space": 0.35, "room": 0.1}, process=band.lead_amp(0.9))
    s.bus("voice", "hi", sends={"space": 0.4}, eq=g_highpass(200.0, 2))
    s.bus("choir", "hi", sends={"space": 0.7}, eq=g_highpass(120.0, 2))
    s.bus("colour", "hi", sends={"space": 0.4}, eq=g_highpass(300.0, 2))

    part_of = lambda bar: band.section_of(form, bar)
    starts = {a: p for a, _, p in form}

    def chord_of(bar):
        part = part_of(bar)
        start = next(a for a, _, p in form if p == part and a <= bar)
        k = bar - start
        if part == "lull":
            return chords["B"][k % 8]
        if part in ("turn", "wake"):
            return chords["turn"][k % 4] if part == "turn" else chords["A"][0]
        return chords["A"][k % 8]

    s.chord_of = chord_of
    dr = Drummer(s, rng, band.metal_kit(rng))
    eth = Drummer(s, rng, _culture_kit(wing, rng))
    gtr = Guitarist(s, "gtr", rng)
    bass = Guitarist(s, "bass", rng, pans=(0.0,), bass=True)
    voice, colour = _voices(wing, rng)
    hits = Drummer(s, rng, {"c": ("colour", colour, 3, 0.4)})
    for bar in range(total):
        part, chord = part_of(bar), chord_of(bar)
        r = gw.root(chord, D2, D2 + 11) - D2
        # drums
        if part == "wake":
            dr.hit("crash", s.at(bar), 1.0)
            dr.hit("kick", s.at(bar), 1.0)
            eth.hit("a", s.at(bar), 1.0)
            if bar % 2 == 1 or spec["form"][0][1] == 2:
                dr.fill(bar, ["t3", "t3", "t2", "t2", "t1", "t1", "snare", "snare"], 8, 8, (0.4, 1.0))
            riff = parse_riff(f"5o:{r} - - - - - - - - - - - - - - -")
        elif part == "lull":
            dr.bar(bar, G_HALF)
            eth.bar(bar, {"a": "X.......X.......", "b": "....x.......x..."})
            riff = parse_riff(f"5o:{r} - - - - - - - p{r} p{r} p{r} p{r} 5:{r} - - -")
        else:
            groove = {"riff": G_THRASH, "motif": G_DOUBLE, "climax": G_BLAST if wing != "assyria" else G_DOUBLE,
                      "turn": G_DOUBLE}[part]
            beats = {"a": "X.......X.......", "b": "..x.x.....x.x..."}
            if bar == total - 1:   # the band stops before the guardian's downbeat
                groove = {k: v[:STOP] + "." * (16 - STOP) for k, v in groove.items()}
                beats = {k: v[:STOP] + "." * (16 - STOP) for k, v in beats.items()}
            dr.bar(bar, groove)
            eth.bar(bar, beats, vel=0.85)
            riff = parse_riff(spec["riff"](chord, bar))
        if bar in starts:
            dr.hit("crash2", s.at(bar), 0.9)
        if part != "wake" and bar % 4 == 3 and bar != total - 1:
            dr.fill(bar, ["t1", "t2", "t3", "t3"], 12, 4, (0.7, 1.0))
        if bar == total - 1:
            riff = [(st, min(n, STOP - st), note, art) for st, n, note, art in riff if st < STOP]
        gtr.riff(bar, riff)
        bass.riff(bar, bass_of(riff), 0.95)
        if part in ("lull", "wake"):
            s.add("pad", s.at(bar), ins.strings(gw.voicing(chord, 38), s.sec(4) + 0.2, 0.7, rng, attack=0.5, release=1.0,
                                                bright=0.8))
        if part in ("motif", "climax"):
            hits.bar(bar, {"c": "....x.......x..."})
    dr.fill(total - 1, ["snare"], 0, STOP, (0.35, 1.0))
    s.duck("bass", dr.kicks, -3.0, 0.08)

    # hi: the guardian motif on the lead guitar and the wing's voice, the lullaby, the choir
    motif_at = next(a for a, _, p in form if p == "motif")
    climax_at, climax_bars = next((a, b) for a, b, p in form if p == "climax")
    lull_at, lull_bars = next((a, b) for a, b, p in form if p == "lull")
    band.lead_line(s, "lead", motif_at, MOTIF, mode, rng, shift=-12, vel=0.9)
    melody(s, "voice", motif_at, MOTIF, voice, mode, vel=0.75, pan=0.25)
    for k in range(0, climax_bars, 8):
        motif = [(b, st, d) for b, st, d in MOTIF if b < min(8, climax_bars - k) * 4]
        band.lead_line(s, "lead", climax_at + k, motif, mode, rng, shift=0, vel=0.9)
        melody(s, "voice", climax_at + k, motif, voice, mode, shift=0 if wing != "assyria" else -12, vel=0.75, pan=-0.25)
    lullaby = [(b, st, d) for b, st, d in gw.LULL44 if b < lull_bars * 4]
    melody(s, "voice", lull_at, lullaby, voice, mode, vel=0.8, pan=0.1)
    for bar in list(range(lull_at, lull_at + lull_bars)) + list(range(climax_at, climax_at + climax_bars)):
        notes = [x + 12 for x in gw.voicing(chord_of(bar), 50)[1:]]
        s.add("choir", s.at(bar), ins.choir(notes, s.sec(4) - 0.1, 0.8, rng, ins.VOWEL_O if wing in ("assyria",
                                            "enlightenment") else ins.VOWEL_A, attack=0.3, release=0.8))
    if wing == "americas":
        s.bus("whistle", "hi", sends={"space": 0.5}, level=-21.0)
        for bar in (motif_at + 7, climax_at + 7):
            s.add("whistle", s.at(bar, 2.0), metal.death_whistle(s.sec(1.6), 0.9, rng), pan=-0.4)
    band.master_guardian(s.render(verbose=False), wing, spec["seed"])


def tracks():
    out = {f"guardian_{w}": (lambda w=w: guardian_theme(w)) for w in WINGS}
    out["guardians"] = lambda: [guardian_theme(w) for w in WINGS]
    return out
