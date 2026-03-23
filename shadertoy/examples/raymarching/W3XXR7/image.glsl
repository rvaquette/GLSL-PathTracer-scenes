// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Distance to a capped torus, like https://www.shadertoy.com/view/tl23RK,
// but parametrized differently so it can be used as a joint. Inspired
// by dr2's experiment - https://www.shadertoy.com/view/3l3GD7. Based
// on the 2D join SDF: https://www.shadertoy.com/view/WldGWM
//
// See https://www.shadertoy.com/view/3ttGW7

// List of other 3D SDFs: https://www.shadertoy.com/playlist/43cXRl
//
// and https://iquilezles.org/articles/distfunctions


float dot2( in vec2 v ) { return dot(v,v); }
vec4 sdJoint3DSphere( in vec3 p, in float l, in float a, in float w)
{
    
    // if perfectly straight
    if( abs(a)<0.001 ) return vec4( length(p-vec3(0,clamp(p.y,0.0,l),0))-w, p );
    
    // parameters
    vec2  sc = vec2(sin(a),cos(a));
    float ra = 0.5*l/a;
    
    // recenter
    p.x -= ra;
    
    // reflect
    vec2 q = p.xy - 2.0*sc*max(0.0,dot(sc,p.xy));

    float u = abs(ra)-length(q);
    float d2 = (q.y<0.0) ? dot2( q+vec2(ra,0.0) ) : u*u;
    float s = sign(a);
    return vec4( sqrt(d2+p.z*p.z)-w,
                 (p.y>0.0) ? s*u : s*sign(-p.x)*(q.x+ra),
                 (p.y>0.0) ? atan(s*p.y,-s*p.x)*ra : (s*p.x<0.0)?p.y:l-p.y,
                 p.z );
}

vec4 sdJoint3DFlat( in vec3 p, in float l, in float a, in float w)
{
    
    // if perfectly straight
    if( abs(a)<0.001 )
    {
        vec3 q = p; q.y -= 0.5*l;
        q = abs(q) - vec3(w,l*0.5,w);
        return vec4(min(max(q.x,max(q.y,q.z)),0.0) + length(max(q,0.0)),p);
    }
    
    // parameters
    vec2  sc = vec2(sin(a),cos(a));
    float ra = 0.5*l/a;
    
    // recenter
    p.x -= ra;
    
    // reflect
    vec2 q = p.xy - 2.0*sc*max(0.0,dot(sc,p.xy));

	// distance
    float u = abs(ra)-length(q);
    float d = max(length( vec2(q.x+ra-clamp(q.x+ra,-w,w), q.y) )*sign(-q.y),abs(u) - w);

    // parametrization (optional)
    float s = sign(a);
    float v = ra*atan(s*p.y,-s*p.x);
    u = u*s;
    
    // square profile
    q = vec2(d,abs(p.z)-w);
    
    d = min(max(q.x,q.y),0.0) + length(max(q,0.0));

    
    return vec4( d, u, v, p.z );
}


vec4 map( in vec3 pos )
{
    float an = 1.3*sin(iTime*1.1+3.0);
    float le = 0.8;
    float wi = 0.2;
    
    vec4 d1 = sdJoint3DSphere(pos-vec3(0.0,0.0, 0.4), le, an, wi );
    vec4 d2 = sdJoint3DFlat(  pos-vec3(0.0,0.0,-0.4), le, an, wi );
    
    return (d1.x<d2.x) ? d1 : d2;
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773;
    const float eps = 0.0005;
    return normalize( e.xyy*map( pos + e.xyy*eps ).x + 
					  e.yyx*map( pos + e.yyx*eps ).x + 
					  e.yxy*map( pos + e.yxy*eps ).x + 
					  e.xxx*map( pos + e.xxx*eps ).x );
}

float hash(vec3 p)  // replace this by something better
{
    p  = fract( p*0.3183099+.1 );
	p *= 17.0;
    return fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
}

float noise( in vec3 x )
{
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
    return mix(mix(mix( hash(i+vec3(0,0,0)), 
                        hash(i+vec3(1,0,0)),f.x),
                   mix( hash(i+vec3(0,1,0)), 
                        hash(i+vec3(1,1,0)),f.x),f.y),
               mix(mix( hash(i+vec3(0,0,1)), 
                        hash(i+vec3(1,0,1)),f.x),
                   mix( hash(i+vec3(0,1,1)), 
                        hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}

float fbm( in vec3 p )
{

    p *= 16.0;
	const mat3 m = mat3( 0.00,  0.80,  0.60,
    	                -0.80,  0.36, -0.48,
        	            -0.60, -0.48,  0.64 )*2.0;
    float f = 0.0;
    f += 0.500*noise( p ); p = m*p;
    f += 0.250*noise( p ); p = m*p;
    f += 0.125*noise( p ); p = m*p;
    return f;
}

#ifndef HW_PERFORMANCE
#define AA 1
#else
#define AA 3
#endif

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
     // camera movement	
	float an = 0.6 + 0.1*iTime;
	vec3 ro = vec3( 1.4*sin(an), 0.2, 1.4*cos(an) );
    vec3 ta = vec3( 0.0, 0.2, 0.0 );
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv =          ( cross(uu,ww));
    
    // render
    vec3 tot = vec3(0.0);
    
    #if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (-iResolution.xy + 2.0*(fragCoord+o))/iResolution.y;
        #else    
        vec2 p = (-iResolution.xy + 2.0*fragCoord)/iResolution.y;
        #endif

	    // create view ray
        vec3 rd = normalize( p.x*uu + p.y*vv + 1.8*ww );

        // raymarch
        const float tmax = 5.0;
        float t = 0.0;
        vec3 uvw = vec3(0.0);
        for( int i=0; i<256; i++ )
        {
            vec3 pos = ro + t*rd;
            
            vec4 h = map(pos);
            if( h.x<0.0001 || t>tmax )
            {
                uvw = h.yzw;
                break;
            }
            t += h.x;
        }
        
    
        // shading/lighting	
        vec3 col = vec3(0.0);
        if( t<tmax )
        {
            vec3 pos = ro + t*rd;
            vec3 nor = calcNormal(pos);
            vec3 lig = normalize(vec3(0.8,0.5,0.4));
            float dif = clamp( dot(nor,lig), 0.0, 1.0 );
            float amb = 0.5 + 0.5*dot(nor,vec3(0.0,1.0,0.0));
            col = vec3(0.2,0.3,0.4)*amb + vec3(0.8,0.7,0.5)*dif;
            col *= fbm( uvw*2.0 );
            col *= 1.75;
        }

        // gamma        
        col = sqrt( col );
	    tot += col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

	fragColor = vec4( tot, 1.0 );
}
