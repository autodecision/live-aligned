shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, cull_disabled;

uniform float dot_size = 5.0;
uniform float daylight = 1.0;

void vertex() {
    POINT_SIZE = dot_size;
    if (COLOR.a < 0.8) {
        vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        VERTEX.y += 0.08 * sin(world.x * 0.23 + TIME * 0.8) * cos(world.z * 0.18 + TIME * 0.65);
    }
}

void fragment() {
    if (length(POINT_COORD - vec2(0.5)) > 0.48) {
        discard;
    }
    ALBEDO = COLOR.rgb * mix(vec3(0.24, 0.31, 0.46), vec3(1.0), daylight);
}
