const float PI=3.1415926535;

ivec2 lp;
void F(float x,float y);


float mixp(float F,vec2 S){
    return F*S.x*(1.-S.y)+S.y;
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
vec4 near(vec4 A,vec3 B){
    float tmp1=min(A.w,B.y);
    float tmp=mix2(A.z,B.z,float(B.y<0.));
    B.y=abs(B.y);
    return vec4(mix(A.xy,B.xy,float(A.y>B.y)),tmp,tmp1);
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

