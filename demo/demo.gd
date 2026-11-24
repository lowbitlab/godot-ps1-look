extends Node3D
## Demo scene of the Lowbit PS1 Look add-on: a small yard seen by a slowly orbiting camera.
##
## Keys: Space = effect on/off, P = palette, D = dithering, F = fog, Tab = settings panel.
## Command line (after `--`): --still (camera stops), --time=<seconds> (orbit time), --preset=<name>,
## --shot=<file.png> (save the main viewport after a few frames and quit).

const ORBIT_RADIUS := 19.0
const ORBIT_HEIGHT := 6.5
const ORBIT_SPEED := 0.1  # radians per second
const TARGET := Vector3(0.0, 1.5, -1.0)

var t := 0.0
var still := false

@onready var look: LowbitPS1Look = $PS1Look
@onready var camera: Camera3D = $Camera
@onready var panel: LowbitPS1Panel = $UI/Margin/Panel
@onready var ui: CanvasLayer = $UI


func _ready() -> void:
	panel.bind(look)
	apply_preset("on")
	panel.visible = true
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--still":
			still = true
		elif arg.begins_with("--time="):
			t = float(arg.get_slice("=", 1))
		elif arg.begins_with("--preset="):
			apply_preset(arg.get_slice("=", 1))
		elif arg.begins_with("--shot="):
			shot = arg.get_slice("=", 1)
	_place_camera()
	if shot != "":
		await _save_shot(shot)
		get_tree().quit()


func _process(delta: float) -> void:
	if not still:
		t += delta
	_place_camera()


func _place_camera() -> void:
	var a := 0.6 + t * ORBIT_SPEED
	camera.position = Vector3(sin(a) * ORBIT_RADIUS, ORBIT_HEIGHT, cos(a) * ORBIT_RADIUS)
	camera.look_at(TARGET)


## Presets used for the screenshots and the tests.
func apply_preset(name: String) -> void:
	var s := look.settings
	look.enabled = true
	s.resolution_mode = LowbitPS1Settings.ResolutionMode.PIXEL_SIZE
	s.pixel_size = 3
	s.reduce_colors = true
	s.color_levels = 32
	s.use_palette = false
	s.dither_enabled = false
	s.dither_strength = 0.6
	s.fog_enabled = false
	s.fog_start = 14.0
	s.fog_end = 70.0
	panel.visible = false
	match name:
		"off":
			look.enabled = false
		"on":
			pass
		"palette":
			s.use_palette = true
			s.palette_preset = LowbitPS1Settings.PalettePreset.LOWBIT_16
			s.dither_enabled = true
			s.dither_strength = 0.8
		"dither":
			s.color_levels = 6
			s.dither_enabled = true
			s.dither_strength = 1.0
		"fog":
			s.fog_enabled = true
		"panel":
			s.dither_enabled = true
			s.fog_enabled = true
			panel.visible = true
			panel.bind(look)
	if panel.visible == false and name != "panel":
		panel.bind(look)


func _save_shot(path: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved %s %dx%d" % [path, img.get_width(), img.get_height()])


func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if e == null or not e.pressed or e.echo:
		return
	var s := look.settings
	match e.keycode:
		KEY_SPACE: look.enabled = not look.enabled
		KEY_P: s.use_palette = not s.use_palette
		KEY_D: s.dither_enabled = not s.dither_enabled
		KEY_F: s.fog_enabled = not s.fog_enabled
		KEY_TAB:
			panel.visible = not panel.visible
			if panel.visible:
				panel.bind(look)
