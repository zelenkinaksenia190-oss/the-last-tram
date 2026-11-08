shader_type spatial;
render_mode unshaded;
varying vec3 p;
varying float eye_distance;
float hash(vec2 v) { return fract(sin(dot(v,vec2(42.39,73.53)))*43758.5453); }
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; eye_distance=length((MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz); }
void fragment() {
 float patch=hash(floor(p.xz*0.9));
 float blades=hash(floor(p.xz*vec2(25.0,12.0)));
 vec3 grass=mix(vec3(0.018,0.035,0.022),vec3(0.065,0.078,0.037),patch*0.6+blades*0.4);
 float leaves=step(0.978,hash(floor(p.xz*9.0)));
 grass=mix(grass,vec3(0.21,0.105,0.025),leaves*0.7);
 ALBEDO=mix(grass,vec3(0.085,0.10,0.085),smoothstep(9.0,70.0,eye_distance)*0.85);
}
