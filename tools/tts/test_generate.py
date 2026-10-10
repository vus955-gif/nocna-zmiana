import json
import tempfile
import unittest
from pathlib import Path

import generate_voice
from voice_data import ROOT


class GenerateTest(unittest.TestCase):
    def test_every_recording_in_the_repo_has_a_manifest_entry(self):
        manifest = json.loads((ROOT / "assets/voice/manifest.json").read_text(encoding="utf-8"))
        for ogg in (ROOT / "assets/voice").glob("*/*.ogg"):
            self.assertIn(ogg.stem, manifest, f"{ogg}: no manifest entry (run generate_voice.py)")
            self.assertEqual(manifest[ogg.stem]["speaker"], ogg.parent.name, ogg)

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
