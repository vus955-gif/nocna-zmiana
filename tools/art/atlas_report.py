"""Where does a model's atlas go? Lists its biggest UV islands (texels with
padding) per material slot, headless:

    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \
        --python tools/art/atlas_report.py -- <module> [model name]
"""
import importlib
import math
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from artlib import bake, scene  # noqa: E402


def main(argv):
    module = argv[0]
    only = argv[1] if len(argv) > 1 else None
    scene.reset()
    mod = importlib.import_module("models." + module)
    models = mod.build()
    if not isinstance(models, list):
        models = [models]
    for m in models:
        if only and m.name != only:
            continue
        for part in m.parts:
            if part.name in m.organic:
                scene.smart_unwrap(part)
            part.finalize()
        slots = set(m.fns)
        rows = []
        per_slot = defaultdict(int)
        for part in m.parts:
            for i in bake._islands(part, slots):
                w = max(1, math.ceil(i["u1"] * m.ppm) - math.floor(i["u0"] * m.ppm)) + 2 * m.pad
                h = max(1, math.ceil(i["v1"] * m.ppm) - math.floor(i["v0"] * m.ppm)) + 2 * m.pad
                slot = part.slots[i["faces"][0].material_index]
                rows.append((w * h, w, h, slot, len(i["faces"])))
                per_slot[slot] += w * h
        rows.sort(reverse=True)
        total = sum(r[0] for r in rows)
        print(f"== {m.name}: {len(rows)} islands, {total} texels with padding @ {m.ppm} px/m")
        for slot, t in sorted(per_slot.items(), key=lambda kv: -kv[1]):
            print(f"   slot {slot:14s} {t:9d}")
        for r in rows[:12]:
            print(f"   island {r[1]:5d} x {r[2]:5d} = {r[0]:8d}  {r[3]} ({r[4]} faces)")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:])
