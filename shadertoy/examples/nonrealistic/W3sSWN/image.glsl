#define PI 3.14159
#define PHI 1.618
#define STEPS 50.
#define EPS 0.00001
#define EPSN 0.001
#define EPSOUT 0.008
#define NB_LEAVES 16.


float hash(vec3 p){
	return fract(123456.789 * sin(dot(p, vec3(12.34, 56.78, 91.01))));
}

mat2 rot(float a){
    float c = cos(a);
    float s = sin(a);
	return mat2(c, -s, s, c);
}

float smoothmin(float a, float b, float k){
	float f = clamp(0.5 + 0.5 * (a - b) / k, 0., 1.);
    return mix(a, b, f) - k * f * (1. - f);
}

float smoothmax(float a, float b, float k){
	return -smoothmin(-a, -b, k);
}

float smoothabs(float p, float k){
	return sqrt(p * p + k * k) - k;
}

float noise(vec3 p){
	vec3 f = fract(p);
    f = f * f * (3. - 2. * f);
    vec3 c = floor(p);
  
    return mix(mix(mix(hash(c), hash(c + vec3(1., 0., 0.)), f.x),
               	   mix(hash(c + vec3(0., 1., 0.)), hash(c + vec3(1., 1., 0.)), f.x),
               	   f.y),
               mix(mix(hash(c + vec3(0., 0., 1.)), hash(c + vec3(1., 0., 1.)), f.x),
               	   mix(hash(c + vec3(0., 1., 1.)), hash(c + vec3(1., 1., 1.)), f.x),
               	   f.y),
               f.z);  
}

float fbm(vec3 p){
	vec3 pos = 10. * p;
    float c = 0.5;
    float res = 0.;
    for(int i = 0; i < 4; i++){
        pos.xy = rot(2.) * pos.xy;
        pos = pos * 2. + 2.;
    	res += c * noise(pos);
        c /= 2.;
    }
    return res;
}

float distLeaf(vec3 pos, float angle, float size, out float color){
    float radius = size;
    float c = 0.95 * radius;
    pos.xy = rot(angle) * pos.xy;

    //main part
    pos.y -= 0.02;
    pos.x -= 0.25 * radius;
    pos.z = smoothabs(pos.z, 0.0075);
	pos.y = -abs(pos.y);
    float dist = length(pos - vec3(0., c, -0.05)) - radius;
    
    //color
    float r = length(pos.xz) / radius;
    color = 0.5 + 0.5 * cos(12. * r);
    
    //tip
    pos.x -= 0.175 * radius;
    pos.z += 0.45 * c;
   	return smoothmin(dist, length(pos - vec3(0., c, 0.)) - (radius * 1.05), 0.005);
}

float distScene(in vec3 pos, out int object, out float colorVariation){
    
    pos.yz = rot(0.5 + 0.25 * (0.5 + 0.5 * sin(0.25 * iTime - 0.5 * PI))) * pos.yz;
    pos.xz = rot(0.25 * iTime) * pos.xz;
    pos.y += 0.2;
    
    float f = noise(100. * pos);
    float sf = smoothstep(0.4, 0.5, f);
    
    //floor
    float dist = pos.y;
    object = 0;
    colorVariation = 0.;
    
    //pot
    vec3 p = pos;
    p.y -= 0.155;
    float distPot = length(p) - 0.2;
    distPot = smoothmax(distPot, p.y - 0.097, 0.01);
    distPot = smoothmax(distPot, -(length(p) - 0.18), 0.01);
    distPot = max(distPot, -(p.y + 0.15));
    dist = min(dist, distPot);
    
    if(dist == distPot){
        object = 1;
        float angle = atan(p.z, p.x);
        colorVariation = 0.9 * smoothstep(0.2, 0.35, 0.5 * sin(3. * sin(20. * angle)) + 0.4 * (f - 0.5)) + 0.1 * sf;
    }
    
    //ground
    float distGround = max(p.y - 0.06 + 0.01 * (noise(150. * p) - 0.5), length(p) - 0.18);
    dist = min(dist, distGround);
    
    if(dist == distGround){
        object = 2;
        colorVariation = 0.;
    }
    
	//plant
    p = pos;
    p.y -= 0.2;
    float distPlant = 100.;
    float anim = 0.05 * (0.5 + 0.5 * sin(5. * iTime));
    float leafAngle = 1.2;
    float offset = 0.01;
    float size = 0.2;
    float leafRot = 2. * PI / PHI;
    float leafColor, lc, d;
    
    for(float i = 0.; i < NB_LEAVES; i++){
        p.xz = rot(leafRot) * p.xz;
        leafAngle *= 0.92;
        size *= 1.04;
        offset += 0.002;
        d = distLeaf(p - vec3(offset, 0., 0.), leafAngle + anim, size, lc);
        distPlant = min(distPlant, d); 
        if(d == distPlant) leafColor = lc;
    }
    dist = min(dist, distPlant);
    
    if(dist == distPlant){
        object = 3;
        colorVariation = 0.8 * smoothstep(0.75, 0., leafColor + 0.4 * f) + 0.2 * sf;
    }
               
    return dist;
}

vec3 getNormal(vec3 p){
    float c;
    int o;
	return normalize(vec3(distScene(p + vec3(EPSN, 0., 0.), o, c) - distScene(p - vec3(EPSN, 0., 0.), o, c),
    					  distScene(p + vec3(0., EPSN, 0.), o, c) - distScene(p - vec3(0., EPSN, 0.), o, c),
                          distScene(p + vec3(0., 0., EPSN), o, c) - distScene(p - vec3(0., 0., EPSN), o, c)));
}

vec3 render(vec2 uv){
    
    vec3 inkColor = vec3(0.15, 0.25, 0.4);
    vec3 col = inkColor;
    
    //raymarch
    vec3 eye = vec3(0., 0., 5);
    vec3 ray = normalize(vec3(uv, 1.) - eye);
    int o;
    float dist, step, c, prevDist;
    bool hit = false;
    vec3 pos = eye;
    dist = distScene(pos, o, c);
    float outline = 1.;
    
    for(step = 0.; step < STEPS; step++){
        prevDist = dist;
    	dist = distScene(pos, o, c);
        if(dist > prevDist + EPS && dist < EPSOUT ){
        	outline = min(outline, dist);
        }
        if(abs(dist) < EPS){
        	hit = true;
            break;
        }
    	pos += dist * ray;
    }
    outline /= EPSOUT;
    
    vec3 normal = getNormal(pos);
    float f = fbm(pos);
    
    //shading
    if(hit){
    	vec3 light = vec3(5., 5., 5.);
        light.yz = rot(0.5) * light.yz;
        float shine = 30.;
        
        //paper
        if(o == 0){
        	col = 1. - 0.025 * vec3(smoothstep(0.6, 0.2, fbm(vec3(uv * 6.,1.))));
        }
        //pot
        if(o == 1) col = mix(vec3(0.6, 0.6, 0.85), vec3(1.), 0.8 * c);
        if(o == 2) col = vec3(0.6, 0.6, 0.6);
        //plant
        if(o == 3) {
            col = mix(vec3(0.55, 0.86, 0.75), vec3(0.96, 0.6, 0.85), c);
			shine = 5.;
        }
        
        //diffuse
        vec3 l = normalize(light - pos);
        float diff = dot(normalize(normal + 0.2 * vec3(f - 0.5)), l);
        diff = smoothstep(0.4, 0.5, diff + 0.3 * f);
        if(o != 0) col = mix(col, vec3(0.1, 0.3, 0.75), 0.3 * (1. - diff));
        
        //specular
        vec3 refl = reflect(-l, normal);
        float spec = pow(dot(normalize(eye - pos), refl), shine);
        spec = smoothstep(0.5, 0.6, spec + 0.5 * f);
        col += 0.01 * shine * spec;
        
        //outline
        outline = smoothstep(0.75, 0.95, outline + 0.9 * f);
        col = mix(inkColor, col, outline);
    }  
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.x;
    uv *= 0.8;
    vec3 col = render(uv);
    fragColor = vec4(col,1.0);
}
