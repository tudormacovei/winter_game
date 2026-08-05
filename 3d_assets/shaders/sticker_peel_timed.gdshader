shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;

// 0.0 = fresh, 1.0 = expired. Driven by GDScript each frame.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D sweep_gradient : source_color, filter_linear, repeat_disable; // multiplicative color filter: white = normal, colors will add a tint

// hint_default_transparent: an unassigned gradient means no glow
// repeat_disable: sampling near 1.0 must not wrap around!
uniform sampler2D edge_glow_gradient : source_color, hint_default_transparent, filter_linear, repeat_disable;
uniform float edge_glow_max_intensity : hint_range(0.0, 3.0) = 1.0;

// the cycle of the pulse is within values [0, 1) of this input
uniform float pulse_phase = 0.0;

// 1.0 once the sticker has expired: kills the edge glow entirely
uniform float failed : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);

	// Angle around the UV center, normalized to [0, 1], clockwise from 12 o'clock.
	vec2 center_offset = UV - vec2(0.5);
	float angle_clockwise_from_top = fract(atan(center_offset.x, -center_offset.y) / TAU + 1.0);

	float sweep_param = clamp(angle_clockwise_from_top - progress, 0.0, 1.0);
	vec4 overlay = texture(sweep_gradient, vec2(sweep_param, 0.5));
	vec3 final_rgb = tex.rgb * overlay.rgb;

	// Wrapped angular distance from the sweep edge: 0 at the edge, 1 at the far side of the circle.
	float edge_diff = angle_clockwise_from_top - progress;
	edge_diff -= round(edge_diff);
	float edge_distance = abs(edge_diff) * 2.0;

	vec4 edge_overlay = texture(edge_glow_gradient, vec2(edge_distance, 0.5));
	float pulse = 0.5 + 0.5 * sin(pulse_phase * TAU);
	float glow_intensity = mix(0.5, edge_glow_max_intensity, progress) * (1.0 - failed);
	// mask glow by sweep luminance: keeps the glow dimmed in the darkened wedge even with colored gradients
	vec3 edge_overlay_rgb = edge_overlay.rgb * edge_overlay.a * pulse * glow_intensity;
	final_rgb += edge_overlay_rgb;

	ALBEDO = final_rgb;
	EMISSION = final_rgb;
	ROUGHNESS = 0.0;
	ALPHA = tex.a;
}
