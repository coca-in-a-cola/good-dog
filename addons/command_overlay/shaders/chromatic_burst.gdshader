// Short radial chromatic aberration burst on line appearance.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;

void fragment() {
	vec2 d = (SCREEN_UV - vec2(0.5)) * amount;
	float r = texture(screen_texture, SCREEN_UV + d).r;
	float g = texture(screen_texture, SCREEN_UV).g;
	float b = texture(screen_texture, SCREEN_UV - d).b;
	COLOR = vec4(r, g, b, 1.0);
}
