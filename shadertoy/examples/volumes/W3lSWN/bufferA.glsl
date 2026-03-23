
// made using dithering thechnique from https://www.shadertoy.com/view/XsdXzN and volumetric raymarching. 
// Inspired by https://www.shadertoy.com/view/ltcXRf and https://www.shadertoy.com/view/MsVXWW

const float dtmax  = 1.0;

// Hacked up version of https://www.shadertoy.com/view/MsVXWW
#define R(p, a) p=cos(a)*p+sin(a)*vec2(p.y, -p.x)

const float nudge      = 0.739513;	                    // size of perpendicular vector
const float normalizer = 1.0 / sqrt(1.0 + nudge*nudge);	// pythagorean theorem on that perpendicular to maintain scale

float SpiralNoiseC(vec3 p){
    float n = 0.0;	// noise amount
    float iter = 1.0;
    for (int i = 0; i < 8; i++){
        n += -abs(sin(p.y*iter) + cos(p.x*iter)) / iter;	// abs for a ridged look
        p.xy += vec2(p.y, -p.x) * nudge;  p.xy *= normalizer;
        p.xz += vec2(p.z, -p.x) * nudge;  p.xz *= normalizer;
        iter *= 1.733733;
    }
    return n;
}

float NebulaNoise(vec3 p){
   float final = p.y + 4.5;
    final += SpiralNoiseC(p.zxy*0.6123 + 100.0)*4.0; // large scale features
    return final;
}

float scene(vec3 p){
    float r       = length(p);
    float NebulaNoise = SpiralNoiseC(2.5*p.zxy*0.6123 + 100.0)*4.0 + 6.0;
    //float noise   = 1.0 + pow(abs(NebulaNoise(p/0.5)*0.5), 2.0) + smoothstep(1.0,2.8,r);
    float noise   = 1.0 + pow(abs(NebulaNoise), 2.0) + smoothstep(1.0,2.8,r);
    float solids  = p.z+1.7; // ground
    float balls = length( vec3(fract(p.xy)-0.5, p.z+0.5 ) )+0.90;
    solids        = min( solids, balls ); // combine scene
    return min(solids,noise);
}

float dist2dens (float dist ){ return max(1.2-dist*dist, 0.0) + 0.002;       }
//float dens2block(float dens ){ return 1.0-pow(0.005, dens/0.05); }
float dens2block(float dt, float dens ){ return 1.0-pow(0.005, dt*dens/0.05); }
//float dens2block(float dt, float dens ){ return -dt*pow(1.5, dens)*0.1; }
float get_dt( float dist ){ return clamp(0.02*dist, 0.002, dtmax); }

// rayMarch integration step to calculate direct ray scattering and absorption (no self shadow, fast preview)
vec3 rayStep( vec3 ro, vec3 rd, vec3 S ){
    float Oc  = S.y;             // occlusion
    float t   = S.z;             // ray length
    vec3  pos     = ro + t*rd;   // pos from ray equation
    float dist    = scene(pos);  // distance from scene objects
    float density = dist2dens(dist);
    float dt      = get_dt(dist);   // ray step length
    float emit    = (300.0*dt*density/dot(pos,pos)); // ammount of light scattered by the density
    float block   = dens2block(dt,density);          // ammount of light absorbed by the density
    float w       = (1.0 - Oc);                      // to simulate exponential decay
    return S + vec3( w*emit, w*block, dt );  // update ray integral
}

// rayMarch integration step calculate light absorbed by density between light source and "ro" 
vec2 rayStepOcc( vec3 ro, vec3 rd, vec2 S ){
    float Oc   = S.x;
    float t    = S.y;
    vec3  pos     = ro + t*rd;
    float dist    = scene(pos);
    float density = dist2dens(dist);
    float dt      = get_dt   (dist);
    float block   = dens2block(dt,density);
    float w       = (1.0 - Oc);
    return S + vec2( w*block, dt );
}

// Self-shadow capable rayMarching
vec3 rayStepFine( vec3 ro, vec3 rd, vec3 S ){
    float Oc   = S.y;
    float t    = S.z;
    vec3  pos      = ro + t*rd;
    float dist     = scene(pos);
    float density  = dist2dens(dist);
    float dt       = get_dt(dist);
      
    // here we integrate occlusion by density between this step on camRay and light 
    vec2 SS        = vec2(0.0);
    float max_dist = length(pos);
    vec3 ld        = -normalize(pos);
    for(int i=0; i<64; i++){ 
		SS = rayStepOcc(pos,ld,SS);
        if( (SS.y>max_dist) ) break;
    }
    float emit = (800.0*dt*density/dot(pos,pos));
    emit *= clamp(1.0-SS.x,0.1,1.0);
    
    float block  = dens2block(dt,density);
    float w      = (1.0 - Oc);
    return S + vec3( w*emit, w*block, dt );
}

// sphere used for bounding volume to save some ray-marching steps
vec2 RaySphereIntersect(vec3 org, vec3 dir, float R){
	float b = dot(dir, org);
	float c = dot(org, org) - R*R;
	float d2 = b*b - c;
	if(d2 < 0.0) return vec2(-1.0,-1.0);
	float d = sqrt(d2);
    return vec2( -b-d, -b+d );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){

    // calculate ray parameters
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 ruv  = (gl_FragCoord.xy-0.5*iResolution.xy)/iResolution.y;  
	vec3 rd  = normalize(vec3(ruv, 1.0));   // ray direction
	vec3 ro  = vec3(0.0, 0.0, -4.0);        // ray origin
	
    // camera rotation
    float pitch   = clamp( -iMouse.y*0.01,-3.0,-1.5);
    float azimuth = iMouse.x*0.01; 
    R(rd.yz, pitch);   R(ro.yz, pitch); 
    R(rd.xy, azimuth); R(ro.xy, azimuth);
    
    
    vec2 tbound = RaySphereIntersect(ro,rd,3.5); // bounding volume
    if( tbound.x>0.0 ){                          // if bounding volume hit, do something
        vec4 frag = texture(iChannel0, uv);      // load result from previous frame
        // note: frag stores (R,G,B,A) channels each contain partial results: 
        // R : last finished light integral
        // G : current partial light integral value
        // B : current partial occlusion integral value 
        // A : current ray length
        if( (frag.w<tbound.x)||(frag.w>tbound.y) ){       // if ray outside scene then restart
            float dither = texture(iChannel1, uv*25.0).r; // radom noise is nicer than ray-steping artifacts
            frag = vec4( frag.g, 0.0, 0.0, tbound.x + dtmax*dither ); // restart
        }
        if(iMouse.z>0.0){ // fast preview (no self shadow)
            for(int i = 0; i < 32; i++){ frag.gba = rayStep( ro, rd, frag.gba );  }
        }else{            // full render with self shadow
            for(int i = 0; i < 4; i++){ frag.gba  = rayStepFine( ro, rd, frag.gba ); }
        }
        fragColor = frag; // store result fo frambuffer texture
	}
}
