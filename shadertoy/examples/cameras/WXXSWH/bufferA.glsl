#define BRIGHT_SPOTS
float BRIGHT_SPOT_TRESHOLD=0.5;

vec3 BriSp(vec3 p){
    if(p.x+p.y+p.z>BRIGHT_SPOT_TRESHOLD*3.)p=(1./(1.-p)-1.)*(1.-BRIGHT_SPOT_TRESHOLD);
    p=clamp(p,0.,100.);
    return p;
}
 

vec3 color(vec2 n){
    vec3 p=texture(iChannel0,n).rgb;
    #ifdef BRIGHT_SPOTS
    
    p=BriSp(p);
    #endif
    return p;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    fragColor = vec4(color(fragCoord/iResolution.xy),0.);
}
