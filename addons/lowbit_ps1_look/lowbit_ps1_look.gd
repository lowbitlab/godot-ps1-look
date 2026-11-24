@tool
@icon("res://addons/lowbit_ps1_look/icon.png")
class_name LowbitPS1Look
extends CanvasLayer
## Gives a 3D scene a PS1-style look without distorting it.
##
## Drop this node anywhere in a scene (or add its script as an autoload). It renders the 3D world a second time
## into a small SubViewport that follows your current Camera3D, then shows that image at a whole-number scale with
## nearest-neighbour filtering and runs colour reduction and ordered dithering over it.
## Your own 2D and UI nodes are drawn on top at full resolution.
##
## Nothing here touches vertices or texture coordinates: no vertex snapping, no affine texture mapping, no jitter.
## With a still camera the output is identical from one frame to the next.
##
## While the node is enabled the main viewport does not render 3D itself (`Viewport.disable_3d`), so the
## scene is not drawn twice.

## Turns the whole effect on or off at runtime.
@export var enabled: bool = true:
	set(v):
		enabled = v
		if is_node_ready():
			_apply()
## The settings resource. A new one with defaults is created when this is empty.
@export var settings: LowbitPS1Settings:
	set(v):
		if settings and settings.changed.is_connected(_apply):
			settings.changed.disconnect(_apply)
		settings = v
		if settings and not settings.changed.is_connected(_apply):
			settings.changed.connect(_apply)
		if is_node_ready():
			_apply()

const META_USERS := &"lowbit_ps1_look_users"
const META_PREVIOUS := &"lowbit_ps1_look_previous_disable_3d"

var _viewport: SubViewport
var _background: ColorRect
var _screen: TextureRect
var _material: ShaderMaterial
var _camera: Camera3D
var _source_camera: Camera3D
var _source_environment: Environment
var _environment: Environment
var _palette_texture: ImageTexture
var _palette_key := PackedColorArray()
var _main_viewport: Viewport
var _active := false
var _environment_dirty := true
var _scale_factor := 1


func _init() -> void:
	layer = -1  # Below the default canvas layer, so your own 2D nodes and UI stay on top and crisp.


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if settings == null:
		settings = LowbitPS1Settings.new()
	_build()
	_apply()


func _enter_tree() -> void:
	if _viewport != null and not Engine.is_editor_hint():
		# Re-added to the tree after a reparent: reconnect to the (possibly different) main viewport.
		_main_viewport = get_viewport()
		if not _main_viewport.size_changed.is_connected(_update_size):
			_main_viewport.size_changed.connect(_update_size)
		_apply()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_deactivate()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if settings == null:
		out.append("No settings resource yet: defaults are used at runtime. Create a LowbitPS1Settings to edit them.")
	return out


## Rebuilds the private environment copy. Call it after changing the Environment your camera uses at runtime.
func refresh() -> void:
	_environment_dirty = true


## Size in pixels of the low-resolution image currently rendered.
func get_internal_size() -> Vector2i:
	return _viewport.size if _viewport else Vector2i.ZERO


## How many window pixels one low-resolution pixel covers (always a whole number).
func get_pixel_scale() -> int:
	return _scale_factor


## Adds a ready-to-use node to `root` and returns it. Used by the editor menu entry, also handy from scripts.
static func add_to(root: Node, settings_resource: LowbitPS1Settings = null) -> LowbitPS1Look:
	var node := LowbitPS1Look.new()
	node.name = "PS1Look"
	node.settings = settings_resource if settings_resource else LowbitPS1Settings.new()
	root.add_child(node, true)
	return node


func _build() -> void:
	_background = ColorRect.new()
	_background.name = "Bars"
	_background.color = Color.BLACK
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background, false, Node.INTERNAL_MODE_FRONT)

	_viewport = SubViewport.new()
	_viewport.name = "LowResViewport"
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.use_debanding = false
	_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_viewport.scaling_3d_scale = 1.0
	_viewport.audio_listener_enable_3d = false
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED  # Switched on by _activate().
	add_child(_viewport, false, Node.INTERNAL_MODE_FRONT)

	_camera = Camera3D.new()
	_camera.name = "MirrorCamera"
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # Its transform is already the interpolated one.
	_viewport.add_child(_camera)

	var shader := load("res://addons/lowbit_ps1_look/shaders/ps1_post.gdshader") as Shader
	_material = ShaderMaterial.new()
	_material.shader = shader

	_screen = TextureRect.new()
	_screen.name = "Screen"
	_screen.texture = _viewport.get_texture()
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.material = _material
	add_child(_screen, false, Node.INTERNAL_MODE_FRONT)

	visible = false  # Shown by _activate(); a node that starts disabled never covers the 3D view.
	_main_viewport = get_viewport()
	_main_viewport.size_changed.connect(_update_size)


func _activate() -> void:
	if _active:
		return
	_active = true
	# Several nodes may share one main viewport (an autoload plus a scene node): the first one remembers
	# the original value, the last one to leave puts it back.
	var users: int = _main_viewport.get_meta(META_USERS, 0)
	if users == 0:
		_main_viewport.set_meta(META_PREVIOUS, _main_viewport.disable_3d)
	_main_viewport.set_meta(META_USERS, users + 1)
	_main_viewport.disable_3d = true
	_viewport.world_3d = _main_viewport.find_world_3d()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not RenderingServer.frame_pre_draw.is_connected(_sync_camera):
		RenderingServer.frame_pre_draw.connect(_sync_camera)
	visible = true


func _deactivate() -> void:
	if _active:
		_active = false
		if is_instance_valid(_main_viewport):
			var users: int = maxi(_main_viewport.get_meta(META_USERS, 1) - 1, 0)
			_main_viewport.set_meta(META_USERS, users)
			if users == 0:
				_main_viewport.disable_3d = _main_viewport.get_meta(META_PREVIOUS, false)
		if RenderingServer.frame_pre_draw.is_connected(_sync_camera):
			RenderingServer.frame_pre_draw.disconnect(_sync_camera)
	# Always hide and stop rendering, also for a node that never became active.
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	visible = false


func _apply() -> void:
	if _viewport == null or settings == null:
		return
	if not enabled:
		_deactivate()
		return
	_activate()
	_update_size()
	_update_shader()
	_environment_dirty = true  # Fog settings may have changed: rebuild the environment copy.


func _update_size() -> void:
	if _viewport == null or settings == null:
		return
	var window := _main_viewport.get_visible_rect().size
	var internal: Vector2i
	var scale_factor: int
	match settings.resolution_mode:
		LowbitPS1Settings.ResolutionMode.FIXED:
			internal = settings.fixed_size
			scale_factor = maxi(1, mini(floori(window.x / internal.x), floori(window.y / internal.y)))
		_:
			scale_factor = maxi(1, settings.pixel_size)
			internal = Vector2i(ceili(window.x / scale_factor), ceili(window.y / scale_factor))
	_viewport.size = internal
	_scale_factor = scale_factor
	var shown := internal * scale_factor
	_screen.size = Vector2(shown)
	_screen.position = ((window - Vector2(shown)) * 0.5).floor() if settings.resolution_mode == LowbitPS1Settings.ResolutionMode.FIXED else Vector2.ZERO
	_background.visible = settings.resolution_mode == LowbitPS1Settings.ResolutionMode.FIXED


func _update_shader() -> void:
	_material.set_shader_parameter("reduce_colors", settings.reduce_colors)
	_material.set_shader_parameter("levels", float(settings.color_levels))
	var colors := settings.palette
	var use_palette := settings.use_palette and colors.size() > 0
	_material.set_shader_parameter("use_palette", use_palette)
	if use_palette:
		var count := mini(colors.size(), LowbitPS1Settings.MAX_PALETTE_COLORS)
		if colors != _palette_key or _palette_texture == null:
			_palette_key = colors.duplicate()
			var img := Image.create(LowbitPS1Settings.MAX_PALETTE_COLORS, 1, false, Image.FORMAT_RGBA8)
			for i in count:
				img.set_pixel(i, 0, colors[i])
			_palette_texture = ImageTexture.create_from_image(img)
		_material.set_shader_parameter("palette_tex", _palette_texture)
		_material.set_shader_parameter("palette_size", count)
	_material.set_shader_parameter("dither_strength", settings.dither_strength if settings.dither_enabled else 0.0)


## Copies the active Camera3D into the mirror camera, right before the frame is drawn (no frame of delay).
func _sync_camera() -> void:
	if not _active or _camera == null:
		return
	var src := _main_viewport.get_camera_3d()
	if src == null:
		return
	var world_env := _main_viewport.find_world_3d().environment
	var wanted_env: Environment = src.environment if src.environment else world_env
	if _environment_dirty or src != _source_camera or wanted_env != _source_environment:
		_environment_dirty = false
		_source_camera = src
		_source_environment = wanted_env
		_environment = _make_environment(wanted_env)
		_camera.environment = _environment
	# With 3D physics interpolation (Godot 4.4+) the real camera is drawn at its interpolated transform.
	_camera.global_transform = src.get_global_transform_interpolated() if src.has_method(&"get_global_transform_interpolated") else src.global_transform
	_camera.projection = src.projection
	_camera.fov = src.fov
	_camera.size = src.size
	_camera.frustum_offset = src.frustum_offset
	_camera.near = src.near
	_camera.far = src.far
	_camera.keep_aspect = src.keep_aspect
	_camera.h_offset = src.h_offset
	_camera.v_offset = src.v_offset
	_camera.cull_mask = src.cull_mask
	_camera.attributes = src.attributes
	if not _camera.current:
		_camera.make_current()


func _make_environment(base: Environment) -> Environment:
	if not settings.fog_enabled:
		return base  # The user's own Environment is used as it is (may be null).
	var env: Environment = base.duplicate() if base else Environment.new()
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = settings.fog_color
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = 1.0
	env.fog_depth_begin = settings.fog_start
	env.fog_depth_end = maxf(settings.fog_end, settings.fog_start + 0.1)
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 1.0
	if settings.fog_match_background and env.background_mode in [Environment.BG_CLEAR_COLOR, Environment.BG_COLOR]:
		env.background_mode = Environment.BG_COLOR
		env.background_color = settings.fog_color
	return env
