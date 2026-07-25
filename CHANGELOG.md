# Changelog

All notable changes to this project will be documented in this file.

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
- **Ultra High Performance Renderer**: High-resolution vector output at 240p,
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
- **Video Profiles**: Five presets and two independent custom slots expose the
  complete advanced effects controls.
- **Direct Video**: Explicit 15 kHz (240p) and 31 kHz (480p) output.
- **Selectable Asteroids Cadence**: Select frame-accurate 61.52Hz video output
  for Asteroids and Asteroids Deluxe, or the more compatible 60Hz mode.
- **Geometry Controls**: Rotation, mirroring, and Normal/Wide framing for monitor
  and cabinet installations.
- **Complete MRA Integration**: Game-specific ROMs, controls, coin mechanisms,
  DIP switches, Service Mode, Diagnostic Step, and Slam Switch behavior are
  provided by the three supplied MRAs.
