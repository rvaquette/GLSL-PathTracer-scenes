//At last! We have achieved the computer graphics of 1989:
//http://www.cs.jhu.edu/~subodh/458/p253-perlin.pdf

//select a fuzz!
//#define FUZZ_TYPE 0		//uniform density, not fuzzy. wuzzy?
//#define FUZZ_TYPE 1		//high freq fuzz
//#define FUZZ_TYPE 2		//lumpy fuzz
//#define FUZZ_TYPE 3		//just the falloff
#define FUZZ_TYPE 4			//furry fur

//#define TEXTURED_LIGHT

//#define POINT_LIGHT	

#define SHADOW_STEPS	4	

//moar steps for main view = too much quality for windoze
#define SHQ
//#define MEDQ
//#define YUCKQ

//get rid of a few math ops for more linear noises
#define CHEAPER_NOISES

//this ray torus code is much nicer/higher quality but for some reason ANGLE does not like it!?!
//#define IQ_RAY_TORUS

#define MAIN_LOD_BIAS 			-10.
#define MAIN_SHADOW_LOD_BIAS	3.
#define GROUND_SHADOW_LOD_BIAS	3.

#define SELF_SHADOW

#define MAIN_TRACE
#define SHADOW_TRACE

void MakeViewRay(out vec3 eye, out vec3 ray, in vec2 fragCoord);
vec4 Sort(vec4 n);
vec4 RayTorus(vec3 ro, vec3 rd, float R, float r);
float noise( in vec3 x, float lod_bias );
vec2 noise2( in vec3 x, float lod_bias );
float sdTorus( vec3 p, vec2 t );
vec3 nTorus( in vec3 pos, vec2 tor );

#define pi 3.1415927



vec3 RotY(vec3 p, float t) {
	float c = cos(t); float s = sin(t);
	return vec3(p.x*c+p.z*s,
				p.y,
				-p.x*s+p.z*c);
}

vec3 RotZ(vec3 p, float t) {
	float c = cos(t); float s = sin(t);
	return vec3(p.x*c+p.y*s,
				-p.x*s+p.y*c,
				p.z);
}

vec4 quat_rotation( float half_angr, vec3 unitVec )
{
    float s, c;
    s = sin( half_angr );
    c = cos( half_angr );
    return vec4( unitVec*s, c );
}

vec3 quat_times_vec(vec4 q, vec3 v)
{
	//http://molecularmusings.wordpress.com/2013/05/24/a-faster-quaternion-vector-multiplication/
	vec3 t = 2. * cross(q.xyz, v);
	return v + q.w * t + cross(q.xyz, t);
}
	
float r=.75;
float R =1.2;//(1.+sin(iTime*0.7)*r*.5);


#define RATE	7.			

float density(vec3 p, float sdf, float lod_bias)
{
	float falloff =	max(-sdf/r,0.);

	float	d = 0.1;
#if FUZZ_TYPE == 1
	//high freq fuzz
	d = noise( p*RATE*8.123, lod_bias);
//	d=sqrt(d);
	d*=d;
#endif	
#if FUZZ_TYPE == 2
	//lumpy fuzz
	d = noise( p*RATE, lod_bias);
	d *= noise( p*(RATE*1.17), lod_bias )-0.3;// * 0.5;
	d *= noise( p*(RATE*4.03), lod_bias )-0.2;// * 0.25;				
	d *= noise( p*(RATE*8.11), lod_bias )-0.1;// * 0.125;
d *= 20.;
d = max(d,0.);
#endif	
#if FUZZ_TYPE == 4
	p += (noise2( p*1.3, lod_bias ).yxy*2.-1.)*0.25; //ought to be a vector wibble but keep it cheap!
//	p -= 0.9*sdf * nTorus(p,vec2(R,r));		//shoot to surface
	p -= 0.9*sdTorus(p,vec2(R,r)) * nTorus(p,vec2(R,r));	//maybe slightly more correct to redo sdf post warping?
	d = noise( p*RATE*6.123, lod_bias);	//high freq hairs
	d*=d;
	d = d < .2 ? 0. : d;				//clip out low alpha gunk to make hairs distinct
	
#endif
#if FUZZ_TYPE > 0
	d *= falloff;
#endif	
	return d * .25;
}

#ifdef POINT_LIGHT
float lightT = iTime;
vec3 lightPos = vec3(0,sin(lightT),cos(lightT))*(R) + vec3(0,R,0);

vec3 TexturedLight(vec3 p)
{
	vec3 d = lightPos-p;
	float falloff = 1.0 / (0.1*dot(d,d)+1.);
#ifdef TEXTURED_LIGHT	
	d = RotZ( d, iTime*1.7654321 );
	vec3 c = texture(iChannel3,d).xyz;
	return c*falloff ;
#else	
	return vec3(falloff);
#endif
}
#else
vec3 offAxis = normalize(vec3(-.25,1,1));
vec3 lightDir = normalize(vec3(1,2,1)); //RotY( offAxis, iTime );

vec3 TexturedLight(vec3 p)
{
#ifdef TEXTURED_LIGHT	
	mat3 m = mat3(  
		vec3(0.970142,-0.000000,0.242536),
		vec3(0.168880,0.717741,-0.675521),
		vec3(-0.174078,0.696311,0.696311));
	p = RotY(p,-iTime);
	p = m * p;
	
	vec3 L = texture(iChannel2,p.xz*.1-vec2(0.25,0.5),3.).xyz;
	L+=sin(iTime)*0.4+0.5;
	L+=0.25;
	L*=L;
	L*=L;
	return L;
#else
	return vec3(1);
#endif	
}
#endif //not POINT_LIGHT

vec3 Trans(float thick)
{
	vec3 beer = vec3(0.793,3.955,0.453);;
	vec3 transmittance = exp(-beer*thick);
	return transmittance;
}

vec3 difColor = vec3(0.875,0.974,0.000);
vec3 transColor = vec3(0.205,0.000,0.405);


float shmarch(vec3 p, vec3 L, float start, float end, float lod_bias)
{
	float d = 0.;
	
	float dt = (end-start)*(1./float(SHADOW_STEPS));
	
	p += L * (start + 0.5* dt);
	
	for (int i=0; i<SHADOW_STEPS; i++)
	{
		float sdf = sdTorus( p, vec2(R, r) );
	
		d += density(p,sdf,lod_bias) * dt;
		p += L * dt;
	}
							
	return d*100.;						
}

float shamarch(vec3 P, vec3 L, vec4 interval, float lod_bias)
{
	float d = 0.;
	
	float start = interval.x;
	float end	= interval.y;
	float dt = (end-start)*(1./float(SHADOW_STEPS));
	
	vec3 p = P + L * (start + 0.5* dt);
	
	for (int i=0; i<(SHADOW_STEPS*2); i++)
	{
		if (i==SHADOW_STEPS)
		{
			start = interval.z;
			end	= interval.w;
			dt = (end-start)*(1./float(SHADOW_STEPS));
	
			p = P + L * (start + 0.5* dt);
	
		}
		
		if (start<1e5)
		{
			float sdf = sdTorus( p, vec2(R, r) );
		
			d += density(p,sdf,lod_bias) * dt;
			p += L * dt;
		}
	}
							
	return d*100.;						
}


vec4 BlendUnder(vec4 accum,vec4 col)
{
	col = clamp(col,vec4(0),vec4(1));	
	col.rgb *= col.a;
	accum += col*(1.0 - accum.a);	
	return accum;
}

vec4 march(vec4 accum, vec3 viewP, vec3 viewD, vec4 roots)
{
	//exponential stepping
#ifdef SHQ
	#define STEPS	128	
	float slices = 512.;
#endif	
#ifdef MEDQ
	#define STEPS	64	
	float slices = 256.;
#endif	
#ifdef YUCKQ	
	#define STEPS	32	
	float slices = 128.;
#endif
	
	float Far = 10.;
	
	float tt = roots.x;
	float end = roots.y;
	float sliceStart = log2(tt)*(slices/log2(Far));
	float sliceEnd = log2(end)*(slices/log2(Far));
			
	float last_tt = tt;
	
	if (tt< 1e5)
	for (int i=0; i<STEPS; i++)
	{							
		sliceStart += 1.;
		float sliceI = sliceStart;// + float(i);	//advance an exponential step
		tt = exp2(sliceI*(log2(Far)/slices));	//back to linear

		vec3 p = viewP+tt*viewD;
						
		float sdf = sdTorus( p, vec2(R, r) );

		float dens = density(p, sdf, MAIN_LOD_BIAS);
		
		dens *= (tt-last_tt)*100.;	//density ought to be proportional to integral over step length?
		last_tt = tt;

#ifdef POINT_LIGHT		
		vec3 lightDir = lightPos-p;
		float light_dist = length(lightDir);
		lightDir = normalize(lightDir);
#endif
		
		//amount of stuff light had to go through to get here
		vec4 shadow_roots = RayTorus(p, lightDir, R, r);
#ifdef SELF_SHADOW		

//		float thick = shamarch(p, lightDir, vec4(0.,shadow_roots.xyz), MAIN_SHADOW_LOD_BIAS);
			
#ifdef POINT_LIGHT		
		shadow_roots[0]=min(shadow_roots[0],light_dist);
#endif
		//well this must be an exit cos we started inside
		float thick = shmarch(p, lightDir, 0., shadow_roots[0], MAIN_SHADOW_LOD_BIAS);

		if (shadow_roots[1]<1e5)	//and there might be another segment
		{
#ifdef POINT_LIGHT		
			shadow_roots.yz=min(shadow_roots.yz,vec2(light_dist));
#endif			
			thick += shmarch(p, lightDir, shadow_roots[1], shadow_roots[2], MAIN_SHADOW_LOD_BIAS);
		}
#else
		float thick = 0.2;//shadow_roots.x+shadow_roots.z-shadow_roots.y;
#endif
		
	#if 1	
		//surface-like reflection term falling off towards interior of torus
		vec3 n = nTorus( p, vec2(R, r) );
		float dif = max(dot(n,lightDir),0.);
		float reflective = 1.-(abs(sdf)/r);
		reflective*=reflective;
		reflective*=reflective;
		dif *= reflective;
	#endif	
				
		vec3 transmittance = Trans(thick);
			
		float shadow = max(1.-thick,0.);		
	//	vec3 c = vec3(transColor+dif*difColor) * shadow;
	//	vec3 c = vec3(transColor) * shadow;
		
		vec3 c = vec3(transColor+dif*difColor) * transmittance;

	#if 0	
		float fy = -(R+r);				//the floor
		float h = p.y - fy;				//distance to floor
		h = max(1. - (h/(1.*(R+r))),0.);		//fall off
		c += vec3(max(-n.y*.05,0.0))*h;	//downwards normals get some floor bounce
	#endif
		
	//	vec3 c = vec3(transColor) * transmittance;
		
		c *= TexturedLight(p);
		
		accum = BlendUnder(accum,vec4(c,dens));

		if (accum.a > 0.99) break;
		
		//if (sliceI > sliceEnd) break; //out of exponential steps	
		if (sliceI > sliceEnd)
		{
			//go to next interval
			tt = roots.y;
			end = roots.w;
			sliceStart = log2(tt)*(slices/log2(Far));
			sliceEnd = log2(end)*(slices/log2(Far));	
			last_tt = tt;
		
			if (tt> 1e5) break;
	
		}
	}	
	
	return accum;
}

float Q(float a, float b, float c)
{
	float d = b*b-4.0*a*c;
	if (d < 0.0) return -1.0;
	d=sqrt(d);	
	float oo2a = 0.5/a;
	return (-b-d)*oo2a; //min((-b-d)*oo2a,(-b+d)*oo2a);
}

float RaySphere(vec3 P, vec3 V, vec3 A, float r)
{
	return Q(dot(V,V),2.0*(dot(P,V)-(dot(A,V))),dot(A,A)+dot(P,P)-r*r-(2.0*(dot(A,P))));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec3 viewP, viewD;
	MakeViewRay(viewP, viewD, fragCoord);

	//ground plane
	float floor_height = -(R+r);
	float floor_intersect_t = (-viewP.y + floor_height) / (viewD.y);
	vec3 p = viewP+viewD*floor_intersect_t;
	vec3 c = texture(iChannel0,p.xz*0.1).xyz;
	c = pow(c,vec3(2.2));

#ifdef SHADOW_TRACE

#ifdef POINT_LIGHT	
	vec3 lightDir = lightPos-p;
	float lightDist = length(lightDir);
	lightDir = normalize(lightDir);
#endif	
	//darken by shadow ray through torus
	vec4 shadow_roots = RayTorus(p, lightDir, R, r);
	float thick=0.;
	
	for (int i=0; i<4; i+=2)
	{
		if (shadow_roots[i]<1e5)
		{
			vec2 sh = vec2(shadow_roots[i],shadow_roots[i+1]);
#ifdef POINT_LIGHT			
			sh = min(sh,vec2(lightDist));
#endif				
			thick += shmarch(p, lightDir, sh.x, sh.y, GROUND_SHADOW_LOD_BIAS);
		}
	}

	c *= max(lightDir.y,0.);
	
	c *= clamp(Trans(thick)+.2,0.,1.)*TexturedLight(p);
	
	float sdf = sdTorus( p, vec2(R, r) );
	c *= min(abs(sdf)+.1,1.);					//block light/blob shadow
	c += transColor * max(1.-abs(sdf),0.)*.2;	//bounce from floor
#endif	

#ifdef MAIN_TRACE		
	//ray marching segments of torus intersections
	vec4 roots = RayTorus(viewP, viewD, R, r);

	vec4 accum = vec4(0);
	
#ifdef POINT_LIGHT
	float lightT = RaySphere(viewP, viewD, lightPos, 0.1);
	if (lightT >0.)
	{
		if (lightT < roots[0])
		{ 
			accum = vec4( TexturedLight(viewP + lightT * viewD), 1.0); 
		}
	}	
#endif

		
//	accum = march(accum,viewP, viewD, roots[0],roots[1]);
//	accum = march(accum,viewP, viewD, roots[2],roots[3]);
	accum = march(accum,viewP, viewD, roots);
	
	//comp over background 
	c = BlendUnder(accum,vec4(c,1.)).xyz;
//	c = mix(c,accum.xyz,accum.w);
#endif
	
	c=pow(c,vec3(1./2.2));
	fragColor = vec4(c,1.0);
}

void MakeViewRay(out vec3 eye, out vec3 ray, in vec2 fragCoord)
{
	vec2 ooR = 1./iResolution.xy;
    vec2 q = fragCoord.xy * ooR;
    vec2 p =  2.*q -1.;
    p.x *= iResolution.x * ooR.y;
	
    vec3 lookAt = vec3(0.);
	eye = vec3(2.5,3.,-2.5) * 1.5; 	
	eye = RotY(eye,iTime*.4);
	
    // camera frame
    vec3 fo = normalize(lookAt-eye);
    vec3 ri = normalize(vec3(fo.z, 0., -fo.x ));
    vec3 up = normalize(cross(fo,ri));
     
    float fov = .25;
	
    ray = normalize(fo + fov*p.x*ri + fov*p.y*up);
	
	//jitter to de-band
	eye += ray * texture(iChannel1,p).x;
}

vec4 Sort( vec4 a)
{
	vec4 m = vec4(min(a.xz,a.yw), max(a.xz,a.yw) );
	vec4 r = vec4(min(m.xz,m.yw), max(m.xz,m.yw) ); 
	a = vec4( r.x, min(r.y,r.z),  max(r.y,r.z), r.w );
	return a;
}

#define SMALL_ENOUGH 1e-4


#ifdef IQ_RAY_TORUS
//thanks iq!
//https://www.shadertoy.com/view/4sBGDy
//slight modifications to return ALL intersections
vec4 RayTorus( in vec3 ro, in vec3 rd, float torus_R, float torus_r )
{
	float Ra2 = torus_R*torus_R;
	float ra2 = torus_r*torus_r;
	
	float m = dot(ro,ro);
	float n = dot(ro,rd);
		
	float k = (m - ra2 - Ra2)*0.5;
	float a = n;
	float b = n*n + Ra2*rd.z*rd.z + k;
	float c = k*n + Ra2*ro.z*rd.z;
	float d = k*k + Ra2*ro.z*ro.z - Ra2*ra2;
	
    //----------------------------------

	float p = -3.0*a*a     + 2.0*b;
	float q =  2.0*a*a*a   - 2.0*a*b   + 2.0*c;
	float r = -3.0*a*a*a*a + 4.0*a*a*b - 8.0*a*c + 4.0*d;
	p /= 3.0;
	r /= 3.0;
	float Q = p*p + r;
	float R = 3.0*r*p - p*p*p - q*q;
	
	float h = R*R - Q*Q*Q;
	float z = 0.0;
	if( h < 0.0 )
	{
		float sQ = sqrt(Q);
		z = 2.0*sQ*cos( acos(R/(sQ*Q)) *(1.0/3.0) );
	}
	else
	{
		float sQ = pow( sqrt(h) + abs(R), 1.0/3.0 );
		z = sign(R)*abs( sQ + Q/sQ );

	}
	
	z = p - z;
	
    //----------------------------------
	
	float d1 = z   - 3.0*p;
	float d2 = z*z - 3.0*r;

	if( abs(d1)<SMALL_ENOUGH ) //this tolerance appears to be deeply annoying to tune. :(
	{
		if( d2<0.0 ) return vec4(1e20);
		d2 = sqrt(d2);
	}
	else
	{
		if( d1<0.0 ) return vec4(1e20);
		d1 = sqrt( d1*0.5 );
		d2 = q/d1;
	}
	
    //----------------------------------
	
	vec4 result = vec4(1e20);

	h = d1*d1 - z + d2;
	if( h>0.0 )
	{
		h = sqrt(h);
		float t1 = -d1 - h - a;
		float t2 = -d1 + h - a;
		
		result[0]=t1;
		result[1]=t2;
	}

	h = d1*d1 - z - d2;
	if( h>0.0 )
	{
		h = sqrt(h);
		float t1 = d1 - h - a;
		float t2 = d1 + h - a;
		result[2]=t1;
		result[3]=t2;
	}
	
	for (int i=0; i<4; i++) if (result[i]<0.) result[i]=1e20;
	result = Sort(result);
	return result;
}

#else //not IQ_RAY_TORUS buggy solver from POV Ray but keeps ANGLE happy?!!


//https://github.com/POV-Ray/povray/blob/3.7-stable/source/backend/math/polysolv.cpp#L808

#define DBL float 

float solve_cubic(float a1, float a2, float a3)
{
	DBL Q, R, Q3, R2, sQ, d, an, theta;
	DBL A2;
	
	A2 = a1 * a1;

	Q = (A2 - 3.0 * a2) * (1./ 9.0);

	/* Modified to save some multiplications and to avoid a floating point
	   exception that occured with DJGPP and full optimization. [DB 8/94] */

	R = (a1 * (A2 - 4.5 * a2) + 13.5 * a3) * (1./ 27.0);

	Q3 = Q * Q * Q;

	R2 = R * R;

	d = Q3 - R2;

	an = a1 * (1./3.);

	if (d >= 0.0)
	{
		/* Three real roots. */ //but only use the first!

		d = R * inversesqrt(Q3);

		theta = acos(d) * (1. / 3.0);

		sQ = -2.0 * sqrt(Q);

		return sQ * cos(theta) - an;
	}

	sQ = pow(sqrt(R2 - Q3) + abs(R), 1.0 / 3.0);

	DBL t = sQ + Q / sQ;
	
	t = R < 0. ? t : -t;
	return t - an;
}

void quartic_descartes(float c1, float c2, float c3, float c4, inout vec4 results)
{
	DBL c12, z, p, q, q1, q2, r, d1, d2;
	
	/* Compute the cubic resolvant */

	c12 = c1 * c1;
	p =  -6. * c12 + 4.*c2;
	q =  c12 * c1 - c1 * c2 + c3;
	q *= 8.;
	r = -3. * c12 * c12 + c12 *4.*c2 - c1 * 8.*c3 + 4.*c4;
				
	float cubic_a1 = -0.5 * p;
	float cubic_a2 = -r;
	float cubic_a3 = 0.5 * r * p - 0.125 * q * q;

	z = solve_cubic(cubic_a1, cubic_a2, cubic_a3);

	d1 = 2.0 * z - p;

	if (d1 < 0.0)
	{
		if (d1 > -SMALL_ENOUGH)
		{
			d1 = 0.0;
		}
		else
		{
			return;
		}
	}

	if (d1 < SMALL_ENOUGH)
	{
		d2 = z * z - r;

		if (d2 < 0.0)
		{
			return;
		}

		d2 = sqrt(d2);
	}
	else
	{
		d1 = sqrt(d1);
		d2 = 0.5 * q * (1./ d1);
	}

	/* Set up useful values for the quadratic factors */

	q1 = d1 * d1;
	q2 = -c1;

	/* Solve the first quadratic */

	p = q1 - 4.0 * (z - d2);

	if (p > 0.)
	{
		p = sqrt(p);
		results[0] = -0.5 * (d1 + p) + q2;
		results[1] = -0.5 * (d1 - p) + q2;
	}

	/* Solve the second quadratic */

	p = q1 - 4.0 * (z + d2);

	if (p > 0.)
	{
		p = sqrt(p);
		results[2] = 0.5 * (d1 + p) + q2;
		results[3] = 0.5 * (d1 - p) + q2;
	}
}

//watch out, unstable on "small" R, r, certain planes and slight breezes!! :(
//http://research.microsoft.com/en-us/um/people/awf/graphics/ray-torus.html
vec4 RayTorus(vec3 A, vec3 B, float R, float r)
{
	//B assumed normalized
	
	float aa = dot(A,A);
	float ab = dot(A,B);
		
	// Set up quartic in t:
	//
	//  4     3     2
	// t + A t + B t + C t + D = 0
	//
	
	float R2 = R*R;
	float K = aa - r*r - R2;
	K *= 0.5;
	float qA = ab;
	float qB = ab*ab + K + R2*B.z*B.z;
	float qC = K*ab + R2*A.z*B.z;
	float qD = K*K +  R2*(A.z*A.z - r*r);

    // 4t^3 + 3At^2 + 2Bt + C
	//12t^2 + 6At   + 2B
	
	vec4 roots = vec4(1e10);
	quartic_descartes(qA,qB,qC,qD, roots);
	
	for (int i=0; i<4; i++)
	{
		if (roots[i] < 0.) 
			roots[i] = 1e10;	
	}
	
	roots = Sort(roots);
		
	return roots;
}

#endif

//iq
float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xy)-t.x,p.z);
  return length(q)-t.y;
}
// df(x)/dx
vec3 nTorus( in vec3 pos, vec2 tor )
{
	return normalize( pos*(dot(pos,pos)- tor.y*tor.y - tor.x*tor.x*vec3(1.0,1.0,-1.0)));
}

float noise( in vec3 x, float lod_bias )
{	
    vec3 p = floor(x);
    vec3 f = fract(x);
#ifndef CHEAPER_NOISES	
	f = f*f*(3.0-2.0*f);	//not terribly noticeable for higher freq noises anyway
#endif
	
	vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
#ifdef CHEAPER_NOISES	
	vec2 rg = texture( iChannel1, uv*(1./256.0), lod_bias ).yx;
#else	
	vec2 rg = texture( iChannel1, (uv+ 0.5)/256.0, lod_bias ).yx;
#endif	
	return mix( rg.x, rg.y, f.z );
}

vec2 noise2( in vec3 x, float lod_bias )
{
    vec3 p = floor(x);
    vec3 f = fract(x);
#ifndef CHEAPER_NOISES	
	f = f*f*(3.0-2.0*f);
#endif
	
	vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
#ifdef CHEAPER_NOISES	
	vec4 rg = texture( iChannel1, uv*(1./256.0), lod_bias ).yxwz;
#else
	vec4 rg = texture( iChannel1, (uv+ 0.5)/256.0, lod_bias ).yxwz;
#endif	
	return mix( rg.xz, rg.yw, f.z );
}

/*
$num = hex $ARGV[0];
print "vec3(";
for ($i=0; $i<3; $i++)
{
	$c = ($num >> ((2-$i)*8))&255;
	$f = $c / 255.0;
	$f = $f ** 2.2;
	$f = -log($f)/$thickness;
	printf( "%.3f", $f);  
	if ($i < 2)
	{
	print ",";
	}
}
print ");";
*/

