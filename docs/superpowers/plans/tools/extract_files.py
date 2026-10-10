"""Writes (or checks) the files a plan task defines, byte-for-byte.

Every file in a task is given under a line  **Plik: `path`**  followed by one
fenced code block. This tool copies those blocks verbatim (tabs preserved,
LF endings; CRLF for .bat) so nobody has to retype them.

Usage (run from the repository root):
  python extract_files.py TASK.md --list                 list files in the task
  python extract_files.py TASK.md PATH [PATH ...]        write only these files
  python extract_files.py TASK.md --all                  write every file
  python extract_files.py TASK.md --check [PATH ...]     compare repo vs plan
                                                         (exit 1 on any diff)
"""
import difflib
import pathlib
import re
import sys

HEADER = re.compile(r"^\*\*Plik: `(.+?)`\*\*\s*$")


def parse(task_path: pathlib.Path) -> dict:
    lines = task_path.read_text(encoding="utf-8").split("\n")
    files = {}
    i = 0
    while i < len(lines):
        m = HEADER.match(lines[i])
        if not m:
            i += 1
            continue
        path = m.group(1)
        j = i + 1
        while j < len(lines) and lines[j].strip() == "":
            j += 1
        if j >= len(lines) or not lines[j].startswith("```"):
            sys.exit(f"no code block after header for {path}")
        body = []
        k = j + 1
        while k < len(lines) and lines[k] != "```":
            body.append(lines[k])
            k += 1
        if k >= len(lines):
            sys.exit(f"unterminated code block for {path}")
        files[path] = "\n".join(body) + "\n" if body else ""
        i = k + 1
    return files


def eol(path: str, text: str) -> str:
    return text.replace("\n", "\r\n") if path.lower().endswith(".bat") else text


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    files = parse(pathlib.Path(sys.argv[1]))
    args = sys.argv[2:]
    if args[0] == "--list":
        for p in files:
            print(p)
        return
    if args[0] == "--check":
        targets = args[1:] or list(files)
        bad = 0
        for p in targets:
            f = pathlib.Path(p)
            if not f.exists():
                print(f"MISSING  {p}")
                bad += 1
                continue
            actual = f.read_bytes().decode("utf-8").replace("\r\n", "\n")
            if actual == files[p]:
                print(f"same     {p}")
            else:
                bad += 1
                print(f"DIFFERS  {p}")
                sys.stdout.writelines(difflib.unified_diff(
                    files[p].splitlines(True), actual.splitlines(True), "plan/" + p, "repo/" + p))
        sys.exit(1 if bad else 0)
    targets = list(files) if args[0] == "--all" else args
    for p in targets:
        if p not in files:
            sys.exit(f"{p} is not defined in this task (see --list)")
        f = pathlib.Path(p)
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_bytes(eol(p, files[p]).encode("utf-8"))
        print(f"wrote    {p}")


main()
