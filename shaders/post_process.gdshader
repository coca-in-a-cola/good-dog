// GDD §9 full-screen post stack: one pass over the rendered world (original, MIT).
// Order: barrel distortion → chromatic aberration + radial blur → saturation →
// canine dichromacy → praise bloom tint → vignette → grain → contrast dip →
// white flash → fade to black. Colour maths runs in linear light.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.25;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.0;
uniform float film_grain_intensity : hint_range(0.0, 0.2) = 0.03;
uniform float barrel_distortion : hint_range(0.0, 0.5) = 0.0;
uniform float canine_vision_weight : hint_range(0.0, 1.0) = 0.0; // 0.0 = human RGB, 1.0 = dichromatic
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform vec3 bloom_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float bloom_boost : hint_range(0.0, 2.0) = 0.0;
uniform float radial_blur_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float flash_white : hint_range(0.0, 1.0) = 0.0;
uniform float contrast_dip : hint_range(0.0, 1.0) = 0.0;
uniform float fade_black : hint_range(0.0, 1.0) = 0.0;

const int BLUR_SAMPLES = 10;
const float BLUR_REACH = 0.3;

// Viénot, Brettel & Mollon 1999 protanope simulation: RGB → LMS, rebuild the
// missing L response from M and S, back to RGB. Same constants as PostProcess.gd.
const mat3 RGB_TO_LMS = mat3(
		vec3(17.8824, 3.45565, 0.0299566),
		vec3(43.5161, 27.1554, 0.184309),
		vec3(4.11935, 3.86714, 1.46709));
const mat3 LMS_TO_RGB = mat3(
		vec3(0.0809444479, -0.0102485335, -0.000365296938),
		vec3(-0.130504409, 0.0540193266, -0.00412161469),
		vec3(0.116721066, -0.113614708, 0.693511405));
const vec2 PROTAN_L_FROM_MS = vec2(2.02344, -2.52581);

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 canine(vec3 lin) {
	vec3 lms = RGB_TO_LMS * lin;
	lms.x = dot(PROTAN_L_FROM_MS, lms.yz);
	return max(LMS_TO_RGB * lms, vec3(0.0));
}

vec3 sample_rgb(vec2 uv, vec2 ca) {
	return vec3(
			texture(screen_texture, uv + ca).r,
			texture(screen_texture, uv).g,
			texture(screen_texture, uv - ca).b);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = SCREEN_UV - vec2(0.5);
	vec2 da = vec2(d.x * aspect, d.y);
	float r2 = dot(da, da);
	float corner2 = 0.25 * aspect * aspect + 0.25;
	// Barrel: magnify the centre, keep the corners pinned (no out-of-frame reads).
	vec2 uv = vec2(0.5) + d * (1.0 + barrel_distortion * r2) / (1.0 + barrel_distortion * corner2);
	vec2 duv = uv - vec2(0.5);
	vec2 ca = duv * chromatic_aberration;
	vec3 c;
	if (radial_blur_intensity > 0.001) {
		c = vec3(0.0);
		for (int i = 0; i < BLUR_SAMPLES; i++) {
			float s = 1.0 - radial_blur_intensity * BLUR_REACH * float(i) / float(BLUR_SAMPLES - 1);
			c += sample_rgb(vec2(0.5) + duv * s, ca * s);
		}
		c /= float(BLUR_SAMPLES);
	} else {
		c = sample_rgb(uv, ca);
	}
	vec3 lin = to_linear(c);
	float luma = dot(lin, vec3(0.2126, 0.7152, 0.0722));
	lin = mix(vec3(luma), lin, saturation);
	lin = mix(lin, canine(lin), canine_vision_weight);
	float bright = smoothstep(0.55, 1.0, dot(lin, vec3(0.2126, 0.7152, 0.0722)));
	vec3 tint = to_linear(bloom_tint);
	lin = mix(lin, lin * tint + tint * 0.15, clamp(bright * bloom_boost, 0.0, 1.0));
	float dist = sqrt(r2 / corner2);
	float inner = mix(0.85, 0.2, vignette_amount);
	lin *= 1.0 - vignette_amount * smoothstep(inner, 1.05, dist);
	vec3 s = to_srgb(lin);
	float n = fract(sin(dot(FRAGCOORD.xy + fract(TIME * 7.31) * 113.0, vec2(12.9898, 78.233))) * 43758.5453);
	s += (n - 0.5) * film_grain_intensity;
	s = mix(s, vec3(0.45), contrast_dip);
	s = mix(s, vec3(1.0), flash_white);
	s *= 1.0 - fade_black;
	COLOR = vec4(clamp(s, 0.0, 1.0), 1.0);
}
