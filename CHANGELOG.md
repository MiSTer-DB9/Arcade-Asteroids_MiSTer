# Changelog

All notable changes to this project will be documented in this file.

## CRT 15 kHz Output Update [20260810]

### Features

- **Native 480i Output**: Adds 720x480 interlaced output for 15 kHz CRTs and
  selectable 240p output.
- **Expanded CRT Resolution**: Increases 240p from 640x240 to 720x240 and
  480p/480i from 640x480 to 720x480.
- **CRT-Compatible Timings**: Adds 59.94 Hz timing with a CRT-friendly active
  width for 240p, 480i, and 480p.
- **CRT Vertical Position**: Moves 240p, 480p, and 480i output vertically.

### Required CRT Setup

> **Required for VGA 480i output and best image quality:** Place these entries in
> an `[Asteroids]` section at the end of `MiSTer.ini`.
> ```ini
> [Asteroids]
> video_mode=720,240,60
> vga_scaler=0
> forced_scandoubler=0
> ```
> For a 31 kHz CRT, use `video_mode=720,480,60`.
> For Direct Video, `direct_video=1` is sufficient if not already set.

Thanks to **akeley**, **biobern**, **Chris23235**, **deadwingmisterfpga**,
**Higgy**, **Malento**, **MiSTerTea**, and **thorr** from the MiSTer FPGA Forum
and to **david92**, **leosync04**, **Matti**, **MikeS**, **pixel_sam**,
**Stefan**, **tim_15k8**, and **dr_waffles** for testing the new CRT modes on
their displays.

## Follow-up Update [20260804]

### Features

- **Asteroids Deluxe Cabinet Artwork**: Asteroids Deluxe used a
  blacklight-illuminated 3D backdrop viewed with the vector display through a
  half-silvered mirror. Two supplied MRAs reproduce the known green and orange
  artwork variants at 240p, 480p, 720p, and 1080p.
- **Custom Artwork Builder**: The included Python tool validates and compresses
  resolution-specific indexed artwork and creates a new MRA containing it for
  any of the three games. Fixed profiles use matching artwork automatically.
- **Expanded CRT Timing Support**: Adds dedicated 240p timing and improves
  native 15 kHz and 31 kHz output compatibility.
- **Spinner and Mouse Rotation**: All three games support reversible spinner
  and mouse movement through timed left/right input.
- **Expanded Thrust Controls**: Asteroids and Asteroids Deluxe can optionally
  use Up for thrust. Lunar Lander can use either analog stick with half-axis or
  full-axis travel while retaining its digital full-thrust fallback.
- **Expanded CRT-Effect Controls**: Halo and bloom can be shaped independently,
  with additional dot-scaling options.

### Technical Improvements

- **Pipelined Artwork Streaming**: Artwork is loaded from the MRA into DDRAM
  and read through a low-priority arbiter client. The decompressor sustains one
  artwork pixel per visible output pixel in 1080p.
- **Asteroids Deluxe Glass Color**: Refined blue-glass color conversion keeps
  normal vector tones distinct while excess highlight energy spills naturally
  into the other channels. Maximum-intensity vectors shift to bright, neutral
  white while lower intensities retain the selected color tint.

### Documentation and Integration

- **CRT Output Guide**: Documents the required MiSTer.ini settings, native
  15 kHz and 31 kHz output, vertical positioning, and sync alternatives.
- **Artwork Documentation**: Documents how to use the supplied compression
  tool, the required image dimensions, palette depths, and generated files.

## Initial Release [20260725]

### Update Notes

- **Reset Saved Settings**: When updating from an older Asteroids core, delete
  its existing MiSTer config files or use **Reset Settings** once for each game.

### Features

- **Three Atari Vector Classics**: Hardware-level implementations of Asteroids,
  Asteroids Deluxe, and Lunar Lander reconstructed from the original
  schematics, DVG state PROM, and program sources.
- **PROM-Driven Digital Vector Generator**: Implements the original Atari DVG
  sequencing and vector timing.
- **High-Resolution Vector Renderer**: High-resolution vector output at 240p,
  480p, 720p, and 1080p, with optional 120Hz output at 720p.
- **CRT Effects Pipeline**: Bloom, halo, dot scaling, tone mapping, selectable
  vector colors, and resolution-aware video profiles.
- **Phosphor Decay**: Models decay within one frame using each pixel's recorded
  draw time, plus phosphor persistence extending across frames.
- **Game-Specific Cabinet Audio**: Recreates Asteroids and Lunar Lander
  discrete audio, Asteroids Deluxe POKEY and discrete effects, main-board
  filtering, and cabinet response.
- **Lunar Lander Analog Thrust**: Supports proportional analog control with a
  digital full-thrust fallback and the original board's tracking response.
- **Lunar Lander Mission Display**: Replaces the cabinet's four mission LEDs
  with on-screen information describing the selected mission conditions.
- **Asteroids Deluxe EAROM**: Preserves its three highest scores and initials
  through MiSTer NVRAM.
- **Video Profiles**: A Touch of CRT, 80s Cruise Control, 80s Overdrive,
  Red Alert, and Ultraviolet, plus two independent custom slots exposing the
  complete advanced effects controls. Exact game- and resolution-specific
  values are documented in [CRT Profile Settings](Profiles/README.md).
- **Direct Video**: Explicit 15 kHz (240p) and 31 kHz (480p) output.
- **Selectable Asteroids Cadence**: Select frame-accurate 61.52Hz video output
  for Asteroids and Asteroids Deluxe, or the more compatible 60Hz mode.
- **Geometry Controls**: Rotation, mirroring, and Normal/Wide framing for monitor
  and cabinet installations.
- **Complete MRA Integration**: Game-specific ROMs, controls, coin mechanisms,
  DIP switches, Service Mode, Diagnostic Step, and Slam Switch mappings are
  provided by the supplied MRAs.
