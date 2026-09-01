shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha;

// Crosshatch fill shader: stamps small rectangles of parallel lines ***over*** the sprite
// Uses texture bombing: the texture is divided into a grid of cells, every every fragment tests the stamps of its own cell and its 8 neighbours (because stamps can overlap neighbours)

uniform sampler2D texture_albedo : source_color, filter_linear;

// The crosshatch spwn area: stamps spawn if their origin is between the two reveal lines
uniform float reveal_bottom_percentage : hint_range(0.0, 100.0) = 0.0;
uniform float reveal_top_percentage : hint_range(0.0, 100.0) = 0.0;
// We have a soft transition zone from 0% stamp draw chance to 100% stamp draw chance at both the top and bottom reveal lines
// Unit is fraction of texture height
uniform float reveal_softness_percentage : hint_range(0.0, 100.0) = 25.0;

// Chance in percent that a candidate stamp spawns, this is the MAX that is used by the reveal lines
uniform float spawn_chance_percentage : hint_range(0.0, 100.0) = 100.0;

uniform float edge_margin_percentage : hint_range(0.0, 25.0) = 5.0; // 5% of width/height

// Visibility of the sprite texture itself
// This is independent from the crosshatch
uniform float sprite_visibility : hint_range(0.0, 1.0) = 1.0;

// Stamp look vars
uniform vec4 stamp_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int line_count : hint_range(1, 32) = 6;
uniform float line_thickness_pixels : hint_range(0.5, 32.0) = 2.0;

// Stamp placement. Sizes are in texture pixels.
uniform float cell_size_pixels : hint_range(4.0, 256.0) = 48.0;
// Stamp width and length as fractions of the cell size
// Capped so that a stamp never reaches past the 3x3 cell neighbourhood that we test against
uniform float stamp_width_ratio : hint_range(0.0, 2.0) = 1.0;
uniform float stamp_length_ratio : hint_range(0.0, 2.0) = 1.0;
uniform int stamps_per_cell : hint_range(1, 16) = 1;
uniform float rotation_range_degrees : hint_range(0.0, 180.0) = 30.0; // max deviation from vertical

// funky animation by simply chaning the seed
uniform float seed_change_interval_seconds : hint_range(0.01, 5.0) = 0.1;

const float HASH_SCALE = 43758.5453; // shared by all sine hashes
const float ANGLE_HASH_OFFSET = 31.0; // decorrelates the angle hash from the spawn hash
const float STAMP_ORIGIN_OPACITY_THRESHOLD = 0.5; // minimum sprite alpha under a stamp origin
const float EPSILON = 0.0001;

// Values that are the same for every candidate stamp of a fragment
struct StampConfig {
    float half_width;
    float half_length;
    float line_period;
    float half_line_thickness;
    float spawn_chance;
    float bottom_line;
    float top_line;
    float softness;
    float edge_margin;
};

// pseudo-random values in 0..1 for a given input (industry-standard function apparently)
float random_1d(float value) {
    return fract(sin(value) * HASH_SCALE);
}

// pseudo-random values in 3d space, outputs in 3D unit cube (again industry-standard function apparently)
vec3 random_3d(vec3 position) {
    return fract(sin(vec3(
        dot(position, vec3(127.1, 311.7, 74.7)),
        dot(position, vec3(269.5, 183.3, 246.1)),
        dot(position, vec3(113.5, 271.9, 124.6))
    )) * HASH_SCALE);
}

// rgb = sprite color at the stamp origin, a = coverage (is the stamp visible in the current pixel the fragment shader is processing?)
vec4 sample_candidate_stamp(vec2 fragment_pixel, vec2 cell, float candidate, vec2 texture_size, float smoothing, float seed, StampConfig config) {
    // yz is the origin point of the stamp inside the cell, x is the roll
    vec3 random_spawn = random_3d(vec3(cell, candidate) + seed);

    vec2 stamp_origin_pixel = (cell + random_spawn.yz) * cell_size_pixels;
    vec2 stamp_origin_uv = stamp_origin_pixel / texture_size;
    float stamp_origin_height_from_bottom = 1.0 - stamp_origin_uv.y;

    // for some reason there are some visual errors at the margins so exclude margins from spawning
    if (stamp_origin_uv.x < config.edge_margin || stamp_origin_uv.x > 1.0 - config.edge_margin
            || stamp_origin_uv.y < config.edge_margin || stamp_origin_uv.y > 1.0 - config.edge_margin) {
        return vec4(0.0);
    }

    float reveal_factor = (1.0 - smoothstep(config.top_line - config.softness, config.top_line, stamp_origin_height_from_bottom))
            * smoothstep(config.bottom_line, config.bottom_line + config.softness, stamp_origin_height_from_bottom);
    if (random_spawn.x >= config.spawn_chance * reveal_factor) {
        return vec4(0.0);
    }

    // use textureLod to force mipmap level 0
    vec4 stamp_origin_sample = textureLod(texture_albedo, stamp_origin_uv, 0.0);
    if (stamp_origin_sample.a <= STAMP_ORIGIN_OPACITY_THRESHOLD) {
        return vec4(0.0);
    }

    // Move the fragment coords into the stamp coordinate space: stamp origin at (0,0), rotation removed.
    // In this coordinate space the stamp is a texture of vertical lines.
    float random_angle = random_3d(vec3(cell, candidate) + seed + ANGLE_HASH_OFFSET).x;
    float angle = (random_angle * 2.0 - 1.0) * radians(rotation_range_degrees);
    vec2 local = fragment_pixel - stamp_origin_pixel;
    local = vec2(
        cos(angle) * local.x + sin(angle) * local.y,
        -sin(angle) * local.x + cos(angle) * local.y
    );

    // bounds for the texture we apply, otherwise it would stretch indefinitely acorss the texture 
    float rectangle_mask = smoothstep(0.0, smoothing, config.half_width - abs(local.x))
            * smoothstep(0.0, smoothing, config.half_length - abs(local.y));

    // Distance from the nearest of the line_count evenly spaced line centres
    float distance_across = local.x + config.half_width;
    float distance_to_line_center = abs(fract(distance_across / config.line_period) - 0.5) * config.line_period;
    float line_mask = 1.0 - smoothstep(config.half_line_thickness - smoothing, config.half_line_thickness + smoothing, distance_to_line_center);

    return vec4(stamp_origin_sample.rgb, rectangle_mask * line_mask);
}

void fragment() {
    vec4 sprite = texture(texture_albedo, UV);
    vec2 texture_size = vec2(textureSize(texture_albedo, 0));
    vec2 fragment_pixel = UV * texture_size;

    // anti-alias width
    float smoothing = max(fwidth(fragment_pixel.x), EPSILON); // how many texture pixels one screen pixel covers

    // randomize seed (randomize the random select :) ) evey interval_seconds for animation
    float seed = random_1d(floor(TIME / seed_change_interval_seconds));

    float stamp_width = stamp_width_ratio * cell_size_pixels;
    // Cap the length so at most half of the stamp diagonal pokes out of the spawning cell (so a 3x3 grid search is sufficient)
    float stamp_length = min(stamp_length_ratio * cell_size_pixels,
            sqrt(max(4.0 * cell_size_pixels * cell_size_pixels - stamp_width * stamp_width, 0.0)));

    StampConfig config;
    config.half_width = stamp_width * 0.5;
    config.half_length = stamp_length * 0.5;
    config.line_period = stamp_width / float(line_count);
    config.half_line_thickness = line_thickness_pixels * 0.5;
    config.spawn_chance = spawn_chance_percentage / 100.0;
    config.softness = max(reveal_softness_percentage / 100.0, EPSILON);
    
    config.top_line = mix(0.0, 1.0 + config.softness, reveal_top_percentage / 100.0); // go by 'softness' above to ensure we hit 100% reveal at top
    config.bottom_line = mix(-config.softness, 1.0, reveal_bottom_percentage / 100.0); // // go by 'softness' below to ensure we hit 0% reveal at bottom
    config.edge_margin = edge_margin_percentage / 100.0;

    vec3 crosshatch_color = vec3(0.0); // premultiplied by coverage
    float coverage = 0.0;
    if (stamp_width >= 1.0 && stamp_length >= 1.0) { // below one pixel nothing is visible
        vec2 home_cell = floor(fragment_pixel / cell_size_pixels);
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                vec2 cell = home_cell + vec2(float(dx), float(dy));
                for (int candidate = 0; candidate < stamps_per_cell; candidate++) {
                    vec4 stamp = sample_candidate_stamp(fragment_pixel, cell, float(candidate), texture_size, smoothing, seed, config);
                    float stamp_alpha = stamp.a * stamp_color.a;
                    // The new stamp slides under the layers that are already accumulated
                    crosshatch_color += (1.0 - coverage) * stamp_alpha * stamp.rgb * stamp_color.rgb;
                    coverage += (1.0 - coverage) * stamp_alpha;
                }
            }
        }
    }

    // Composite the crosshatch layer over the sprite layer
    float sprite_alpha = sprite.a * sprite_visibility;
    float combined_alpha = coverage + sprite_alpha * (1.0 - coverage);
    vec3 combined_color = crosshatch_color + sprite.rgb * COLOR.rgb * sprite_alpha * (1.0 - coverage);
    ALBEDO = combined_color / max(combined_alpha, EPSILON);
    ALPHA = combined_alpha * COLOR.a;
}
