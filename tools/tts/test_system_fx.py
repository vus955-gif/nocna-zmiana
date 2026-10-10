import unittest

import numpy as np

from system_fx import process, track_f0

SR = 24000


def vowel(seconds=1.6):
    """A sung 'aa' whose pitch glides +-60 Hz around 170 Hz — speech-like movement."""
    t = np.arange(int(SR * seconds)) / SR
    f0 = 170 + 60 * np.sin(2 * np.pi * 0.8 * t)
    phase = 2 * np.pi * np.cumsum(f0) / SR
    x = sum(np.sin(k * phase) / k for k in range(1, 20))
    return (0.2 * x / np.abs(x).max()).astype(np.float32)


def spread(wav):
    """Standard deviation of the pitch in semitones (voiced frames only)."""
    f0, _ = track_f0(wav.astype(np.float64), SR)
    v = f0[f0 > 0]
    return float(np.std(12 * np.log2(v / np.median(v))))


class SystemFxTest(unittest.TestCase):
    def test_the_tracker_follows_a_known_pitch(self):
        f0, t = track_f0(vowel().astype(np.float64), SR)
        wanted = 170 + 60 * np.sin(2 * np.pi * 0.8 * t)
        voiced = f0 > 0
        self.assertGreater(voiced.mean(), 0.9)
        err = np.abs(12 * np.log2(f0[voiced] / wanted[voiced]))
        self.assertLess(np.median(err), 0.15, np.median(err))

    def test_level_0_leaves_the_voice_alone(self):
        x = vowel()
        self.assertTrue(np.array_equal(process(x, SR, 0, seed=1), x))

    def test_level_1_flattens_the_intonation(self):
        x = vowel()
        self.assertLess(spread(process(x, SR, 1, seed=1)), 0.5 * spread(x))

    def test_level_1_keeps_the_length_and_the_loudness(self):
        x = vowel()
        y = process(x, SR, 1, seed=1)
        self.assertEqual(len(y), len(x))
        rms = lambda a: float(np.sqrt(np.mean(a.astype(np.float64) ** 2)))
        self.assertTrue(0.5 < rms(y) / rms(x) < 2.0, rms(y) / rms(x))
        self.assertTrue(np.isfinite(y).all())

    def test_the_same_seed_gives_the_same_file(self):
        x = vowel()
        self.assertTrue(np.array_equal(process(x, SR, 2, seed=7), process(x, SR, 2, seed=7)))

    def test_level_2_is_broken_differently_from_level_1(self):
        x = vowel()
        a, b = process(x, SR, 1, seed=7), process(x, SR, 2, seed=7)
        self.assertFalse(len(a) == len(b) and np.allclose(a, b))
        self.assertLess(len(b), 1.5 * len(x))


if __name__ == "__main__":
    unittest.main()
