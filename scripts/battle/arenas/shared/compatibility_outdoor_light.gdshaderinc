// Compatibility encodes shadowed lights separately. Preserve the combined matte colour.
uniform vec3 poke_sun_direction;
uniform vec3 poke_ambient;
uniform float poke_ambient_occlusion = 1.0;
uniform vec3 poke_fill_direction_0;
uniform vec3 poke_fill_direction_1;
uniform vec3 poke_fill_direction_2;
uniform vec3 poke_fill_colour_0;
uniform vec3 poke_fill_colour_1;
uniform vec3 poke_fill_colour_2;
varying vec3 poke_sun_view;
varying vec3 poke_fill_view_0;
varying vec3 poke_fill_view_1;
varying vec3 poke_fill_view_2;
vec3 poke_to_srgb(vec3 x) {
 x = max(x, vec3(0.0));
 return mix(x * 12.92, 1.055 * pow(x, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), x));
}
vec3 poke_to_linear(vec3 x) {
 return mix(x / 12.92, pow((x + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), x));
}
void light() {
 vec3 contribution = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
 vec3 sun_direction = poke_sun_view;
 if (LIGHT_IS_DIRECTIONAL && dot(LIGHT, sun_direction) > 0.9999) {
  vec3 base = poke_ambient * poke_ambient_occlusion;
  base += max(dot(NORMAL, poke_fill_view_0), 0.0) * poke_fill_colour_0;
  base += max(dot(NORMAL, poke_fill_view_1), 0.0) * poke_fill_colour_1;
  base += max(dot(NORMAL, poke_fill_view_2), 0.0) * poke_fill_colour_2;
  vec3 delta = max(poke_to_srgb((base + contribution) * ALBEDO) - poke_to_srgb(base * ALBEDO), vec3(0.0));
  DIFFUSE_LIGHT += poke_to_linear(delta) / max(ALBEDO, vec3(0.00001));
 } else {
  DIFFUSE_LIGHT += contribution;
 }
}
