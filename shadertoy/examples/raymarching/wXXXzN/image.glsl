// Copyright Inigo Quilez, 2018 - https://iquilezles.org/
// I am the sole copyright owner of this Work.
// You cannot host, display, distribute or share this Work neither
// as it is or altered, here on Shadertoy or anywhere else, in any
// form including physical and digital. You cannot use this Work in any
// commercial or non-commercial product, website or project. You cannot
// sell this Work and you cannot mint an NFTs of it or train a neural
// network with it without permission. I share this Work for educational
// purposes, and you can link to it, through an URL, proper attribution
// and unmodified screenshot, as part of your educational material. If
// these conditions are too restrictive please contact me and we'll
// definitely work it out.

#ifndef HW_PERFORMANCE
#define AA 2
#else
#define AA 3
#endif



// https://iquilezles.org/articles/spherefunctions
vec3 sphNormal( in vec3 pos, in vec4 sph )
{
    return normalize(pos-sph.xyz);
}

// https://iquilezles.org/articles/spherefunctions
float sphIntersect( in vec3 ro, in vec3 rd, in vec4 sph )
{
    vec3 oc = ro - sph.xyz;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - sph.w*sph.w;
    float h = b*b - c;
    if( h<0.0 ) return -1.0;
    return -b - sqrt( h );
}

// https://iquilezles.org/articles/spherefunctions
float sphOcclusion( in vec3 pos, in vec3 nor, in vec4 sph )
{
    vec3  r = sph.xyz - pos;
    float l = length(r);
    float d = dot(nor,r);
    float res = d;

    if( d<sph.w ) res = pow(clamp((d+sph.w)/(2.0*sph.w),0.0,1.0),1.5)*sph.w;
    
    return clamp( res*(sph.w*sph.w)/(l*l*l), 0.0, 1.0 );
}

// https://iquilezles.org/articles/filterableprocedurals
float linesTextureGradBox( in float p, in float ddx, in float ddy, int id )
{
    float N = 12.0;//float( 2 + 7*((id>>1)&3) );

    float w = max(abs(ddx), abs(ddy)) + 0.01;
    float a = p + 0.5*w;                        
    float b = p - 0.5*w;           
    return 1.0 - (floor(a)+min(fract(a)*N,1.0)-
                  floor(b)-min(fract(b)*N,1.0))/(N*w);
}


//-------------------------------------------------------------------------------------------
// scene
//-------------------------------------------------------------------------------------------
vec4 getSphere( int id, float t )
{
    #if AA>1
    vec4 s1 = texelFetch( iChannel1, ivec2(id,0), 0 );        
    vec4 s2 = texelFetch( iChannel1, ivec2(id,1), 0 );
    return mix( s1, s2, t );
    #else
    return texelFetch( iChannel1, ivec2(id,0), 0 );
    #endif
}


float occlusion( in vec3 pos, in vec3 nor, in float mb )
{
	float res = 1.0;
	for( int i=0; i<NUMSPHERES; i++ )
    {
        vec4 sph = getSphere( i, mb );
	    res *= 1.0 - sphOcclusion( pos, nor, sph ); 
    }
    return res;					  
}

vec3 trace( in vec3 ro, in vec3 rd, in vec3 rdx, in vec3 rdy, in vec3 col, float mb )
{
    float tmin = 1e20;
    
    vec4 obj = vec4(0.0);
	float t  = tmin;
	int   id = -1;
	for( int i=0; i<NUMSPHERES; i++ )
	{
		vec4 sph = getSphere(i, mb);
	    float h = sphIntersect( ro, rd, sph ); 
		if( h>0.0 && h<t ) 
		{
			t  = h;
			id = i;
            obj = sph;
		}
	}

    // shade
    if( id!=-1 )
    {
		vec3 pos  = ro + t*rd;
        vec3 nor = sphNormal( pos, obj );
        // manual ray differentials
        vec3 dpdx = t*(rdx*dot(rd,nor)/dot(rdx,nor) - rd);
        vec3 dpdy = t*(rdy*dot(rd,nor)/dot(rdy,nor) - rd);
        //vec3 posx = ro + rdx*t*dot(rd,nor)/dot(rdx,nor);
        //vec3 posy = ro + rdy*t*dot(rd,nor)/dot(rdy,nor);
        
        float occ = occlusion( pos, nor, mb );
        float fre = clamp(1.0+dot(rd,nor),0.0,1.0);

        // color
        col = 0.5 + 0.5*cos(float(id)*0.01 + vec3(5.3,4.3,3.3)  + (((id&7)<3)?vec3(0.5,1.0,1.5):vec3(0.0)) );
        col += fre*0.3 - 0.08;
        col = clamp(col,0.0,1.0);

        // texture coords, with manual derivatives
        vec3 dir = normalize(pos);
        float u    = dot(pos-obj.xyz,dir)*8.0/obj.w;
        float dudx = dot(       dpdx,dir)*8.0/obj.w;
        float dudy = dot(       dpdy,dir)*8.0/obj.w;
        //float ux = dot(posx-obj.xyz,normalize(posx))*8.0/obj.w;
        //float uy = dot(posy-obj.xyz,normalize(posy))*8.0/obj.w;
        //float dudx = u - ux;
        //float dudy = u - uy;

        // texture
        col *= 0.4 + 0.6*linesTextureGradBox( u, abs(dudx), abs(dudy), id );

        // occlusion
        col *= occ;

        
    }

    return col;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 tot = vec3(0.0);
    #if AA>1
    for( int j=ZERO; j<AA; j++ )
    for( int i=ZERO; i<AA; i++ )
    {
        // sub-pixel        
        vec2 of = vec2( float(i), float(j))/float(AA) - 0.5;
        vec2 p = (2.0*(fragCoord+of)-iResolution.xy)/iResolution.y;
        
        uint hh = uint(i+AA*int(fragCoord.x))*17U +
                  uint(j+AA*int(fragCoord.y))*127U +
                  uint(iFrame)*31U;
        float mb = hash1(hh);
    #else
    {
        // pixel        
        vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
        float mb = 0.0;
    #endif        

        // camera
        vec3 ro = vec3(0.0,0.0,4.0);
        vec3 rd = normalize( vec3(p.xy,-2.5) );


        // ray differentials
        vec2 px = p + vec2(2.0,0.0)/iResolution.y;
        vec2 py = p + vec2(0.0,2.0)/iResolution.y;
        vec3 rdx = normalize( vec3(px.xy,-2.5) );
        vec3 rdy = normalize( vec3(py.xy,-2.5) );

        // render
        vec3 col = vec3(0.15,0.22,0.25);
        col = trace( ro, rd, rdx, rdy, col, mb );

        // gama
        col = pow( col, vec3(0.4545) );
        
        tot += col;
    }
    #if AA>1
	tot /= float(AA*AA);
    #endif
    

    // color correct
    tot = 1.1*pow( tot, vec3(1.0,1.3,1.4) );   
        
    // vignetting
    vec2 q = fragCoord / iResolution.xy;
    tot *= 0.2 + 0.8*pow(16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.2);

    // dithering
    //tot += (1.0/255.0)*hash3(uint(fragCoord.x) + 13U*uint(fragCoord.y));

    fragColor = vec4( tot, 1.0 );
}

