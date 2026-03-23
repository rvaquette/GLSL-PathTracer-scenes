#define PI 3.14159
#define S(a,b,k) (max(0.,k-abs(b-a))/k)
#define SMIN(a,b,k) (min(a,b)-S(a,b,k)*S(a,b,k)*S(a,b,k)*k/6.)
#define R2(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define C(p,r) (length(p)-r)

// curved lines
float CL(vec2 p, vec2 a, vec2 b, float t1, float t2, float c) {
    vec2 ba = b-a;
    float h = clamp(dot(p-a,ba)/dot(ba,ba),0.,1.);
    vec2 pos = p-a-ba*h;
    pos.y -= sin(h*PI)*c;
    return length(pos)-mix(t1,t2,h);
}

float sdNeuron(vec2 p) {
    float soma = C(p,.1);
    float nuc = C(p-vec2(.02,.01),.04);
    
    // Dendrites
    float d = 1.;
    for(float i=0.; i<12.; i++) {
        float a = i/6.*PI + sin(i)*.2;
        vec2 rp = R2(a)*p;
        float l = .5+sin(i*1.7)*.2;
        float c = .1*sin(i*2.1);
        d = SMIN(d, CL(rp,vec2(0),vec2(l,0),.02,.005,c), .1);
    }
    
    // Axon
    vec2 ap = p-vec2(.3,0);
    float ax = CL(ap,vec2(0),vec2(.8,-.2),.04,.02,.1);
    
    // Terminals
    vec2 tb = vec2(1.1,-.2);
    float tm = 1.;
    
    // Terminal 1
    float t1 = CL(p-tb,vec2(0),R2(PI*.2)*vec2(.3,0),.015,.008,.05);
    
    // Terminal 2 and so on...
    float t2 = CL(p-tb,vec2(0),R2(-PI*.2)*vec2(.3,0),.015,.008,.05);
    float t3 = CL(p-tb,vec2(0),vec2(.35,0),.015,.008,.05);
    float t4 = CL(p-tb-vec2(.25,.1),vec2(0),R2(PI*.3)*vec2(.2,0),.015,.008,.05);
    float t5 = CL(p-tb-vec2(.25,-.1),vec2(0),R2(-PI*.3)*vec2(.2,0),.015,.008,.05);
    
    tm = SMIN(SMIN(t1,t2,.05),t3,.05);
    tm = SMIN(SMIN(tm,t4,.05),t5,.05);
    
    return SMIN(SMIN(max(soma,-nuc),d,.1),SMIN(ax,tm,.05),.1);
}

Main {
    vec2 U0 = U;
    vec2 p = (2.*U-R)/min(R.x,R.y);
    p = vec2(-p.y+.5,p.x);

    float d = sdNeuron(p);
    vec3 c = vec3(0);
    
    float ng = smoothstep(.02,-.01,d);
    c += vec3(.1,.95,1.)*.7*ng;
    
    float sg = smoothstep(.01,-.01,C(p,.1));
    c += vec3(.8,.85,.9)*.3*sg;
    
    float nc = smoothstep(.01,-.01,C(p-vec2(.02,.01),.04));
    c += vec3(.7,.75,.8)*.6*nc;
    
    float edge = smoothstep(-.005,.005,d);
    c = mix(c,vec3(1.),(1.-edge)*.5);
    
    //wyatt's sorcery:
    Q = vec4(0);
    Q.x = (c.r+c.g+c.b)/3.;
    

    vec4 gn = A(U0+vec2(0,1));
    vec4 ge = A(U0+vec2(1,0));
    vec4 gs = A(U0-vec2(0,1));
    vec4 gw = A(U0-vec2(1,0));
    
    Q.yz = -vec2(ge.w-gw.w,gn.w-gs.w);
    Q.w = Q.x;
}
