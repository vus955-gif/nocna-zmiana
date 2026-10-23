"""HUD role colours per colour-vision mode (plan 2026-10-21-dostepnosc, section 4).

    python role_search.py [--target 40] [--window 30] [--seed 5]
    python role_search.py --peaks      the caffeine pulse's peak per mode (after the search)

Groups of colours that must read apart from each other on the HUD: the stamina
bar's fill, its exhausted red and the caffeinated cream; the fuse carried and
the fuse in the box; the crosshair's hit markers (plain hit white and blocked
grey are fixed, the weak point and the kill move); and the health bar alone
(it only has to stand out of its dark channel). For every mode (Machado et al.
2009, cvd.py) a group keeps its standard colours when they already reach
--target (distance of every pair = min(dE in the mode, 0.8 * dE normal)) and
the bars keep WCAG 3:1 with their channel (non-text contrast) seen in the mode;
otherwise its moving colours are searched within +-window degrees of their
standard hue, the best separation first, then the least drift from the
standard colours (normal vision) among those within 1 dE of it.
The result is typed into src/style/colour_vision.gd and checked there by tests."""
import argparse, colorsys, itertools, math, random
import numpy as np
from cvd import CHANNEL, sim, lab, contrast

STANDARD = {
    "health": (0.84, 0.17, 0.13),
    "stamina_fill": (0.95, 0.8, 0.3),
    "stamina_exhausted": (1.0, 0.43, 0.33),
    "stamina_caffeine": (0.96, 0.89, 0.72),
    "fuse_carried": (1.0, 0.72, 0.35),
    "fuse_inserted": (0.35, 1.0, 0.5),
    "hit": (1.0, 1.0, 1.0),
    "hit_weak_point": (1.0, 0.8, 0.2),
    "hit_kill": (1.0, 0.25, 0.2),
    "hit_blocked": (0.6, 0.6, 0.6),
}
# group -> (moving roles, fixed roles, roles that are bar fills on the channel)
GROUPS = {
    "health": (["health"], [], ["health"]),
    "stamina": (["stamina_fill", "stamina_exhausted", "stamina_caffeine"], [], ["stamina_fill", "stamina_exhausted", "stamina_caffeine"]),
    "fuses": (["fuse_carried", "fuse_inserted"], [], []),
    "markers": (["hit_weak_point", "hit_kill"], ["hit", "hit_blocked"], []),
}
MODES = ("deut", "prot", "trit")
BAR_CONTRAST = 3.0
SINGLE_TARGET = 3.5   # the health bar: contrast with its channel, a little over the 3:1 bar


def hexed(c):
    return "#%02x%02x%02x" % tuple(int(round(x * 255)) for x in c)


def pair(a, b, mode):
    la, lb = lab(sim(a, mode)), lab(sim(b, mode))
    na, nb = lab(a), lab(b)
    return min(float(np.linalg.norm(la - lb)), 0.8 * float(np.linalg.norm(na - nb)))


def group_score(colors, mode, n_moving=None):
    """Smallest pair distance; with n_moving, only pairs with one of the first
    n_moving colours in them (two fixed colours are not ours to part)."""
    n = len(colors) if n_moving is None else n_moving
    return min((pair(colors[i], colors[j], mode) for i, j in itertools.combinations(range(len(colors)), 2) if i < n),
               default=1e9)


def bars_ok(named, bars, mode):
    return all(contrast(named[r], CHANNEL, mode) >= BAR_CONTRAST and contrast(named[r], CHANNEL, "norm") >= BAR_CONTRAST for r in bars)


def candidates(role, window):
    h0, s0, v0 = colorsys.rgb_to_hsv(*STANDARD[role])
    out = []
    for dh in range(-int(window), int(window) + 1, 3):
        for s in (0.15, 0.25, 0.35, 0.5, 0.65, 0.8, 0.9):
            for v in (0.7, 0.8, 0.9, 1.0):
                out.append(tuple(round(x * 255) / 255 for x in colorsys.hsv_to_rgb(((h0 * 360 + dh) % 360) / 360, s, v)))
    return out


def drift(named, roles):
    return sum(float(np.linalg.norm(lab(named[r]) - lab(STANDARD[r]))) for r in roles)


def solve(group, mode, target, window, rng, iters=6000):
    moving, fixed, bars = GROUPS[group]
    named = dict(STANDARD)
    if group == "health":
        if contrast(STANDARD["health"], CHANNEL, mode) >= SINGLE_TARGET:
            return {}, contrast(STANDARD["health"], CHANNEL, mode)
        ok = [c for c in candidates("health", 20) if contrast(c, CHANNEL, mode) >= SINGLE_TARGET and contrast(c, CHANNEL, "norm") >= SINGLE_TARGET]
        best = min(ok, key=lambda c: float(np.linalg.norm(lab(c) - lab(STANDARD["health"]))))
        return {"health": best}, contrast(best, CHANNEL, mode)
    members = moving + fixed
    if group_score([STANDARD[r] for r in members], mode, len(moving)) >= target and bars_ok(named, bars, mode):
        return {}, group_score([STANDARD[r] for r in members], mode, len(moving))
    pools = {r: candidates(r, window) for r in moving}

    def score(choice):
        trial = dict(named)
        trial.update(choice)
        if not bars_ok(trial, bars, mode):
            return -1.0
        return group_score([trial[r] for r in members], mode, len(moving))

    cur = {r: STANDARD[r] for r in moving}
    cur_s = score(cur)
    best, best_s = dict(cur), cur_s
    temp = 5.0
    for _ in range(iters):
        r = rng.choice(moving)
        trial = dict(cur)
        trial[r] = rng.choice(pools[r])
        s = score(trial)
        if s > cur_s or rng.random() < math.exp((s - cur_s) / temp):
            cur, cur_s = trial, s
        temp = max(0.05, temp * 0.999)
        if cur_s > best_s:
            best, best_s = dict(cur), cur_s
    # the least drift among the near-best (never below the target when the best reached it)
    floor = target if best_s >= target else best_s - 0.5
    cur, cur_d = dict(best), drift({**named, **best}, moving)
    kept, kept_d = dict(cur), cur_d
    temp = 4.0
    for _ in range(iters * 2):
        r = rng.choice(moving)
        trial = dict(cur)
        trial[r] = rng.choice(pools[r])
        if score(trial) < floor:
            continue
        d = drift({**named, **trial}, moving)
        if d < cur_d or rng.random() < math.exp((cur_d - d) / temp):
            cur, cur_d = trial, d
        temp = max(0.05, temp * 0.999)
        if cur_d < kept_d:
            kept, kept_d = dict(cur), cur_d
    return {r: kept[r] for r in moving if kept[r] != STANDARD[r]}, score(kept)


# The stamina bar's caffeinated fill pulses between the caffeine colour and its
# peak: every point of that swing must keep the target from the plain fill and
# from exhaustion. The peak is the caffeine 55 % of the way to white unless that
# fails; then a peak near the caffeine's hue, 8..20 dE from it in the mode.
CHOSEN = {
    "deut": {"stamina_fill": "#ffd959", "stamina_exhausted": "#cc4129", "stamina_caffeine": "#e6e2c3"},
    "prot": {"stamina_fill": "#ffd959", "stamina_exhausted": "#ff7259", "stamina_caffeine": "#fff8d9"},
    "trit": {"stamina_fill": "#e9ff80", "stamina_exhausted": "#e6522e", "stamina_caffeine": "#e6aa95"},
}


def unhex(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) / 255 for i in (0, 2, 4))


def pulse_score(caf, peak, fill, exh, mode):
    """Least distance of any point of the pulse from the fill and from
    exhaustion, in the mode and normally (both must reach the target)."""
    from cvd import de
    worst = 1e9
    for k in range(11):
        tone = tuple(a + (b - a) * k / 10 for a, b in zip(caf, peak))
        for other in (fill, exh):
            worst = min(worst, de(tone, other, mode), de(tone, other, "norm"))
    return worst


def peaks(target):
    for mode, roles in CHOSEN.items():
        fill, exh, caf = (unhex(roles[k]) for k in ("stamina_fill", "stamina_exhausted", "stamina_caffeine"))
        white = tuple(round((c + (1 - c) * 0.55) * 255) / 255 for c in caf)
        if pulse_score(caf, white, fill, exh, mode) >= target:
            print("%s peak %s (55 %% to white) %.1f" % (mode, hexed(white), pulse_score(caf, white, fill, exh, mode)))
            continue
        h0 = colorsys.rgb_to_hsv(*caf)[0] * 360
        best = None
        for dh in range(-20, 21, 2):
            for s in np.arange(0.1, 0.9, 0.04):
                for v in np.arange(0.7, 1.001, 0.02):
                    c = tuple(round(x * 255) / 255 for x in colorsys.hsv_to_rgb(((h0 + dh) % 360) / 360, s, v))
                    from cvd import de, lum
                    if not 8 <= de(caf, c, mode) <= 20 or lum(c) <= lum(caf):
                        continue
                    if contrast(c, CHANNEL, mode) < BAR_CONTRAST or contrast(c, CHANNEL, "norm") < BAR_CONTRAST:
                        continue
                    score = pulse_score(caf, c, fill, exh, mode)
                    if best is None or score > best[0]:
                        best = (score, c)
        print("%s peak %s (55 %% to white fails: %.1f) -> %s %.1f" % (mode, hexed(white), pulse_score(caf, white, fill, exh, mode), hexed(best[1]), best[0]))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", type=float, default=40.0)
    ap.add_argument("--window", type=float, default=30.0)
    ap.add_argument("--seed", type=int, default=5)
    ap.add_argument("--peaks", action="store_true")
    args = ap.parse_args()
    if args.peaks:
        peaks(args.target)
        raise SystemExit(0)
    rng = random.Random(args.seed)
    for mode in MODES:
        print(mode)
        for group in GROUPS:
            changed, s = solve(group, mode, args.target, args.window, rng)
            moving, fixed, bars = GROUPS[group]
            std = contrast(STANDARD["health"], CHANNEL, mode) if group == "health" else group_score([STANDARD[r] for r in moving + fixed], mode, len(moving))
            print("  %-8s standard %5.1f -> %5.1f  %s" % (group, std, s, " ".join("%s=%s" % (r, hexed(c)) for r, c in changed.items()) or "(standard kept)"))
