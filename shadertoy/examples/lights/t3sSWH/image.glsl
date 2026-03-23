// ***********************************************************
// Conelight sphere
// by Jochen "Virgill" Feldkötter
//
// Just an early experiment for my 4k intro "the explorer"
// http://www.pouet.net/prod.php?which=75741
// ***********************************************************


vec3 lightpos = vec3(0),schein;
float scatter =0.;


float rnd(vec2 co)
{
    return fract(sin(dot(co.xy ,vec2(12.98,78.23))) * 43758.54);
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

float map(in vec3 p) 
{
		
	float d = p.y-.5*log(1.*pow(length(p.xz),1.)+0.2);
 	d = min(d,length(p)-0.4);
   	schein=(p-lightpos);
    pR(schein.zx,iMouse.x*-0.03+0.8);
    pR(schein.yz,iMouse.y*0.03-.5);
	float s= sdCone(schein,normalize(vec2(1,.9)))/length(schein*schein);
    scatter += max(-s,0.)*0.2;
   
    float f = length(p-lightpos)-0.1; 
    return min(f,d);
}


vec3 calcNormal(vec3 pos)
{
    float eps = 0.0002, d = map(pos);
	return normalize(vec3(map(pos+vec3(eps,0,0))-d,map(pos+vec3(0,eps,0))-d,map(pos+vec3(0,0,eps))-d));
}


float castRay(in vec3 ro, in vec3 rd, in float maxt, in vec2 co) {

    float precis = 0.001;
    float h = precis * 2.0;
    float t = -3.5+rnd(co+0.01*iTime)*7.;
    for(int i = 0; i < 200; i++) 
    {
    	if(abs(h) < precis || t > maxt) break;
        h = map(ro+rd*t);
        t += 0.5*h;
    }
    return t;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) 
{
	// camera setup (iq)   
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;
    float theta = iTime * 3.141592 * 0.20;
    float x = 5.0 * cos(theta*0.5);
    float z = 5.0 * sin(theta*0.5);
    vec3 ro = vec3(0.5*x, 4.0, 5.3);
    
    vec3 ta = vec3(0.0, 0.25, 0.0);
    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(0.0, 1.0, 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = normalize(cross(cu, cw));
    vec3 rd = normalize(p.x * cu + p.y * cv + 7.5 * cw);
   
    lightpos = vec3(1,0.7 + 0.2 * sin(theta*2.0),1); 

    vec3 col = vec3(0);
   	float t= castRay(ro, rd, 15.0,uv);    
	float depth = clamp(t/5.-1.3,0.,1.);
	if (t>15.) t=-1000000.;

	col+=0.3*scatter*vec3(1,0.8,0.6);


	fragColor = vec4(col,0.);
}
