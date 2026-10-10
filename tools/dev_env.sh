# Sourced by the tools (". tools/dev_env.sh"): Godot's user folder and the
# GPU driver's caches go to tools/godot/editor_data/{appdata,localappdata}
# on the game's drive instead of %APPDATA% / %LOCALAPPDATA% on C:. Windowed
# runs keep their shader and pipeline caches there. The game never keeps
# saves, settings or logs in them (see SavePaths).
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
APPDATA="$TOOLS_DIR/godot/editor_data/appdata"
LOCALAPPDATA="$TOOLS_DIR/godot/editor_data/localappdata"
export APPDATA LOCALAPPDATA
mkdir -p "$APPDATA" "$LOCALAPPDATA"
