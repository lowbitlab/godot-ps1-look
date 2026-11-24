// Lowbit PS1 Look: colour reduction and ordered dithering of the low-resolution image.
//
// This is a 2D (canvas_item) shader that only reads and writes colours of the finished image.
// It never moves a vertex and never changes a texture coordinate of any 3D surface:
// the geometry and the textures are rendered by the engine's own, perspective-correct pipeline.
shader_type canvas_item;

uniform bool reduce_colors = true;
uniform float levels : hint_range(2.0, 256.0) = 32.0;
uniform bool use_palette = false;
uniform int palette_size : hint_range(1, 64) = 16;
uniform sampler2D palette_tex : filter_nearest, repeat_disable;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.0;
// Dither amplitude when a palette is used (levels do not apply there).
uniform float palette_spread = 0.2;

const float BAYER_4X4[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

// Threshold of the 4x4 Bayer matrix for a pixel of the low-resolution grid, in (-0.5, 0.5).
float bayer(ivec2 p) {
	int i = (p.x & 3) + ((p.y & 3) << 2);
	return (BAYER_4X4[i] + 0.5) / 16.0 - 0.5;
}

vec3 nearest_palette_color(vec3 c) {
	vec3 best = texelFetch(palette_tex, ivec2(0, 0), 0).rgb;
	float best_d = distance(c, best);
	for (int i = 1; i < 64; i++) {
		if (i >= palette_size) {
			break;
		}
		vec3 p = texelFetch(palette_tex, ivec2(i, 0), 0).rgb;
		float d = distance(c, p);
		if (d < best_d) {
			best_d = d;
			best = p;
		}
	}
	return best;
}

void fragment() {
	ivec2 tex_size = textureSize(TEXTURE, 0);
	ivec2 px = clamp(ivec2(UV * vec2(tex_size)), ivec2(0), tex_size - ivec2(1));
	vec4 src = texelFetch(TEXTURE, px, 0);
	vec3 c = src.rgb;
	float d = bayer(px) * dither_strength;

	if (use_palette) {
		c = nearest_palette_color(clamp(c + vec3(d * palette_spread), 0.0, 1.0));
	} else if (reduce_colors) {
		float steps = levels - 1.0;
		c = floor(clamp(c + vec3(d / steps), 0.0, 1.0) * steps + 0.5) / steps;
	} else if (dither_strength > 0.0) {
		// No colour reduction: a faint dither on the 8-bit image.
		c = clamp(c + vec3(d / 255.0), 0.0, 1.0);
	}
	COLOR = vec4(c, 1.0);
}
