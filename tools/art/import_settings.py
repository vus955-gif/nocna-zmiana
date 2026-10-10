"""Godot import presets for the generated art (plain Python, no Blender needed).

Pixel textures must stay crisp: lossless storage (no VRAM block compression
smearing the texels), mipmaps on (no shimmer at distance), no automatic
"detect 3D" re-compression. Normal maps are flagged as such. Models are
imported without automatic LODs (the meshes are already low-poly).

Run after generating assets and before `godot --headless --import`:
    python tools/art/import_settings.py
Existing .import files are patched in place (Godot keeps their uid);
missing ones are created minimal and completed by Godot on import.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TEXTURE = {
    "compress/mode": "0",
    "mipmaps/generate": "true",
    "detect_3d/compress_to": "0",
    "process/fix_alpha_border": "true",
}
SCENE = {
    "meshes/generate_lods": "false",
    "meshes/ensure_tangents": "true",
    "gltf/embedded_image_handling": "0",
}


def patch(path, importer, typ, params):
    imp = path.with_name(path.name + ".import")
    if not imp.exists():
        lines = ["[remap]", "", f'importer="{importer}"', f'type="{typ}"', "", "[params]", ""]
        lines += [f"{k}={v}" for k, v in params.items()]
        imp.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
        return "created"
    text = imp.read_text(encoding="utf-8").splitlines()
    seen = set()
    out = []
    in_params = False
    for line in text:
        if line.startswith("["):
            in_params = line.strip() == "[params]"
        key = line.split("=", 1)[0] if in_params and "=" in line else None
        if key in params:
            line = f"{key}={params[key]}"
            seen.add(key)
        out.append(line)
    missing = [k for k in params if k not in seen]
    if missing:
        out += [f"{k}={params[k]}" for k in missing]
    new = "\n".join(out) + "\n"
    if new != "\n".join(text) + "\n":
        imp.write_text(new, encoding="utf-8", newline="\n")
        return "patched"
    return "ok"


def main():
    counts = {}
    for png in sorted((ROOT / "assets" / "textures").glob("*.png")):
        params = dict(TEXTURE)
        params["compress/normal_map"] = "1" if png.stem.endswith("_normal") else "0"
        r = patch(png, "texture", "CompressedTexture2D", params)
        counts[r] = counts.get(r, 0) + 1
    for glb in sorted((ROOT / "assets" / "models").glob("*.glb")):
        r = patch(glb, "scene", "PackedScene", SCENE)
        counts[r] = counts.get(r, 0) + 1
    print("import presets:", counts)


if __name__ == "__main__":
    main()
