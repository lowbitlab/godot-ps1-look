@tool
@icon("res://addons/lowbit_ps1_look/icon.png")
class_name LowbitPS1Panel
extends PanelContainer
## An optional ready-made settings panel for a LowbitPS1Look node, built in code.
## Set `look` (or put the panel anywhere under the same scene and call `bind(look)`), and the controls edit
## the node's settings live. Handy for a graphics menu or for trying values out.

var look: LowbitPS1Look
var _controls := {}


func _init() -> void:
	custom_minimum_size = Vector2(300, 0)


## Connects the panel to a node and (re)builds the controls.
func bind(node: LowbitPS1Look) -> void:
	look = node
	for child in get_children():
		child.queue_free()
	_controls.clear()
	if look == null or look.settings == null:
		return
	_build()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var title := Label.new()
	title.text = "PS1 look"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	_check(box, "enabled", "Effect on", look.enabled, func(v: bool) -> void: look.enabled = v)
	_slider(box, "pixel_size", "Pixel size", 1, 8, 1, look.settings.pixel_size, func(v: float) -> void: look.settings.pixel_size = int(v))
	_check(box, "reduce_colors", "Reduce colours", look.settings.reduce_colors, func(v: bool) -> void: look.settings.reduce_colors = v)
	_slider(box, "color_levels", "Levels per channel", 2, 32, 1, look.settings.color_levels, func(v: float) -> void: look.settings.color_levels = int(v))
	_check(box, "use_palette", "Use palette", look.settings.use_palette, func(v: bool) -> void: look.settings.use_palette = v)

	var option := OptionButton.new()
	option.add_item("Lowbit 16", LowbitPS1Settings.PalettePreset.LOWBIT_16)
	option.add_item("Warm 8", LowbitPS1Settings.PalettePreset.WARM_8)
	option.add_item("Green 4", LowbitPS1Settings.PalettePreset.GREEN_4)
	option.add_item("Custom", LowbitPS1Settings.PalettePreset.CUSTOM)
	var index := option.get_item_index(look.settings.palette_preset)
	option.selected = maxi(index, 0)
	option.item_selected.connect(func(i: int) -> void:
		look.settings.palette_preset = option.get_item_id(i) as LowbitPS1Settings.PalettePreset)
	box.add_child(option)
	_controls["palette_preset"] = option

	_check(box, "dither_enabled", "Dithering", look.settings.dither_enabled, func(v: bool) -> void: look.settings.dither_enabled = v)
	_slider(box, "dither_strength", "Dither strength", 0.0, 1.0, 0.05, look.settings.dither_strength, func(v: float) -> void: look.settings.dither_strength = v)
	_check(box, "fog_enabled", "Fog", look.settings.fog_enabled, func(v: bool) -> void: look.settings.fog_enabled = v)
	_slider(box, "fog_start", "Fog start (m)", 0.0, 40.0, 0.5, look.settings.fog_start, func(v: float) -> void: look.settings.fog_start = v)
	_slider(box, "fog_end", "Fog end (m)", 5.0, 80.0, 0.5, look.settings.fog_end, func(v: float) -> void: look.settings.fog_end = v)


func _check(parent: Control, key: String, text: String, value: bool, on_change: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(func(v: bool) -> void: on_change.call(v))
	parent.add_child(c)
	_controls[key] = c


func _slider(parent: Control, key: String, text: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(100, 18)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(40, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = _fmt(value, step)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = _fmt(v, step)
		on_change.call(v))
	row.add_child(slider)
	row.add_child(readout)
	parent.add_child(row)
	_controls[key] = slider


func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%.2f" % v
