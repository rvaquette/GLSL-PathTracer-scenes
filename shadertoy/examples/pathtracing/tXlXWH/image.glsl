// more realistic color range
vec3 ACES(vec3 x) {
    float a = 2.51;
    float b =  .06;
    float c = 2.1;
    float d =  .7;
    float e =  .14;
    return (x*(a*x+b))/(x*(c*x+d)+e);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec4 data = texelFetch(iChannel0, ivec2(fragCoord), 0);
    vec3 col = data.rgb/data.w;
    
    col = pow(col,vec3(.4545)); // gamma correction
    col = ACES(col);
    
    // vignette
    vec2 p = fragCoord/iResolution.xy;
    col *= clamp(pow(100. * p.x*p.y*(1.-p.x)*(1.-p.y), .1), 0., 1.);
    // dithering
    col += fract(sin(fragCoord.x*vec3(13,1,11)+fragCoord.y*vec3(1,7,5))*158.391832)/255.;
        
    // output
    fragColor = vec4(col,1.0);
}
