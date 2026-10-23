shader_type spatial;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float rake(vec2 p) {
 float straight = p.y + .055*sin(p.x*.65);
 vec2 a = p-vec2(109.47,31.60);
 vec2 b = p-vec2(113.47,36.30);
 vec2 c = p-vec2(110.67,37.00);
 float da = length(a), db = length(b), dc = length(c);
 float wa = 1.0-smoothstep(1.45,2.25,da);
 float wb = 1.0-smoothstep(1.9,2.85,db);
 float wc = 1.0-smoothstep(1.05,1.70,dc);
 // Raised concentric rake strokes sit around each stone within the parallel bed.
 float wave = sin(straight*46.0);
 wave = mix(wave,sin(da*46.0),wa);
 wave = mix(wave,sin(db*46.0),wb);
 return mix(wave,sin(dc*46.0),wc);
}
void fragment() {
 vec2 p = world_pos.xz;
 float footprint = max(length(dFdx(p)),length(dFdy(p)));
 float clarity = 1.0-smoothstep(.035,.16,footprint);
 float groove = rake(p)*clarity;
 float grain = fract(sin(dot(floor(p*420.0),vec2(12.9898,78.233)))*43758.5453);
 ALBEDO = vec3(.48,.40,.27)*(1.0+.065*groove+.045*(grain-.5));
 vec2 slope = vec2(rake(p+vec2(.008,0.0))-rake(p-vec2(.008,0.0)),rake(p+vec2(0.0,.008))-rake(p-vec2(0.0,.008)))*.13*clarity;
 NORMAL = normalize((VIEW_MATRIX*vec4(normalize(vec3(-slope.x,1.0,-slope.y)),0.0)).xyz);
 ROUGHNESS = .97;
 SPECULAR = .18;
}
