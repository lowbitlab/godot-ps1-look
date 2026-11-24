@tool
@icon("res://addons/lowbit_ps1_look/icon.png")
class_name LowbitPS1Settings
extends Resource
## Settings for the Lowbit PS1 Look node.
##
## Every property emits `changed`, so the node updates while you edit the resource in the
## inspector or change a value from a script at runtime.
## There is no vertex snapping, no affine texture mapping and no jitter in this add-on:
## geometry and textures are rendered exactly as the engine renders them, only the final image is reduced.

enum ResolutionMode {
	PIXEL_SIZE, ## Each low-resolution pixel is `pixel_size` x `pixel_size` window pixels. The internal size follows the window.
	FIXED, ## A fixed internal size, shown at the largest whole-number scale that fits, with black bars.
}

enum PalettePreset {
	CUSTOM,
	LOWBIT_16, ## 16 general-purpose colours.
	WARM_8, ## 8 sepia tones.
	GREEN_4, ## 4 greens.
}

const MAX_PALETTE_COLORS := 64

const _PRESETS := {
	PalettePreset.LOWBIT_16: [
		"0d0f1a", "2a1d2e", "4a2c3a", "7a3d3a", "b05a3c", "e08a4a", "f2c86b", "fff3b0",
		"1d3a2a", "2f5e3a", "5b8c3a", "98b84a", "2f4a73", "4a7ab0", "8ab4d8", "e8f0f4",
	],
	PalettePreset.WARM_8: ["1a1410", "3b2a20", "6b4a32", "9a7048", "c89c64", "e8c88a", "f6e6b8", "fffaf0"],
	PalettePreset.GREEN_4: ["0b1f12", "235a31", "5e9a47", "c8e8a0"],
}

@export_group("Resolution")
## How the internal resolution is chosen.
@export var resolution_mode: ResolutionMode = ResolutionMode.PIXEL_SIZE:
	set(v):
		resolution_mode = v
		emit_changed()
## Window pixels per low-resolution pixel (PIXEL_SIZE mode). 3 gives 427x240 in a 1280x720 window.
@export_range(1, 16, 1) var pixel_size: int = 3:
	set(v):
		pixel_size = clampi(v, 1, 16)
		emit_changed()
## Internal size in pixels (FIXED mode), for example 320x240.
@export var fixed_size: Vector2i = Vector2i(320, 240):
	set(v):
		fixed_size = Vector2i(maxi(v.x, 16), maxi(v.y, 16))
		emit_changed()

@export_group("Colour")
## Reduce the number of colours.
@export var reduce_colors: bool = true:
	set(v):
		reduce_colors = v
		emit_changed()
## Levels per colour channel. 32 is the 15-bit colour of the original console; 256 means no reduction.
@export_range(2, 256, 1) var color_levels: int = 32:
	set(v):
		color_levels = clampi(v, 2, 256)
		emit_changed()
## Use a palette instead of per-channel levels.
@export var use_palette: bool = false:
	set(v):
		use_palette = v
		emit_changed()
## Ready-made palettes. Choosing one fills `palette`. Editing `palette` by hand switches this to CUSTOM.
@export var palette_preset: PalettePreset = PalettePreset.LOWBIT_16:
	set(v):
		palette_preset = v
		if v != PalettePreset.CUSTOM:
			_setting_preset = true
			palette = get_preset_colors(v)
			_setting_preset = false
		emit_changed()
## The palette colours (at most 64 are used).
@export var palette: PackedColorArray = PackedColorArray():
	set(v):
		palette = v
		if not _setting_preset and palette_preset != PalettePreset.CUSTOM \
				and v != get_preset_colors(palette_preset):
			palette_preset = PalettePreset.CUSTOM
		emit_changed()

@export_group("Dithering")
## Ordered dithering with a 4x4 Bayer matrix, locked to the low-resolution pixel grid.
@export var dither_enabled: bool = true:
	set(v):
		dither_enabled = v
		emit_changed()
## Strength of the dither. 1.0 spreads the pattern over one colour step.
@export_range(0.0, 1.0, 0.01) var dither_strength: float = 0.6:
	set(v):
		dither_strength = clampf(v, 0.0, 1.0)
		emit_changed()

@export_group("Fog")
## Depth fog. When on, the node works on a private copy of the camera's Environment, yours is not modified.
@export var fog_enabled: bool = false:
	set(v):
		fog_enabled = v
		emit_changed()
@export var fog_color: Color = Color(0.62, 0.68, 0.74):
	set(v):
		fog_color = v
		emit_changed()
## Distance in metres where the fog starts.
@export_range(0.0, 1000.0, 0.5, "or_greater") var fog_start: float = 6.0:
	set(v):
		fog_start = maxf(v, 0.0)
		emit_changed()
## Distance in metres where the fog is solid.
@export_range(0.1, 2000.0, 0.5, "or_greater") var fog_end: float = 30.0:
	set(v):
		fog_end = maxf(v, 0.1)
		emit_changed()
## Replace a plain-colour or clear-colour background with the fog colour so distant things fade into it.
@export var fog_match_background: bool = true:
	set(v):
		fog_match_background = v
		emit_changed()

var _setting_preset := false


func _init() -> void:
	# Fill the default palette without emitting `changed` before anyone listens.
	palette = get_preset_colors(palette_preset)


## Returns the colours of a ready-made palette (empty for CUSTOM).
static func get_preset_colors(preset: PalettePreset) -> PackedColorArray:
	var out := PackedColorArray()
	if _PRESETS.has(preset):
		for hex: String in _PRESETS[preset]:
			out.append(Color.html(hex))
	return out
