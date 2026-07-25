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
| **Display** | Monochrome XY vector monitor | Doubled-density Vector Doubler (shadow DVG) and high-resolution raster renderer for detailed Full HD output, with bloom, halo, phosphor decay, and selectable vector colors |
| **Controls** | Digital ship controls in Asteroids/Deluxe; rotation, analog thrust lever, Abort, and mission selection in Lunar Lander | MiSTer joystick, analog controller, keyboard, and cabinet input mapping |

---

## Controls

### Asteroids / Asteroids Deluxe

| Input | Function |
|---|---|
| **Left / Right** | Rotate the ship |
| **Fire (Button A)** | Fire |
| **Thrust (Button B)** | Apply thrust |
| **Hyperspace / Shield (Button X)** | Use Hyperspace in Asteroids or activate the shield in Asteroids Deluxe |
| **Start 1 / Start 2** | Start a one-player or two-player game |
| **Coin / Coin Right** | Operate the left or right coin mechanism |

### Lunar Lander

Lunar Lander is best played with digital Left/Right controls and an analog
stick for proportional thrust, matching the original cabinet's rotation
buttons and thrust lever. For setups without a suitable analog control,
Digital Thrust provides an on/off fallback.

| Input | Function |
|---|---|
| **Left / Right** | Rotate the lander |
| **Analog Stick Up** | Operate the proportional thrust lever; this is the recommended control |
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

Lunar Lander models the original approximately 3 kHz tracking ADC: the
software-visible thrust value follows the requested lever position rather than
jumping to it instantly.

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

---

## Recommended MiSTer Video Settings

The renderer supports 240p, 480p, 720p, and 1080p output. **1080p is
recommended** for the highest vector detail. Compatible 720p displays can use
the optional 120Hz mode.

Asteroids and Asteroids Deluxe support Atari's original 61.52Hz frame cadence.
If your display cannot synchronize reliably at 61.52Hz, return to 60Hz by
turning **61.52Hz (Authentic)** off, or set `vsync_adjust=0` in `mister.ini`.

For high-resolution flat-panel output, add the following settings under the
exact `[Asteroids]` header in `mister.ini`. MiSTer's scaler filters and shadow
mask are disabled so they do not alter the core's CRT-effects output.

```ini
[Asteroids]
video_mode=8
vsync_adjust=2
vscale_mode=0
hdmi_limited=0
hdr=1
vfilter_default=
vfilter_vertical_default=
vfilter_scanlines_default=
shmask_default=
shmask_mode_default=0
```

The empty filter entries override filters inherited from the global
`[MiSTer]` section.

### Direct Video and CRT Output

When Direct Video is active, use **Direct Video Scan Rate** in Video Options to
select 15 kHz (240p) or 31 kHz (480p) output.

When using a real CRT, start with **A Touch of CRT**, **Off**, or a **Custom**
profile. Stronger profiles recreate characteristics that the tube may already
provide, including bloom, halo, and phosphor persistence.

---

## Video Options

| Option | Description |
|---|---|
| **Aspect Ratio** | Optimized selects the intended core aspect, Stretched fills the display, and Pixel Perfect requests direct pixel mapping. |
| **120Hz (720p only)** | Enables approximately 120Hz output when the active mode is 720p. |
| **61.52Hz (Authentic)** | Uses Atari's original Asteroids and Asteroids Deluxe frame cadence. Turn it off for 60Hz-compatible output. |
| **Direct Video Scan Rate** | Selects 15 kHz (240p) or 31 kHz (480p) while Direct Video is active. |
| **Buffer Mode** | Selects EOF + VBL, VBL-only, or EOF-only frame presentation. |
| **Inter-Frame Decay** | Models phosphor persistence extending beyond one frame. Especially suitable for monochrome vector displays with long-retention phosphors. |
| **Intra-Frame Decay** | Models decay within one frame using each pixel's recorded draw time. More suitable for later color vector games with longer redraw times and shorter phosphor persistence. |
| **Profile** | Selects five fixed presets, two independent custom slots, or the effects-filter bypass path. |

Intra-frame and inter-frame decay are independent profile settings. Fixed
profiles select both automatically, while Off and the two custom profiles
expose them directly. These modes normally need little overlap: use either one
for a natural result, or combine them for deliberately spectacular effects.

### Video Profiles

| Profile | Description |
|---|---|
| **Off** | Bypasses bloom and halo. Dot Scale, Tone Mapping, and both decay controls remain available. |
| **A Touch of CRT** | Adds subtle CRT halo and bloom. |
| **80s Cruise Control** | Adds stronger halo, bloom, and medium inter-frame decay. This is the default profile. |
| **80s Overdrive** | Models a heavily driven arcade CRT with stronger glow and phosphor decay. |
| **Neon Fever Dream** | Stylized high-energy vector presentation with excessive flashing bright lights. |
| **Purple Haze** | Outside reality, where bright lines flash and fade but their glowing trails refuse to disappear. Impossible on a real CRT, spectacular in motion. |
| **Custom 1 / Custom 2** | Two independent user-configurable slots exposing the complete advanced effects controls. |

> **Warning:** Neon Fever Dream and Purple Haze feature excessive
> flashing bright lights and should not be used by anyone sensitive to them.

Both custom slots retain their own complete control set through MiSTer's
**Save Settings** command.

### Video Geometry

| Option | Description |
|---|---|
| **Orientation** | Provides all eight unique rotation and mirroring combinations. |
| **Zoom** | Normal shows the full game area. Wide provides additional space around it. |

---

## ROMs

```text
                                *** Attention ***

ROMs are not included. Use the supplied Asteroids MRA with the matching MAME
Asteroids Rev 4 ROM set, the Asteroids Deluxe MRA with the matching Asteroids
Deluxe Rev 3 ROM set, or the Lunar Lander MRA with the matching Lunar Lander
Rev 2 ROM set. Each MRA verifies its program ROMs, vector ROMs, and DVG state
PROM by CRC.

Quick reference for MiSTer SD-card placement:

/_Arcade/Asteroids.mra
/_Arcade/Asteroids Deluxe.mra
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
