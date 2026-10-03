shader_type spatial;
render_mode unshaded, blend_mix;

uniform float radius : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float falloff_start : hint_range(0.0, 1.0, 0.01) = 0.0; // fraction of the radius
uniform float falloff_strength : hint_range(0.5, 10.0, 0.1) = 4.0;

void vertex() {
	float particle_scale = length(MODEL_MATRIX[0].xyz);
	mat4 billboard_matrix = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard_matrix;
	VERTEX *= particle_scale;
}

void fragment() {
	float distance_from_center = length(UV - vec2(0.5)) * 2.0; // 0.0 at the center, 1.0 at UV edge

	float falloff_start_distance = radius * falloff_start;
	float falloff_width = max(radius - falloff_start_distance, fwidth(distance_from_center));
	float falloff_progress = clamp((distance_from_center - falloff_start_distance) / falloff_width, 0.0, 1.0);

	float edge_value = exp(-falloff_strength);
	float disc_alpha = (exp(-falloff_strength * falloff_progress) - edge_value) / (1.0 - edge_value);

	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * disc_alpha;
}
