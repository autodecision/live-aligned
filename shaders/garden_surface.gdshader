shader_type spatial;
uniform vec3 base_color = vec3(.2,.22,.2);
uniform bool wood = false;
uniform bool pebbles = false;
uniform bool weathered_stone = false;
varying vec3 p;
float hash(vec3 a) { return fract(sin(dot(a,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 a) {
 vec3 i=floor(a),f=fract(a);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float broad = noise(p*3.0), fine = noise(p*74.0);
 float shade = .72+.36*broad+.12*fine;
 if (wood) { shade *= .82+.18*sin(p.x*145.0+noise(p*vec3(.5,2.0,9.0))*8.0); }
 if (pebbles) {
  float near_grain = noise(p*94.0);
  float tiny_grain = noise(p*187.0);
  float fade = 1.0-smoothstep(.35,1.4,length(fwidth(p))*94.0);
  shade *= .93+.15*near_grain+(tiny_grain-.5)*.12*fade;
 }
 vec3 color = base_color*shade;
 float relief = fine*.06+broad*.12;
 if (weathered_stone) {
  float mineral = noise(p*4.8+noise(p*1.3)*2.0);
  float chips = noise(p*31.0);
  float strata = sin(dot(p,vec3(3.4,19.0,5.2))+noise(p*5.0)*2.7);
  float fissure = pow(1.0-abs(sin(dot(p,vec3(4.2,1.3,-3.5))+noise(p*1.1)*.8)),18.0)*smoothstep(.25,.60,noise(p*5.0));
  float lichen = smoothstep(.65,.82,noise(p*9.0))*.23;
  color = base_color*(.65+.60*mineral+.12*chips+.045*strata)*(1.0-.22*fissure);
  color = mix(color,vec3(.22,.235,.13),lichen);
  relief = mineral*.075+chips*.018+strata*.005-fissure*.012;
 }
 ALBEDO = color;
 ROUGHNESS = .92;
 SPECULAR = .22;
 if (weathered_stone) {
  vec3 n = normalize(NORMAL);
  vec3 dpdx = dFdx(VERTEX), dpdy = dFdy(VERTEX);
  vec3 r1 = cross(dpdy,n), r2 = cross(n,dpdx);
  float determinant = dot(dpdx,r1);
  vec3 gradient = sign(determinant)*(dFdx(relief)*r1+dFdy(relief)*r2);
  NORMAL = normalize(abs(determinant)*n-gradient*.13);
 } else {
  NORMAL_MAP = normalize(vec3((fine-.5)*.16,(broad-.5)*.12,1.0))*.5+.5;
 }
}
