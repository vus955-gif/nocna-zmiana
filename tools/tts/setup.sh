#!/usr/bin/env bash
# One-time setup of the voice tools, all on D: (tools/tts/, gitignored):
# Python 3.11 venv with the packages of the earlier Kokoro session (copied, no
# download), the Kokoro ONNX model and the candidate voices. The System's
# voice processing (system_fx.py) is plain numpy, so nothing is compiled.
#   bash tools/tts/setup.sh /path/to/neuron-spike
set -euo pipefail
cd "$(dirname "$0")"
FROM="${1:?folder of the earlier session (has .venv-tts and models/)}"
export UV_CACHE_DIR="$PWD/.uv-cache"
export UV_NATIVE_TLS=1   # this machine's PyPI certificate chain is only in the system store
PY=.venv/Scripts/python.exe
[ -x "$PY" ] || uv venv .venv --python 3.11
cp -rn "$FROM/.venv-tts/Lib/site-packages/." .venv/Lib/site-packages/
mkdir -p models/voices
[ -f models/model_fp16.onnx ] || cp "$FROM/models/model_fp16.onnx" models/
[ -f models/voices/af_heart.bin ] || cp "$FROM/models/af_heart.bin" models/voices/
"$PY" download_voices.py
"$PY" -c "import kokoro_onnx, onnxruntime, espeakng_loader, soundfile, numpy; print('tts ok')"
