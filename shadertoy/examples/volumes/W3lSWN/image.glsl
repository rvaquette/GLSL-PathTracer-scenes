// here we just output texture computed in "Buf A"
// see dithering tutorial in https://www.shadertoy.com/view/XsdXzN

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    vec3 color = texture(iChannel0, uv).r*vec3(1.0, 0.5, 0.25);
    color = pow(color, vec3(1.8));
    color = color/(1.0 + color);
    fragColor = vec4(color,1.0);
    
}
