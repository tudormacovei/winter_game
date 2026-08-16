shader_type canvas_item;

group_uniforms Blink;

// 0.0 is fully closed, 1.0 is fully open (fully transparent texture)
uniform float eye_open_amount : hint_range(0.0, 1.0, 0.01) = 1.0;

// Distances between the top/bottom and left/right control points.
// Vertical distance is measured in screen heights, horizontal distance in screen widths (1 = one full width/height)
uniform float vertical_point_distance : hint_range(0.0, 6.0, 0.01) = 3.0;
uniform float horizontal_point_distance : hint_range(0.0, 6.0, 0.01) = 3.0;

// Returns a negative value if we are inside the open eye
float eye_boundary(vec2 point, float half_width, float half_height) {
	vec2 absolute_point = abs(point); // 4-way symmetry so we can just check one quadrant

	float normalized_x = absolute_point.x / half_width;
	// simple quadratic (1-x^2) for eye shape
	float vertical_boundary = half_height * (1.0 - normalized_x * normalized_x);
	return absolute_point.y - vertical_boundary;
}


void fragment() {
	vec4 base_color = COLOR;
	float open_amount = clamp(eye_open_amount, 0.0, 1.0);
	float half_width = horizontal_point_distance * 0.5;
	float half_height = vertical_point_distance * 0.5 * open_amount;

	float closed_alpha = 1.0;
	if (half_width > 0.0001 && half_height > 0.0001) {
		vec2 centered_point = UV - vec2(0.5);

		float signed_distance = eye_boundary(centered_point, half_width, half_height);
		float aperture_alpha = step(signed_distance, 0.0); // outputs 0 or 1
		closed_alpha = 1.0 - aperture_alpha;
	}

	// Preserve the ColorRect/texture RGB and only apply the blink mask to alpha.
	COLOR = vec4(base_color.rgb, base_color.a * closed_alpha);
}
