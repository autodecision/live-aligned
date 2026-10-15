shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D meadow_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 ground_world_position;
varying vec3 ground_world_normal;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float ground_noise(vec2 p) { vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y); }
void vertex() { ground_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; ground_world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
 vec3 p=ground_world_position;
 float large=ground_noise(p.xz*.29);float fine=ground_noise(p.xz*4.5);
 float slope=smoothstep(.34,.90,normalize(ground_world_normal).y);
 float height=smoothstep(-2.2,1.1,p.y);
 float cover=smoothstep(.24,.76,slope*height+(large-.5)*.64+(fine-.5)*.16);
 vec3 meadow=texture(meadow_texture,p.xz*.19).rgb;
 vec3 rock=mix(vec3(.20,.19,.15),vec3(.43,.40,.31),large)*mix(.84,1.12,fine);
 vec3 soil=vec3(.19,.135,.071)*mix(.85,1.12,fine);
 float edge=cover*(1.0-cover)*1.35;
 ALBEDO=mix(mix(rock,meadow,cover),soil,edge);
 ROUGHNESS=.93;
}
