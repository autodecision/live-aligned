shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Shared by Mediterranean_Sea and the exact-edge distant water ring.
// Contact data comes from the composed runtime, never from screen depth.
uniform float water_time = 0.0;
uniform sampler2D contact_field : filter_linear, repeat_disable;
varying vec3 world_point;

float hash21(vec2 p) {
 return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
// Value noise and analytic derivatives avoid multiple offset noise samples.
vec3 noise_gradient(vec2 p) {
 vec2 i = floor(p), f = fract(p), u = f*f*(3.0-2.0*f), du = 6.0*f*(1.0-f);
 float a=hash21(i), b=hash21(i+vec2(1,0)), c=hash21(i+vec2(0,1)), d=hash21(i+vec2(1,1));
 return vec3(mix(mix(a,b,u.x),mix(c,d,u.x),u.y),
             du*vec2(mix(b-a,d-c,u.y),mix(c-a,d-b,u.x)));
}
float noise2(vec2 p) { return noise_gradient(p).x; }
vec2 coast(vec2 p) {
 vec2 uv = (p-vec2(-64.0,-112.0))/240.0;
 vec2 field = textureLod(contact_field,clamp(uv,vec2(0),vec2(1)),0.0).rg;
 float border = min(min(uv.x,uv.y),min(1.0-uv.x,1.0-uv.y));
 return mix(vec2(-15.0,32.0),field,smoothstep(0.0,.025,border));
}
// Height and derivative of four differently directed, differently sized swells.
vec3 swell(vec2 p) {
 vec4 phases = vec4(dot(p,vec2(.33,.16)), dot(p,vec2(-.22,.51)),
                    dot(p,vec2(.91,-.35)), dot(p,vec2(-1.4,-1.1)))
               - water_time*vec4(.75,.95,1.35,1.9);
 vec4 amplitudes = vec4(.19,.11,.055,.025);
 vec4 slopes = amplitudes*cos(phases);
 return vec3(dot(amplitudes,sin(phases)),
             dot(slopes,vec4(.33,-.22,.91,-1.4)),
             dot(slopes,vec4(.16,.51,-.35,-1.1)));
}
void vertex() {
 vec3 p = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float shore_damping = mix(.42,1.0,smoothstep(0.0,3.5,coast(p.xz).y));
 VERTEX.y += swell(p.xz).x*shore_damping;
 world_point = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 vec2 p = world_point.xz;
 vec2 field = coast(p);
 float depth = max(0.0,world_point.y-field.x);
 float shore_distance = field.y;
 float distance_to_eye = length(CAMERA_POSITION_WORLD-world_point);
 float footprint = max(length(dFdx(p)),length(dFdy(p)));
 vec2 drift = p-vec2(.22,-.11)*water_time;
 vec3 broad = noise_gradient(drift*.13);
 vec2 warped = drift+vec2(broad.x,noise2(drift*.15+17.0))*1.2;
 float fine_visibility = 1.0-smoothstep(.06,.40,footprint);
 float mid_visibility = 1.0-smoothstep(.25,1.2,footprint);
 // Wide glassy patches alternate with short, crossing wind ripples.
 float wind = mix(.35,1.0,smoothstep(.20,.80,broad.x));
 vec2 gradient = swell(p).yz*mix(.42,1.0,smoothstep(0.0,3.5,shore_distance));
 gradient += (vec2(4.8,2.1)*(.010*cos(dot(warped,vec2(4.8,2.1))-water_time*.32))
             +vec2(-3.0,7.2)*(.007*cos(dot(warped,vec2(-3.0,7.2))+water_time*.48)))*wind*mid_visibility;
 gradient += noise_gradient(warped*1.7+vec2(0,water_time*.11)).yz*.105*wind*mid_visibility;
 gradient += noise_gradient(warped*7.5+vec2(water_time*.13,0)).yz*.13*wind*fine_visibility;
 vec3 normal_world = normalize(vec3(-gradient.x,1.0,-gradient.y));
 // The original sea and exported ring have different triangle winding.
 // Determine the water side from the viewer so their lighting cannot split.
 if (CAMERA_POSITION_WORLD.y < world_point.y) { normal_world = -normal_world; }
 NORMAL = normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);

 float shallows = exp(-depth*.46);
 vec3 water = mix(vec3(.009,.095,.145),vec3(.055,.29,.275),shallows);
 water *= mix(.83,1.14,broad.x)*mix(.88,1.12,noise2(warped*1.8));

 // Broken shoreward-moving wash, with an irregular contact line.
 float break_up = noise2(p*1.8-vec2(.14,.06)*water_time);
 float front = sin(shore_distance*3.8+water_time*1.3+broad.x*4.0+break_up*2.1);
 float wash = smoothstep(.60,.96,front)*(1.0-smoothstep(.2,2.4,shore_distance));
 float contact = exp(-shore_distance*4.5);
 float foam_grain = mix(.30,1.0,smoothstep(.25,.66,noise2(p*8.0-vec2(.22,.11)*water_time)));
 float foam = (wash*.58+contact*.40)*smoothstep(.28,.70,break_up)*foam_grain;
 foam *= (1.0-smoothstep(45.0,90.0,distance_to_eye))*mid_visibility;
 // Occasional wind-torn crest flecks; most open water stays clear.
 float crest = swell(p).x;
 foam += smoothstep(.24,.34,crest)*smoothstep(.69,.86,break_up)*wind*.12*mid_visibility;
 float impact = distance(p,vec2(12.4,7.45));
 foam += smoothstep(.55,.96,sin(impact*15.0-water_time*6.0+break_up*2.1))*exp(-impact*1.8)*break_up*.4;
 foam = clamp(foam,0.0,.82);
 ALBEDO = mix(water,vec3(.61,.76,.72),foam);
 ROUGHNESS = mix(.17+.045*wind+.09*(1.0-fine_visibility),.48,foam);
 METALLIC = .02;
 SPECULAR = .5;
}
