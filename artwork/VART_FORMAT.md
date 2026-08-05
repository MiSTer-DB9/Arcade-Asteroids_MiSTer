# VART Artwork Container

VART is a sequential, palette-indexed artwork format for the VFB presentation
pipeline. Version 1 carries one or more resolution planes and retains RGBA
palette data. The initial Asteroids implementation decodes one background
layer. Layer descriptors leave room for a later foreground stream.

All integers are little-endian. Every palette, payload, and row starts at an
eight-byte boundary. Reserved fields must be zero.

## Header

The 64-byte header contains:

| Offset | Size | Field |
| ---: | ---: | --- |
| `0x00` | 4 | ASCII `VART` |
| `0x04` | 1 | Version, currently 1 |
| `0x05` | 1 | Flags, currently zero |
| `0x06` | 1 | Layer count |
| `0x07` | 1 | Plane count |
| `0x08` | 4 | Total container bytes |
| `0x0c` | 4 | CRC32 from the descriptor table through EOF |
| `0x10` | 4 | Descriptor-table offset, currently 64 |
| `0x14` | 2 | Descriptor bytes, currently 48 |
| `0x16` | 2 | Reserved |
| `0x18` | 8 | Reserved |
| `0x20` | 32 | Reserved |

## Plane Descriptor

Each 48-byte descriptor contains:

| Offset | Size | Field |
| ---: | ---: | --- |
| `0x00` | 2 | Width |
| `0x02` | 2 | Height |
| `0x04` | 1 | Layer identifier |
| `0x05` | 1 | Layer role: 0 background, 1 foreground |
| `0x06` | 1 | Palette-index bits: 4, 6, or 8 |
| `0x07` | 1 | Flags: bit 0 row-copy support, bit 1 alpha present |
| `0x08` | 2 | Palette entries: 16, 64, or 256 |
| `0x0a` | 2 | Reserved |
| `0x0c` | 4 | Palette offset |
| `0x10` | 4 | Palette bytes |
| `0x14` | 4 | Compressed payload offset |
| `0x18` | 4 | Compressed payload bytes |
| `0x1c` | 4 | Decompressed pixel count |
| `0x20` | 4 | Row count |
| `0x24` | 4 | Stream layout, currently zero for a separate stream |
| `0x28` | 8 | Reserved |

Palette entries are RGBA8888 in red, green, blue, alpha byte order. Descriptors
may point to one shared palette or to independent palettes.

The repository builder accepts indexed PNG sources only. PNG palette
transparency is retained in these RGBA entries; RGB and RGBA source images are
not converted implicitly.

## Rows And Tokens

Each row begins with a 16-bit encoded-bit count. Token bits follow least
significant bit first and are padded with zeroes through the next qword.

| Header | Operation | Count |
| --- | --- | ---: |
| `0LLLLLLL` | Literal indices follow | 1 to 128 |
| `10LLLLLL` | Repeat one following index | 1 to 64 |
| `11LLLLLL` | Copy from the preceding row | 1 to 64 |

Each palette index consumes the descriptor's 4, 6, or 8 bits. A valid row
consumes exactly its declared bits and emits exactly its declared width. The
first row cannot contain a previous-row token.

## Current Asteroids Planes

| Mode | Dimensions |
| --- | ---: |
| 1080p | 1360 x 1080 |
| 720p at 60 or 120 Hz | 916 x 720 |
| 480p | 640 x 480 |
| 240p | 640 x 240 |

The renderer selects a background plane only on an exact dimension match.
