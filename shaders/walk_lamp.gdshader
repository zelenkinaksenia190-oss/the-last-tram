shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 light_color : source_color = vec4(0.8,0.5,0.2,1.0);
void fragment() {
 float radius=length((UV-0.5)*2.0);
 float intensity=pow(max(0.0,1.0-radius),2.5);
 float grain=0.75+0.25*fract(sin(dot(floor(UV*110.0),vec2(12.9898,78.233)))*43758.5453);
 ALBEDO=light_color.rgb;
 ALPHA=intensity*0.26*grain;
}
