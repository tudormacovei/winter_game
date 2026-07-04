shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D texture_sampler : source_color, filter_linear, repeat_disable;

// 0.0 and 1.0 - midnight
// 0.25 and 0.75 - dawn and dusk
// 0.5 - noon
global uniform float time_of_day;

uniform int shadow_type : hint_enum("Global", "Highlight") = 0;

group_uniforms global_shadow;
global uniform float shadow_global_min_alpha;
global uniform float shadow_global_max_alpha;

group_uniforms object_shadow;
global uniform float shadow_highlight_min_alpha;
global uniform float shadow_highlight_max_alpha;
group_uniforms;

void fragment() {
	float tex_alpha = texture(texture_sampler, UV).a;

	// 1.0 at midnight, 0.0 at noon
	float midnight_factor = (cos(TAU * time_of_day) + 1.0) * 0.5;
	float alpha_scale;
	if (shadow_type == 0) // Global 
		alpha_scale = mix(shadow_global_min_alpha, shadow_global_max_alpha, midnight_factor);
	else // Object 
		alpha_scale = mix(shadow_highlight_min_alpha, shadow_highlight_max_alpha, 1.0 - midnight_factor);

	ALBEDO = vec3(0.0);
	ALPHA = tex_alpha * alpha_scale;
}