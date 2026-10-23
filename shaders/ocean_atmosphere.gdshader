shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float daylight = 1.0;
void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}
void fragment(){
 vec3 eye=INV_VIEW_MATRIX[3].xyz;
 float immersion=1.0-smoothstep(-5.25,-4.74,eye.y);
 if(immersion<.001){discard;}
 float depth=texture(scene_depth,SCREEN_UV).r;
 vec4 view=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1.0);
 vec3 view_point=view.xyz/max(view.w,.00001);
 float distance_to_surface=depth<.00001?300.0:length(view_point);
 vec3 direction=normalize((INV_VIEW_MATRIX*vec4(normalize(view_point),0.0)).xyz);
 float distance_in_water=max(distance_to_surface-1.2,0.0);
 // Blue-green scattering replaces the sky void and conceals distant mesh ends.
 vec3 tint=mix(vec3(.008,.030,.045),vec3(.035,.22,.26),daylight);
 tint*=mix(.68,1.1,smoothstep(-.35,.9,direction.y));
 vec3 transmission=exp(-distance_in_water*vec3(.075,.040,.030));
 transmission*=1.0-smoothstep(18.0,38.0,distance_to_surface);
 float edge=min(min(eye.x+55.15751,160.0-eye.x),min(eye.z+100.0,110.0-eye.z));
 transmission*=smoothstep(-8.0,22.0,edge);
 vec3 original=texture(scene_color,SCREEN_UV).rgb;
 vec3 scattered=original*transmission+tint*(vec3(1.0)-transmission);
 ALBEDO=mix(original,scattered,immersion);
 ALPHA=1.0;
}
