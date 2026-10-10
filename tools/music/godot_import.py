"""Import settings for the encoded Ogg Vorbis files (.import next to each).

Loops get loop=true with loop_offset 0 (they loop over the whole file;
the seam check in check_loops.gd / analyze.py --seams confirms the decoded
ends meet sample-exactly). One-shots and stings do not loop. An existing
.import keeps its uid and paths; only these parameters change, and Godot
reimports the file on the next `--import`.
"""
import re
from pathlib import Path

PARAMS = [("loop", "false"), ("loop_offset", "0"), ("bpm", "0"), ("beat_count", "0"), ("bar_beats", "4")]


def mark_ogg(ogg_path, loop):
    ogg_path = Path(ogg_path)
    wanted = dict(PARAMS)
    wanted["loop"] = "true" if loop else "false"
    import_path = ogg_path.with_name(ogg_path.name + ".import")
    if not import_path.exists():
        body = '[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n\n[params]\n\n'
        body += "".join(f"{k}={v}\n" for k, v in wanted.items())
        import_path.write_text(body, encoding="utf-8", newline="\n")
        return
    text = import_path.read_text(encoding="utf-8")
    for key, value in wanted.items():
        pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
        if pattern.search(text):
            text = pattern.sub(f"{key}={value}", text)
        else:
            text = text.rstrip("\n") + f"\n{key}={value}\n"
    import_path.write_text(text, encoding="utf-8", newline="\n")
