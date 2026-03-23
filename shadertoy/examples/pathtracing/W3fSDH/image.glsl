float srgb_gamma(
  float v) {
  return v <= 0.0031308
    ? v * 12.92
    : 1.055 * pow(v, 0.41666666666) - 0.055; }

vec3 srgb_gamma(
  vec3 v) {
  return vec3(
    srgb_gamma(v.r),
    srgb_gamma(v.g),
    srgb_gamma(v.b)); }


void mainImage(out vec4 o, vec2 u) {
  o = texelFetch(iChannel0, ivec2(u), 0);
  o.rgb /= o.a;
  o.rgb = max(vec3(0.0), o.rgb);
  o.rgb = srgb_gamma(o.rgb);
  o.a = 1.0; }
