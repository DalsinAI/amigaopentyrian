#!/bin/sh
# Stages the Tyrian 2.1 freeware data for a lab test, on the PC that runs the
# job: scripts/fetch_runtime_data.py fetches the ZIP pinned in
# gameports/runtime-data.json (its SHA-256 checked), and its data files go to
# OUT/OpenTyrian/data with flat, lowercase names. Nothing here is committed or
# packaged: the data stays external (gameports/runtime-data.json's policy).
#   OUT    the output directory (default build-data)
#   CACHE  where the ZIP is kept between runs (default a temporary folder)
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${OUT:-"$HERE/build-data"}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/opentyrian-data.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM
CACHE=${CACHE:-"$WORK/cache"}

python3 "$HERE/scripts/fetch_runtime_data.py" --root "$HERE" --game opentyrian \
    --cache "$CACHE" --allow-network

python3 - "$CACHE/tyrian21.zip" "$OUT/OpenTyrian/data" <<'PY'
import sys, zipfile
from pathlib import Path
zip_path, dest = Path(sys.argv[1]), Path(sys.argv[2])
# DOS programs and documents are not game data
skip = {".exe", ".ovl", ".doc", ".diz", ".ico", ".txt"}
dest.mkdir(parents=True, exist_ok=True)
n = 0
with zipfile.ZipFile(zip_path) as z:
    for info in z.infolist():
        name = Path(info.filename).name.lower()
        if info.is_dir() or not name or Path(name).suffix in skip:
            continue
        (dest / name).write_bytes(z.read(info))
        n += 1
print(f"{n} data files in {dest}")
PY
