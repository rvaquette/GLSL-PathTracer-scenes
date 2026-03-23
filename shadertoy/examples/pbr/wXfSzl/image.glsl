
const int MAX_MARCHING_STEPS=1024;
const float MIN_DIST=.01;
const float MAX_DIST=10.;
const float EPSILON=.00001;
const float PI = 3.141;

// Primitives from https://iquilezles.org/articles/distfunctions

float sdSphere(vec3 p,float s)
{
    return length(p)-s;
}

float sdBox(vec3 p,vec3 b)
{
    vec3 q=abs(p)-b;
    return length(max(q,0.))+min(max(q.x,max(q.y,q.z)),0.);
}

float sdRoundBox(vec3 p,vec3 b,float r)
{
    vec3 q=abs(p)-b;
    return length(max(q,0.))+min(max(q.x,max(q.y,q.z)),0.)-r;
}

float sdVerticalCapsule(vec3 p,float h,float r)
{
    p.y-=clamp(p.y,0.,h);
    return length(p)-r;
}

float sdCapsule(vec3 p,vec3 a,vec3 b,float r)
{
    vec3 pa=p-a,ba=b-a;
    float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);
    return length(pa-ba*h)-r;
}

float sdCylinder( vec3 p, vec3 c )
{
  return length(p.xz-c.xy)-c.z;
}


float opUnion(float d1,float d2){return min(d1,d2);}

float opSubtraction(float d1,float d2){return max(-d1,d2);}

float opIntersection(float d1,float d2){return max(d1,d2);}

float opSmoothUnion(float d1,float d2,float k){
    float h=clamp(.5+.5*(d2-d1)/k,0.,1.);
return mix(d2,d1,h)-k*h*(1.-h);}

float opSmoothSubtraction(float d1,float d2,float k){
    float h=clamp(.5-.5*(d2+d1)/k,0.,1.);
return mix(d2,-d1,h)+k*h*(1.-h);}

float opSmoothIntersection(float d1,float d2,float k){
    float h=clamp(.5-.5*(d2-d1)/k,0.,1.);
return mix(d2,d1,h)+k*h*(1.-h);}

vec3 rotateX(vec3 p,float angle){
    return vec3(mat4(
            1,0,0,0,
            0,cos(angle),-sin(angle),0,
            0,sin(angle),cos(angle),0,
            0,0,0,1
        )*vec4(p,0)
    );
}

vec3 rotateY(vec3 p,float angle){
    return vec3(mat4(
            cos(angle),0,sin(angle),0,
            0,1,0,0,
            -sin(angle),0,cos(angle),0,
            0,0,0,1
        )*vec4(p,0)
    );
}

vec3 rotateZ(vec3 p,float angle){
    return vec3(mat4(
            cos(angle),-sin(angle),0,0,
            sin(angle),cos(angle),0,0,
            0,0,1,0,
            0,0,0,1
        )*vec4(p,0)
    );
}

vec3 repeat(in vec3 p,in vec3 c){
    return mod(p+.5*c,c)-.5*c;
}

vec3 twist(in vec3 p,float k){
    float c=cos(k*p.y);
    float s=sin(k*p.y);
    mat2 m=mat2(c,-s,s,c);
    return vec3(m*p.xz,p.y);
}

vec3 cheapBend(in vec3 p,float k){
    float c=cos(k*p.x);
    float s=sin(k*p.x);
    mat2 m=mat2(c,-s,s,c);
    return vec3(m*p.xy,p.z);
}

vec3 cameraTransform(vec3 p) {
    return rotateY(rotateX(p,.3+sin(iTime*.2)*.4), iTime*0.2);
}

float grimace(in vec3 p) {
    return opSmoothUnion(
        sdRoundBox(cheapBend(p,sin(iTime*3.)),vec3(1.1,.2,.4),.05),
        sdRoundBox(cheapBend(rotateY(p, 3.141*.5),cos(iTime*3.)),vec3(1.1,.2,.4),.05),
        .4
    );
}

float displace(in vec3 p) {
    return sin(5.*p.x+iTime)*sin(5.*p.y+iTime*.9)*sin(5.*p.z+iTime*.8)*.1;
}

float sceneSDF2(in vec3 p){
    return sdSphere(p, .6 + sin(iTime*.1)*.7);
}


float sceneSDF(in vec3 p){
    return opSmoothUnion(opSmoothIntersection(grimace(p), sceneSDF2(p), .1), opSmoothSubtraction(
		opSmoothUnion(
        	opSmoothUnion(
            	sdCylinder(p, vec3(0,0,.5)),
            	sdCylinder(rotateZ(p, PI*.5), vec3(0,0,.5)),
                .03
        	),
        	sdCylinder(rotateX(p, PI*.5), vec3(0,0,.5)),
            .03
    	),
    	opSmoothIntersection(
    		sdSphere(p, 1.),
        	sdBox(p, vec3(.75)),
            .03
    	),.03
    ),.3);
}

float march(in vec3 ro,in vec3 rd){
    float depth=MIN_DIST;
    int cost=MAX_MARCHING_STEPS;
    for(int i=0;i<MAX_MARCHING_STEPS;i++){
        float dist=sceneSDF(ro+depth*rd);
        if(dist<EPSILON){
            cost=i;
            break;
        }
        depth+=dist;
        if(depth>=MAX_DIST){
            cost=i;
            depth=MAX_DIST;
            break;
        }
    }
    return depth;
}

vec3 calcNormal(in vec3 p)
{
    const float h = 0.0001; // replace by an appropriate value
    const vec2 k = vec2(1,-1);
    return normalize( k.xyy*sceneSDF( p + k.xyy*h ) + 
                      k.yyx*sceneSDF( p + k.yyx*h ) + 
                      k.yxy*sceneSDF( p + k.yxy*h ) + 
                      k.xxx*sceneSDF( p + k.xxx*h ) );
}


vec4 normalColor( in vec3 pos)
{
	return vec4(calcNormal(pos)*0.5+0.5, 1.);    	
}

vec4 aoColor(in vec3 pos, in vec3 rd) {
    vec3 nor = calcNormal(pos);
    vec3 ref = reflect(rd,nor);

    float outer = march(pos, ref);
    vec3 reflection = texture( iChannel0, ref ).xyz * clamp(outer-2.,0.,.5);
    vec3 ambient = texture( iChannel1, ref ).xyz * clamp(outer-1.,.5,.1);

    vec3 n = normalize(pos);
	vec2 uv = vec2( atan( n.z, n.x ), asin(n.y) );
    
    vec3 col = (texture( iChannel2, uv ).xyz) * clamp(march(pos, normalize(vec3(.1, 1., .2))), .2, 1.);
	return vec4(ambient *col + reflection,1.);
}



vec4 render(in vec3 ro,in vec3 rd){
    float depth=march(ro, rd);
    if(depth>MAX_DIST-EPSILON){
        return texture( iChannel0, rd);
    }
    return aoColor(ro + rd * depth, rd);
    
}

vec3 rayDirection(float fieldOfView,vec2 size,vec2 fragCoord){
    vec2 xy=fragCoord-size/2.;
    float z=size.y/tan(radians(fieldOfView)/2.);
    return normalize(vec3(xy,-z));
}

void mainImage(out vec4 fragColor,in vec2 fragCoord){
    fragColor=render(
        cameraTransform(vec3(0.,0.,5.)),// ray origin
        cameraTransform(rayDirection(60.,iResolution.xy,fragCoord))
    );
}

void mainVR(out vec4 fragColor,in vec2 fragCoord,in vec3 fragRayOri,in vec3 fragRayDir)
{
    fragColor=render(
        fragRayOri+vec3(0.,0.,2.),
    fragRayDir);
}


