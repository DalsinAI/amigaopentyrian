# OpenTyrian — active open3 intake

Source pin: `ac5d0e71f4245744350c6116ce24f10624da58f8`,
[upstream](https://github.com/opentyrian/opentyrian). GPL-2.0-or-later engine.
SDL2, 68040 + FPU, libnix, GCC 16.2.0-open3. Networking disabled.

Prepare with `scripts/game_port_prepare.py prepare --game opentyrian --allow-network`.
Build the exported pin offline, applying the checked-in patches (`patches/`, in
order, with no fuzz):

```sh
python3 build_open3.py --source build/game-ports/sources/opentyrian \
  --stove /path/to/verified-open3 --out build/opentyrian-open3 --jobs 2
python3 scripts/fetch_runtime_data.py --root . --game opentyrian --allow-network
```

The helper writes `receipt.json` and `build.log`; it does not deploy or fetch.
Put the binary beside `data/` with the contents of the upstream-linked Tyrian
2.1 ZIP (flat, lowercase names). User files go in `PROGDIR:User`.
Run `opentyrian --no-sound --no-joystick --data=data` for the muted smoke.

On Cradle, `stove_build` with target `.` runs `build-amiga.sh` (the same build,
the upstream pin fetched by the job; it takes the os32-gcc16 stove with
OpenAmigaGCC 16.2.0-open3 or open4 and records which in `receipt.json`), and
target `runtime-data` stages the pinned Tyrian 2.1 data for a lab as
`OpenTyrian/data`. Both are for labs; neither is a package.

### Display

The game draws 320x200. On an Amiga it starts on a screen of its own (on an
RTG board the desktop-sized 640x480 mode, the frame whole at 2x with black
bands above and below) with no CPU scaler. Alt+Return gives a Workbench window
of exactly 320x200 and back. Setup > Graphics still offers the scalers and
scaling modes; `PROGDIR:User/opentyrian.cfg` keeps the choice.
`SetEnv OPENTYRIAN_FPS 1` logs the frames shown every five seconds (a file name
instead of `1` adds the lines to that file).

### Controls

Keyboard (upstream's defaults, changeable in Options > Keyboard): arrow keys
move, Space fires, Return changes the rear gun's mode, Ctrl and Left Alt fire
the left and right sidekicks, P pauses, Escape opens the in-game menu (and
leaves menus), Alt+Return switches screen and window. The mouse moves the ship
too.

Joysticks and pads come through SDL from GFOpenInput (lowlevel.library where
GFOpenInput isn't installed). Port 2's stick is SDL joystick 1. With
GFOpenInput every pad has SDL's game controller layout, so the Amiga build adds
to upstream's defaults (stick or d-pad moves, A fires, B changes mode, X and Y
the sidekicks, Back the menu, Guide pauses): the shoulders also fire the
sidekicks and Start opens the menu, which a CD32 pad (no Back or Guide) needs.
Options > Joystick shows and changes them; Reset to Defaults brings them back.

### Audio

Music (the game's OPL2 tunes, emulated) and sound effects are mixed by the game
into one 44.1 kHz 16-bit mono stream that SDL plays through AHI (OpenAHI's
driver on AmiCradle); `--no-sound` turns it off. The log says what SDL opened
(`Audio: ahi, 44100 Hz, 1 channel(s), 1024 samples a buffer`). With
`OPENTYRIAN_FPS` set, each five-second line also gives the buffers mixed and
the time spent mixing them: 215 or 216 buffers in five seconds (44100 / 1024 a
second) means none was late.
The data digest is pinned in the runtime manifest. Assets stay external;
freeware is not permission to redistribute every asset without review.

## Observed 24 October 2026

Clean compile/link passed. Executable SHA-256:
`7b05261b65ed89aee05cf8c45e81027587f85718b7ac8af600aa91104e5951d3`.
Compiler archive SHA-256:
`9fcc136ab59e3bb5b91d2764d0bf290b709d72d7380be4ce0cdf005edf8eff21`.

Isolated copied lab, runtime `zen x86-64-v3 20261024T070109Z`, Kickstart
3.2.3 47.115, CRC32 `b18d3b67`, SDL_OPENGPU=0, muted. Title and moving
attract demo rendered, but the 320x200 window appeared to clip the scaled
picture. Keyboard/menu/gameplay control is not qualified. Both launches
exited via Escape with Shell RC 0 and created configuration/save-container
files under User. Creating a save container is not a gameplay save/load pass.

Remaining: full-frame presentation, deliberate menu/ship movement/fire,
actual game save/load, audio, input devices and repeat on intended ROM/runtime.
This is TESTING, not RELEASE. The isolated lab was stopped after the run;
Instance-32 and platform repositories were untouched.
