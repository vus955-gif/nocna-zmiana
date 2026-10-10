"""Windowless previews of the paper museum map (W6).

Reads the drawing operations Godot recorded (tests/support/map_preview.gd ->
tests/_out/map/*.json, MapRecorder's format) and draws them with pycairo:
  <name>_sheet.png   the whole sheet, every layer (paper, print, wear, the
                     wings' and rooms' names, the pencil, "you are here")
  <name>_screen.png  what the guard sees on opening the map (1920 x 1080:
                     the view's zoom and centre, the names as faded as the
                     zoom makes them, the tabs and the hint line)
  <name>_close.png   the same, zoomed in
  poster.png         the wall poster's sheet
The pencil layer is masked by the graphite grain like the game's shader.
Usage: python tools/map/render_preview.py [dir] [name-filter]
"""
import json
import sys
from pathlib import Path

import cairo
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests" / "_out" / "map"
TEXTURES = {
    "paper": ROOT / "assets" / "ui" / "map" / "leaflet_paper.jpg",
    "wear": ROOT / "assets" / "ui" / "map" / "leaflet_wear.png",
}
GRAIN = ROOT / "assets" / "ui" / "map" / "graphite_grain.png"
GRAIN_TILE = 256.0
GRAIN_FLOOR = 0.42
LAYER_ORDER = ["shadow", "paper", "print", "wear", "wings", "names", "pencil", "here"]

_surfaces = {}


def surface_from_rgba(arr):
    """numpy RGBA uint8 -> cairo ARGB32 (premultiplied) surface."""
    h, w = arr.shape[:2]
    rgba = arr.astype(np.float32) / 255.0
    a = rgba[:, :, 3:4]
    pre = np.concatenate([rgba[:, :, :3] * a, a], axis=2)
    bgra = (pre[:, :, [2, 1, 0, 3]] * 255.0 + 0.5).astype(np.uint8)
    stride = cairo.ImageSurface.format_stride_for_width(cairo.FORMAT_ARGB32, w)
    data = np.zeros((h, stride), np.uint8)
    data[:, : w * 4] = bgra.reshape(h, w * 4)
    return cairo.ImageSurface.create_for_data(bytearray(data.tobytes()), cairo.FORMAT_ARGB32, w, h, stride)


def texture(name):
    if name not in _surfaces:
        img = Image.open(TEXTURES[name]).convert("RGBA")
        _surfaces[name] = surface_from_rgba(np.asarray(img))
    return _surfaces[name]


def grain_mask():
    if "grain" not in _surfaces:
        tooth = np.asarray(Image.open(GRAIN).convert("L"), np.float32) / 255.0
        alpha = GRAIN_FLOOR + (1.0 - GRAIN_FLOOR) * tooth
        rgba = np.zeros(tooth.shape + (4,), np.uint8)
        rgba[:, :, 3] = (alpha * 255.0 + 0.5).astype(np.uint8)
        _surfaces["grain"] = surface_from_rgba(rgba)
    return _surfaces["grain"]


def rgba(c, alpha=1.0):
    return c[0], c[1], c[2], c[3] * alpha


def draw_op(ctx, op, alpha=1.0):
    kind = op["op"]
    if kind == "rect":
        x, y, w, h = op["r"]
        ctx.rectangle(x, y, w, h)
        ctx.set_source_rgba(*rgba(op["c"], alpha))
        ctx.fill()
    elif kind == "poly":
        pts = op["pts"]
        ctx.move_to(pts[0], pts[1])
        for i in range(2, len(pts), 2):
            ctx.line_to(pts[i], pts[i + 1])
        ctx.close_path()
        ctx.set_source_rgba(*rgba(op["c"], alpha))
        ctx.fill()
    elif kind == "line":
        pts = op["pts"]
        ctx.move_to(pts[0], pts[1])
        for i in range(2, len(pts), 2):
            ctx.line_to(pts[i], pts[i + 1])
        if op.get("closed"):
            ctx.close_path()
        ctx.set_line_width(op["w"])
        ctx.set_line_join(cairo.LINE_JOIN_ROUND)
        ctx.set_line_cap(cairo.LINE_CAP_BUTT)
        ctx.set_source_rgba(*rgba(op["c"], alpha))
        ctx.stroke()
    elif kind == "lines":
        pts = op["pts"]
        ctx.set_line_width(op["w"])
        ctx.set_line_cap(cairo.LINE_CAP_BUTT)
        ctx.set_source_rgba(*rgba(op["c"], alpha))
        for i in range(0, len(pts) - 3, 4):
            ctx.move_to(pts[i], pts[i + 1])
            ctx.line_to(pts[i + 2], pts[i + 3])
            ctx.stroke()
    elif kind == "disc":
        x, y = op["p"]
        ctx.arc(x, y, op["r"], 0, 2 * np.pi)
        ctx.set_source_rgba(*rgba(op["c"], alpha))
        ctx.fill()
    elif kind == "text":
        x, y = op["p"]
        ctx.save()
        weight = cairo.FONT_WEIGHT_BOLD if op.get("bold") else cairo.FONT_WEIGHT_NORMAL
        ctx.select_font_face(op["fam"], cairo.FONT_SLANT_NORMAL, weight)
        ctx.set_font_size(op["s"])
        ctx.translate(x, y)
        ctx.rotate(op.get("a", 0.0))
        # Godot measured the text; squeeze or stretch cairo's to the same width
        ext = ctx.text_extents(op["t"])
        if ext.x_advance > 0.5 and op.get("w", 0) > 0.5:
            ctx.scale(op["w"] / ext.x_advance, 1.0)
        ctx.move_to(0, 0)
        ctx.set_source_rgba(*rgba(op["c"], alpha))
        ctx.show_text(op["t"])
        ctx.restore()
    elif kind == "tex":
        x, y, w, h = op["r"]
        surf = texture(op["id"])
        ctx.save()
        ctx.translate(x, y)
        ctx.scale(w / surf.get_width(), h / surf.get_height())
        ctx.set_source_surface(surf, 0, 0)
        ctx.get_source().set_filter(cairo.FILTER_GOOD)
        ctx.paint_with_alpha(op["c"][3] * alpha)
        ctx.restore()


def render_sheet(data, scale, names=1.0, wings=1.0):
    """The sheet at `scale` device px per sheet px (with its shadow margin)."""
    sw, sh = data["sheet"]
    margin = 60
    w, h = int((sw + margin * 2) * scale), int((sh + margin * 2) * scale)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    ctx = cairo.Context(surf)
    base = cairo.Matrix(scale, 0, 0, scale, margin * scale, margin * scale)
    layers = {}
    for op in data["ops"]:
        layers.setdefault(op.get("layer", ""), []).append(op)
    for layer in LAYER_ORDER:
        ops = layers.get(layer, [])
        if not ops:
            continue
        alpha = names if layer == "names" else wings if layer == "wings" else 1.0
        if alpha <= 0.001:
            continue
        if layer == "pencil":
            pencil = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
            pctx = cairo.Context(pencil)
            pctx.set_matrix(base)
            for op in ops:
                draw_op(pctx, op)
            ctx.save()
            ctx.identity_matrix()
            ctx.set_source_surface(pencil, 0, 0)
            ctx.set_matrix(base)
            pattern = cairo.SurfacePattern(grain_mask())
            pattern.set_extend(cairo.EXTEND_REPEAT)
            pattern.set_filter(cairo.FILTER_GOOD)
            ctx.mask(pattern)
            ctx.restore()
            continue
        ctx.save()
        ctx.set_matrix(base)
        for op in ops:
            if op["op"] != "label":
                draw_op(ctx, op, alpha)
        ctx.restore()
    return surf, margin


def render_screen(data, view):
    sw, sh = data["screen"]["size"]
    zoom = view["zoom"]
    cx, cy = view["center"]
    sheet, margin = render_sheet(data, zoom, view["names"], view["wings"])
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(sw), int(sh))
    ctx = cairo.Context(surf)
    # the game dimmed behind the map (a dark, warm night)
    grad = cairo.RadialGradient(sw * 0.5, sh * 0.45, 100, sw * 0.5, sh * 0.5, sw * 0.7)
    grad.add_color_stop_rgb(0, 0.11, 0.1, 0.09)
    grad.add_color_stop_rgb(1, 0.03, 0.03, 0.035)
    ctx.set_source(grad)
    ctx.paint()
    ox = sw * 0.5 - cx * zoom - margin * zoom
    oy = sh * 0.5 - cy * zoom - margin * zoom
    ctx.set_source_surface(sheet, ox, oy)
    ctx.paint()
    for op in data["screen"]["chrome"]:
        if op["op"] != "label":
            draw_op(ctx, op)
    return surf


def main():
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    only = sys.argv[2] if len(sys.argv) > 2 else ""
    for path in sorted(folder.glob("*.json")):
        if only and only not in path.stem:
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        if path.stem == "poster":
            surf, _ = render_sheet(data, 0.5)
            surf.write_to_png(str(folder / "poster.png"))
            print("poster.png")
            continue
        sheet, _ = render_sheet(data, 1.0)
        sheet.write_to_png(str(folder / (path.stem + "_sheet.png")))
        for view in data["screen"]["views"]:
            render_screen(data, view).write_to_png(str(folder / ("%s_%s.png" % (path.stem, view["name"]))))
        print(path.stem)


if __name__ == "__main__":
    main()
