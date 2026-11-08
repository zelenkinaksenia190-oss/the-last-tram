shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D artwork : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 tiling = vec2(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float desaturation = 0.0;
uniform vec3 mist_color = vec3(0.085, 0.10, 0.085);
uniform bool cutout = false;
uniform float wind = 0.0;
uniform float phase = 0.0;
varying vec3 world_point;
varying vec3 view_point;
void vertex() {
 VERTEX.x += wind * pow(1.0 - UV.y, 2.0) * (sin(TIME * 0.85 + phase) + 0.3 * sin(TIME * 1.7 + VERTEX.y));
 world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 view_point = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 vec2 p = region.xy + (vec2(0.005) + fract(UV * tiling) * 0.99) * region.zw;
 vec4 c = texture(artwork, p) * tint;
 c.rgb=mix(c.rgb,vec3(dot(c.rgb,vec3(0.299,0.587,0.114))),desaturation);
 if (cutout && c.a < 0.48) discard;
 float mist = smoothstep(9.0, 70.0, length(view_point)) * 0.85;
 float shade = 0.84 + 0.07*sin(world_point.x*0.63+world_point.z*0.33)*sin(world_point.z*0.47);
 ALBEDO = mix(c.rgb*shade, mist_color, mist);
 ROUGHNESS = 1.0;
}
