shader_type canvas_item;

// health_normalized drives the circle size: 1.0 is full health (large circle), 0.0 means no circle
//
// wave1 and wave2 together shape the circle boundary.
// wave2 warps the angle space that wave1 reads from, which breaks the perfect circular symmetry
// without adding a second visible wave layer on top.
//
// The radial group distorts the UV sample point, creating ripples just outside the circle edge.

uniform float health_normalized : hint_range(0.0, 1.0) = 1.0;

// wave1: primary sinusoidal deformation of the circle boundary
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;
uniform float wave_magnitude : hint_range(0.0, 0.1) = 0.02;        // in normalized height units, resolution-independent
uniform float wave_frequency : hint_range(1.0, 16.0, 1.0) = 4.0;  // whole number: ensures the wave wraps seamlessly around 2*PI

// wave2: pre-distorts the angle before wave1 runs, softly breaking the circular symmetry
uniform float wave2_speed : hint_range(0.0, 10.0) = 1.0;
uniform float wave2_magnitude : hint_range(0.0, 0.1) = 0.02;       // in radians, not distance units
uniform float wave2_frequency : hint_range(1.0, 16.0, 1.0) = 4.0; // same seamlessness rule applies

// radial: UV distortion anchored to the circle edge, creates ripples that travel with the circle
uniform float radial_speed : hint_range(0.0, 10.0) = 1.0;
uniform float radial_magnitude : hint_range(0.0, 0.05) = 0.01;     // in UV units
uniform float radial_frequency : hint_range(1.0, 32.0, 1.0) = 8.0; // whole number for seamless wrap

// blend: tints the opaque parts of the overlay with a gradient between two colors.
// blend_color_inner sits right next to the distorted circle edge.
// blend_color_outer sits at the far edge of the screen (the corner).
// Detection samples the texture at half the radial distortion, so the tinted region
// is less wobbly than the visible texture but still moves with the effect.
uniform vec4 blend_color_inner : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 blend_color_outer : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float blend_alpha_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float blend_gradient_distance : hint_range(0.01, 1.0) = 0.5; // in normalized height units, same scale as the feather

void fragment() {

	// coordinate setup
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE.xy;
	vec2 uv = (FRAGCOORD.xy - 0.5 * resolution) / resolution.y;

	float dist = length(uv);
	float angle = atan(uv.y, uv.x); // polar angle in radians, ranges from -PI to PI


	// CIRCLE MASK
	// base_radius reaches the screen corners at full health, so the overlay is fully hidden when health is 100%.
	// wave2 nudges the angle by a small radian amount before wave1 reads it. Because the nudge
	// itself varies sinusoidally around the circle, wave1 ends up sampling an uneven input and
	// produces a less symmetric shape without adding a visually distinct second wave.
	float distorted_angle = angle + wave2_magnitude * sin(wave2_frequency * angle + TIME * wave2_speed);

	float base_radius = health_normalized * 0.5 * length(vec2(resolution.x / resolution.y, 1.0));
	float radius = base_radius + wave_magnitude * sin(wave_frequency * distorted_angle + TIME * wave_speed);

	// smoothstep over a 5px band gives a soft edge.
	// Outputs 0 inside the circle (transparent) and 1 outside (texture visible).
	float feather = 5.0 / resolution.y;
	float mask = smoothstep(radius - feather, radius + feather, dist);


	// RADIAL UV DISTORTION
	// Shifts the UV we sample the texture at, creating ripples that travel around the circle edge.
	// d is how far outside the circle boundary we are (0 inside or exactly at the edge).

	// Falloff formula: d * K * exp(1 - d * K)
	// This is a bell curve in d. It is 0 at d = 0 (the circle edge), peaks at exactly 1.0
	// when d = 1/K, then decays back toward 0.
	float d = max(0.0, dist - radius);
	float falloff = d * 6.0 * exp(1.0 - d * 6.0);

	// The sample point is nudged along the radial direction (toward or away from center).
	// screen_offset is used for the direction rather than uv because the nudge is in UV space.
	// The guard on screen_dist avoids a divide by 0 at the exact center pixel.
	vec2 screen_offset = SCREEN_UV - vec2(0.5);
	float screen_dist = length(screen_offset);
	vec2 radial_dir = screen_dist > 0.0001 ? screen_offset / screen_dist : vec2(0.0);
	float radial_wave = sin(angle * radial_frequency + TIME * radial_speed);
	vec2 sample_UV = UV + radial_dir * radial_wave * falloff * radial_magnitude;


	// BLEND COLOR DETECTION
	// Sample the texture again at half the radial distortion offset. If that less-distorted
	// sample reads as opaque, the pixel is "inside" the overlay artwork and we tint it.
	//
	// The tint itself is a gradient driven by how far the pixel is from the circle edge.
	// Like the feather, the gradient distance is a fixed normalized-height length and
	// does NOT depend on the circle size, so the band of colors stays consistent as
	// health changes.
	vec2 detect_UV = UV + radial_dir * radial_wave * falloff * radial_magnitude * 0.5;
	float detect_alpha = texture(TEXTURE, detect_UV).a;

	float gradient_t = clamp(d / blend_gradient_distance, 0.0, 1.0);
	vec4 blend_color = mix(blend_color_inner, blend_color_outer, gradient_t);


	// output
	vec4 tex = texture(TEXTURE, sample_UV);
	if (detect_alpha > blend_alpha_threshold) {
		tex.rgb = mix(tex.rgb, blend_color.rgb, blend_color.a);
	}
	COLOR = vec4(tex.rgb, tex.a * mask);
}
