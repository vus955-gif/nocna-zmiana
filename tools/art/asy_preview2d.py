"""2D check of the Assyrian relief designs (no Blender needed, seconds):
    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/art/asy_preview2d.py [names]
writes tests/_out/art/asy2d_<name>.png (the relief lit by a low raking light)."""
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from artlib import asy, asy_figures as F, asy_panels as PN, asy_relief as rl  # noqa: E402

OUT = HERE.parents[1] / "tests" / "_out" / "art"


def warrior(ppm):
    R = rl.Relief(1.0, 2.25, ppm, u0=-0.5, v0=-0.05, seed=3)
    F.warrior(F.Pen(R, rl.Xf(0.0, 0.0, 1.0, 1)))
    return R


def genie(ppm):
    R = rl.Relief(1.6, 2.5, ppm, u0=-0.9, v0=-0.05, seed=4)
    F.genie(F.Pen(R, rl.Xf(0.0, 0.0, 1.0, 1)))
    return R


def lion(ppm, pose, **kw):
    R = rl.Relief(2.4, 1.3, ppm, u0=-1.3, v0=-0.05, seed=5)
    F.lion(F.Pen(R, rl.Xf(0.0, 0.0, 1.0, 1)), pose=pose, **kw)
    return R


def archer(ppm):
    R = rl.Relief(1.2, 2.25, ppm, u0=-0.5, v0=-0.05, seed=6)
    F.archer(F.Pen(R, rl.Xf(0.0, 0.0, 1.0, 1)))
    return R


def chariot(ppm):
    R = rl.Relief(3.3, 2.3, ppm, u0=-2.15, v0=-0.05, seed=7)
    F.chariot(F.Pen(R, rl.Xf(0.0, 0.0, 1.0, 1)))
    return R


DESIGNS = {
    "archer": lambda: archer(128),
    "chariot": lambda: chariot(128),
    "warrior256": lambda: warrior(256),
    "warrior128": lambda: warrior(128),
    "genie": lambda: genie(128),
    "lion": lambda: lion(256, "walk"),
    "lion_leap": lambda: lion(128, "leap"),
    "lion_dying": lambda: lion(128, "dying", arrows=[(-0.2, 0.84, -60), (0.05, 0.8, -70), (-0.45, 0.8, -50)]),
}
DESIGNS.update({"panel_" + k: v for k, v in PN.DESIGNS.items()})


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    for n in names or list(DESIGNS):
        t0 = time.time()
        R = DESIGNS[n]()
        maps = asy.ReliefMaps(R)
        fn = asy.relief_material(maps, emit_color=(1.0, 0.5, 0.2))
        asy.preview_png(R, fn, OUT / f"asy2d_{n}.png", scale=2 if R.ppm >= 200 else 3)
        print(f"{n}: {R.W}x{R.H} {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main(sys.argv[1:])
