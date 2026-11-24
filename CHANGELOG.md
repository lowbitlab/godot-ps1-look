# Changelog

All notable changes to Lowbit PS1 Look are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-21

First release.

### Added
- `LowbitPS1Look` node: renders the current 3D camera into a small `SubViewport` and shows it at a whole-number scale with nearest-neighbour filtering. It can also be added as an autoload.
- `LowbitPS1Settings` resource with editor-friendly exported properties, grouped as Resolution, Colour, Dithering and Fog. Every change applies live.
- Resolution modes: pixel size (the internal size follows the window) and fixed internal size (largest whole-number scale, black bars).
- Colour reduction by levels per channel (32 = 15-bit colour) or by palette (up to 64 colours, three ready-made palettes).
- Ordered 4x4 Bayer dithering, locked to the low-resolution pixel grid, with an on/off switch and a strength value.
- Optional depth fog on a private copy of the camera's `Environment`.
- `LowbitPS1Panel`: an optional settings panel built in code.
- Editor menu entry (Project > Tools) that adds the node to the open scene.
- Demo scene and test scripts (`tests/`), six screenshots.

### Not included, on purpose
- No vertex snapping, no affine texture mapping and no jitter. Geometry and textures are drawn by the engine exactly as usual.
