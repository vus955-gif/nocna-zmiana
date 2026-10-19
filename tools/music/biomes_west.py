"""The western wings' music zones (see gen_biomes.py for the whole score):
Egypt (oriental death/thrash in Hijaz), Assyria (a doom war march in
Kurd), Greece (galloping heavy metal, Dorian with a Mixolydian lift),
the Americas (tribal groove metal). Each zone: one loop, four synced stems
(band.py)."""
import band
import gen_wings as gw
import instruments as ins
import metal
import modes as md
from band import (G_BLAST, G_DBEAT, G_DOUBLE, G_HALF, G_THRASH, Band, Drummer, Guitarist, bass_of, melody, parse_riff,
                  v_flute, v_reed)
from dsp import g_highpass, g_lowpass, g_mul, g_shelf_hi, g_shelf_lo
from gen_music import m

D2 = band.D2


def starts(form):
    return {start for start, _, _ in form}


def arp_clean(s, guitar, bar, chord, figure, vel=0.8, low=50):
    """A clean-guitar figure [(step, steps, chord-tone index)] over
    [param chord]'s tones climbing from a root in [low, low + 11]."""
    tones = gw.arp(chord, low)
    guitar.riff(bar, [(st, n, tones[i] - D2, "ring") for st, n, i in figure], vel)


# --- Egypt: "Piaski nocy" - oriental death/thrash in Hijaz ------------------------------

EGYPT_BARS = 60
EGYPT_FORM = [(0, 8, "A"), (8, 8, "A2"), (16, 8, "B"), (24, 8, "C"), (32, 8, "A"), (40, 8, "D"), (48, 8, "B2"),
              (56, 4, "turn")]
EGYPT_CHORDS = band.progression([
    (0, 8, ["D", "D", "Eb", "D", "D", "D", "Cm", "Eb"]), (8, 8, ["Gm", "Cm", "Eb", "D", "D", "D", "Cm", "Eb"]),
    (16, 8, ["Gm", "Gm", "Cm", "Cm", "Gm", "Gm", "Eb", "D"]), (24, 8, ["D", "D", "Eb", "Eb", "Cm", "Cm", "D", "D"]),
    (32, 8, ["D", "D", "Eb", "D", "D", "D", "Cm", "Eb"]), (40, 8, ["D", "Eb", "D", "Eb", "Gm", "Cm", "Eb", "D"]),
    (48, 8, ["Gm", "Gm", "Cm", "Cm", "Gm", "Gm", "Eb", "D"]), (56, 4, ["D", "Eb", "D", "Eb"])])
EGYPT_RIFF = {
    "D": "5:0 - p p 1 - p p 4 - 5 4 1 - p p",
    "D2": "5:0 - p p 1 - p p 4 - 7 - 8 - 7 4",
    "Eb": "5:1 - - p p p 5:1 - p p 1 - p p 4 1",
    "Cm": "5:10 - - p p p 5:10 - p p 8 - 7 - 4 1",
    "Gm": "5:5 - - p p p 5:5 - p p 4 - 1 - p p",
    "trem_D": "1 1 1 1 0 0 0 0 4 4 4 4 1 1 1 1",
    "trem_Eb": "5:1 - - - 1 1 1 1 4 4 4 4 5 5 4 1",
}
# hi: the guitar lead's phrases (beats, Hijaz steps; the raised seventh makes them double harmonic)
EGYPT_LEAD = {
    "B1": [(0, 10, 2), (2, 12, 1), (3, 11, 1), (4, 10, 3), (7, 9, 1), (8, 8, 2), (10, 10, 1), (11, 9, 1), (12, 8, 3), (15, 6, 1)],
    "B2": [(0, 7, 2), (2, 10, 1), (3, 9, 1), (4, 10, 4), (8, 12, 2), (10, 10, 1), (11, 8, 1), (12, 9, 4)],
    "D1": [(0, 7, 1), (1, 8, 1), (2, 9, 2), (4, 8, 2), (6, 10, 1), (7, 12, 1), (8, 11, 2), (10, 9, 1), (11, 8, 1), (12, 10, 4)],
    "D2": [(0, 10, 2), (2, 12, 1), (3, 10, 1), (4, 8, 3), (7, 6, 1), (8, 5, 2), (10, 3, 1), (11, 1, 1), (12, 0, 4)],
}


def egypt_riff(chord, tag, bar):
    if tag == "D" and chord in ("D", "Eb"):
        return EGYPT_RIFF["trem_" + chord]
    if chord == "D":
        return EGYPT_RIFF["D2" if bar % 2 else "D"]
    return EGYPT_RIFF[chord]


def zone_egypt():
    s = Band(150, 4, EGYPT_BARS, seed=2101, levels={
        "drone": -27.0, "pad": -27.5, "clean": -23.5, "ney": -21.0, "oud": -24.0, "doum": -25.5, "tek": -28.0, "zill": -32.0,
        "darbuka": -22.0, "ttoms": -25.0, "tbass": -23.0, "tgtr": -24.5, "swell": -29.0,
        "kick": -20.5, "snare": -21.5, "cym": -27.5, "toms": -24.0, "gtr": -17.0, "bass": -20.5, "cdarb": -25.0, "cdrone": -29.0,
        "lead": -19.5, "mizmar": -22.5, "choir": -24.5, "sistrum": -30.0, "hcym": -29.0,
    })
    rng = s.rng
    mode = "hijaz"
    band.zone_reverbs(s, "gallery", rt60=3.0, pre_delay=0.045, dark=0.4, early=14, early_span=0.08)
    s.bus("drone", "explore", sends={"space": 0.25}, eq=g_shelf_lo(70.0, -5.0))
    s.bus("cdrone", "combat", sends={"space": 0.2}, eq=g_mul(g_highpass(60.0, 2), g_lowpass(1500.0, 2)))
    s.bus("pad", "explore", sends={"space": 0.6}, eq=g_mul(g_lowpass(2000.0, 2), g_highpass(45.0, 2)))
    s.bus("clean", "explore", sends={"space": 0.55}, process=band.clean_chorus(0.6), stereo_width=1.1)
    s.bus("ney", "explore", sends={"far": 0.8, "space": 0.3}, eq=g_mul(g_highpass(200.0, 2), g_shelf_hi(6000.0, -3.0)))
    s.bus("oud", "explore", sends={"space": 0.4}, eq=g_highpass(90.0, 2))
    s.bus("doum", "explore", sends={"space": 0.3}, eq=g_shelf_lo(60.0, -2.0))
    s.bus("tek", "explore", sends={"space": 0.3}, eq=g_highpass(300.0, 2))
    s.bus("zill", "explore", sends={"space": 0.4}, eq=g_highpass(2500.0, 2))
    s.bus("darbuka", "tension", sends={"room": 0.3, "space": 0.2}, eq=g_highpass(70.0, 2))
    s.bus("ttoms", "tension", sends={"room": 0.3, "space": 0.3}, eq=g_highpass(55.0, 2))
    s.bus("tbass", "tension", sends={"room": 0.05}, process=band.bass_rig(0.8))
    s.bus("tgtr", "tension", sends={"room": 0.25, "space": 0.15}, process=band.rhythm_amp(0.7), stereo_width=0.7,
          eq=g_lowpass(3500.0, 2))
    s.bus("swell", "tension", sends={"space": 0.5}, stereo_width=1.2)
    band.metal_buses(s)
    s.bus("gtr", "combat", sends={"room": 0.12}, process=band.rhythm_amp(1.0), stereo_width=0.9)
    s.bus("bass", "combat", sends={"room": 0.04}, process=band.bass_rig(1.1))
    s.bus("cdarb", "combat", sends={"room": 0.3}, eq=g_highpass(120.0, 2))
    s.bus("lead", "hi", sends={"space": 0.35, "room": 0.1}, process=band.lead_amp(0.85))
    s.bus("mizmar", "hi", sends={"space": 0.4}, eq=g_highpass(250.0, 2))
    s.bus("choir", "hi", sends={"space": 0.7}, eq=g_highpass(150.0, 2))
    s.bus("sistrum", "hi", sends={"space": 0.4}, eq=g_highpass(2500.0, 2))
    s.bus("hcym", "hi", sends={"room": 0.2, "space": 0.3}, eq=g_highpass(500.0, 2))

    tag_of = lambda bar: band.section_of(EGYPT_FORM, bar)
    chord_of = lambda bar: EGYPT_CHORDS[bar]
    s.chord_of = chord_of

    # --- explore: drone, pad, clean Hijaz arpeggios, the ney's lullaby, a soft maqsum, oud tremolo
    bed = band.drone_bed(s)
    s.add("drone", 0, bed)
    s.add("cdrone", 0, bed)
    for bar in range(0, EGYPT_BARS, 4):
        s.add("pad", s.at(bar), ins.strings(gw.voicing(chord_of(bar), 38), s.sec(16) - 0.3, 0.5, rng, attack=2.0,
                                            release=2.5, bright=0.6), 0.9)
    clean = Guitarist(s, "clean", rng, pans=(0.0,), bright=0.7)
    for bar in range(EGYPT_BARS):
        chord = chord_of(bar)
        r = gw.root(chord, 50, 61) - D2
        third = 4 if chord in ("D", "Eb") else 3
        figure = [(0, 2, r, "ring"), (2, 2, r + 7, "ring"), (4, 2, r + 12, "ring"), (6, 2, r + 12 + third, "ring"),
                  (8, 2, r + 7, "ring"), (10, 2, r + 13 if chord == "D" else r + 12, "ring"), (12, 4, r + 12, "ring")]
        if tag_of(bar) == "C" or bar % 2 == 1:
            figure = figure[:4] + [(8, 8, r + 7, "ring")]
        clean.riff(bar, figure, 0.8)
    ney = v_flute(rng, "ney")
    melody(s, "ney", 4, md.LULLABY_A[:9], ney, mode, unit=2.0, vel=0.8)
    melody(s, "ney", 32, [(b - 12, st, d) for b, st, d in md.LULLABY_A[9:]], ney, mode, unit=2.0, vel=0.85)
    melody(s, "ney", 44, [(0, 10, 3), (3, 8, 1), (4, 8, 2), (6, 6, 2), (8, 5, 4), (12, 4, 2), (14, 7, 2)], ney, mode, vel=0.7)
    for bar in range(16, 24, 2):
        run = [(4, 0), (4, 1), (4, 4), (4, 1)] if chord_of(bar) == "Gm" else [(4, 1), (4, 0), (8, 1)]
        at = 0
        for steps, off in run:
            note = gw.root(chord_of(bar), 50, 61) + off
            for k in range(steps):
                s.add("oud", s.step(bar, at + k, 0.002), metal.oud(note, 0.55 + 0.15 * (k == 0), rng), pan=-0.3)
            at += steps
    kit_e = Drummer(s, rng, {
        "doum": ("doum", lambda: ins.frame_drum(70.0, 0.85, rng, "doum", ring=1.2), 3, -0.1),
        "tek": ("tek", lambda: ins.frame_drum(118.0, 0.7, rng, "tek"), 4, 0.25),
        "zill": ("zill", lambda: ins.rattle(0.7, rng, 0.12, "sistrum"), 3, 0.45)})
    for bar in range(EGYPT_BARS):
        kit_e.bar(bar, {"doum": "X.......x.......", "tek": "..x...x.....x..."}, vel=0.8)
        if bar % 2 == 1:
            kit_e.bar(bar, {"zill": "....x.......x..."}, vel=0.7)

    # --- tension: the darbuka's maqsum with ornaments, toms, the bass pedal, quiet chugs, a swell
    kit_t = Drummer(s, rng, {
        "doum": ("darbuka", lambda: ins.frame_drum(108.0, 0.9, rng, "doum", ring=0.6), 4, 0.15),
        "tek": ("darbuka", lambda: ins.frame_drum(122.0, 0.8, rng, "tek"), 5, 0.2),
        "slap": ("darbuka", lambda: ins.frame_drum(150.0, 0.8, rng, "slap"), 3, 0.25),
        "t2": ("ttoms", lambda: metal.tom(110.0, 0.85, rng), 2, -0.2),
        "t3": ("ttoms", lambda: metal.tom(82.0, 0.9, rng), 2, -0.35)})
    for bar in range(EGYPT_BARS):
        orn = bar % 4 == 3
        kit_t.bar(bar, {"doum": "X.....x.X.......", "tek": "..x.x....xx.x.xx" if orn else "..x.x.....x.x...",
                        "slap": "..............x." if orn else ""})
        kit_t.bar(bar, {"t3": "X.......X.......", "t2": "..............x." if bar % 8 == 7 else ""})
    tbass = Guitarist(s, "tbass", rng, pans=(0.0,), bass=True)
    tg = Guitarist(s, "tgtr", rng, pans=(-0.6, 0.6))
    for bar in range(EGYPT_BARS):
        r = gw.root(chord_of(bar), D2, D2 + 11) - D2
        line = parse_riff(f"p{r} . p . p{r} . p . p{r} . p . p{r} . p{1 if r == 0 else r} .")
        tbass.riff(bar, bass_of(line), 0.85)
        if tag_of(bar) != "C":
            tg.riff(bar, line, 0.7)
    s.add("swell", s.at(56), metal.riser(s.sec(16), rng))

    # --- combat: Hijaz riffs over the metal kit, the darbuka in the mix
    dr = Drummer(s, rng, band.metal_kit(rng))
    gtr = Guitarist(s, "gtr", rng)
    bass = Guitarist(s, "bass", rng, pans=(0.0,), bass=True)
    darb = Drummer(s, rng, {"doum": ("cdarb", lambda: ins.frame_drum(110.0, 0.9, rng, "doum", ring=0.5), 3, 0.2),
                            "tek": ("cdarb", lambda: ins.frame_drum(124.0, 0.8, rng, "tek"), 4, 0.3)})
    heads = starts(EGYPT_FORM)
    for bar in range(EGYPT_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        groove = {"A": G_THRASH, "A2": G_DOUBLE, "B": G_HALF, "C": G_HALF, "D": G_BLAST, "B2": G_DOUBLE, "turn": G_DBEAT}[tag]
        if tag == "C" and bar >= 28:
            groove = G_DOUBLE
        dr.bar(bar, groove)
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
        if bar % 8 == 7 and bar != EGYPT_BARS - 1:
            dr.fill(bar, ["t1", "t1", "t2", "t2", "t3", "t3", "snare", "snare"], 8, 8, (0.6, 1.0))
        darb.bar(bar, {"doum": "x.......x.......", "tek": "..x.x.....x.x..."}, vel=0.8)
        riff = parse_riff(egypt_riff(chord, tag, bar))
        if tag == "C" and bar < 28:
            riff = parse_riff("5:0 - - - - - - - 5:1 - - - - - - -" if chord != "Cm" else "5:10 - - - - - - - 5:8 - - - 5:7 - - -")
        gtr.riff(bar, riff)
        bass.riff(bar, bass_of(riff), 0.95)
    dr.fill(EGYPT_BARS - 1, ["snare"], 0, 16, (0.35, 1.0))
    s.duck("bass", dr.kicks, -3.0, 0.08)

    # --- hi: the guitar lead in double harmonic, the mizmar an octave over it, calls, choir, sistrum
    alter = {6: 1}   # C -> C#: Hijaz -> double harmonic in the leads
    reed = v_reed(rng, False)
    for bar0, key in [(16, "B1"), (20, "B2"), (40, "D1"), (44, "D2"), (48, "B1"), (52, "B2")]:
        band.lead_line(s, "lead", bar0, EGYPT_LEAD[key], mode, rng, shift=-12, vel=0.9, alter=alter)
        melody(s, "mizmar", bar0, EGYPT_LEAD[key], reed, mode, vel=0.75, pan=0.3, alter=alter)
    for bar0 in (2, 10, 34):
        melody(s, "mizmar", bar0, [(4, 9, 1), (5, 8, 1), (6, 7, 2)], reed, mode, vel=0.7, pan=-0.3)
        melody(s, "mizmar", bar0 + 4, [(4, 12, 1), (5, 10, 0.5), (5.5, 9, 0.5), (6, 8, 2)], reed, mode, vel=0.7, pan=0.3)
    for bar in range(40, 48):
        notes = [x + 12 for x in gw.voicing(chord_of(bar), 50)[1:]]
        s.add("choir", s.at(bar), ins.choir(notes, s.sec(4) - 0.1, 0.7, rng, ins.VOWEL_A, attack=0.3, release=0.8))
    hk = Drummer(s, rng, {"sis": ("sistrum", lambda: ins.rattle(0.9, rng, 0.16, "sistrum"), 3, -0.4),
                          "china": ("hcym", lambda: metal.crash(0.8, rng, china=True), 2, -0.6)})
    for bar in range(EGYPT_BARS):
        hk.bar(bar, {"sis": "....x.......x..."})
        if tag_of(bar) in ("D", "B2") and bar % 2 == 0:
            hk.hit("china", s.at(bar, 2.0), 0.8)
    return band.master_zone(s.render(), "egypt", 2101)


# --- Assyria: "Lwy Niniwy" - a doom war march in Kurd -------------------------------------

ASSYRIA_BARS = 36
ASSYRIA_FORM = [(0, 8, "A"), (8, 8, "B"), (16, 8, "C"), (24, 8, "A2"), (32, 4, "turn")]
ASSYRIA_CHORDS = band.progression([
    (0, 8, ["Dm", "Dm", "Eb", "Dm", "Dm", "Dm", "Bb", "Cm"]), (8, 8, ["Gm", "Gm", "Eb", "Eb", "Cm", "Cm", "Dm", "Dm"]),
    (16, 8, ["Dm", "Eb", "Dm", "Eb", "Bb", "Bb", "Cm", "Eb"]), (24, 8, ["Dm", "Dm", "Eb", "Dm", "Dm", "Dm", "Bb", "Cm"]),
    (32, 4, ["Dm", "Eb", "Cm", "Eb"])])
ASSYRIA_RIFF = {
    "Dm": "5:0 - - - - - - - 5:1 - - - 5:0 - p p",
    "Eb": "5:1 - - - - - - - 5:0 - - - 5:1 - p p",
    "Bb": "5:8 - - - - - - - b5:7 - - - 5:5 - p p",
    "Cm": "5:10 - - - - - - - 5:8 - - - b5:7 - - -",
    "Gm": "5:5 - - - - - - - 5:3 - - - 5:5 - p p",
    "sludge": "p p p p 5:1 - p p p p 5:0 - p p 5:1 -",
    "sludge_b": "p p p p 5:8 - p p p p b5:7 - p p 5:5 -",
}
# the duduk's laments (Kurd steps, played an octave down): over B (Gm Gm Eb Eb Cm Cm Dm Dm) and A2
LAMENT = [(0, [(0, 10, 4)]), (1, [(0, 12, 3), (3, 10, 1)]), (2, [(0, 8, 4)]), (3, [(0, 9, 2), (2, 8, 2)]),
          (4, [(0, 10, 3), (3, 8, 1)]), (5, [(0, 6, 4)]), (6, [(0, 7, 6)]), (7, [(2, 4, 2)])]
LAMENT_A2 = [(0, [(0, 7, 4)]), (1, [(0, 9, 3), (3, 8, 1)]), (2, [(0, 12, 4)]), (3, [(0, 11, 4)]), (4, [(0, 9, 4)]),
             (5, [(0, 7, 2), (2, 9, 2)]), (6, [(0, 7, 4)]), (7, [(0, 6, 4)])]


def zone_assyria():
    s = Band(90, 4, ASSYRIA_BARS, seed=2201, levels={
        "drone": -27.0, "pad": -27.0, "lyre": -22.0, "duduk": -21.0, "clean": -24.0, "doum": -25.0,
        "march": -21.5, "big": -23.0, "bronze": -28.0, "tgtr": -24.0, "tbass": -23.5, "swell": -29.0,
        "kick": -20.0, "snare": -21.5, "cym": -28.0, "toms": -24.0, "gtr": -16.8, "bass": -20.0, "cbig": -24.0,
        "cdrone": -29.0, "lead": -20.5, "reeds": -21.5, "choir": -24.0, "hbronze": -27.0,
    })
    rng = s.rng
    mode = "kurd"
    band.zone_reverbs(s, "gallery", rt60=3.4, pre_delay=0.05, dark=0.36, early=16, early_span=0.09, early_gain=0.55)
    s.bus("drone", "explore", sends={"space": 0.25}, eq=g_shelf_lo(65.0, -4.0))
    s.bus("cdrone", "combat", sends={"space": 0.2}, eq=g_mul(g_highpass(60.0, 2), g_lowpass(1400.0, 2)))
    s.bus("pad", "explore", sends={"space": 0.55}, eq=g_mul(g_lowpass(1600.0, 2), g_highpass(40.0, 2)))
    s.bus("lyre", "explore", sends={"space": 0.5}, eq=g_highpass(80.0, 2), stereo_width=1.1)
    s.bus("duduk", "explore", sends={"far": 0.8, "space": 0.3}, eq=g_highpass(120.0, 2))
    s.bus("clean", "explore", sends={"space": 0.8, "far": 0.3}, process=band.clean_chorus(0.4, bright=0.7))
    s.bus("doum", "explore", sends={"space": 0.4}, eq=g_mul(g_lowpass(1400.0, 2), g_highpass(48.0, 2)))
    s.bus("march", "tension", sends={"room": 0.25, "space": 0.3}, eq=g_shelf_lo(55.0, -2.0))
    s.bus("big", "tension", sends={"space": 0.35, "far": 0.3}, eq=g_mul(g_highpass(45.0, 2), g_shelf_lo(70.0, -3.0)))
    s.bus("bronze", "tension", sends={"space": 0.5}, eq=g_highpass(300.0, 2))
    s.bus("tgtr", "tension", sends={"space": 0.35}, process=band.rhythm_amp(0.8, tight=80.0), stereo_width=0.8,
          eq=g_lowpass(3000.0, 2))
    s.bus("tbass", "tension", sends={"room": 0.05}, process=band.bass_rig(0.9))
    s.bus("swell", "tension", sends={"space": 0.5}, stereo_width=1.2)
    band.metal_buses(s, room=0.22, space=0.18)
    s.bus("gtr", "combat", sends={"room": 0.15, "space": 0.08}, process=band.rhythm_amp(1.15, tight=80.0, cab=5600.0),
          stereo_width=0.9)
    s.bus("bass", "combat", sends={"room": 0.04}, process=band.bass_rig(1.3))
    s.bus("cbig", "combat", sends={"space": 0.3}, eq=g_mul(g_highpass(48.0, 2), g_shelf_lo(70.0, -3.0)))
    s.bus("lead", "hi", sends={"space": 0.4}, process=band.lead_amp(0.8))
    s.bus("reeds", "hi", sends={"space": 0.45}, eq=g_highpass(150.0, 2))
    s.bus("choir", "hi", sends={"space": 0.7}, eq=g_highpass(100.0, 2))
    s.bus("hbronze", "hi", sends={"space": 0.5}, eq=g_highpass(300.0, 2))

    tag_of = lambda bar: band.section_of(ASSYRIA_FORM, bar)
    chord_of = lambda bar: ASSYRIA_CHORDS[bar]
    s.chord_of = chord_of

    # --- explore: drone, pad, the lyre, the duduk's lament, a ringing "doom" guitar, a far war drum
    bed = band.drone_bed(s, cutoff=220.0)
    s.add("drone", 0, bed)
    s.add("cdrone", 0, bed)
    for bar in range(0, ASSYRIA_BARS, 2):
        s.add("pad", s.at(bar), ins.strings(gw.voicing(chord_of(bar), 38), s.sec(8) - 0.3, 0.45, rng, attack=2.5,
                                            release=3.0, bright=0.55), 0.9)
    for bar in range(ASSYRIA_BARS):
        tones = gw.arp(chord_of(bar), 50)
        picks = [(0, 0), (1, 2), (2, 1), (3, 3)] if bar % 2 == 0 else [(0, 2), (2, 4), (3, 3)]
        if tag_of(bar) == "C":
            picks = [(0, 0), (2, 2)]
        for beat, i in picks:
            s.add("lyre", s.at(bar, beat, 0.008), ins.lyre(tones[i], 0.6 * rng.uniform(0.9, 1.05), rng), pan=-0.3)
    duduk = v_reed(rng, True)
    for base, lament in ((8, LAMENT), (24, LAMENT_A2)):
        for bar, notes in lament:
            melody(s, "duduk", base + bar, notes, duduk, mode, shift=-12, vel=0.75)
    clean = Guitarist(s, "clean", rng, pans=(0.0,), bright=0.5)
    for bar in range(ASSYRIA_BARS):
        if tag_of(bar) in ("A", "C", "A2"):
            r = gw.root(chord_of(bar), D2, D2 + 11) - D2
            clean.riff(bar, [(0, 8, (r, "5o"), "ring"), (8, 8, (r + 12, "5"), "ring")], 0.6)
    kit_e = Drummer(s, rng, {"doum": ("doum", lambda: ins.frame_drum(64.0, 0.75, rng, "doum", ring=1.5), 3, -0.1)})
    for bar in range(ASSYRIA_BARS):
        kit_e.bar(bar, {"doum": "X.......x......."}, vel=0.8)

    # --- tension: the march (frame drums, the great drum), bronze, ringing fuzz chords, the bass
    kit_t = Drummer(s, rng, {
        "doum": ("march", lambda: ins.frame_drum(72.0, 0.9, rng, "doum", ring=1.0), 4, 0.15),
        "tek": ("march", lambda: ins.frame_drum(92.0, 0.75, rng, "tek"), 4, 0.25),
        "big": ("big", lambda: ins.big_drum(44.0, 0.95, rng, 2.0), 3, -0.1),
        "bronze": ("bronze", lambda: ins.anvil(0.8, rng, 640.0), 2, 0.45)})
    tg = Guitarist(s, "tgtr", rng, pans=(-0.7, 0.7))
    tbass = Guitarist(s, "tbass", rng, pans=(0.0,), bass=True)
    for bar in range(ASSYRIA_BARS):
        kit_t.bar(bar, {"doum": "X.....x.X.......", "tek": "....x.....x.x.x.", "big": "X.......X......."})
        if bar % 4 == 3:
            kit_t.hit("bronze", s.at(bar, 3.0), 0.8)
        r = gw.root(chord_of(bar), D2, D2 + 11) - D2
        tg.riff(bar, [(0, 16, (r, "5"), "ring")], 0.75)
        tbass.riff(bar, [(0, 8, r - 12, "open"), (8, 6, r - 12, "open"), (14, 2, r - 12, "pm")], 0.85)
    s.add("swell", s.at(32), metal.riser(s.sec(16), rng))

    # --- combat: crushing riffs, double kick in B, sludge in C, the great drum in the mix
    dr = Drummer(s, rng, band.metal_kit(rng, toms=(130.0, 98.0, 74.0)))
    big = Drummer(s, rng, {"big": ("cbig", lambda: ins.big_drum(50.0, 1.0, rng, 1.6), 3, 0.0)})
    gtr = Guitarist(s, "gtr", rng)
    bass = Guitarist(s, "bass", rng, pans=(0.0,), bass=True)
    heads = starts(ASSYRIA_FORM)
    for bar in range(ASSYRIA_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        groove = {"A": {"kick": "X.....x.X.x.....", "snare": "....X.......X...", "ride": "x...x...x...x..."},
                  "B": G_DOUBLE, "C": G_HALF, "A2": G_DOUBLE, "turn": G_THRASH}[tag]
        dr.bar(bar, groove)
        big.bar(bar, {"big": "X.......X......."} if tag != "C" else {"big": "X..............."})
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
            dr.hit("crash2", s.at(bar), 0.8)
        if bar % 4 == 3:
            dr.fill(bar, ["t1", "t2", "t3", "t3"], 12, 4, (0.7, 1.0))
        text = ASSYRIA_RIFF.get(chord, ASSYRIA_RIFF["Dm"])
        if tag == "C":
            text = ASSYRIA_RIFF["sludge_b" if chord == "Bb" else "sludge"]
        riff = parse_riff(text)
        gtr.riff(bar, riff, 1.0, gap=0.95)
        bass.riff(bar, bass_of(riff), 0.95)
    s.duck("bass", dr.kicks, -3.0, 0.1)

    # --- hi: the lament on duduk and mizmar an octave up, a Kurd guitar lead, a low choir, bronze
    mizmar = v_reed(rng, False)
    for base, lament in ((8, LAMENT), (24, LAMENT_A2)):
        for bar, notes in lament:
            melody(s, "reeds", base + bar, notes, duduk, mode, shift=-12, vel=0.8, pan=-0.2)
            melody(s, "reeds", base + bar, notes, mizmar, mode, shift=0, vel=0.6, pan=0.25)
    # over C (Dm Eb Dm Eb Bb Bb Cm Eb)
    lead = [(0, 7, 2), (2, 9, 1), (3, 7, 1), (4, 5, 4), (8, 6, 2), (10, 4, 1), (11, 3, 1), (12, 3, 4),
            (16, 7, 2), (18, 9, 2), (20, 7, 4), (24, 6, 2), (26, 5, 2), (28, 8, 4)]
    band.lead_line(s, "lead", 16, lead, mode, rng, shift=-12, vel=0.9)
    for bar in list(range(0, 16)) + list(range(24, 32)):
        notes = [x for x in gw.voicing(chord_of(bar), 45)[:3]]
        s.add("choir", s.at(bar), ins.choir(notes, s.sec(4) - 0.1, 0.75, rng, ins.VOWEL_O, attack=0.4, release=0.9))
    hb = Drummer(s, rng, {"bronze": ("hbronze", lambda: ins.anvil(0.8, rng, 620.0), 3, 0.5)})
    for bar in range(ASSYRIA_BARS):
        hb.bar(bar, {"bronze": "....x.......x..." if tag_of(bar) in ("B", "A2") else "............x..."})
    return band.master_zone(s.render(), "assyria", 2201)


# --- Greece: "Marmur i ksiezyc" - galloping heavy metal (Dorian, a Mixolydian lift) ------

GREECE_BARS = 72
GREECE_FORM = [(0, 16, "A"), (16, 16, "B"), (32, 16, "C"), (48, 16, "A2"), (64, 8, "turn")]
GREECE_CHORDS = band.progression([
    (0, 16, ["Dm", "Dm", "C", "C", "G", "G", "Dm", "Dm"]), (16, 16, ["D", "D", "C", "C", "G", "G", "D", "D"]),
    (32, 16, ["Am", "Am", "G", "G", "F", "F", "G", "G", "Am", "Am", "G", "G", "F", "F", "Em", "Em"]),
    (48, 16, ["Dm", "Dm", "C", "C", "G", "G", "Dm", "Dm"]), (64, 8, ["Dm", "C", "G", "G", "D", "C", "G", "G"])])
# the twin lead's tune (Dorian steps; B part Mixolydian), 8 bars = 32 beats
GREECE_TUNE = [(0, 7, 3), (3, 8, 1), (4, 9, 4), (8, 8, 2), (10, 7, 2), (12, 6, 4), (16, 4, 2), (18, 5, 2), (20, 7, 4),
               (24, 9, 3), (27, 8, 1), (28, 7, 4)]
# the second guitar's line over it (thirds, a sixth or a fourth where a third would rub)
GREECE_TWIN = [(0, 9, 3), (3, 10, 1), (4, 11, 4), (8, 10, 2), (10, 8, 2), (12, 8, 4), (16, 7, 2), (18, 7, 2), (20, 12, 4),
               (24, 11, 3), (27, 10, 1), (28, 9, 4)]
# the bridge (Am Am G G F F G G / ... F F Em Em) on the aulos
GREECE_BRIDGE = [(0, 11, 3), (3, 13, 1), (4, 8, 4), (8, 12, 4), (12, 10, 2), (14, 11, 2), (16, 13, 4), (20, 11, 4),
                 (24, 12, 3), (27, 11, 1), (28, 10, 4)]
GREECE_BRIDGE2 = GREECE_BRIDGE[:8] + [(24, 12, 3), (27, 11, 1), (28, 8, 4)]


def gallop(root, last=None):
    """A bar of the gallop (eighth, two sixteenths) on a power chord;
    [param last]: another root for the last beat."""
    beats = [f"5:{root} . p{root} p{root}"] * 3 + [f"5:{last if last is not None else root} . p{root} p{root}"]
    return " ".join(beats)


def zone_greece():
    s = Band(180, 4, GREECE_BARS, seed=2301, levels={
        "drone": -27.5, "kithara": -22.0, "aulos": -21.0, "clean": -23.5, "tympanon": -25.5, "pad": -27.0,
        "tgal": -23.0, "ttoms": -24.5, "timp": -25.0, "swell": -29.0,
        "kick": -20.5, "snare": -21.0, "cym": -27.0, "toms": -24.0, "gtr": -17.0, "bass": -20.5, "cdrone": -30.0,
        "lead": -20.0, "lead2": -22.0, "haulos": -23.0, "choir": -24.0,
    })
    rng = s.rng
    band.zone_reverbs(s, "hall", rt60=3.6, pre_delay=0.05, dark=0.5, early=12, early_span=0.09)
    s.bus("drone", "explore", sends={"space": 0.3}, eq=g_shelf_lo(70.0, -6.0))
    s.bus("cdrone", "combat", sends={"space": 0.2}, eq=g_mul(g_highpass(60.0, 2), g_lowpass(1500.0, 2)))
    s.bus("pad", "explore", sends={"space": 0.7}, eq=g_mul(g_highpass(180.0, 2), g_shelf_hi(5000.0, -2.0)), stereo_width=1.2)
    s.bus("kithara", "explore", sends={"space": 0.55}, eq=g_highpass(70.0, 2), stereo_width=1.1)
    s.bus("aulos", "explore", sends={"far": 0.8, "space": 0.35}, eq=g_highpass(200.0, 2))
    s.bus("clean", "explore", sends={"space": 0.6}, process=band.clean_chorus(0.5), stereo_width=1.15)
    s.bus("tympanon", "explore", sends={"space": 0.35}, eq=g_highpass(80.0, 2))
    s.bus("tgal", "tension", sends={"room": 0.1}, process=band.bass_rig(0.9))
    s.bus("ttoms", "tension", sends={"room": 0.3, "space": 0.3}, eq=g_highpass(60.0, 2))
    s.bus("timp", "tension", sends={"space": 0.45}, eq=g_shelf_lo(80.0, -4.0))
    s.bus("swell", "tension", sends={"space": 0.5}, stereo_width=1.2)
    band.metal_buses(s, room=0.16, space=0.14)
    s.bus("gtr", "combat", sends={"room": 0.12}, process=band.rhythm_amp(0.95, presence_db=4.0), stereo_width=0.9)
    s.bus("bass", "combat", sends={"room": 0.04}, process=band.bass_rig(1.0))
    s.bus("lead", "hi", sends={"space": 0.4, "room": 0.1}, process=band.lead_amp(0.85))
    s.bus("lead2", "hi", sends={"space": 0.4, "room": 0.1}, process=band.lead_amp(0.85))
    s.bus("haulos", "hi", sends={"space": 0.45}, eq=g_highpass(250.0, 2))
    s.bus("choir", "hi", sends={"space": 0.7}, eq=g_highpass(150.0, 2))

    tag_of = lambda bar: band.section_of(GREECE_FORM, bar)
    chord_of = lambda bar: GREECE_CHORDS[bar]
    s.chord_of = chord_of
    mode_of = lambda bar: "mixolydian" if tag_of(bar) == "B" else "dorian"

    # --- explore: drone, an airy choir pad, the kithara, the aulos's lullaby, clean guitars, the tympanon
    s.add("drone", 0, band.drone_bed(s, cutoff=300.0, shape="tri"))
    s.add("cdrone", 0, band.drone_bed(s, low=0.0, cutoff=280.0))
    for bar in range(0, GREECE_BARS, 2):
        notes = [x + 12 for x in gw.voicing(chord_of(bar), 50)[1:]]
        s.add("pad", s.at(bar), ins.choir(notes, s.sec(8) - 0.2, 0.5, rng, ins.VOWEL_U, attack=1.5, release=2.0, singers=3))
    for bar in range(GREECE_BARS):
        tones = gw.arp(chord_of(bar), 50)
        picks = [(0, 0), (2, 2)] if bar % 2 == 0 else [(0, 3), (2, 1)]
        if tag_of(bar) == "C":
            picks = [(0, 0), (1, 2), (2, 3), (3, 4)]
        for beat, i in picks:
            s.add("kithara", s.at(bar, beat, 0.008), ins.lyre(tones[i], 0.6 * rng.uniform(0.9, 1.05), rng, big=True), pan=-0.25)
    aulos = lambda midi, sec, vel: metal.aulos(midi, max(sec * 0.96, 0.12), vel, rng)
    melody(s, "aulos", 0, GREECE_TUNE, aulos, "dorian", vel=0.75, pan=0.15)
    melody(s, "aulos", 24, GREECE_TUNE, aulos, "mixolydian", vel=0.7, pan=0.15)
    melody(s, "aulos", 40, GREECE_BRIDGE2, aulos, "dorian", vel=0.7, pan=-0.15)
    melody(s, "aulos", 56, GREECE_TUNE, aulos, "dorian", vel=0.7, pan=0.15)
    clean = Guitarist(s, "clean", rng, pans=(-0.5, 0.5), bright=0.65)
    for bar in range(16, 32):
        tones = gw.arp(chord_of(bar), 55)
        clean.riff(bar, [(0, 8, tones[1] - D2, "ring"), (8, 8, tones[2] - D2, "ring")], 0.7)
    kit_e = Drummer(s, rng, {"doum": ("tympanon", lambda: ins.frame_drum(132.0, 0.8, rng, "doum", ring=0.8), 3, 0.2),
                             "tek": ("tympanon", lambda: ins.frame_drum(140.0, 0.7, rng, "tek"), 4, 0.3)})
    for bar in range(GREECE_BARS):
        kit_e.bar(bar, {"doum": "X...............", "tek": "........x.....x."}, vel=0.8)

    # --- tension: the gallop on a muted bass, toms, timpani on the changes, a swell
    tgal = Guitarist(s, "tgal", rng, pans=(0.0,), bass=True)
    kit_t = Drummer(s, rng, {"t2": ("ttoms", lambda: metal.tom(120.0, 0.85, rng), 3, 0.2),
                             "t3": ("ttoms", lambda: metal.tom(88.0, 0.9, rng), 3, -0.25)})
    for bar in range(GREECE_BARS):
        r = gw.root(chord_of(bar), D2, D2 + 11) - D2
        tgal.riff(bar, bass_of(parse_riff(gallop(r).replace("5:", "p"))), 0.8)
        kit_t.bar(bar, {"t3": "X.......X.......", "t2": "....x.......x.xx" if bar % 4 == 3 else "....x.......x..."})
        if bar % 2 == 0:
            s.add("timp", s.at(bar), ins.timpani(gw.root(chord_of(bar), 38, 49), 0.8, rng), pan=-0.2)
    s.add("swell", s.at(64), metal.riser(s.sec(32), rng))

    # --- combat: the gallop
    dr = Drummer(s, rng, band.metal_kit(rng))
    gtr = Guitarist(s, "gtr", rng)
    bass = Guitarist(s, "bass", rng, pans=(0.0,), bass=True)
    heads = starts(GREECE_FORM)
    for bar in range(GREECE_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        r = gw.root(chord, D2, D2 + 11) - D2
        nxt = gw.root(chord_of((bar + 1) % GREECE_BARS), D2, D2 + 11) - D2
        if tag == "C":
            dr.bar(bar, {"kick": "X.......X.x.....", "snare": "........X.......", "ride": "x.x.x.x.x.x.x.x."})
            riff = parse_riff(f"5o:{r} - - - - - - - - - - - p{r} p{r} p{r} p{r}")
        else:
            gal = {"kick": "X.xxX.xxX.xxX.xx", "snare": "....X.......X...",
                   "crash" if tag != "B" else "china": "x.......x......."}
            dr.bar(bar, gal)
            riff = parse_riff(gallop(r, nxt if bar % 2 == 1 and nxt != r else None))
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
            dr.hit("crash2", s.at(bar), 0.8)
        if bar % 8 == 7 and tag != "C":
            dr.fill(bar, ["t1", "t1", "t2", "t2", "t3", "t3", "t3", "snare"], 8, 8, (0.6, 1.0))
        gtr.riff(bar, riff)
        bass.riff(bar, bass_of(riff), 0.95)
    s.duck("bass", dr.kicks, -2.5, 0.07)

    # --- hi: the twin lead in thirds, the aulos, a choir over the Mixolydian lift
    for bar0 in (16, 24, 48, 56):
        mode = mode_of(bar0)
        band.lead_line(s, "lead", bar0, GREECE_TUNE, mode, rng, shift=-12, vel=0.9, pan=-0.35)
        band.lead_line(s, "lead2", bar0, GREECE_TWIN, mode, rng, shift=-12, vel=0.8, pan=0.35)
    for bar0, tune in ((32, GREECE_BRIDGE), (40, GREECE_BRIDGE2)):
        melody(s, "haulos", bar0, tune, aulos, "dorian", vel=0.75, pan=0.1)
    for bar in range(16, 32):
        notes = [x + 12 for x in gw.voicing(chord_of(bar), 50)[1:]]
        s.add("choir", s.at(bar), ins.choir(notes, s.sec(4) - 0.1, 0.7, rng, ins.VOWEL_A, attack=0.3, release=0.8))
    return band.master_zone(s.render(), "greece", 2301)


# --- the Americas: "Weze i ogien" - tribal groove metal --------------------------------

AMERICAS_BARS = 40
AMERICAS_FORM = [(0, 8, "A"), (8, 8, "B"), (16, 8, "C"), (24, 8, "A2"), (32, 8, "turn")]
AMERICAS_CHORDS = band.progression([
    (0, 8, ["Dm", "Dm", "Dm", "Dm", "Bb", "Bb", "C", "C"]), (8, 8, ["Dm", "Bb", "C", "Am", "Dm", "F", "Gm", "Dm"]),
    (16, 8, ["Dm"]), (24, 8, ["Dm", "Bb", "C", "Dm", "Bb", "Bb", "C", "C"]),
    (32, 8, ["Bb", "Bb", "C", "C", "Dm", "Dm", "Eb", "Eb"])])


def americas_riff(chord, tag):
    r = {"Dm": 0, "Bb": 8, "C": 10, "Gm": 5, "Am": 7, "Eb": 1, "F": 3}[chord]
    if tag == "C":
        return f"5:{r} - - - - - - - . . . . 5:{r + 1} - - -"
    if tag == "B":
        return f"5:{r} - p{r} p{r} 5:{r} - p{r} p{r} 5:{r + 1} - p{r} p{r} 5:{r} - . ."
    if chord == "Dm":
        return "5:0 - - p p . 5:3 - p p 5:5 - 5:3 - p p"
    return f"5:{r} - - p{r} p{r} . 5:{r} - p{r} p{r} 5:{r + 2} - 5:{r} - p{r} p{r}"


def zone_americas():
    s = Band(100, 4, AMERICAS_BARS, seed=2401, levels={
        "drone": -27.5, "marimba": -22.5, "clay": -21.0, "slit": -25.0, "rattle": -30.0, "lowtom": -26.0,
        "tribal": -21.5, "huehuetl": -23.0, "gourd": -27.5, "tbass": -23.0, "swell": -29.0,
        "kick": -20.5, "snare": -21.5, "cym": -28.0, "toms": -23.5, "ctribal": -23.0, "gtr": -17.0, "bass": -20.0,
        "cdrone": -30.0, "lead": -20.5, "hclay": -22.5, "whistle": -22.0, "conch": -24.0,
    })
    rng = s.rng
    mode = "aeolian"
    band.zone_reverbs(s, "gallery", rt60=2.9, pre_delay=0.04, dark=0.42, early=14, early_span=0.07)
    s.bus("drone", "explore", sends={"space": 0.25}, eq=g_shelf_lo(70.0, -5.0))
    s.bus("cdrone", "combat", sends={"space": 0.2}, eq=g_mul(g_highpass(60.0, 2), g_lowpass(1400.0, 2)))
    s.bus("marimba", "explore", sends={"space": 0.4}, eq=g_highpass(70.0, 2), stereo_width=1.1)
    s.bus("clay", "explore", sends={"far": 0.9, "space": 0.3}, eq=g_highpass(300.0, 2))
    s.bus("slit", "explore", sends={"far": 0.5, "space": 0.3}, eq=g_lowpass(2500.0, 1))
    s.bus("rattle", "explore", sends={"space": 0.3}, eq=g_highpass(2000.0, 2))
    s.bus("lowtom", "explore", sends={"space": 0.35}, eq=g_mul(g_highpass(50.0, 2), g_lowpass(1200.0, 2)))
    s.bus("tribal", "tension", sends={"room": 0.3, "space": 0.25}, eq=g_highpass(55.0, 2), feeds={"tension": 0.0})
    s.bus("huehuetl", "tension", sends={"space": 0.35}, eq=g_mul(g_highpass(45.0, 2), g_shelf_lo(70.0, -3.0)))
    s.bus("gourd", "tension", sends={"space": 0.3}, eq=g_highpass(2000.0, 2), stereo_width=1.2)
    s.bus("tbass", "tension", sends={"room": 0.05}, process=band.bass_rig(0.9))
    s.bus("swell", "tension", sends={"space": 0.5}, stereo_width=1.2)
    band.metal_buses(s, room=0.2, space=0.12)
    s.bus("ctribal", "combat", sends={"room": 0.3, "space": 0.15}, eq=g_highpass(60.0, 2))
    s.bus("gtr", "combat", sends={"room": 0.12}, process=band.rhythm_amp(1.05, tight=85.0), stereo_width=0.9)
    s.bus("bass", "combat", sends={"room": 0.04}, process=band.bass_rig(1.2))
    s.bus("lead", "hi", sends={"space": 0.4}, process=band.lead_amp(0.85))
    s.bus("hclay", "hi", sends={"space": 0.45}, eq=g_highpass(300.0, 2))
    s.bus("whistle", "hi", sends={"space": 0.5, "far": 0.3})
    s.bus("conch", "hi", sends={"far": 0.9, "space": 0.3}, eq=g_highpass(90.0, 2))

    tag_of = lambda bar: band.section_of(AMERICAS_FORM, bar)
    chord_of = lambda bar: AMERICAS_CHORDS[bar]
    s.chord_of = chord_of

    # --- explore: drone, marimba in 3+3+2, the clay flute's lullaby, slit drums, rattles, a low drum
    bed = band.drone_bed(s, cutoff=220.0)
    s.add("drone", 0, bed)
    s.add("cdrone", 0, bed)
    for bar in range(AMERICAS_BARS):
        tones = gw.arp(chord_of(bar), 50)
        seq = [(0, 0), (3, 1), (6, 2), (8, 3), (11, 2), (14, 1)] if bar % 2 == 0 else [(0, 0), (3, 2), (6, 3), (8, 4), (10, 3), (12, 2), (14, 1)]
        for st, i in seq:
            v = (0.62 if st in (0, 8) else 0.45) * rng.uniform(0.92, 1.05)
            s.add("marimba", s.step(bar, st, 0.004), ins.marimba(tones[i], v, rng), pan=-0.2 + 0.05 * (st % 3))
    clay = v_flute(rng, "clay")
    # the 3/4 lullaby floats over the groove: one of its bars to a 4/4 bar (3 against 4)
    melody(s, "clay", 8, md.LULLABY_A, clay, mode, shift=12, unit=4.0 / 3.0, vel=0.7, pan=0.2)
    melody(s, "clay", 24, md.LULLABY_A[:9], clay, mode, shift=12, unit=4.0 / 3.0, vel=0.65, pan=-0.15)
    kit_e = Drummer(s, rng, {
        "lo": ("slit", lambda: ins.slit_drum(176.0, 0.8, rng), 3, -0.3), "hi": ("slit", lambda: ins.slit_drum(236.0, 0.75, rng), 3, -0.25),
        "shake": ("rattle", lambda: ins.rattle(0.7, rng, 0.08), 4, 0.4),
        "drum": ("lowtom", lambda: ins.big_drum(60.0, 0.7, rng, 1.2), 3, 0.0)})
    for bar in range(AMERICAS_BARS):
        kit_e.bar(bar, {"lo": "X.......x.......", "hi": "......x.......x.", "shake": "..x...x...x...x.",
                        "drum": "X.....x........."}, vel=0.8)

    # --- tension: tribal toms in 16ths, the huehuetl, gourds, the bass groove
    tribal = {"t1": ("tribal", lambda: metal.tom(165.0, 0.85, rng), 3, 0.35), "t2": ("tribal", lambda: metal.tom(122.0, 0.85, rng), 3, 0.0),
              "t3": ("tribal", lambda: metal.tom(86.0, 0.9, rng), 3, -0.35),
              "hue": ("huehuetl", lambda: ins.big_drum(56.0, 0.95, rng, 1.5), 3, -0.1),
              "gourd": ("gourd", lambda: ins.rattle(0.8, rng, 0.09), 4, 0.45)}
    kit_t = Drummer(s, rng, tribal)
    tbass = Guitarist(s, "tbass", rng, pans=(0.0,), bass=True)
    for bar in range(AMERICAS_BARS):
        kit_t.bar(bar, {"t3": "X..x..X...x..x..", "t2": "..x....x..x....x", "t1": "..............xx" if bar % 2 else "",
                        "hue": "X.......X.......", "gourd": "xoxoxoxoxoxoxoxo"})
        r = gw.root(chord_of(bar), D2, D2 + 11) - D2
        tbass.riff(bar, bass_of(parse_riff(f"p{r} . . p{r} p{r} . p{r} . p{r} . . p{r} p{r} . p{r} .")), 0.85)
    s.add("swell", s.at(36), metal.riser(s.sec(16), rng))

    # --- combat: the groove riffs, the kit with the tribal toms on top
    dr = Drummer(s, rng, band.metal_kit(rng, toms=(160.0, 118.0, 84.0)))
    ct = Drummer(s, rng, {"t2": ("ctribal", lambda: metal.tom(124.0, 0.85, rng), 3, 0.3),
                          "t3": ("ctribal", lambda: metal.tom(86.0, 0.9, rng), 3, -0.3)})
    gtr = Guitarist(s, "gtr", rng)
    bass = Guitarist(s, "bass", rng, pans=(0.0,), bass=True)
    heads = starts(AMERICAS_FORM)
    for bar in range(AMERICAS_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        if tag == "C":
            dr.bar(bar, {"kick": "X..x..x...x..x..", "snare": "........X.......", "china": "x.......x......."})
            ct.bar(bar, {"t3": "X..x..X...x..x..", "t2": "..x.x..x..x.x..x"})
        else:
            dr.bar(bar, {"kick": "X..x..x.X.x...x.", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."})
            ct.bar(bar, {"t3": "X.....x.........", "t2": "..........x...x."}, vel=0.8)
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
        if bar % 4 == 3:
            dr.fill(bar, ["t1", "t2", "t2", "t3"], 12, 4, (0.7, 1.0))
        riff = parse_riff(americas_riff(chord, tag))
        gtr.riff(bar, riff)
        bass.riff(bar, bass_of(riff), 0.95)
    s.duck("bass", dr.kicks, -3.0, 0.09)

    # --- hi: the clay flute and a guitar lead, death whistles closing the phrases, the conch
    tune = [(0, 7, 2), (2, 9, 1), (3, 7, 1), (4, 6, 2), (6, 5, 2), (8, 4, 3), (11, 2, 1), (12, 4, 4),
            (16, 7, 2), (18, 9, 2), (20, 10, 2), (22, 9, 2), (24, 10, 3), (27, 7, 1), (28, 7, 4)]
    for bar0 in (8, 24):
        band.lead_line(s, "lead", bar0, tune, mode, rng, shift=-12, vel=0.9)
        melody(s, "hclay", bar0, tune, clay, mode, shift=12, vel=0.7, pan=0.25)
    for bar in (7, 15, 23, 31, 39):
        s.add("whistle", s.at(bar, 2.0), metal.death_whistle(s.sec(1.6), 0.9, rng, pitch=rng.uniform(1700.0, 2100.0)),
              pan=rng.uniform(-0.6, 0.6))
    for bar in (0, 16, 24):
        s.add("conch", s.at(bar, 0.0), ins.conch(m("D3"), s.sec(3), 0.85, rng), pan=-0.4)
    return band.master_zone(s.render(), "americas", 2401)


ZONES = {"egypt": zone_egypt, "assyria": zone_assyria, "greece": zone_greece, "americas": zone_americas}
