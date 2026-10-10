"""Numbers instead of ears: loudness, peaks, spectrum balance and loop seams.

    python tools/music/analyze.py assets/music/*.wav assets/ambience/*.wav

For every file: length, integrated loudness (BS.1770, LUFS), loudest 3 s
(short-term max), sample and true peak (dBFS), DC, stereo correlation,
energy share per band, and for loops (all but *_sting / one-shots) the
seam check: the jump from the last sample to the first against the
track's own sample-to-sample steps, high-frequency energy around the seam
against the median (a click shows up as a big ratio) and the level of the
last vs the first 50 ms.
"""
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dsp  # noqa: E402

BANDS = [("sub", 20, 60), ("low", 60, 250), ("lowmid", 250, 1000), ("mid", 1000, 4000), ("high", 4000, 10000),
         ("air", 10000, 22050)]


def band_shares(x):
    m = dsp.mono(x)
    spec = np.abs(np.fft.rfft(m)) ** 2
    f = np.fft.rfftfreq(m.shape[0], 1.0 / dsp.SR)
    total = spec[f >= 20].sum() or 1.0
    return {name: float(spec[(f >= lo) & (f < hi)].sum() / total) for name, lo, hi in BANDS}


def seam(x):
    """Loop seam metrics (x plays again from sample 0 after its last)."""
    x = dsp.stereo(x)
    steps = np.abs(np.diff(x, axis=0))
    typical = np.percentile(steps, 99.9, axis=0)
    jump = np.abs(x[0] - x[-1])
    hf = dsp.fft_filter(x, dsp.g_highpass(6000.0, 4), circular=True)
    power = np.sum(hf ** 2, axis=1)
    win = dsp.n_of(0.005)
    c = np.concatenate([[0.0], np.cumsum(np.concatenate([power, power[:win]]))])
    energy = c[win:] - c[:-win]
    around = float(np.sum(np.concatenate([power[-win // 2:], power[:win // 2]])))
    # loops start on a downbeat, so the seam window is compared with the
    # loud windows (onsets) of the track, not with its median
    p99 = float(np.percentile(energy[:x.shape[0]], 99.0)) or 1e-20
    loudest = float(np.max(energy[:x.shape[0]])) or 1e-20
    tail = dsp.rms(x[-dsp.n_of(0.05):])
    head = dsp.rms(x[:dsp.n_of(0.05)])
    return {
        "jump_vs_p999": float(np.max(jump / np.maximum(typical, 1e-9))),
        "hf_ratio": around / p99,
        "hf_vs_max": around / loudest,
        "edge_db": float(dsp.to_db(max(tail, 1e-9)) - dsp.to_db(max(head, 1e-9))),
    }


def _png(path, gray):
    """Writes an 8-bit grayscale PNG (no dependencies)."""
    import struct
    import zlib
    h, w = gray.shape
    raw = b"".join(b"\x00" + gray[row].astype(np.uint8).tobytes() for row in range(h))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def spectrogram(x, path, start=0.0, seconds=None, width=1400, height=360, fmin=30.0, fmax=16000.0, floor_db=-80.0):
    """Log-frequency spectrogram PNG (bright = loud), for eyeballing notes,
    rhythm and sections."""
    m = dsp.mono(x)
    a = dsp.n_of(start)
    b = m.shape[0] if seconds is None else min(m.shape[0], a + dsp.n_of(seconds))
    m = m[a:b]
    size = 4096
    hop = max((m.shape[0] - size) // width, 1)
    window = np.hanning(size)
    freqs = np.fft.rfftfreq(size, 1.0 / dsp.SR)
    rows = np.geomspace(fmin, fmax, height)
    idx = np.clip(np.searchsorted(freqs, rows), 0, freqs.size - 1)
    cols = []
    for c in range(width):
        seg = m[c * hop:c * hop + size]
        if seg.shape[0] < size:
            seg = np.pad(seg, (0, size - seg.shape[0]))
        spec = np.abs(np.fft.rfft(seg * window)) / (size / 4)
        cols.append(dsp.to_db(spec[idx]))
    img = np.array(cols).T[::-1]
    img = np.clip((img - floor_db) / -floor_db, 0.0, 1.0) * 255.0
    _png(path, img)


def report(x, name="", loop=True):
    x = np.asarray(x, dtype=float)
    st = dsp.stereo(x)
    info = {
        "name": name,
        "seconds": st.shape[0] / dsp.SR,
        "lufs": dsp.lufs(st, circular=loop),
        "st_max": dsp.short_term_max(st, circular=loop),
        "peak_db": float(dsp.to_db(dsp.peak(st))),
        "true_peak_db": dsp.true_peak(st),
        "dc": float(np.max(np.abs(st.mean(axis=0)))),
        "corr": float(np.corrcoef(st[:, 0], st[:, 1])[0, 1]) if x.ndim == 2 and np.std(st[:, 0]) > 0 else 1.0,
        "bands": band_shares(st),
    }
    if loop:
        info["seam"] = seam(st)
    return info


def format_report(info):
    bands = " ".join(f"{k}={v * 100:.0f}%" for k, v in info["bands"].items())
    line = (f"{info['name']:<34} {info['seconds']:7.2f}s  {info['lufs']:6.1f} LUFS  st-max {info['st_max']:6.1f}  "
            f"peak {info['peak_db']:5.1f}  tp {info['true_peak_db']:5.1f} dBFS  corr {info['corr']:.2f}\n"
            f"{'':<34} {bands}")
    if "seam" in info:
        s = info["seam"]
        line += (f"\n{'':<34} seam: jump/p99.9={s['jump_vs_p999']:.2f} hf/p99={s['hf_ratio']:.2f} "
                 f"hf/max={s['hf_vs_max']:.2f} edge={s['edge_db']:+.1f} dB")
    return line


def best_lag(decoded, reference, max_lag=4096):
    """Lag k (samples) with decoded[n] ~ reference[n + k], by FFT
    cross-correlation of the mono sums (search +-max_lag)."""
    a = dsp.mono(decoded)
    b = dsp.mono(reference)
    size = dsp.fast_len(a.shape[0] + b.shape[0])
    corr = np.fft.irfft(np.conj(np.fft.rfft(a, size)) * np.fft.rfft(b, size), size)
    lags = np.concatenate([np.arange(0, max_lag + 1), np.arange(-max_lag, 0)])
    values = np.concatenate([corr[:max_lag + 1], corr[-max_lag:]])
    return int(lags[np.argmax(values)])


def snr_db(decoded, reference):
    err = np.sum((decoded - reference) ** 2)
    return float(10.0 * np.log10(max(np.sum(reference ** 2), 1e-20) / max(err, 1e-20)))


def seams(root):
    """Compares the engine's decode of each looping .ogg (dumped by
    tests/support/decode_loops.gd) with its WAV intermediate: length, sample
    alignment of the start and on both sides of the wrap, error level, and
    whether the error spikes at the wrap (a click, a gap or padding)."""
    src_root = root / "build" / "audio_src"
    decoded = src_root / "decoded"
    worst = 0.0
    print(f"{'loop':<18} {'frames':>9} {'len diff':>8} {'lag head/pre/post':>18} {'snr pre/post dB':>16} {'seam err/p99.9':>15} {'step/p99.9':>11}")
    for info_path in sorted(decoded.glob("*.json")):
        name = info_path.stem
        info = json.loads(info_path.read_text())
        wav = next((p for p in (src_root / "music" / f"{name}.wav", src_root / "ambience" / f"{name}.wav") if p.exists()), None)
        if wav is None:
            print(f"{name:<18} no WAV intermediate")
            continue
        src = dsp.stereo(dsp.read_wav(wav))
        length = src.shape[0]
        pre = int(round(info["pre"] * dsp.SR))
        post = int(round(info["post"] * dsp.SR))
        wrap = np.fromfile(decoded / f"{name}_wrap.f32", dtype="<f4").reshape(-1, 2).astype(float)
        head = np.fromfile(decoded / f"{name}_head.f32", dtype="<f4").reshape(-1, 2).astype(float)
        margin = 4096
        # the source around the wrap, with room to slide it by a lag
        around_wrap = np.concatenate([src[length - pre - margin:], src[:post + margin]])
        expected = around_wrap[margin:margin + pre + post]
        lag_head = best_lag(head[margin:post - margin], src[margin:post - margin])
        lag_pre = best_lag(wrap[margin:pre - margin], expected[margin:pre - margin])
        lag_post = best_lag(wrap[pre + margin:pre + post - margin], expected[pre + margin:pre + post - margin])
        # a constant latency of the decoder is harmless as long as it is the
        # same on both sides of the wrap; compare against the shifted source
        expected = around_wrap[margin + lag_pre:margin + lag_pre + pre + post]
        err = wrap - expected
        err_mag = np.max(np.abs(err), axis=1)
        around = float(np.max(err_mag[pre - 256:pre + 256]))
        elsewhere = float(np.percentile(np.concatenate([err_mag[:pre - 256], err_mag[pre + 256:]]), 99.9)) or 1e-12
        steps = np.max(np.abs(np.diff(wrap, axis=0)), axis=1)
        step = float(np.max(steps[pre - 2:pre + 2]))
        typical = float(np.percentile(steps, 99.9)) or 1e-12
        ratio = around / elsewhere
        worst = max(worst, ratio, step / typical, 99.0 if not (lag_head == lag_pre == lag_post) else 0.0)
        print(f"{name:<18} {length:>9} {info['frames'] - length:>8.1f} {lag_head:>6}/{lag_pre:>5}/{lag_post:>5} "
              f"{snr_db(wrap[:pre], expected[:pre]):>7.1f}/{snr_db(wrap[pre:], expected[pre:]):>7.1f} "
              f"{ratio:>15.2f} {step / typical:>11.2f}")
    return worst


def main(args):
    """analyze.py [--png=DIR [--start=S] [--seconds=S]] files...
    analyze.py --seams   (after tests/support/decode_loops.gd)"""
    if "--seams" in args:
        worst = seams(Path(__file__).resolve().parents[2])
        print(f"worst seam ratio {worst:.2f} (a click, gap or padding at the wrap would be far above 2)")
        sys.exit(0 if worst < 3.0 else 1)
    png_dir, start, seconds = None, 0.0, None
    paths = []
    for arg in args:
        if arg.startswith("--png="):
            png_dir = Path(arg[6:])
        elif arg.startswith("--start="):
            start = float(arg[8:])
        elif arg.startswith("--seconds="):
            seconds = float(arg[10:])
        else:
            paths.append(arg)
    for path in paths:
        p = Path(path)
        x = dsp.read_wav(p)
        loop = not any(tag in p.stem for tag in ("sting", "shot_", "step_", "land_", "jump_", "gear_"))
        print(format_report(report(x, p.name, loop)))
        if png_dir is not None:
            png_dir.mkdir(parents=True, exist_ok=True)
            spectrogram(x, png_dir / f"{p.stem}.png", start, seconds)


if __name__ == "__main__":
    main(sys.argv[1:])
