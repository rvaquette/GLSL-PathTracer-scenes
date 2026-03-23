#define put(e) res = with(e,res)

struct C{
    float d;
    int t;
};
    
vec3 light = normalize(vec3(-2,0,0));
    
float box(vec3 s,vec3 p){
    return length(max(abs(p)-s,0.))-0.01;
}

float sbox(vec3 s,vec3 p){
    vec3 d = abs(p) - s;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float fbox(vec3 s,vec3 p){
    float frame,res;
    frame = box(vec3(s.x,s.y,0.001),p-vec3(0,0,s.z));
    res = frame;
    frame = box(vec3(s.x,s.y,0.001),p-vec3(0,0,-s.z));
    res = min(frame,res);
    frame = box(vec3(0.001,s.y,s.z),p-vec3(s.x,0,0));
    res = min(frame,res);
    frame = box(vec3(0.001,s.y,s.z),p-vec3(-s.x,0,0));
    res = min(frame,res);
    return res;
}

C with(C a, C b){
	if(a.d < b.d) return a;
    else return b;
}    

C dist(vec3 p){
    C res;
    C frame;
    frame = C(fbox(vec3(1,1.6,1)/4.,p-vec3(0,0.2,0)),0);
    res = frame;
    C base;
    base = C(max(sbox(vec3(1,0.1,1)/4.,p-vec3(0,-0.26,0)),-sbox(vec3(0.8,1.,0.8)/4.,p-vec3(0,-0.26,0))),2);
    put(base);
    base = C(box(vec3(1,0.1,1)/4.,p-vec3(0,-0.66,0)),1);
    put(base);
    C stick;
    stick = C(box(vec3(0.09,1,0.09)/4.,p-vec3(-0.225,-0.4,0.225)),1);
    put(stick);
    stick = C(box(vec3(0.09,1,0.09)/4.,p-vec3(0.225,-0.4,0.225)),1);
    put(stick);
    stick = C(box(vec3(0.09,1,0.09)/4.,p-vec3(-0.225,-0.4,-0.225)),1);
    put(stick);
    stick = C(box(vec3(0.09,1,0.09)/4.,p-vec3(0.225,-0.4,-0.225)),1);
    put(stick);
    C con = C(box(vec3(0.85,0.2,0.85)/4.,p-vec3(0,-0.61,0)),1);
    put(con);
    
    C table = C(box(vec3(3.,1.,3.)/4.,p-vec3(-0.3,-0.96,0.3)),3);
    put(table);
    put(C(-p.x + 0.45,4));
    put(C(p.z + 0.45,4));
    return res;
}

vec3 normal(vec3 p){
    vec2 e = vec2(0.001,0);
    return normalize(vec3(
        dist(p+e.xyy).d - dist(p-e.xyy).d,
        dist(p+e.yxy).d - dist(p-e.yxy).d,
        dist(p+e.yyx).d - dist(p-e.yyx).d));
}

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
float hash( float n ) { return fract(sin(n)*753.5453123); }
float noiseBase( in vec3 x , float e )
{
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
	
    float n = p.x + p.y*157.0 + 113.0*p.z + e;
    return mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
                   mix( hash(n+157.0), hash(n+158.0),f.x),f.y),
               mix(mix( hash(n+113.0), hash(n+114.0),f.x),
                   mix( hash(n+270.0), hash(n+271.0),f.x),f.y),f.z);
}
const mat3 m = mat3( 0.00,  0.80,  0.60,
                    -0.80,  0.36, -0.48,
                    -0.60, -0.48,  0.64 );
float noise(vec3 p, float e){
    float f = 0.0;
    vec3 q = 8.0*p;
    f  = 0.5000*noiseBase( q,e ); q = m*q*2.01;
    f += 0.2500*noiseBase( q,e ); q = m*q*2.02;
    f += 0.1250*noiseBase( q,e ); q = m*q*2.03;
    f += 0.0625*noiseBase( q,e ); q = m*q*2.01;
    return f;
}
float pattern(vec3 p){
    return noise(p,0.);
}
vec2 Dpat(vec3 p, vec3 n1, vec3 n2){
    n1 *= 0.001;
    n2 *= 0.001;
    return normalize(vec2(
        pattern(p+n1) - pattern(p-n1),
        pattern(p+n2) - pattern(p-n2)));
}

vec3 render(vec3 p,vec3 v,vec3 n,int t){
    if(t==0){
        p.y -= 0.2;
        float dep = pattern(p);
        vec2 n2 = Dpat(p,vec3(0,1,0),cross(vec3(0,1,0),n));
        vec3 nr = normalize(vec3(n2.y*(1.-abs(n.x)),n2.x,n2.y*(1.-abs(n.z)))+n*15.);
        vec3 e = mix(vec3(1),vec3(0.4),abs(nr.y));
        if(dot(p,nr) > 0.)e *= 0.5 / pow(length(p),0.8);
        else e *= 1.3 / pow(length(p),0.9);
        e -= dep * vec3(0,0.7,1.0) * 0.3;
        e *= vec3(0.9,0.8,0.5);
        float ef = 1./1.5;
        e = vec3(pow(e.x,ef),pow(e.y,ef),pow(e.z,ef));
        return e;
    }else if(t==3){
        vec3 col = texture(iChannel1,vec2(p.x,p.z)/2.).xyz;
        p.y -= 0.2;
        col *= 0.2 / pow(length(p),2.);
        return col;
    }else if(t==4){
        vec3 col = texture(iChannel1,vec2(p.x+p.z,p.y)/2.).xyz;
        p.y -= 0.2;
        col *= 0.3 / pow(length(p),2.);
        return col;
    }else{
        vec3 c = vec3(0);
        c += max(dot(-v,n),0.0)/20.0;
        c += pow(max(dot(reflect(v,n),light),0.0),10.0)/5.0;
        if(t==2){
            c += 0.2 / pow(length(p),1.5) * n.y * vec3(0.9,0.9,0.5);
        }
        return c;
    }
}

float ao(vec3 p,vec3 n){
    float e = 0.0;
    for(int i=1;i<5;i++){
        e += dist(p+n*float(i)/10.0).d / (float(i)/10.0) * pow(2.,-float(i));
    }
    return pow(e+0.5,0.7);
}

vec3 color(vec3 p, vec3 v){
    float d = 0.001;
    int maxIter = 100;
    C c=C(0.,-1);
    for(int i=0;i<100;i++){
        C ci=dist(p+d*v);
        float rd = ci.d;
        if(abs(rd) < 0.001){
            maxIter=i;
            c=ci;
            break;
        }
        d += rd;
    }
    if(c.t==-1)return v*0.5+0.5;
    vec3 pos = p+d*v;
    vec3 n = normal(pos);
    return render(pos,v,n,c.t)*ao(pos,n);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 R = iResolution.xy, 
	uv = (2.*fragCoord.xy - R)/R.y;
    vec3 p=vec3(0,0,0);
    vec3 vi = vec3(1,0,0);
    vec3 v=vec3(4.0,uv.y,uv.x);
    v=normalize(v);
    vi=normalize(vi);
    float rot;
    rot = 0.4;
    v.xy *= mat2(cos(rot),sin(rot),-sin(rot),cos(rot));
    vi.xy *= mat2(cos(rot),sin(rot),-sin(rot),cos(rot));
    rot = sin(iTime)/2.+3.1415/4.;
    v.xz *= mat2(cos(rot),sin(rot),-sin(rot),cos(rot));
    vi.xz *= mat2(cos(rot),sin(rot),-sin(rot),cos(rot));
    p -= vi*3.;
	fragColor = vec4(color(p,v),1.0);
}
