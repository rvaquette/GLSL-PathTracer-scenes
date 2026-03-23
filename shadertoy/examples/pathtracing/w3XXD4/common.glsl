const float PI=3.1415926535;
struct object{
    float d;float d2;int id;int i_id;int s;
};
struct material{
    vec3 Cs;vec3 Cd;vec2 S;vec4 R;vec3 light;
};

ivec2 lp;
void F(float x,float y);

//----------------------------------------------------------------------------------------
//  1 out, 1 in...
float hash11(float p)
{
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

//----------------------------------------------------------------------------------------
//  1 out, 2 in...
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 = fract(tan(dot(p3,p3)*20.*atan(p3))) ;
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

//----------------------------------------------------------------------------------------
//  1 out, 3 in...
float hash13(vec3 p3)
{
	p3  = fract(p3 * .1031);
    p3 = fract(tan(dot(p3,p3)*20.*atan(p3))) ;
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}
//----------------------------------------------------------------------------------------
// 1 out 4 in...
float hash14(vec4 p4)
{
	p4 = fract(p4  * vec4(.1031, .1030, .0973, .1099));
    p4 = fract(tan(dot(p4,p4)*20.*atan(p4))) ;

    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.x + p4.y) * (p4.z + p4.w));
}




float luma(vec3 c){
    return dot(c,vec3(0.299,0.587,0.114));
}
vec4 rColor(vec3 c,float cosA){
    cosA=abs(cosA);
    vec3 A0=1.-sqrt(c);vec3 A1=1.+sqrt(c);
    vec3 B=sqrt(4.*sqrt(c)+cosA*cosA*pow(A0,vec3(2)));
    vec3 s0=(cosA*A0-B)/max(cosA*A0+B,1e-5);
    vec3 s1=(B*A0-cosA*A1*A1)/max(B*A0+cosA*A1*A1,1e-5);
    vec3 R=0.5*(s0*s0+s1*s1);
    return vec4(R,luma(R));
}
float mixp(float F,float S){
    return F*S/max(1.+(S-1.)*F,1e-5);
}
float fresnel(vec3 v,vec3 n,float rs){
    float cosa=dot(v,n);
    float cosb=sqrt(max(1.-(1.-cosa*cosa)/(rs*rs),0.));
    return 0.5*(pow((cosa-rs*cosb)/max(cosa+rs*cosb,1e-4),2.)+pow((cosb-rs*cosa)/max(cosb+rs*cosa,1e-4),2.));
}

vec3 hsv2rgb(vec3 c){
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
vec3 rgb2hsv(vec3 c){

    const vec4 k=vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
    vec4 p=mix(vec4(c.bg,k.wz),vec4(c.gb,k.xy),step(c.b,c.g));
    vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
    float d=q.x-min(q.w,q.y);
    return vec3(abs(q.z+(q.w-q.y)/(6.*d+0.001)),d/(q.x+0.001),q.x);

}
vec2 rot(vec2 a,float theata){
    return a.xx*vec2(cos(theata),sin(theata))+a.yy*vec2(-sin(theata),cos(theata));
}
vec3 rot(vec3 a,vec3 range){
    a.yz=rot(a.yz,range.x);
    a.xz=rot(a.xz,range.y);
    a.xy=rot(a.xy,range.z);
    return a;
}
float mix2(float A,float B,float x){
    return (B-A)*x+A;
}
float mix2(int A,float B,float x){
    return (B-float(A))*x+float(A);
}
float smin( float a, float b, float k )
{
    float h = max(k-abs(a-b),0.0);
    return min(a, b) - h*h*0.25/k;
}

// https://iquilezles.org/articles/smin
float smax( float a, float b, float k )
{
    float h = max(k-abs(a-b),0.0);
    return max(a, b) + h*h*0.25/k;
}
float sdBox(vec3 p,vec3 a);

object newObj(float d,float d2,int id,int i_id,int s){
    object o;o.d=d;o.d2=d2;o.id=id;o.i_id=i_id;o.s=s;
    return o;
}
object near(object A,vec3 B){
    object c;
    c.d2=A.d>abs(B.y)?B.y:A.d2;
    float tmp=mix2(A.i_id,B.z,float(B.y<0.));
    c.s=A.s+int(B.y<0.);
    B.y=abs(B.y);
    c.id=int(mix2(A.id,B.x,float(A.d>B.y)));
    c.d=min(A.d,B.y);
    c.i_id=int(tmp);
    return c;
}


vec2 rotClamp(vec2 pos,int n){
    float alpha=-atan(pos.x,pos.y);
    float tmp=PI/float(n);
    return abs(rot(pos,-alpha+mod(alpha,2.*tmp)-tmp));
}
vec3 rnd33(vec3 p3)
{
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

mat2 rot(float a) {return mat2(cos(a),sin(a),-sin(a),cos(a));}

float ndot(vec2 a, vec2 b ) { return a.x*b.x - a.y*b.y; }
float sdSphere(vec3 p,float r){
    return length(p)-r;
}
float sdBoundingBox( vec3 p, vec3 b, float e )
{
  p=abs(p)-b;
  vec3 q=abs(p+e)-e;
  return min(min(
      length(max(vec3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
      length(max(vec3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
      length(max(vec3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
}
float sdEllipsoid( in vec3 p, in vec3 r ) // approximated
{
    float k0 = length(p/r);
    float k1 = length(p/(r*r));
    return k0*(k0-1.0)/k1;
}
float sdTorus( vec3 p, vec2 t )
{
    return length( vec2(length(p.xz)-t.x,p.y) )-t.y;
}
float sdBox( vec3 p, vec3 b )
{
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

// la,lb=semi axis, h=height, ra=corner
float sdRhombus(vec3 p, float la, float lb, float h, float ra)
{
    p = abs(p);
    vec2 b = vec2(la,lb);
    float f = clamp( (ndot(b,b-2.0*p.xz))/dot(b,b), -1.0, 1.0 );
	vec2 q = vec2(length(p.xz-0.5*b*vec2(1.0-f,1.0+f))*sign(p.x*b.y+p.z*b.x-b.x*b.y)-ra, p.y-h);
    return min(max(q.x,q.y),0.0) + length(max(q,0.0));
}
float sdCone( in vec3 p, in vec2 c, float h )
{
  // c is the sin/cos of the angle, h is height
  // Alternatively pass q instead of (c,h),
  // which is the point at the base in 2D
  vec2 q = h*vec2(c.x/c.y,-1.0);
    
  vec2 w = vec2( length(p.xz), p.y );
  vec2 a = w - q*clamp( dot(w,q)/dot(q,q), 0.0, 1.0 );
  vec2 b = w - q*vec2( clamp( w.x/q.x, 0.0, 1.0 ), 1.0 );
  float k = sign( q.y );
  float d = min(dot( a, a ),dot(b, b));
  float s = max( k*(w.x*q.y-w.y*q.x),k*(w.y-q.y)  );
  return sqrt(d)*sign(s);
}
float sdCappedCylinder( vec3 p, float h, float r )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(h,r);
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}
float dSphere(vec3 p,vec3 rd,float r){
    float d0=sdSphere(p,r);
    float b=dot(p,rd);
    float c=dot(p,p)-r*r;
    float h=b*b-c;
    h = h>=0.?sqrt( h ):1e20;
    float d1=abs(-b-sign(d0)*h);
    d1-=1e-5;
    d1=max(d1,0.);
    d1*=sign(d0);
    return rd==vec3(0)?d0:d1;
}
float dPlane(vec3 p,vec3 rd,vec4 n){
    float d0=dot(n,vec4(p,1))/length(n.xyz);
    float d1=-abs(d0)/dot(rd,normalize(n.xyz));
    d1=d1>=0.?d1:1e20;
    d1-=1e-5;
    d1*=sign(d0);
    return rd==vec3(0)?d0:d1;
}
float dBox(vec3 ro,vec3 rd,vec3 boxSize){
    float d0=sdBox(ro,boxSize);    
    vec3 m = 1.0/rd; // can precompute if traversing a set of aligned boxes
    vec3 n = m*ro;   // can precompute if traversing a set of aligned boxes
    vec3 k = abs(m)*boxSize;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
    float d1=d0>=0.?tN:tF;//vec2( tN, tF );
    d1=tN>tF || tF<0.0?1e20:d1;
    d1-=1e-5;
    d1*=sign(d0);
    return rd==vec3(0)?d0:d1;
}
float hash( float n )
{
    return fract( n*17.5*fract( n*0.3183099 ) );
}
vec4 noised( in vec3 x )
{
    vec3 p = floor(x);
    vec3 w = fract(x);
	vec3 u = w*w*(3.0-2.0*w);
    vec3 du = 6.0*w*(1.0-w);
    
    float n = p.x + p.y*157.0 + 113.0*p.z;
    
    float a = hash(n+  0.0);
    float b = hash(n+  1.0);
    float c = hash(n+157.0);
    float d = hash(n+158.0);
    float e = hash(n+113.0);
	float f = hash(n+114.0);
    float g = hash(n+270.0);
    float h = hash(n+271.0);
	
    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return vec4( k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z, 
                 du * (vec3(k1,k2,k3) + u.yzx*vec3(k4,k5,k6) + u.zxy*vec3(k6,k4,k5) + k7*u.yzx*u.zxy ));
}


vec4 fbm3D( in vec3 x ,int n)
{
    const float scale  = 1.5;

    float a = 0.0;
    float b = 0.5;
	float f = 1.0;
    vec3  d = vec3(0.0);
    for( int i=0; i<n; i++ )
    {
        vec4 n = noised(f*x*scale);
        a += b*n.x;           // accumulate values		
        d += b*n.yzw*f*scale; // accumulate derivatives
        b *= 0.5;             // amplitude decrease
        f *= 1.8;             // frequency increase
    }

	return vec4( a, d );
}
