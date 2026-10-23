shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D wave_pattern : repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.82;
uniform vec2 phase_rotation = vec2(1.0, 0.0);

void fragment() {
    vec2 p = (SCREEN_UV - vec2(0.5)) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
    float radius = length(p);

    // The packed pattern stores sin/cos phase and the baked zigzag folds.
    vec4 pattern = texture(wave_pattern, clamp(p * 0.5 + vec2(0.5),
        vec2(0.0), vec2(1.0)));
    float ripple = dot(pattern.rg * 2.0 - vec2(1.0), phase_rotation);
    float etching = pattern.b * 2.0 - 1.0;

    float ribbon = smoothstep(-0.15, 0.84, ripple);
    float bright_edge = pow(max(ripple, 0.0), 9.0);
    float fine_line = pow(max(etching, 0.0), 8.0);
    float dark_edge = smoothstep(0.15, 0.90, -ripple);

    // Blending the moving ink and light creates an optical wave without a
    // costly full-screen scene copy or a second sample of every world pixel.
    vec3 cobalt = vec3(0.014, 0.035, 0.72);
    vec3 violet = vec3(0.46, 0.49, 1.0);
    vec3 pigment = mix(vec3(0.003, 0.005, 0.035),
        mix(cobalt, violet, bright_edge * (0.28 + 0.72 * fine_line)),
        clamp(ribbon * 0.78 + bright_edge * 0.35, 0.0, 1.0));
    float opacity = strength * (0.12 * dark_edge + 0.17 * ribbon
        + 0.32 * bright_edge + 0.06 * fine_line * bright_edge);
    opacity *= 1.0 - 0.10 * smoothstep(0.28, 0.95, radius);
    COLOR = vec4(pigment, opacity);
}
