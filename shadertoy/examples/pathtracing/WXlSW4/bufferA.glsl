#define MAXDEPTH 4
#define PI 3.14159265359
#define MAXSTEP 400
#define MAXDIST 10.0
#define MINDIST 0.001
const vec3 camPos = vec3(0.0, 0.3, -0.4);
//const vec3 camPos = vec3(0.0, 0.7, -0.06); // up view
const vec3 target = vec3(0.0, 0.2, 0.0);
struct Mat{vec3 c, e;}; //color, emission

// pseudo random numbers////////////////////////////////////////////////
float seed = 0.0;

void initSeed(vec2 uv){
    seed = mod(fract(sin(uv.x*875.87+12.8+iTime)*776.978)*2378.0 + fract(sin(uv.y*594.87+57.75)*689.655)*8938.0
            + fract(sin(iTime*798.43+89.24)*875.365)*5685.0 ,10000.0);
}
void next(){seed=mod(seed*348.12+77.0, 10000.0);}
float random(){
    next();
    return seed/10000.0;
}
/////////////////////////////////////////////////////////////////////////

float sdPerso(vec3 pos){
    float d = 1e5;
    vec3 p;
    //stick
    p = pos - vec3(0.0, 0.2, 0.0);
    d = min(d, sdCylinder(p, vec2(0.01, 0.2))-0.003);
    
    p = pos-vec3(-0.05, 0.36, 0.0);
    d = min(d, sdCappedTorus(p, vec2(0.866025,-0.5), 0.04, 0.01));
    p = pos-vec3(-0.05, 0.36, 0.0);
    d = min(d, sdSphere(p, 0.01));
    p = pos-vec3(-0.11, 0.35, 0.0);
    d = min(d, sdSphere(p, 0.01));
    
    float teta = 1.0;
    p = mat3x3(cos(teta), 0.0, sin(teta),
                  0.0   , 1.0,   0.0,
              -sin(teta), 0.0, cos(teta))*(pos - vec3(-0.11, 0.25, 0.0));
    d = min(d, sdBoundingBox(p, vec3(0.06, 0.08, 0.06), 0.005 )); 
    //body
    
    //d = min(d, sdCappedCone(pos, vec3(0.05, 0.16, 0.0), vec3(0.13, 0.03, 0.0), 0.05, 0.12));
    p = pos;
    p.z = abs(p.z);
    d = min(d, sdCapsule(p, vec3(0.1, 0.0, 0.02), vec3(0.25, 0.1, 0.05), 0.04 ));
    d = min(d, sdCapsule(p, vec3(0.25, 0.1, 0.05), vec3(0.31, 0.01, 0.03), 0.03 ));
    d = min(d, sdCapsule(p, vec3(0.07, 0.15, 0.0), vec3(0.1, 0.0, 0.0), 0.04 ));
    d = min(d, sdCapsule(p, vec3(0.06, 0.1, 0.08), vec3(0.06, 0.18, 0.08), 0.02 ));
    //head
    p = pos-vec3(0.07, 0.25, 0.0);
    d = min(d, sdSphere(p, 0.05));
    p -= vec3(0.0, 0.08, 0.0);
    d = min(d, sdCone(p, vec2(0.1, 0.04), 0.05 ));  
    
    return d;
}


float DE(vec3 pos, out Mat obj){
    float dist = 1e6;
    float t;
    
    //working light
    //t = sdSphere(pos - vec3(-2.0, 2.0, -2.0), 1.8);
    //if (t<dist){dist = t; obj = Mat(vec3(1.0), vec3(1.0));}
    
    //ground
    t = sdPlane(pos);
    if (t<dist){dist = t; obj = Mat(vec3(0.1), vec3(0.0));}
    
    //backbround sphere
    t = -sdSphere(pos, 3.0);
    if (t<dist){dist = t; obj = Mat(vec3(0.0), vec3(0.0));}
    
    //perso
    t = sdPerso(pos);
    if (t<dist){dist = t; obj = Mat(vec3(0.1), vec3(0.0));}
    
    //lights
    t = sdCapsule(pos, vec3(-0.11, 0.22, 0.0), vec3(-0.11, 0.28, 0.0), 0.05);
    if (t<dist){dist = t; obj = Mat(vec3(0.8, 0.0, 0.0), vec3(40.0, 13.0, 13.0));}
    vec3 p = pos - vec3(0.105, 0.25, -0.028);
    p.z = abs(p.z);
    t = sdSphere(p, 0.01);
    if (t<dist){dist = t; obj = Mat(vec3(0.8, 0.0, 0.0), vec3(10.0));}
    
    return dist;
}

float intersect(vec3 ro, vec3 rd, out vec3 normal, out Mat obj){
    normal = rd;
    obj = Mat(vec3(0.9, 0.1, 0.1), vec3(0.0));
    float t = 0.0;
    for(int i = 0; i < MAXSTEP; i++){
        vec3 p = ro + t * rd;
        float delta = DE(p, obj);
        t += delta;
        if(t > MAXDIST)return -1.0;
        if(abs(delta) < MINDIST){//end
            float off=0.001;
            Mat m;
            normal = normalize(vec3(DE(p+vec3(off,0,0), m)-DE(p-vec3(off,0,0), m),
                                    DE(p+vec3(0,off,0), m)-DE(p-vec3(0,off,0), m),
                                    DE(p+vec3(0,0,off), m)-DE(p-vec3(0,0,off), m))); 
            break;
        }
        
    }
    return t;
}

vec3 newDir(vec3 n){
    float teta = random()*2.0*PI;
    float z = random()*2.0-1.0;
    vec3 v = vec3(sqrt(1.0-z*z)*cos(teta), sqrt(1.0-z*z)*sin(teta), z); 
    if (dot(n, v)<0.0);
        return -v;
    return v;
}

vec3 march(vec3 ro, vec3 rd){
	vec3 col = vec3(0.0);
	vec3 mask = vec3(1.0);
	for (int depth = 0; depth < MAXDEPTH; ++depth) {
		Mat obj;
        vec3 n;
        float t = intersect(ro, rd, n, obj);
        if(t<=0.0)break;
        
		ro = ro + t * rd + n * MINDIST * 3.0;
		rd = newDir(n);
        
		col += mask * obj.e;
		mask *= obj.c;
        
        if (dot(mask, mask)<0.00001)break;
		
	}
	return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy*2.0-1.0;
    uv.x *= iResolution.x/iResolution.y;
    initSeed(uv);
    
    vec3 dir0 = normalize(target-camPos);
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, dir0));
    up = cross(dir0, right);
    vec3 rd = normalize(dir0 + right*uv.x + up*uv.y);
        
    vec3 col = march(camPos, rd);
    
    
    
    vec3 last = texture(iChannel0, fragCoord/iResolution.xy).xyz;
    float weight = 1.0/float(iFrame + 1);
    col = col * weight + last * (1.0-weight);
    fragColor = vec4(col,1.0);
}
