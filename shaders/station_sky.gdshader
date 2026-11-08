shader_type sky;
render_mode use_half_res_pass;
uniform sampler2D cloud_painting : source_color, filter_nearest, repeat_enable;
void sky() {
 vec2 plane=EYEDIR.xz/max(0.08,EYEDIR.y)*vec2(0.10,0.30);
 plane+=vec2(TIME*0.0015,TIME*0.0002);
 vec2 mirrored=abs(fract(plane*0.5)*2.0-1.0);
 vec3 source=texture(cloud_painting,vec2(mirrored.x,mirrored.y*0.73)).rgb;
 float paint=dot(source,vec3(0.3,0.59,0.11));
 vec3 clouds=mix(vec3(0.22,0.31,0.30),vec3(0.52,0.60,0.54),paint);
 COLOR=mix(vec3(0.24,0.34,0.32),clouds,smoothstep(-0.03,0.14,EYEDIR.y));
}
