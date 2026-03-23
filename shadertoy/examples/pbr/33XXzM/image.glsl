
#define LIGHT vec3(00,000,8000)
#define IOR 2.407 //index of refraction: 2.407 violet, 2.42 yellow (standard), 2.451 red
#define IOR2 (IOR + .0044)
#define DISPERSION 30.0
#define D DISPERSION
#define BRIGHT 10.0
const float PI = (355./113.);
const vec2 u = vec2(.1,0);

float hash(float n) {return fract(n*fract(n*.133929));}

vec2 rotate(vec2 p, float a) {return vec2 (cos(a)*p.x - sin(a)*p.y, sin(a)*p.x + cos(a)*p.y);}

float line_sdf(vec3 p, vec3 a, vec3 b)
{
    b-=a;
    p-=a;
    float angxy = -atan(b.y,b.x);
    p.xy = rotate(p.xy, angxy);
    b.xy = rotate(b.xy, angxy);
    float angxz = -atan(b.z,b.x);
    p.xz = rotate(p.xz, angxz);
    return length(p.yz);   
}

float dist (vec2 a, vec2 b)
{
    return (a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y);
}

//"pyramid" distance function (a cone with planar sides)
//the pyramid tip is (0,0,0), the pyramid shares its axis with the global x-axis
//p: point being sampled
//ang3: angle of p around the x-axis (0.0 - 1.0, precalculated)

//s: number of sides
//t: tilt angle (radians)
//o: offset of pyramid (offset along x-axis)
//r: rotation around x-axis (0.0 - 1.0)
//h: height (offset along surface normal)
float pyramid(vec3 p, float ang3, float s, float t, float o, float r, float h)
{
    ang3 = round((ang3+r)*s)/s-r;
    ang3 = ang3*PI*2.0;
    p.yz = rotate(p.yz,-ang3);
    p.x += o;
    p.xy = rotate(p.xy,t);
    return p.y-h;
}

float scene(vec3 p)
{
    if(length(p)>400.0)return length(p)-350.0;

    float ang3 = atan(p.z,p.y)/(PI*2.0);  //angle of p around x axis  0.0 - 1.0
    
    //make our diamond cuts out of six pyramids
    float t7 = pyramid(p,ang3,16.0,-PI/2.0,355.,0.0,0.0); //culet
    float t1 = pyramid(p,ang3,16.0,-(PI/2.0-.722),361.4,0.0,0.0); //lower girdle facets
    float t11 = pyramid(p,ang3,8.0,-(PI/2.0-.705),357.2,1.0/32.0,0.0); //pavilion main facets
    
    float t5 = pyramid(p,ang3,16.0,0.0,0.0,-1.0/32.0,290.0); //girdle
    
    float adjust_top = -10.0;
    
    float t2 = pyramid(p,ang3,16.0,PI/2.0-.71,-146.0+adjust_top,0.0,0.0); //upper girdle facets
    float t3 = pyramid(p,ang3,8.0,PI/2.0-.602,-100.85+adjust_top,1.0/32.0,0.0); //kite facets
    float t4 = pyramid(p,ang3,8.0,PI/2.0-.35,-41.85+adjust_top,-1.0/32.0,0.0); //star facets
    
    float t6 = pyramid(p,ang3,16.0,PI/2.0,15.0+adjust_top,0.0,0.0); //top

    return max(max(max(max(max(max(max(t1,t11),t2),t3),t4),t5),t6),t7); 
}

float calc(inout vec3 p, vec3 ps, inout vec3 norm) 
{
    float min_d = 100000.0;
    for(int i = 0; i < 80; i++)
    {
        float dist = scene(p);
        min_d = min(dist, min_d);
        p+=dist*ps;
        if(dist<.1)break;
    }
    if(min_d>.1)return 1000.0;
    norm = normalize(vec3(scene(p+u.xyy)-scene(p-u.xyy), scene(p+u.yxy)-scene(p-u.yxy), scene(p+u.yyx)-scene(p-u.yyx)));
    return min_d;
}

float light(vec3 p, vec3 ps, vec3 l)
{
        float ldist = line_sdf(l,p,p+ps);
        ldist = clamp((1.0-ldist/1000.0),0.0,1.0);
        return ldist*ldist*ldist*float(dot(ps,normalize(l-p))>0.0)*2.0;
}

vec3 cam(vec3 p)
{
    float s = sin(iTime*.1);
    s=mod(iTime*.1,2.0);
    s-=1.0;
    s = (1.0-pow(1.0-abs(s),6.0))*sign(s);
    s*=PI;
    s+=PI;
    p.xz = rotate(p.xz,-PI*.5+sin(iTime*.5)*PI*.25-s);
    p.xy = rotate(p.xy,-PI*.25+cos(iTime*.5)*PI*.15);
    return p;
}
vec3 icam(vec3 p)
{
    float s = sin(iTime*.1);
    s=mod(iTime*.1,2.0);
    s-=1.0;
    s = (1.0-pow(1.0-abs(s),6.0))*sign(s);
    s*=PI;
    s+=PI;
    p.xy = rotate(p.xy,PI*.25-cos(iTime*.5)*PI*.15);
    p.xz = rotate(p.xz,PI*.5-sin(iTime*.5)*PI*.25-iTime*.05+s);
    return p;
}
void mainImage( out vec4 F, in vec2 C )
{
    F = vec4(0);
        
    //lighting
    vec3 l=cam(LIGHT);
  
    
    //start marching
    vec3 p = cam(vec3(0,0,1200));
    vec3 ps = cam(normalize((vec3((C-iResolution.xy*.5)/iResolution.y,-1.2))));
    
    vec3 norm;
    float min_d = calc(p,ps,norm);
    
    if(min_d==1000.0||min_d > .1)
    {
        F=texture(iChannel0,icam(ps));
        return;
    } 

    //refract into diamond
    vec3 p3 = p;
    vec3 ps3 = normalize(refract(ps,norm,1.03/IOR));
    p3+=ps3*2500.0;
    ps3=-ps3;
    vec3 norm3;
    float min_d3 = calc(p3,ps3,norm3);
    
    vec3 p4 = p;
    vec3 ps4 = normalize(refract(ps,norm,1.03/IOR2));
    p4+=ps4*2500.0;
    ps4=-ps4;
    vec3 norm4;
    float min_d4 = calc(p4,ps4,norm4);
    float remaining_light = .8;
    
    //bounce around inside diamond
    for (int i = 0; i < 10; i++)
    {
        vec3 ps_old = ps3;
        ps3 = refract(-ps_old,-norm3,IOR/1.03);
        float r0 = (1.03-IOR)/(1.03+IOR);
        r0*=r0;
        
        vec3 pss_old = ps4;
        ps4 = refract(-pss_old,-norm3,IOR2/1.03);
        float r00 = (1.03-IOR2)/(1.03+IOR2);
        r00*=r00;
        
        if((ps3!=vec3(0))) //check for total internal reflection
        {
            float refract_amount = 1.0-(r0+(1.0-r0)*pow((1.0-dot(-ps_old,norm3)),5.0)); //Fresnel transmittance using Schlick's approximation
                                                                                        //taken directly from here: https://en.wikipedia.org/wiki/Schlick%27s_approximation
            float rrr = texture(iChannel0,icam(normalize(ps3+(ps4-ps3)*D)),4.).b;       //taken directly from here: https://en.wikipedia.org/wiki/Schlick%27s_approximation
            float ggg = texture(iChannel0,icam(normalize(ps3+(ps4-ps3)*D*.5)),4.).b;    //taken directly from here: https://en.wikipedia.org/wiki/Schlick%27s_approximation
            float bbb = texture(iChannel0,icam(normalize(ps3)),4.).b;  
            F.r+=pow(rrr,2.2)*refract_amount*remaining_light;
            F.g+=pow(ggg,2.2)*refract_amount*remaining_light;
            F.b+=pow(bbb,2.2)*refract_amount*remaining_light;
            F.r+=BRIGHT*light(p3,normalize(ps3+(ps4-ps3)*D),l)*refract_amount*remaining_light;
            F.g+=BRIGHT*light(p3,normalize(ps3+(ps4-ps3)*D*.5),l)*refract_amount*remaining_light;
            F.b+=BRIGHT*light(p3,normalize(ps3),l)*refract_amount*remaining_light;
            remaining_light-=refract_amount*remaining_light;
            if(remaining_light<0.1)break;       
        }
        
        ps3=normalize(reflect(-ps_old,-norm3));
        p3+=ps3*2500.0;
        ps3=-ps3;
        
        ps4=normalize(reflect(-pss_old,-norm3));
        p4+=ps4*2500.0;
        ps4=-ps4;
           
        min_d3 = calc(p3,ps3,norm3);
        if(min_d3>.1)break;
           
        min_d4 = calc(p4,ps4,norm4);

    }
    F.r+=pow(texture(iChannel0,icam(normalize(ps3+(ps4-ps3)*D)),4.).r,2.2)*remaining_light;
    F.g+=pow(texture(iChannel0,icam(normalize(ps3+(ps4-ps3)*D*.5)),4.).g,2.2)*remaining_light;
    F.b+=pow(texture(iChannel0,icam(normalize(ps3)),4.).b,2.2)*remaining_light;
    F.r+=BRIGHT*light(p3,normalize(ps3+(ps4-ps3)*D),l)*remaining_light;
    F.g+=BRIGHT*light(p3,normalize(ps3+(ps4-ps3)*D*.5),l)*remaining_light;
    F.b+=BRIGHT*light(p3,normalize(ps3),l)*remaining_light;

    
    //reflection
    vec3 p2 = p;
    vec3 ps2 = normalize(reflect(ps,norm));
    F*=.7; //~70% transmittance
    //reflected texture
    if(min_d <=.1) F+=pow(texture(iChannel0,icam(ps2)),vec4(2.2))*.2; //~30% reflectance
 
    //reflected specular
    float ldist = line_sdf(l,p2,p2+ps2);
    ldist = clamp((1.0-ldist/500.0),0.0,1.0);
    F += BRIGHT*.1*ldist*ldist*ldist*ldist*float(dot(ps2,l-p2)>0.0);
    
    //srgb
    F=pow(F,vec4(1./2.2));
}
