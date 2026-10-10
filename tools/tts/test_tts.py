import unittest

import numpy as np

from kokoro_tts import SR, Kokoro, lang_of


class KokoroTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tts = Kokoro({"Heniek": "hˈɛnjɛk"})

    def test_a_sentence_is_a_plausible_recording(self):
        wav = self.tts.synth("The museum is now closed. Thank you for your visit.", "af_heart")
        self.assertTrue(1.5 < len(wav) / SR < 7.0, len(wav) / SR)
        rms = float(np.sqrt(np.mean(wav ** 2)))
        self.assertTrue(0.01 < rms < 0.3, rms)
        self.assertTrue(np.isfinite(wav).all())

    def test_a_lexicon_word_is_spoken_from_its_ipa(self):
        self.assertIn("hˈɛnjɛk", self.tts.phonemes("Heniek here.", "en-gb"))

    def test_the_accent_follows_the_voice(self):
        self.assertEqual(lang_of("bm_george"), "en-gb")
        self.assertEqual(lang_of("af_heart"), "en-us")

    def test_long_text_is_split_into_chunks_not_cut(self):
        text = " ".join(["The same decree is written three times, in three scripts."] * 8)
        wav = self.tts.synth(text, "af_heart")
        self.assertGreater(len(wav) / SR, 15.0)

    def test_unknown_lexicon_symbols_are_refused(self):
        with self.assertRaises(ValueError):
            Kokoro({"Zawilski": "zaˈvʲilskʲi☃"})


if __name__ == "__main__":
    unittest.main()
