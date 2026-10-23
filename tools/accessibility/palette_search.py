"""Search for the weapon palette of one colour-vision mode (plan 2026-10-21-dostepnosc, section 4).

    python palette_search.py [--window 35] [--seed 11] [--min-s 0.4] [--identity 1.0] [--slack 1.0]
                             [--modes deut,prot,trit] [--json out.json]

The palettes in the game (21.10/22.10): --window 30 --min-s 0.5 --identity 0.7, --slack 1.0
for deut and prot, --slack 0.05 for trit (its best separation is only just over the bar).

For deuteranopia, protanopia and tritanopia (Machado, Oliveira & Fernandes 2009,
severity 1.0, linear RGB; cvd.py) picks one colour per weapon that keeps:
- its hue within +-window degrees of the standard palette's (cvd.ORIG),
- its identity: of all the standard colours, the nearest to it (CIE76, normal
  vision) is its own weapon's, by a margin (its own at most --identity times as
  far as the nearest other one) - a box's print and its rim still agree,
- WCAG contrast >= 4.5 with the HUD's enamel, both seen normally and in the mode.
Score of a palette = the smallest distance of any two of its colours and the
white medkit, each pair's distance being min(dE in the mode, 0.8 * dE normal):
the mode's palette must stay apart for everybody else at the table too. Of the
palettes within --slack of the best score found, the one nearest the standard
colours wins (least summed dE to them, normal vision).
Simulated annealing with restarts over a grid of HSV candidates; numpy distance
tables make one run a few seconds. The result is typed into
src/style/colour_vision.gd and checked there by tests."""
import argparse, colorsys, json, math, random
import numpy as np
from cvd import ORIG, MEDKIT, ENAMEL, sim, lab, contrast

NAMES = list(ORIG.keys())


def hue_deg(rgb):
    return colorsys.rgb_to_hsv(*rgb)[0] * 360.0


def hue_dist(a, b):
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def candidates(min_s=0.4):
    out = []
    for h in range(0, 360, 2):
        for s in [x for x in (0.4, 0.5, 0.6, 0.7, 0.8, 0.9) if x >= min_s - 1e-9]:
            for v in (0.75, 0.85, 0.95, 1.0):
                out.append((h, s, v, tuple(round(x * 255) / 255 for x in colorsys.hsv_to_rgb(h / 360, s, v))))
    return out


def lab_table(colors, mode):
    return np.array([lab(sim(c, mode)) for c in colors])


def pair_table(labs):
    labs = labs.astype(np.float32)
    return np.linalg.norm(labs[:, None, :] - labs[None, :, :], axis=2)


def search(mode, window, seed, min_s=0.4, identity=1.0, slack=1.0, iters=20000, restarts=8):
    rng = random.Random(seed)
    cands = candidates(min_s)
    rgb = [c[3] for c in cands]
    lab_mode, lab_norm = lab_table(rgb, mode), lab_table(rgb, "norm")
    dist = np.minimum(pair_table(lab_mode), 0.8 * pair_table(lab_norm))
    med_mode = np.linalg.norm(lab_mode - lab(sim(MEDKIT, mode)), axis=1)
    med_norm = np.linalg.norm(lab_norm - lab(sim(MEDKIT, "norm")), axis=1)
    med = np.minimum(med_mode, 0.8 * med_norm)
    orig_lab = np.array([lab(ORIG[k]) for k in NAMES])
    to_orig = np.linalg.norm(lab_norm[:, None, :] - orig_lab[None, :, :], axis=2)
    allowed = []
    for w, name in enumerate(NAMES):
        h0 = hue_deg(ORIG[name])
        ok = [i for i, (h, s, v, c) in enumerate(cands)
              if hue_dist(h, h0) <= window and to_orig[i][w] <= identity * np.delete(to_orig[i], w).min()
              and contrast(c, ENAMEL, "norm") >= 4.5 and contrast(c, ENAMEL, mode) >= 4.5]
        if not ok:
            raise SystemExit("%s: no candidate in a %g degree window" % (name, window))
        allowed.append(ok)

    def score(sel):
        idx = np.array(sel)
        sub = dist[np.ix_(idx, idx)] + np.eye(len(idx)) * 1e9
        return float(min(sub.min(), med[idx].min()))

    best, best_sel = -1.0, None
    for _ in range(restarts):
        sel = [rng.choice(a) for a in allowed]
        cur = score(sel)
        temp = 6.0
        for _ in range(iters):
            k = rng.randrange(len(NAMES))
            trial = sel[:]
            trial[k] = rng.choice(allowed[k])
            s = score(trial)
            if s > cur or rng.random() < math.exp((s - cur) / temp):
                sel, cur = trial, s
            temp = max(0.05, temp * 0.9995)
            if cur > best:
                best, best_sel = cur, sel[:]
    # second pass: of the palettes within `slack` of the best separation, the one
    # nearest the standard colours (least summed drift, normal vision)
    floor = best - slack
    own = [to_orig[:, w] for w in range(len(NAMES))]

    def drift(sel):
        return float(sum(own[w][i] for w, i in enumerate(sel)))

    sel, cur = best_sel[:], drift(best_sel)
    kept, kept_drift = sel[:], cur
    temp = 4.0
    for _ in range(iters * 2):
        k = rng.randrange(len(NAMES))
        trial = sel[:]
        trial[k] = rng.choice(allowed[k])
        if score(trial) < floor:
            continue
        d = drift(trial)
        if d < cur or rng.random() < math.exp((cur - d) / temp):
            sel, cur = trial, d
        temp = max(0.05, temp * 0.9995)
        if cur < kept_drift:
            kept, kept_drift = sel[:], cur
    return score(kept), [cands[i] for i in kept]


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--window", type=float, default=35.0)
    ap.add_argument("--seed", type=int, default=11)
    ap.add_argument("--min-s", type=float, default=0.4)
    ap.add_argument("--identity", type=float, default=1.0)
    ap.add_argument("--slack", type=float, default=1.0)
    ap.add_argument("--modes", default="deut,prot,trit")
    ap.add_argument("--json", default="")
    args = ap.parse_args()
    found = {}
    for mode in args.modes.split(","):
        best, picked = search(mode, args.window, args.seed, args.min_s, args.identity, args.slack)
        print("%s window %g seed %d min s %.2f identity %.2f min score %.1f" % (mode, args.window, args.seed, args.min_s, args.identity, best))
        found[mode] = {"mode": mode, "colors": {}}
        for name, (h, s, v, c) in zip(NAMES, picked):
            code = "#%02x%02x%02x" % tuple(int(round(x * 255)) for x in c)
            found[mode]["colors"][name] = code
            print("   %-11s orig h %3d -> h %3d s %.2f v %.2f  %s" % (name, hue_deg(ORIG[name]), h, s, v, code))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(found, f, indent=1)
