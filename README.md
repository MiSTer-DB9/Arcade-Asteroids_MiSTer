# Asteroids / Asteroids Deluxe / Lunar Lander for MiSTer FPGA

An FPGA implementation of Atari's monochrome vector arcade classics
**Asteroids** (1979), **Asteroids Deluxe** (1980), and **Lunar Lander** (1979)
for the
[MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer/wiki) platform.

Asteroids combines precise rotation and thrust controls with a wraparound
playfield, hyperspace, flying saucers, and one of the most recognizable vector
displays in arcade history. Asteroids Deluxe builds on that foundation with
shields, new hazards, POKEY audio, and persistent high scores. Lunar Lander
adds precision analog thrust, selectable missions, and a careful balance
between fuel and survival. This core reconstructs all three machines from
Atari's schematics and pairs them with a high-resolution vector renderer and
CRT-effects pipeline.

## Support the Project

Hey, Videodr0me here! If you enjoy reliving the golden age of arcade games,
please support my work and future updates:
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow?style=flat-square&logo=buy-me-a-coffee)](https://buymeacoffee.com/Videodr0me)

---

## Original Hardware

| Subsystem | Original Hardware | FPGA Implementation |
|---|---|---|
| **Main CPU** | MOS Technology 6502A at 1.512 MHz in all three games | T65-compatible 6502 running at 1.512 MHz, derived from the exact 12.096 MHz master clock |
| **Vector Generator** | PROM-sequenced Atari Digital Vector Generator, vector RAM/ROM, DACs, and analog integrators in all three games | PROM-driven DVG using the original state PROM |
| **Audio** | Discrete analog sound in Asteroids and Lunar Lander; POKEY with discrete effects in Asteroids Deluxe | Schematic-derived audio, filtering, mixing, and cabinet response for all three games |
| **Mission Indicators** *(Lunar only)* | Four cabinet LEDs identify the selected mission | On-screen mission information shows the selected mission and its flight conditions |
| **Persistent Storage** *(Deluxe only)* | 64-byte Atari ER2055 EAROM | ER2055-compatible EAROM with MiSTer NVRAM persistence |
| **Display** | Monochrome XY vector monitor | Doubled-density Vector Doubler (shadow DVG) and high-resolution raster renderer for detailed Full HD output, with bloom, halo, phosphor decay, and selectable vector colors. Best in 1080p with HDR = 1 set.|
| **Cabinet Backdrop** *(Deluxe upright only)* | Blacklight-illuminated 3D cardboard backdrop and raised inserts, viewed through a half-silvered mirror | Resolution-specific indexed artwork blended behind the vector display, with green and orange cabinet variants |
| **Controls** | Digital ship controls in Asteroids/Deluxe; rotation, analog thrust lever, Abort, and mission selection in Lunar Lander | MiSTer joystick, analog controller, keyboard, spinner, mouse, and cabinet input mapping |

---

## Controls

### Asteroids / Asteroids Deluxe

| Input | Function |
|---|---|
| **Left / Right** | Rotate the ship |
| **Spinner / Mouse** *(optional)* | Rotate the ship when **Rotation** is set to **Spinner / Mouse** |
| **Fire (Button A)** | Fire |
| **Thrust (Button B)** | Apply thrust |
| **Hyperspace / Shield (Button X)** | Use Hyperspace in Asteroids or activate the shield in Asteroids Deluxe |
| **Start 1 / Start 2** | Start a one-player or two-player game |
| **Coin / Coin Right** | Operate the left or right coin mechanism |

The **Input Controls** menu can optionally make Up activate thrust alongside
the normal thrust button.

### Lunar Lander

Lunar Lander is best played with digital Left/Right controls and an analog
stick for proportional thrust, matching the original cabinet's rotation
buttons and thrust lever. For setups without a suitable analog control,
Digital Thrust provides an on/off fallback.

The **Input Controls** menu can assign proportional thrust to the left or
right analog stick. **Half** range uses center-to-up travel for a
self-centering stick; **Full** maps fully down to zero and fully up to maximum
for throttle-style controls.

| Input | Function |
|---|---|
| **Left / Right** | Rotate the lander |
| **Spinner / Mouse** *(optional)* | Rotate the lander when **Rotation** is set to **Spinner / Mouse** |
| **Selected Analog Stick Up** | Operate the proportional thrust lever; this is the recommended control |
| **Digital Thrust (Button A)** | Apply full thrust as a digital fallback |
| **Abort Thrust (Button B)** | Initiate the emergency upright-rotation and maximum-thrust sequence |
| **Start (Start)** | Start the currently selected mission |
| **Select Mission (Select)** | Cycle through the four mission types before launch |
| **Coin Left / Coin Right** | Operate the left or right coin mechanism |

| Mission | Conditions |
|---|---|
| **Training** | Light gravity, atmospheric friction, controlled rotation |
| **Cadet** | Moderate gravity, no atmospheric friction, controlled rotation |
| **Prime** | Strong gravity, no atmospheric friction, controlled rotation |
| **Command** | Moderate gravity, no atmospheric friction, rotational momentum |

The original cabinet indicated the selected mission through four dedicated
LEDs. The core instead briefly displays the selected mission and its flight
conditions on screen when the selection changes.

### Input Controls Menu

| Option | Games | Function |
|---|---|---|
| **Rotation** | All three | Selects the original left/right buttons or spinner/mouse rotation. |
| **Spinner Direction** | All three | Selects normal or reversed spinner/mouse direction; shown only in spinner/mouse mode. |
| **Thrust** | Asteroids / Deluxe | Selects the thrust button alone or Up and the thrust button together. |
| **Thrust Stick** | Lunar Lander | Selects the left or right analog stick for proportional thrust. |
| **Thrust Range** | Lunar Lander | **Half** maps center-to-up travel; **Full** maps the complete down-to-up axis. |

Asteroids exposes Service Mode and Diagnostic Step on its MRA DIP-switch page.
Asteroids Deluxe exposes Service Mode and the Slam Switch.
Lunar Lander exposes Service Mode, the Slam Switch, and Diagnostic Step.

The Cabinet Audio Hardware menu can independently bypass the main-board
filtering and the cabinet amplifier/speaker response.

---

## High Scores and EAROM/NVRAM

Asteroids Deluxe maintains a ten-entry high-score table during a session. Its
three highest scores and initials are stored in EAROM across power cycles and
are marked with spaceship symbols in the table.
Asteroids and Lunar Lander do not use EAROM.

To erase the persistent scores, open the MRA DIP-switch page and set
**Service Mode** to **On**. The self-test screen appears immediately. Press
Rotate Left, Rotate Right, Thrust, and Fire simultaneously. The `ERASING`
message is displayed for several seconds while the table is cleared; wait for
it to finish, then set **Service Mode** back to **Off**.

Persistent EAROM loading and saving requires starting the core through the
supplied MRA. After erasing the table, select **Save NVRAM** in the core menu
so the cleared EAROM is also saved persistently on the MiSTer SD card.
**Autosave NVRAM** can save subsequent EAROM changes automatically.

---

## Requirements

When updating from an older release, delete the existing MiSTer config files or
use **Reset Settings** once for each game. Config files are normally found under
`/media/fat/config/`.

The CRT-style video pipeline uses MiSTer SDRAM and requires a 32MB SDRAM
module or larger. Use the included MRAs so the program ROMs, DVG PROM, controls,
and DIP switches are configured correctly for each game.

Two Asteroids Deluxe MRAs are supplied for the Rev 3 ROM set:
`Asteroids Deluxe (v3 green).mra` and `Asteroids Deluxe (v3 orange).mra`.
They reproduce the two known cabinet backdrop variants and contain
resolution-specific indexed artwork for 240p, 480p, 720p, and 1080p. Fixed
profiles display matching artwork automatically. In Custom 1 and Custom 2, the
Background controls are disabled when the loaded MRA does not provide a valid
artwork plane for the current resolution.

### Custom Artwork

The artwork builder in the `artwork` directory can validate and compress a
custom backdrop, then add it to a new copy of an Asteroids, Asteroids Deluxe,
or Lunar Lander MRA. It requires Python 3 and Pillow (`pip install Pillow`).
For complete resolution coverage, supply one indexed PNG at each size below.
Any MRA may contain a subset; artwork is shown only at the included resolutions.

| Core Mode | PNG Size |
|---|---|
| **1080p** | 1360x1080 |
| **720p** | 916x720 |
| **480p / 480i** | 720x480 |
| **240p** | 720x240 |

Artwork is screen-fixed and does not follow the core's vector-orientation
setting. This makes the tool useful for vertical-monitor installations: create
the source artwork already rotated by 90 degrees for the intended physical
display orientation, while retaining the required PNG dimensions above.

Images must use PNG indexed-color (`P`) mode. A plane may use up to 16, 64, or
256 palette entries; the builder automatically stores its indices at 4, 6, or
8 bits. Indexed PNG transparency is supported and retained. The four planes
can use different palettes or index depths.

Run the builder from the repository root, passing the source MRA followed by
the four PNGs:

```powershell
python artwork/build_artwork.py `
  "releases/Asteroids Deluxe (v3 green).mra" `
  "my_art/backdrop_1360x1080.png" `
  "my_art/backdrop_916x720.png" `
  "my_art/backdrop_720x480.png" `
  "my_art/backdrop_720x240.png"
```

The current 720-wide plane set is selected by default. Use `--format legacy`
with 640x480 and 640x240 planes when preparing artwork for an older core build.

The source MRA is never modified. The ready-to-use result is written beside it
with an `_art` suffix, for example
`releases/Asteroids Deluxe (v3 green)_art.mra`. If that filename already
exists, the builder uses `_art1`, `_art2`, and so on. Any existing artwork
payload in the source is replaced only in the generated copy.

Additional outputs are written to `artwork/generated`:

- `<mra-name>.vart` is the compressed binary VART artwork container.
- `rom_index_2.xml` is the complete ROM-index-2 XML element for manual use in
  another MRA.
- `artwork_stats.json` records validation, exact decoder round-trip results,
  raw and compressed sizes, palette depth, transparency, and the three worst
  compressed scanlines for every plane and for the complete package.

The same compression summary is printed when the command completes. Use
`--no-update-mra` to generate and verify these files without creating a new
MRA.

---

## Recommended MiSTer Video Settings

The renderer supports 240p, 480i, 480p, 720p, and 1080p output. **1080p is
recommended** with **hdr=1** set for the highest vector detail and high dynamic range. Compatible 720p displays can additionally use
the optional 120Hz mode.

Asteroids and Asteroids Deluxe support Atari's original 61.52Hz frame cadence.
If your display cannot synchronize reliably at 61.52Hz, return to 60Hz by
turning **61.52Hz (Authentic)** off.

For high-resolution flat-panel output, add the following settings under the
exact `[Asteroids]` header at the end of `mister.ini`. MiSTer's scaler filters and shadow
mask are disabled so they do not alter the core's CRT-effects output.

```ini
[Asteroids]
video_mode=8   ; 8 = 1080p 0 = 720p
hdr=1          ; highly recommended
vsync_adjust=1 ; (or higher) required for authentic frame cadence and 120Hz mode
vscale_mode=0
vfilter_default=
vfilter_vertical_default=
vfilter_scanlines_default=
shmask_default=
shmask_mode_default=0
```

The empty filter entries override filters inherited from the global
`[MiSTer]` section.

### CRT and Direct Video Output

#### CRT Output

> **Required for CRT output:** Before loading the core, set
> `video_mode=720,240,60`, `vga_scaler=0`, and `forced_scandoubler=0`.
>
> Otherwise, the VGA output may use an out-of-range HD timing. These settings
> also ensure the best image quality.

```ini
[Asteroids]
video_mode=720,240,60
vga_scaler=0
forced_scandoubler=0
```

Place these entries in an `[Asteroids]` section at the end of `MiSTer.ini`.
Later entries take priority over earlier ones, ensuring that these core-specific
settings override global settings.

For a 31 kHz CRT, change the mode line to `video_mode=720,480,60`.

The following options are available under **Video Timing & Geometry**:

- **61.52Hz (Authentic)** follows the original Asteroids and Asteroids Deluxe
  frame cadence. Turn it off if your CRT cannot synchronize reliably.
- **15 kHz Format** selects 480i or 240p, with 480i used by default. At 31 kHz,
  the core uses 480p and hides this option.
- **CRT Vertical Position** moves the picture vertically. Positive values move
  it down and negative values move it up.

#### Direct Video

For Direct Video users, setup is simpler: use `direct_video=1` if you have not
already. Under **Video Timing & Geometry**, **Direct Video Scan Rate** selects
15 kHz or 31 kHz output.

#### Alternatives if Sync Fails

These alternatives are not recommended. Using `vga_scaler=1` greatly reduces
image quality and should only be considered if the native output will not
synchronize.

With `vga_scaler=1`, MiSTer's scaler drives the VGA output using the selected
`video_mode` or manual modeline. `vsync_adjust=0` retains that modeline's
refresh rate; `1` or `2` adjusts its pixel clock to follow the core.

Keep the usual `vga_mode`, `composite_sync`, and `vga_sog` settings required by
your CRT connection.

---

## Video Options

### Video Profiles & Effects

| Option | Description |
|---|---|
| **Profile** | Selects five fixed presets, two independent custom slots, or the effects-filter bypass path. |
| **Background** | Blends matching MRA artwork with the completed CRT-effects output. |
| **Background Blend** | Sets artwork strength from 31.3% (`-4`) to 57.8% (`+3`); `0` uses the 40.6% default and `+2` uses 50%. |
| **Inter-Frame Decay** | Carries fading vector energy across completed frames. |
| **Intra-Frame Decay** | Uses each pixel's recorded draw order to vary brightness within one vector frame. |

Inter-Frame Decay models phosphor persistence lasting longer than one redraw.
Intra-Frame Decay models brightness changes that become visible within a single
vector frame. For a natural result, favor Inter-Frame Decay when the phosphor
remains visible across redraws, or Intra-Frame Decay when it fades substantially
during one redraw. Strongly combining both is primarily a stylized effect.

### Video Timing & Geometry

| Option | Description |
|---|---|
| **Orientation** | Provides all eight unique rotation and mirroring combinations. |
| **Zoom** | Normal shows the full game area. Wide provides additional space around it. |
| **Buffer Mode** | Selects EOF + VBL, VBL-only, or EOF-only frame presentation. |
| **120Hz (720p only)** | Enables 120Hz output when the active mode is 720p. |
| **61.52Hz (Authentic)** | Uses Atari's original Asteroids and Asteroids Deluxe frame cadence. Turn it off for 60Hz-compatible output. |
| **Direct Video Scan Rate** | Selects the 15 kHz or 31 kHz output bracket while Direct Video is active. |
| **15 kHz Format** | Selects 480i or 240p when the core is running in the 15 kHz bracket. 480i is the default; switching modes restarts the game. |
| **CRT Vertical Position** | Moves 240p, 480p, or 480i output vertically. Positive values move the picture down; the available offsets follow each mode's blanking margins. |
| **Aspect Ratio** | Optimized selects the intended core aspect, Stretched fills the display, and Pixel Perfect requests direct pixel mapping. |

### Video Profiles

| Profile | Description |
|---|---|
| **Off** | Bypasses bloom and halo. Dot Scale, Tone Mapping, and both decay controls remain available. |
| **A Touch of CRT** | Adds subtle CRT halo and bloom. |
| **80s Cruise Control** | Adds stronger halo, bloom, and a restrained inter-frame trail. This is the default profile. |
| **80s Overdrive** | Models a heavily driven arcade CRT with stronger glow and phosphor decay. |
| **Red Alert** | Outside reality, where bright lines flash and fade but their glowing trails refuse to disappear. Impossible on a real CRT, spectacular in motion. |
| **Ultraviolet** | Stylized high-energy vector presentation with excessive flashing bright lights. |
| **Custom 1 / Custom 2** | Two independent user-configurable slots exposing the complete advanced effects controls. |

> **Warning:** Red Alert and Ultraviolet feature excessive
> flashing bright lights and should not be used by anyone sensitive to them.

Both custom slots retain their own complete control set through MiSTer's
**Save Settings** command.

The exact game- and resolution-specific preset values are listed in
[CRT Profile Settings](Profiles/README.md), making them easy to reproduce and
modify in either custom slot.

---

## ROMs

```text
                                *** Attention ***

ROMs are not included. Use the supplied Asteroids MRA with the matching MAME
Asteroids Rev 4 ROM set, either Asteroids Deluxe backdrop MRA with the matching
Asteroids Deluxe Rev 3 ROM set, or the Lunar Lander MRA with the matching Lunar
Lander Rev 2 ROM set. Each MRA verifies its program ROMs, vector ROMs, and DVG
state PROM by CRC.

Quick reference for MiSTer SD-card placement:

/_Arcade/Asteroids.mra
/_Arcade/Asteroids Deluxe (v3 green).mra
/_Arcade/Asteroids Deluxe (v3 orange).mra
/_Arcade/Lunar Lander.mra
/_Arcade/cores/Asteroids.rbf
/games/mame/asteroid.zip
/games/mame/astdelux.zip
/games/mame/llander.zip
```

See the
[MiSTer Arcade ROM guide](https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms)
for other supported ROM-folder layouts.

---

## Compilation

The project uses **Quartus Prime Lite 17.0** and targets the Cyclone V FPGA on
the Terasic DE10-Nano.

1. Open `Asteroids.qpf` in Quartus.
2. Run the complete compilation flow.
3. Find the generated `Asteroids.rbf` in `output_files/`.

Production source files are listed in `files.qip`. Core-specific RTL is under
`rtl/`; `sys/` contains the standard MiSTer framework.

---

## Credits and Acknowledgments

- **Asteroids:** Atari, 1979.
- **Asteroids Deluxe:** Atari, 1980.
- **Lunar Lander:** Atari, 1979.
- **MiSTer Asteroids / Asteroids Deluxe / Lunar Lander core, DVG, renderer, discrete audio models, and integration:** Videodr0me.
- **POKEY core:** Based on MikeJ's FPGAArcade POKEY implementation.
- **T65 CPU core:** Daniel Wallner and subsequent T65 maintainers.
- **MiSTer platform:** Sorgelig and the MiSTer community.

---

## License

See [LICENSE](LICENSE) and the headers of individual source files for the terms
that apply to this project and its incorporated components.
