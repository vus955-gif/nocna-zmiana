"""Markdown table of the Assyrian models from a build log of build_models.py:
    python tools/art/asy_table.py build.log
(model, parts, triangles, atlas, px/m) for the catalogue."""
import re
import sys


def main(path):
    rows = []
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"model (\S+): (\d+) parts, (\d+) tris, atlas (\d+x\d+) @ (\d+) px/m", line)
        if m:
            name, parts, tris, atlas, ppm = m.groups()
            rows.append((name, int(parts), int(tris), atlas, int(ppm)))
    print("| Id | Części | Trójkąty | Atlas | px/m |")
    print("|---|---|---|---|---|")
    for name, parts, tris, atlas, ppm in rows:
        print(f"| `{name}` | {parts} | {tris:,} | {atlas} | {ppm} |".replace(",", " "))


if __name__ == "__main__":
    main(sys.argv[1])
