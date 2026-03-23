#define PI acos(-1.)
#define MIN_DIST 0.001
#define MAX_DIST 1500.0
#define ITERATION 200

#define MAT_VOID vec3(-1)
#define MAT_ERNST0 vec3(0.6619, 0.3542, 0.3158)
#define MAT_ERNST0_006 vec3(0.6619, 0.6108, 0.5172)
#define MAT_ERNST0_002 vec3(0.3324, 0.6921, 0.5215)
#define MAT_ERNST0_003 vec3(0.6982, 0.4874, 0.0414)
#define MAT_ERNST0_001 vec3(0.1334, 0.42, 0.1273)
#define MAT_ERNST0_005 vec3(0.1025, 0.0915, 0.0915)
#define MAT_ERNST0_004 vec3(0.2306, 0.2807, 0.6619)

float hash11(float p){
	p = fract(p * .1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}
vec2 hash22(vec2 p){
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

float vmax(vec3 v){return max(max(v.x, v.y), v.z);}
float sdEllipsoid(in vec3 p, in vec3 r){return (length(p/r)-1.0)*min(min(r.x,r.y),r.z);}
float sdCapsule(vec3 p, float r, float c){return mix(length(p.xz) - r, length(vec3(p.x, abs(p.y) - c, p.z)) - r, step(c, abs(p.y)));}
float sdTorus( vec3 p, vec2 t ){
	vec2 q = vec2(length(p.xz)-t.x,p.y);
	return length(q)-t.y;
}
float sdCappedTorus(vec3 p, vec2 r, float per){
	p.x = abs(p.x);
	vec2 sc = vec2(sin(per),cos(per));
	float k = (sc.y*p.x>sc.x*p.z) ? dot(p.xz,sc) : length(p.xz);
	return sqrt( dot(p,p) + r.x*r.x - 2.0*r.x*k ) - r.y;
}
float sdCappedCylinder( vec3 p, vec2 h ){
	vec2 d = abs(vec2(length(p.xz),p.y)) - h;
	return ((min(max(d.x,d.y),0.0) + length(max(d,0.0))))-0.0;
}
float sdPieCylinder( vec3 p, float r, float h, float per ){
	per = mod(per, PI);
	vec2 c = vec2(sin(per),cos(per));
	p.xz=c.y*p.xz+c.x*vec2(p.z,-p.x);
	p.x = abs(p.x);
	float l = length(p.xz) - r;
	float m = length(p.xz-c*clamp(dot(p.xz,c),0.0, r));
	float x = max(l,m*sign(c.y*p.x-c.x*p.z));
	float y = abs(p.y) - h;
	return ((min(max(x,y),0.0) + length(max(vec2(x,y),0.0))));
}

float sdConeSection( in vec3 p, in float h, in float r1, in float r2 ){
	vec2 q = vec2( length(p.xz), p.y );
	vec2 k1 = vec2(r2,h);
	vec2 k2 = vec2(r2-r1,2.0*h);
	vec2 ca = vec2(q.x-min(q.x,(q.y < 0.0)?r1:r2), abs(q.y)-h);
	vec2 cb = q - k1 + k2*clamp( dot(k1-q,k2)/dot(k2,k2), 0.0, 1.0 );
	float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
	return s*sqrt( min(dot(ca,ca),dot(cb,cb)) );
}

float sdRoundCone( vec3 p, float h, float r1, float r2 ){
	vec2 q = vec2( length(p.xz), p.y+h*.5 );

	float b = (r1-r2)/h;
	float a = sqrt(1.0-b*b);
	float k = dot(q,vec2(-b,a));

	if( k < 0.0 ) return length(q) - r1;
	if( k > a*h ) return length(q-vec2(0.0,h)) - r2;

	return dot(q, vec2(a,b) ) - r1;
}
float sdBox(vec3 p,vec3 b){vec3 d=abs(p)-b;return length(max(d,vec3(0)))+vmax(min(d,vec3(0.0)));}
vec4 v4OpUnion(in vec4 a,in vec4 b){
	return a.x<b.x?a:b;
}
float fOpUnionSmooth(float a,float b,float r){
	vec2 u = max(vec2(r - a,r - b), vec2(0));
	return max(r, min (a, b)) - length(u);
}
vec4 v4OpUnionSmooth(vec4 a,vec4 b,float r){
	float h=clamp(0.5+0.5*(b.x-a.x)/r,0.0,1.0);
	float res = mix(b.x,a.x,h)-r*h*(1.0-h);
	return vec4(res, mix(b.yzw,a.yzw,h));
}
vec4 v4OpSubstraction(in vec4 a,in vec4 b){
	float res = max(-a.x, b.x);
	return (res==-a.x)?vec4(-a.x, a.yzw):b;
}
vec4 v4OpSubstractionSmooth( vec4 a,vec4 b,float r){
	vec2 u = max(vec2(r + b.x, r + -a.x), vec2(0));
	float res = min(-r, max(b.x, -a.x))+length(u);
	vec3 m = mix(b.yzw, a.yzw, clamp(abs(-b.x)+abs(res),0.0,1.0)*clamp(r,0.,1.));
	return vec4(res, m);
}
vec4 v4OpIntersection(in vec4 a,in vec4 b){
	float res = max(a.x, b.x);
	return (res==a.x)?a:b;
}

vec4 v4OpIntersectionSmooth( vec4 a,vec4 b,float r){
	vec2 u = max(vec2(r + b.x,r + a.x), vec2(0));
	float res =  min(-r, max(b.x, a.x)) + length(u);
	vec3 m = mix(a.yzw, b.yzw, clamp(a.x-res,0.0,1.0)*r);
	return vec4(res, m);
}
void pRepLimited(inout float p_el, float s, float repetitions ){
	repetitions -= 1.;
	float offset = 1.-step(.5, mod(repetitions, 2.));
	p_el += s*.5*offset;
	float r = round(p_el/s);
	float half_rep = ceil(repetitions/2.);
	r = clamp(r, -half_rep, repetitions-half_rep);
	p_el-=s*r;
}
vec4 sd002(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p), bsr=10.0;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);
	d = sdEllipsoid(p+vec3(-12.0, -1.0, -4.0), vec3(0.99, 0.99, 0.99));
	res = v4OpUnion(vec4(d, MAT_ERNST0), res);

	d = sdBox(p+vec3(-12.0, -1.0, -5.0), vec3(1.0, 1.0, 1.0)-0.01)-0.01;
	res = v4OpSubstractionSmooth(vec4(d, MAT_ERNST0_001), res, 0.02);
	return res;
}
vec4 sd001(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p), bsr=15.0;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);
	d = sdEllipsoid(p+vec3(-12.0, -1.0, -8.0), vec3(0.99, 0.99, 0.99));
	res = v4OpUnion(vec4(d, MAT_ERNST0_005), res);

	d = sdBox(p+vec3(-12.0, -1.0, -9.0), vec3(1.0, 1.0, 1.0)-0.01)-0.01;
	res = v4OpIntersectionSmooth(vec4(d, MAT_ERNST0_001), res, 0.02);
	return res;
}
vec4 sdScene(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);

    vec3 cp001 = p;
	cp001.xyz += vec3(-8.0856, -4.9245, -10.7845);
	pRepLimited(cp001.y, 2.5, 3.);
	pRepLimited(cp001.z, 1.25, 4.);
	pRepLimited(cp001.x, 1.25, 4.);

	res = sd001(p);
	res = v4OpUnionSmooth(sd002(p), res, .01);

	d = sdBox(p+vec3(0.0, -1.0, -6.0), vec3(1.0, 1.0, 1.0)-0.01)-0.01;
	d = fOpUnionSmooth(sdBox(p+vec3(3.0, -1.0, -6.0), vec3(1.0, 1.0, 1.0)-0.3)-0.3, d, 0.01);
    
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0_003), res, .01);

	d = sdCappedCylinder(p+vec3(0.0, -1.0, -9.0), vec2(1.0, 1.0)-0.01)-0.01;
	d = fOpUnionSmooth(sdCappedCylinder(p+vec3(3.0, -1.0, -9.0), vec2(1.0, 1.0)-0.3)-0.3, d, 0.01);
    
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0), res, .01);

	d = sdCappedTorus(p+vec3(-3.0, -0.5, -12.0), vec2(1.0, 0.5), 2.356);
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0_004), res, .01);

	d = sdCapsule(p+vec3(-3.0, -1.0, 0.0), 0.59, 0.44);
	d = fOpUnionSmooth(sdConeSection(p+vec3(0.0, -1.021, -3.0), 1.0-0.01, 1.02-0.01, 0.0)-0.01, d, 0.01);
	d = fOpUnionSmooth(sdConeSection(p+vec3(3.0, -1.021, -3.0), 1.0-0.1, 1.02-0.1, 0.0)-0.1, d, 0.01);
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0), res, .01);

	d = sdEllipsoid(p+vec3(0.0, -1.0, 0.0), vec3(1.0, 1.0, 1.0));
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0_001), res, .01);

	d = sdEllipsoid(p+vec3(-12.0, -1.0, 0.0), vec3(0.99, 0.99, 0.99));
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0), res, .01);

	d = sdEllipsoid(p+vec3(-3.0, -1.5, -3.0), vec3(1.0, 1.5, 1.0));
	d = fOpUnionSmooth(sdPieCylinder(p+vec3(0.0, -1.0, -12.0), 1.0-0.01, 1.0-0.01, 2.356)-0.01, d, 0.01);
	d = fOpUnionSmooth(sdPieCylinder(p+vec3(3.0, -1.0, -12.0), 1.0-0.3, 1.0-0.3, 2.356)-0.3, d, 0.01);
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0_001), res, .01);

	d = p.y;
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0_002), res, 0.01);

	{
        // sdHex
		vec3 tp = p+vec3(-6.0, -1.1, 0.0);
		vec3 trp = p.xzy+vec3(-6.,-1.1,0)+vec3(0,1,-1.1);//rot(p+vec3(-6.0, -1.1, 0.0), vec3(1.5708, 0.0, 0.0));
		vec3 dim = vec3(0.75, 0.75, 1.0);
		float td = MAX_DIST;
        
		const vec3 k = vec3(-0.866254, 0.5, 0.57735);
		vec2 h = dim.xz;
		trp = abs(trp);
		trp.xy -= 2.0*min(dot(k.xy, trp.xy), 0.0)*k.xy;
		vec2 d2 = vec2(
			 length(trp.xy-vec2(clamp(trp.x,-k.z*h.x,k.z*h.x), h.x))*sign(trp.y-h.x),
			 trp.z-h.y );
		td = min(max(d2.x,d2.y),0.0) + length(max(d2,0.0))-.01;
		d=td;
	}
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0_005), res, 0.01);

	{
		vec3 tp = cp001;
		vec3 trp = cp001;
		vec3 dim = vec3(0.6342, 1.0, 0.6342);
		float td = MAX_DIST;
		
		float r = max(dim.x, dim.z);
		float c = dim.y*.5;
		float elg = c-min(.5,c);
		trp.y -= clamp(trp.y,-elg,elg);
		
		float a = .5*trp.y*trp.y+.5;
		float b = abs(trp.y);
		trp.y = b<1. ? a : b;
		
		trp.y -= min(.5,c);
		td = length(trp)-r;
		d=td;
	}
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0_006), res, 0.01);

	d = sdRoundCone(p+vec3(-3.0, -1.5, -6.0), 1.5, 0.765, 0.0);
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0), res, 0.01);

	d = sdTorus(p+vec3(-3.0, -0.5, -9.0), vec2(1.0, 0.5));
	d = fOpUnionSmooth(sdBox(p+vec3(-12.0, -1.0, -1.0), vec3(1.0, 1.0, 1.0)-0.01)-0.01, d, 0.01);
	res = v4OpUnionSmooth(vec4(d, MAT_ERNST0_001), res, 0.01);

	return res;
}
mat2 rotate(float r){return mat2(cos(r),sin(r),-sin(r),cos(r));}
vec3 rotate(vec3 c,float r){return vec3(rotate(r)*c.xz,c.y).xzy;}
float de(vec3 c){
    return sdScene(c).x+fract(length(vec3(hash11(c.x),hash11(c.y),hash11(c.z)))*100.)/1000.;
}
vec4 doMarch(vec3 pos,vec3 cam){
    int i = 0;
    vec3 march = vec3(0);
    float d = 1.;
    
    for(;i<100&&d>0.02&&length(march)<100.;i++){
        d = de(pos+march);
        march += d*cam;
    }
    return vec4(march+pos,i);
}
vec3 getnormal(vec3 n){
    vec2 e = vec2(1.0,-1.0)*(n.y<0.002-1.?.002:.002);
    return normalize(e.xyy*de(n+e.xyy)+e.yyx*de(n+e.yyx)+e.yxy*de(n+e.yxy)+e.xxx*de(n+e.xxx));
}
vec3 getcol(vec3 c){
    return length(c)<50.?sdScene(c).yzw:vec3(.9);
}
void mainImage(out vec4 o,vec2 u){
    vec2 U = u;
    u += fract(hash22(u+iTime)*10000.);
	vec2 uv = (u-iResolution.xy/2.)/iResolution.y;
    
    vec3 pos = vec3(-4,7,-4);
    vec2 look = vec2(-.65,-.5);
    vec3 cam = rotate(rotate(normalize(vec3(uv,1)).yxz,-look.y).yxz,look.x);
    
    vec4 march = doMarch(pos,cam);
    vec3 col = getcol(march.xyz);
    for(int i = 0;i<10;i++){
        pos = march.xyz;
        vec3 refl = reflect(cam,getnormal(pos));
        pos += refl/10.;
        cam = refl;
        march = doMarch(pos,cam);
        if(length(march.xyz)>100.)break;
        col *= getcol(march.xyz);
    }
	o = vec4(col, 1.);
    vec4 old = texelFetch(iChannel0,ivec2(U),0);
    if(iFrame!=0)o = mix(o,old,.99);
}
