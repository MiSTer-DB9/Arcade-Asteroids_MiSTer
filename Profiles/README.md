# CRT Profile Settings

These tables list the fixed settings used by the current CRT profiles. Select
`Custom 1` or `Custom 2` in the OSD and enter the values from any row to use it
as a starting point for experimentation.

Profiles vary with the selected game and output resolution. The 240p and 480p
profiles currently use identical settings. The 720p settings apply at both
60Hz and 120Hz.

Grouped columns follow the OSD order:

- **Artwork**: Background / Background Blend
- **Bloom**: Bloom Width / Bloom Curve
- **Halo**: Halo / Halo Curve / Halo Spread / Halo Compression
- **Decay**: Inter-Frame Decay / Intra-Frame Decay

Background artwork is only displayed when the active MRA contains valid
artwork for the current resolution. Background Blend has no effect when
Background is Off.

## Asteroids Deluxe

### 240p / 480p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | On / 0 | 2x | Linear 2 | Off / Minimal | Off / Minimal / Original / Off | Off / Off | Deluxe Blue |
| 80s Cruise Control | On / 0 | 2x | Linear 2 | Thin / Mild+ | 0.75x / Mild / Original / 16 | Short / Off | Deluxe Blue |
| 80s Overdrive | On / 0 | 2.5x | Bright | Thin / Mild+ | 1.0x / Moderate / Original / 16 | Medium / Off | Deluxe Blue |
| Red Alert | On / 0 | 3x | Bright | Tight / Strong- | 1.5x / Strong / Wide 1 / Off | Long / LUT A | Red |
| Ultraviolet | On / 0 | 3x | Bright | Tight / Strong | 1.5x / Strong / Wide 2 / Off | Long / LUT C | Purple |

### 720p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | On / 0 | 4x | Bright | Thin / Moderate | 1.25x / Minimal / Wide 1 / 8 | Off / Off | Deluxe Blue |
| 80s Cruise Control | On / 0 | 4x | Bright | Thin / Mod+ | 1.5x / Minimal / Original / 16 | Short / Off | Deluxe Blue |
| 80s Overdrive | On / 0 | 5x | Bright | Tight / Mild+ | 1.5x / Mild / Original / 8 | Medium / Off | Deluxe Blue |
| Red Alert | On / 0 | 5x | Bright | Soft / Moderate | 1.5x / Strong / Wide 1 / Off | Long / LUT A | Red |
| Ultraviolet | On / 0 | 5x | Bright | Wide / Strong | 1.5x / Strong / Original / Off | Long / LUT A | Purple |

### 1080p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | On / 0 | 4x | Bright | Tight / Mild+ | 1.25x / Minimal / Original / 8 | Off / Off | Deluxe Blue |
| 80s Cruise Control | On / 0 | 5x | Bright | Tight / Moderate | 1.5x / Strong- / Wide 2 / 8 | Short / Off | Deluxe Blue |
| 80s Overdrive | On / 0 | 5x | Bright | Normal / Mild | 1.5x / Strong / Wide 2 / 24 | Medium / Off | Deluxe Blue |
| Red Alert | On / 0 | 5x | Bright | Broad / Moderate | 1.5x / Strong / Wide 2 / Off | Long / LUT A | Red |
| Ultraviolet | On / 0 | 5x | Bright | Wide / Strong | 1.5x / Strong / Original / Off | Long / LUT A | Purple |

## Asteroids

The artwork values are retained by the resolver, but standard Asteroids MRAs
do not contain background artwork.

### 240p / 480p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | Off / -2 | 2x | Linear 1 | Thin / Mild+ | 0.33x / Mild+ / Wide 1 / Off | Off / Off | White |
| 80s Cruise Control | Off / -2 | 2x | Linear 1 | Thin / Mild+ | 0.5x / Mild+ / Wide 3 / Off | Short / Off | White |
| 80s Overdrive | Off / -2 | 2.5x | Linear 1 | Tight / Mild | 0.5x / Mild / Wide 3 / Off | Medium / Off | White |
| Red Alert | Off / -2 | 3x | Bright | Tight / Strong- | 1.5x / Strong / Wide 1 / Off | Long / LUT A | Red |
| Ultraviolet | Off / -2 | 3x | Bright | Tight / Strong | 1.5x / Strong / Wide 2 / Off | Long / LUT C | Purple |

### 720p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | Off / -2 | 2.5x | Linear 1 | Thin / Mild+ | 0.25x / Mild+ / Wide 1 / Off | Off / Off | White |
| 80s Cruise Control | Off / -2 | 3x | Linear 1 | Tight / Mild | 0.33x / Mild / Wide 1 / Off | Short / Off | White |
| 80s Overdrive | Off / -2 | 3x | Linear 1 | Normal / Minimal | 0.5x / Minimal / Original / Off | Medium / Off | White |
| Red Alert | Off / -2 | 5x | Bright | Soft / Moderate | 1.5x / Strong / Wide 1 / Off | Long / LUT A | Red |
| Ultraviolet | Off / -2 | 5x | Bright | Wide / Strong | 1.5x / Strong / Original / Off | Long / LUT A | Purple |

### 1080p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | Off / -2 | 3x | Linear 1 | Tight / Mild+ | 0.25x / Mild+ / Wide 1 / Off | Off / Off | White |
| 80s Cruise Control | Off / -2 | 3x | Linear 1 | Soft / Mild | 0.33x / Mild / Wide 1 / Off | Short / Off | White |
| 80s Overdrive | Off / -2 | 3x | Linear 1 | Normal / Mild | 0.5x / Mild / Wide 1 / Off | Medium / Off | White |
| Red Alert | Off / -2 | 5x | Bright | Broad / Moderate | 1.5x / Strong / Wide 2 / Off | Long / LUT A | Red |
| Ultraviolet | Off / -2 | 5x | Bright | Wide / Strong | 1.5x / Strong / Original / Off | Long / LUT A | Purple |

## Lunar Lander

### 240p / 480p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | Off / -2 | 2x | Linear 1 | Thin / Mild+ | 0.33x / Mild+ / Wide 1 / Off | Off / Off | Lunar Green |
| 80s Cruise Control | Off / -2 | 2x | Linear 1 | Thin / Mild+ | 0.5x / Mild+ / Wide 3 / Off | Short / Off | Lunar Green |
| 80s Overdrive | Off / -2 | 2.5x | Linear 1 | Tight / Mild | 0.5x / Mild / Wide 3 / Off | Short / LUT C | Lunar Green |
| Red Alert | Off / -2 | 3x | Bright | Tight / Strong- | 1.5x / Strong / Wide 1 / Off | Long / LUT A | Red |
| Ultraviolet | Off / -2 | 3x | Bright | Tight / Strong | 1.5x / Strong / Wide 2 / Off | Long / LUT C | Purple |

### 720p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | Off / -2 | 2.5x | Linear 1 | Thin / Mild+ | 0.25x / Mild+ / Wide 1 / Off | Off / Off | Lunar Green |
| 80s Cruise Control | Off / -2 | 3x | Linear 1 | Tight / Mild | 0.33x / Mild / Wide 1 / Off | Short / Off | Lunar Green |
| 80s Overdrive | Off / -2 | 3x | Linear 1 | Normal / Minimal | 0.5x / Minimal / Original / Off | Short / LUT C | Lunar Green |
| Red Alert | Off / -2 | 5x | Bright | Soft / Moderate | 1.5x / Strong / Wide 1 / Off | Long / LUT A | Red |
| Ultraviolet | Off / -2 | 5x | Bright | Wide / Strong | 1.5x / Strong / Original / Off | Long / LUT A | Purple |

### 1080p

| Profile | Artwork | Dot Scale | Tone Mapping | Bloom | Halo | Decay | Vector Color |
|---|---|---:|---|---|---|---|---|
| A Touch of CRT | Off / -2 | 3x | Linear 1 | Tight / Mild+ | 0.25x / Mild+ / Wide 1 / Off | Off / Off | Lunar Green |
| 80s Cruise Control | Off / -2 | 3x | Linear 1 | Soft / Mild | 0.33x / Mild / Wide 1 / Off | Short / Off | Lunar Green |
| 80s Overdrive | Off / -2 | 3x | Linear 1 | Normal / Mild | 0.5x / Mild / Wide 1 / Off | Short / LUT C | Lunar Green |
| Red Alert | Off / -2 | 5x | Bright | Broad / Moderate | 1.5x / Strong / Wide 2 / Off | Long / LUT A | Red |
| Ultraviolet | Off / -2 | 5x | Bright | Wide / Strong | 1.5x / Strong / Original / Off | Long / LUT A | Purple |

## Off and Custom Profiles

`Off` is not a fixed preset. It disables bloom and halo while retaining the
selected Dot Scale, Tone Mapping, Inter-Frame Decay, and Intra-Frame Decay
values shown directly below the Profile option.

`Custom 1` and `Custom 2` are independent user-defined slots. Both can be
saved through MiSTer's **Save Settings** command.
