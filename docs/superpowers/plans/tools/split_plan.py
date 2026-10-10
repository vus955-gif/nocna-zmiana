"""Splits the stage-1a plan into conventions.md + task-NN.md files."""
import pathlib
import re
import sys

plan = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
lines = plan.read_text(encoding="utf-8").split("\n")

starts = [i for i, l in enumerate(lines) if re.match(r"^### Zadanie \d+:", l)]
end_all = next(i for i, l in enumerate(lines) if l.startswith("## Samokontrola"))
(out / "conventions.md").write_text("\n".join(lines[: starts[0]]) + "\n", encoding="utf-8")
for n, s in enumerate(starts):
    e = starts[n + 1] if n + 1 < len(starts) else end_all
    num = int(re.match(r"^### Zadanie (\d+):", lines[s]).group(1))
    (out / f"task-{num:02d}.md").write_text("\n".join(lines[s:e]).rstrip("-\n ") + "\n", encoding="utf-8")
    print(f"task-{num:02d}.md  lines {s + 1}-{e}")
