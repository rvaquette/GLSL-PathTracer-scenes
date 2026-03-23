// this is the first time i've tried to make a short code

#define V vec3

float f(V p) {
    return max(0.,1.1-length(p)-.1*texture(iChannel0,p.xy).r-.04*sin(sin(4.*p.x)+15.*p.y+6.*iTime));
}

void mainImage(out vec4 c, vec2 p) {
    V r = iResolution, 
    d = V(fract((p-.5*r.xy)/r.y*2.2)-.5,1),
    o = d*2.3-V(0,0,3),
    a = V(5);
    
    c *= 0.;
    for (int i=0; i<32; i++) {
        c.rgb += (a*=mix(V(.9,1,.8),mix(mix(V(1,.9,.8),V(.8,.9,1),step(p.x,.5*r.x)),V(1,.8,.9),step(p.x,r.x/4.)),step(p.x,r.x*.75))-f(o+=d*.05)/3.)*max(0.,(f(o)-f(o+.07)));
    }
    c = sqrt(c/(1.+c));
}

// Xor's version (361 chars)
/*

#define f(p) max(0.,1.1-length(p)-.1*texture(iChannel0,p.xy).r-.04*sin(sin(4.*(p.x))+15.*(p.y)+6.*iTime))

void mainImage(out vec4 c, vec2 p)
{
    vec3 r = iResolution,
    d = vec3(fract((p-.5*r.xy)/r.y*2.2)-.5,1),
    o = d*2.3-3./r, a = d-d+5.;
    
    for (c *= 0.; c.a++<32.; c.rgb += (a*=mat4x3(.8,.9,1,1,.8,.9,1,.9,.8,.9,1,.8)[int(p/r.x*4.)]-f(o)/3.)*max(0.,f(o)-f(.07+o)))
        o+=d*.05;
   
    c = sqrt(c/++c);
}

*/

// iq's version (349 chars)
/*

#define f(p) max(0.,1.1-length(p)-.1*texture(iChannel0,p.xy).r-.04*sin(sin(4.*(p.x))+15.*(p.y)+6.*iTime))

void mainImage(out vec4 c, vec2 p)
{
    vec3 r = iResolution,
    d = vec3(fract(1.1*(p+p-r.xy)/r.y)-.5,1),
    o = d*2.3-3./r, f = d-d, a = f+5.;
    
    for(;o.z < 1.; 
         a *= .8+.1*vec3(ivec3(104,145,6)>>2*int(4.*p/r.x)&3)-f(o)/3.,
         f += a*max(0.,f(o)-f(.07+o)) )
         o += d*.05;
   
    c.rgb = sqrt(f/++f);
}

*/
