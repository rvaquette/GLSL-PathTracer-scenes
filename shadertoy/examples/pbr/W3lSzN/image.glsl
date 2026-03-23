// Fork of "Ruby in a crystal" by xjorma. https://shadertoy.com/view/wdVcWm
// 2025-01-22 16:32:21

// Created by David Gallardo - xjorma/2020
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0

#ifndef HW_PERFORMANCE
#else
#define AA
#endif

#define MAX_DIST		60.
#define PI              radians(180.)
#define TAU             radians(360.)
#define MAX_BOUNCES     4

#define GAMMA			0

float map(in vec3 p, out vec3 absorb, out vec3 refcol)
{
    float id  = fDodecahedron(p, 0.8);
    float od = fDodecahedron(p, 0.805);			// Horrible hack, not very proud of this, but to fix that the proper way I have to rethink the render loop to handle inter material transition, also I am not sure how to make it work with ray matching. 
    float oi = fIcosahedron(p, 1.5);

    float d = min(max(oi, -od), id);
    if (d == id)
    {
        absorb = vec3(0, 1, 1) * 10.;
        refcol = vec3(1,0.5,0.5);
    }
    else
    {
        absorb = vec3(0);
        refcol = vec3(1);
    }
    return oi;
}

vec3 getSkyColor(vec3 rd)
{
    vec3 col = vec3(1.);//texture(iChannel0, rd).rgb;
    #if GAMMA
    	col = pow(col, vec3(2.2));
    #endif
    return col;
}

vec3 normal(in vec3 pos)
{
    vec3	_absorb;
    vec3	_refcolor;
    vec2	eps = vec2(0.0001, 0);
	float	d = map(pos, _absorb, _refcolor);
	return normalize(vec3(map(pos + eps.xyy, _absorb, _refcolor) - d, map(pos + eps.yxy, _absorb, _refcolor) - d, map(pos + eps.yyx, _absorb, _refcolor) - d));
}


float rayMarch(in float sgn, in vec3 ro, in vec3 rd, in float offT, out vec3 absorb, out vec3 refcolor)
{
  float t = offT;
  for (int i = 0; i < 16; i++)
  {
    float h = sgn * map(ro + rd*t, absorb, refcolor);
    if (h < 0.0005 || t > MAX_DIST)
        break;
    t += h;
  }
  return t;
}


vec3 Render(in vec3 ro, in vec3 rd, in float cref)
{
    float sgn = 1.;
    vec3  rel = vec3(1.);
    vec3  col = vec3(0);
    float transp = 1.;
    for(int i = 0; i < MAX_BOUNCES; i++)
    {
        vec3	absorb;
        vec3	refcolor;
        float t = rayMarch(sgn, ro, rd, 0.003, absorb,refcolor);
        if( t> MAX_DIST)
        {
            // col += rel * getSkyColor(rd);
            break;
        }
        vec3 rabs = mix(absorb, vec3(0), (sgn + 1.) / 2.);
        vec3 beerlamb = exp(-rabs * t);
        vec3 p = ro + rd * t;
        vec3 n = sgn * normal(p);
        vec3 refl = reflect(rd, n);
        vec3 refr = refract(rd, n, cref);
        //float fresnel = 1.0 - pow(dot(n, -rd), 2.);
        float fresnel = pow(1.0 - abs(dot(n, rd)), 2.6);
        float reflectorFactor = mix (0.2, 1., fresnel);
        float refractionFactor = mix (transp, 0., fresnel);
     
    	col += (1. - refractionFactor) * rel * beerlamb * getSkyColor(refl) * refcolor * reflectorFactor;
    	rel *= refractionFactor * beerlamb;     
        
       	ro = p;     
        if (refr == vec3(0.0))
        {
            rd = refl;
        }
        else
        {
            rd = refr; 
            sgn *= -1.;
            cref = 1.2 / cref;
        }        
    }
    return col;
}


mat3 setCamera( in vec3 ro, in vec3 ta )
{
	vec3 cw = normalize(ta-ro);
	vec3 up = vec3(0, 1, 0);
	vec3 cu = normalize( cross(cw,up) );
	vec3 cv = normalize( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

vec3 vignette(vec3 color, vec2 q, float v)
{
    color *= 0.3 + 0.8 * pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), v);
    return color;
}

vec3 desaturate(in vec3 c, in float a)
{
    float l = dot(c, vec3(1. / 3.));
    return mix(c, vec3(l), a);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec3 tot = vec3(0.0);
        
#ifdef AA
	vec2 rook[4];
    rook[0] = vec2( 1./8., 3./8.);
    rook[1] = vec2( 3./8.,-1./8.);
    rook[2] = vec2(-1./8.,-3./8.);
    rook[3] = vec2(-3./8., 1./8.);
    for( int n=0; n<4; ++n )
    {
        // pixel coordinates
        vec2 o = rook[n];
        vec2 p = (-iResolution.xy + 2.0*(fragCoord+o))/iResolution.y;
#else //AA
        vec2 p = (-iResolution.xy + 2.0*fragCoord)/iResolution.y;
#endif //AA
 
        // camera
        
        float theta	= radians(360.)*(iMouse.x/iResolution.x-0.5) + iTime*.2;
        float phi	= radians(90.)*(iMouse.y/iResolution.y-0.5)-1.;
        vec3 ro = 4.*vec3( sin(phi)*cos(theta),cos(phi),sin(phi)*sin(theta));
        //vec3 ro = vec3(0.0,.2,4.0);
        vec3 ta = vec3( 0 );
        // camera-to-world transformation
        mat3 ca = setCamera( ro, ta );
        //vec3 cd = ca[2];    
        
        vec3 rd =  ca*normalize(vec3(p,.8));        
        
        vec3 col;
        float cbase = .8;
        float cvar = 0.02;
        col.r = Render(ro , rd, cbase - cvar).r;
        col.g = Render(ro , rd, cbase).g;
        col.b = Render(ro , rd, cbase + cvar).b;
        

        tot += col;
            
#ifdef AA
    }
    tot /= 2.;
#endif

    #if GAMMA
    	tot = pow(tot, vec3(1. / 2.2));
    #endif
    
    //66tot = desaturate(tot, -0.2);
    //tot = vignette(tot, fragCoord / iResolution.xy, 1.2);
    
	fragColor = vec4( sqrt(tot), 1.0 );
}

