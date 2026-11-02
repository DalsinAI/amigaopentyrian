#!/bin/sh
# OpenTyrian for AmigaOS 3.x / AmiCradle (68040 + FPU, SDL2 through GFOpenGPU),
# built with the os32-gcc16 stove (OpenAmigaGCC 16.2.0-open3 or open4). This is the
# build Cradle's stove_build runs (STOVE= and OUT= set); build_open3.py is the
# same build from a local checkout with a staged stove.
#   STOVE              the stove (default ~/AmigaChrome/stoves/os32-gcc16)
#   OUT                the output directory (default build-amiga)
#   OPENTYRIAN_SOURCE  a local upstream checkout holding the pinned commit;
#                      without it the pinned commit is fetched from upstream
#   JOBS               make's job count (default 2)
# Outputs: OpenTyrian/opentyrian (put it in a drawer beside data/), receipt.json.
# The game data is not built here: runtime-data/build-amiga.sh stages it.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STOVE=${STOVE:-"$HOME/AmigaChrome/stoves/os32-gcc16"}
OUT=${OUT:-"$HERE/build-amiga"}
JOBS=${JOBS:-2}
# the compiler archives taken: open3 (the 24 October build's) and open4
# (Cradle's os32-gcc16 stove since 2 November 2026)
OPEN3=9fcc136ab59e3bb5b91d2764d0bf290b709d72d7380be4ce0cdf005edf8eff21
OPEN4=495319a2ffd803278f8827cad70074029c7aa9ecbe05d037e8646ba43ab94ab2
P="$STOVE/prefix"
SDK="$P/m68k-amigaos"
CC="$P/bin/m68k-amigaos-gcc"

# the compiler must be one of them: its archive's checksum, from the stove's
# STOVE.json (Cradle's stoves) or provenance.json (a staged stove)
RELEASE=$(python3 - "$STOVE" "$OPEN3" "$OPEN4" <<'EOF'
import json, sys
from pathlib import Path
stove = Path(sys.argv[1])
known = {sys.argv[2]: "16.2.0-open3", sys.argv[3]: "16.2.0-open4"}
got = None
if (stove / "STOVE.json").is_file():
    got = json.loads((stove / "STOVE.json").read_text()).get("compilerArchive", {}).get("sha256")
if got is None and (stove / "provenance.json").is_file():
    got = json.loads((stove / "provenance.json").read_text()).get("archive_sha256")
# GFOpenAmigaGCC 16.2.0-open5 (Cradle's os32-gcc16 stove since the evening of
# 2 November 2026) has no published archive: known by STOVE.json's release
# and the compiler's own --version
if got is None and (stove / "STOVE.json").is_file() and \
        json.loads((stove / "STOVE.json").read_text()).get("release") == "GFOpenAmigaGCC 16.2.0-open5":
    import subprocess
    v = subprocess.run([str(stove / "prefix/bin/m68k-amigaos-gcc"), "--version"], capture_output=True, text=True).stdout
    if "(GFOpenAmigaGCC 16.2.0-open5)" not in v:
        sys.exit(f"STOVE.json says GFOpenAmigaGCC 16.2.0-open5, the compiler says {v.splitlines()[:1]}")
    got = "unpublished"
    known[got] = "16.2.0-open5"
if got not in known:
    for name in ("STOVE.json", "provenance.json"):
        if (stove / name).is_file():
            print((stove / name).read_text()[:1500], file=sys.stderr)
    sys.exit(f"{stove} is not an OpenAmigaGCC 16.2.0-open3 or open4 or a GFOpenAmigaGCC 16.2.0-open5 stove (compiler archive {got})")
print(known[got])
EOF
)
"$CC" --version | head -n 1
"$CC" --version | head -n 1 | grep -q "$RELEASE" || { echo "$CC is not $RELEASE"; exit 2; }

PIN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["ports"]["opentyrian"]["source"]["commit"])' "$HERE/gameports/catalog.json")
URL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["ports"]["opentyrian"]["source"]["url"])' "$HERE/gameports/catalog.json")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/opentyrian-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM

if [ -n "${OPENTYRIAN_SOURCE:-}" ]; then
    SRC=$OPENTYRIAN_SOURCE
else
    SRC="$WORK/upstream"
    git init -q "$SRC"
    git -C "$SRC" fetch -q --depth 1 "$URL" "$PIN"
fi
git -C "$SRC" cat-file -e "$PIN^{commit}"
EPOCH=$(git -C "$SRC" show -s --format=%ct "$PIN")

mkdir -p "$WORK/src"
git -C "$SRC" archive "$PIN" | tar -xf - -C "$WORK/src"
for patch in "$HERE"/patches/*.patch; do
    echo "patch: $(basename "$patch")"
    patch --batch --forward --fuzz=0 -p1 -d "$WORK/src" < "$patch"
done

# -fno-delete-null-pointer-checks: address 0 is memory on an Amiga
FLAGS="-noixemul -m68040 -m68881 -fno-delete-null-pointer-checks -pthread -O2 -ffile-prefix-map=$WORK/src=."
( cd "$WORK/src" && SOURCE_DATE_EPOCH=$EPOCH make -j "$JOBS" PLATFORM=AMIGA WITH_NETWORK=false \
    CC="$CC" CFLAGS="$FLAGS" SDL_CPPFLAGS="-I$SDK/include/SDL2" SDL_LDFLAGS="-L$SDK/lib" \
    SDL_LDLIBS="-lSDL2 -lGL -lm -pthread" TYRIAN_DIR=PROGDIR:data "VCS_IDREV=printf ${PIN}" )

EXE="$WORK/src/opentyrian"
[ "$(od -An -tx1 -N4 "$EXE" | tr -d ' \n')" = "000003f3" ] || { echo "not an Amiga HUNK executable"; exit 2; }
mkdir -p "$OUT/OpenTyrian"
cp "$EXE" "$OUT/OpenTyrian/opentyrian"

python3 - "$HERE" "$OUT" "$PIN" "$EPOCH" "$STOVE" "$RELEASE" <<'EOF'
import hashlib, json, sys
from pathlib import Path
here, out, pin, epoch, stove, release = Path(sys.argv[1]), Path(sys.argv[2]), *sys.argv[3:]
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
sdk = Path(stove) / "prefix/m68k-amigaos"
receipt = {
    "source_commit": pin, "source_date_epoch": epoch,
    "patches": {p.name: sha(p) for p in sorted((here / "patches").glob("*.patch"))},
    "compiler_release": release,
    "sdk_inputs": {n: sha(sdk / n) for n in ("lib/libSDL2.a", "lib/libGL.a", "include/SDL2/SDL.h")},
    "executable_sha256": sha(out / "OpenTyrian/opentyrian"),
    "scope": "Source build only; network disabled; no runtime or release pass implied",
}
(out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
EOF
