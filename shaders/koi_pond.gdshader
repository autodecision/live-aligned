shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float pond_time = 0.0;
varying vec3 world_pos;
void vertex() {
 world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y += .005*sin(world_pos.x*2.5+pond_time*.9)*cos(world_pos.z*2.0-pond_time*.7);
}
void fragment() {
 vec2 p = world_pos.xz;
 float a = p.x*3.8+p.y*2.9+pond_time*.75;
 float b = p.x*2.2-p.y*4.1-pond_time*.58;
 vec3 ripple_normal = normalize(vec3(.018*cos(a)+.012*cos(b),1.0,.014*cos(a)-.017*cos(b)));
 NORMAL = normalize((VIEW_MATRIX*vec4(ripple_normal,0.0)).xyz);
 float fresnel = pow(1.0-max(dot(NORMAL,VIEW),0.0),3.0);
 ALBEDO = mix(vec3(.11,.31,.28),vec3(.43,.65,.62),fresnel);
 ALPHA = mix(.15,.48,fresnel);
 ROUGHNESS = .17;
 SPECULAR = .68;
}
