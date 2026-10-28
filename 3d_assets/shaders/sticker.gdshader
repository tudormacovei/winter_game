shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D vein_mask : hint_default_transparent, filter_linear_mipmap;
uniform float roughness = 0.5;
uniform float albedo_brightness = 1.0;

// for all stickers
instance uniform float base_alpha = 0.0;

// for directional stickers
instance uniform bool wave_enabled = false; 
instance uniform vec2 wave_direction = vec2(0.0, 1.0);

// for timed stickers
instance uniform float flash = 0.0;
instance uniform float danger = 0.0;

// All of these values are in UV units
const float wave_spacing = 2.0; // distance between two wave fronts
const float wave_speed = 2.5; // uv units per second
const float wave_fade_in = 0.3;
const float wave_fade_out_distance = 1.5;

const float wave_saturation_boost = 5.0;
const float wave_brightness_boost = 3.0;
const vec3 wave_tint = vec3(0.8, 0.0, 0.0);

const float flash_saturation_boost = 5.0;
const float flash_brightness_boost = 3.0;
const vec3 flash_tint = vec3(0.8, 0.0, 0.0);

const vec3 failed_color = vec3(0.325, 0.0, 0.0);

// wave strength at this uv position, from 0.0 to 1.0
float get_wave_amount(vec2 uv, vec2 direction) {
	// Position along the wave direction
	float pos = dot(uv - vec2(0.5), normalize(direction));
	// Distance behind the nearest wave front
	float dist = mod(TIME * wave_speed - pos, wave_spacing);

	// this value rises from 0.0 to 1.0 during the wave_fade_in portion, then goes to 0.0 in the wave_fade_out portion
	return smoothstep(0.0, wave_fade_in, dist) - smoothstep(wave_fade_in, wave_fade_in + wave_fade_out_distance, dist);
}

// boost amount from 0.0 to 1.0
vec3 boost_color(vec3 rgb, float amount, float saturation_boost, float brightness_boost, vec3 tint) {
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	float saturation_factor = 1.0 + saturation_boost * amount;
	vec3 tint_factor = mix(vec3(1.0), tint, amount);
	float brightness_factor = 1.0 + brightness_boost * amount;

	vec3 saturated_rgb = max(mix(vec3(luma), rgb, saturation_factor), vec3(0.0));
	return saturated_rgb * tint_factor * brightness_factor;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	float vein_amount = texture(vein_mask, UV).a;

	vec3 failed_rgb = tex.rgb * failed_color;
	vec3 danger_rgb = mix(tex.rgb, failed_rgb, danger);
	float danger_alpha = mix(base_alpha, 1.0, danger);

	// for directional stickers
	float wave_amount = wave_enabled ? get_wave_amount(UV, wave_direction) * vein_amount : 0.0;
	vec3 wave_rgb = boost_color(danger_rgb, wave_amount, wave_saturation_boost, wave_brightness_boost, wave_tint);

	// for timed stickers
	float flash_amount = flash * vein_amount;
	vec3 flash_rgb = boost_color(danger_rgb, flash_amount, flash_saturation_boost, flash_brightness_boost, flash_tint);

	// danger_rgb is the new base we apply the effects on so that is why we use that here
	vec3 wave_change = wave_rgb - danger_rgb;
	vec3 flash_change = flash_rgb - danger_rgb;
	vec3 mixed_rgb = max(danger_rgb + wave_change + flash_change, vec3(0.0));
	float total_amount = min(wave_amount + flash_amount, 1.0);
	float mixed_alpha = tex.a * mix(danger_alpha, 1.0, total_amount);

	ALBEDO = mixed_rgb * albedo_brightness;
	EMISSION = mixed_rgb;
	ROUGHNESS = roughness;
	ALPHA = mixed_alpha;
}
