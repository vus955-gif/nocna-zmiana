"""Voice audition for the owner: the same lines in every candidate voice.

Writes build/voice-samples/*.wav and index.html (players + notes, Polish).
Nothing is played here — the owner listens when they like. Heniek's samples
also come with a rough walkie-talkie preview (the game's radio bus does the
real one); the System's in levels 0, 1 and 2.
"""
import html

import numpy as np
import soundfile as sf

from download_voices import CANDIDATES
from kokoro_tts import SR, Kokoro
from system_fx import process
from voice_data import ROOT, load

OUT = ROOT / "build/voice-samples"
TEXT = {
    "heniek": "Kid? Heniek here. Leg's in plaster, but the radio works. The locker key's in the ticket booth, "
              "in the drawer. And listen: if something moves that shouldn't, don't argue with it.",
    "system": "Attention. The City Museum is now closed. Thank you for your visit. The security officer is "
              "reminded not to touch the exhibits. Including the ones that touch him.",
}


def radio(wav):
    """Rough preview only: 320-3200 Hz band and a soft clip."""
    spec = np.fft.rfft(wav)
    freq = np.fft.rfftfreq(len(wav), 1 / SR)
    spec[(freq < 320) | (freq > 3200)] = 0
    y = np.fft.irfft(spec, len(wav))
    return np.tanh(3.0 * y / max(float(np.abs(y).max()), 1e-6)) * 0.5


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").write_text("")          # Godot must not import the samples
    for old in list(OUT.glob("*.wav")) + list(OUT.glob("*.import")):
        old.unlink()
    tts = Kokoro(load().lexicon)
    rows = []
    for role, voices in CANDIDATES.items():
        for voice in voices:
            dry = tts.synth(TEXT[role], voice)
            takes = [("czysty", "czysty", dry)]
            if role == "heniek":
                takes.append(("radio", "radio (podgląd)", radio(dry)))
            else:
                for level in (1, 2):
                    takes.append((f"stopien{level}", f"stopień {level}", process(dry, SR, level, seed=7)))
            for slug, label, wav in takes:
                name = f"{role}_{voice}_{slug}.wav"
                sf.write(OUT / name, (0.9 * wav / max(float(np.abs(wav).max()), 1e-6)).astype(np.float32), SR,
                         subtype="PCM_16")
                rows.append((role, voice, label, name))
            print(role, voice)
    (OUT / "index.html").write_text(page(rows), encoding="utf-8")


def page(rows):
    def section(role, title, note):
        items = "".join(
            f'<tr><td><b>{html.escape(v)}</b></td><td>{html.escape(l)}</td>'
            f'<td><audio controls preload="none" src="{n}"></audio></td></tr>'
            for r, v, l, n in rows if r == role)
        return f"<h2>{title}</h2><p>{note}</p><table>{items}</table>"
    return f"""<!doctype html><html lang="pl"><head><meta charset="utf-8"><title>Głosy — próbki</title>
<style>body{{font:16px/1.6 Georgia,serif;max-width:860px;margin:40px auto;padding:0 16px;color:#222;background:#faf7f0}}
h1{{font-weight:normal}}h2{{margin-top:2em;border-bottom:1px solid #ccb}}table{{border-collapse:collapse;width:100%}}
td{{padding:6px 10px;border-bottom:1px solid #e4dfd2}}audio{{width:320px}}</style></head><body>
<h1>Nocna Zmiana — próbki głosów</h1>
<p>Te same zdania w każdym głosie-kandydacie. Wybierz jeden głos dla Heńka i jeden dla Systemu
(oraz stopień „maszynowości” Systemu na co dzień). Podgląd radia jest przybliżony — w grze robi go kanał dźwięku.
Nazwy głosów: <i>a</i> = akcent amerykański, <i>b</i> = brytyjski; <i>m</i> = męski, <i>f</i> = żeński.</p>
{section("heniek", "Heniek (krótkofalówka)", "„" + html.escape(TEXT["heniek"]) + "”")}
{section("system", "System — Wirtualny Kustosz", "„" + html.escape(TEXT["system"]) + "”")}
</body></html>"""


if __name__ == "__main__":
    main()
