//Ethan Shulman/public_int_i 2016
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

//thanks to iq for the great tutorials, code and information




#define FOV_SCALE 1.3
#define ITERATIONS 128
#define SHADOW_ITERATIONS 24
#define REFLECTION_ITERATIONS 84
#define EPSILON .0008
#define NORMAL_EPSILON .0004
#define VIEW_DISTANCE 2.
#define pi 3.141592



vec3 cameraLocation;
vec2 cameraRotation;


struct material {
    vec3 diffuse,specular,emissive;
    float metallic,roughness;
};
struct light {
    vec3 position, color;
    float size;
};
    
const vec3 ambient = vec3(0.35);


#define nLights 1

#if nLights != 0
light lights[nLights];
#endif    

void initLights() {
    #if nLights != 0
    lights[0] = light(vec3(30.,100.,-10.),
                      vec3(1.,.7,.85),
                      1000.);
	#endif
}


//distance functions from iq's site
float sdTorus( vec3 p, vec2 t ) {
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}
float udBox( vec3 p, vec3 b )
{
  return length(max(abs(p)-b,0.0));
}
float sdBox( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) +
         length(max(d,0.0));
}
float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
    vec3 pa = p - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}
float sdTriPrism( vec3 p, vec2 h )
{
    vec3 q = abs(p);
    return max(q.z-h.y,max(q.x*0.866025+p.y*.5,-p.y)-h.x*0.5);
}
float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}




float ffract(float p) {
    return fract(p)*2.-1.;
}
vec3 ffract(vec3 p) {
    return fract(p)*2.-1.;
}

//random float 0-1 from seed a
float hash(float a) {
    return fract(fract(a*24384.2973)*512.34593+a*128.739623);
}
//random float 0-1 from seed p
float hash3(in vec3 p) {
    return fract(fract(p.x)*128.234+fract(p.y)*124.234+fract(fract(p.z)*128.234)+
                 fract(p.x*128.234)*18.234+fract(p.y*128.234)*18.234+fract(fract(p.z*128.234)*18.234));
}

//random ray in a hemisphere relative to d, uses p as a seed
vec3 randomHemiRay(in vec3 d, in vec3 p) {
    vec3 rand = normalize(ffract(ffract(p)*512.124+ffract(p*16.234)*64.3249+ffract(p*128.234)*12.4345));
    return rand*sign(dot(d,rand));
}

    
vec2 rot(in vec2 v, in float ang) {
    float si = sin(ang);
    float co = cos(ang);
    return v*mat2(si,co,-co,si);
}


vec2 df(in vec3 rp) {
    #define dc(d,i) {float db = d;if(db<dr.x) {dr=vec2(db,i);}}
    
    vec2 dr = vec2(rp.y,0.);//ground
   	dc(udBox(rp-vec3(0.,0.,.2),vec3(2.,.3,.01)),1.);//wall
    
    vec3 slp = vec3(mod(abs(rp.x),.3)-.15,rp.y-.1,rp.z);
    dc(max(abs(rp.x)-.6, length(slp)-.1),2.);//spheres
    
    return dr;
}
vec2 df_hq(in vec3 rp) {
	return df(rp);
}



const vec3 ne = vec3(NORMAL_EPSILON,0.,0.);
vec3 normal2(in vec3 rp) {
    return normalize(vec3(df(rp+ne).x-df(rp-ne).x,
                          df(rp+ne.yxz).x-df(rp-ne.yxz).x,
                          df(rp+ne.yzx).x-df(rp-ne.yzx).x));
}


vec3 normal(in vec3 rp) {
    return normalize(vec3(df_hq(rp+ne).x-df_hq(rp-ne).x,
                          df_hq(rp+ne.yxz).x-df_hq(rp-ne.yxz).x,
                          df_hq(rp+ne.yzx).x-df_hq(rp-ne.yzx).x));
}


material mat(vec3 rp) {
    vec2 dr = df(rp);
    
    if (dr.y < 1.) {
        //ground material
		return material(vec3(.74,.79,.85), //diffuse
                     vec3(.79,.82,.96), //specular
                  	 vec3(0.), //emissive
                     0.,//metallic
                     .64);//roughness
    }
    if (dr.y < 2.) {
        //wall material
		return material(vec3(.74,.79,.85), //diffuse
                     vec3(.92), //specular
                  	 vec3(0.), //emissive
                     .84,//metallic
                     .08);//roughness
    }
	
    float met = pow((rp.x+.6)/1.2,2.);
    vec3 ts = vec3(.99,.32,.22);
    //sphere material
	return material(ts, //diffuse
                    mix(ts,vec3(.92),met), //specular
                  	 vec3(0.), //emissive
                     met,//metallic
                     .5-met*.5);//roughness
    
}



//rp = ray pos
//rd = ray dir
//maxDist = max trace distance
//returns -1 if nothing is hit
float trace(in vec3 rp, inout vec3 rd, float maxDist) {
    
    float d,s = 0.;
    for (int i = 0; i < ITERATIONS; i++) {
        d = df(rp+rd*s).x;
        if (d < EPSILON || s > maxDist) break;
        s += d;
    }
    
    if (d < EPSILON) return s;
    
    return -1.0;
}
float rTrace(in vec3 rp, inout vec3 rd, float maxDist) {
    
    float d,s = 0.;
    for (int i = 0; i < REFLECTION_ITERATIONS; i++) {
        d = df(rp+rd*s).x;
        if (d < EPSILON || s > maxDist) break;
        s += d;        
    }
    
    if (d < EPSILON) return s;
    
    return -1.0;
}

#define AO_ITERATIONS 16
#define AO_PRECISION .005
#define AO_INTENSITY 2.
#define AO_ATTEN 0.9

float ambientOcclusion(in vec3 p, in vec3 norm) {
	float sum = 0.0;
	float atten = 1.0;
	float s = AO_PRECISION;
    
    float d;
    
	for (int i = 1; i < AO_ITERATIONS; i++) {
        d = max(0., df(p+norm*s).x);
        
		sum += (s-d)*atten;		
		s += AO_PRECISION*(1.+float(i)*.25);	
		atten *= AO_ATTEN;
	}
	
	return 1.0-sum*AO_INTENSITY;
}

float softShadowTrace(in vec3 rp, in vec3 rd, in float maxDist, in float penumbraSize, in float penumbraIntensity) {
    vec3 p = rp;
    float sh = 0.;
    float d,s = 0.;
    for (int i = 0; i < SHADOW_ITERATIONS; i++) {
        d = df(rp+rd*s).x;
        sh += max(0., penumbraSize-d)*float(s>penumbraSize*2.);
        s += d;
        if (d < EPSILON || s > maxDist) break;
    }
    
    if (d < EPSILON) return 0.;
    
    return max(0.,1.-sh/penumbraIntensity);
}

vec3 background(in vec3 rd) {
	vec3 c = vec3(0.);
    return c;
}
vec3 background_gi(in vec3 rd) {
    return background(rd);
}

void lighting(in vec3 td, in vec3 sd, in vec3 norm, in vec3 reflDir, in material m, inout vec3 dif, inout vec3 spec) {
    float ao = ambientOcclusion(td,norm);
    dif = ambient*ao;
    spec = vec3(0.);
        
    #if nLights != 0
    for (int i = 0; i < nLights; i++) {
        vec3 lightVec = lights[i].position-td;
        float lightAtten = length(lightVec);
        lightVec = normalize(lightVec);
        float shadow = softShadowTrace(sd, lightVec, lightAtten, .01, .01);
        lightAtten = max(0., 1.-lightAtten/lights[i].size)*shadow;
        
    	dif += max(0., dot(lightVec,norm))*lights[i].color*lightAtten;
        spec += pow(max(0., dot(reflDir, lightVec)), 4.+(1.-m.roughness)*78.)*shadow*lights[i].color;
    }
	#endif
}

//copy of shade without reflection trace
vec3 shadeNoReflection(in vec3 rp, in vec3 rd, in vec3 norm, in material m) {
    vec3 sd = rp-rd*EPSILON*2.;//locateSurface(rp)-rd*EPSILON*2.;
    
    //lighting
    vec3 reflDir = reflect(rd,norm);

    vec3 lightDif,lightSpec;
    lighting(rp,sd,norm,reflDir,m,lightDif,lightSpec);

    return lightDif*m.diffuse +
        	(.5+m.metallic*.5)*lightSpec*m.specular +
        	m.emissive ;
}

vec3 shade(in vec3 rp, in vec3 rd, in vec3 norm, material m) {
    vec3 sd = rp-rd*EPSILON;//locateSurface(rp)-rd*EPSILON*2.;
    
    //lighting
    vec3 dlc = vec3(0.);
    
    vec3 slc = vec3(0.);
    
    vec3 tReflDir = reflect(normalize(mix(rd, 
                                  randomHemiRay(norm,rp*cos(float(iFrame)/1024.+float(iFrame)*1.1923)+rp.yzx+128.1924*cos(float(iFrame)*.1972)),
                                  m.roughness)),
                            norm);
    float rtd = rTrace(sd,tReflDir,VIEW_DISTANCE);
    if (rtd < 0.) {
        slc += background(tReflDir);
    } else {
        vec3 rhp = sd+tReflDir*rtd;
        slc += shadeNoReflection(rhp,tReflDir,normal(rhp),mat(rhp));
    }
    
    vec3 lightDif,lightSpec;
    lighting(rp,sd,norm,reflect(rd,norm),m,lightDif,lightSpec);
    dlc += lightDif;
    slc += lightSpec;
    
    float fres = 1.-max(0., dot(-rd,norm));
    
    return (1.-m.metallic)*dlc*m.diffuse +
        	slc*m.specular*((.5-m.metallic*.5)*fres+m.metallic*(.5+m.metallic*.5)) +
        	m.emissive ;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
  	vec2 uv = (fragCoord.xy - iResolution.xy*.5)/iResolution.x;

    
    initLights();

    cameraRotation = vec2(cos(iTime*.1)+pi/2., 2.);
	cameraLocation = vec3(0., 0., -1.);
    
    vec3 rp = cameraLocation;
    vec3 rd = normalize(vec3(uv*FOV_SCALE,1.));

    rd.yz = rot(rd.yz,cameraRotation.y);
    rd.xz = rot(rd.xz,cameraRotation.x);
    rp.yz = rot(rp.yz,cameraRotation.y);
    rp.xz = rot(rp.xz,cameraRotation.x);    
    
	float itd = trace(rp,rd,VIEW_DISTANCE);

    vec3 hp = rp+itd*rd;
    fragColor = texture(iChannel0, fragCoord/iResolution.xy)*.9+
              vec4(mix(shade(hp,
                      rd,
                      normal(hp),
                      mat(hp)), background(rd), max(clamp(-itd,0.,1.),itd/VIEW_DISTANCE)),
        			1.);
}
