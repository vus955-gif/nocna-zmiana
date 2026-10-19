"""The hub's and the eastern zones' music (see gen_biomes.py for the whole
score): the Great Court (darksynth with the museum's lullaby), the
Enlightenment (neoclassical metal), Asia (taiko metal with electronics),
the basement (industrial metal), the roof (blackgaze). Each zone: one
loop, four synced stems (band.py)."""
import numpy as np

import band
import dsp
import gen_music as gm
import gen_wings as gw
import instruments as ins
import metal
import modes as md
from band import G_BLAST, G_DBEAT, G_DOUBLE, G_HALF, G_THRASH, Band, Drummer, Guitarist, bass_of, melody, parse_riff
from dsp import g_bell, g_highpass, g_lowpass, g_mul, g_shelf_hi, g_shelf_lo
from gen_music import m, ms

D2 = band.D2
# the lullaby re-barred in 4/4 (gen_wings: 8 bars, scale steps)
LULL44 = gw.LULL44


def starts(form):
    return {start for start, _, _ in form}


def root_of(chord):
    """Semitones of the chord's root over D2 (0..11)."""
    return gw.root(chord, D2, D2 + 11) - D2


def third_of(chord):
    iv = gw.tones(chord)
    return iv[1] if len(iv) > 2 else 7


# --- the Great Court: "Dziedziniec" - darksynth, guitars in the fight -------------------

COURT_BARS = 42
COURT_FORM = [(0, 8, "A"), (8, 8, "B"), (16, 8, "C"), (24, 8, "D"), (32, 8, "E"), (40, 2, "turn")]
COURT_CHORDS = band.progression([
    (0, 8, ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"]), (8, 8, ["Dm", "Dm", "Bb", "A", "Dm", "F", "A", "Dm"]),
    (16, 8, ["F", "F", "C", "C", "Dm", "Dm", "Bb", "A"]), (24, 8, ["Bb", "Bb", "Gm", "Gm", "Dm", "Dm", "A", "A"]),
    (32, 8, ["Dm", "Dm", "Bb", "A", "Dm", "F", "A", "Dm"]), (40, 2, ["Gm", "A"])])


def zone_court():
    s = Band(105, 4, COURT_BARS, seed=2501, levels={
        "pad": -24.0, "arp": -24.5, "sub": -26.0, "beat": -24.5, "clap": -27.0, "hats": -28.5, "box": -21.5,
        "octbass": -22.0, "tkick": -23.5, "topen": -30.0, "swell": -29.0, "tpad": -27.0,
        "kick": -20.0, "snare": -21.0, "cym": -28.0, "toms": -25.0, "gtr": -17.5, "reese": -20.0, "stabs": -23.5,
        "cpad": -27.0, "lead": -19.0, "evil": -25.0, "harp": -25.0,
    })
    rng = s.rng
    mode = "harmonic"
    band.zone_reverbs(s, "vast", rt60=3.8, pre_delay=0.07, dark=0.3, early=10, early_span=0.1, early_gain=0.4)
    s.bus("pad", "explore", sends={"space": 0.5}, eq=g_mul(g_highpass(90.0, 2), g_lowpass(5000.0, 1)), stereo_width=1.2,
          feeds={"explore": 0.0})
    s.bus("cpad", "combat", sends={"space": 0.3}, eq=g_mul(g_highpass(150.0, 2), g_lowpass(4000.0, 1)), stereo_width=1.2)
    s.bus("arp", "explore", sends={"space": 0.45}, eq=g_highpass(180.0, 2), stereo_width=1.1)
    s.bus("sub", "explore", eq=g_highpass(28.0, 2))
    s.bus("beat", "explore", sends={"room": 0.2}, eq=g_mul(g_highpass(40.0, 2), g_lowpass(9000.0, 1)))
    s.bus("clap", "explore", sends={"space": 0.4}, eq=g_highpass(200.0, 2))
    s.bus("hats", "explore", sends={"room": 0.2}, eq=g_highpass(6000.0, 2))
    s.bus("box", "explore", sends={"space": 0.55}, eq=g_mul(g_highpass(220.0, 2), g_shelf_hi(9000.0, -3.0)))
    s.bus("octbass", "tension", sends={"room": 0.1}, eq=g_mul(g_highpass(35.0, 2), g_lowpass(2500.0, 2)))
    s.bus("tkick", "tension", sends={"room": 0.15}, eq=g_highpass(38.0, 2))
    s.bus("topen", "tension", sends={"room": 0.2}, eq=g_highpass(6000.0, 2))
    s.bus("tpad", "tension", sends={"space": 0.5}, eq=g_mul(g_highpass(200.0, 2), g_lowpass(6000.0, 1)), stereo_width=1.2)
    s.bus("swell", "tension", sends={"space": 0.4}, stereo_width=1.2)
    band.metal_buses(s, room=0.15, space=0.15)
    s.bus("gtr", "combat", sends={"room": 0.12}, process=band.rhythm_amp(1.0), stereo_width=0.9)
    s.bus("reese", "combat", sends={"room": 0.05}, eq=g_mul(g_highpass(35.0, 2), g_lowpass(3000.0, 2)))
    s.bus("stabs", "combat", sends={"space": 0.35}, eq=g_highpass(200.0, 2), stereo_width=1.2)
    s.bus("lead", "hi", sends={"space": 0.4}, eq=g_mul(g_highpass(250.0, 2), g_bell(2500.0, 2.0, 0.8)), stereo_width=1.1)
    s.bus("evil", "hi", sends={"space": 0.4}, eq=g_highpass(300.0, 2))
    s.bus("harp", "hi", sends={"space": 0.5, "room": 0.1}, eq=g_highpass(300.0, 2), stereo_width=1.3)

    tag_of = lambda bar: band.section_of(COURT_FORM, bar)
    chord_of = lambda bar: COURT_CHORDS[bar]
    s.chord_of = chord_of

    # --- explore: analog pad, a soft synth arpeggio, sub, a half-time beat, the lullaby on the music box
    for bar in range(0, COURT_BARS, 2):
        chord = chord_of(bar)
        same = chord_of(bar + 1) == chord if bar + 1 < COURT_BARS else True
        for k, ch in enumerate([chord] if same else [chord, chord_of(bar + 1)]):
            r = gw.root(ch, 50, 61)
            notes = [r, r + 7, r + 12 + third_of(ch)]
            sig = metal.analog_pad(notes, s.sec(8 if same else 4) - 0.2, 0.6, rng, attack=0.8, release=1.5, cutoff=2400.0)
            s.add("pad", s.at(bar + k), sig)
            s.add("cpad", s.at(bar + k), sig)
            s.add("tpad", s.at(bar + k), metal.supersaw(notes, s.sec(8 if same else 4) - 0.2, 0.5, rng, attack=1.5,
                                                         release=1.5, bright=0.4) if tag_of(bar) == "D" else np.zeros((1, 2)))
    for bar in range(COURT_BARS):
        tones = gw.arp(chord_of(bar), 50)
        for k, i in enumerate([0, 1, 2, 3, 2, 1, 4, 2]):
            v = (0.6 if k % 2 == 0 else 0.45) * rng.uniform(0.92, 1.04)
            s.add("arp", s.at(bar, k * 0.5, 0.002), metal.synth_pluck(tones[i], v, rng, decay=0.28, bright=0.8),
                  pan=-0.3 if k % 2 else 0.3)
        s.add("sub", s.at(bar), metal.sub_bass(gw.root(chord_of(bar), 33, 44), s.sec(4) - 0.05, 0.85, rng))
    beat = Drummer(s, rng, {"kick": ("beat", lambda: metal.kick(0.8, rng, click=0.3, tight=1.4), 3, 0.0),
                            "clap": ("clap", lambda: metal.gated_snare(0.8, rng, gate=0.2), 3, 0.0),
                            "hat": ("hats", lambda: metal.hihat("closed", 0.7, rng), 4, 0.3)})
    for bar in range(COURT_BARS):
        beat.bar(bar, {"kick": "X.........x.....", "clap": "........x.......", "hat": "..x...x...x...x."}, vel=0.85)
    for bar0 in (8, 32):
        melody(s, "box", bar0, LULL44, lambda midi, sec, vel: ins.music_box(midi, vel, rng), mode, vel=0.8, pan=0.1)

    # --- tension: the octave bass in eighths, a four-on-the-floor kick, open hats, a swell
    tk = Drummer(s, rng, {"kick": ("tkick", lambda: metal.kick(0.85, rng, click=0.5), 3, 0.0),
                          "open": ("topen", lambda: metal.hihat("open", 0.7, rng), 3, -0.3)})
    for bar in range(COURT_BARS):
        tk.bar(bar, {"kick": "X...x...X...x...", "open": "..x...x...x...x."})
        r = gw.root(chord_of(bar), 33, 44)
        for k in range(8):
            s.add("octbass", s.at(bar, k * 0.5, 0.002), ins.synth_bass(r + (12 if k % 2 else 0), 0.2, 0.9, rng, drive=2.0))
    s.duck("octbass", tk.kicks, -5.0, 0.12)
    s.add("swell", s.at(40), metal.riser(s.sec(8), rng))

    # --- combat: gated snare, the kit, sixteenth chugs, the reese bass pumping under the kick, stabs
    dr = Drummer(s, rng, dict(band.metal_kit(rng), snare=("snare", lambda: metal.gated_snare(0.95, rng), 4, 0.0)))
    gtr = Guitarist(s, "gtr", rng)
    heads = starts(COURT_FORM)
    for bar in range(COURT_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        r = root_of(chord)
        if tag == "D":
            dr.bar(bar, {"kick": "X.......X.x.....", "snare": "........X.......", "ride": "x.x.x.x.x.x.x.x."})
            riff = f"5o:{r} - - - - - - - - - - - p{r} p{r} p{r} p{r}"
        else:
            groove = {"kick": "X...X...X...X...", "snare": "....X.......X...", "hat": "xxxxxxxxxxxxxxxx"}
            if bar % 4 == 3:
                groove = dict(groove, kick="X...X...X.xxxxxx")
            dr.bar(bar, groove)
            riff = f"5:{r} - p{r} p{r} p{r} p{r} 5:{r} - p{r} p{r} 5:{r} - p{r} p{r} p{r} p{r}"
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
        gtr.riff(bar, parse_riff(riff))
        rb = gw.root(chord, 33, 44)
        for k in range(8):
            s.add("reese", s.at(bar, k * 0.5, 0.002), metal.reese(rb, s.sec(0.45), 0.9, rng, cutoff=650.0))
        if bar % 2 == 0 and tag != "D":
            notes = [gw.root(chord, 57, 68) + i for i in (0, 7, 12 + third_of(chord))]
            s.add("stabs", s.at(bar), metal.supersaw(notes, s.sec(0.75), 0.8, rng, release=0.25, bright=0.8))
    dr.fill(COURT_BARS - 1, ["t1", "t1", "t2", "t2", "t3", "t3", "snare", "snare"], 8, 8, (0.6, 1.0))
    s.duck("reese", dr.kicks, -6.0, 0.14)

    # --- hi: the supersaw lead with the lullaby, the feral music box over it, bright arpeggios
    lead = lambda midi, sec, vel: metal.supersaw(midi, max(sec * 0.95, 0.1), vel, rng, voices=5, detune=12.0, vibrato=1.0)
    for bar0 in (8, 32):
        melody(s, "lead", bar0, LULL44, lead, mode, vel=0.85)
        melody(s, "evil", bar0, LULL44, lambda midi, sec, vel: ins.evil_box(midi + 12, vel, rng), mode, vel=0.8, pan=0.25)
    for bar in range(16, 32):
        tones = gw.arp(chord_of(bar), 62)
        for k in range(16):
            i = [0, 1, 2, 3, 4, 3, 2, 1][k % 8]
            s.add("harp", s.step(bar, k, 0.002), metal.synth_pluck(tones[i], 0.5 + 0.2 * (k % 4 == 0), rng, decay=0.12, bright=0.9),
                  pan=-0.4 if k % 2 else 0.4)
    return band.master_zone(s.render(), "court", 2501)


# --- the Enlightenment: "Menuet dla automatow" - neoclassical metal --------------------

ENL_BARS = 56
ENL_FORM = [(0, 8, "A"), (8, 8, "B"), (16, 8, "B2"), (24, 8, "C"), (32, 8, "A"), (40, 8, "B"), (48, 8, "turn")]
ENL_CIRCLE = ["Dm", "Gm", "C", "F", "Bb", "Em7b5", "A7", "Dm"]
ENL_CHORDS = band.progression([
    (0, 8, ["Dm", "Dm", "Gm", "A7", "Dm", "Dm", "A7", "Dm"]), (8, 8, ENL_CIRCLE), (16, 8, ENL_CIRCLE),
    (24, 8, ["Gm", "Gm", "Dm", "Dm", "Em7b5", "A7", "Dm", "A7"]), (32, 8, ["Dm", "Dm", "Gm", "A7", "Dm", "Dm", "A7", "Dm"]),
    (40, 8, ENL_CIRCLE), (48, 8, ["Bb", "Bb", "Gm", "Gm", "Em7b5", "Em7b5", "A7", "A7"])])


def zone_enlightenment():
    s = Band(140, 4, ENL_BARS, seed=2601, levels={
        "harpsi": -21.0, "strings": -26.0, "clock": -31.0, "box": -22.5, "drone": -29.0,
        "organ": -25.0, "timp": -25.0, "tgtr": -24.5, "ticks": -29.0, "tbass": -24.0, "swell": -29.0,
        "kick": -20.5, "snare": -21.5, "cym": -27.5, "toms": -24.5, "gtr": -17.5, "bass": -20.5, "charps": -22.5,
        "corgan": -24.5, "lead": -19.5, "evil": -24.0, "horgan": -22.5,
    })
    rng = s.rng
    mode = "harmonic"
    band.zone_reverbs(s, "library", rt60=1.6, pre_delay=0.015, dark=0.6, early=16, early_span=0.04, early_gain=0.6)
    s.bus("harpsi", "explore", sends={"room": 0.3, "space": 0.3}, eq=g_highpass(60.0, 2), stereo_width=1.1)
    s.bus("strings", "explore", sends={"space": 0.6}, eq=g_mul(g_lowpass(4000.0, 1), g_highpass(40.0, 2)))
    s.bus("clock", "explore", sends={"room": 0.4}, eq=g_mul(g_lowpass(5000.0, 1), g_highpass(500.0, 2)))
    s.bus("box", "explore", sends={"space": 0.5}, eq=g_mul(g_highpass(160.0, 2), g_shelf_hi(9000.0, -2.0)))
    s.bus("drone", "explore", sends={"space": 0.3}, eq=g_shelf_lo(70.0, -6.0))
    s.bus("organ", "tension", sends={"space": 0.5}, eq=g_shelf_lo(60.0, -2.0))
    s.bus("timp", "tension", sends={"space": 0.45}, eq=g_shelf_lo(80.0, -4.0))
    s.bus("tgtr", "tension", sends={"room": 0.2}, process=band.rhythm_amp(0.7), stereo_width=0.7, eq=g_lowpass(3500.0, 2))
    s.bus("ticks", "tension", sends={"room": 0.2}, eq=g_highpass(700.0, 2))
    s.bus("tbass", "tension", sends={"room": 0.05}, process=band.bass_rig(0.8))
    s.bus("swell", "tension", sends={"space": 0.5}, stereo_width=1.2)
    band.metal_buses(s, room=0.16, space=0.12)
    s.bus("gtr", "combat", sends={"room": 0.12}, process=band.rhythm_amp(1.0, presence_db=4.0), stereo_width=0.9)
    s.bus("bass", "combat", sends={"room": 0.04}, process=band.bass_rig(1.0))
    s.bus("charps", "combat", sends={"room": 0.25, "space": 0.15}, eq=g_highpass(150.0, 2), stereo_width=1.2)
    s.bus("corgan", "combat", sends={"space": 0.4}, eq=g_highpass(80.0, 2))
    s.bus("lead", "hi", sends={"space": 0.3, "room": 0.15}, process=band.lead_amp(0.85))
    s.bus("evil", "hi", sends={"space": 0.4}, eq=g_highpass(300.0, 2))
    s.bus("horgan", "hi", sends={"space": 0.5}, eq=g_highpass(150.0, 2))

    tag_of = lambda bar: band.section_of(ENL_FORM, bar)
    chord_of = lambda bar: ENL_CHORDS[bar]
    s.chord_of = chord_of

    # --- explore: a two-voice harpsichord invention (eighths over quarter-note bass), strings, clocks, the lullaby
    s.add("drone", 0, band.drone_bed(s, low=0.2, cutoff=240.0, shape="tri"))
    for bar in range(ENL_BARS):
        chord = chord_of(bar)
        tones = band.chord_arp(chord, 62)
        for k, i in enumerate([0, 2, 1, 2, 3, 2, 1, 2]):
            v = (0.55 if k % 2 == 0 else 0.42) * rng.uniform(0.92, 1.04)
            s.add("harpsi", s.at(bar, k * 0.5, 0.003), ins.harpsichord(tones[i], v, rng, hold=s.sec(0.45), four_foot=0.0), pan=0.25)
        r = gw.root(chord, 38, 49)
        fifth = 6 if chord == "Em7b5" else 7
        for k, note in enumerate([r, r + 12, r + fifth, r + 12]):
            s.add("harpsi", s.at(bar, k, 0.003), ins.harpsichord(note, 0.6 if k == 0 else 0.45, rng, hold=s.sec(0.9)), pan=-0.3)
        s.add("clock", s.at(bar, 0), ins.clock_tick(False, 0.5, rng), pan=0.6)
        s.add("clock", s.at(bar, 2), ins.clock_tick(True, 0.5, rng), pan=0.6)
    for start, beats, chord in gm.chord_spans(ENL_CHORDS, 4):
        if chord in gm.PAD:
            s.add("strings", s.at(0, start), ins.strings(ms(gm.PAD[chord]), s.sec(beats) + 0.2, 0.45, rng, attack=1.0,
                                                         release=1.4, bright=0.7))
    box = lambda midi, sec, vel: ins.music_box(midi, vel, rng)
    melody(s, "box", 0, LULL44, box, mode, vel=0.8, pan=0.05)
    melody(s, "box", 32, LULL44[:9], box, mode, vel=0.7, pan=0.05)

    # --- tension: the organ's pedal, timpani, muted eighths on the roots, the clockwork in sixteenths
    tg = Guitarist(s, "tgtr", rng, pans=(-0.6, 0.6))
    tbass = Guitarist(s, "tbass", rng, pans=(0.0,), bass=True)
    ticks = [ins.clock_tick(k % 2 == 1, 0.8, rng) for k in range(6)]
    for bar in range(ENL_BARS):
        chord = chord_of(bar)
        r = root_of(chord)
        s.add("organ", s.at(bar), ins.organ([gw.root(chord, 26, 37), gw.root(chord, 38, 49)], s.sec(4) - 0.05, 0.8, rng,
                                           release=0.2, chiff=0.5))
        s.add("timp", s.at(bar), ins.timpani(gw.root(chord, 38, 49), 0.8 if bar % 2 == 0 else 0.6, rng), pan=-0.2)
        line = parse_riff(" ".join([f"p{r} ." for _ in range(8)]))
        tg.riff(bar, line, 0.7)
        tbass.riff(bar, bass_of(line), 0.8)
        for k in range(16):
            s.add("ticks", s.step(bar, k, 0.002), ticks[k % 6], 1.0 if k % 4 == 0 else 0.6, pan=-0.4)
    s.add("swell", s.at(54), metal.riser(s.sec(8), rng))

    # --- combat: pedal-point riffs on the circle of fifths, harpsichord sixteenths, organ chords
    dr = Drummer(s, rng, band.metal_kit(rng))
    gtr = Guitarist(s, "gtr", rng)
    bass = Guitarist(s, "bass", rng, pans=(0.0,), bass=True)
    heads = starts(ENL_FORM)
    for bar in range(ENL_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        r = root_of(chord)
        th = third_of(chord)
        fifth = 6 if chord == "Em7b5" else 7
        groove = {"A": G_THRASH, "B": G_DOUBLE, "B2": G_DOUBLE, "C": G_HALF, "turn": G_DBEAT}[tag]
        dr.bar(bar, groove)
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
        if bar % 8 == 7:
            dr.fill(bar, ["t1", "t1", "t2", "t2", "t3", "t3", "snare", "snare"], 8, 8, (0.6, 1.0))
        if tag in ("B", "B2"):
            riff = f"5:{r} - p{r} {r + th} p{r} {r + fifth} p{r} {r + 12} 5:{r} - p{r} {r + fifth} p{r} {r + th} p{r} {r + fifth}"
        elif tag == "C":
            riff = f"5o:{r} - - - - - - - 5o:{r} - - - p{r} p{r} p{r} p{r}"
        else:
            riff = f"5:{r} - - p{r} p{r} p{r} 5:{r} - - p{r} p{r} p{r} 5:{r} - p{r} p{r}"
        if chord == "Em7b5":
            riff = riff.replace(f"5:{r} ", f"b5:{r} ").replace(f"5o:{r} ", f"b5:{r} ")
        events = parse_riff(riff)
        gtr.riff(bar, events)
        bass.riff(bar, bass_of(events), 0.95)
        tones = band.chord_arp(chord, 62)
        for k in range(16):
            i = [0, 1, 2, 3, 2, 1, 2, 1][k % 8] if k < 8 else [3, 2, 1, 2, 3, 4, 3, 2][k % 8]
            s.add("charps", s.step(bar, k, 0.002), ins.harpsichord(tones[i], 0.6 if k % 4 == 0 else 0.45, rng, hold=s.sec(0.24),
                                                                    four_foot=0.0), pan=0.3)
        if tag in ("C", "turn"):
            s.add("corgan", s.at(bar), ins.organ(gw.voicing(chord, 50), s.sec(4) - 0.05, 0.8, rng, release=0.2))
    s.duck("bass", dr.kicks, -3.0, 0.08)

    # --- hi: harmonic-minor sweeps on the lead guitar, the organ's tune, the feral music box
    for bar in list(range(8, 24)) + list(range(40, 48)):
        up = band.chord_arp(chord_of(bar), 50, 9)
        seq = up + up[-2:0:-1]
        for k in range(16):
            note = seq[k % len(seq)]
            s.add("lead", s.step(bar, k, 0.001), metal.lead_di(note, s.sec(0.25) * 0.95, 0.8, rng, vibrato=0.0), pan=0.0)
    organ_tune = [(0, 10, 4), (4, 12, 4), (8, 11, 4), (12, 9, 4), (16, 8, 4), (20, 6, 4), (24, 7, 4), (28, 6, 2), (30, 4, 2)]
    organ = lambda midi, sec, vel: ins.organ([midi, midi + 12], max(sec * 0.97, 0.1), vel * 1.2, rng, release=0.2)
    melody(s, "horgan", 24, organ_tune, organ, mode, vel=0.8)
    band.lead_line(s, "lead", 24, organ_tune, mode, rng, shift=0, vel=0.85)
    for bar0 in (0, 32):
        melody(s, "evil", bar0, LULL44, lambda midi, sec, vel: ins.evil_box(midi + 12, vel, rng), mode, vel=0.8, pan=0.3)
    return band.master_zone(s.render(), "enlightenment", 2601)


# --- Asia: "Ogrod w nocy" - taiko metal with electronics ----------------------------------

ASIA_BARS = 60
ASIA_FORM = [(0, 12, "A"), (12, 12, "B"), (24, 12, "C"), (36, 12, "A2"), (48, 12, "B2")]
ASIA_CHORDS = band.progression([
    (0, 12, ["D5", "D5", "D5", "D5", "Eb5", "Eb5", "G5", "G5", "D5", "D5", "Bb4", "Bb4"]),
    (12, 12, ["D5", "D5", "D5", "D5", "F5", "F5", "G5", "G5", "C5", "C5", "A4", "A4"]),
    (24, 12, ["D5"] * 8 + ["Eb5"] * 4),
    (36, 12, ["D5", "D5", "D5", "D5", "Eb5", "Eb5", "G5", "G5", "D5", "D5", "Bb4", "Bb4"]),
    (48, 12, ["D5", "D5", "D5", "D5", "C5", "C5", "G5", "G5", "A4", "A4", "A4", "A4"])])
# chord -> (root over D2, guitar shape, sho cloud)
ASIA_CH = {"D5": (0, "5", ["D4", "G4", "A4", "D5"]), "Eb5": (1, "5", ["Eb4", "Bb4", "Eb5"]),
           "G5": (5, "5", ["G3", "D4", "G4", "A4"]), "Bb4": (8, "4", ["Bb3", "Eb4", "Bb4"]),
           "F5": (3, "5", ["F3", "C4", "F4", "G4"]), "C5": (10, "5", ["C4", "F4", "G4", "C5"]),
           "A4": (7, "4", ["A3", "D4", "G4", "A4"])}
ASIA_RIFF = {
    ("insen", "D5"): "p p 1 p p 5 p p 7 - 8 - 7 5 1 p",
    ("insen", "Eb5"): "5:1 - p p 1 p 5:1 - p p 7 - 5 - 1 -",
    ("insen", "G5"): "5:5 - p p 5:5 - p p 7 - 8 - 7 - 5 -",
    ("insen", "Bb4"): "4:8 - p p 4:8 - p p 7 - 5 - 1 - p p",
    ("penta", "D5"): "p p 3 p p 5 p p 7 - 10 - 7 5 3 p",
    ("penta", "F5"): "5:3 - p p 5:3 - p p 5 - 7 - 5 - 3 -",
    ("penta", "G5"): "5:5 - p p 5:5 - p p 7 - 10 - 7 - 5 -",
    ("penta", "C5"): "5:10 - p p 5:10 - p p 7 - 5 - 3 - p p",
    ("penta", "A4"): "4:7 - p p 4:7 - p p 5 - 3 - p p p p",
}
ASIA_TUNE_PENTA = [(0, 7, 3), (3, 9, 1), (4, 11, 4), (8, 10, 2), (10, 9, 2), (12, 7, 4), (16, 9, 4), (20, 10, 4), (24, 11, 4),
                   (28, 10, 4), (32, 13, 4), (36, 11, 2), (38, 10, 2), (40, 11, 8)]
ASIA_TUNE_IN = [(0, 11, 3), (3, 12, 1), (4, 11, 4), (8, 10, 2), (10, 10, 2), (12, 7, 4), (16, 8, 4), (20, 10, 4), (24, 10, 4),
                (28, 11, 4), (32, 7, 4), (36, 11, 2), (38, 7, 2), (40, 12, 4), (44, 10, 2), (46, 8, 2)]


def zone_asia():
    s = Band(144, 4, ASIA_BARS, seed=2701, levels={
        "koto": -22.0, "shami": -25.0, "shaku": -21.0, "sho": -25.5, "sub": -26.5, "taiko": -25.0, "bowl": -28.0,
        "elec": -28.0, "ens": -21.5, "shost": -25.0, "tsub": -24.5, "swell": -29.0,
        "kick": -20.5, "snare": -21.5, "cym": -28.0, "toms": -24.5, "ctaiko": -22.5, "gtr": -17.2, "bass": -20.5,
        "cshami": -24.0, "lead": -20.0, "hshaku": -22.0, "hsho": -25.0, "hbowl": -27.0,
    })
    rng = s.rng
    band.zone_reverbs(s, "room", rt60=2.4, pre_delay=0.035, dark=0.5, early=12, early_span=0.06)
    s.bus("koto", "explore", sends={"space": 0.45}, eq=g_highpass(90.0, 2), stereo_width=1.1)
    s.bus("shami", "explore", sends={"space": 0.35}, eq=g_highpass(120.0, 2))
    s.bus("shaku", "explore", sends={"far": 0.8, "space": 0.3}, eq=g_mul(g_highpass(220.0, 2), g_shelf_hi(7000.0, -3.0)))
    s.bus("sho", "explore", sends={"space": 0.6}, eq=g_mul(g_highpass(200.0, 2), g_lowpass(5000.0, 1)))
    s.bus("sub", "explore", eq=g_highpass(28.0, 2))
    s.bus("taiko", "explore", sends={"space": 0.4, "far": 0.2}, eq=g_shelf_lo(60.0, -3.0))
    s.bus("bowl", "explore", sends={"space": 0.6}, eq=g_highpass(300.0, 2))
    s.bus("elec", "explore", sends={"space": 0.3}, eq=g_highpass(300.0, 2), stereo_width=1.2)
    s.bus("ens", "tension", sends={"room": 0.3, "space": 0.3}, eq=g_shelf_lo(55.0, -2.0))
    s.bus("shost", "tension", sends={"room": 0.2}, eq=g_highpass(150.0, 2))
    s.bus("tsub", "tension", eq=g_highpass(30.0, 2))
    s.bus("swell", "tension", sends={"space": 0.5}, stereo_width=1.2)
    band.metal_buses(s, room=0.16, space=0.12)
    s.bus("ctaiko", "combat", sends={"room": 0.3, "space": 0.2}, eq=g_shelf_lo(55.0, -3.0))
    s.bus("gtr", "combat", sends={"room": 0.12}, process=band.rhythm_amp(1.0), stereo_width=0.9)
    s.bus("bass", "combat", sends={"room": 0.04}, process=band.bass_rig(1.1))
    s.bus("cshami", "combat", sends={"room": 0.2}, eq=g_highpass(200.0, 2))
    s.bus("lead", "hi", sends={"space": 0.35}, process=band.lead_amp(0.85))
    s.bus("hshaku", "hi", sends={"space": 0.45}, eq=g_highpass(250.0, 2))
    s.bus("hsho", "hi", sends={"space": 0.6}, eq=g_highpass(300.0, 2))
    s.bus("hbowl", "hi", sends={"space": 0.6}, eq=g_highpass(300.0, 2))

    tag_of = lambda bar: band.section_of(ASIA_FORM, bar)
    chord_of = lambda bar: ASIA_CHORDS[bar]
    s.chord_of = chord_of
    mode_of = lambda bar: "penta" if tag_of(bar) in ("B", "B2") else "insen"

    def scale_tones(bar, root_midi):
        mode = mode_of(bar)
        pcs = sorted({(md.D4 + i) % 12 for i in md.MODES[mode]})
        return [n for n in range(root_midi, root_midi + 25) if n % 12 in pcs]

    # --- explore: koto falling figures, a sparse shamisen, the shakuhachi's lullaby, sho, sub pulse, a far taiko
    for bar in range(ASIA_BARS):
        r = ASIA_CH[chord_of(bar)][0] + D2 + 24
        sc = scale_tones(bar, r)
        figure = [(0, sc[5]), (2, sc[3]), (4, sc[2]), (8, sc[0])] if bar % 2 == 0 else [(0, sc[3]), (4, sc[5]), (6, sc[4]),
                                                                                       (10, sc[3]), (12, sc[0])]
        for st, note in figure:
            push = 1.0 if (note % 12 == 2 and mode_of(bar) == "insen" and st == 12) else 0.0
            s.add("koto", s.step(bar, st, 0.006), ins.koto(note, 0.6 * rng.uniform(0.9, 1.05), rng, push=push), pan=-0.3)
        if bar % 4 == 2:
            s.add("shami", s.step(bar, 8, 0.004), metal.shamisen(sc[2] - 12, 0.7, rng), pan=0.3)
            s.add("shami", s.step(bar, 11, 0.004), metal.shamisen(sc[1] - 12, 0.6, rng), pan=0.3)
        s.add("sub", s.at(bar), metal.sub_bass(ASIA_CH[chord_of(bar)][0] + 38, s.sec(2) - 0.05, 0.8, rng))
    for bar in range(0, ASIA_BARS, 2):
        s.add("sho", s.at(bar), ins.sho(ms(ASIA_CH[chord_of(bar)][2]), s.sec(8) - 0.3, 0.6, rng, attack=1.5, release=1.8))
    shaku = lambda midi, sec, vel: ins.flute(midi, max(sec * 0.97, 0.15), vel, rng, "shakuhachi", fall=-90.0 if sec > 1.5 else 0.0)
    melody(s, "shaku", 12, md.LULLABY_A, shaku, "penta", unit=2.0, vel=0.75, pan=0.2)
    melody(s, "shaku", 36, md.LULLABY_A, shaku, "insen_up", unit=2.0, vel=0.7, pan=0.2)
    far = Drummer(s, rng, {"don": ("taiko", lambda: ins.big_drum(56.0, 0.8, rng, 1.6), 3, -0.1)})
    for bar in range(ASIA_BARS):
        far.bar(bar, {"don": "X.......x......." if bar % 2 == 0 else "X..............."}, vel=0.8)
    for bar in range(12, 24):
        tones = scale_tones(bar, ASIA_CH[chord_of(bar)][0] + D2 + 24)
        for k in range(8):
            s.add("elec", s.at(bar, k * 0.5, 0.002), metal.synth_pluck(tones[[0, 2, 3, 2, 4, 3, 2, 1][k]], 0.45, rng, decay=0.2,
                                                                         bright=0.5), pan=-0.4 if k % 2 else 0.4)
    for bar in (0, 24, 48):
        s.add("bowl", s.at(bar, 0.5), ins.bowl(m("A5"), 0.7, rng), pan=0.45)

    # --- tension: the taiko ensemble (don - don - doko), the shamisen's ostinato, sub eighths
    ens = Drummer(s, rng, {"don": ("ens", lambda: ins.big_drum(58.0, 0.95, rng, 1.4), 4, -0.1),
                           "ko": ("ens", lambda: ins.big_drum(82.0, 0.75, rng, 0.7), 4, 0.15),
                           "rim": ("ens", lambda: ins.frame_drum(215.0, 0.8, rng, "slap"), 3, 0.35)})
    for bar in range(ASIA_BARS):
        ens.bar(bar, {"don": "X.......X.......", "ko": "....x.x.....x.xx" if bar % 2 else "....x.x.....x...",
                      "rim": "..x.......x....."})
        sc = scale_tones(bar, ASIA_CH[chord_of(bar)][0] + D2 + 12)
        for k in range(16):
            s.add("shost", s.step(bar, k, 0.002), metal.shamisen(sc[[0, 2, 1, 2, 3, 2, 1, 2][k % 8]], 0.45 + 0.2 * (k % 4 == 0), rng),
                  pan=0.35)
        for k in range(8):
            s.add("tsub", s.at(bar, k * 0.5), metal.sub_bass(ASIA_CH[chord_of(bar)][0] + 38, s.sec(0.4), 0.8, rng, release=0.04))
    s.add("swell", s.at(56), metal.riser(s.sec(16), rng))

    # --- combat: in-scale / pentatonic riffs, the taiko on top of the kit, the shamisen doubling the riff
    dr = Drummer(s, rng, band.metal_kit(rng))
    ct = Drummer(s, rng, {"don": ("ctaiko", lambda: ins.big_drum(56.0, 1.0, rng, 1.3), 4, -0.15),
                          "ko": ("ctaiko", lambda: ins.big_drum(80.0, 0.8, rng, 0.7), 4, 0.2)})
    gtr = Guitarist(s, "gtr", rng)
    bass = Guitarist(s, "bass", rng, pans=(0.0,), bass=True)
    heads = starts(ASIA_FORM)
    for bar in range(ASIA_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        groove = {"A": G_THRASH, "B": G_DOUBLE, "C": G_HALF, "A2": G_DOUBLE, "B2": G_BLAST}[tag]
        dr.bar(bar, groove)
        ct.bar(bar, {"don": "X.......X.......", "ko": "......x.....x.x." if tag != "C" else "x.x.x.x.x.xxx.xx"})
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
        if bar % 4 == 3:
            dr.fill(bar, ["t1", "t2", "t3", "t3"], 12, 4, (0.7, 1.0))
        if tag == "C":
            r = ASIA_CH[chord][0]
            other = 1 if r == 0 else 0
            text = f"5:{r} - - - - - - - 5:{other} - - - 5:{r} - - -"
        else:
            text = ASIA_RIFF[(mode_of(bar), chord)]
        events = parse_riff(text)
        gtr.riff(bar, events)
        bass.riff(bar, bass_of(events), 0.95)
        for step, _steps, note, art in events:
            if not isinstance(note, tuple) and art == "open":
                s.add("cshami", s.step(bar, step, 0.002), metal.shamisen(D2 + note + 24, 0.75, rng), pan=0.3)
    s.duck("bass", dr.kicks, -3.0, 0.08)

    # --- hi: the lead guitar and the shakuhachi in the section's scale, a high sho, the bowl
    band.lead_line(s, "lead", 12, ASIA_TUNE_PENTA, "penta", rng, shift=-12, vel=0.9)
    melody(s, "hshaku", 12, ASIA_TUNE_PENTA, shaku, "penta", vel=0.75, pan=0.25)
    band.lead_line(s, "lead", 36, ASIA_TUNE_IN, "insen", rng, shift=-12, vel=0.9)
    melody(s, "hshaku", 36, ASIA_TUNE_IN, shaku, "insen", vel=0.75, pan=0.25)
    # the hi stem breathes at the loop point (a lossy encoder rebuilds a file's first samples worst):
    # the last phrase ends two beats early, no sho over the last two bars, the bowl off the downbeat
    melody(s, "hshaku", 48, ASIA_TUNE_PENTA[:-1] + [(40, 11, 6)], shaku, "penta", vel=0.7, pan=-0.25)
    for bar in range(0, ASIA_BARS - 2, 2):
        s.add("hsho", s.at(bar), ins.sho([x + 12 for x in ms(ASIA_CH[chord_of(bar)][2])], s.sec(8) - 0.3, 0.6, rng,
                                         attack=0.8, release=1.2))
    for bar in range(0, ASIA_BARS, 4):
        s.add("hbowl", s.at(bar, 0.5), ins.bowl(m("D6"), 0.8, rng, 4.0), pan=0.3)
    return band.master_zone(s.render(), "asia", 2701)


# --- the basement: "Kotlownia" - industrial metal ---------------------------------------

BASEMENT_BARS = 48
BASEMENT_FORM = [(0, 8, "A"), (8, 8, "B"), (16, 8, "C"), (24, 8, "A"), (32, 8, "B"), (40, 8, "turn")]
BASEMENT_CHORDS = band.progression([
    (0, 8, ["D", "D", "D", "D", "D", "D", "Eb", "Eb"]), (8, 8, ["D", "D", "Ab", "Ab", "D", "D", "C", "Eb"]),
    (16, 8, ["D"]), (24, 8, ["D", "D", "D", "D", "D", "D", "Eb", "Eb"]), (32, 8, ["D", "D", "Ab", "Ab", "D", "D", "C", "Eb"]),
    (40, 8, ["Ab", "Ab", "G", "G", "Eb", "Eb", "D", "D"])])
BASEMENT_ROOT = {"D": 0, "Eb": 1, "Ab": 6, "G": 5, "C": 10}


def basement_root(chord, low, high):
    """The power chord's root placed in [low, high] (MIDI)."""
    pc = (D2 + BASEMENT_ROOT[chord]) % 12
    r = low + ((pc - low) % 12)
    return r if r <= high else r - 12


def basement_riff(chord, tag):
    r = BASEMENT_ROOT[chord]
    if tag == "C":
        return "5:0 - - . p . p . 5:0 - - . b5:0 - - -"
    if chord == "D":
        return "p p . p p . p . 5:1 - p . p p b5:0 -"
    return f"5:{r} - p{r} p{r} . p{r} 5:{r} - p{r} p{r} . p{r} 5:{r - 1 if r else 0} - 5:{r} -"


def zone_basement():
    s = Band(120, 4, BASEMENT_BARS, seed=2801, levels={
        "drone": -26.0, "pipes": -25.0, "steam": -30.0, "clank": -31.0, "hammer": -27.0, "box": -23.0, "sub": -26.5,
        "ikick": -22.5, "metal": -25.0, "treese": -23.5, "swell": -28.5,
        "kick": -20.0, "snare": -21.0, "cym": -28.0, "toms": -25.0, "gtr": -17.0, "reese": -20.5, "anvil": -26.0,
        "cdrone": -29.0, "lead": -20.0, "evil": -23.0, "hpipes": -26.0,
    })
    rng = s.rng
    band.zone_reverbs(s, "concrete", rt60=1.9, pre_delay=0.01, dark=0.15, early=18, early_span=0.05, early_gain=0.7)
    s.bus("drone", "explore", sends={"space": 0.3}, eq=g_shelf_lo(60.0, -3.0))
    s.bus("cdrone", "combat", sends={"space": 0.2}, eq=g_mul(g_highpass(60.0, 2), g_lowpass(1200.0, 2)))
    s.bus("pipes", "explore", sends={"space": 0.4}, eq=g_highpass(150.0, 2))
    s.bus("steam", "explore", sends={"space": 0.3}, stereo_width=1.3)
    s.bus("clank", "explore", sends={"space": 0.3}, eq=g_highpass(1000.0, 2))
    s.bus("hammer", "explore", sends={"far": 0.8, "space": 0.4}, eq=g_highpass(200.0, 2))
    s.bus("box", "explore", sends={"space": 0.5}, eq=g_mul(g_highpass(250.0, 2), g_lowpass(6000.0, 1)))
    s.bus("sub", "explore", eq=g_highpass(28.0, 2))
    s.bus("ikick", "tension", sends={"room": 0.2}, eq=g_highpass(35.0, 2))
    s.bus("metal", "tension", sends={"room": 0.3, "space": 0.3}, eq=g_highpass(250.0, 2))
    s.bus("treese", "tension", sends={"room": 0.05}, eq=g_mul(g_highpass(35.0, 2), g_lowpass(2000.0, 2)))
    s.bus("swell", "tension", sends={"space": 0.4}, stereo_width=1.2)
    band.metal_buses(s, room=0.25, space=0.15, kick_eq=g_mul(g_highpass(38.0, 2), g_bell(2500.0, 3.0, 0.7)))
    s.bus("gtr", "combat", sends={"room": 0.15}, process=band.rhythm_amp(1.2, tight=95.0, scoop_db=-6.0), stereo_width=0.95)
    s.bus("reese", "combat", sends={"room": 0.05}, eq=g_mul(g_highpass(35.0, 2), g_lowpass(3000.0, 2)))
    s.bus("anvil", "combat", sends={"room": 0.3, "space": 0.2}, eq=g_highpass(400.0, 2))
    s.bus("lead", "hi", sends={"space": 0.35}, eq=g_mul(g_highpass(300.0, 2), g_bell(2000.0, 3.0, 0.8)), stereo_width=1.1)
    s.bus("evil", "hi", sends={"space": 0.4}, eq=g_highpass(300.0, 2))
    s.bus("hpipes", "hi", sends={"room": 0.3, "space": 0.3}, eq=g_highpass(300.0, 2))

    tag_of = lambda bar: band.section_of(BASEMENT_FORM, bar)
    chord_of = lambda bar: BASEMENT_CHORDS[bar]

    # --- explore: the boiler's machine pulse, steam, far hammers, a rusty music box, sub pulses
    bed = band.drone_bed(s, low=0.15, cutoff=200.0)
    s.add("drone", 0, bed)
    s.add("cdrone", 0, bed)
    mach = Drummer(s, rng, {"pipe": ("pipes", lambda: metal.pipe_hit(rng.uniform(260.0, 340.0), 0.7, rng, 0.9, dull=0.85), 4, 0.2),
                            "clank": ("clank", lambda: metal.pipe_hit(rng.uniform(1200.0, 1600.0), 0.6, rng, 0.3, dull=0.9), 4, -0.3),
                            "hammer": ("hammer", lambda: ins.anvil(0.7, rng, 420.0), 3, 0.5)})
    for bar in range(BASEMENT_BARS):
        mach.bar(bar, {"pipe": "x..x..x.........", "clank": "..o...o.o.o...oo" if bar % 2 else "..o...o...o...o."}, vel=0.8)
        if bar % 2 == 0:
            mach.hit("hammer", s.at(bar), 0.7)
        if bar % 4 == 3:
            s.add("steam", s.at(bar, 3.0), metal.steam(s.sec(1.0), 0.7, rng), pan=rng.uniform(-0.6, 0.6))
        s.add("sub", s.at(bar), metal.sub_bass(basement_root(chord_of(bar), 33, 44), s.sec(1.5), 0.8, rng))
    rusty = lambda midi, sec, vel: dsp.lowpass(ins.crush(ins.music_box(midi + 0.3 * rng.standard_normal(), vel, rng), 2, 7), 6000.0)
    melody(s, "box", 8, LULL44, rusty, "harmonic", vel=0.75, pan=-0.15)
    melody(s, "box", 32, LULL44[:9], rusty, "harmonic", vel=0.7, pan=0.15)

    # --- tension: the industrial kick on the floor, metal in sixteenths, the reese bass, a swell
    tk = Drummer(s, rng, {"ikick": ("ikick", lambda: metal.industrial_kick(0.85, rng), 3, 0.0),
                          "m1": ("metal", lambda: metal.pipe_hit(rng.uniform(700.0, 900.0), 0.7, rng, 0.4, dull=0.6), 4, 0.35),
                          "m2": ("metal", lambda: metal.pipe_hit(rng.uniform(480.0, 560.0), 0.7, rng, 0.5, dull=0.5), 3, -0.35)})
    for bar in range(BASEMENT_BARS):
        tk.bar(bar, {"ikick": "X...X...X...X...", "m1": "..x...x...x...xx", "m2": ".o..o.o..o..o.o."})
        rb = basement_root(chord_of(bar), 33, 44)
        for k in range(8):
            s.add("treese", s.at(bar, k * 0.5, 0.002), metal.reese(rb, s.sec(0.4), 0.85, rng, cutoff=450.0, drive=2.0))
    s.duck("treese", tk.kicks, -5.0, 0.12)
    s.add("swell", s.at(46), metal.riser(s.sec(8), rng, top=9000.0))

    # --- combat: the drum machine, machine riffs (Phrygian chugs, the tritone), the reese, anvils
    kit = dict(band.metal_kit(rng), kick=("kick", lambda: metal.industrial_kick(0.95, rng), 4, 0.0),
               clap=("snare", lambda: metal.clap(0.9, rng), 3, 0.1))
    dr = Drummer(s, rng, kit)
    anv = Drummer(s, rng, {"anvil": ("anvil", lambda: ins.anvil(0.8, rng, 1180.0), 3, 0.45)})
    gtr = Guitarist(s, "gtr", rng)
    heads = starts(BASEMENT_FORM)
    for bar in range(BASEMENT_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        if tag == "C":
            dr.bar(bar, {"kick": "X.......X.x.....", "snare": "........X.......", "clap": "........x.......",
                         "china": "x...x...x...x..."})
        else:
            dr.bar(bar, {"kick": "X...X...X...X.x.", "snare": "....X.......X...", "clap": "....x.......x...",
                         "hat": "xxxxxxxxxxxxxxxx"})
            anv.bar(bar, {"anvil": "..x.......x....." if bar % 2 else "..x..........x.."})
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
        gtr.riff(bar, parse_riff(basement_riff(chord, tag)))
        rb = basement_root(chord, 33, 44)
        for k in range(16):
            if k % 4 != 3:
                s.add("reese", s.step(bar, k, 0.001), metal.reese(rb, s.sec(0.2), 0.9, rng, cutoff=800.0, drive=2.4))
    dr.fill(BASEMENT_BARS - 1, ["snare", "clap"], 8, 8, (0.5, 1.0))
    s.duck("reese", dr.kicks, -6.0, 0.1)

    # --- hi: a siren lead gliding between its notes, the crushed lullaby, pipes ringing
    siren = [(0, 7, 4), (4, 8, 4), (8, 7, 4), (12, 4, 4), (16, 7, 4), (20, 11, 4), (24, 10, 4), (28, 8, 4)]
    prev = None
    for beat, step, beats in siren:
        midi = md.note(step, "locrian")
        for bar0 in (8, 32):
            s.add("lead", s.at(bar0, beat), metal.supersaw(midi, s.sec(beats) * 0.97, 0.85, rng, voices=5, detune=25.0,
                                                           glide_from=prev, vibrato=1.5, bright=0.7))
        prev = midi
    melody(s, "evil", 0, LULL44, lambda midi, sec, vel: ins.evil_box(midi + 12, vel, rng), "locrian", vel=0.75, pan=0.3)
    melody(s, "evil", 24, LULL44, lambda midi, sec, vel: ins.evil_box(midi + 12, vel, rng), "locrian", vel=0.75, pan=-0.3)
    hp = Drummer(s, rng, {"p": ("hpipes", lambda: metal.pipe_hit(rng.uniform(900.0, 1300.0), 0.8, rng, 1.0, dull=0.3), 4, 0.4)})
    for bar in range(BASEMENT_BARS):
        hp.bar(bar, {"p": "......x.......x." if tag_of(bar) != "C" else "x...x...x...x..."})
    return band.master_zone(s.render(), "basement", 2801)


# --- the roof: "Dach pod ksiezycem" - blackgaze -----------------------------------------

ROOF_BARS = 54
ROOF_FORM = [(0, 8, "A"), (8, 8, "B"), (16, 8, "C"), (24, 8, "A"), (32, 8, "D"), (40, 8, "B"), (48, 6, "turn")]
ROOF_CHORDS = band.progression([
    (0, 8, ["Dm", "Dm", "Bb", "Bb", "F", "F", "C", "C"]), (8, 8, ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "Am", "Am"]),
    (16, 8, ["Bb", "Bb", "F", "F", "C", "C", "Dm", "Dm"]), (24, 8, ["Dm", "Dm", "Bb", "Bb", "F", "F", "C", "C"]),
    (32, 8, ["Gm", "Gm", "Bb", "Bb", "F", "F", "C", "C"]), (40, 8, ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "Am", "Am"]),
    (48, 6, ["Bb", "Bb", "C", "C", "Dm", "Dm"])])
# chord -> its open shape (metal.SHAPES): minor add9, major add9, Bb major seventh, A minor plain
ROOF_SHAPE = {"Dm": "add9", "Gm": "add9", "Am": "m", "Bb": "maj7", "F": "Madd9", "C": "Madd9"}
ROOF_TUNE = {
    "A": [(0, 11, 6), (6, 9, 2), (8, 10, 8), (16, 9, 4), (20, 11, 4), (24, 10, 4), (28, 8, 4)],
    "B": [(0, 7, 6), (6, 9, 2), (8, 12, 8), (16, 10, 4), (20, 12, 4), (24, 11, 4), (28, 8, 4)],
    "D": [(0, 10, 6), (6, 12, 2), (8, 14, 8), (16, 13, 4), (20, 11, 4), (24, 10, 4), (28, 8, 4)],
}


def zone_roof():
    s = Band(135, 4, ROOF_BARS, seed=2901, levels={
        "clean": -22.0, "pad": -25.0, "bells": -27.0, "floor": -26.0, "wind": -31.0,
        "tgtr": -22.5, "ttoms": -24.5, "rev": -28.0, "tbass": -24.0,
        "kick": -21.0, "snare": -21.5, "cym": -26.5, "toms": -25.0, "gtr": -16.8, "bass": -21.0, "cpad": -27.0,
        "lead": -19.5, "choir": -23.5, "glass": -27.0,
    })
    rng = s.rng
    band.zone_reverbs(s, "open", rt60=4.6, pre_delay=0.04, dark=0.45, early=4, early_span=0.15, early_gain=0.15)
    s.bus("clean", "explore", sends={"space": 0.8}, process=band.clean_chorus(0.7, bright=1.1), stereo_width=1.25)
    s.bus("pad", "explore", sends={"space": 0.6}, eq=g_mul(g_highpass(120.0, 2), g_lowpass(5000.0, 1)), stereo_width=1.3)
    s.bus("cpad", "combat", sends={"space": 0.4}, eq=g_mul(g_highpass(200.0, 2), g_lowpass(5000.0, 1)), stereo_width=1.3)
    s.bus("bells", "explore", sends={"far": 0.8, "space": 0.4}, eq=g_highpass(150.0, 2))
    s.bus("floor", "explore", sends={"space": 0.5}, eq=g_mul(g_highpass(45.0, 2), g_lowpass(1500.0, 2)))
    s.bus("wind", "explore", sends={"space": 0.2}, stereo_width=1.4)
    s.bus("tgtr", "tension", sends={"space": 0.45}, process=band.rhythm_amp(0.75), stereo_width=1.0, eq=g_lowpass(4500.0, 2))
    s.bus("ttoms", "tension", sends={"room": 0.2, "space": 0.4}, eq=g_highpass(50.0, 2))
    s.bus("rev", "tension", sends={"space": 0.5}, eq=g_highpass(800.0, 2), stereo_width=1.3)
    s.bus("tbass", "tension", sends={"room": 0.05}, process=band.bass_rig(0.7))
    band.metal_buses(s, room=0.12, space=0.25)
    s.bus("gtr", "combat", sends={"space": 0.22, "room": 0.08}, process=band.rhythm_amp(0.95, mid_db=4.0, presence_db=4.5),
          stereo_width=1.0)
    s.bus("bass", "combat", sends={"room": 0.04}, process=band.bass_rig(0.9))
    s.bus("lead", "hi", sends={"space": 0.6}, process=band.lead_amp(0.8))
    s.bus("choir", "hi", sends={"space": 0.8}, eq=g_highpass(150.0, 2))
    s.bus("glass", "hi", sends={"space": 0.9})

    tag_of = lambda bar: band.section_of(ROOF_FORM, bar)
    chord_of = lambda bar: ROOF_CHORDS[bar]
    s.chord_of = chord_of

    # --- explore: shimmering clean tremolo chords, a wide pad, far bells, a soft floor tom, wind
    clean = Guitarist(s, "clean", rng, pans=(0.0,), bright=0.75)
    for bar in range(ROOF_BARS):
        chord = chord_of(bar)
        r = root_of(chord)
        if r < 5:
            r += 12
        shape = ROOF_SHAPE[chord]
        if tag_of(bar) == "C":
            clean.riff(bar, [(0, 16, (r, shape), "ring")], 0.75)
        else:
            clean.riff(bar, [(k, 2, (r, shape), "open") for k in range(0, 16, 2)], 0.6, gap=0.98)
    for bar in range(0, ROOF_BARS, 2):
        chord = chord_of(bar)
        rr = gw.root(chord, 50, 61)
        notes = [rr, rr + 7, rr + 12 + third_of(chord), rr + 14]
        sig = metal.analog_pad(notes, s.sec(8) - 0.2, 0.55, rng, attack=1.5, release=2.0, cutoff=2200.0)
        s.add("pad", s.at(bar), sig)
        s.add("cpad", s.at(bar), sig)
    for bar in range(0, ROOF_BARS, 4):
        s.add("bells", s.at(bar, 1.0), ins.church_bell(m("A3") if bar % 8 else m("D4"), 0.6, rng, length=6.0), pan=0.5)
    fl = Drummer(s, rng, {"floor": ("floor", lambda: metal.tom(72.0, 0.8, rng, 1.0), 3, -0.15)})
    for bar in range(ROOF_BARS):
        fl.bar(bar, {"floor": "X.......x......." if tag_of(bar) != "C" else "X..............."}, vel=0.8)
    n = s.n
    wind = dsp.noise(n, rng, g_mul(dsp.g_band(300.0, 3000.0, 1), dsp.pink), 2)
    s.add("wind", 0, wind * (0.35 + 0.65 * (0.5 + 0.5 * dsp.wander(n, rng, 0.07)))[:, None])

    # --- tension: tremolo distortion under the shimmer, toms in eighths, reverse cymbals, the bass
    tg = Guitarist(s, "tgtr", rng, pans=(-0.8, 0.8))
    tbass = Guitarist(s, "tbass", rng, pans=(0.0,), bass=True)
    tt = Drummer(s, rng, {"t2": ("ttoms", lambda: metal.tom(105.0, 0.85, rng), 3, 0.2),
                          "t3": ("ttoms", lambda: metal.tom(78.0, 0.9, rng), 3, -0.2)})
    for bar in range(ROOF_BARS):
        chord = chord_of(bar)
        r = root_of(chord)
        tg.tremolo(bar, [(16, (r, "5"))], art="open", vel=0.7)
        tbass.riff(bar, [(0, 16, r - 12, "open")], 0.8)
        tt.bar(bar, {"t3": "x.x.x.x.x.x.x.x.", "t2": "....x.......x..."}, vel=0.75)
    for start, _bars, _ in ROOF_FORM:
        if start >= 2:
            s.add("rev", s.at(start - 2), metal.reverse_cymbal(s.sec(8), 0.8, rng))
        else:
            s.add("rev", s.at(ROOF_BARS - 2), metal.reverse_cymbal(s.sec(8), 0.8, rng))

    # --- combat: blast beats under tremolo-picked open chords, a groove section, a half-time valley
    dr = Drummer(s, rng, band.metal_kit(rng, toms=(140.0, 104.0, 76.0)))
    gtr = Guitarist(s, "gtr", rng)
    bass = Guitarist(s, "bass", rng, pans=(0.0,), bass=True)
    heads = starts(ROOF_FORM)
    for bar in range(ROOF_BARS):
        tag, chord = tag_of(bar), chord_of(bar)
        low = root_of(chord)
        r = low + 12 if low < 5 else low
        shape = ROOF_SHAPE[chord]
        if tag == "C":
            dr.bar(bar, {"kick": "X.......x.x.....", "snare": "........X.......", "ride": "x.x.x.x.x.x.x.x."})
            gtr.riff(bar, [(0, 16, (r, shape), "ring")], 1.0)
        elif tag == "D":
            dr.bar(bar, {"kick": "xxxxxxxxxxxxxxxx", "snare": "........X.......", "china": "x...x...x...x..."})
            gtr.tremolo(bar, [(16, (r, shape))], art="open", vel=0.95)
        else:
            dr.bar(bar, G_BLAST if bar % 8 < 6 else G_DOUBLE)
            gtr.tremolo(bar, [(16, (r, shape))], art="open", vel=0.95)
        if bar in heads:
            dr.hit("crash", s.at(bar), 1.0)
            dr.hit("crash2", s.at(bar), 0.85)
        if bar % 8 == 7:
            dr.fill(bar, ["t1", "t1", "t2", "t2", "t3", "t3", "snare", "snare"], 8, 8, (0.6, 1.0))
        bass.riff(bar, [(0, 8, low - 12, "open"), (8, 8, low - 12, "open")], 0.9)

    # --- hi: the high lead in long notes, the choir, glass
    for bar0, key in [(0, "A"), (8, "B"), (24, "A"), (32, "D"), (40, "B")]:
        band.lead_line(s, "lead", bar0, ROOF_TUNE[key], "aeolian", rng, shift=0, vel=0.85, vibrato=0.45)
    for bar in range(ROOF_BARS):
        if tag_of(bar) in ("B", "D", "turn"):
            notes = [x + 12 for x in gw.voicing(chord_of(bar), 50)[1:]]
            s.add("choir", s.at(bar), ins.choir(notes, s.sec(4) - 0.1, 0.7, rng, ins.VOWEL_A, attack=0.4, release=0.9))
    for bar, name in [(0, "A5"), (16, "F5"), (32, "D6"), (48, "E5")]:
        s.add("glass", s.at(bar), ins.glass(m(name), s.sec(32) - 1.0 if bar < 48 else s.sec(20), 0.6, rng, attack=2.0,
                                            release=2.0), pan=0.3)
    return band.master_zone(s.render(), "roof", 2901)


ZONES = {"court": zone_court, "enlightenment": zone_enlightenment, "asia": zone_asia, "basement": zone_basement,
         "roof": zone_roof}
