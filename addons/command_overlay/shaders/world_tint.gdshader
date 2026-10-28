// OVER_WORLD backdrop: desaturates and darkens whatever is rendered below the overlay layer.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float saturation = 0.2;
uniform float brightness = 0.6;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(luma), c, saturation) * brightness, 1.0);
}
