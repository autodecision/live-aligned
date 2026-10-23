shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.37, 0.47, 0.43);
uniform vec3 light_dot : source_color = vec3(0.76, 0.79, 0.64);
uniform vec3 dark_dot : source_color = vec3(0.22, 0.44, 0.45);
uniform vec3 daylight_tint : source_color = vec3(1.0);
uniform vec3 dry_base_color : source_color = vec3(0.23, 0.32, 0.21);
uniform float waterline_y = 1000000.0;
uniform float dots_per_meter = 6.0;

varying vec3 world_point;
varying vec3 world_normal;

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    if (world_point.y >= waterline_y) {
        ALBEDO = dry_base_color * daylight_tint;
    } else {
    vec3 n = abs(normalize(world_normal));
    vec2 surface = n.y >= n.x && n.y >= n.z ? world_point.xz
        : n.x >= n.z ? world_point.zy : world_point.xy;
    vec2 grid = surface * dots_per_meter;
    vec2 cell = floor(grid);
    vec2 center = vec2(hash12(cell), hash12(cell + vec2(17.0, 43.0)));
    center = mix(vec2(0.5), center, 0.70);
    float radius = mix(0.24, 0.38, hash12(cell + vec2(29.0, 7.0)));
    float distance_to_dot = length(fract(grid) - center);
    float edge = max(fwidth(distance_to_dot), 0.012);
    float circle = 1.0 - smoothstep(radius - edge, radius + edge, distance_to_dot);
    vec3 pigment = mix(dark_dot, light_dot, hash12(cell + vec2(61.0, 13.0)));
    ALBEDO = mix(base_color, pigment, circle) * daylight_tint;
    }
}
