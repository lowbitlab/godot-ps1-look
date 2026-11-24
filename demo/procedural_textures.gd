class_name DemoTextures
extends RefCounted
## Small tileable textures drawn in code for the demo (64x64, nearest filtering).
## They are generated at start-up, so the demo ships no image files and has no third-party art.

const SIZE := 64


static func make(kind: String) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var img := Image.create(SIZE, SIZE, true, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, _pixel(kind, x, y, rng))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _noise(rng: RandomNumberGenerator, amount: float) -> float:
	return rng.randf_range(-amount, amount)


static func _pixel(kind: String, x: int, y: int, rng: RandomNumberGenerator) -> Color:
	match kind:
		"grass":
			var g := Color(0.28, 0.5, 0.2)
			var n := _noise(rng, 0.07)
			if (x * 7 + y * 13) % 11 == 0:
				g = Color(0.36, 0.58, 0.24)
			return Color(g.r + n, g.g + n, g.b + n * 0.5)
		"path":
			var n := _noise(rng, 0.05)
			return Color(0.55 + n, 0.43 + n, 0.3 + n * 0.5)
		"brick":
			var row := y / 8
			var offset := 8 if row % 2 == 1 else 0
			var bx := (x + offset) % 16
			var mortar := (y % 8) == 0 or bx == 0
			var n := _noise(rng, 0.04)
			if mortar:
				return Color(0.68 + n, 0.65 + n, 0.6 + n)
			var tint := float((row * 5 + (x + offset) / 16 * 3) % 4) * 0.025
			return Color(0.62 + tint + n, 0.28 + n, 0.2 + n)
		"stone":
			var cell := ((x / 16) + (y / 12) * 2) % 3
			var base := 0.5 + cell * 0.05
			var edge := (x % 16) == 0 or (y % 12) == 0
			var n := _noise(rng, 0.04)
			var v := base - (0.14 if edge else 0.0) + n
			return Color(v, v, v * 1.04)
		"wood":
			var plank := x / 16
			var grain := sin(y * 0.5 + plank * 2.0) * 0.03
			var edge := (x % 16) == 0
			var n := _noise(rng, 0.03)
			var v := 0.5 + grain + n - (0.15 if edge else 0.0)
			return Color(v * 1.0, v * 0.68, v * 0.38)
		"roof":
			var row := y / 8
			var offset := 4 if row % 2 == 1 else 0
			var edge := (y % 8) == 7 or ((x + offset) % 8) == 0
			var n := _noise(rng, 0.03)
			var v := 0.34 - (0.1 if edge else 0.0) + n
			return Color(v * 1.2, v * 0.55, v * 0.45)
		"barrel":
			var band := (y % 21) < 3
			var n := _noise(rng, 0.03)
			if band:
				return Color(0.3 + n, 0.3 + n, 0.32 + n)
			var plank := (x % 8) == 0
			var v := 0.46 + n - (0.12 if plank else 0.0)
			return Color(v, v * 0.66, v * 0.4)
		"crate":
			var frame := x < 5 or x >= SIZE - 5 or y < 5 or y >= SIZE - 5
			var diag := absi(x - y) < 3
			var n := _noise(rng, 0.03)
			var v := 0.56 if (frame or diag) else 0.44
			return Color(v + n, v * 0.7 + n, v * 0.4 + n)
		"leaf":
			var n := _noise(rng, 0.09)
			var g := 0.52 + (0.08 if (x * 5 + y * 3) % 9 == 0 else 0.0)
			return Color(0.2 + n, g + n, 0.2 + n * 0.5)
	return Color.MAGENTA
