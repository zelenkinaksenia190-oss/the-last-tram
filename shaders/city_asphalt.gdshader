shader_type spatial;
render_mode unshaded;
varying vec3 p;
varying float eye_distance;
float hash(vec2 v) { return fract(sin(dot(v,vec2(12.9898,78.233)))*43758.5453); }
void vertex() {
 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 eye_distance=length((MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz);
}
void fragment() {
 vec2 cell=floor(p.xz*12.0);
 float grain=hash(cell);
 float patch=hash(floor(p.xz*0.6));
 vec3 road=vec3(0.052,0.063,0.059)*(0.70+grain*0.40+patch*0.25);
 float crack=step(0.992,hash(floor(p.xz*4.0)));
 road*=1.0-crack*0.55;
 ALBEDO=mix(road,vec3(0.085,0.10,0.085),smoothstep(9.0,70.0,eye_distance)*0.85);
}
