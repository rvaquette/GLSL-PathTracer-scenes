// computing f0 and f82 using spectral integration of the exact fresnel for angles of incidence 0 and ~82°
// under a standart D65 Illuminant   
// (acos(1./7.) ~= 81.79° ~= 82°)

float getWavelength(float frame){
    const float spectrum_start = 380.;
    const float spectrum_end = 780.;
    
    const float spectrum_range = spectrum_end-spectrum_start;
    const float PHI = .5+.5*sqrt(5.);
    
    return fract(frame*PHI)*spectrum_range+spectrum_start;
}

void precompute_fresnel(inout vec4 fragColor, vec2 dithering, int frame)
{
    float wl = getWavelength(float(frame)+dithering.x-dithering.y);
    vec2 iorcpx =  getIOR(wl);

    vec3 col = vec3(0.);

    float ndoti = (gl_FragCoord.x<iResolution.x*.5? 1. : 1./7. );
    
    float fresnel = conductiveFresnel(iorcpx.x,iorcpx.y,ndoti);

    vec3 tx = get_D65(wl)*spectrum_to_rgb(wl);

    col = fresnel*tx;
    
    fragColor += vec4((col),1.);
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*(fragCoord)-iResolution.xy)/iResolution.x;

    
    vec4 noise = texture(iChannel1,fragCoord/iChannelResolution[1].xy);
    vec2 dithering = (noise.rg*255.+noise.ba)/256.;
    
    if(abs(uv.x)>.6){
        float wl =getWavelength(float(iFrame)+dithering.x-dithering.y);
        fragColor = texture(iChannel0, fragCoord/iResolution.xy)+
            vec4(spectrum_to_rgb(wl)*get_D65(wl)
            ,1.);
        return;
    }

    fragColor = 
        //(.5-sign(iMouse.z)*.5)*
        texture(iChannel0, fragCoord/iResolution.xy);
    const int samples = 1;
    for(int i = 0;i<samples;i++){
        precompute_fresnel(fragColor, dithering, (iFrame)*samples+i);
    }
}
