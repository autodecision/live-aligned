shader_type spatial;
render_mode cull_disabled;
uniform bool rock_base=false;
varying vec3 world_point;
varying vec3 world_normal;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 p=world_point.xz;
 float patches=noise(p*.31);
 float grit=noise(p*22.0);
 float ripples=sin(p.x*5.5+sin(p.y*.75)*1.5+noise(p*.5)*3.0)*.5+.5;
 vec3 sand=mix(vec3(.25,.27,.23),vec3(.48,.45,.33),patches);
 sand*=mix(.83,1.08,grit)*mix(.94,1.04,ripples);
 vec3 stone=mix(vec3(.18,.21,.20),vec3(.35,.36,.30),noise(world_point.xy*.8));
 ALBEDO=mix(stone,sand,smoothstep(.25,.85,abs(normalize(world_normal).y)));
 if(rock_base){ALBEDO=mix(ALBEDO,stone*0.85,smoothstep(-9.2,-7.25,world_point.y));}
 ROUGHNESS=.96;
}
