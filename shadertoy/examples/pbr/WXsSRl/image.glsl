#define MAX_ITERATIONS 64
#define MIN_DISTANCE  .01

struct Ray {
	vec3 ori;
	vec3 dir;
};
struct Dist {
	float dist;
    int id;
};
struct Hit {
	vec3 p;
    Dist dist;
};

float distSphere(vec3 p, vec3 pos, float radius) {

    return length(pos - p) - radius;
    
}

float distBox(vec3 p, vec3 pos, vec3 r) {
 
    return length(max(abs(pos - p)-r, 0.));
    
}

// Thanks iq! Again..
// Source: https://iquilezles.org/articles/smin
float smin( float a, float b, float k )
{
    float res = exp( -k*a ) + exp( -k*b );
    return -log( res )/k;
}

float distBall(vec3 p, vec3 pos, float radius) {
 
    float sph1 = distSphere(p, pos + vec3(0.,0.,.5), radius + .4);
    float sph2 = distSphere(p, pos + vec3(.3,0.,0.),  radius	   );
    
    return max(-sph2,sph1);
    
}

Dist distToScene(vec3 p) {
 
    float s    = sin(iTime);
    float c    = cos(iTime);
    vec3  bp   = vec3(0.,0.,2.3) + (vec3(c,s,0.)*vec3(.6));
    
    float ball = distBall(p, vec3(0.,0.,2.), .2);
    float box  = distBox (p, bp, vec3(.3));
    
    return Dist(smin(ball, box, 32.), 0);
    
}
    
Hit raymarch(Ray ray) {
 
    vec3 p = ray.ori;
    float t = 0.;
    int id = -1;
    
    for(int i = 0; i < MAX_ITERATIONS; i++) {
     
        Dist d = distToScene(p);
        p += ray.ori + (ray.dir * d.dist);
        
        if(d.dist <= MIN_DISTANCE) {
         
            t = d.dist;
            id = d.id;
            
            break;
            
        }
        
    }
    
    return Hit(p,Dist(t,id));
    
}

vec3 normal(vec3 p) {
 
    const float d = .001;
    
    vec3 left = vec3(p.x - d,p.yz);
    vec3 right = vec3(p.x + d,p.yz);
    vec3 up = vec3(p.x,p.y-d,p.z);
    vec3 down = vec3(p.x,p.y+d,p.z);
    vec3 front = vec3(p.xy,p.z-d);
    vec3 back = vec3(p.xy,p.z+d);
    
    float distLeft = distToScene(left).dist;
    float distRight = distToScene(right).dist;
    float distUp = distToScene(up).dist;
    float distDown = distToScene(down).dist;
    float distFront = distToScene(front).dist;
    float distBack = distToScene(back).dist;
    
    return normalize(vec3(distRight-distLeft,distDown-distUp,distBack-distFront));
    
}

vec4 shade(Ray ray) {
 
    Hit scene = raymarch(ray);
    
    if(scene.dist.id == 0) {

        vec3 n  = normal(scene.p);
        vec3 rd = reflect(ray.dir, n);
        
        return texture(iChannel0, rd);
        
    }
    
    return texture(iChannel0, ray.dir);
    
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = (fragCoord.xy - iResolution.xy / 2.) / iResolution.y;
	
    vec3 ori = vec3(0.,0.,0.);
    vec3 dir = vec3(uv, .6);
    
    fragColor = shade(Ray(ori,dir));
}
