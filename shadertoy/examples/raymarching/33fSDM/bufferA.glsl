// RGB rendering, using Lazanyi approximation

void importanceSampling(bool useCubemap, inout vec4 fragColor, vec3 n, vec3 rd, vec3 ld, float r,
    vec2 dithering, samplerCube cubemap, int iFrame,bool useLaz)
{
    vec3 col = vec3(0.);
    
    vec3 h = h_sampleGGXVNDF(n,-rd,r,dithering,iFrame);
    float ndoti = dot(h,-rd);
  
    vec3 f = Lazanyi2019(f0_,f82_,ndoti); // Schlick(f0,ndoti); //(worse approximation)
    vec3 dir = reflect(rd,h);
    if(dot(dir,n)>=0.){ //ignore sample if reflected vector intersects sphere
        vec3 tx = texture(cubemap,dir).rgb;
        float l = ggxMasking(n,dir,r);
        col = f*tx*l;
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
    
    if(i.a>100000.){
        fragColor = texture(iChannel2,rd);
        return;
    }
    
    vec3 p = ro+rd*i.a;
    vec3 n = i.rgb;
    float r = getRoughness(p.xzy,iChannel3);
    r*=r;
    fragColor = 
        //(.5-sign(iMouse.z)*.5)*
        texture(iChannel0,fragCoord/iResolution.xy);
    const int samples = 1;
    for(int i = 0;i<samples;i++){
        importanceSampling(true, fragColor,n,rd,vec3(0),r,dithering,iChannel2,(iFrame%2048)*samples+i,
        true);
    }
    

}
