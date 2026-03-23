void mainImage(out vec4 o, vec2 u) {
    o = texelFetch(iChannel0, ivec2(u), 0);
    o.rgb /= o.a;
    o.rgb = max(vec3(0.0), o.rgb);
    o.rgb = srgb_gamma(o.rgb);
    o.a = 1.0; }
