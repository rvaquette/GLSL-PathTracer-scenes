// https://iquilezles.org/articles/distfunctions
float sdPlane(vec3 p, vec3 n, float h) {
    return dot(p, n) + h;
}

// https://iquilezles.org/articles/distfunctions
float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

// https://iquilezles.org/articles/distfunctions
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// https://iquilezles.org/articles/distfunctions
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// https://iquilezles.org/articles/smin
float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0);
    return min(a, b) - 0.25*h*h/k;
}

// https://iquilezles.org/articles/smin
float smax(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0);
    return max(a, b) + 0.25*h*h/k;
}

float prod3(vec3 v) {
	return v.x*v.y*v.z;
}

mat3 rot(vec3 axis, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    vec3 a = axis*(1.0 - c);
    vec4 b = vec4(axis*s, c);
    vec2 n = vec2(-1.0, 1.0);
    return mat3(
        axis.xyx*a.xxz + b.wzy*n.yxy,
        axis.yyz*a.xyy + b.zwx*n.yyx,
        axis.xzz*a.zyz + b.yxw*n.xyy
    );
}

float sdCone( vec3 p, vec2 c )
{
    float q = length(p.xy);
    return dot(c,vec2(q,p.z));
}

void pR(inout vec2 p,float a) 
{
	p = cos(a)*p+sin(a)*vec2(p.y,-p.x);
}

float rand( float n )
{
  	return fract(cos(n)*4145.92653);
}

float noise(vec2 p)
{
  	vec2 f  = smoothstep(0.0, 1.0, fract(p));
  	p  = floor(p);
  	float n = p.x + p.y*57.0;
  	return mix(mix(rand(n+0.0), rand(n+1.0),f.x), mix( rand(n+57.0), rand(n+58.0),f.x),f.y);
}

float fbm( vec2 p )
{
	mat2 m2 = mat2(1.6,-1.2,1.2,1.6);	
  	float f = 0.5000*noise( p ); p = m2*p;
  	f += 0.2500*noise( p ); p = m2*p;
  	f += 0.1666*noise( p ); p = m2*p;
  	f += 0.0834*noise( p );
  	return f;
}
