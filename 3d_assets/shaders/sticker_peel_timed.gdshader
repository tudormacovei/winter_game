shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

// 0.0 = fresh, 1.0 = expired. Driven by GDScript each frame.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D sweep_gradient : source_color, filter_linear; // IS TREATED AS MONOCHROME

void fragment() {
	vec4 tex = texture(albedo_texture, UV);

	// Angle around the UV center, normalized to [0, 1], clockwise from 12 o'clock.
	vec2 center_offset = UV - vec2(0.5);
	float angle_clockwise_from_top = fract(atan(center_offset.x, -center_offset.y) / TAU + 1.0);

	float sweep_param = clamp(angle_clockwise_from_top - progress, 0.0, 1.0);
	vec4 overlay = texture(sweep_gradient, vec2(sweep_param, 0.5));
	vec3 final_rgb = tex.rgb * overlay.r; // treat given gradient as monochrome

	ALBEDO = final_rgb;
	EMISSION = final_rgb;
	ROUGHNESS = roughness;
	ALPHA = tex.a;
}
