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
