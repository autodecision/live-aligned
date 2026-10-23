shader_type spatial;
render_mode cull_disabled;
uniform float swim_time = 0.0;
instance uniform float fish_phase = 0.0;
instance uniform float fish_motion = 1.0;
void vertex() {
 float tail = 1.0-smoothstep(-.43,.15,VERTEX.x);
 float wave = swim_time*4.7 + VERTEX.x*9.0 + fish_phase;
 VERTEX.z += sin(wave)*(.022+.033*fish_motion)*tail*tail;
 VERTEX.y += sin(wave*.65)*.008*tail;
 NORMAL.z += cos(wave)*.14*tail;
 NORMAL = normalize(NORMAL);
}
void fragment() {
 ALBEDO = COLOR.rgb;
 ROUGHNESS = .44;
 SPECULAR = .32;
}
