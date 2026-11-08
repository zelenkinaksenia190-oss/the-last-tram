shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_point;
varying vec3 view_point;
float hash(vec2 p) { return fract(sin(dot(p,vec2(42.39,73.53)))*43758.5453); }
void vertex() {
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 view_point=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 float patch=hash(floor(world_point.xz*0.8));
 float blades=hash(floor(world_point.xz*vec2(18.0,13.0)));
 vec3 grass=mix(vec3(0.065,0.105,0.065),vec3(0.14,0.19,0.095),patch*0.6+blades*0.4);
 float dry=step(0.96,hash(floor(world_point.xz*11.0)));
 grass=mix(grass,vec3(0.22,0.18,0.10),dry*0.55);
 ALBEDO=mix(grass,vec3(0.17,0.24,0.22),smoothstep(9.0,70.0,length(view_point))*0.85);
}
