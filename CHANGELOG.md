# Changelog

All notable changes to this project will be documented in this file.

## Follow-up Update [20260804]

### Features

- **Asteroids Deluxe Cabinet Artwork**: Asteroids Deluxe used a
  blacklight-illuminated 3D backdrop viewed with the vector display through a
  half-silvered mirror. Two supplied MRAs reproduce the known green and orange
  artwork variants at 240p, 480p, 720p, and 1080p.
- **Custom Artwork Builder**: The included Python tool validates and compresses
  resolution-specific indexed artwork and creates a new MRA containing it.
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

- **CRT Output Guide**: Documents core-native and MiSTer-scaled analog output,
  15 kHz and 31 kHz modelines, sync choices, and the required renderer-height
  ranges.
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
