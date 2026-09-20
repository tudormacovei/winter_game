shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded, particle_trails;

// Ribbon shader for particle trails
// We use this shader to turn the ribbon mesh around it's length so it faces towards the camera, and to fadeout the ribbon alpha on age

uniform float edge_softness : hint_range(0.0, 1.0) = 0.5;
uniform float fade_in_end : hint_range(0.0, 1.0) = 0.1; // age at which the ribbon reaches full alpha
uniform float fade_out_start : hint_range(0.0, 1.0) = 0.6;
uniform float unfold_age : hint_range(0.01, 1.0) = 0.1; // trail_lifetime / lifetime of the particle node: the age at which the whole ribbon has left the spawn point

varying float age; // 0.0 at spawn, 1.0 at death

void vertex() {
	age = INSTANCE_CUSTOM.y;

	vec3 camera_backward = INV_VIEW_MATRIX[2].xyz;
	vec3 camera_backward_flat = vec3(camera_backward.x, 0.0, camera_backward.z);
	vec3 world_up = vec3(0.0, 1.0, 0.0);
	vec3 ribbon_width_axis = normalize(cross(world_up, camera_backward_flat));

	float distance_along_ribbon = VERTEX.y;
	float distance_from_center_line = VERTEX.x;

	float unfolded_fraction = clamp(age / unfold_age, 0.0, 1.0);
	float unfolded_width = 1.0 - smoothstep(unfolded_fraction - 0.1, unfolded_fraction, UV.y);
	float particle_scale = length(MODEL_MATRIX[0].xyz);

	vec3 center_line_point_on_path = (MODEL_MATRIX * vec4(0.0, distance_along_ribbon, 0.0, 1.0)).xyz;
	vec3 world_position = center_line_point_on_path + ribbon_width_axis * distance_from_center_line * unfolded_width * particle_scale;

	VERTEX = world_position;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX);
}

void fragment() {
	float distance_from_center_line = abs(UV.x * 2.0 - 1.0);
	float edge_alpha = smoothstep(0.0, max(edge_softness, 0.001), 1.0 - distance_from_center_line);

	float fade_in_progress = smoothstep(0.0, max(fade_in_end, 0.001), age);
	float fade_out_progress = smoothstep(min(fade_out_start, 0.999), 1.0, age);
	float life_alpha = fade_in_progress * (1.0 - fade_out_progress);

	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * edge_alpha * life_alpha;
}
