shader_type canvas_item;

// All lengths/widths are fractions of the image height, watch out for spooky nonsquare textures
group_uniforms Wipe;
uniform float wipe_angle : hint_range(0.0, 360.0, 1.0) = 0.0; // degrees clockwise
uniform float transition_thickness : hint_range(0.0, 1.0) = 0.1;

group_uniforms Noise;
uniform sampler2D noise_texture : filter_linear;
uniform float noise_strength : hint_range(0.0, 1.0) = 1.0;

group_uniforms ColorBands;
// bright band is at the edge of fade, then middle, then dark, then the sprite becomes visible
uniform vec4 bright_band_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float bright_band_width : hint_range(0.0, 0.5) = 0.08;
uniform vec4 middle_band_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float middle_band_width : hint_range(0.0, 0.5) = 0.06;
uniform vec4 dark_band_color : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform float dark_band_width : hint_range(0.0, 0.5) = 0.06;
uniform float band_blend_width : hint_range(0.0, 0.2) = 0.02;

group_uniforms CodeDrivenValues;

uniform float visibility_start : hint_range(0.0, 1.0) = 0.0;
uniform float visibility_end : hint_range(0.0, 1.0) = 1.0;

uniform float sprite_switch_progress : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D previous_texture : filter_linear, hint_default_transparent;

const float EPSILON = 0.0001;

const float SWITCH_NOISE_STRENGTH = 0.15;

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

vec2 get_wipe_direction() {
	float angle_radians = radians(wipe_angle);
	return vec2(sin(angle_radians), -cos(angle_radians)); // UV.y grows downward
}

// How far behind an edge the soft edge and the color bands still change the sprite
float get_trail_length() {
	float all_bands_width = bright_band_width + middle_band_width + dark_band_width;
	return max(transition_thickness, all_bands_width + band_blend_width * 0.5);
}

// 0.0 before the band starts, 1.0 after
float get_band_blend(float band_start, float distance_from_edge) {
	float half_blend_width = max(band_blend_width, EPSILON) * 0.5;
	return smoothstep(band_start - half_blend_width, band_start + half_blend_width, distance_from_edge);
}

vec3 apply_color_bands(vec3 sprite_rgb, float distance_from_edge) {
	float middle_band_start = bright_band_width;
	float dark_band_start = middle_band_start + middle_band_width;
	float sprite_start = dark_band_start + dark_band_width;

	vec3 banded_rgb = mix(bright_band_color.rgb, middle_band_color.rgb, get_band_blend(middle_band_start, distance_from_edge));
	banded_rgb = mix(banded_rgb, dark_band_color.rgb, get_band_blend(dark_band_start, distance_from_edge));
	return mix(banded_rgb, sprite_rgb, get_band_blend(sprite_start, distance_from_edge));
}

// Adds the wipe effect to the given pixel color, given its distance from the wipe edge (positive = the side where the sprite shows)
// - distance <= 0: returns transparent
// - transition_thickness >= distance >= 0: returned color gets the color bands (supposed to look like a burn)
// - distance >= distance: returns unmodified original sprite color
vec4 apply_wipe_edge(vec4 sprite_color, float distance_from_edge) {
	vec3 banded_rgb = apply_color_bands(sprite_color.rgb, distance_from_edge);
	float edge_alpha = smoothstep(0.0, max(transition_thickness, EPSILON), distance_from_edge);
	return vec4(banded_rgb, sprite_color.a * edge_alpha);
}

float get_reveal_edge_position(float progress, float sweep_length) {
	return mix(0.0, sweep_length + noise_strength + get_trail_length(), progress);
}

float get_wipe_out_edge_position(float progress, float sweep_length) {
	return mix(-get_trail_length(), sweep_length + noise_strength, progress);
}

// The burn-in edge sits edge_separation further out from the midline
float get_burn_out_edge_position(float progress, float sweep_length, float edge_separation) {
	float trail_length = get_trail_length();
	float start_position = -max(trail_length, edge_separation);
	float end_position = sweep_length * 0.5 + SWITCH_NOISE_STRENGTH + max(0.0, trail_length - edge_separation); // the doors travel half the sweep length
	return mix(start_position, end_position, progress);
}

vec4 blend_over(vec4 top_color, vec4 bottom_color) {
	float alpha = top_color.a + bottom_color.a * (1.0 - top_color.a);
	float top_share = top_color.a / max(alpha, EPSILON);
	return vec4(mix(bottom_color.rgb, top_color.rgb, top_share), alpha);
}

void fragment() {
	vec4 current_sprite_color = COLOR;

	vec2 image_size = vec2(TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x, 1.0); // width and height, normalized to image height
	vec2 wipe_direction = get_wipe_direction();
	float sweep_length = dot(abs(wipe_direction), image_size); // from the corner the wipe starts at to the opposite one

	float offset_from_midline = dot((UV - 0.5) * image_size, wipe_direction); // value from -sweep_length / 2 to +sweep_length / 2
	float noise_value = texture(noise_texture, UV).r; // 0.0 to 1.0

	bool is_switching_sprite = sprite_switch_progress < 1.0;
	if (is_switching_sprite) {
		// idea for the sprite switch is that it looks like elevator doors opening to reveal the other sprite underneath
		vec4 previous_sprite_color = texture(previous_texture, UV) * modulate_color;
		float noisy_distance_from_midline = abs(offset_from_midline) + noise_value * SWITCH_NOISE_STRENGTH;
		float edge_separation = 2.0 * transition_thickness; // the two soft edges just touch, so the sprite is never see-through
		float burn_out_edge = get_burn_out_edge_position(sprite_switch_progress, sweep_length, edge_separation);
		float burn_in_edge = burn_out_edge + edge_separation;
		
		vec4 previous_layer = apply_wipe_edge(previous_sprite_color, noisy_distance_from_midline - burn_out_edge);
		vec4 current_layer = apply_wipe_edge(current_sprite_color, burn_in_edge - noisy_distance_from_midline);
		COLOR = blend_over(current_layer, previous_layer);
	} else {
		// normal fadein/fadeout branch

		// Use the noise to shift where the gradient we compute is calculated (so we use the noise to shift the position and that is how we get the noisy look)
		float sweep_position = offset_from_midline + sweep_length * 0.5 + noise_value * noise_strength; // this is 0.0 where the wipe starts
		float visibility_start_edge = get_wipe_out_edge_position(visibility_start, sweep_length);
		float visibility_end_edge = get_reveal_edge_position(visibility_end, sweep_length);
		float distance_from_visibility_edge = min(sweep_position - visibility_start_edge, visibility_end_edge - sweep_position);
		
		COLOR = apply_wipe_edge(current_sprite_color, distance_from_visibility_edge);
	}
}
