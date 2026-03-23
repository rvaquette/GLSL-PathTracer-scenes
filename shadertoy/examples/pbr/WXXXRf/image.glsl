#define ZERO_TRICK max(0, -iFrame)
#define PI 3.14159265
#define ITERATIONS 96
#define dmin 0.001
#define tmax 20.
#define ROT(a)          mat2(cos(a), sin(a), -sin(a), cos(a))

float sdf4(vec3 p){
	//Torus1
	float primaryRadius1=0.55;
	float secondaryRadius1=0.2;
	return length(vec2(length(p.xz)-primaryRadius1,p.y))-secondaryRadius1;
}

const float SCALE1=0.7;
//Mandelbox1
const float S1=-2.9;
const float R1=0.35;
const int ITR1=10;
const float F1=1.;

vec3 scale_color1(vec3 q){
	vec3 p=q/SCALE1;
	return vec3(1,1,1);
}
float sdf1(vec3 p){
	return sdf4(p);
}
float sdf2(vec3 p){
	vec3 sp1=p/SCALE1;
	vec4 q3=vec4(sp1,1.0);
	vec4 c1=vec4(sp1,1.0);
    float temp = +asin(sin(iTime/2.))*0.15;
	for (int a1=0;a1<ITR1;a1++){
		q3.xyz=F1*(clamp(q3.xyz,-1.0,1.0)*2.0-q3.xyz);
		q3 *=S1/clamp(dot(q3.xyz,q3.xyz),R1+temp,1.0);
		q3 +=c1;
	}
	return (.333*length(q3.xyz)/abs(q3.w))*SCALE1;
}

float sdf3(vec3 p){
	float thickness=0.025;
	float surface=sdf1(p);
	float onioned=abs(surface)-thickness;
	if (onioned>thickness){
		return onioned;
	}
	else if (surface<-thickness){
		return surface;
	}
	else{
		float detail=sdf2(p);
		float dist = max(onioned,detail);
		return min(dist,surface);
	}
}

float box(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float pmin(float a, float b, float k) {
  float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
  return mix( b, a, h ) - k*h*(1.0-h);
}

float pmax(float a, float b, float k) {
  return -pmin(-a, -b, k);
}

vec3 pmin(vec3 a, vec3 b, float k) {
  vec3 h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
  return mix( b, a, h ) - k*h*(1.0-h);
}

vec3 pabs(vec3 a, float k) {
  return -pmin(a, -a, k);
}

float glow  = 0.0;
float glow2  = 0.0;

float map(vec3 p){

   
    
	/*float s=3.;
	p=abs(p);
    vec3  p0 = p *.9;
    
    for (float i=0.; i<4.; i++){
        p = 2.-pabs(p,.12);
        
    	float g=-4.5*clamp(.46*max(1.6/dot(p,p),.7),.0,1.2);
    	p*=g;
    	p+=p0;
        s*=g;
	}
    
	s=abs(s);
	float a=3.8;
	p-=clamp(p,-a,a);
    */
    
    p.xy *= ROT(iTime*0.13);
    p.yz *= ROT(1.57 + iTime*0.14);
    
    glow += 0.001 / max(0.0125,length(p));
    glow2 =  .6 +max(0.005,length(p)) ;
    
	return sdf3(p);//(.333*length(q3.xyz)/abs(q3.w))*0.7;
    
    
	//return length(p)/s;
	
}

float trace(vec3 ro, vec3 rd){
    float d = 0.;
    float t = 0.;

    
    for(int i=0; i<ITERATIONS; i++){
       d = map(ro + rd * t);
       
       if(d < dmin || t > tmax) break;
       
       t += d;
    }
    
    return t;
}

float get_ao(vec3 p, vec3 n)
{
    float r = 0.0, w = 1.0, d;
    for(float i=1.0; i<5.0+1.1; i++)
    {
        d = i/5.0;
        r += w*(d - map(p + n*d));
        w *= 0.5;
    }
    return 1.0-clamp(r,0.0,1.0);
}


vec3 get_normal(vec3 p) {
	const vec2 e = vec2(0.002, 0);
	return normalize(vec3(map(p + e.xyy)-map(p - e.xyy), 
                          map(p + e.yxy)-map(p - e.yxy),	
                          map(p + e.yyx)-map(p - e.yyx)));
}



float softshadow( in vec3 ro, in vec3 rd, float k )
{
    float res = 1.0;
    float t = 0.01;
	float h = 1.0;
    for( int i=0; i<24; i++ )
    {
        h = map(ro + rd*t);
        res = min( res, k*h/t );
        if( res<0.001 )break;
        t += clamp( h, 0.01, 2. );
    }
    return clamp(res,0.,1.0);
}

vec3 get_col(vec3 p){
    p.xy *= ROT(iTime*0.13);
    p.yz *= ROT(1.57 + iTime*0.14);
    
    float d1 = sdf1(p);
    float d2 = sdf2(p);
    if (abs(d1)<abs(d2)){
        
        return vec3(.8, .0, 0.);
    }
    else{
        return vec3(1.0,.7,0.0);
    }
}

mat3 calcLookAtMatrix( in vec3 ro, in vec3 ta, in float roll )
{
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(sin(roll),cos(roll),0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
    return mat3( uu, vv, ww );
}

void doCamera( out vec3 camPos, out vec3 camTar, in float time, in vec2 mouse ){
    float radius 	= 1.2 ;//+ sin(time*.25)*1.6;
    float theta 	= -0.85 + 6.0*mouse.x;// - iTime*0.15;
    float phi 		= .1 +1.57 ;//* mouse.y ;//.5 + sin(iTime*.05) *2.14159 ;//mouse.y - iTime*0.5;
    
    float pos_x = radius * cos(theta) * sin(phi);
    float pos_z = radius * sin(theta) * sin(phi);
    float pos_y = radius * cos(phi);
    
    camPos = vec3(pos_x, pos_y, pos_z);
    camTar = vec3(0.0,0.0,0.0);
}


vec3 postProcess(in vec3 col, in vec2 q)  {
  col=pow(clamp(col,0.0,1.0),vec3(1.0/2.2)); 
  /*col=col*0.6+0.4*col*col*(3.0-2.0*col);  // contrast
  col=mix(col, vec3(dot(col, vec3(0.33))), -0.4);  // satuation*/
  col*=0.5+0.5*pow(29.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),.5);  // vigneting
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    
    vec2 uv = (fragCoord* 2.0 - iResolution.xy) / iResolution.y;
    vec2 q=fragCoord.xy/iResolution.xy; 
    /*vec3 ro = vec3(0,0.,1.75);
    vec3 rd = normalize(vec3(uv,-2.0));*/
    //vec2 p = (-iResolution.xy + 2.0*fragCoord.xy)/iResolution.y;
    vec2 m = iMouse.xy/iResolution.xy;
    
    // camera movement
    vec3 ro, ta;
    doCamera( ro, ta, iTime, m );

    // camera matrix
    mat3 camMat = calcLookAtMatrix( ro, ta, 0.0 );  // 0.0 is the camera roll
    
	// create view ray
	vec3 rd = normalize( camMat * vec3(uv.xy,1.0) ); // 2.0 is the lens length
    //vec3 col = texture(iChannel0, rd).rgb * .3;
    vec3 col = pow(texture(iChannel0, rd).rgb, vec3(2.2));

    float d = trace(ro,rd);
    
    if(d < tmax ){
        vec3 p = ro + rd * d;
       
        
        vec3 n = get_normal(p);      
		vec3 lightPos=vec3(0.,8.,2.);
    	vec3 li = lightPos - p;
		float len = length( li );
		li /= len;
        float amb=0.5+0.5*n.y;
		float dif = clamp(dot(n, li), 0.4, 1.0);
        float ao = get_ao(p,n);
        float shd = softshadow(ro,rd,1.5);
        
        vec3 refl = reflect(rd,n);
        //vec3 rf = texture(iChannel0, refl).xyz;
        vec3 rf = pow(texture(iChannel0, refl).xyz, vec3(2.2));
        
        float spe = max(0.0, pow(clamp(dot(lightPos, reflect(rd, n)), 0.0, 1.0), 8.0)); 
        vec3 c =  get_col(p);
        
        col= c * (dif * amb) * ao ;
        
        col += vec3(spe * .0)  * ao;
        //col += vec3(0.3) * glow  ;
        col += rf * .4;
        
        if(c == vec3(1.0,.7,0.0)){//length(p)< 1.23)
           //col*=  shd;
           col *=  glow2 * ao ;
           
        }
    }
    
    fragColor = vec4(postProcess(col, q),1.0);
}
