void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord/iResolution.xy;
    vec2 texelSize = 1.0 / iResolution.xy;
    
    vec4 color = vec4(0.0);
    
    float blurRadius = 5.0;
    float samples = 0.0;
    for(float x = -blurRadius; x <= blurRadius; x++) {
        vec2 offset = vec2(x + 0.5, 0.0) * texelSize;
        color += texture(iChannel0, uv + offset);
        samples += 1.0;
    }
    
    fragColor = color / samples;
}
