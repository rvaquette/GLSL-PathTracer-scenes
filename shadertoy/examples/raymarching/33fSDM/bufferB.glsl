// spectral rendering. Assuming all the spectral data is exact, this should converge to the ground truth.
// assumes scene is lit by D65 illuminant (to have cubemap colors match "perfectly" the RGB colors)

float getWavelength(float frame){
    const float spectrum_start = 380.;
    const float spectrum_end = 780.;
    
    const float spectrum_range = spectrum_end-spectrum_start;
    const float PHI = .5+.5*sqrt(5.);
    
    return fract(frame*PHI)*spectrum_range+spectrum_start;
}

void importanceSampling_s(inout vec4 fragColor, vec3 n, vec3 rd, float r, vec2 dithering, int frame)
{
    float wl = getWavelength(float(frame)+dithering.x-dithering.y);
    vec2 iorcpx =  getIOR(wl);
      
    vec3 col = vec3(0.);
    vec3 h = h_sampleGGXVNDF(n,-rd,r,dithering,frame);
    float ndoti = dot(h,-rd);
    float fresnel = conductiveFresnel(iorcpx.x,iorcpx.y,ndoti);

    vec3 dir = reflect(rd,h);
    if(dot(dir,n)>=0.){ //ignore sample if reflected vector intersects sphere
        vec3 tx = texture(iChannel2,dir).rgb;
        
        float rayIntensity = RGBtoSPD(tx,wl)*get_D65(wl);
        vec3 spectralColor = rayIntensity*spectrum_to_rgb(wl);
        
        float l = ggxMasking(n,dir,r);
        
        col = fresnel*spectralColor*l;
    } 
    
    fragColor += vec4((col),1.);
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*(fragCoord)-iResolution.xy)/iResolution.x;

    vec3 ro = vec3(0.,0.,-2.25);
    vec3 rd = normalize(vec3(uv,1.));

    vec4 noise = texture(iChannel1,fragCoord/iChannelResolution[1].xy);
    vec2 dithering = (noise.rg*255.+noise.ba)/256.;
    
    vec4 i = iSphere(vec3(0),1.,ro,rd);
    fragColor = 
        //(.5-sign(iMouse.z)*.5)*
        texture(iChannel0, fragCoord/iResolution.xy);
     
    if(i.a>10.){
        float wl =getWavelength(float(iFrame)+dithering.x-dithering.y);
        fragColor += vec4(spectrum_to_rgb(wl)*get_D65(wl)
            *RGBtoSPD(texture(iChannel2,rd).rgb,wl)
            ,1.);
        return;
    }
    vec3 p = ro+rd*i.a;

    vec3 n = normalize(p);
    float r = getRoughness(p.xzy, iChannel3);
    r*=r;
    
    const int samples = 1;
    for(int i = 0;i<samples;i++){
        importanceSampling_s(fragColor, n, rd, r, dithering, (iFrame)*samples+i);
    }
}
