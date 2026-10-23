"""Tests of the room tails (acoustics_tails.py) and of the ambient story's
sounds and rain beds (ambience_story.py). numpy only; run with Blender's
bundled Python:

    cd tools/music
    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" -m unittest -v test_acoustics

The checks of rendered files read build/audio_src/ambience/ and skip, loudly
("SKIPPED: ..."), what has not been rendered.
"""
import unittest
from pathlib import Path

import numpy as np

import acoustics_tails as tails
import ambience_story as story
import analyze
import dsp

ROOT = Path(__file__).resolve().parents[2]
BUILT = ROOT / "build" / "audio_src" / "ambience"


def skip_unless(path):
    if not path.exists():
        print(f"SKIPPED: {path} not rendered")
        return True
    return False


class Profiles(unittest.TestCase):
    def setUp(self):
        self.profiles = tails.load_profiles()

    def test_every_profile_has_a_tail_block(self):
        self.assertEqual(len(self.profiles), 11)
        for pid, prof in self.profiles.items():
            for key in ("rt60", "predelay_ms", "early", "early_ms", "dark", "low"):
                self.assertIn(key, prof["tail"], f"{pid}.{key}")
            self.assertIn("tail_db", prof)

    def test_bigger_spaces_ring_longer(self):
        rt = {pid: p["tail"]["rt60"] for pid, p in self.profiles.items()}
        self.assertGreater(rt["vast"], rt["hall"])
        self.assertGreater(rt["hall"], rt["gallery"])
        self.assertGreater(rt["gallery"], rt["room"])
        self.assertGreater(rt["room"], rt["store"])


class RoomResponse(unittest.TestCase):
    def setUp(self):
        self.profiles = tails.load_profiles()

    def test_the_decay_follows_the_profile(self):
        for pid, prof in self.profiles.items():
            if prof["tail"].get("echoes_ms"):
                continue   # discrete echoes dominate a short open space: checked below
            ir = tails.room_ir(prof["tail"], np.random.default_rng(5))
            t20 = tails.decay_time(ir)
            self.assertAlmostEqual(t20 / prof["tail"]["rt60"], 1.0, delta=0.2, msg=f"{pid}: T20 {t20:.2f} s")

    def test_nothing_arrives_before_the_predelay(self):
        for pid, prof in self.profiles.items():
            ir = tails.room_ir(prof["tail"], np.random.default_rng(5))
            pre = prof["tail"]["predelay_ms"] / 1000.0
            self.assertTrue(np.all(ir[:dsp.n_of(pre)] == 0.0), pid)
            self.assertLess(tails.onset(ir), pre + prof["tail"]["early_ms"][1] / 1000.0 + 0.02, pid)

    def test_galleries_and_corridors_flutter_between_their_walls(self):
        for pid in ("gallery", "corridor"):
            prof = self.profiles[pid]["tail"]
            ir = dsp.mono(tails.room_ir(prof, np.random.default_rng(5)))
            energy = dsp.box_smooth(dsp.bandpass(ir, 1000.0, 5000.0) ** 2, dsp.n_of(0.001), circular=False)
            trend = dsp.box_smooth(energy, dsp.n_of(0.06), circular=False)   # the decay itself out
            seg = (energy / np.maximum(trend, 1e-20))[dsp.n_of(0.1):dsp.n_of(0.9)]
            seg = seg - seg.mean()
            spec = np.abs(np.fft.rfft(seg * np.hanning(seg.size)))
            f = np.fft.rfftfreq(seg.size, 1.0 / dsp.SR)
            f0 = 1000.0 / prof["flutter_ms"]
            peak = spec[(f > f0 * 0.95) & (f < f0 * 1.05)].max()
            floor = np.median(spec[(f > 5.0) & (f < 3.0 * f0)])
            self.assertGreater(peak / floor, 3.0, f"{pid}: the envelope repeats every {prof['flutter_ms']} ms")

    def test_the_roof_answers_with_echoes_off_the_buildings(self):
        prof = self.profiles["open"]["tail"]
        ir = dsp.mono(tails.room_ir(prof, np.random.default_rng(5)))
        w = dsp.n_of(0.01)
        for delay in prof["echoes_ms"][:2]:
            at = dsp.n_of(delay / 1000.0)
            echo = dsp.rms(ir[at - w // 2:at + w])
            before = dsp.rms(ir[at - 4 * w:at - 2 * w])
            self.assertGreater(echo, before * 2.0, f"an echo at {delay} ms")

    def test_steel_rings_where_books_do_not(self):
        steel = tails.room_ir(self.profiles["steel"]["tail"], np.random.default_rng(5))
        library = tails.room_ir(self.profiles["library"]["tail"], np.random.default_rng(5))
        self.assertGreater(tails.decay_time(steel, 2500.0, 7000.0), tails.decay_time(library, 2500.0, 7000.0) * 2.0)


class Tails(unittest.TestCase):
    def test_a_tail_is_repeatable_and_normalised(self):
        prof = tails.load_profiles()["room"]["tail"]
        a = tails.render_tail("room", prof, "crack")
        b = tails.render_tail("room", prof, "crack")
        self.assertTrue(np.array_equal(a, b))
        self.assertAlmostEqual(tails.momentary_max(a), tails.TAIL_MOMENTARY, delta=0.3)
        self.assertLessEqual(dsp.true_peak(a), tails.TAIL_CEILING + 0.05)

    def test_classes_differ_in_weight(self):
        rng = np.random.default_rng(1)
        shares = {k: analyze.band_shares(tails.excitation(k, rng)) for k in tails.CLASSES}
        low = {k: shares[k]["sub"] + shares[k]["low"] for k in shares}
        self.assertGreater(low["boom"], low["crack"])
        self.assertGreater(low["blast"], low["boom"])

    def test_rendered_tails(self):
        out = BUILT / "tails"
        if skip_unless(out):
            return
        profiles = tails.load_profiles()
        lengths = {}
        for pid, prof in profiles.items():
            for kind in tails.CLASSES:
                path = out / f"tail_{pid}_{kind}.wav"
                if skip_unless(path):
                    continue
                x = dsp.read_wav(path)
                self.assertEqual(x.ndim, 2, f"{path.name} is stereo")
                peak = dsp.true_peak(x)
                self.assertLessEqual(peak, tails.TAIL_CEILING + 0.1, path.name)
                # the momentary target, or as loud as the ceiling lets a short, peaky tail be
                level = tails.momentary_max(x)
                self.assertTrue(abs(level - tails.TAIL_MOMENTARY) < 0.4 or (peak > tails.TAIL_CEILING - 0.2 and level < tails.TAIL_MOMENTARY),
                                f"{path.name}: {level:.1f} LUFS, tp {peak:.1f}")
                self.assertLess(np.max(np.abs(x[:4])), 1e-3, f"{path.name} starts silent")
                self.assertLess(dsp.rms(x[-dsp.n_of(0.01):]), 1e-3, f"{path.name} ends silent")
                self.assertLess(float(np.max(np.abs(x.mean(axis=0)))), 1e-3, f"{path.name}: no DC")
                lengths[(pid, kind)] = x.shape[0]
        if lengths:
            self.assertGreater(lengths[("vast", "crack")], lengths[("store", "crack")] * 4)



class StorySounds(unittest.TestCase):
    def test_a_story_sound_is_repeatable(self):
        for kind in ("whisper", "phantom_steps", "radio_chatter"):
            a = story.SHOTS[kind][1](np.random.default_rng(11), 1)
            b = story.SHOTS[kind][1](np.random.default_rng(11), 1)
            self.assertTrue(np.array_equal(a, b), kind)

    def test_whispers_come_in_syllables(self):
        x = story.shot_whisper(np.random.default_rng(4), 0)
        env = dsp.box_smooth(np.abs(x), dsp.n_of(0.01), circular=False)[:dsp.n_of(2.0)]
        env = env - env.mean()
        spec = np.abs(np.fft.rfft(env * np.hanning(env.size)))
        f = np.fft.rfftfreq(env.size, 1.0 / dsp.SR)
        syll = spec[(f > 2.5) & (f < 9.0)].max()
        slow = np.median(spec[(f > 20.0) & (f < 60.0)])
        self.assertGreater(syll, slow * 5.0, "the level comes and goes at a syllable rate")

    def test_rendered_story_sounds(self):
        out = BUILT / "oneshots"
        if skip_unless(out):
            return
        for kind, (count, _make) in story.SHOTS.items():
            for k in range(count):
                path = out / f"shot_{kind}_{k + 1}.wav"
                if skip_unless(path):
                    continue
                x = dsp.read_wav(path)
                self.assertEqual(x.ndim, 1, f"{path.name} is mono")
                self.assertAlmostEqual(float(dsp.to_db(dsp.peak(x))), story.SHOT_PEAK_DB[kind], delta=0.15, msg=path.name)
                level = tails.momentary_max(x)
                self.assertTrue(-19.0 < level < -11.0, f"{path.name}: loudest moment {level:.1f} LUFS")
                self.assertLess(np.max(np.abs(x[:8])), 0.01, f"{path.name} starts from silence")
                self.assertLess(dsp.rms(x[-dsp.n_of(0.01):]), 1e-3, f"{path.name} ends in silence")

    def test_rain_beds_loop_without_a_seam_or_a_whine(self):
        for name in story.BEDS:
            path = BUILT / f"bed_{name}.wav"
            if skip_unless(path):
                continue
            x = dsp.read_wav(path)
            self.assertEqual(x.shape[0], dsp.n_of(story.LOOP), name)
            info = analyze.report(x, name, True)
            self.assertAlmostEqual(info["lufs"], story.BED_LUFS[name], delta=0.3, msg=name)
            self.assertLess(info["seam"]["jump_vs_p999"], 1.0, f"{name}: no jump at the seam")
            self.assertLess(info["seam"]["hf_ratio"], 1.5, f"{name}: no click at the seam")
            self.assertLess(abs(info["corr"]), 0.5, f"{name}: rain all around, not in the middle")
            # a steady whine survives averaging over the loop (Welch), passing drops do not
            m = dsp.mono(x)
            size = 1 << 15
            win = np.hanning(size)
            psd = np.mean([np.abs(np.fft.rfft(m[a:a + size] * win)) ** 2 for a in range(0, m.size - size, size // 2)], axis=0)
            f = np.fft.rfftfreq(size, 1.0 / dsp.SR)
            band = (f > 1500.0) & (f < 8000.0)
            ratio = psd[band] / dsp.box_smooth(psd[band], 200, circular=False)
            self.assertLess(float(ratio.max()), 5.0, f"{name}: no tone stands out of the rain (white noise: ~1.4)")


if __name__ == "__main__":
    unittest.main()
