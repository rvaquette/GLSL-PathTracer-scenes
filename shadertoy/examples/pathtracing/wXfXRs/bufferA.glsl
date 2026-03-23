float h21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx)*345.2927);
    p3 += dot(p3, p3.yzx + 64.37);
    return fract((p3.x + p3.y) * p3.z);
}

float h31(vec3 p) {
    p += dot(p,abs(p)+3817.34);
    p = fract(sin(p)*5823.35);
    return fract(p.x*-p.y+p.y*-p.z+dot(p,p.yzx+336.33));
}

vec3 h43(vec4 p) {
    return vec3(h21(p.xy),h21(p.yz),h21(p.zw));
}

float n31(vec3 p) {
    vec3 m = sin(fract(p)*3.14159-1.57079)*.5+.5;
    vec2 o = vec2(1,0);
    p = floor(p);
    float a = mix(h31(p),h31(p+o.yyx),m.z);
    float b = mix(h31(p+o.xyy),h31(p+o.xyx),m.z);
    float c = mix(h31(p+o.yxy),h31(p+o.yxx),m.z);
    float d = mix(h31(p+o.xxy),h31(p+o.xxx),m.z);
    return mix(mix(a,c,m.y),mix(b,d,m.y),m.x);
}

vec3 rpos(vec4 s) {
    return normalize(sin(h43(s)*6.283185));
}

mat2 r(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c,-s,s,c);
}

mat3 look(vec3 o, vec3 t) {
    vec3 f = normalize(t-o);
    vec3 r = normalize(cross(f,vec3(0,1,0)));
    vec3 u = cross(r,f);
    return mat3(r,u,f);
}

float box(vec3 p, vec3 b) {
    vec3 q = abs(p)-b;
    return length(max(q,0.)) + min(0.,max(q.x,max(q.y,q.z)));
}

float torus(vec3 p, float r) {
    return length(vec2(length(p.xz)-r,p.y));
}

#define SD .002

#define mmin(a,b) a.x < b.x ? a : b;
#define mmax(a,b) a.x > b.x ? a : b;
#define d(a) d = mmin(d,a);

vec2 dist(vec3 p) {
    vec2 d = vec2(100);
    d(vec2(length(p-5.)-2.,1));
    d(vec2(p.y+1.,2));
    d(vec2(box(p+1.,vec3(1))-.2,3));
    d(vec2(torus(p+vec3(0,1,0),1.)-.5,4));
    d(vec2(length(p-1.)-1.,5));
    return d;
}
vec3 P,D,N,C;

float raymarch(vec3 p, vec3 r, float l, float md) {
    for (int i; i < 512; i++) {
        float d = dist(p+r*l).x;
        l += d;
        if (abs(d) < SD || l > md) break;
    }
    return min(l,md);
}

float refractmarch(vec3 p, vec3 r, float l, float md) {
    for (int i; i < 128; i++) {
        float d = dist(p+r*l).x;
        l += abs(d);
        if (abs(d) < SD || l > md) break;
    }
    return min(l,md);
}

vec3 normal(vec3 p) {
    vec2 o = vec2(SD,0);
    return normalize(vec3(dist(p+o.xyy).x,dist(p+o.yxy).x,dist(p+o.yyx).x)-dist(p).x);
}

float volumetrics(float l) {
    //return l;
    float r = h21(vec2(D.x,iFrame));
    //return r > exp(-l*.05) ? l*r : l;
    for (float o; o < l; o+=1.) {
        vec3 p = P+D*o;
        if (r < smoothstep(.3,.8,n31(p*.1))*.98) return o+r;
    }
    return l;
}

vec3 tex(sampler2D t, vec3 s, float b) {
    vec3 x = texture(t,P.zy/s.zy).xyz;
    vec3 y = texture(t,P.xz/s.xz).xyz;
    vec3 z = texture(t,P.xy/s.xy).xyz;
    vec3 m = normalize(pow(abs(N), vec3(b)));
    return x*m.x+y*m.y+z*m.z;
}

struct material {
    vec3 a,e;
    float s,t,r;
};

material getmat(int m) {
    switch(m) {
        case 0:
            return material(vec3(0),vec3(0),0.,0.,0.);
        case 1:
            return material(vec3(0),N*50.+50.,0.,0.,0.);
        case 2:
            return material(vec3(.2,.2,.6),vec3(0),1.,0.,0.);
        case 3:
            return material(vec3(1,.2,.2),vec3(0),1.,0.,0.);
        case 4:
            return material(vec3(.9),vec3(0),0.,0.,0.);
        case 5:
            return material(vec3(.4,.6,.8),vec3(0),0.,abs(dot(D,N)),2.);
    }
}

#define steps 8
#define dispersion .03

vec3 sampleColor() {
    float p = float((iFrame%steps))/float((steps+1));
    return max(vec3(0),sin((vec3(0,.3333,.6666)+p+.5)*6.28318)) * 2.5;
}

float sampleDispersion() {
    return (float(iFrame%steps)/float(steps)-.5)*dispersion+1.;
}

vec3 render(vec2 uv) {
    uv += sin(vec2(152.,123.62)*iTime)/iResolution.xy*.5; //Jitter UVs
    vec2 m = iMouse.xy / iResolution.xy;
    P = vec3(0,0,-5); //Set ray origin
    P.yz *= r(-m.y*2.+1.5); P.xz *= r(m.x*8.); //Rotate ray origin
    uv *= sampleDispersion();
    D = look(P,vec3(0)) * normalize(vec3(uv,1)); //Set ray direction
    
    vec3 r = vec3(1);
    r *= sampleColor();
    for (int i; i<5; i++) {
    	float l = raymarch(P,D,.1,20.*pow(1.,float(i))); //Raymarch
        float v = volumetrics(l);
        if (v<l) {
            l = v;
            P += D*l;
            D = rpos(vec4(P,iFrame));
            r *= .5;
            continue;
        }
        P += D*l;
        vec3 n = h43(vec4(P,iFrame));
        N = normal(P); //Calculate normals
        vec2 d = dist(P); //Sample distance field
        if (abs(d.x)>SD) d.y = 0.; //Turn failed raymarches into sky material
        material m = getmat(int(d.y)); //Get material properties
        if (length(m.e)>SD) C += r*m.e; //Render emissive surface
        if (n.x < m.t) {
            m.r *= sampleDispersion();
            P -= N * SD * 2.;
            D = refract(D,N,1./m.r);
            l = refractmarch(P,D,0.,5.);
            P += D * l;
            P -= N * SD * 2.;
            D = refract(D,N,1./m.r);
            r *= pow(m.a,vec3(l));
            continue;
        }
        vec3 p = rpos(vec4(P,iFrame)); //Get random point in sphere
        D = normalize(mix(reflect(D,N),dot(p,N) > 0. ? p : -p, m.s)); //Scatter ray
        r *= m.a * max(dot(D,N),.4); //Calculate reflection color
        if (length(r)<SD) break; //Return if surface isn't reflective
    }
    return C;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 d = texelFetch(iChannel0,ivec2(0),0);
    bool a = length(d.xy-iMouse.xy) < 1.;
    if (length(fragCoord)<1.) {
        fragColor = a ? d + vec4(0,0,1,0) : vec4(iMouse.xy,1,iTime);
    } else {
        fragColor = vec4(render((fragCoord-.5*iResolution.xy)/iResolution.y),1.) +
            (a ? texelFetch(iChannel0,ivec2(fragCoord),0) : vec4(0));
    }
}
