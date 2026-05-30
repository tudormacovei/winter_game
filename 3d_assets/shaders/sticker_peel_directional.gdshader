shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform vec2 wave_direction = vec2(0.0, 1.0);
uniform float wave_frequency : hint_range(0.1, 30.0) = 8.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;

// Longitudinal effect (length-wise for the wave)
uniform float wave_decay : hint_range(0.0, 12.0) = 4.0; // higher value = sharper leading crest with a faster-decaying tail.

// Transversal effect: defines the shape of the wave leading line
// stack two sines for visual interest
uniform float bend_freq_large : hint_range(0.0, 30.0) = 1.5; // how many sine waves that fit across the wave crest
uniform float bend_amp_large : hint_range(0.0, TAU) = 1.2; // amplitude in radians of wave phase. 0 = straight crest; TAU = one full wavelength of offset (crest doubles back on itself, more does not make sense).
uniform float bend_freq_small : hint_range(0.0, 30.0) = 6.0; // how many sine waves that fit across the wave crest
uniform float bend_amp_small : hint_range(0.0, TAU) = 0.4; // same radians-of-phase units as bend_amp_large.

// Output thresholds (operate on a [-1, 1] wave value):
// values above wave_max_threshold clamp to the texture's max brightness (1.0).
// values below wave_min_threshold clamp to wave_min_multiplier.
uniform float wave_max_threshold : hint_range(-1.0, 1.0) = 0.8;
uniform float wave_min_threshold : hint_range(-1.0, 1.0) = -0.8;
uniform float wave_min_multiplier : hint_range(0.0, 1.0) = 0.3;

// "Black hole" effect: pull the texture sample along the wave direction proportional to wave intensity,
// so near the crest the texture appears stretched/sucked toward the wave front.
uniform float texture_pull : hint_range(-0.2, 0.2) = 0.03;

void fragment() {
	// Wave-aligned UV basis: dir is the direction of travel, perp is along the crest.
	vec2 dir = length(wave_direction) > 0.0001 ? normalize(wave_direction) : vec2(0.0, 1.0);
	vec2 perp = vec2(-dir.y, dir.x);

	// Transverse bend: sum of a low-frequency and a higher-frequency sine, giving a smooth wavy crest.
	float transverse = dot(UV - vec2(0.5), perp);
	float bend = sin(transverse * bend_freq_large * TAU) * bend_amp_large
			   + sin(transverse * bend_freq_small * TAU) * bend_amp_small;

	// Longitudinal phase, warped by the transverse bend so the crest curves along the wave front.
	float phase = dot(UV - vec2(0.5), dir) * wave_frequency - TIME * wave_speed;
	float warped = phase + bend;

	// fract restarts the cycle every TAU, exp gives a sharp peak at the cycle start with an exponential trailing tail.
	float cycle = fract(warped / TAU);
	float wave_raw = exp(-wave_decay * cycle);
	float wave_signed = wave_raw * 2.0 - 1.0;

	float s = clamp(wave_signed, wave_min_threshold, wave_max_threshold);
	float band = max(wave_max_threshold - wave_min_threshold, 0.0001);
	float t = (s - wave_min_threshold) / band;

	// correction: brigthness is complement of wave intensity
	float brightness = 1.0 - mix(wave_min_multiplier, 1.0, t);

	// Sample the texture at a UV pulled along the wave direction by the wave's intensity.
	vec2 sample_uv = UV + dir * wave_signed * texture_pull;
	vec4 tex = texture(albedo_texture, sample_uv);

	ALBEDO = tex.rgb * brightness;
	EMISSION = tex.rgb * brightness;
	ROUGHNESS = roughness;
	// Drop alpha when the wave darkens the sticker, but never amplify it above the texture's own alpha.
	ALPHA = tex.a * min(brightness, 1.0);
}
