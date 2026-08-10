# Asteroids Artwork Builder

`build_artwork.py` validates indexed PNG artwork, compresses it into a VART
container, and embeds that container as ROM index 2 in a new MiSTer MRA. The
current 720-wide plane set is the default; use `--format legacy` for the former
640-wide 240p and 480p planes.

The supplied green and orange Asteroids Deluxe MRAs already contain their
artwork. The builder can also add artwork to a new copy of the supplied
Asteroids or Lunar Lander MRA. Use your own indexed images when building a
custom version.

## Required Images

For complete resolution coverage, supply one image at each supported size:

| Core Mode | Required Size |
|---|---:|
| 1080p | 1360x1080 |
| 720p | 916x720 |
| 480p / 480i | 720x480 |
| 240p | 720x240 |

Any MRA may contain a subset; artwork is shown only at the included
resolutions. Every supplied image must match one of the sizes above.

Run the builder from the repository root:

```powershell
python artwork/build_artwork.py `
  "releases/Asteroids Deluxe (v3 green).mra" `
  "my_art/background_1360x1080.png" `
  "my_art/background_916x720.png" `
  "my_art/background_720x480.png" `
  "my_art/background_720x240.png"
```

For an older core using 640-wide low-resolution video, pass `--format legacy`
and supply 640x480 and 640x240 planes instead.

The source MRA is never modified. The generated MRA is written beside it with
an `_art` suffix. If that filename already exists, the builder uses `_art1`,
`_art2`, and so on. Any existing artwork payload is replaced only in the
generated copy.

## Image Format

Images must be indexed PNGs (`P` mode) using no more than 256 palette entries.
The builder compacts the used palette and stores indices at 4, 6, or 8 bits for
up to 16, 64, or 256 colors.

Use 16 colors where visual quality permits. This usually provides the best
compression and keeps the embedded MRA artwork reasonably small.

Good perceptual palette quantizers include
[pngquant/libimagequant](https://pngquant.org/), GIMP's indexed-color
conversion, and ImageMagick's palette quantization tools.

Artwork is fixed to the screen and does not follow vector orientation. Prepare
rotated artwork in advance when using a vertically mounted display.

## Generated Files

Generated files are written under `artwork/generated`:

- `<mra-name>.vart`: compressed VART container.
- `rom_index_2.xml`: ROM index 2 element for manual MRA integration.
- `artwork_stats.json`: dimensions, palette depth, compression statistics,
  decoder round-trip results, and the three largest scanlines.

The same summary is printed when the command completes. Use
`--no-update-mra` to validate and generate these files without creating a new
MRA.
