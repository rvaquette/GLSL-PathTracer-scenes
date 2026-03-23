// RayMarching lookup angles,plane,sphere map and rand 
// in below src code taken from iq shadertoy demo
 

//2 point light source demo  c = c0+1/(kc+kl*d+kq*d*d)
// and quadratic cube
#define PT   1
#define SPH  2
#define PLN  3
#define CUBE 4


vec3  ptLight1Col = vec3(0.764,0.413,0.294);//cyan
vec3  ptLight2Col = vec3(0.464,0.213,0.294);//magento

vec2 randState;

float rand()
{
   randState.x = fract(sin(dot(randState.xy, vec2(12.9898, 78.233))) * 43758.5453);
   randState.y = fract(sin(dot(randState.xy, vec2(12.9898, 78.233))) * 43758.5453);        
    
   return randState.x;
}

struct PointLight
{
    vec3 pos;
    vec3 col;
};

struct Ob
{
    float t;
    vec3  c;
    PointLight  ptL; 
    int prop;
};

float mapPlane(vec3 p)
{
    float r = 0.5;
    float l = p.y + (r);
    return l;
}
float quadEq(float t)
{
    return 1.2*t*t+1.0*t+0.01;
}
float mapCube(vec3 p, float r)
{
    //p=p-vec3(0.5,0.47,2.0);
    p = p - vec3(0.5,0.47,0.5);
    vec3 t = vec3(quadEq(p.x),quadEq(p.y),quadEq(p.z));
    return length(t)-r;
}
Ob map(vec3 p)
{
    Ob o; 
    float tme = iTime*0.5;
    vec3 pt2 = vec3(0.9*cos(tme),-0.3*sin(tme/2.0),0.8*sin(tme));
    vec3 pt1 = vec3(0.9*sin(tme),-0.3*sin(tme/2.0),0.8*cos(tme));
    
    vec3 mov = p-pt1;
    vec3 mov1 =  p-pt2;
    float sph= length(p-vec3(0.0,0.0,0.1))-0.25;
    float p1 = length(mov)-0.02;
    float p2 =  length(mov1)-0.02;
    float pl = mapPlane(p);
    float cb = mapCube(p,0.25);
    o.t = min(min(sph,pl),cb);
    o.t = min(min(p1,p2),o.t);
    
    o.ptL.pos = min(mov,mov1);
    vec3 A= ptLight2Col*(1.0-p2)+ptLight1Col*p2;
    vec3 B= ptLight1Col*(1.0-p1)+ptLight2Col*p1;
    
    o.ptL.col = mix(A,B,0.5);
    
    /*vec3 mn = normalize(o.ptL.pos);
    vec3 dirPt = normalize(pt2 - pt1);
    float an = dot(mn, dirPt);
    vec3 A= ptLight1Col;
    vec3 B= ptLight2Col;
    o.ptL.col = mix(A,B,an);*/
    
    if (sph < pl && sph < cb)
    {
        o.c = vec3(0.1,0.1,0.2);
        o.prop = SPH;
    
    }
    else if (pl < sph && pl < cb)
    {
        o.c = vec3(0.1,0.2,0.1);
        o.prop = PLN;
    }
    else if (cb < sph && cb < pl)
    {
        o.c = vec3(0.8,0.2,0.5);
        o.prop = CUBE;
    }
    if (p1 < sph && p1 < pl && p1 < cb && p1 < p2)
    {
        o.c = ptLight1Col;
        o.prop = PT;
        
    }
    else if (p2 < sph && p2 < pl  && p2 < cb &&  p2 < p1)
    {
        o.c = ptLight2Col;
        o.prop = PT;
    }
    return o;
}

vec3 calcNormal(vec3 pos)
{
    vec2 e = vec2(0.0001,0.0);
    return normalize(vec3(map(pos+e.xyy).t-map(pos-e.xyy).t,
                          map(pos+e.yxy).t-map(pos-e.yxy).t,
                          map(pos+e.yyx).t-map(pos-e.yyx).t));
}


void castRay(in vec3 ro, vec3 rd,inout Ob o)
{
    float t =0.0;
    for(int i=0;i<100;i++)
    {
        vec3 pos = ro+t*rd;
        o = map(pos);
        float h = o.t;
        if (h<0.001)
            break;
        t+=h;
        if (t>20.0) break;
    }
    if (t>20.0) t=-0.1;
    o.t =t;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    
    randState = (2.0*fragCoord-iResolution.xy)/iResolution.y ;
    /*float an = 10.0*iMouse.x/iResolution.x;
    vec3 ro = vec3(2.0*cos(an),-0.3,2.0*sin(an));*/
    
    float an = 10.0*fract(0.05*iTime)+iMouse.x/iResolution.x;
    float up = cos(iTime)-an;
    vec3 ro = vec3(2.0*cos(an),-0.3*up,2.0*sin(an));
    
    vec3 ta = vec3(0.0,0.0,0.0);
    
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww,vec3(0.0,1.0,0.0)));
    vec3 vv = normalize(cross(uu,ww));
                        
    vec3 rd = normalize(p.x*uu+p.y*vv+1.5*ww);
    
    vec3 col = vec3(0.0)-0.7*rd.y;
    
    Ob o;
    castRay(ro, rd,o);
    if (o.t > 0.0) 
    {
        vec3 pos = ro + o.t*rd;
        
        vec3 nor = calcNormal(pos);
        
        vec3 mate = o.c;
        nor +=normalize(vec3(0.0,0.0,0.5));
        vec3 sun_light = (o.ptL.pos);
        float sun_shad = step(o.t,0.0);
        
        float kc=0.3, kl=0.3,kq = 0.03;
        
        float d = length(sun_light);
        vec3 oc = o.ptL.col;

        if (o.prop == SPH)
        {
            
            mate  += ((1.0/(kc+kl*d+kq*d*d))*oc) ;
            float sun_dif = clamp(dot(nor,sun_light),0.0,1.0);
            float sky_dif = clamp(0.5+0.5*dot(nor,vec3(0.0,1.0,0.0)),0.0,1.0);
            float boun_dif = clamp(0.9-0.5*dot(nor,vec3(0.0,-1.0,0.0)),0.0,1.0);
            
            col = mate*sun_dif*sun_shad;   
            col +=mate*sky_dif;    
            col +=mate*boun_dif; 
        }
        else if (o.prop == PLN)
        {
            mate = ((1.0/(kc+kl*d+kq*d*d))*oc) ;
            float sun_dif = clamp(dot(nor,sun_light),0.0,1.0);
            float sky_dif = clamp(0.5+0.5*dot(nor,vec3(0.0,1.0,0.0)),0.0,1.0);
            float boun_dif = clamp(0.5+0.5*dot(nor,vec3(0.0,-1.0,0.0)),0.0,1.0);

            col = mate*sun_dif*sun_shad;   
            col +=mate*sky_dif;    
            col +=mate*boun_dif;
        }
        else if (o.prop == CUBE)
        {
            mate = ((1.0/(kc+kl*d+kq*d*d))*oc) ;
            float sun_dif = clamp(dot(nor,sun_light),0.0,1.0);
            float sky_dif = clamp(0.5+0.5*dot(nor,vec3(0.0,1.0,0.0)),0.0,1.0);
            float boun_dif = clamp(0.5+0.5*dot(nor,vec3(0.0,-1.0,0.0)),0.0,1.0);

            col = mate*sun_dif*sun_shad;   
            col +=mate*sky_dif;    
            col +=mate*boun_dif;
        }
        else if (o.prop == PT)
        {
        
            vec3 sun_light = o.ptL.pos;
            
            float d = length(sun_light-pos);
            
            mate += ((1.0/(kc+kl*d+kq*d*d))*o.ptL.col);
            col = mate;
        }
    }
    
    fragColor = vec4(col,1.0);
}
