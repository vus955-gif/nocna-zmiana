import json
import tempfile
import unittest
from pathlib import Path

import generate_voice
from voice_data import ROOT, load


class GenerateTest(unittest.TestCase):
    def test_every_recording_in_the_repo_has_a_manifest_entry(self):
        manifest = json.loads((ROOT / "assets/voice/manifest.json").read_text(encoding="utf-8"))
        for ogg in (ROOT / "assets/voice").glob("*/*.ogg"):
            self.assertIn(ogg.stem, manifest, f"{ogg}: no manifest entry (run generate_voice.py)")
            self.assertEqual(manifest[ogg.stem]["speaker"], ogg.parent.name, ogg)

    def test_every_line_has_an_up_to_date_recording(self):
        # the same promise the Godot test makes, from the tool's side: the manifest hash is the hash of today's
        # text, voice, tempo, level and fx version, and the file is there (G3: the uncanny events' lines included)
        manifest = json.loads((ROOT / "assets/voice/manifest.json").read_text(encoding="utf-8"))
        data = load()
        for key, line in data.lines.items():
            self.assertEqual(manifest.get(key, {}).get("hash"), data.hash_of(key), f"{key}: text or settings changed - run build_voice.sh")
            self.assertTrue((ROOT / "assets/voice" / line["speaker"] / f"{key}.ogg").exists(), key)
        for key in manifest:
            self.assertIn(key, data.lines, f"{key}: a recording of a line that is gone")

    def test_a_speaker_may_use_any_processing_level_of_the_tool(self):
        # G3: Heniek's wrong voice on the radio is Heniek's voice at level 1 (the machine intonation)
        data = load()
        voice, speed, level = data.settings("VO_HENIEK_RADIO_NOT_ME")
        self.assertEqual((voice, level), ("am_michael", 1))
        self.assertLess(speed, 1.0)
        self.assertEqual(data.settings("VO_HENIEK_EYES")[2], 0)

    def test_removing_a_line_drops_its_ogg_import_and_source_wav(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, dst = Path(tmp) / "src", Path(tmp) / "dst"
            for path in (src / "system" / "VO_OLD.wav", dst / "system" / "VO_OLD.ogg", dst / "system" / "VO_OLD.ogg.import",
                         dst / "system" / "VO_KEPT.ogg"):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"x")
            old_src, old_dst = generate_voice.SRC, generate_voice.DST
            generate_voice.SRC, generate_voice.DST = src, dst
            try:
                generate_voice.remove("VO_OLD")
            finally:
                generate_voice.SRC, generate_voice.DST = old_src, old_dst
            self.assertEqual(sorted(p.name for p in dst.glob("*/*")), ["VO_KEPT.ogg"])
            self.assertEqual(list(src.glob("*/*")), [])


if __name__ == "__main__":
    unittest.main()
