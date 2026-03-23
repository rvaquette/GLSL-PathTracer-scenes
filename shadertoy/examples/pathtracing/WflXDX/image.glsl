vec3 ACES(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.1;
    float d = 0.7;
    float e = 0.12;
    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {
    // Concise recursion system borrowed from Poisson (starts in main in buffer A)
    vec4 col = texelFetch(iChannel0, ivec2(fragCoord), 0);
    col.rgb /= col.a;
    col.rgb = ACES(col.rgb);
    fragColor = vec4(pow(col.rgb, vec3(1.0/2.2)), 1);
}
