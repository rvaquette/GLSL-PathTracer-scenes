// Just a pbr shader to test materials.

// aces tonemapper
vec3 ACES(vec3 x) {
    float a = 2.51;
    float b =  .03;
    float c = 2.43;
    float d =  .59;
    float e =  .14;
    return (x*(a*x+b))/(x*(c*x+d)+e);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // normalized pixel coordinates
    vec2 p = fragCoord/iResolution.xy;
    
    float w = texture(iChannel0, p).w; // numbers of renders
    
    // base texture with chromatic aberration
    vec2 off = (p-.5)*.00; // CA offset
    vec3 col = vec3(texture(iChannel0, p+off).r,
                    texture(iChannel0, p    ).g,
                    texture(iChannel0, p-off).b)/w;
    
    col = pow(col, vec3(.4545)); // gamma correction
    col = ACES(col); // tonemapping
   
    // color grading
    col = col*col*(3.-2.*col); // contrast
    col = 1.85*col/(1.+col); // highlighs rollof

    // vignette
    col *= .5+.5*pow(16. * p.x*p.y*(1.-p.x)*(1.-p.y), .1);
   
    // output
    fragColor = vec4(col,1.);
}
