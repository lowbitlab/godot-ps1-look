extends Node
## Headless-friendly checks of the Lowbit PS1 Look add-on. They need a renderer (run them under xvfb-run, see run_tests.sh).
## Usage: godot --path . res://tests/test_runner.tscn -- --test=<name>
## Each test prints "PASS <name>: <numbers>" or "FAIL <name>: <reason>" and quits with exit code 0 / 1.

const DEMO := preload("res://demo/demo.tscn")

var _demo: Node3D


func _ready() -> void:
	var test_name := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test="):
			test_name = arg.get_slice("=", 1)
	if not has_method("_test_" + test_name):
		print("FAIL %s: unknown test" % test_name)
		get_tree().quit(1)
		return
	var result: Array = await call("_test_" + test_name)
	print("%s %s: %s" % ["PASS" if result[0] else "FAIL", test_name, result[1]])
	get_tree().quit(0 if result[0] else 1)


# ---------- helpers ----------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _start_demo(preset: String) -> void:
	_demo = DEMO.instantiate()
	_demo.still = true
	add_child(_demo)
	await _frames(3)
	_demo.apply_preset(preset)
	await _frames(5)


func _diff(a: Image, b: Image) -> Dictionary:
	var da := a.get_data()
	var db := b.get_data()
	if da.size() != db.size():
		return {"pixels": -1, "max": 255, "mean": 255.0}
	if da == db:
		return {"pixels": 0, "max": 0, "mean": 0.0}
	var changed := 0
	var biggest := 0
	var total := 0
	var count := da.size() / 4
	for i in count:
		var worst := 0
		for c in 3:
			worst = maxi(worst, absi(da[i * 4 + c] - db[i * 4 + c]))
		if worst > 0:
			changed += 1
			total += worst
			biggest = maxi(biggest, worst)
	return {"pixels": changed, "max": biggest, "mean": float(total) / count}


func _fmt(d: Dictionary) -> String:
	return "%d differing pixels, max channel difference %d, mean %.4f" % [d.pixels, d.max, d.mean]


# ---------- tests ----------

## With the camera still, two frames one second apart must be identical, with every effect on.
func _test_still_frames() -> Array:
	var report := []
	for preset in ["on", "palette", "dither", "fog", "panel"]:
		await _start_demo(preset)
		var a := await _grab()
		await get_tree().create_timer(1.0).timeout
		var b := await _grab()
		var d := _diff(a, b)
		report.append("%s: %s" % [preset, _fmt(d)])
		_demo.queue_free()
		await _frames(2)
		if d.pixels != 0:
			return [false, "; ".join(report)]
	return [true, "; ".join(report)]


## Pixel size 1, no colour reduction, no dither must give the same image as the effect switched off:
## the add-on adds no geometric change and no texture-mapping change of its own.
func _test_identity() -> Array:
	await _start_demo("off")
	var off_img := await _grab()
	var s: LowbitPS1Settings = _demo.look.settings
	_demo.look.enabled = true
	s.pixel_size = 1
	s.reduce_colors = false
	s.use_palette = false
	s.dither_enabled = false
	s.fog_enabled = false
	await _frames(5)
	var on_img := await _grab()
	var d := _diff(off_img, on_img)
	return [d.pixels == 0 or (d.max <= 2 and d.mean < 0.05), _fmt(d)]


## A vertical edge must follow the true perspective projection while the camera glides sideways:
## monotonic, within one low-resolution pixel of the projected position.
func _test_edge_follows_projection() -> Array:
	var root := Node3D.new()
	add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(30, 30, 0.1)
	box.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.WHITE
	box.material_override = m
	box.position = Vector3(15, 0, -6)  # its left edge is at x = 0
	root.add_child(box)
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.make_current()
	var look := LowbitPS1Look.add_to(root)
	look.settings.pixel_size = 4
	look.settings.reduce_colors = false
	look.settings.dither_enabled = false
	await _frames(4)
	var previous := 1e9
	var worst := 0.0
	var steps := 48
	for k in steps + 1:
		cam.position.x = k * 0.01
		await _frames(2)
		var img := await _grab()
		var measured := -1
		for x in img.get_width():
			if img.get_pixel(x, 360).r > 0.5:
				measured = x
				break
		var expected := cam.unproject_position(Vector3(0, 0, -5.95)).x
		var err := absf(measured - expected)
		worst = maxf(worst, err)
		if measured < 0 or float(measured) > previous + 0.5:
			return [false, "step %d: edge at %d after %.0f (not monotonic) or missing" % [k, measured, previous]]
		previous = measured
		if err > 4.0:
			return [false, "step %d: edge at %d, projected %.1f" % [k, measured, expected]]
	root.queue_free()
	return [true, "%d steps of 1 cm, worst distance to the projected edge %.2f px (one low-resolution pixel is 4 px)" % [steps + 1, worst]]


## Consecutive frames while the camera moves 5 mm per frame: the look must not add noise compared with the plain image.
func _test_motion_noise() -> Array:
	var out := []
	for preset in ["off", "on", "dither", "palette"]:
		await _start_demo(preset)
		var t0: float = _demo.t
		var frames: Array[Image] = []
		for k in 6:
			_demo.t = t0 + k * 0.0027  # 0.1 rad/s * 19 m * 0.0027 s = 5 mm
			await _frames(2)
			frames.append(await _grab())
		var worst := 0.0
		for k in 5:
			var d := _diff(frames[k], frames[k + 1])
			worst = maxf(worst, d.pixels / float(frames[k].get_width() * frames[k].get_height()))
		out.append({"preset": preset, "changed": worst})
		_demo.queue_free()
		await _frames(2)
	var text := []
	for o in out:
		text.append("%s: %.2f %% of pixels change per frame" % [o.preset, o.changed * 100.0])
	# The look must not make the picture noisier than the plain image: each preset changes at most 1.5x as many pixels.
	var ok := true
	for o in out:
		ok = ok and o.changed <= out[0].changed * 1.5
	return [ok, "; ".join(text)]


## Camera moving every frame (9 cm steps): the frame grabbed right after each move with the effect at pixel size 1
## (no reduction, no dither) must equal the plain image exactly. Catches a lagging, snapped or jittered mirror camera.
func _test_moving_identity() -> Array:
	await _start_demo("off")
	var t0: float = _demo.t
	var plain: Array[Image] = []
	for k in 8:
		_demo.t = t0 + k * 0.5
		await get_tree().process_frame
		plain.append(await _grab())
	var s: LowbitPS1Settings = _demo.look.settings
	_demo.look.enabled = true
	s.pixel_size = 1
	s.reduce_colors = false
	s.use_palette = false
	s.dither_enabled = false
	s.fog_enabled = false
	await _frames(5)
	var worst_pixels := 0
	var worst_max := 0
	for k in 8:
		_demo.t = t0 + k * 0.5
		await get_tree().process_frame
		var d := _diff(plain[k], await _grab())
		worst_pixels = maxi(worst_pixels, d.pixels)
		worst_max = maxi(worst_max, d.max)
	return [worst_pixels == 0, "8 moving frames, worst case %d differing pixels (max channel difference %d)" % [worst_pixels, worst_max]]


## A node that starts with enabled = false must not cover the normal 3D view, and must not touch disable_3d.
func _test_start_disabled() -> Array:
	var root := Node3D.new()
	add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var look := LowbitPS1Look.new()
	look.enabled = false
	root.add_child(look)
	await _frames(4)
	var img := await _grab()
	var c := img.get_pixel(640, 360)
	var off_ok := c.r > 0.9 and c.g < 0.1 and not get_viewport().disable_3d and not look.visible
	look.enabled = true
	await _frames(4)
	var on_ok := get_viewport().disable_3d and look.visible
	var c2 := (await _grab()).get_pixel(640, 360)
	root.queue_free()
	return [off_ok and on_ok and c2.r > 0.9, "disabled: centre %s, disable_3d %s, layer visible %s; enabled: centre %s" % [c, get_viewport().disable_3d, look.visible, c2]]


## Two nodes on one viewport (an autoload and a scene node): disable_3d is restored only when the last one leaves.
func _test_two_nodes() -> Array:
	var vp := get_viewport()
	var root := Node3D.new()
	add_child(root)
	var a := LowbitPS1Look.add_to(root)
	var b := LowbitPS1Look.add_to(root)
	await _frames(3)
	var both_on := vp.disable_3d
	a.queue_free()
	await _frames(2)
	var one_left := vp.disable_3d
	b.queue_free()
	await _frames(2)
	var none_left := not vp.disable_3d
	root.queue_free()
	return [both_on and one_left and none_left, "two nodes: %s, one removed: %s, both removed restored: %s" % [both_on, one_left, none_left]]


## Window pixels per low-resolution pixel is always a whole number, in both modes and after a resize.
func _test_integer_scale() -> Array:
	await _start_demo("on")
	var look: LowbitPS1Look = _demo.look
	var s := look.settings
	var report := []
	for size in [Vector2i(1280, 720), Vector2i(1000, 600), Vector2i(777, 431)]:
		get_window().size = size
		await _frames(4)
		for ps in [1, 3, 5]:
			s.pixel_size = ps
			await _frames(2)
			var internal := look.get_internal_size()
			var expected := Vector2i(ceili(size.x / float(ps)), ceili(size.y / float(ps)))
			if internal != expected or look.get_pixel_scale() != ps:
				return [false, "window %s pixel_size %d: internal %s, expected %s" % [size, ps, internal, expected]]
		report.append("%dx%d ok" % [size.x, size.y])
	s.resolution_mode = LowbitPS1Settings.ResolutionMode.FIXED
	s.fixed_size = Vector2i(320, 240)
	get_window().size = Vector2i(1280, 720)
	await _frames(4)
	if look.get_internal_size() != Vector2i(320, 240) or look.get_pixel_scale() != 3:
		return [false, "FIXED 320x240 in 1280x720: internal %s scale %d" % [look.get_internal_size(), look.get_pixel_scale()]]
	report.append("FIXED 320x240 -> scale 3")
	return [true, ", ".join(report)]


## Turning the node off gives the 3D back to the main viewport; removing it restores the old state.
func _test_toggle() -> Array:
	await _start_demo("on")
	var vp := get_viewport()
	if not vp.disable_3d:
		return [false, "disable_3d should be true while enabled"]
	_demo.look.enabled = false
	await _frames(2)
	if vp.disable_3d:
		return [false, "disable_3d should be false after enabled = false"]
	var off_img := await _grab()
	var lit := 0
	for x in range(0, 1280, 40):
		if off_img.get_pixel(x, 700).g > 0.2:
			lit += 1
	_demo.look.enabled = true
	await _frames(2)
	_demo.look.queue_free()
	await _frames(2)
	return [lit > 5 and not vp.disable_3d, "3D visible with the effect off (%d of 32 samples lit), disable_3d restored after removal" % lit]


## The node works when it is added from code before any camera exists (autoload case) and follows a camera added later.
func _test_late_camera() -> Array:
	var root := Node3D.new()
	add_child(root)
	var look := LowbitPS1Look.add_to(root)
	look.settings.pixel_size = 4
	await _frames(3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	await _frames(4)
	var img := await _grab()
	var c := img.get_pixel(640, 360)
	return [c.r > 0.9 and c.g < 0.1, "centre pixel after the camera appeared: %s" % c]


## The palette limits the output colours; levels limit the channel values.
func _test_colour_reduction() -> Array:
	await _start_demo("palette")
	var s: LowbitPS1Settings = _demo.look.settings
	var allowed := {}
	for c in s.palette:
		allowed[c.to_html(false)] = true
	await _frames(3)
	var img := await _grab()
	var seen := {}
	for y in range(0, 720, 7):
		for x in range(0, 1280, 7):
			var c := img.get_pixel(x, y)
			seen[c.to_html(false)] = true
	var outside := 0
	for k in seen:
		if not allowed.has(k):
			outside += 1
	if outside > 0:
		return [false, "%d colours outside the palette" % outside]
	s.use_palette = false
	s.color_levels = 4
	s.dither_enabled = false
	s.fog_enabled = false
	await _frames(4)
	img = await _grab()
	var values := {}
	for y in range(0, 720, 11):
		for x in range(0, 1280, 11):
			var c := img.get_pixel(x, y)
			values[snappedf(c.r, 0.01)] = true
			values[snappedf(c.g, 0.01)] = true
			values[snappedf(c.b, 0.01)] = true
	return [values.size() <= 4 + 2, "palette: %d distinct colours all inside the %d-colour palette; 4 levels: %d distinct channel values" % [seen.size(), allowed.size(), values.size()]]


## No vertex or texture-coordinate writes anywhere in the add-on: a scan for forbidden tokens, comments ignored.
func _test_static_scan() -> Array:
	var forbidden := ["shader_type spatial", "VERTEX", "noperspective", "UV =", "UV=", "UV +=", "UV -=", "UV *=", "UV /=", "UV.x =", "UV.y =", "UV.xy =", "snap_lines", "affine", "jitter", "vertex_snap"]
	var files := _list_files("res://addons/lowbit_ps1_look")
	var hits := []
	var scanned := 0
	for path: String in files:
		if not (path.ends_with(".gd") or path.ends_with(".gdshader")):
			continue
		scanned += 1
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line
			for marker in ["//", "#"]:
				var i := code.find(marker)
				if i >= 0:
					code = code.substr(0, i)
			for word in forbidden:
				if word in code:
					hits.append("%s: %s" % [path, word])
	return [hits.is_empty(), "%d script / shader files scanned, %s" % [scanned, "no forbidden token" if hits.is_empty() else str(hits)]]


func _list_files(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_list_files(dir.path_join(d)))
	return out
