// Blurred glow copy of the overlay text. Applied to a CanvasGroup, whose
// children are rendered into a mipmapped backbuffer that this shader samples.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float radius_px = 18.0;
uniform float intensity = 1.0;

void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * radius_px / 3.0;
	vec4 sum = vec4(0.0);
	float weight_sum = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 o = vec2(float(x), float(y));
			float w = exp(-dot(o, o) / 4.5);
			sum += textureLod(screen_texture, SCREEN_UV + o * step_uv, 2.0) * w;
			weight_sum += w;
		}
	}
	vec4 c = sum / weight_sum;
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	COLOR = vec4(c.rgb, c.a * intensity);
}
