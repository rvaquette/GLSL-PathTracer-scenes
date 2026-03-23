void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    int j = int(fragCoord.x);
    vec4 circle = texelFetch(iChannel0, ivec2(j, 0), 0);
    float fun = smoothstep(0.0, 1.0, sin(iTime * 0.5));
    vec3 animation = vec3(sin(iTime + float(j) * 2.0), cos(iTime + float(j) * 3.0), cos(iTime * 2.0 + float(j) * 4.0)) * 0.3 * fun * smoothstep(8.0, 12.0, iTime);
    circle.xyz += animation;
    circle.w *= mix(1.1, 0.4, fun);
    fragColor = circle;
}
