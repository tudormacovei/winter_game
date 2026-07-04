shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D texture : source_color, filter_linear;

// 0.0 and 1.0 - midnight
// 0.25 and 0.75 - dawn and dusk
// 0.5 - noon
global uniform float time_of_day;

uniform vec3 color_noon   : source_color = vec3(1.00, 0.98, 0.92);
uniform vec3 color_sunset : source_color = vec3(0.95, 0.60, 0.30);
uniform vec3 color_night  : source_color = vec3(0.10, 0.12, 0.25);

uniform float night_brightness  : hint_range(0.0, 1.0) = 0.25;

void fragment() {
    vec4 tex = texture(texture, UV);

    float daylight  = sin(time_of_day * PI);            // 0.0 at midnight, 1.0 at noon
    float sunset = abs(sin(time_of_day * PI * 2.0));    // 0.0 at noon, 1.0 at dawn and dusk
    sunset = pow(sunset, 0.5);                          // Spreads the peak so it lasts a bit longer

    float brightness = mix(night_brightness, 1.0, daylight);

    vec3 tint = mix(color_night, color_noon, daylight);
    tint = mix(tint, color_sunset, sunset * (1.0 - daylight));

    ALBEDO = clamp(tex.rgb * tint * brightness, 0.0, 1.0);
    ALPHA  = tex.a;
}