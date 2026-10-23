shader_type spatial;
render_mode diffuse_burley;
uniform float water_time = 0.0;
uniform float fold_amplitude = 1.0;
varying vec2 stream_uv;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() {
 // glTF flips Blender V: recover t=0 at the sill and t=1 at the sea.
 stream_uv=vec2(UV.x,1.0-UV.y);
 float envelope=smoothstep(0.0,.12,stream_uv.y);
 float fold=sin(stream_uv.y*42.0-water_time*9.0+UV.x*18.0)*.016;
 fold+=sin(stream_uv.y*71.0-water_time*14.0-UV.x*31.0)*.009;
 VERTEX+=NORMAL*fold*envelope*fold_amplitude;
}
void fragment() {
 vec2 q=vec2(stream_uv.x*25.0,stream_uv.y*7.0-water_time*1.7);
 float fine=noise2(q*vec2(1.0,2.4));
 float stream=noise2(q*vec2(.42,.7));
 float foam=smoothstep(.69,.89,fine*.65+stream*.35);
 // Thin intermittent strands leave a darker reflective body with shaded sides.
 ALBEDO=mix(mix(vec3(.025,.22,.26),vec3(.09,.39,.43),stream),vec3(.64,.82,.80),foam*.72);
 ROUGHNESS=mix(.16,.32,foam);
 METALLIC=.06;
 SPECULAR=.65;
 NORMAL=normalize(NORMAL+vec3(sin(q.x*3.0+q.y)*.075,cos(q.y*4.0-q.x)*.05,0.0));
}
