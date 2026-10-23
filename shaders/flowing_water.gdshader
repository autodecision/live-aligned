shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float water_time = 0.0;
uniform int water_kind = 0; // 0 sea, 1 contained surface, 2 falling water
uniform vec3 bounds_min;
uniform vec3 bounds_max;
uniform vec2 current = vec2(0.35,0.15);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) { vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
float swell(vec2 p) {
 return .16*sin(.85*p.x-.36*p.y-1.1*water_time)+.075*sin(-.46*p.x-1.38*p.y-1.58*water_time)+.03*sin(2.6*p.x-.75*p.y-2.3*water_time);
}
float ripples(vec2 p) {
 vec2 q=p-current*water_time;
 return sin(q.x*7.0+q.y*4.2)*.018+sin(q.x*-3.4+q.y*11.0)*.011+noise2(q*9.0)*.016;
}
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 if (water_kind==0) {
  VERTEX.y+=swell(p.xz);
 } else if (water_kind==1) {
  vec2 edge=min(p.xz-bounds_min.xz,bounds_max.xz-p.xz);
  float fade=smoothstep(0.0,.20,min(edge.x,edge.y));
  VERTEX.y+=ripples(p.xz)*fade*.45;
 }
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 vec3 p=world_position;float foam=0.0;
 if(water_kind==2) {
  // Constant phase follows gravity down the existing connected waterfall meshes.
  vec2 q=vec2((p.x+p.z)*14.0,(p.y+water_time*2.4)*3.0);
  float threads=noise2(q)+.35*noise2(q*2.3);
  foam=smoothstep(.64,1.07,threads);
  ALBEDO=mix(vec3(.035,.25,.29),vec3(.72,.87,.85),foam);
  NORMAL=normalize(NORMAL+vec3(sin(q.y*3.0+q.x)*.15,cos(q.y*2.0-q.x)*.1,0.0));
  ROUGHNESS=mix(.14,.32,foam);
 } else {
  // Analytic gradients evaluate each wave once instead of four offset samples.
  vec2 q=p.xz-current*water_time;
  vec2 gradient=vec2(7.0,4.2)*(.018*cos(dot(q,vec2(7.0,4.2))))
               +vec2(-3.4,11.0)*(.011*cos(dot(q,vec2(-3.4,11.0))));
  vec2 cell=floor(q*9.0);vec2 f=fract(q*9.0);vec2 u=f*f*(3.0-2.0*f);
  vec2 du=6.0*f*(1.0-f);
  float a=hash(cell);float b=hash(cell+vec2(1,0));
  float c=hash(cell+vec2(0,1));float d=hash(cell+vec2(1,1));
  gradient+=.144*du*vec2(mix(b-a,d-c,u.y),mix(c-a,d-b,u.x));
  if(water_kind==0) {
   gradient+=vec2(.85,-.36)*(.16*cos(dot(p.xz,vec2(.85,-.36))-1.1*water_time));
   gradient+=vec2(-.46,-1.38)*(.075*cos(dot(p.xz,vec2(-.46,-1.38))-1.58*water_time));
   gradient+=vec2(2.6,-.75)*(.03*cos(dot(p.xz,vec2(2.6,-.75))-2.3*water_time));
  }
  float dx=gradient.x;float dz=gradient.y;
  NORMAL=normalize((VIEW_MATRIX*vec4(normalize(vec3(-dx,1.0,-dz)),0.0)).xyz);
  vec2 impact=water_kind==0?vec2(12.4,7.45):vec2(4.3,4.9);
  float r=distance(p.xz,impact);
  if(water_kind==0) {
   float impact_noise=noise2(p.xz*6.0-vec2(water_time*.25));
   float rings=sin(r*15.0-water_time*6.0+impact_noise*2.1);
   foam=smoothstep(.55,.96,rings)*exp(-r*1.8)*smoothstep(.2,.7,impact_noise)*.50;
  } else {
   foam=smoothstep(.6,.97,sin(r*15.0-water_time*6.0))*exp(-r*1.2)*.65;
  }
  float variation=noise2((p.xz-current*water_time)*1.8);
  vec3 deep=water_kind==0?vec3(.018,.16,.20):vec3(.045,.25,.28);
  vec3 light=water_kind==0?vec3(.055,.31,.34):vec3(.14,.43,.43);
  ALBEDO=mix(mix(deep,light,variation),vec3(.7,.86,.84),foam);
  ROUGHNESS=.16+foam*.18;
 }
 METALLIC=.18;SPECULAR=.7;
}
