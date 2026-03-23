const float CAMERA_DIST     = 45.;
const float CLOUD_THICKNESS = 2.;
const vec3  SUN = vec3(-20., 20., 0.); 

float map(vec3 m) {
    return sdGoldBear(m);   
}

// iq made it
float perlin(vec3 v) {
    vec3 p = floor(v);
    vec3 f = fract(v);
	f = f*f*(3.0-2.0*f);
    v = p + f;
    
    return (texture(iChannel0,(v+0.5)/32.0).x - 0.5)*2.;
}

float noise(vec3 pos) {

    float total = 0.;

    float t = iTime * 1.0;

    total += perlin((pos+t) * 0.5)* 0.25;
    total += perlin((pos+t) * 1.) * 0.25;
    total += perlin((pos+t) * 2.) * 0.25;

    return total;
}

bool rayMarching(vec3 ro, vec3 rd, out vec3 m, float margin) {
    
    float marchingDist = 0.0;
    const float maxDist = 100.;

    float matter = 0.;

    for(int i = 0; i<100; i++) {
        
        m = ro + rd * marchingDist;    
        
        float dist = map(m) - margin*1.1;
        
        if(dist<0.01) {
            return true;
        }
    
        marchingDist += dist;
            
        if(marchingDist >= maxDist) {
            break;
        }
    }
    
	return false;    
}

float density(vec3 m) { 
    float dist = map(m);
    float shape = 1. - dist/CLOUD_THICKNESS;  
    return max(0., noise(m)*0.5 + shape * 1.)*0.1;
}

float computeLight(vec3 m) {

    vec3 rd = normalize(SUN-m);   
    
    float matter = 0.;

    float _step = 4.;

    for(int i=0; i<3; i++) {
        m += rd * _step;
        _step *= 1.5;
        matter += density(m);
    }

    return 1. - smoothstep(0., 1.25, matter);
}


vec3 matterMarch(vec3 ro, vec3 rd, vec3 sky) {
    
    float marchingDist = 0.;
    vec3 finalColor = vec3(0.);

    vec3 m;
    int i;
    float matter = 0.;
    float totalAlpha = 0.;

    float _step = 0.1;

    for(i = 0; i<20; i++) {
        
        m = ro + rd * marchingDist;    
        
        float lighting = computeLight(m);
        
        float d = density(m)*3.;
        
        float alpha = (1. - totalAlpha) * d;
        
        totalAlpha += alpha;
        
        finalColor += alpha * vec3(lighting);
        
        if(totalAlpha>=0.99) break;
        
        marchingDist += _step;
        _step += 0.1;
     }
    
	return finalColor += (1. - totalAlpha) * sky;  
}

vec3 sky(vec2 uv, vec3 ro, vec3 rd) {

    const vec3 skycolor = vec3(0.6,0.8,1.0)*0.9;
    const vec3 suncolor = (skycolor + 1.) * 0.5;
    
    float corner = 1. - pow(length(uv), 2.) * 0.25;
    
    vec3 sunDir = normalize(SUN - ro);
    float specular = pow(max(0., dot(rd, sunDir)), 1.5)*0.25;
    
    return mix(skycolor * corner, suncolor, specular);
}

vec3 computeNormal(in vec3 pos) { // iq
	vec3 eps = vec3( 0.1, 0.0, 0.0 );
	vec3 nor = vec3(
	     map(pos+eps.xyy) - map(pos-eps.xyy),
	     map(pos+eps.yxy) - map(pos-eps.yxy),
	     map(pos+eps.yyx) - map(pos-eps.yyx));
	return normalize(nor);
}

vec3 run(vec2 fragCoord) {

    vec3 m;
    vec2 uv;
    vec3 camera = vec3(0, 1., -CAMERA_DIST);
    vec3 ro = camera;
    vec3 rd;

    uv = (fragCoord - iResolution.xy * 0.5) / iResolution.y;
    rd	= normalize(vec3(uv.xy, 0.85));

    vec2 mouse = iMouse.xy/iResolution.xy;

    mat3 transfo = rotY(-mouse.x*4.*3.1415+0.3) * rotX(-mouse.y*4.*3.1415);

    ro = transfo * ro;
    rd = transfo * rd;    

    float lighting = 1.;
    float matter = 0.;

    vec3 sky = sky(uv, ro, rd);

    return rayMarching(ro, rd, m, CLOUD_THICKNESS) ? matterMarch(m, rd, sky) : sky;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord ) {

    fragColor = vec4(run(fragCoord), 1.);
} 

