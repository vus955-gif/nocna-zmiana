# Głos — etap G1: szkielet (narzędzia, reżyser, kanały, napisy, zapis, rekwizyty)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> Plan wykonawczy. Wykonawca: jeden agent w worktree `voice-g1` (gałąź `voice-g1` od `pietro-1`), **równolegle** z dokańczaniem skrzydeł — pliki rozłączne (wyjątki niżej: `locale/strings.csv`, `world_features.gd`, `court.gd`, `egypt.gd`, `tests/test_runner.gd` — dopisywanie na końcu, konflikty scalać jako sumę).
> Projekt: `docs/superpowers/specs/2026-10-08-glos-projekt.md` (§1–§7). Treść kwestii (G2) — osobny plan po ukończeniu skrzydeł.
> **Bez okien i bez dźwięku** (właściciel pracuje przy komputerze): tylko `--headless`, `blender -b`, skrypty. Niczego nie odtwarzać. Próbki głosów zapisać do plików — właściciel odsłucha sam.
> Nic nie trafia na GitHub. Commity tylko lokalnie.

**Cel:** gra potrafi mówić: Heniek przez krótkofalówkę i System z głośników oraz przy stojaku audioprzewodnika, z napisami w języku gry, wyciszaniem muzyki pod mową, zapamiętywaniem wysłuchanych kwestii i opcjami „Głosy” / „Napisy”; nagrania powstają skryptem z Kokoro-82M; właściciel dostaje próbki głosów do wyboru.

**Architektura:** Python (osobne środowisko na D:) generuje suche nagrania Kokoro, System dostaje obróbkę offline (pyworld: spłaszczona, schodkowa intonacja, 3 stopnie), Blender koduje Ogg jak resztę dźwięku. W grze autoload `VoiceDirector` słucha wyłącznie `Events`, reguły kwestii są danymi (`data/voice/*.json`), kolejka (`VoiceQueue`) i dopasowanie reguł (`VoiceRules`) to czysta logika testowana bez dźwięku; akustykę (radio, głośniki 3D, pogłos stref) robi silnik.

**Tech Stack:** Godot 4.7.2 / GDScript, własny runner testów (`tools/run_tests.sh`); Python 3.11 (uv) + kokoro-onnx 0.6.1 + onnxruntime + pyworld; Blender 5.1 (`aud`) do Ogg; Blender do modeli.

---

## Kontrakt i decyzje (wspólne dla wszystkich zadań)

### Pliki

| Plik | Odpowiedzialność |
|---|---|
| `tools/tts/setup.sh` | jednorazowa instalacja na D: (venv, model, głosy, pyworld) |
| `tools/tts/download_voices.py` | pobranie plików głosów z onnx-community (lista kandydatów) |
| `tools/tts/kokoro_tts.py` | tekst EN → 24 kHz mono float32 (Kokoro ONNX fp16), słowniczek wymowy |
| `tools/tts/system_fx.py` | obróbka głosu Systemu, stopnie 0/1/2, deterministyczna |
| `tools/tts/voice_data.py` | odczyt `strings.csv` + `data/voice/*.json`, skrót kwestii |
| `tools/tts/generate_voice.py` | kwestie → `build/audio_src/voice/<mówiący>/<klucz>.wav` + `assets/voice/manifest.json` |
| `tools/tts/voice_samples.py` | próbki głosów dla właściciela → `build/voice-samples/` + `index.html` |
| `tools/tts/test_tts.py`, `tools/tts/test_system_fx.py`, `tools/tts/test_voice_data.py` | testy Pythona (`unittest`) |
| `tools/tts/build_voice.sh` | cały proces: generowanie → kodowanie Ogg → import Godota |
| `tools/music/encode_ogg.py` | (zmiana) tryb `-- voice` |
| `data/voice/lines.json` | kwestie: kto, kiedy, priorytet, stopień obróbki |
| `data/voice/speakers.json` | mówiący → głos Kokoro, tempo; `fx_version` |
| `data/voice/lexicon.json` | wymowa polskich nazw (IPA) |
| `assets/voice/<mówiący>/<klucz>.ogg`, `assets/voice/manifest.json` | wygenerowane nagrania (w repo) |
| `src/audio/voice/voice_catalog.gd` | `VoiceCatalog`: dane kwestii, ścieżki nagrań, skrót |
| `src/audio/voice/voice_rules.gd` | `VoiceRules`: czy reguła pasuje do zdarzenia |
| `src/audio/voice/voice_queue.gd` | `VoiceQueue`: kto mówi następny i kiedy |
| `src/audio/voice/voice_director.gd` | autoload `VoiceDirector`: zdarzenia → kolejka → kanały, ducking, zapis |
| `src/ui/subtitle_bar.gd` | `SubtitleBar`: napisy |
| `src/props/loudspeaker.gd`, `src/props/audioguide_stand.gd` | rekwizyty |
| `tools/art/models/loudspeaker.py`, `tools/art/models/audioguide_stand.py` | modele Blendera |

### Format danych

`data/voice/speakers.json`:
```json
{
  "fx_version": 1,
  "speakers": {
    "heniek": {"voice": "am_michael", "speed": 1.0},
    "system": {"voice": "bf_emma", "speed": 0.95}
  }
}
```
Głosy są **tymczasowe**, do czasu wyboru właściciela (zadanie 6). Akcent wynika z prefiksu głosu (`a…` en-us, `b…` en-gb).

`data/voice/lines.json` — klucz = klucz tekstu w `locale/strings.csv`:
```json
{
  "lines": {
    "VO_HENIEK_NIGHT_1":   {"speaker": "heniek", "event": "night_started", "night": 1, "priority": 2},
    "VO_SYSTEM_CLOSING_1": {"speaker": "system", "level": 0, "event": "night_started", "night_min": 1, "delay": 20, "priority": 1},
    "VO_GUIDE_ROSETTA_A":  {"speaker": "system", "level": 0, "station": "rosetta", "variant": "a", "once": false},
    "VO_GUIDE_ROSETTA_B":  {"speaker": "system", "level": 2, "station": "rosetta", "variant": "b", "after_guardian": "colossus", "once": false}
  }
}
```
Pola reguły: `speaker` (`heniek`|`system`), `event` (niżej), warunki `night`, `night_min`, `zone`, `guardian`, `count`, `goal`, `at` (s od startu nocy, dla `night_time`), `delay` (s przed wejściem do kolejki), `priority` (0 uwaga poboczna, 1 zwykła, 2 wydarzenie; domyślnie 1), `once` (domyślnie `true`), `level` (obróbka Systemu 0–2, domyślnie 0), `speed` (nadpisuje tempo mówiącego). Stanowisko przewodnika: `station`, `variant` (`a`|`b`), dla `b` warunek `after_guardian` albo `after_witching: true`.
Kanał wynika z danych: `heniek` → `radio`; `system` z `station` → `guide`; `system` bez `station` → `pa`.

Zdarzenia: sygnały `Events` — `night_started`, `power_cut`, `witching_hour`, `dawn_broke`, `room_entered` (tylko `first_visit`), `guardian_awakened`, `guardian_defeated`, `shard_collected`, `seal_collected`, `gate_opened`, `boss_awakened`, `boss_defeated` — oraz pseudo-zdarzenia reżysera: `death` (komentarz po śmierci, na początku następnej nocy, na zmianę Heniek/System, najwyżej raz na noc), `destroyed` (próg liczby zniszczonych eksponatów, `count`), `stall` (zastój, `goal`), `night_time` (`at`).

**Skrót kwestii** (Python i GDScript liczą identycznie): SHA-256 z UTF-8 napisu
`"<voice>|<speed z 3 miejscami po przecinku>|<level>|<fx_version>|<tekst EN>"` → hex małymi literami.
Python: `f"{voice}|{speed:.3f}|{level}|{fx_version}|{text}"`; GDScript: `"%s|%.3f|%d|%d|%s" % [voice, speed, level, fx_version, text]`.
`assets/voice/manifest.json`: `{"<klucz>": {"hash": "…", "speaker": "heniek", "seconds": 6.21}, …}`.

Teksty `VO_*` są **jednowierszowe** (bez `\n`) i mają co najmniej 20 znaków EN (Kokoro słabo radzi sobie z bardzo krótkimi wypowiedziami).

### Kanały dźwięku (`default_bus_layout.tres`)
- Music (2) i Ambience (3): efekt `AudioEffectAmplify` o `resource_name = "VoiceDuck"` (0 dB) — **ducking tylko przez ten efekt**; głośności kanałów należą do `Settings`.
- 14 `Voice` → Master (suwak „Głosy”, `volume_voice`).
- 15 `VoiceRadio` → Voice: HighPass 320 Hz, LowPass 3200 Hz, Distortion (overdrive, drive 0,18), Compressor (−18 dB, 4:1).
- 16 `VoiceSystem` → Voice (bez efektów; pogłos ze stref przez `area_mask` odtwarzaczy 3D). Pogłos głosu idzie wysyłką strefy do `SFXReturn` (jak efekty) — świadomy kompromis.

### Liczby startowe (do strojenia w teście właściciela)
Spokój 4 s; kwestia wydarzenia czeka na spokój najwyżej 10 s; uwaga poboczna przepada po 60 s; 180 s między uwagami pobocznymi; 20 s ciszy po każdej kwestii; zastój 360 s, podpowiedź najwyżej co 600 s; ducking Music −6 dB, Ambience −4 dB, wejście 0,25 s, powrót 0,8 s; głośniki: do 3 najbliższych w 45 m, przesunięcie = różnica odległości / 343 m/s; brak głośnika w zasięgu → odtwarzacz 2D −6 dB; przewodnik gaśnie powyżej 12 m.

### Teksty startowe (zadanie 4)

| Klucz | PL (napis) | EN (synteza i napis) |
|---|---|---|
| `VO_HENIEK_NIGHT_1` | Młody? Tu Heniek. Noga w gipsie, ale radio działa. Klucz do szafki jest w kasie, w szufladzie. I słuchaj: jak coś się rusza, a nie powinno, nie dyskutuj z tym. | Kid? Heniek here. Leg's in plaster, but the radio works. The locker key's in the ticket booth, in the drawer. And listen: if something moves that shouldn't, don't argue with it. |
| `VO_SYSTEM_CLOSING_1` | Uwaga. Muzeum Miejskie jest zamknięte. Dziękujemy za wizytę. Pracownik ochrony proszony jest o niedotykanie eksponatów. Także tych, które dotykają jego. | Attention. The City Museum is now closed. Thank you for your visit. The security officer is reminded not to touch the exhibits. Including the ones that touch him. |
| `VO_GUIDE_ROSETTA_A` | Stanowisko pierwsze. Kamień z Rosetty, rok sto dziewięćdziesiąty szósty przed naszą erą. Ten sam dekret zapisano trzy razy: hieroglifami, pismem demotycznym i po grecku. Dzięki greckiemu tekstowi Jean-François Champollion odczytał hieroglify w tysiąc osiemset dwudziestym drugim roku. | Stop one. The Rosetta Stone, 196 BC. The same decree is written three times: in hieroglyphs, in Demotic script, and in Greek. Thanks to the Greek text, Jean-François Champollion deciphered the hieroglyphs in 1822. |
| `VO_GUIDE_ROSETTA_B` | Stanowisko pierwsze. Kamień z Rosetty. Ten sam tekst zapisano trzy razy, bo za pierwszym razem nikt nie słuchał. Za drugim też nie. Proszę nie stać tak blisko. Kamień nie lubi, kiedy się go czyta po zmroku. | Stop one. The Rosetta Stone. The same text was written three times, because the first time no one listened. Nor the second. Please do not stand so close. The stone does not like being read after dark. |

Pozostałe nowe klucze: `OPT_VOLUME_VOICE` (Głosy / Voices), `OPT_SUBTITLES` (Napisy / Subtitles), `PROMPT_AUDIOGUIDE` (Posłuchaj audioprzewodnika / Listen to the audio guide), `VOICE_SPEAKER_HENIEK` (Heniek · radio / Heniek · radio), `VOICE_SPEAKER_SYSTEM` (Wirtualny Kustosz / Virtual Curator), `VOICE_SPEAKER_GUIDE` (Audioprzewodnik / Audio guide).

---

## Zadania

### Task 1: Narzędzia na D: (środowisko, model, głosy, pyworld)

**Files:**
- Create: `tools/tts/setup.sh`, `tools/tts/download_voices.py`
- Modify: `.gitignore`

Źródło modelu i pakietów (sprawdzona wcześniej sesja, 7.10): lokalny folder `neuron-spike/` z gotowym środowiskiem Kokoro (`.venv-tts` na Pythonie 3.11.14 z uv: kokoro-onnx 0.6.1, onnxruntime 1.30, espeakng_loader 0.2.4, phonemizer 3.4, soundfile 0.14, numpy 2.4.6; `models/model_fp16.onnx` 163 234 774 B, `models/af_heart.bin`). Folder `tools/` ma `.gdignore` — Godot go nie skanuje.

- [x] **Step 1: `.gitignore`** — dopisz:
```
/tools/tts/.venv/
/tools/tts/.uv-cache/
/tools/tts/models/
```

- [x] **Step 2: `tools/tts/download_voices.py`**
```python
"""Fetches Kokoro voice styles (510 x 256 float32 = 522 240 bytes each) from the
official ONNX export into tools/tts/models/voices/. Already present = skipped."""
import sys
import urllib.request
from pathlib import Path

URL = "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/voices/{}.bin"
SIZE = 522240
DST = Path(__file__).resolve().parent / "models" / "voices"
# audition candidates per role (docs/superpowers/specs/2026-10-08-glos-projekt.md §5.4)
CANDIDATES = {
    "heniek": ["am_michael", "am_fenrir", "am_puck", "bm_george", "bm_fable", "bm_lewis"],
    "system": ["af_heart", "af_bella", "af_nicole", "bf_emma", "bf_isabella"],
}


def fetch(names):
    DST.mkdir(parents=True, exist_ok=True)
    for name in names:
        path = DST / f"{name}.bin"
        if path.exists() and path.stat().st_size == SIZE:
            continue
        data = urllib.request.urlopen(URL.format(name), timeout=60).read()
        if len(data) != SIZE:
            raise SystemExit(f"{name}: {len(data)} bytes, expected {SIZE}")
        path.write_bytes(data)
        print("voice", name)


if __name__ == "__main__":
    fetch(sys.argv[1:] or sorted({v for vs in CANDIDATES.values() for v in vs}))
```

- [x] **Step 3: `tools/tts/setup.sh`**
```bash
#!/usr/bin/env bash
# One-time setup of the voice tools, all on D: (tools/tts/, gitignored):
# Python 3.11 venv with the packages of the earlier Kokoro session (copied, no
# download), the Kokoro ONNX model, the candidate voices and pyworld (built
# locally: PyPI has no Windows wheel for Python 3.11; VS Build Tools 2022 are installed).
#   bash tools/tts/setup.sh /path/to/neuron-spike
set -euo pipefail
cd "$(dirname "$0")"
FROM="${1:?folder of the earlier session (has .venv-tts and models/)}"
export UV_CACHE_DIR="$PWD/.uv-cache"
PY=.venv/Scripts/python.exe
[ -x "$PY" ] || uv venv .venv --python 3.11
cp -rn "$FROM/.venv-tts/Lib/site-packages/." .venv/Lib/site-packages/
mkdir -p models/voices
[ -f models/model_fp16.onnx ] || cp "$FROM/models/model_fp16.onnx" models/
[ -f models/voices/af_heart.bin ] || cp "$FROM/models/af_heart.bin" models/voices/
"$PY" download_voices.py
"$PY" -c "import pyworld" 2>/dev/null || {
	uv pip install --python "$PY" cython setuptools wheel
	uv pip install --python "$PY" --no-build-isolation pyworld==0.3.6
}
"$PY" -c "import kokoro_onnx, onnxruntime, espeakng_loader, soundfile, pyworld, numpy; print('tts ok')"
```

- [x] **Step 4: Uruchom** `bash tools/tts/setup.sh "<ścieżka neuron-spike z góry>"`.
Oczekiwane: na końcu `tts ok`; `ls tools/tts/models/voices` → 11 plików `.bin` po 522 240 B; `du -sh tools/tts/models` ≈ 170 MB.
**Jeśli kompilacja pyworld się nie uda:** zatrzymaj zadanie i zgłoś kontrolerowi treść błędu (nie instaluj nic na C:, nie szukaj obejść na własną rękę — awaryjna ścieżka to własne PSOLA w numpy, decyzja kontrolera).

- [x] **Step 5: Commit**
```bash
git add .gitignore tools/tts/setup.sh tools/tts/download_voices.py
git commit -m "Voice tools: one-time setup on D: (Kokoro ONNX from the earlier session, candidate voices, pyworld)"
```

### Task 2: `kokoro_tts.py` — tekst → nagranie

**Files:**
- Create: `tools/tts/kokoro_tts.py`, `tools/tts/test_tts.py`

- [x] **Step 1: Test** `tools/tts/test_tts.py`
```python
import unittest

import numpy as np

from kokoro_tts import SR, Kokoro, lang_of


class KokoroTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tts = Kokoro({"Heniek": "hˈɛnjɛk"})

    def test_a_sentence_is_a_plausible_recording(self):
        wav = self.tts.synth("The museum is now closed. Thank you for your visit.", "af_heart")
        self.assertTrue(1.5 < len(wav) / SR < 7.0, len(wav) / SR)
        rms = float(np.sqrt(np.mean(wav ** 2)))
        self.assertTrue(0.01 < rms < 0.3, rms)
        self.assertTrue(np.isfinite(wav).all())

    def test_a_lexicon_word_is_spoken_from_its_ipa(self):
        self.assertIn("hˈɛnjɛk", self.tts.phonemes("Heniek here.", "en-gb"))

    def test_the_accent_follows_the_voice(self):
        self.assertEqual(lang_of("bm_george"), "en-gb")
        self.assertEqual(lang_of("af_heart"), "en-us")

    def test_long_text_is_split_into_chunks_not_cut(self):
        text = " ".join(["The same decree is written three times, in three scripts."] * 8)
        wav = self.tts.synth(text, "af_heart")
        self.assertGreater(len(wav) / SR, 15.0)

    def test_unknown_lexicon_symbols_are_refused(self):
        with self.assertRaises(ValueError):
            Kokoro({"Zawilski": "zaˈvʲilskʲi\u2603"})


if __name__ == "__main__":
    unittest.main()
```

- [x] **Step 2: Uruchom — ma się nie udać** (brak modułu): `cd tools/tts && .venv/Scripts/python.exe -m unittest test_tts -v` → `ModuleNotFoundError: No module named 'kokoro_tts'`.

- [x] **Step 3: `tools/tts/kokoro_tts.py`**
```python
"""Kokoro-82M (ONNX fp16), offline on the CPU: English text -> 24 kHz mono float32.

Runs in tools/tts/.venv (tools/tts/setup.sh). Same call as the earlier narration
session that proved this model: espeak-ng phonemes (kokoro_onnx's tokenizer),
the style row picked by the phoneme count, and a tiny speed nudge when the fp16
graph returns NaN for a given (text, speed) pair. Polish names come from a
lexicon (word -> IPA) because the ONNX path has no "[word](/IPA/)" markup.
"""
import os
import re
import shutil
import tempfile
from pathlib import Path

import espeakng_loader
import numpy as np
import onnxruntime as ort
from kokoro_onnx.config import EspeakConfig
from kokoro_onnx.tokenizer import Tokenizer

HERE = Path(__file__).resolve().parent
MODEL = HERE / "models" / "model_fp16.onnx"
VOICES = HERE / "models" / "voices"
SR = 24000
MAX_PHONEMES = 500       # the style table has 510 rows
CHUNK_PHONEMES = 300     # sentences are grouped up to about this many phonemes
SENTENCE_GAP = 0.22      # s of silence between grouped chunks
SENTENCE = re.compile(r"(?<=[.!?…])\s+")
NUDGES = (0, .005, -.005, .01, -.01, .015, -.015, .02, -.02)


def lang_of(voice):
    """Kokoro voices are trained per accent: a* = American, b* = British."""
    return {"a": "en-us", "b": "en-gb"}[voice[0]]


def _espeak_data():
    """espeak-ng keeps its data path in a ~230-char buffer: a long path is mirrored to a short one."""
    src = espeakng_loader.get_data_path()
    if len(src) < 180:
        return src
    dst = os.path.join(tempfile.gettempdir(), "kokoro-espeak-en")
    if not os.path.exists(os.path.join(dst, "en_dict")):
        os.makedirs(dst, exist_ok=True)
        for f in ("phontab", "phonindex", "phondata", "intonations", "en_dict"):
            shutil.copy2(os.path.join(src, f), dst)
        shutil.copytree(os.path.join(src, "lang"), os.path.join(dst, "lang"), dirs_exist_ok=True)
    return dst


class Kokoro:
    def __init__(self, lexicon=None):
        self.sess = ort.InferenceSession(str(MODEL), providers=["CPUExecutionProvider"])
        self.tok = Tokenizer(EspeakConfig(lib_path=espeakng_loader.get_library_path(), data_path=_espeak_data()))
        self.vocab = self.tok.vocab
        self.lexicon = dict(lexicon or {})
        bad = {w: [c for c in ipa if c not in self.vocab] for w, ipa in self.lexicon.items()}
        bad = {w: cs for w, cs in bad.items() if cs}
        if bad:
            raise ValueError(f"lexicon symbols the model does not know: {bad}")
        words = sorted(self.lexicon, key=len, reverse=True)
        self._lex = re.compile(r"\b(" + "|".join(map(re.escape, words)) + r")\b") if words else None
        self._styles = {}

    def style(self, voice):
        if voice not in self._styles:
            self._styles[voice] = np.fromfile(VOICES / f"{voice}.bin", dtype=np.float32).reshape(-1, 1, 256)
        return self._styles[voice]

    def phonemes(self, text, lang):
        """espeak phonemes; lexicon words are swapped for their IPA."""
        if self._lex is None:
            return self.tok.phonemize(text, lang)
        out, pos = [], 0
        for m in self._lex.finditer(text):
            if m.start() > pos:
                out.append(self.tok.phonemize(text[pos:m.start()], lang))
            out.append(self.lexicon[m.group(1)])
            pos = m.end()
        if pos < len(text):
            out.append(self.tok.phonemize(text[pos:], lang))
        return " ".join(p.strip() for p in out if p.strip())

    def ids(self, text, lang):
        return [self.vocab[c] for c in self.phonemes(text, lang) if c in self.vocab]

    def _run(self, ids, voice, speed):
        style = self.style(voice)[len(ids)].astype(np.float32)
        for nudge in NUDGES:
            out = self.sess.run(None, {"input_ids": np.array([[0, *ids, 0]], dtype=np.int64),
                                       "style": style,
                                       "speed": np.array([speed + nudge], dtype=np.float32)})
            wav = np.asarray(out[0], dtype=np.float32).reshape(-1)
            if np.isfinite(wav).all():
                return wav
        raise RuntimeError("the fp16 graph returned NaN for every speed nudge")

    def synth(self, text, voice, speed=1.0):
        """A whole line: sentences grouped into chunks the model handles well, joined by short gaps."""
        lang = lang_of(voice)
        groups, cur = [], ""
        for sentence in SENTENCE.split(text.strip()):
            trial = f"{cur} {sentence}".strip()
            if cur and len(self.ids(trial, lang)) > CHUNK_PHONEMES:
                groups.append(cur)
                cur = sentence
            else:
                cur = trial
        groups.append(cur)
        gap = np.zeros(int(SENTENCE_GAP * SR), dtype=np.float32)
        parts = []
        for i, group in enumerate(groups):
            ids = self.ids(group, lang)
            if len(ids) > MAX_PHONEMES:
                raise ValueError(f"one sentence is too long for Kokoro ({len(ids)} phonemes): {group[:60]}")
            if i:
                parts.append(gap)
            parts.append(self._run(ids, voice, speed))
        return np.concatenate(parts)
```

- [x] **Step 4: Uruchom testy** → `OK` (5 testów). Jeśli `test_a_lexicon_word_is_spoken_from_its_ipa` nie przechodzi, bo któryś symbol IPA nie istnieje w `vocab`, zmień zapis w teście na symbole ze słownika modelu (wydrukuj `sorted(tts.vocab)`).

- [x] **Step 5: Commit** `git add tools/tts/kokoro_tts.py tools/tts/test_tts.py && git commit -m "Voice tools: Kokoro ONNX synthesis with a pronunciation lexicon"`

### Task 3: `system_fx.py` — maszynowy głos Systemu

**Files:**
- Create: `tools/tts/system_fx.py`, `tools/tts/test_system_fx.py`

- [x] **Step 1: Test** `tools/tts/test_system_fx.py`
```python
import unittest

import numpy as np
import pyworld as pw

from system_fx import process

SR = 24000


def vowel(seconds=1.6):
    """A sung 'aa' whose pitch glides +-60 Hz around 170 Hz — speech-like movement."""
    t = np.arange(int(SR * seconds)) / SR
    f0 = 170 + 60 * np.sin(2 * np.pi * 0.8 * t)
    phase = 2 * np.pi * np.cumsum(f0) / SR
    x = sum(np.sin(k * phase) / k for k in range(1, 20))
    return (0.2 * x / np.abs(x).max()).astype(np.float32)


def spread(wav):
    """Standard deviation of the pitch in semitones (voiced frames only)."""
    f0, _ = pw.harvest(wav.astype(np.float64), SR, frame_period=5.0)
    v = f0[f0 > 0]
    return float(np.std(12 * np.log2(v / np.median(v))))


class SystemFxTest(unittest.TestCase):
    def test_level_0_leaves_the_voice_alone(self):
        x = vowel()
        self.assertTrue(np.array_equal(process(x, SR, 0, seed=1), x))

    def test_level_1_flattens_the_intonation(self):
        x = vowel()
        self.assertLess(spread(process(x, SR, 1, seed=1)), 0.5 * spread(x))

    def test_the_same_seed_gives_the_same_file(self):
        x = vowel()
        self.assertTrue(np.array_equal(process(x, SR, 2, seed=7), process(x, SR, 2, seed=7)))

    def test_level_2_is_broken_differently_from_level_1(self):
        x = vowel()
        a, b = process(x, SR, 1, seed=7), process(x, SR, 2, seed=7)
        self.assertFalse(len(a) == len(b) and np.allclose(a, b))
        self.assertLess(len(b), 1.5 * len(x))


if __name__ == "__main__":
    unittest.main()
```

- [x] **Step 2: Uruchom — ma się nie udać** (`No module named 'system_fx'`).

- [x] **Step 3: `tools/tts/system_fx.py`**
```python
"""The System's voice: Kokoro's dry take made machine-like (offline, deterministic).

Level 0 = untouched. Level 1 = machine: the pitch movement is squashed toward
the line's median and snapped to whole semitones (the flat, stepped announcer
intonation) plus a faint metallic comb. Level 2 = broken: level 1, then seeded
glitches — pitch jumps on a few syllables, stutters at quiet points, short
dropouts. pyworld (the WORLD vocoder) splits the voice into pitch, spectral
envelope and aperiodicity, so the pitch changes without touching the timbre.
"""
import numpy as np
import pyworld as pw

FRAME_MS = 5.0
SQUASH = {1: 0.25, 2: 0.35}      # share of the original pitch movement that survives
COMB_MS, COMB_MIX = 1.6, 0.12
JUMPS = (-7, -5, 3, 5, 7)        # semitones of a level-2 pitch jump


def flatten_pitch(f0, level, rng):
    voiced = f0 > 0
    if not voiced.any():
        return f0
    ref = float(np.median(f0[voiced]))
    semis = np.round(12.0 * np.log2(f0[voiced] / ref) * SQUASH[level])
    out = f0.copy()
    out[voiced] = ref * 2.0 ** (semis / 12.0)
    if level >= 2:
        frames = np.flatnonzero(voiced)
        for _ in range(max(1, len(frames) // 400)):      # about one jump per 2 s of voicing
            start = int(rng.choice(frames))
            seg = out[start:start + int(rng.integers(16, 40))]
            seg[seg > 0] *= 2.0 ** (int(rng.choice(JUMPS)) / 12.0)
    return out


def comb(y, sr):
    d = int(sr * COMB_MS / 1000)
    out = y.copy()
    out[d:] += COMB_MIX * y[:-d]
    return out


def glitch(y, sr, rng):
    """Two stutters (a 60-90 ms grain repeated) at quiet points, two 25 ms dropouts."""
    out = y.copy()
    hop = int(0.01 * sr)
    env = np.sqrt(np.convolve(out ** 2, np.ones(hop) / hop, mode="same"))
    quiet = np.flatnonzero(env < 0.25 * env.max())
    for _ in range(2):
        if len(quiet) == 0:
            break
        at = int(rng.choice(quiet))
        grain = int(rng.uniform(0.06, 0.09) * sr)
        if at + grain < len(out):
            out = np.concatenate([out[:at], np.tile(out[at:at + grain], int(rng.integers(2, 4))), out[at:]])
        quiet = quiet[quiet < at]
    drop = int(0.025 * sr)
    for _ in range(2):
        at = int(rng.integers(0, max(1, len(out) - drop)))
        out[at:at + drop] = 0.0
    return out


def process(wav, sr, level, seed):
    if level <= 0:
        return wav
    rng = np.random.default_rng(seed)
    x = wav.astype(np.float64)
    f0, t = pw.harvest(x, sr, frame_period=FRAME_MS)
    sp = pw.cheaptrick(x, f0, t, sr)
    ap = pw.d4c(x, f0, t, sr)
    y = pw.synthesize(flatten_pitch(f0, level, rng), sp, ap, sr, frame_period=FRAME_MS)
    y = comb(y, sr)
    if level >= 2:
        y = glitch(y, sr, rng)
    return y.astype(np.float32)
```

- [x] **Step 4: Uruchom testy** → `OK` (4).
- [x] **Step 5: Commit** `git commit -m "Voice tools: the System's machine voice (flattened, stepped pitch; three levels)"` (z oboma plikami).

### Task 4: Dane kwestii i teksty

**Files:**
- Create: `data/voice/lines.json`, `data/voice/speakers.json`, `data/voice/lexicon.json`
- Modify: `locale/strings.csv` (dopisać na końcu), `export_presets.cfg`

- [x] **Step 1:** `data/voice/speakers.json` i `data/voice/lines.json` — dokładnie jak w „Format danych”.
- [x] **Step 2:** `data/voice/lexicon.json`:
```json
{"Heniek": "hˈɛnjɛk", "Zawilski": "zavˈilski", "Wróblewski": "vrublˈɛfski", "Kopeć": "kˈɔpɛʧ", "Mazur": "mˈazur", "lamassu": "lamˈasu"}
```
(Symbol spoza słownika modelu = błąd `Kokoro(...)` — popraw zapis, a nie test.)
- [x] **Step 3:** `locale/strings.csv` — dopisz 4 kwestie z tabeli „Teksty startowe” i 6 kluczy z listy pod nią (kolumny `keys,pl,en`; pola z przecinkiem w cudzysłowie, jak reszta pliku; bez łamania wiersza).
- [x] **Step 4:** `export_presets.cfg`: `include_filter="data/voice/*.json"` (dane czytane `FileAccess` muszą być w paczce gry).
- [x] **Step 5: Commit** `git commit -m "Voice data: first lines (Heniek, the System, the Rosetta guide), speakers, lexicon"`

### Task 5: Generowanie nagrań i kodowanie Ogg

**Files:**
- Create: `tools/tts/voice_data.py`, `tools/tts/test_voice_data.py`, `tools/tts/generate_voice.py`, `tools/tts/build_voice.sh`
- Modify: `tools/music/encode_ogg.py`, `tests/unit/test_audio_assets.gd` (skan seriali obejmuje `assets/voice/*/`)

- [x] **Step 1: Test** `tools/tts/test_voice_data.py`
```python
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
```

- [x] **Step 2: `tools/tts/voice_data.py`**
```python
"""Voice lines as data: text from locale/strings.csv, rules from data/voice/*.json."""
import csv
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@dataclass
class VoiceData:
    lines: dict
    speakers: dict
    fx_version: int
    lexicon: dict
    text_en: dict

    def settings(self, key):
        """(voice, speed, level) of one line."""
        line = self.lines[key]
        speaker = self.speakers[line["speaker"]]
        return speaker["voice"], float(line.get("speed", speaker["speed"])), int(line.get("level", 0))

    def hash_of(self, key):
        voice, speed, level = self.settings(key)
        return line_hash(voice, speed, level, self.fx_version, self.text_en[key])


def line_hash(voice, speed, level, fx_version, text):
    return hashlib.sha256(f"{voice}|{speed:.3f}|{level}|{fx_version}|{text}".encode("utf-8")).hexdigest()


def load(root=ROOT):
    lines = json.loads((root / "data/voice/lines.json").read_text(encoding="utf-8"))["lines"]
    sp = json.loads((root / "data/voice/speakers.json").read_text(encoding="utf-8"))
    lexicon = json.loads((root / "data/voice/lexicon.json").read_text(encoding="utf-8"))
    with open(root / "locale/strings.csv", encoding="utf-8", newline="") as f:
        text = {row["keys"]: row["en"] for row in csv.DictReader(f)}
    missing = [k for k in lines if not text.get(k)]
    if missing:
        raise SystemExit(f"no English text in locale/strings.csv for: {missing}")
    return VoiceData(lines, sp["speakers"], int(sp["fx_version"]), lexicon, {k: text[k] for k in lines})
```

- [x] **Step 3: Testy** `cd tools/tts && .venv/Scripts/python.exe -m unittest test_voice_data -v` → `OK`.

- [x] **Step 4: `tools/tts/generate_voice.py`**
```python
"""Voice lines -> build/audio_src/voice/<speaker>/<key>.wav + assets/voice/manifest.json.

Only lines whose hash changed (text, voice, speed, level, fx_version) are made
again; lines gone from data/voice/lines.json lose their .ogg and manifest entry.
Then tools/music/encode_ogg.py -- voice encodes the WAVs (tools/tts/build_voice.sh).
    tools/tts/.venv/Scripts/python.exe tools/tts/generate_voice.py [--all]
"""
import hashlib
import json
import sys

import numpy as np
import soundfile as sf

from kokoro_tts import SR, Kokoro
from system_fx import process
from voice_data import ROOT, load

SRC = ROOT / "build/audio_src/voice"
DST = ROOT / "assets/voice"
MANIFEST = DST / "manifest.json"
TARGET_DB, PEAK_DB = -20.0, -1.0        # RMS of the speech (frames above the gate), peak ceiling
HEAD, TAIL = 0.06, 0.12                 # s of silence around a line


def normalize(wav):
    frames = wav[: len(wav) // 480 * 480].reshape(-1, 480)
    energy = np.sqrt(np.mean(frames ** 2, axis=1))
    speech = energy[energy > energy.max() * 10 ** (-45 / 20)]
    rms = float(np.sqrt(np.mean(speech ** 2))) if len(speech) else float(np.sqrt(np.mean(wav ** 2)))
    gain = min(10 ** (TARGET_DB / 20) / max(rms, 1e-6), 10 ** (PEAK_DB / 20) / max(float(np.abs(wav).max()), 1e-6))
    return wav * gain


def main(force):
    data = load()
    tts = Kokoro(data.lexicon)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for key in sorted(data.lines):
        speaker = data.lines[key]["speaker"]
        h = data.hash_of(key)
        ogg = DST / speaker / f"{key}.ogg"
        if not force and manifest.get(key, {}).get("hash") == h and ogg.exists():
            continue
        if len(data.text_en[key]) < 25:
            print(f"warning: {key} is short ({len(data.text_en[key])} chars) — Kokoro is weak on very short lines")
        voice, speed, level = data.settings(key)
        wav = tts.synth(data.text_en[key], voice, speed)
        seed = int(hashlib.sha256(key.encode()).hexdigest()[:8], 16)
        wav = normalize(process(wav, SR, level, seed))
        wav = np.concatenate([np.zeros(int(HEAD * SR)), wav, np.zeros(int(TAIL * SR))]).astype(np.float32)
        (SRC / speaker).mkdir(parents=True, exist_ok=True)
        sf.write(SRC / speaker / f"{key}.wav", wav, SR, subtype="PCM_16")
        manifest[key] = {"hash": h, "speaker": speaker, "seconds": round(len(wav) / SR, 3)}
        print(f"{key}: {voice} x{speed:.2f} level {level}, {len(wav) / SR:.2f} s")
    for key in [k for k in manifest if k not in data.lines]:
        for path in DST.glob(f"*/{key}.ogg*"):
            path.unlink()
        del manifest[key]
        print(f"{key}: removed")
    DST.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main("--all" in sys.argv)
```

- [x] **Step 5: `tools/music/encode_ogg.py`** — dopisz rodzaj `voice` (mono 24 kHz, 64 kbit/s) i tryb samego głosu:
  - `BITRATE` += `("voice", 1): 64000`;
  - w `encode()`: `rate=24000 if kind == "voice" else 44100`;
  - na początku `main()`: `voice_only = sys.argv[sys.argv.index("--") + 1:] == ["voice"] if "--" in sys.argv else False`; dotychczasowe zadania tylko gdy `not voice_only`; potem zawsze:
```python
    for src in sorted((SRC / "voice").glob("*/*.wav")):
        jobs.append((src, DST / "voice" / src.parent.name / (src.stem + ".ogg"), "voice", False))
```
  - docstring: wiersz `build/audio_src/voice/<speaker>/<key>.wav -> assets/voice/<speaker>/<key>.ogg`.

- [x] **Step 6: `tools/tts/build_voice.sh`**
```bash
#!/usr/bin/env bash
# Voice lines: Kokoro -> build/audio_src/voice/*.wav -> assets/voice/*.ogg (+ manifest, .import), Godot import.
#   bash tools/tts/build_voice.sh          changed lines only
#   bash tools/tts/build_voice.sh --all    every line again
set -euo pipefail
cd "$(dirname "$0")/../.."
. tools/dev_env.sh
BLENDER="D:/Program Files/Blender Foundation/Blender 5.1/blender.exe"
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
(cd tools/tts && .venv/Scripts/python.exe generate_voice.py "$@")
"$BLENDER" -b --factory-startup --python tools/music/encode_ogg.py -- voice 2>&1 | grep -E " MB|Error|nothing" || true
"$GODOT" --headless --path . --import > /dev/null 2>&1
```

- [x] **Step 7: `tests/unit/test_audio_assets.gd`** — w `test_every_ogg_has_its_fixed_stream_serial` dodaj katalogi `res://assets/voice/heniek` i `res://assets/voice/system` do listy skanowanych.

- [x] **Step 8: Uruchom** `bash tools/tts/build_voice.sh`. Oczekiwane: 4 wiersze `VO_…: … s`, 4 pliki `assets/voice/*/VO_*.ogg` (+ `.import`), `manifest.json` z 4 wpisami; drugie uruchomienie nie generuje niczego (wszystko aktualne).

- [x] **Step 9: Commit** (z `assets/voice/`) `git commit -m "Voice: generate the lines (Kokoro + System fx), encode Ogg like the music, manifest with hashes"`

### Task 6: Próbki głosów dla właściciela

**Files:**
- Create: `tools/tts/voice_samples.py`

- [x] **Step 1: `tools/tts/voice_samples.py`**
```python
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
    tts = Kokoro(load().lexicon)
    rows = []
    for role, voices in CANDIDATES.items():
        for voice in voices:
            dry = tts.synth(TEXT[role], voice)
            takes = {"czysty": dry}
            if role == "heniek":
                takes["radio (podgląd)"] = radio(dry)
            else:
                for level in (1, 2):
                    takes[f"stopień {level}"] = process(dry, SR, level, seed=7)
            for label, wav in takes.items():
                name = f"{role}_{voice}_{label.split()[0]}.wav"
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
(oraz stopień „maszynowości” Systemu na co dzień). Podgląd radia jest przybliżony — w grze robi go kanał dźwięku.</p>
{section("heniek", "Heniek (krótkofalówka)", "„" + html.escape(TEXT["heniek"]) + "”")}
{section("system", "System — Wirtualny Kustosz", "„" + html.escape(TEXT["system"]) + "”")}
</body></html>"""


if __name__ == "__main__":
    main()
```
- [x] **Step 2: Uruchom** `cd tools/tts && .venv/Scripts/python.exe voice_samples.py` → `build/voice-samples/index.html` + 6×2 + 5×3 = 27 plików WAV. **Nie odtwarzać.** Zgłoś kontrolerowi ścieżkę strony (kontroler przekaże ją właścicielowi).
- [x] **Step 3: Commit** `git commit -m "Voice tools: audition page for the owner (candidate voices, radio preview, System levels)"`
- [ ] **Step 4 (po decyzji właściciela, może przyjść później):** wpisz wybrane głosy/tempo/stopień do `data/voice/speakers.json` (i stopnie kwestii Systemu w `lines.json`), `bash tools/tts/build_voice.sh`, commit „Voice: the owner's voices”.

### Task 7: Kanały, opcje, teksty opcji

**Files:**
- Modify: `default_bus_layout.tres`, `src/core/settings_data.gd`, `src/ui/options_menu.gd`
- Test: `tests/unit/test_voice_buses.gd` (nowy); istniejące `test_settings_data.gd`, `test_options_menu.gd` mają przejść bez zmian

- [x] **Step 1: Test** `tests/unit/test_voice_buses.gd`
```gdscript
extends TestCase


func test_voice_has_its_buses_under_the_master() -> void:
	for bus in [&"Voice", &"VoiceRadio", &"VoiceSystem"]:
		assert_gt(AudioServer.get_bus_index(bus), 13, "%s comes after the reverb buses" % bus)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Voice")), &"Master")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"VoiceRadio")), &"Voice")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"VoiceSystem")), &"Voice")


func test_the_radio_bus_sounds_like_a_walkie_talkie() -> void:
	var index := AudioServer.get_bus_index(&"VoiceRadio")
	var kinds: Array[String] = []
	for i in AudioServer.get_bus_effect_count(index):
		kinds.append(AudioServer.get_bus_effect(index, i).get_class())
	assert_true(kinds.has("AudioEffectHighPassFilter") and kinds.has("AudioEffectLowPassFilter"), str(kinds))
	assert_true(kinds.has("AudioEffectDistortion"), str(kinds))


func test_music_and_ambience_have_a_duck_effect_at_zero() -> void:
	for bus in [&"Music", &"Ambience"]:
		var effect := VoiceDirector.duck_effect(bus)
		assert_not_null(effect, "%s has VoiceDuck" % bus)
		if effect:
			assert_almost_eq(effect.volume_db, 0.0)


func test_the_voice_volume_drives_the_voice_bus() -> void:
	assert_eq(SettingsData.VOLUME_BUSES[&"volume_voice"], &"Voice")
	Settings.set_value(&"volume_voice", 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Voice")))
	Settings.set_value(&"volume_voice", 1.0)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Voice")))


func test_subtitles_are_on_by_default() -> void:
	assert_true(SettingsData.new().subtitles)
```
(`VoiceDirector.duck_effect` powstaje w zadaniu 11 — do tego czasu ten jeden test jest czerwony; to w porządku, zadania idą po kolei. `Settings.set_value(key, value, persist := true)` — `src/core/settings.gd:69`.)

- [x] **Step 2: Uruchom** `bash tools/run_tests.sh --filter=voice_buses` → czerwone (brak kanałów).
- [x] **Step 3: `default_bus_layout.tres`** — przed `[resource]` dopisz pod-zasoby:
```
[sub_resource type="AudioEffectAmplify" id="AudioEffectAmplify_duck_music"]
resource_name = "VoiceDuck"

[sub_resource type="AudioEffectAmplify" id="AudioEffectAmplify_duck_ambience"]
resource_name = "VoiceDuck"

[sub_resource type="AudioEffectHighPassFilter" id="AudioEffectHighPassFilter_radio"]
cutoff_hz = 320.0

[sub_resource type="AudioEffectLowPassFilter" id="AudioEffectLowPassFilter_radio"]
cutoff_hz = 3200.0

[sub_resource type="AudioEffectDistortion" id="AudioEffectDistortion_radio"]
mode = 3
drive = 0.18
post_gain = -2.0

[sub_resource type="AudioEffectCompressor" id="AudioEffectCompressor_radio"]
threshold = -18.0
ratio = 4.0
```
w `[resource]` po wpisach busa 2 i 3:
```
bus/2/effect/0/effect = SubResource("AudioEffectAmplify_duck_music")
bus/2/effect/0/enabled = true
bus/3/effect/0/effect = SubResource("AudioEffectAmplify_duck_ambience")
bus/3/effect/0/enabled = true
```
a na końcu:
```
bus/14/name = &"Voice"
bus/14/solo = false
bus/14/mute = false
bus/14/bypass_fx = false
bus/14/volume_db = 0.0
bus/14/send = &"Master"
bus/15/name = &"VoiceRadio"
bus/15/solo = false
bus/15/mute = false
bus/15/bypass_fx = false
bus/15/volume_db = 0.0
bus/15/send = &"Voice"
bus/15/effect/0/effect = SubResource("AudioEffectHighPassFilter_radio")
bus/15/effect/0/enabled = true
bus/15/effect/1/effect = SubResource("AudioEffectLowPassFilter_radio")
bus/15/effect/1/enabled = true
bus/15/effect/2/effect = SubResource("AudioEffectDistortion_radio")
bus/15/effect/2/enabled = true
bus/15/effect/3/effect = SubResource("AudioEffectCompressor_radio")
bus/15/effect/3/enabled = true
bus/16/name = &"VoiceSystem"
bus/16/solo = false
bus/16/mute = false
bus/16/bypass_fx = false
bus/16/volume_db = 0.0
bus/16/send = &"Voice"
```
- [x] **Step 4: `src/core/settings_data.gd`** — `VOLUME_BUSES` += `&"volume_voice": &"Voice"`; `var volume_voice: float = 1.0`; `var subtitles: bool = true`; oba klucze do `keys()` (`volume_voice` po `volume_ambience`, `subtitles` przy innych przełącznikach interfejsu); `volume_voice = clampf(volume_voice, 0.0, 1.0)` w `sanitize()`.
- [x] **Step 5: `src/ui/options_menu.gd`** — po wierszu `volume_ambience`:
```gdscript
	_add(list, OptionRow.slider(&"volume_voice", "OPT_VOLUME_VOICE", 0.0, 1.0, 0.05, _percent))
```
w sekcji interfejsu:
```gdscript
	_add(list, OptionRow.toggle(&"subtitles", "OPT_SUBTITLES"))
```
- [x] **Step 6: Uruchom** `bash tools/run_tests.sh --filter=voice_buses,settings,options` → zielone poza `test_music_and_ambience_have_a_duck_effect_at_zero` (czeka na zadanie 11).
- [x] **Step 7: Commit** `git commit -m "Voice buses (radio, System), duck effects on music and ambience, voice volume and subtitles options"`

### Task 8: `VoiceCatalog` + test danych

**Files:**
- Create: `src/audio/voice/voice_catalog.gd`, `tests/unit/test_voice_data.gd`

- [x] **Step 1: Test** `tests/unit/test_voice_data.gd`
```gdscript
extends TestCase
## Every voice line has its text (PL + EN), its rule, its recording, and the
## recording is up to date (manifest hash = the hash of today's text and settings).

const MANIFEST := "res://assets/voice/manifest.json"
var catalog: VoiceCatalog
var texts: Dictionary = {}


func before_each() -> void:
	catalog = VoiceCatalog.load_default()
	texts = _csv()


func test_there_are_lines_and_speakers() -> void:
	assert_gt(catalog.lines.size(), 3)
	for speaker in [&"heniek", &"system"]:
		assert_true(catalog.speakers.has(String(speaker)), String(speaker))


func test_every_line_has_polish_and_english_text_on_one_row() -> void:
	for key in catalog.lines:
		assert_true(texts.has(key), key + " is in locale/strings.csv")
		if not texts.has(key):
			continue
		var pl: String = texts[key][0]
		var en: String = texts[key][1]
		assert_true(pl != "" and en != "", key)
		assert_false(pl.contains("\n") or en.contains("\n"), key + " is one row")
		assert_true(en.length() >= 20, key + ": Kokoro is weak on very short lines")


func test_every_rule_is_well_formed() -> void:
	for key in catalog.lines:
		var line: Dictionary = catalog.lines[key]
		assert_true(catalog.speakers.has(String(line.get("speaker", ""))), key + ": known speaker")
		if line.has("station"):
			assert_true(String(line.get("variant", "")) in ["a", "b"], key + ": variant a or b")
			continue
		var event := StringName(line.get("event", ""))
		assert_true(event in VoiceCatalog.EVENTS, "%s: event %s" % [key, event])
		if not event in VoiceCatalog.PSEUDO_EVENTS:
			assert_true(Events.has_signal(event), "%s: Events.%s exists" % [key, event])


func test_every_guide_station_has_a_day_recording() -> void:
	for key in catalog.lines:
		var line: Dictionary = catalog.lines[key]
		if line.has("station"):
			assert_ne(catalog.guide_key(StringName(line.station), &"a"), &"", String(line.station))


func test_every_line_has_an_up_to_date_recording() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_true(manifest is Dictionary, "assets/voice/manifest.json (bash tools/tts/build_voice.sh)")
	if not manifest is Dictionary:
		return
	for key in catalog.lines:
		var entry: Dictionary = manifest.get(key, {})
		var voice: Dictionary = catalog.speakers[String(catalog.lines[key].speaker)]
		var line: Dictionary = catalog.lines[key]
		var wanted := VoiceCatalog.hash_of(String(voice.voice), float(line.get("speed", voice.speed)),
				int(line.get("level", 0)), catalog.fx_version, texts.get(key, ["", ""])[1])
		assert_eq(entry.get("hash", ""), wanted, key + ": text or settings changed — run tools/tts/build_voice.sh")
		assert_true(ResourceLoader.exists(catalog.stream_path(key)), key + ": recording exists")
	for key in manifest:
		assert_true(catalog.lines.has(key), key + ": manifest entry without a line")


func test_the_speaker_labels_exist() -> void:
	for key in ["VOICE_SPEAKER_HENIEK", "VOICE_SPEAKER_SYSTEM", "VOICE_SPEAKER_GUIDE"]:
		assert_true(texts.has(key), key)


## locale/strings.csv read raw (the same bytes the voice tools hash).
static func _csv() -> Dictionary:
	var out := {}
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			out[row[0]] = [row[1], row[2]]
	return out
```

- [x] **Step 2: Uruchom** `--filter=voice_data` → czerwone (`VoiceCatalog` nie istnieje).

- [x] **Step 3: `src/audio/voice/voice_catalog.gd`**
```gdscript
class_name VoiceCatalog
extends RefCounted
## Voice lines as data: data/voice/lines.json (who says it, when) and
## data/voice/speakers.json (which Kokoro voice); the text itself is in
## locale/strings.csv under the same key. Recordings: assets/voice/<speaker>/<key>.ogg
## (tools/tts/build_voice.sh). Spec: docs/superpowers/specs/2026-10-08-glos-projekt.md.

const LINES_PATH := "res://data/voice/lines.json"
const SPEAKERS_PATH := "res://data/voice/speakers.json"
const AUDIO_DIR := "res://assets/voice"
## Events the rules may name: Events signals plus the director's own.
const PSEUDO_EVENTS: Array[StringName] = [&"death", &"destroyed", &"stall", &"night_time"]
const EVENTS: Array[StringName] = [&"night_started", &"power_cut", &"witching_hour", &"dawn_broke",
		&"room_entered", &"guardian_awakened", &"guardian_defeated", &"shard_collected", &"seal_collected",
		&"gate_opened", &"boss_awakened", &"boss_defeated", &"death", &"destroyed", &"stall", &"night_time"]

var lines: Dictionary = {}      ## String key -> Dictionary (the rule)
var speakers: Dictionary = {}   ## String speaker -> {voice, speed}
var fx_version := 1


static func load_default() -> VoiceCatalog:
	var catalog := VoiceCatalog.new()
	catalog.lines = _read(LINES_PATH).get("lines", {})
	var data := _read(SPEAKERS_PATH)
	catalog.speakers = data.get("speakers", {})
	catalog.fx_version = int(data.get("fx_version", 1))
	return catalog


static func _read(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## SHA-256 of "<voice>|<speed:.3f>|<level>|<fx_version>|<text>" — the same as
## tools/tts/voice_data.py line_hash().
static func hash_of(voice: String, speed: float, level: int, version: int, text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%s|%.3f|%d|%d|%s" % [voice, speed, level, version, text]).to_utf8_buffer())
	return context.finish().hex_encode()


func line(key: StringName) -> Dictionary:
	return lines.get(String(key), {})


func speaker_of(key: StringName) -> StringName:
	return StringName(line(key).get("speaker", ""))


## &"radio" (Heniek), &"guide" (an audio-guide stand) or &"pa" (the loudspeakers).
func channel_of(key: StringName) -> StringName:
	var rule := line(key)
	if rule.get("speaker", "") == "heniek":
		return &"radio"
	return &"guide" if rule.has("station") else &"pa"


func stream_path(key: StringName) -> String:
	return "%s/%s/%s.ogg" % [AUDIO_DIR, speaker_of(key), key]


func stream(key: StringName) -> AudioStream:
	var path := stream_path(key)
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


## Keys of the lines listening to [param event], in file order.
func keys_for_event(event: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for key in lines:
		if StringName(lines[key].get("event", "")) == event:
			out.append(StringName(key))
	return out


## The recording of [param station] in [param variant] (&"a" day, &"b" night), or &"".
func guide_key(station: StringName, variant: StringName) -> StringName:
	for key in lines:
		var rule: Dictionary = lines[key]
		if StringName(rule.get("station", "")) == station and StringName(rule.get("variant", "")) == variant:
			return StringName(key)
	return &""
```

- [x] **Step 4: Uruchom** `--filter=voice_data` → zielone (nagrania z zadania 5 są aktualne).
- [x] **Step 5: Commit** `git commit -m "VoiceCatalog: voice lines as data, recording paths, the shared line hash (+ data test)"`

### Task 9: `VoiceRules` i `VoiceQueue` — czysta logika

**Files:**
- Create: `src/audio/voice/voice_rules.gd`, `src/audio/voice/voice_queue.gd`, `tests/unit/test_voice_queue.gd`

- [x] **Step 1: Test** `tests/unit/test_voice_queue.gd`
```gdscript
extends TestCase

var queue: VoiceQueue


func before_each() -> void:
	queue = VoiceQueue.new()


func _run(seconds: float, calm := true) -> Array[StringName]:
	var started: Array[StringName] = []
	var t := 0.0
	while t < seconds:
		var key := queue.advance(0.1, calm)
		if key != &"":
			started.append(key)
		t += 0.1
	return started


func test_a_line_waits_for_calm_then_starts() -> void:
	queue.push(&"A", VoiceQueue.NORMAL)
	assert_eq(_run(3.0), [] as Array[StringName], "not before 4 s of calm")
	assert_eq(_run(1.5), [&"A"] as Array[StringName])


func test_one_voice_at_a_time_and_a_gap_after_each_line() -> void:
	queue.push(&"A", VoiceQueue.EVENT)
	queue.push(&"B", VoiceQueue.EVENT)
	assert_eq(_run(5.0), [&"A"] as Array[StringName])
	assert_eq(_run(30.0), [] as Array[StringName], "A is still on air")
	queue.finished()
	assert_eq(_run(19.0), [] as Array[StringName], "20 s of quiet after a line")
	assert_eq(_run(2.0), [&"B"] as Array[StringName])


func test_the_higher_priority_goes_first() -> void:
	queue.push(&"side", VoiceQueue.SIDE)
	queue.push(&"event", VoiceQueue.EVENT)
	assert_eq(_run(5.0), [&"event"] as Array[StringName])


func test_an_event_line_stops_waiting_for_calm_after_10_s() -> void:
	queue.push(&"E", VoiceQueue.EVENT)
	assert_eq(_run(9.5, false), [] as Array[StringName])
	assert_eq(_run(1.0, false), [&"E"] as Array[StringName])


func test_a_side_remark_that_waited_a_minute_is_dropped() -> void:
	queue.push(&"S", VoiceQueue.SIDE)
	_run(61.0, false)
	assert_false(queue.has(&"S"))


func test_side_remarks_are_three_minutes_apart() -> void:
	queue.push(&"S1", VoiceQueue.SIDE)
	assert_eq(_run(5.0), [&"S1"] as Array[StringName])
	queue.finished()
	queue.push(&"S2", VoiceQueue.SIDE)
	assert_eq(_run(55.0), [] as Array[StringName])
	assert_false(queue.has(&"S2"), "it waited more than a minute behind the gap: dropped")


func test_a_delay_holds_a_line_back() -> void:
	queue.push(&"D", VoiceQueue.NORMAL, 20.0)
	assert_eq(_run(19.0), [] as Array[StringName])
	assert_eq(_run(5.0), [&"D"] as Array[StringName])


func test_duplicates_are_ignored() -> void:
	assert_true(queue.push(&"A", VoiceQueue.NORMAL))
	assert_false(queue.push(&"A", VoiceQueue.NORMAL))


func test_an_interrupted_line_comes_back_first() -> void:
	queue.push(&"A", VoiceQueue.EVENT)
	queue.push(&"B", VoiceQueue.EVENT)
	_run(5.0)
	assert_eq(queue.interrupt(), &"A")
	queue.hold(&"guide")
	assert_true(queue.is_speaking())
	queue.finished()
	assert_eq(_run(25.0), [&"A"] as Array[StringName])


func test_rules_match_their_conditions() -> void:
	assert_true(VoiceRules.matches({"night": 1}, {"night": 1}))
	assert_false(VoiceRules.matches({"night": 1}, {"night": 2}))
	assert_true(VoiceRules.matches({"night_min": 2}, {"night": 3}))
	assert_false(VoiceRules.matches({"night_min": 2}, {"night": 1}))
	assert_true(VoiceRules.matches({"zone": "egypt"}, {"zone": &"egypt"}))
	assert_false(VoiceRules.matches({"guardian": "colossus"}, {"guardian": &"centaur"}))
	assert_true(VoiceRules.matches({"count": 3}, {"count": 3}))
	assert_false(VoiceRules.matches({"goal": "GOAL_A"}, {"goal": &"GOAL_B"}))
	assert_false(VoiceRules.matches({"speaker": "system"}, {"speaker": &"heniek"}))
	assert_true(VoiceRules.matches({"speaker": "heniek", "night": 2}, {"night": 2}), "no speaker in payload: any")
```

- [x] **Step 2: Uruchom** `--filter=voice_queue` → czerwone.

- [x] **Step 3: `src/audio/voice/voice_rules.gd`**
```gdscript
class_name VoiceRules
extends RefCounted
## Does a line's rule (data/voice/lines.json) fit an event's payload? Pure.
## A condition absent from the rule does not filter; a payload without the
## field fails rules that ask for it (except "speaker", which only filters
## when the payload names one — the death comment's turn).


static func matches(rule: Dictionary, payload: Dictionary) -> bool:
	if rule.has("night") and int(rule.night) != int(payload.get("night", -1)):
		return false
	if rule.has("night_min") and int(payload.get("night", 0)) < int(rule.night_min):
		return false
	for field in ["zone", "guardian", "goal"]:
		if rule.has(field) and StringName(rule[field]) != StringName(payload.get(field, "")):
			return false
	if rule.has("count") and int(rule.count) != int(payload.get("count", -1)):
		return false
	if payload.has("speaker") and StringName(rule.get("speaker", "")) != StringName(payload.speaker):
		return false
	return true
```

- [x] **Step 4: `src/audio/voice/voice_queue.gd`**
```gdscript
class_name VoiceQueue
extends RefCounted
## Who speaks next, and when. Pure logic: the director feeds it time, calm and
## requests; it answers with the line to start. One voice at a time.

const SIDE := 0
const NORMAL := 1
const EVENT := 2
const GUIDE := 3

const CALM_NEEDED := 4.0      ## s with no hunter near and no hit before a line starts
const EVENT_MAX_WAIT := 10.0  ## an event line stops waiting for calm after this long
const SIDE_EXPIRY := 60.0     ## a side remark that waited this long is dropped (stays unheard)
const SIDE_GAP := 180.0       ## s between two side remarks
const LINE_GAP := 20.0        ## s of quiet after any line

var pending: Array[Dictionary] = []   ## {key, priority, delay, waited}
var speaking: Dictionary = {}         ## the request on air; {} when quiet
var calm_time := 0.0
var since_line := LINE_GAP
var since_side := SIDE_GAP


func push(key: StringName, priority: int, delay := 0.0) -> bool:
	if has(key):
		return false
	pending.append({"key": key, "priority": priority, "delay": delay, "waited": 0.0})
	return true


func has(key: StringName) -> bool:
	if speaking.get("key", &"") == key:
		return true
	for request in pending:
		if request.key == key:
			return true
	return false


func is_speaking() -> bool:
	return not speaking.is_empty()


## Ages the queue by [param dt]; returns the key that starts now, or &"".
func advance(dt: float, calm: bool) -> StringName:
	calm_time = calm_time + dt if calm else 0.0
	if speaking.is_empty():
		since_line += dt
	since_side += dt
	var kept: Array[Dictionary] = []
	for request in pending:
		if request.delay > 0.0:
			request.delay = maxf(0.0, request.delay - dt)
		else:
			request.waited += dt
		if not (request.priority == SIDE and request.waited > SIDE_EXPIRY):
			kept.append(request)
	pending = kept
	if not speaking.is_empty() or since_line < LINE_GAP:
		return &""
	var best := _best_ready()
	if best.is_empty():
		return &""
	pending.erase(best)
	speaking = best
	if best.priority == SIDE:
		since_side = 0.0
	return best.key


func _best_ready() -> Dictionary:
	var best: Dictionary = {}
	for request in pending:
		if request.delay > 0.0:
			continue
		if request.priority == SIDE and since_side < SIDE_GAP:
			continue
		var waited_enough: bool = request.priority >= EVENT and request.waited >= EVENT_MAX_WAIT
		if calm_time < CALM_NEEDED and not waited_enough:
			continue
		if best.is_empty() or request.priority > best.priority:
			best = request
	return best


## The line on air ended. Returns its key.
func finished() -> StringName:
	var key: StringName = speaking.get("key", &"")
	speaking = {}
	since_line = 0.0
	return key


## Something more important cut in: the line on air goes back to the front of
## the queue and will be played again from its start.
func interrupt() -> StringName:
	if speaking.is_empty():
		return &""
	var request := speaking
	speaking = {}
	request.waited = 0.0
	pending.push_front(request)
	return request.key


## The audio guide takes the air directly (the player pressed its button).
func hold(key: StringName) -> void:
	speaking = {"key": key, "priority": GUIDE, "delay": 0.0, "waited": 0.0}


func clear() -> void:
	pending.clear()
	speaking = {}
	calm_time = 0.0
	since_line = LINE_GAP
	since_side = SIDE_GAP
```
- [x] **Step 5: Uruchom** `--filter=voice_queue` → zielone.
- [x] **Step 6: Commit** `git commit -m "VoiceQueue and VoiceRules: who speaks next (calm, priorities, gaps, expiry, interruption)"`

### Task 10: Zapis — wysłuchane kwestie

**Files:**
- Modify: `src/state/game_state.gd`, `tests/unit/test_game_state.gd` (`_fill`), `tests/unit/test_game_state_floor1.gd` (pole w teście „every progress field”)

- [x] **Step 1: Testy** — w `test_game_state.gd` `_fill()` dopisz `state.mark_voice_heard(&"VO_HENIEK_NIGHT_1")` i `state.voice_state = {"destroyed": 12, "death_turn": "system", "death_night": 2}`; nowy test:
```gdscript
func test_voice_lines_heard_survive_a_save() -> void:
	var state := PersistentState.new()
	assert_true(state.mark_voice_heard(&"VO_A"))
	assert_false(state.mark_voice_heard(&"VO_A"), "once")
	state.voice_state = {"destroyed": 7, "death_turn": "system", "death_night": 3}
	var loaded := PersistentState.new()
	loaded.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_true(loaded.voice_heard.has(&"VO_A"))
	assert_eq(loaded.voice_state, {"destroyed": 7, "death_turn": "system", "death_night": 3})
	loaded.reset()
	assert_true(loaded.voice_heard.is_empty() and loaded.voice_state.is_empty())
```
(Dopasuj tworzenie stanu do wzorca w pliku — jeśli testy używają innego konstruktora/ścieżki zapisu, idź za nim.)
- [x] **Step 2: Uruchom** `--filter=game_state` → czerwone.
- [x] **Step 3: `src/state/game_state.gd`** (wzorzec `chess_found`):
```gdscript
## Voice lines already heard (VoiceDirector; "once per game" and the audio
## guide's night recordings). Marked when a line ends; saved with the next save.
var voice_heard: Array[StringName] = []
## The director's counters: "destroyed" (exhibits destroyed, all nights),
## "death_turn" ("heniek"/"system": who comments the next death), "death_night".
var voice_state: Dictionary = {}
```
`reset()`: `voice_heard = []`, `voice_state = {}`;
```gdscript
func mark_voice_heard(key: StringName) -> bool:
	return _add_once(voice_heard, key)
```
`to_dict()`: `"voice_heard": _strings(voice_heard), "voice_state": voice_state.duplicate(),`;
`from_dict()`: `voice_heard = _names(data.get("voice_heard"))`, `voice_state = _voice_state(data.get("voice_state"))` z:
```gdscript
## Only the known counters, with their types (JSON brings numbers back as floats).
static func _voice_state(value: Variant) -> Dictionary:
	var out := {}
	if not value is Dictionary:
		return out
	for key in ["destroyed", "death_night"]:
		if value.has(key) and (value[key] is int or value[key] is float):
			out[key] = int(value[key])
	if value.get("death_turn") in ["heniek", "system"]:
		out["death_turn"] = String(value.death_turn)
	return out
```
Wersji zapisu nie podbijać (`from_dict` znosi brak pól).
- [x] **Step 4: Uruchom** `--filter=game_state` → zielone.
- [x] **Step 5: Commit** `git commit -m "Save: voice lines heard and the voice director's counters"`

### Task 11: `VoiceDirector` (autoload)

**Files:**
- Create: `src/audio/voice/voice_director.gd`, `tests/integration/test_voice_director.gd`
- Modify: `project.godot` (autoload po `Foley`), `tests/test_runner.gd` (`_reset_globals`: `VoiceDirector.reset()`)

- [x] **Step 1: Test** `tests/integration/test_voice_director.gd`
```gdscript
extends TestCase
## The director with the real catalog (data/voice) and the real recordings.
## Time is driven by VoiceDirector.advance(); the audio driver is a dummy.

var camera: Camera3D


func before_each() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true


func after_each() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = false


func _advance(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		VoiceDirector.advance(0.1)
		t += 0.1


func test_the_first_night_starts_with_heniek_on_the_radio() -> void:
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(5.0)
	assert_eq(started.size(), 1)
	assert_eq(started[0][0], &"VO_HENIEK_NIGHT_1")
	assert_eq(started[0][1], &"radio")


func test_a_line_is_heard_once_per_game() -> void:
	Events.night_started.emit(1, &"")
	_advance(5.0 + VoiceDirector.catalog.stream(&"VO_HENIEK_NIGHT_1").get_length() + 1.0)
	assert_true(GameState.voice_heard.has(&"VO_HENIEK_NIGHT_1"))
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(10.0)
	for entry in started:
		assert_ne(entry[0], &"VO_HENIEK_NIGHT_1", "not again")


func test_the_system_closes_the_museum_after_heniek() -> void:
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(80.0)
	var keys := started.map(func(e): return e[0])
	assert_eq(keys, [&"VO_HENIEK_NIGHT_1", &"VO_SYSTEM_CLOSING_1"])
	assert_eq(started[1][1], &"pa")


func test_music_ducks_under_a_line_and_comes_back() -> void:
	Events.night_started.emit(1, &"")
	_advance(5.0)
	assert_almost_eq(VoiceDirector.duck_effect(&"Music").volume_db, VoiceDirector.DUCK_MUSIC_DB, 0.01)
	assert_almost_eq(VoiceDirector.duck_effect(&"Ambience").volume_db, VoiceDirector.DUCK_AMBIENCE_DB, 0.01)
	_advance(VoiceDirector.catalog.stream(&"VO_HENIEK_NIGHT_1").get_length() + 2.0)
	assert_almost_eq(VoiceDirector.duck_effect(&"Music").volume_db, 0.0, 0.001)


func test_the_guide_plays_the_day_recording_then_the_night_one() -> void:
	var stand := Node3D.new()
	add_child(stand)
	assert_eq(VoiceDirector.play_guide(&"rosetta", stand), &"VO_GUIDE_ROSETTA_A")
	VoiceDirector.stop_line()
	GameState.defeat_guardian(&"colossus")
	assert_eq(VoiceDirector.play_guide(&"rosetta", stand), &"VO_GUIDE_ROSETTA_B")


func test_a_second_press_stops_the_guide() -> void:
	var stand := Node3D.new()
	add_child(stand)
	VoiceDirector.play_guide(&"rosetta", stand)
	assert_eq(VoiceDirector.play_guide(&"rosetta", stand), &"")
	assert_eq(VoiceDirector.current_line(), &"")


func test_the_guide_cuts_heniek_who_comes_back_later() -> void:
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(5.0)
	var stand := Node3D.new()
	add_child(stand)
	VoiceDirector.play_guide(&"rosetta", stand)
	assert_false(GameState.voice_heard.has(&"VO_HENIEK_NIGHT_1"), "cut lines stay unheard")
	_advance(VoiceDirector.catalog.stream(&"VO_GUIDE_ROSETTA_A").get_length() + 25.0)
	assert_eq(started.filter(func(e): return e[0] == &"VO_HENIEK_NIGHT_1").size(), 2, "Heniek again from the start")


func test_walking_away_stops_the_guide() -> void:
	var stand := Node3D.new()
	add_child(stand)
	VoiceDirector.play_guide(&"rosetta", stand)
	camera.global_position = Vector3(0, 0, VoiceDirector.GUIDE_RANGE + 2.0)
	_advance(0.2)
	assert_eq(VoiceDirector.current_line(), &"")


func test_a_death_is_commented_at_the_next_night_by_turns() -> void:
	# needs a death line per speaker in data — skip quietly until G2 adds them
	if VoiceDirector.catalog.keys_for_event(&"death").is_empty():
		return
	Events.player_died.emit()
	Events.night_started.emit(2, &"")
	_advance(5.0)
	assert_eq(GameState.voice_state.get("death_turn"), "system")
	assert_eq(GameState.voice_state.get("death_night"), 2)


func test_destroyed_exhibits_are_counted() -> void:
	for i in 3:
		Events.enemy_destroyed.emit(null, null, false)
	assert_eq(GameState.voice_state.get("destroyed"), 3)


func test_pause_freezes_the_line() -> void:
	Events.night_started.emit(1, &"")
	_advance(5.0)
	var left := VoiceDirector.line_left()
	get_tree().paused = true
	await physics_frames(30)
	get_tree().paused = false
	assert_almost_eq(VoiceDirector.line_left(), left, 0.001)
```
(`Events.enemy_destroyed.emit(null, null, false)` — jeśli typowany sygnał nie przyjmie `null` dla `DamageInfo`, użyj `DamageInfo.new()`.)

- [x] **Step 2: Uruchom** `--filter=voice_director` → czerwone.

- [x] **Step 3: `src/audio/voice/voice_director.gd`**
```gdscript
extends Node
## Voice-over (autoload "VoiceDirector"): Heniek on the walkie-talkie and the
## museum's System on the loudspeakers and at the audio-guide stands.
## Listens to Events only. Lines and rules are data (VoiceCatalog), who
## speaks next is VoiceQueue, the acoustics are the buses (VoiceRadio,
## VoiceSystem) and the reverb zones. Time runs through advance(), so tests
## drive it without audio. Spec: docs/superpowers/specs/2026-10-08-glos-projekt.md.

signal line_started(key: StringName, channel: StringName, seconds: float)
signal line_ended(key: StringName)

const STALL_TIME := 360.0        ## s without progress before Heniek nudges
const STALL_GAP := 600.0         ## s between two nudges
const DEATH_DELAY := 3.0         ## s into the next night before the death comment
const DUCK_MUSIC_DB := -6.0
const DUCK_AMBIENCE_DB := -4.0
const DUCK_ATTACK := 0.25
const DUCK_RELEASE := 0.8
const PA_RANGE := 45.0           ## loudspeakers farther than this stay silent
const PA_SPEAKERS := 3
const PA_FALLBACK_DB := -6.0     ## no loudspeaker in range: heard faintly anyway
const GUIDE_RANGE := 12.0
const RADIO_CLICK := 0.14        ## s of the click before Heniek speaks
const SPEED_OF_SOUND := 343.0

var enabled := false
var catalog: VoiceCatalog
var queue := VoiceQueue.new()
var duck := 0.0

var _line: StringName = &""
var _line_left := 0.0
var _radio_wait := 0.0
var _radio: AudioStreamPlayer
var _radio_fx: AudioStreamPlayer
var _pa_fallback: AudioStreamPlayer
var _speakers: Array = []         ## loudspeakers playing the current line
var _guide_stand: Node3D = null
var _night := 0
var _night_clock := -1.0          ## < 0: no night running
var _fired: Dictionary = {}       ## night_time lines fired this night
var _witching := false
var _died := false
var _since_progress := 0.0
var _since_nudge := STALL_GAP
var _goal: StringName = &""


func _ready() -> void:
	enabled = AudioContext.automatic()
	catalog = VoiceCatalog.load_default()
	_radio = _player(&"VoiceRadio")
	_radio_fx = _player(&"VoiceRadio")
	_pa_fallback = _player(&"VoiceSystem")
	_pa_fallback.volume_db = PA_FALLBACK_DB
	Events.night_started.connect(_on_night_started)
	Events.power_cut.connect(func() -> void: trigger(&"power_cut", {}))
	Events.witching_hour.connect(_on_witching_hour)
	Events.dawn_broke.connect(_on_dawn_broke)
	Events.room_entered.connect(_on_room_entered)
	Events.guardian_awakened.connect(func(_node: Node, id: StringName) -> void:
		trigger(&"guardian_awakened", {"guardian": id}))
	Events.guardian_defeated.connect(func(id: StringName) -> void:
		_progress()
		trigger(&"guardian_defeated", {"guardian": id}))
	Events.shard_collected.connect(func(_shard: StringName, count: int) -> void:
		_progress()
		trigger(&"shard_collected", {"count": count}))
	Events.seal_collected.connect(func(_seal: StringName) -> void:
		_progress()
		trigger(&"seal_collected", {}))
	Events.gate_opened.connect(func(_gate: StringName) -> void:
		_progress()
		trigger(&"gate_opened", {}))
	Events.goal_changed.connect(func(goal: StringName) -> void:
		_goal = goal
		_progress())
	Events.boss_awakened.connect(func(_boss: Node) -> void: trigger(&"boss_awakened", {}))
	Events.boss_defeated.connect(func(_boss: Node) -> void: trigger(&"boss_defeated", {}))
	Events.player_died.connect(_on_player_died)
	Events.player_damaged.connect(func(_amount: float, _from: Vector3) -> void: queue.calm_time = 0.0)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)


func _player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _process(delta: float) -> void:
	if enabled:
		advance(delta)


## Everything that moves with time; tests call it directly.
func advance(dt: float) -> void:
	_tick_night(dt)
	_tick_stall(dt)
	if _line != &"":
		_tick_line(dt)
	var key := queue.advance(dt, _calm())
	if key != &"":
		_start(key)
	_tick_duck(dt)


func reset() -> void:
	_silence()
	queue.clear()
	duck = 0.0
	_set_duck(&"Music", 0.0)
	_set_duck(&"Ambience", 0.0)
	_night = 0
	_night_clock = -1.0
	_fired.clear()
	_witching = false
	_died = false
	_since_progress = 0.0
	_since_nudge = STALL_GAP
	_goal = &""


func current_line() -> StringName:
	return _line


func line_left() -> float:
	return _line_left


## Queues every unheard line whose rule fits [param event]. Returns how many.
func trigger(event: StringName, payload: Dictionary) -> int:
	if not enabled:
		return 0
	var fields := payload.duplicate()
	fields["night"] = _night
	var queued := 0
	for key in catalog.keys_for_event(event):
		var rule := catalog.line(key)
		if rule.get("once", true) and GameState.voice_heard.has(key):
			continue
		if not VoiceRules.matches(rule, fields):
			continue
		if queue.push(key, int(rule.get("priority", VoiceQueue.NORMAL)), float(rule.get("delay", 0.0))):
			queued += 1
	return queued


## The player pressed an audio-guide button. Plays the stand's recording (the
## night one once its condition holds); a second press stops it. A line on
## air (Heniek, the System) yields and comes back later from its start.
func play_guide(station: StringName, stand: Node3D) -> StringName:
	if _guide_stand == stand and _line != &"":
		stop_line()
		return &""
	if _line != &"":
		_cut()
	var key := catalog.guide_key(station, _guide_variant(station))
	if key == &"":
		return &""
	queue.hold(key)
	_guide_stand = stand
	var stream := catalog.stream(key)
	if stand.has_method(&"play_voice"):
		stand.play_voice(stream)
	_begin(key, _seconds(key, stream))
	return key


## Stops the line on air (the guide's second press, walking away). It counts as heard.
func stop_line() -> void:
	if _line == &"":
		return
	_stop_players()
	_finish()


func _guide_variant(station: StringName) -> StringName:
	var night := catalog.line(catalog.guide_key(station, &"b"))
	if night.is_empty():
		return &"a"
	if night.has("after_guardian") and GameState.is_guardian_defeated(StringName(night.after_guardian)):
		return &"b"
	if night.get("after_witching", false) and _witching:
		return &"b"
	return &"a"


func _start(key: StringName) -> void:
	var stream := catalog.stream(key)
	var seconds := _seconds(key, stream)
	match catalog.channel_of(key):
		&"radio":
			_radio_fx.stream = Sfx.stream_of(&"radio_click_in")
			if _radio_fx.stream:
				_radio_fx.play()
			_radio.stream = stream
			_radio_wait = RADIO_CLICK
			seconds += RADIO_CLICK
		&"pa":
			_play_pa(stream)
	_begin(key, seconds)


func _begin(key: StringName, seconds: float) -> void:
	_line = key
	_line_left = seconds
	line_started.emit(key, catalog.channel_of(key), seconds)


## Length of the recording, or a reading-speed estimate while a line has none yet.
func _seconds(key: StringName, stream: AudioStream) -> float:
	return stream.get_length() if stream else maxf(1.5, tr(key).length() / 14.0)


func _tick_line(dt: float) -> void:
	if _radio_wait > 0.0:
		_radio_wait -= dt
		if _radio_wait <= 0.0 and _radio.stream:
			_radio.play()
	_line_left -= dt
	if _guide_stand and _listener().distance_to(_guide_stand.global_position) > GUIDE_RANGE:
		stop_line()
	elif _line_left <= 0.0:
		_finish()


## The line ended (played out or stopped): heard, the queue is free.
func _finish() -> void:
	var key := _line
	if catalog.channel_of(key) == &"radio":
		_radio_fx.stream = Sfx.stream_of(&"radio_click_out")
		if _radio_fx.stream:
			_radio_fx.play()
	_line = &""
	_guide_stand = null
	_speakers = []
	queue.finished()
	GameState.mark_voice_heard(key)
	line_ended.emit(key)


## Cut without counting it heard: a Heniek/System line goes back to the queue,
## a guide recording just stops.
func _cut() -> void:
	var key := _line
	_stop_players()
	if catalog.channel_of(key) == &"guide":
		queue.finished()
	else:
		queue.interrupt()
	_line = &""
	_guide_stand = null
	_speakers = []
	line_ended.emit(key)


## Everything quiet, nothing heard (a new night, a death, a reset).
func _silence() -> void:
	if _line != &"":
		_stop_players()
		_line = &""
		_guide_stand = null
		_speakers = []
		queue.finished()
		line_ended.emit(&"")
	_radio_wait = 0.0


func _stop_players() -> void:
	_radio.stop()
	_radio_fx.stop()
	_pa_fallback.stop()
	for speaker in _speakers:
		if is_instance_valid(speaker):
			speaker.stop_voice()
	if is_instance_valid(_guide_stand) and _guide_stand.has_method(&"stop_voice"):
		_guide_stand.stop_voice()


func _play_pa(stream: AudioStream) -> void:
	var here := _listener()
	var near: Array = get_tree().get_nodes_in_group(&"loudspeakers").filter(
			func(s: Node3D) -> bool: return s.global_position.distance_to(here) <= PA_RANGE)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(here) < b.global_position.distance_to(here))
	_speakers = near.slice(0, PA_SPEAKERS)
	if _speakers.is_empty():
		_pa_fallback.stream = stream
		_pa_fallback.play()
		return
	var nearest: float = _speakers[0].global_position.distance_to(here)
	for speaker in _speakers:
		speaker.play_voice(stream, (speaker.global_position.distance_to(here) - nearest) / SPEED_OF_SOUND)


func _listener() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera else Vector3.ZERO


func _calm() -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera == null or PerceptionWorld.hunters_near(camera.global_position) == 0


func _tick_duck(dt: float) -> void:
	var target := 1.0 if _line != &"" else 0.0
	duck = move_toward(duck, target, dt / (DUCK_ATTACK if target > duck else DUCK_RELEASE))
	_set_duck(&"Music", DUCK_MUSIC_DB * duck)
	_set_duck(&"Ambience", DUCK_AMBIENCE_DB * duck)


func _set_duck(bus: StringName, db: float) -> void:
	var effect := duck_effect(bus)
	if effect:
		effect.volume_db = db


## The "VoiceDuck" amplifier on [param bus] (default_bus_layout.tres), or null.
## Bus volumes belong to Settings, so ducking only ever touches this effect.
static func duck_effect(bus: StringName) -> AudioEffectAmplify:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return null
	for i in AudioServer.get_bus_effect_count(index):
		var effect := AudioServer.get_bus_effect(index, i)
		if effect is AudioEffectAmplify and effect.resource_name == "VoiceDuck":
			return effect
	return null


func _tick_night(dt: float) -> void:
	if _night_clock < 0.0:
		return
	_night_clock += dt
	for key in catalog.keys_for_event(&"night_time"):
		var rule := catalog.line(key)
		if _fired.has(key) or float(rule.get("at", 0.0)) > _night_clock:
			continue
		_fired[key] = true
		if rule.get("once", true) and GameState.voice_heard.has(key):
			continue
		if VoiceRules.matches(rule, {"night": _night}):
			queue.push(key, int(rule.get("priority", VoiceQueue.NORMAL)), float(rule.get("delay", 0.0)))


func _tick_stall(dt: float) -> void:
	if _night_clock < 0.0:
		return
	_since_progress += dt
	_since_nudge += dt
	if _since_progress >= STALL_TIME and _since_nudge >= STALL_GAP:
		_since_nudge = 0.0
		trigger(&"stall", {"goal": _goal})


func _progress() -> void:
	_since_progress = 0.0


func _on_night_started(night: int, _modifier: StringName) -> void:
	_silence()
	queue.clear()
	_night = night
	_night_clock = 0.0
	_fired.clear()
	_witching = false
	_progress()
	_since_nudge = STALL_GAP
	trigger(&"night_started", {})
	if _died:
		_died = false
		_comment_death()


func _comment_death() -> void:
	var state := GameState.voice_state
	if int(state.get("death_night", -1)) == _night:
		return
	var turn := String(state.get("death_turn", "heniek"))
	for key in catalog.keys_for_event(&"death"):
		var rule := catalog.line(key)
		if String(rule.get("speaker", "")) != turn or GameState.voice_heard.has(key):
			continue
		if VoiceRules.matches(rule, {"night": _night}) and queue.push(key, VoiceQueue.SIDE, DEATH_DELAY):
			state["death_night"] = _night
			state["death_turn"] = "system" if turn == "heniek" else "heniek"
			return


func _on_player_died() -> void:
	_silence()
	_died = true


func _on_witching_hour() -> void:
	_witching = true
	trigger(&"witching_hour", {})


func _on_dawn_broke() -> void:
	trigger(&"dawn_broke", {})
	_night_clock = -1.0


func _on_room_entered(_room: StringName, zone: StringName, first_visit: bool) -> void:
	if first_visit:
		_progress()
		trigger(&"room_entered", {"zone": zone})


func _on_enemy_destroyed(_enemy: Node, _info: DamageInfo, _finisher: bool) -> void:
	var count := int(GameState.voice_state.get("destroyed", 0)) + 1
	GameState.voice_state["destroyed"] = count
	trigger(&"destroyed", {"count": count})
```
Uwaga do testu „kolejności”: `_comment_death()` wybiera **pierwszą** niewysłuchaną kwestię `death` mówiącego, którego jest kolej; gdy taka nie istnieje — nic się nie zmienia (kolej zostaje).

- [x] **Step 4: `project.godot`** — w `[autoload]` po `Foley`: `VoiceDirector="*res://src/audio/voice/voice_director.gd"`. `tests/test_runner.gd` `_reset_globals()`: `VoiceDirector.reset()` (po `RunState.reset()`).
- [x] **Step 5: Uruchom** `--filter=voice` → wszystkie zielone (także `test_music_and_ambience_have_a_duck_effect_at_zero` z zadania 7).
- [x] **Step 6: Pełny zestaw** `bash tools/run_tests.sh` → zielony (zwróć uwagę na testy, które liczą autoloady albo węzły w drzewie).
- [x] **Step 7: Commit** `git commit -m "VoiceDirector: events to lines, one voice at a time, radio/loudspeakers/guide, ducking, heard lines, death and stall remarks"`

### Task 12: Napisy

**Files:**
- Create: `src/ui/subtitle_bar.gd`, `tests/integration/test_subtitle_bar.gd`
- Modify: `src/audio/voice/voice_director.gd` (`_ready`: `add_child(SubtitleBar.new())` — pasek słucha sygnałów reżysera)

- [x] **Step 1: Test** `tests/integration/test_subtitle_bar.gd`
```gdscript
extends TestCase

var bar: SubtitleBar


func before_each() -> void:
	bar = SubtitleBar.new()
	add_child(bar)


func test_a_line_shows_who_speaks_and_what_in_the_game_language() -> void:
	TranslationServer.set_locale("pl")
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	assert_true(bar.is_showing())
	assert_eq(bar.speaker_text(), tr("VOICE_SPEAKER_HENIEK"))
	assert_true(tr("VO_HENIEK_NIGHT_1").begins_with(bar.current_text().substr(0, 10)))
	TranslationServer.set_locale("en")
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	assert_true(bar.current_text().begins_with("Kid?"))
	TranslationServer.set_locale("pl")


func test_long_lines_come_in_parts_timed_by_length() -> void:
	var parts := SubtitleBar.split("One two three. Four five six seven. Eight nine.", 20)
	assert_eq(parts.size(), 3)
	var ends := SubtitleBar.timings(parts, 9.0)
	assert_almost_eq(ends[ends.size() - 1], 9.0, 0.001)
	assert_true(ends[0] < ends[1] and ends[1] < ends[2])


func test_the_bar_follows_the_parts_and_hides_at_the_end() -> void:
	bar.show_line(&"VO_GUIDE_ROSETTA_A", &"guide", 12.0)
	var first := bar.current_text()
	bar.advance(11.0)
	assert_ne(bar.current_text(), first, "a later part")
	bar.clear_line(&"VO_GUIDE_ROSETTA_A")
	assert_false(bar.is_showing())


func test_subtitles_off_hides_the_bar() -> void:
	Settings.set_value(&"subtitles", false)
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	assert_false(bar.is_showing())
```

- [x] **Step 2: Uruchom** `--filter=subtitle` → czerwone.

- [x] **Step 3: `src/ui/subtitle_bar.gd`**
```gdscript
class_name SubtitleBar
extends CanvasLayer
## Subtitles of the voice lines: who speaks (in their colour) and what, in the
## game's language (Polish players hear English and read Polish). Sits above
## the HUD's hint strip; long lines come in parts timed by their length.

const LAYER := 13
const BOTTOM := 240              ## px above the bottom edge (the hint strip is at 170)
const MAX_CHARS := 110
const WIDTH := 1100.0
const COLOURS := {&"radio": Color(0.91, 0.67, 0.33), &"pa": Color(0.55, 0.82, 0.95), &"guide": Color(0.55, 0.82, 0.95)}
const LABELS := {&"radio": "VOICE_SPEAKER_HENIEK", &"pa": "VOICE_SPEAKER_SYSTEM", &"guide": "VOICE_SPEAKER_GUIDE"}

var _panel: PanelContainer
var _who: Label
var _text: Label
var _key: StringName = &""
var _parts: PackedStringArray = []
var _ends: PackedFloat32Array = []
var _elapsed := 0.0


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.03, 0.78)
	style.set_content_margin_all(14.0)
	_panel.add_theme_stylebox_override(&"panel", style)
	var column := VBoxContainer.new()
	_who = UiTheme.label("", 18, UiTheme.ACCENT)
	_text = UiTheme.label("", 26, UiTheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = WIDTH
	column.add_child(_who)
	column.add_child(_text)
	_panel.add_child(column)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, BOTTOM)
	_panel.visible = false
	var director := get_parent()
	if director and director.has_signal(&"line_started"):
		director.line_started.connect(show_line)
		director.line_ended.connect(clear_line)


func show_line(key: StringName, channel: StringName, seconds: float) -> void:
	_key = key
	_parts = split(tr(key), MAX_CHARS)
	_ends = timings(_parts, seconds)
	_elapsed = 0.0
	_who.text = tr(LABELS.get(channel, "VOICE_SPEAKER_SYSTEM"))
	_who.add_theme_color_override(&"font_color", COLOURS.get(channel, UiTheme.TEXT))
	_text.text = _parts[0] if _parts.size() > 0 else ""
	_panel.visible = Settings.data.subtitles and _text.text != ""


func clear_line(key: StringName) -> void:
	if key == _key or key == &"":
		_key = &""
		_panel.visible = false


func _process(delta: float) -> void:
	if _key != &"":
		advance(delta)


func advance(dt: float) -> void:
	_elapsed += dt
	for i in _ends.size():
		if _elapsed < _ends[i]:
			_text.text = _parts[i]
			return
	_text.text = _parts[_parts.size() - 1] if _parts.size() > 0 else ""


func is_showing() -> bool:
	return _panel.visible


func speaker_text() -> String:
	return _who.text


func current_text() -> String:
	return _text.text


## Sentences grouped greedily into parts of at most [param max_chars] (a longer
## sentence stays whole).
static func split(text: String, max_chars: int) -> PackedStringArray:
	var parts: PackedStringArray = []
	var current := ""
	var regex := RegEx.create_from_string("[^.!?…]+[.!?…]*\\s*")
	for found in regex.search_all(text):
		var sentence := found.get_string().strip_edges()
		if sentence == "":
			continue
		if current != "" and current.length() + 1 + sentence.length() > max_chars:
			parts.append(current)
			current = sentence
		else:
			current = sentence if current == "" else current + " " + sentence
	if current != "":
		parts.append(current)
	return parts


## End time of each part, proportional to its length, the last one at [param seconds].
static func timings(parts: PackedStringArray, seconds: float) -> PackedFloat32Array:
	var total := 0
	for part in parts:
		total += part.length()
	var ends: PackedFloat32Array = []
	var acc := 0
	for part in parts:
		acc += part.length()
		ends.append(seconds * acc / maxf(1.0, total))
	return ends
```
(`UiTheme.label(text, size, color, font) -> Label` — `src/ui/ui_theme.gd:81`.)
- [x] **Step 4: `voice_director.gd` `_ready()`**: na końcu `add_child(SubtitleBar.new())`.
- [x] **Step 5: Uruchom** `--filter=subtitle,voice` → zielone.
- [x] **Step 6: Commit** `git commit -m "Subtitles for the voice lines (speaker in colour, game language, timed parts, option)"`

### Task 13: Kliknięcia radia

**Files:**
- Modify: `tools/sfx/gen_sfx.py`, `src/fx/sfx.gd` (`SOUNDS` += `&"radio_click_in"`, `&"radio_click_out"`)
- Create: `assets/sfx/radio_click_in.wav`, `assets/sfx/radio_click_out.wav` (generowane)

- [x] **Step 1:** W `gen_sfx.py` (styl istniejących generatorów, tylko stdlib, ziarno z nazwy): `radio_click_in` — 4 ms klik (impuls + krótki szum), potem 110 ms szumu w paśmie ~400–3000 Hz opadającego do zera; `radio_click_out` — klik, 180 ms „ogona” szumu (squelch) opadającego szybciej, drugi cichszy klik na końcu. Szczyt ≤ −6 dBFS.
- [x] **Step 2:** `python tools/sfx/gen_sfx.py radio_click_in radio_click_out` (tym Pythonem, którego używa reszta efektów), import Godota.
- [x] **Step 3:** Test w `tests/unit/test_voice_buses.gd`:
```gdscript
func test_the_radio_clicks_exist() -> void:
	for sound in [&"radio_click_in", &"radio_click_out"]:
		assert_not_null(Sfx.stream_of(sound), String(sound))
		assert_lt(Sfx.stream_of(sound).get_length(), 0.4)
```
- [x] **Step 4:** `--filter=voice` zielone. **Commit** `git commit -m "Radio clicks for Heniek's walkie-talkie"`

### Task 14: Rekwizyty — głośnik i stojak audioprzewodnika

**Files:**
- Create: `tools/art/models/loudspeaker.py`, `tools/art/models/audioguide_stand.py`, `src/props/loudspeaker.gd`, `src/props/audioguide_stand.gd`, `tests/integration/test_voice_props.gd`
- Modify: `tools/art/build_models.py` (`ALL`), `src/style/art_library.gd` (`REGISTRY`), `src/world/world_features.gd` (budowa z markerów), `src/level/floor1/zones/court.gd`, `src/level/floor1/zones/egypt.gd` (markery)

- [x] **Step 1: Modele** (wzór: `tools/art/models/emergency_light.py`, części jak w `emergency_cabinet.py`; styl zestawu: grube bryły, pikselowe tekstury):
  - `loudspeaker` — skrzynka ok. 0,34 × 0,24 × 0,14 m z kratką (pas otworów w teksturze), uchwyt ścienny, mała soczewka kontrolki; nowoczesny, szarobiały plastik (świeżo zainstalowany „System” — lekki dysonans z XIX-wiecznym wnętrzem jest zamierzony); tył przy x/z = 0 (montaż na ścianie).
  - `audioguide_stand` — słupek ok. 1,05 m, skośny pulpit z numerem stanowiska (tablica do podmiany w teksturze: „1”), duży okrągły przycisk (osobna część `button`, mosiądz) i kratka głośniczka; podstawa ciężka, nie do przeoczenia jako obiekt interaktywny (#39).
  - Dopisz do `ALL`, `bash tools/art/build_art.sh loudspeaker audioguide_stand`, obejrzyj `tests/_out/art/*.png` (podgląd renderowany headless), dopisz do `ArtLibrary.REGISTRY` (`&"loudspeaker": ["loudspeaker"]`, `&"audioguide_stand": ["audioguide_stand", "button"]`).
- [x] **Step 2: Test** `tests/integration/test_voice_props.gd`
```gdscript
extends TestCase


func test_a_loudspeaker_joins_the_group_and_plays_after_its_delay() -> void:
	var speaker := Loudspeaker.create(Transform3D.IDENTITY)
	add_child(speaker)
	assert_true(speaker.is_in_group(&"loudspeakers"))
	var stream := VoiceDirector.catalog.stream(&"VO_SYSTEM_CLOSING_1")
	speaker.play_voice(stream, 0.05)
	assert_false(speaker.is_speaking())
	speaker.advance(0.1)
	assert_true(speaker.is_speaking())
	assert_eq(speaker.player.bus, &"VoiceSystem")
	assert_true(speaker.player.area_mask & Layers.REVERB_ZONE != 0, "hears the reverb zones")
	speaker.stop_voice()
	assert_false(speaker.is_speaking())


func test_a_stand_is_interactable_and_asks_the_director() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	var stand := AudioguideStand.create(&"rosetta", Transform3D.IDENTITY)
	add_child(stand)
	assert_eq(stand.prompt(), tr("PROMPT_AUDIOGUIDE"))
	stand.interact(null)
	assert_eq(VoiceDirector.current_line(), &"VO_GUIDE_ROSETTA_A")
	stand.interact(null)
	assert_eq(VoiceDirector.current_line(), &"")
	VoiceDirector.enabled = false


func test_floor1_places_loudspeakers_and_the_rosetta_stand() -> void:
	var layout := Floor1Layout.create()
	var speakers := layout.markers.keys().filter(func(k): return String(k).begins_with("loudspeaker_"))
	assert_gt(speakers.size(), 2)
	assert_true(layout.markers.has(&"audioguide_rosetta"))
```
- [x] **Step 3: `src/props/loudspeaker.gd`**
```gdscript
class_name Loudspeaker
extends Node3D
## A wall loudspeaker of the museum's System. VoiceDirector plays the System's
## lines through the nearest few, each a little later by its extra distance.

const MODEL := &"loudspeaker"

var player: AudioStreamPlayer3D
var _delay := -1.0


static func create(at: Transform3D) -> Loudspeaker:
	var speaker := Loudspeaker.new()
	speaker.transform = at
	return speaker


func _ready() -> void:
	add_to_group(&"loudspeakers")
	var model := ArtLibrary.try_instance(MODEL)
	if model == null:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.mesh.size = Vector3(0.34, 0.24, 0.14)
		box.position = Vector3(0.0, 0.0, 0.07)
		model = box
	add_child(model)
	player = AudioStreamPlayer3D.new()
	player.bus = &"VoiceSystem"
	player.unit_size = 10.0
	player.max_distance = 60.0
	player.area_mask = Layers.REVERB_ZONE
	player.position = Vector3(0.0, 0.0, 0.15)
	add_child(player)


func play_voice(stream: AudioStream, delay := 0.0) -> void:
	player.stream = stream
	_delay = delay
	if delay <= 0.0:
		_delay = -1.0
		player.play()


func stop_voice() -> void:
	_delay = -1.0
	player.stop()


func is_speaking() -> bool:
	return player.playing


func _process(delta: float) -> void:
	if _delay >= 0.0:
		advance(delta)


func advance(dt: float) -> void:
	if _delay < 0.0:
		return
	_delay -= dt
	if _delay < 0.0:
		player.play()
```
(W teście z dźwiękiem Dummy `player.playing` po `play()` powinno być `true`; jeśli nie jest, `is_speaking()` niech zwraca flagę ustawianą w `play()` i zerowaną w `stop_voice()` / po `stream.get_length()`.)
- [x] **Step 4: `src/props/audioguide_stand.gd`**
```gdscript
class_name AudioguideStand
extends Interactable
## An audio-guide stand at an exhibit: press E to hear the System's recording
## (day version; the night one once its condition holds — VoiceDirector).

const MODEL := &"audioguide_stand"

var station: StringName
var player: AudioStreamPlayer3D


static func create(station_id: StringName, at: Transform3D) -> AudioguideStand:
	var stand := AudioguideStand.new()
	stand.station = station_id
	stand.transform = at
	stand.prompt_key = "PROMPT_AUDIOGUIDE"
	return stand


func _ready() -> void:
	add_box(Vector3(0.5, 1.1, 0.4), Vector3(0.0, 0.55, 0.0))
	var model := ArtLibrary.try_instance(MODEL)
	if model == null:
		var post := MeshInstance3D.new()
		post.mesh = BoxMesh.new()
		post.mesh.size = Vector3(0.3, 1.05, 0.3)
		post.position = Vector3(0.0, 0.525, 0.0)
		model = post
	add_child(model)
	player = AudioStreamPlayer3D.new()
	player.bus = &"VoiceSystem"
	player.unit_size = 4.0
	player.max_distance = VoiceDirector.GUIDE_RANGE + 4.0
	player.area_mask = Layers.REVERB_ZONE
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)


func interact(by: Node) -> void:
	if not enabled:
		return
	super(by)
	VoiceDirector.play_guide(station, self)


func play_voice(stream: AudioStream, _delay := 0.0) -> void:
	player.stream = stream
	player.play()


func stop_voice() -> void:
	player.stop()
```
- [x] **Step 5: `world_features.gd`** — przy innych budowniczych markerów (`_build_notes` itd.):
```gdscript
func _build_voice_props() -> void:
	for id in _marker_ids("loudspeaker_"):
		add_child(Loudspeaker.create(level.markers[id]))
	for id in _marker_ids("audioguide_"):
		add_child(AudioguideStand.create(StringName(String(id).trim_prefix("audioguide_")), level.markers[id]))
```
i wywołanie obok pozostałych (dopasuj nazwy pól do pliku).
- [x] **Step 6: Markery** (G1 — tylko tyle, ile trzeba do sprawdzenia całości; pełne rozmieszczenie w G2):
  - `court.gd`: `loudspeaker_court_1`, `loudspeaker_court_2` — na ścianach Dziedzińca, ok. 3,2 m nad posadzką, przodem do środka (yaw), w różnych końcach;
  - `egypt.gd`: `loudspeaker_egypt_1` nad wejściem do Przedsionka Rosetty od strony skrzydła; `audioguide_rosetta` w Przedsionku Rosetty, ok. 1,5 m przed Kamieniem, przodem do gracza wchodzącego z Dziedzińca, z dala od osi przejścia.
  - Pozycje z geometrii sal w tych plikach (granice pomieszczeń); po zmianie pomieszczeń: `bash tools/bake_shell_cache.sh` (jeśli markery wpływają na skorupę — zwykle nie).
- [x] **Step 7: Uruchom** `--filter=voice_props,world,w7,art` → zielone; potem pełny zestaw.
- [x] **Step 8: Commit** `git commit -m "Voice props: wall loudspeakers and the Rosetta audio-guide stand (Blender models, markers)"`

### Task 15: Dokumentacja i zamknięcie

**Files:**
- Modify: `docs/audio/dzwiek-przewodnik.html` (sekcja „Głos”), `docs/superpowers/specs/2026-10-08-glos-projekt.md` (nagłówek: stan G1), ten plan (sekcja „Stan prac”)

- [x] **Step 1:** W `dzwiek-przewodnik.html` sekcja „Głos”: kanały (Voice/VoiceRadio/VoiceSystem, VoiceDuck), jak dodać kwestię (klucz w `strings.csv` → wpis w `lines.json` → `bash tools/tts/build_voice.sh` → test `voice_data`), pola reguł, pseudo-zdarzenia, głośniki i stojaki (markery `loudspeaker_*`, `audioguide_<stanowisko>`), liczby startowe.
- [x] **Step 2:** Pełny zestaw `bash tools/run_tests.sh` → zielony; testy Pythona `cd tools/tts && .venv/Scripts/python.exe -m unittest -v` → OK.
- [x] **Step 3:** Dopisz w tym planie sekcję „Stan prac / co dalej” (co zrobione, co czeka na wybór głosów, uwagi dla G2).
- [x] **Step 4: Commit** `git commit -m "Voice G1: docs (how to add a line), plan status"`. Scalanie do `pietro-1` robi kontroler.

---

## Poza G1 (etap G2, osobny plan po skrzydłach)
Wszystkie kwestie Heńka (ok. 50–70), Systemu (30–40) i przewodnika (ok. 12 stanowisk × 2), rozmieszczenie wszystkich głośników i stojaków, komentarze w kawiarni (#10/#32), strojenie liczb po teście właściciela.

## Stan prac / co dalej

**Wynik (8.10, po scaleniu `pietro-1` @4b3ded2):** pełny zestaw `bash tools/run_tests.sh` – 1972 testy, 0 błędów, bez linii ERROR; testy Pythona (`tools/tts`) – 13/13 OK. Wszystkie 15 zadań zrobione, po jednym commicie na zadanie.

> Gałąź `voice-g1` (od `pietro-1` @3b95f11), 8 października 2026. Wykonawca: jeden agent, bez okien i bez dźwięku.

### Zrobione (zadania 1–15)
- **Narzędzia** (`tools/tts/`, poza gitem `.venv/`, `.uv-cache/`, `models/`): venv Pythona 3.11 na D: z pakietami sesji `neuron-spike` (bez pobierania), model Kokoro ONNX fp16 + 11 głosów-kandydatów (`download_voices.py`), `kokoro_tts.py` (synteza, słowniczek IPA, cięcie na zdania, obejście NaN), `system_fx.py` (głos Systemu), `voice_data.py`, `generate_voice.py`, `voice_samples.py`, `build_voice.sh`; `encode_ogg.py` ma tryb `-- voice` (mono 24 kHz, 64 kbit/s, tylko zmienione pliki). Testy Pythona: `cd tools/tts && .venv/Scripts/python.exe -m unittest -v` (13 testów).
- **Dane**: `data/voice/{lines,speakers,lexicon}.json`, 4 kwestie próbne + 6 kluczy w `locale/strings.csv`, `export_presets.cfg` pakuje `data/voice/*.json`. Nagrania w `assets/voice/` z `manifest.json` (skróty).
- **Próbki głosów dla właściciela**: `build/voice-samples/index.html` (27 WAV: 6 głosów Heńka × czysty/radio, 5 głosów Systemu × czysty/stopień 1/stopień 2). **Nikt ich nie odtwarzał.**
- **Gra**: kanały `Voice`/`VoiceRadio`/`VoiceSystem` + `VoiceDuck` na Music/Ambience; opcje „Głosy” i „Napisy”; `VoiceCatalog`, `VoiceRules`, `VoiceQueue`, autoload `VoiceDirector` (zdarzenia → kolejka → radio/głośniki/stojak, ducking, zapis, śmierć na zmianę, zastój), `SubtitleBar`, zapis `GameState.voice_heard` / `voice_state`, kliknięcia radia (`radio_click_in/out`), rekwizyty `Loudspeaker` i `AudioguideStand` (modele Blendera `loudspeaker`, `audioguide_stand` z częścią `button`), markery: 2 głośniki na Dziedzińcu, 1 w Przedsionku Rosetty, stojak `audioguide_rosetta`. Sekcja „Głos” w `docs/audio/dzwiek-przewodnik.html`.

### Odstępstwa od planu
- **pyworld nie do zbudowania**: VS Build Tools 2022 bez Windows SDK (brak `math.h`), a pyworld 0.3.6 nie ma sdist (0.3.5 ma, ale nie kompiluje się bez SDK). Decyzja kontrolera (opcja C): `system_fx.py` to własny numpy – śledzenie wysokości YIN + TD-PSOLA; `resynthesize()` jest jedynym szwem, w który wszedłby WORLD, gdyby właściciel sam zainstalował Windows 11 SDK. Pomiar na prawdziwej mowie: stopień 1 trafia w docelową wysokość (mediana błędu 0,08 półtonu), rozrzut intonacji 3,5 → 1,05 półtonu, głośność i długość zachowane, 0,3 s na kwestię. `setup.sh` nie instaluje pyworld; uv łączy się z PyPI przez `UV_NATIVE_TLS=1` (certyfikaty tej maszyny).
- Test kanałów (zadanie 7) od początku zielony: `VoiceDirector.duck_effect` wszedł do testu w zadaniu 11 (wcześniej lokalny pomocnik), żeby każdy commit miał zielony zestaw.
- `test_side_remarks_are_three_minutes_apart`: arytmetyka planu była o 5 s za krótka (S2 czekało 55 s, próg wygaśnięcia to 60 s) – test najpierw sprawdza, że S2 jeszcze czeka, potem po 10 s, że przepadło.
- `voice_samples.py`: nazwy plików planu zlewały „stopień 1” i „stopień 2” w jeden plik (`label.split()[0]`) – osobne slugi `stopien1`/`stopien2`; katalog próbek dostaje `.gdignore` (Godot importował WAV-y), tak samo `build/audio_src`.
- Kratka głośnika rysowana na siatce texeli (4 texele = jeden otwór), bo otwory 9 mm przy 256 px/m dawały morę.
- Dodatkowe testy poza planem: licznik `VoiceDirector.stall_nudges` (zastój), test wyłączonego reżysera, drugi głośnik w zasięgu / poza zasięgiem, etykiety i kolory napisów, `clear()` kolejki.

### Wybór właściciela (8.10, po odsłuchu próbek)
- Heniek = `am_michael` (radio robi szyna `VoiceRadio`), System = `af_nicole` ze **stopniem 2 na co dzień** – właścicielowi podoba się, że brzmi jak nagranie ASMR z zacięciami w głosie (niesamowitość zamierzona). Brzmienia `system_fx.py` nie poprawiać. Wpisane do `speakers.json` (`fx_version` 2) i `lines.json`, nagrania wygenerowane na nowo.
- **Otwarte na G2:** plan miał stopnie 0/1/2 jako kroki zepsucia (zamknięcie czyste → noc maszynowa → godzina duchów/awaria uszkodzona). Skoro codzienny System to już 2, eskalacja z §2.2 projektu (godzina duchów, tryb awaryjny z baterii) potrzebuje wyrazu powyżej 2: kandydaci – stopień 3 w `system_fx.py` (gęstsze zacięcia, dłuższe ubytki, większe skoki, może wolniejsze tempo) do odsłuchu przez właściciela, albo tylko tekst i tempo. Na razie wszystkie kwestie Systemu (także `VO_GUIDE_ROSETTA_B`) mają stopień 2; stopnie 0/1 zostają w narzędziu.

### Po przeglądzie kodu (poprawki, 8.10)
- Reżyser: wyjście ze sceny gry (`SceneTree.scene_changed`, jak `Music`/`Ambience`) ucisza, czyści kolejkę i zatrzymuje zegar nocy; `_calm()` (skan percepcji) próbkowany ~4 Hz i tylko gdy coś czeka albo gra; klucze `night_time` i reguły per zdarzenie buforowane w `VoiceCatalog`; `_tick_duck` pomijany, gdy cisza i ducking 0; `_stop_players()` zeruje czekanie na klik radia (przerwana kwestia Heńka nie odzywała się pod przewodnikiem); czas liczony w czasie rzeczywistym (`delta / Engine.time_scale`), więc hitstop nie rozjeżdża napisów i duckingu; komentarz po śmierci przechodzi do drugiego mówiącego, gdy mówiący z kolei nie ma już niewysłuchanych kwestii.
- Testy z wstrzykniętymi kwestiami (`VoiceCatalog.add_line`, `reset()` je zrzuca): śmierć na zmianę i przekazanie kolei, `night_time`, próg `destroyed`, zastój z celem, `room_entered`/`guardian_awakened`; `test_voice_data` odrzuca nieznane pola reguł oraz `level`/`priority` poza 0–2.
- Stojak dostaje bryłę kolizji (`StaticBody3D` na warstwie świata). Napisy reagują na przełącznik „Napisy” w trakcie kwestii. `generate_voice.py` usuwa też WAV usuniętej kwestii; test, że każdy `.ogg` ma wpis w manifeście.
- **G2 (znany kompromis):** ogon pogłosu głośników i stojaków wraca przez `SFXReturn`, więc słychać go także przy „Głosy” = 0 – do naprawy osobną szyną powrotu pogłosu pod `Voice` (bez przebudowy układu szyn teraz).

### Do sprawdzenia w oknie (sesja okienkowa, bez dźwięku albo za zgodą)
- Pasek napisów nad paskiem podpowiedzi HUD (warstwa 13, 240 px od dołu): czytelność, kolory mówiących, podział długiej kwestii.
- Głośniki na ścianach Dziedzińca (x = ±29,85, y = 3,2, z = ±12) i nad drzwiami Przedsionka Rosetty (−31,05, 4,6, 23): czy nie wchodzą w banery/sztukaterię; stojak przy Kamieniu (−40,7, 0, 24) – czy nie zasłania osi przejścia; podgląd modeli `tests/_out/art/{loudspeaker,audioguide_stand}.png`.
- Odsłuch: radio Heńka (kanał `VoiceRadio` + kliknięcia), echo między głośnikami, ducking muzyki.

### Uwagi dla G2
- Kwestie `death`, `destroyed`, `stall`, `night_time` mają reguły i testy, ale żadnych wpisów w danych – `test_a_death_is_commented_at_the_next_night_by_turns` zaczyna sprawdzać, gdy pojawią się kwestie `death` obu mówiących.
- Stojaki: `audioguide_<stanowisko>` + para `VO_GUIDE_<X>_A/B` w `lines.json`; stanowiska hubu z `after_witching: true`.
- Pełne rozmieszczenie głośników (po jednym przy wejściu do każdego skrzydła) i kawiarnia (#10/#32).
- Pogłos głosu przez `SFXReturn` (wyżej) i wyraz eskalacji Systemu powyżej stopnia 2 (wyżej).
