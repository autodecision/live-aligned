shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float effect_mix=1.0;
uniform float exposure=0.0;
uniform float contrast=1.0;
uniform float saturation=1.0;
uniform float vibrance=0.0;
uniform float temperature=0.0;
uniform float tint=0.0;
uniform float shadow_tone=0.0;
uniform float highlight_warmth=0.0;
uniform float gamma=1.0;
uniform float shadow_lift=0.0;
uniform float highlight_rolloff=0.0;
uniform float bloom=0.0;
uniform float bloom_radius=5.0;
uniform float bloom_threshold=.72;
uniform float sharpness=0.0;
uniform float vignette=0.0;
uniform float vignette_softness=.65;
uniform float chromatic=0.0;
uniform float film_grain=0.0;
uniform float lens_distortion=0.0;
uniform float letterbox=0.0;
uniform float posterize=0.0;
uniform float color_levels=16.0;
uniform float outlines=0.0;
uniform float outline_width=1.0;
uniform float scanlines=0.0;
uniform float bleach=0.0;
float luminance(vec3 c) { return dot(c,vec3(.2126,.7152,.0722)); }
float grain_hash(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
vec3 read_screen(vec2 p) { return textureLod(screen_texture,clamp(p,vec2(0.0),vec2(1.0)),0.0).rgb; }
void fragment() {
 vec2 original_uv=SCREEN_UV;
 vec3 original=read_screen(original_uv);
 vec2 uv=original_uv;
 if(abs(lens_distortion)>.0001) {
  vec2 q=(uv-.5)*2.0;uv=.5+q*.5*(1.0+lens_distortion*dot(q,q));
 }
 vec3 c=read_screen(uv);
 if(chromatic>.001) {
  vec2 offset=(uv-.5)*SCREEN_PIXEL_SIZE*chromatic*2.0;
  c.r=read_screen(uv+offset).r;c.b=read_screen(uv-offset).b;
 }
 if(sharpness>.001 || outlines>.001) {
  vec2 d=SCREEN_PIXEL_SIZE*max(1.0,outline_width);
  vec3 left=read_screen(uv-vec2(d.x,0));vec3 right=read_screen(uv+vec2(d.x,0));
  vec3 up=read_screen(uv-vec2(0,d.y));vec3 down=read_screen(uv+vec2(0,d.y));
  c+=sharpness*(c-(left+right+up+down)*.25);
  float edge=length(vec2(luminance(right)-luminance(left),luminance(up)-luminance(down)));
  c*=1.0-smoothstep(.06,.28,edge)*outlines*.8;
 }
 if(bloom>.001) {
  vec2 d=SCREEN_PIXEL_SIZE*bloom_radius;
  vec3 halo=vec3(0.0);
  for(int i=0;i<8;i++) {
   float angle=float(i)*.785398;
   vec3 sample_color=read_screen(uv+vec2(cos(angle),sin(angle))*d);
   halo+=max(sample_color-vec3(bloom_threshold),vec3(0.0));
  }
  c+=halo*(bloom*.45/(8.0*max(.05,1.0-bloom_threshold)));
 }
 c*=exp2(exposure);
 c*=vec3(1.0+temperature*.16,1.0,1.0-temperature*.16);
 c+=tint*vec3(.035,-.06,.035);
 float lum=luminance(c);
 c+=vec3(-.25,.45,.6)*shadow_tone*(1.0-smoothstep(.08,.65,lum))*.12;
 c+=vec3(.9,.4,-.4)*highlight_warmth*smoothstep(.35,.9,lum)*.1;
 c=(c-.5)*contrast+.5;
 lum=luminance(c);
 c=mix(vec3(lum),c,saturation);
 float color_range=max(c.r,max(c.g,c.b))-min(c.r,min(c.g,c.b));
 c=mix(vec3(luminance(c)),c,1.0+vibrance*(1.0-clamp(color_range,0.0,1.0)));
 c=pow(max(c,vec3(0.0)),vec3(1.0/max(.1,gamma)));
 c+=shadow_lift*(1.0-smoothstep(0.0,.6,luminance(c)));
 c=mix(c,c/(1.0+max(c-vec3(.65),vec3(0.0))*2.0),highlight_rolloff);
 c=clamp(c,vec3(0.0),vec3(1.0));
 if(posterize>.001)c=mix(c,floor(c*color_levels+.5)/color_levels,posterize);
 if(bleach>.001) {
  lum=luminance(c);vec3 silver=mix(2.0*c*lum,1.0-2.0*(1.0-c)*(1.0-lum),step(.5,lum));
  c=mix(c,mix(vec3(lum),silver,.65),bleach);
 }
 if(scanlines>.001)c*=1.0-scanlines*(.5+.5*sin(original_uv.y/SCREEN_PIXEL_SIZE.y*3.141593));
 if(film_grain>.001)c+=(grain_hash(original_uv/SCREEN_PIXEL_SIZE+floor(TIME*24.0))-.5)*film_grain;
 float radius=length((original_uv-.5)*vec2(1.0,.85))*1.7;
 c*=1.0-vignette*smoothstep(1.0-vignette_softness,1.15,radius);
 if(letterbox>.001)c*=step(letterbox,original_uv.y)*step(original_uv.y,1.0-letterbox);
 c=mix(original,c,effect_mix);
 COLOR=vec4(clamp(c,vec3(0.0),vec3(1.0)),1.0);
}
