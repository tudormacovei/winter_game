shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

// 0.0 and 1.0 - midnight
// 0.25 and 0.75 - dawn and dusk
// 0.5 - noon
global uniform float time_of_day;

uniform vec3 color_noon   : source_color = vec3(0.3, 0.6, 1.00);
uniform vec3 color_sunset : source_color = vec3(0.95, 0.33, 0.13);
uniform vec3 color_night  : source_color = vec3(0.01, 0.01, 0.07);

void fragment() {
    float daylight  = sin(time_of_day * PI);            // 0.0 at midnight, 1.0 at noon
    float sunset = abs(sin(time_of_day * PI * 2.0));    // 0.0 at noon, 1.0 at dawn and dusk
    sunset = pow(sunset, 0.5);                          // Spreads the peak so it lasts a bit longer

    vec3 sky = mix(color_night, color_noon, daylight);
    sky = mix(sky, color_sunset, sunset * (1.0 - daylight));

    ALBEDO = sky;
    ALPHA  = 1.0;
}