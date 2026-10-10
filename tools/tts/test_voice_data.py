import unittest

from voice_data import line_hash, load


class VoiceDataTest(unittest.TestCase):
    def test_the_hash_matches_the_contract(self):
        # the same string the GDScript test hashes (VoiceCatalog.hash_of)
        self.assertEqual(line_hash("af_heart", 1.0, 0, 1, "Hello there, museum."),
                         __import__("hashlib").sha256("af_heart|1.000|0|1|Hello there, museum.".encode()).hexdigest())

    def test_every_line_has_english_text_and_a_speaker(self):
        data = load()
        for key, line in data.lines.items():
            self.assertIn(line["speaker"], data.speakers, key)
            self.assertGreaterEqual(len(data.text_en[key]), 20, key)
            self.assertNotIn("\n", data.text_en[key], key)


if __name__ == "__main__":
    unittest.main()
