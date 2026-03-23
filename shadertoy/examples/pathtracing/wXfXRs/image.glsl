#define C(c) t=max(t,smoothstep(.5,.47,texture(iChannel3,clamp(P,0.,.0625)+vec2(c%16,15-c/16)/16.).w));P.x-=.03;
#define N(a,b) f=float(a)*pow(.1,float(b)-1.);for (int i;i<int(b);i++) {C((int(mod(f,10.))+48));f*=10.;}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord/iResolution.x;
    vec4 d = texelFetch(iChannel0,ivec2(0),0); //Data
    vec3 c = texelFetch(iChannel0,ivec2(fragCoord),0).xyz/d.z; //Color
    c /= 1. + c * .8; //Tonemapping
    c = pow(c,vec3(.45)); //Gamma correction
    
    float t, f;vec2 P=uv;
    N(d.z+1.,5);C(32);C(83);C(65);C(77);C(80);C(76);C(69);C(83);
    P=uv-vec2(0,.04);
    C(32);C(32);N(d.z/(iTime-d.w),3);C(32);C(70);C(80);C(83);
    P=uv-vec2(0,.08);
    
    fragColor = vec4(mix(c,vec3(1),t),1);
}
