"""Tests of the biome score's generators (metal.py, band.py) and of the
rendered intermediates. numpy only; run with Blender's bundled Python:

    cd tools/music
    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" -m unittest -v test_music_gen

The asset checks (loudness targets, peaks, lengths, seams of every zone
family and guardian theme) read build/audio_src/music/*.wav and skip, loudly
("SKIPPED: ..."), what has not been rendered.
"""
import sys
import unittest
from pathlib import Path

import numpy as np

import analyze
import band
import dsp
import metal
from band import Band, Drummer, Guitarist, parse_riff

ROOT = Path(__file__).resolve().parents[2]
WAVS = ROOT / "build" / "audio_src" / "music"
ZONES = ["court", "egypt", "assyria", "greece", "enlightenment", "asia", "americas", "basement", "roof"]
WINGS = ["egypt", "assyria", "greece", "enlightenment", "asia", "americas"]
# frames of every zone loop and guardian theme (as tests/unit/test_audio_assets.gd expects)
ZONE_FRAMES = {"asia": 4410000}
GUARDIAN_FRAMES = {"egypt": 2822400, "assyria": 2822400, "greece": 2822400, "enlightenment": 3175200, "asia": 2646000,
                   "americas": 3175200}


def tiny_band(seed=7):
    """A 4-bar loop in all four stems: drums, an amped riff, a pad, a lead."""
    s = Band(120, 4, 4, seed=seed, levels={"kick": -21.0, "snare": -22.0, "gtr": -18.0, "pad": -24.0, "tdrum": -23.0,
                                           "lead": -20.0})
    rng = s.rng
    s.reverb("room", rt60=0.8, pre_delay=0.008, dark=0.5)
    s.bus("pad", "explore", sends={"room": 0.3})
    s.bus("tdrum", "tension", sends={"room": 0.2})
    s.bus("kick", "combat")
    s.bus("snare", "combat", sends={"room": 0.3})
    s.bus("gtr", "combat", process=band.rhythm_amp(1.0))
    s.bus("lead", "hi", process=band.lead_amp())
    dr = Drummer(s, rng, {"kick": ("kick", lambda: metal.kick(0.9, rng), 2, 0.0),
                          "snare": ("snare", lambda: metal.snare(0.9, rng), 2, 0.0),
                          "tom": ("tdrum", lambda: metal.tom(100.0, 0.9, rng), 2, 0.0)})
    g = Guitarist(s, "gtr", rng)
    for bar in range(4):
        dr.bar(bar, {"kick": "X...x...X...x...", "snare": "....X.......X...", "tom": "X.......X......."})
        g.riff(bar, parse_riff("5:0 - p p 1 - p p 4 - 5 4 1 - p p"))
        s.add("pad", s.at(bar), metal.analog_pad([50, 57, 65], s.sec(4) - 0.1, 0.6, rng))
    band.lead_line(s, "lead", 0, [(0, 7, 4), (4, 9, 4), (8, 8, 8)], "hijaz", rng, shift=-12)
    return s


class Voices(unittest.TestCase):
    def test_a_string_is_repeatable_bounded_and_gated(self):
        a = metal.string_di(38, 0.2, 0.9, np.random.default_rng(3), mute=1.0)
        b = metal.string_di(38, 0.2, 0.9, np.random.default_rng(3), mute=1.0)
        self.assertTrue(np.array_equal(a, b), "same seed, same note")
        self.assertLessEqual(dsp.peak(a), 0.9 + 1e-9)
        self.assertEqual(float(a[-1]), 0.0, "the fret hand lets go: the note ends at zero")
        self.assertTrue(np.all(np.isfinite(a)))

    def test_palm_mutes_are_shorter_and_darker_than_open_notes(self):
        rng = np.random.default_rng(4)
        open_ = metal.string_di(38, 1.0, 0.9, rng)
        muted = metal.string_di(38, 1.0, 0.9, rng, mute=1.0)
        tail = dsp.n_of(0.4)
        self.assertLess(dsp.rms(muted[tail:]), dsp.rms(open_[tail:]) * 0.3, "a palm mute dies fast")
        hi = lambda x: analyze.band_shares(x)["mid"] + analyze.band_shares(x)["high"]
        self.assertLess(hi(muted), hi(open_), "and darker")

    def test_the_amp_keeps_silence_silent(self):
        self.assertFalse(np.any(metal.amp(np.zeros(4096))))

    def test_the_amp_treats_a_loop_as_a_loop(self):
        rng = np.random.default_rng(5)
        x = np.zeros(dsp.n_of(2.0))
        for k in range(8):
            note = metal.chord_di(38, "5", 0.2, 0.9, rng, mute=1.0)
            x[dsp.n_of(0.25 * k):dsp.n_of(0.25 * k) + note.shape[0]] += note
        y = metal.amp(x)
        shift = 12345
        self.assertLess(np.max(np.abs(metal.amp(np.roll(x, shift)) - np.roll(y, shift))), 1e-6, "rotation-equivariant")
        self.assertLess(abs(float(np.mean(y))), 1e-3 * dsp.rms(y), "no DC")
        shares = analyze.band_shares(y)
        self.assertGreater(shares["lowmid"] + shares["mid"], 0.6, "a guitar lives in the mids")
        self.assertLess(shares["air"], 0.01, "the cabinet cuts the fizz")

    def test_drums_are_peak_normalised_and_finite(self):
        rng = np.random.default_rng(6)
        for name, hit in [("kick", metal.kick(0.9, rng)), ("snare", metal.snare(0.9, rng)), ("tom", metal.tom(110.0, 0.9, rng)),
                          ("hat", metal.hihat("closed", 0.9, rng)), ("open", metal.hihat("open", 0.9, rng)),
                          ("ride", metal.ride(0.9, rng)), ("crash", metal.crash(0.9, rng)),
                          ("china", metal.crash(0.9, rng, china=True)), ("gated", metal.gated_snare(0.9, rng)),
                          ("ikick", metal.industrial_kick(0.9, rng)), ("clap", metal.clap(0.9, rng))]:
            self.assertTrue(np.all(np.isfinite(hit)), name)
            self.assertAlmostEqual(dsp.peak(hit), 0.9, 6, name)
        self.assertGreater(analyze.band_shares(metal.kick(0.9, rng))["sub"] + analyze.band_shares(metal.kick(0.9, rng))["low"], 0.9)
        self.assertGreater(analyze.band_shares(metal.hihat("closed", 0.9, rng))["high"] + 0.0, 0.2)

    def test_culture_voices_render(self):
        rng = np.random.default_rng(7)
        for name, sig in [("oud", metal.oud(62, 0.8, rng)), ("shamisen", metal.shamisen(62, 0.8, rng)),
                          ("aulos", metal.aulos(69, 0.6, 0.8, rng)), ("whistle", metal.death_whistle(1.0, 0.9, rng)),
                          ("pipe", metal.pipe_hit(400.0, 0.8, rng)), ("steam", metal.steam(0.5, 0.6, rng))]:
            self.assertGreater(sig.shape[0], dsp.n_of(0.2), name)
            self.assertTrue(np.all(np.isfinite(sig)), name)
            self.assertGreater(dsp.peak(sig), 0.0, name)
        shares = analyze.band_shares(metal.death_whistle(1.0, 0.9, rng))
        self.assertGreater(shares["mid"] + shares["high"], 0.6, "the death whistle screams high")


class Notation(unittest.TestCase):
    def test_a_riff_reads_holds_rests_mutes_and_chords(self):
        events = parse_riff("5:0 - p p 1 - . p3 b5:7 -")
        self.assertEqual(events, [(0, 2, (0, "5"), "open"), (2, 1, 0, "pm"), (3, 1, 0, "pm"), (4, 2, 1, "open"),
                                  (7, 1, 3, "pm"), (8, 2, (7, "b5"), "open")])
        self.assertEqual(band.bass_of(events)[0], (0, 2, -12, "open"), "the bass takes the root an octave down")

    def test_drum_strings_place_their_hits_on_the_grid(self):
        s = Band(120, 4, 1, seed=1)
        s.bus("kick", "combat")
        dr = Drummer(s, s.rng, {"kick": ("kick", lambda: metal.kick(0.9, s.rng), 1, 0.0)})
        dr.bar(0, {"kick": "X...x...........", "snare": "x..."}, jitter=0.0)
        self.assertEqual(dr.kicks, [0, s.spb], "beats 1 and 2; an instrument the kit lacks is skipped")

    def test_chord_arpeggios_keep_the_chords_own_tones(self):
        self.assertEqual(band.chord_arp("Em7b5", 50, 5), [52, 55, 58, 62, 64], "the flat fifth, not B")
        self.assertEqual(band.chord_arp("Dm", 50, 4), [50, 53, 57, 62])


class Mastering(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.first = band.master_quad(tiny_band().render(verbose=False))

    def test_a_band_render_is_repeatable(self):
        again = band.master_quad(tiny_band().render(verbose=False))
        for a, b in zip(self.first, again):
            self.assertTrue(np.array_equal(a, b))

    def test_the_four_stems_hit_the_games_levels(self):
        explore, tension, combat, hi = self.first
        self.assertAlmostEqual(dsp.lufs(explore, circular=True), band.TARGETS["explore"], delta=0.3)
        self.assertAlmostEqual(dsp.lufs(explore + tension, circular=True), band.TARGETS["explore+tension"], delta=0.3)
        self.assertAlmostEqual(dsp.lufs(combat, circular=True), band.TARGETS["combat"], delta=0.3)
        self.assertAlmostEqual(dsp.lufs(combat + hi, circular=True), band.TARGETS["combat+hi"], delta=0.3)
        for x in (explore, explore + tension, combat, combat + hi):
            self.assertLessEqual(dsp.to_db(dsp.peak(x)), -1.49, "the pair the game sums stays under the ceiling")

    def test_the_stems_stay_in_sync_and_loop_without_a_seam(self):
        lengths = {x.shape[0] for x in self.first}
        self.assertEqual(lengths, {4 * 4 * 22050}, "one length for the whole family")
        for x in self.first:
            self.assertLess(analyze.seam(x)["jump_vs_p999"], 0.6, "the end flows into the start")


def _wav(name):
    path = WAVS / f"{name}.wav"
    return dsp.stereo(dsp.read_wav(path)) if path.exists() else None


class RenderedAssets(unittest.TestCase):
    """The intermediates gen_biomes.py and guardians.py wrote. Where
    nothing was rendered (build/ is not in git) the tests are skipped with
    a message that says so: a green run then has not checked any music."""

    @classmethod
    def setUpClass(cls):
        if not any(WAVS.glob("*.wav")):
            message = (f"SKIPPED: no rendered WAVs in {WAVS} - the loudness, peak, length and seam checks of the "
                       "biome music did NOT run (render them with tools/build_audio.sh first)")
            print("\n" + message, file=sys.stderr)
            raise unittest.SkipTest(message)

    def _check_pair(self, base, layer, base_target, full_target, frames):
        a, b = _wav(base), _wav(layer)
        if a is None or b is None:
            self.skipTest(f"SKIPPED: {base}.wav / {layer}.wav not rendered - this pair was NOT checked")
        self.assertEqual(a.shape[0], frames, base)
        self.assertEqual(b.shape[0], frames, layer)
        self.assertAlmostEqual(dsp.lufs(a, circular=True), base_target, delta=0.35, msg=base)
        self.assertAlmostEqual(dsp.lufs(a + b, circular=True), full_target, delta=0.35, msg=layer)
        for name, x in ((base, a), (layer, b), (base + "+" + layer, a + b)):
            self.assertLessEqual(dsp.to_db(dsp.peak(x)), -1.3, name)
            # rendered circularly, the wrap is one more step of the waveform: it must not stand out from
            # the loop's own steps (the engine's decode across the wrap: test_audio_assets.gd)
            self.assertLess(analyze.seam(x)["jump_vs_p999"], 1.0, name + " seam")

    def test_every_zone_family(self):
        for zone in ZONES:
            with self.subTest(zone=zone):
                names = band.zone_names(zone)
                frames = ZONE_FRAMES.get(zone, 4233600)
                self._check_pair(names[0], names[1], band.TARGETS["explore"], band.TARGETS["explore+tension"], frames)
                self._check_pair(names[2], names[3], band.TARGETS["combat"], band.TARGETS["combat+hi"], frames)

    def test_every_guardian_theme(self):
        for wing in WINGS:
            with self.subTest(wing=wing):
                self._check_pair(f"guardian_{wing}", f"guardian_{wing}_hi", -18.0, -16.5, GUARDIAN_FRAMES[wing])


if __name__ == "__main__":
    unittest.main()
