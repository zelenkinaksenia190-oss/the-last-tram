shader_type sky;
render_mode use_half_res_pass;
uniform sampler2D cloud_painting : source_color, filter_nearest, repeat_enable;
void sky() {
 // A horizontal cloud layer avoids pinching the painted clouds at the top of the dome.
 vec2 plane=EYEDIR.xz/max(0.08,EYEDIR.y)*vec2(0.10,0.30);
 plane+=vec2(TIME*0.0018,TIME*0.00025);
 vec2 mirrored=abs(fract(plane*0.5)*2.0-1.0);
 vec3 clouds=texture(cloud_painting,vec2(mirrored.x,mirrored.y*0.73)).rgb*vec3(0.75,0.61,0.48);
 vec3 horizon=vec3(0.14,0.115,0.075);
 COLOR=mix(horizon,clouds,smoothstep(-0.03,0.14,EYEDIR.y));
}
