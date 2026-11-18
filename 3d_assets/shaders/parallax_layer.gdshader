shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

group_uniforms CodeDrivenValues;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform sampler2D pulse_ring_texture : repeat_enable, filter_linear;
uniform sampler2D pulse_noise_texture : repeat_enable, filter_linear;
uniform float pulse_ring_count;
uniform float pulse_noise_amount;
uniform float pulse_min_multiplier;
uniform float pulse_max_multiplier;
uniform float pulse_cycles; // rings move towards the outside of the screen at a rate of one ring per cycle

// smooth rampup using these 2 vals 
const float PULSE_MASK_START_CHROMA = 0.05;
const float PULSE_MASK_FULL_CHROMA = 0.3;

// not fully x or y aligned direction to make the movement harder to spot
const vec2 NOISE_MOVEMENT_PER_CYCLE = vec2(0.25, 0.1);

void fragment() {
	vec4 layer_color = texture(texture_albedo, UV);
	float chroma = max(layer_color.r, max(layer_color.g, layer_color.b)) - min(layer_color.r, min(layer_color.g, layer_color.b));
	float pulse_mask = smoothstep(PULSE_MASK_START_CHROMA, PULSE_MASK_FULL_CHROMA, chroma);

	vec2 image_size = vec2(textureSize(texture_albedo, 0));
	vec2 position_from_center = (UV - 0.5) * image_size / image_size.y; // in layer heights, so the rings are circles
	float ring_position = length(position_from_center) * pulse_ring_count - pulse_cycles;
	float ring_brightness = texture(pulse_ring_texture, vec2(ring_position, 0.5)).r;
	
	float noise_value = mix(1.0, texture(pulse_noise_texture, position_from_center + NOISE_MOVEMENT_PER_CYCLE * pulse_cycles).r, pulse_noise_amount);
	float pulse_strength = (ring_brightness * 2.0 - 1.0) * noise_value * pulse_mask; // -1 to 1, 0 keeps the opacity as set
	float target_multiplier = pulse_strength < 0.0 ? pulse_min_multiplier : pulse_max_multiplier;

	ALBEDO = layer_color.rgb * COLOR.rgb; // COLOR is where we get the modulate value from
	ALPHA = min(layer_color.a * COLOR.a * mix(1.0, target_multiplier, abs(pulse_strength)), 1.0);
}
