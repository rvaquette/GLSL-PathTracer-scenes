//  Original license:
//	Creative Commons CC0 1.0 Universal (CC-0)
//	
//	area lights based on Brian Karis's Siggraph 2013 presentation
//	http://blog.selfshadow.com/publications/s2013-shading-course/
//	
//	kind of pointless for a ray marched scene, but they work with rasterized stuff too.
//	I still need to do attenuation and some noodling. comments too, though everything's
//	in the course notes at the site above for anyone interested.
//	
//	raymarching code and anything else that looks well written courtesy of iq.
//	
//	~bj.2013

// Modified to implement Decima's sphere area lights. 

//#define DISABLE_ALBEDO
//#define DISABLE_NORMALS
//#define DISABLE_ROUGHNESS


float sphereRad;
vec3 spherePos1; // old implementation using representative point
vec3 spherePos2; // old implementation, but using the formulation of Decima based on Karis' implementation
vec3 spherePos3; // new implementation, based on the NoH maximisation technique by Decima.

#define PI 3.1415

float Pow2(float v) { return v * v; }
float Pow4(float v) { return v * v * v * v; }
float rsqrt(float a) { return inversesqrt(a); }
float saturate(float v) { return clamp(v, 0., 1.); }
vec3 saturate(vec3 v) { return clamp(v, 0., 1.); }

vec3 ACESFilm(vec3 x)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x*(a*x+b))/(x*(c*x+d)+e));
}

struct BxDFContext
{
	float NoV;
	float NoL;
	float VoL;
	float NoH;
	float VoH;	
};

float specTrowbridgeReitz_Legacy( float HoN, float a, float aP )
{
	float a2 = a * a;
	float aP2 = aP * aP;
	return ( a2 * aP2 ) / pow( HoN * HoN * ( a2 - 1.0 ) + 1.0, 2.0 );
}

float specTrowbridgeReitz( float a2, float NoH )
{
	float d = ( NoH * a2 - NoH ) * NoH + 1.;
	return a2 / ( PI*d*d );
}

float visSchlickSmithMod( float NoL, float NoV, float r )
{
	float k = pow( r * 0.5 + 0.5, 2.0 ) * 0.5;
	float l = NoL * ( 1.0 - k ) + k;
	float v = NoV * ( 1.0 - k ) + k;
	return 1.0 / ( 4.0 * l * v );
}

float Vis_SmithJointApprox( float a2, float NoV, float NoL )
{
	float a = sqrt(a2);
	float Vis_SmithV = NoL * ( NoV * ( 1. - a ) + a );
	float Vis_SmithL = NoV * ( NoL * ( 1. - a ) + a );
	return 0.5 * 1.0 / ( Vis_SmithV + Vis_SmithL );
}

float fresSchlickSmith( float HoV, float f0 )
{
	return f0 + ( 1.0 - f0 ) * pow( 1.0 - HoV, 5.0 );
}

float New_a2( float a2, float SinAlpha, float VoH )
{
	//return a2 + 0.25 * SinAlpha * (3.0 * sqrt(a2) + SinAlpha) / ( VoH + 0.001 );
	//return a2 + 0.25 * SinAlpha * ( saturate(12. * a2 + 0.125) + SinAlpha ) / ( VoH + 0.001 );
    
    // the following seems more pleasing and energy conserving:
	return a2 + 0.25 * SinAlpha * ( a2 * 2. + 1. + SinAlpha ) / ( VoH + 0.001 );
}

float EnergyNormalization( inout float a2, float VoH, float SinAlpha )
{
	float Sphere_a2 = a2;
	float Energy = 1.;
	if( SinAlpha > 0. )
	{
		Sphere_a2 = New_a2( a2, SinAlpha, VoH );
		Energy = a2 / Sphere_a2;
	}
	return Energy;
}

void SphereMaxNoH( inout BxDFContext Context, float SinAlpha, bool bNewtonIteration )
{
	if( SinAlpha > 0. )
	{
		float CosAlpha = sqrt( 1. - Pow2( SinAlpha ) );
	
		float RoL = 2. * Context.NoL * Context.NoV - Context.VoL;
		if( RoL >= CosAlpha )
		{
			Context.NoH = 1.;
			Context.VoH = abs( Context.NoV );
		}
		else
		{
			float rInvLengthT = SinAlpha * rsqrt( 1. - RoL*RoL );
			float NoTr = rInvLengthT * ( Context.NoV - RoL * Context.NoL );
			float VoTr = rInvLengthT * ( 2. * Context.NoV*Context.NoV - 1. - RoL * Context.VoL );

			if (bNewtonIteration)
			{
				// dot( cross(N,L), V )
				float NxLoV = sqrt( saturate( 1. - Pow2(Context.NoL) - Pow2(Context.NoV) - Pow2(Context.VoL) + 2. * Context.NoL * Context.NoV * Context.VoL ) );

				float NoBr = rInvLengthT * NxLoV;
				float VoBr = rInvLengthT * NxLoV * 2. * Context.NoV;

				float NoLVTr = Context.NoL * CosAlpha + Context.NoV + NoTr;
				float VoLVTr = Context.VoL * CosAlpha + 1.   + VoTr;

				float p = NoBr   * VoLVTr;
				float q = NoLVTr * VoLVTr;
				float s = VoBr   * NoLVTr;

				float xNum = q * ( -0.5 * p + 0.25 * VoBr * NoLVTr );
				float xDenom = p*p + s * (s - 2.*p) + NoLVTr * ( (Context.NoL * CosAlpha + Context.NoV) * Pow2(VoLVTr) + q * (-0.5 * (VoLVTr + Context.VoL * CosAlpha) - 0.5) );
				float TwoX1 = 2. * xNum / ( Pow2(xDenom) + Pow2(xNum) );
				float SinTheta = TwoX1 * xDenom;
				float CosTheta = 1.0 - TwoX1 * xNum;
				NoTr = CosTheta * NoTr + SinTheta * NoBr;
				VoTr = CosTheta * VoTr + SinTheta * VoBr;
			}

			Context.NoL = Context.NoL * CosAlpha + NoTr;
			Context.VoL = Context.VoL * CosAlpha + VoTr;

			float InvLenH = rsqrt( 2. + 2. * Context.VoL );
			Context.NoH = saturate( ( Context.NoL + Context.NoV ) * InvLenH );
			Context.VoH = saturate( InvLenH + InvLenH * Context.VoL );
		}
	}
}

float sphereLight( bool newtonIteration, vec3 sphPos, vec3 pos, vec3 N, vec3 V, float f0, float roughness, float NoV, out float NoL, out float atten )
{
    vec3 lightV         = sphPos - pos;
	vec3 L				= normalize(lightV);
	vec3 H				= normalize( V + L );
	
    float distSq = dot(lightV, lightV);
    float invDist = rsqrt(distSq);
    
    BxDFContext context;
    context.NoL = saturate(dot( N, L ));
    context.NoV = NoV;
    context.NoH = saturate(dot( H, N ));
    context.VoH = saturate(dot( H, V ));
    context.VoL = dot(V, L);
    
    // radius multiplied by the inverse distance for the sin alpha of the sphere light - see Decima presentation
    // Modified based on roughness.
    float SinAlpha = saturate(sphereRad * invDist * (1. - roughness * roughness));
    SphereMaxNoH(context, SinAlpha, newtonIteration);
    
    context.NoV = saturate(abs(context.NoV) + 1e-5);
    
    float a2 = Pow4(roughness);
    float energy = EnergyNormalization(a2, context.NoV, SinAlpha);
	float specD		= specTrowbridgeReitz( a2, context.NoH ) * energy;
	float specF		= fresSchlickSmith( context.VoH, f0 );
	float specV		= Vis_SmithJointApprox(a2, context.NoV, context.NoL );
	
    NoL = context.NoL;
    
    atten = 1.0 / max(1e-4, distSq);
	return specD * specF * specV * context.NoL;
}

float sphereLight_Legacy( vec3 sphPos, vec3 pos, vec3 N, vec3 V, vec3 r, float f0, float roughness, float NoV, out float NoL )
{
	vec3 L				= sphPos - pos;
	vec3 centerToRay	= dot( L, r ) * r - L;
	vec3 closestPoint	= L + centerToRay * clamp( sphereRad / length( centerToRay ), 0.0, 1.0 );	
	vec3 l				= normalize( closestPoint );
	vec3 h				= normalize( V + l );
	
	NoL				= clamp( dot( N, l ), 0.0, 1.0 );
	float HoN		= clamp( dot( h, N ), 0.0, 1.0 );
	float HoV		= dot( h, V );
	
	float distL		= length( L );
	float alpha		= roughness * roughness;
	float alphaPrime	= saturate( sphereRad / ( distL * 2.0 ) + alpha);
	
	float specD		= specTrowbridgeReitz_Legacy( HoN, alpha, alphaPrime );
	float specF		= fresSchlickSmith( HoV, f0 );
	float specV		= visSchlickSmithMod( NoL, NoV, roughness );
	
	return specD * specF * specV * NoL;
}

vec3 areaLights( vec3 pos, vec3 nor, vec3 rd )
{
	float noise		=  texture( iChannel1, pos.xz ).x * 0.5;
	noise			+= texture( iChannel1, pos.xz * 0.5 ).y;
	noise			+= texture( iChannel1, pos.xz * 0.25 ).z * 2.0;
	noise			+= texture( iChannel1, pos.xz * 0.125 ).w * 4.0;
	
	vec3 albedo		= pow( texture( iChannel0, pos.xz ).xyz, vec3( 2.2 ) );
	albedo			= mix( albedo, albedo * 1.3, noise * 0.35 - 1.0 );
	float roughness = 0.7 - clamp( 0.5 - dot( albedo, albedo ), 0.05, 0.95 );
	float f0		= 0.3;
	
	#ifdef DISABLE_ALBEDO
	albedo			= vec3(0.1);
	#endif
	
	#ifdef DISABLE_ROUGHNESS
	roughness		= 0.05;
	#endif
	
	vec3 v			= -normalize( rd );
	float NoV		= saturate( dot( nor, v ));
	vec3 r			= reflect( -v, nor );
	
	float NdotLSphere1;	    
    float NdotLSphere2;
    float NdotLSphere3;
    
    float atten2, atten3;
    float specSph1	= sphereLight_Legacy(spherePos1, pos, nor, v, r, f0, roughness, NoV, NdotLSphere1 );
	float specSph2	= sphereLight(false, spherePos2, pos, nor, v, f0, roughness, NoV, NdotLSphere2, atten2 );
    float specSph3	= sphereLight(true, spherePos3, pos, nor, v, f0, roughness, NoV, NdotLSphere3, atten3 );
    
    
    float lumens = 500.0;
    float luminance = lumens / (4. * 3.1415 * (sphereRad * sphereRad * 10000.));
    
	vec3 color		= luminance * albedo * 0.3183 * saturate( NdotLSphere1 + NdotLSphere2 * atten2 + NdotLSphere3 * atten3) + specSph1 + specSph2 * atten2 + specSph3 * atten3;
    color = ACESFilm(color);
    
	return pow( color, vec3( 1.0 / 2.2 ) );
}

vec3 rotYaw( vec3 v, float a )
{
	float c = cos(a);
	float s = sin(a);
	return v * mat3( c, 0,-s,	0, 1, 0,	s, 0, c );
}

vec3 rotPitch( vec3 v, float a )
{
	float c = cos(a);
	float s = sin(a);
	return v * mat3( 1, 0, 0,	0, c,-s,	0, s, c );
}

void updateLights()
{
	sphereRad		= 0.05;
    spherePos1	= vec3(0.5, sphereRad+abs(sin(iTime)) * 0.5, 0);
    spherePos2	= vec3(0.0, sphereRad+abs(sin(iTime)) * 0.5, 0);
    spherePos3	= vec3(-0.5, sphereRad+abs(sin(iTime)) * 0.5, 0);
}

//--------------------------------------------------------------------------
//	everything below here is based on iq's Raymarching - Primitives shader	
//	https://www.shadertoy.com/view/Xds3zN
//	
//--------------------------------------------------------------------------



// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// A list of usefull distance function to simple primitives, and an example on how to 
// do some interesting boolean operations, repetition and displacement.
//
// More info here: https://iquilezles.org/articles/distfunctions


vec2 map( in vec3 pos )
{
	vec2 sphere1		= vec2( length( pos - spherePos1 ) - sphereRad, 2.0 );
    vec2 sphere2		= vec2( length( pos - spherePos2 ) - sphereRad, 2.0 );
    vec2 sphere3		= vec2( length( pos - spherePos3 ) - sphereRad, 2.0 );

float bump		= 0.0;
	
	#ifndef DISABLE_NORMALS
	bump			= texture( iChannel0, pos.xz * 6.0 ).x * 0.002;
	#endif
	
	vec2 res		= vec2( pos.y + bump, 1.0 );
	res				= ( res.x < sphere1.x ) ? res : sphere1;
    res				= ( res.x < sphere2.x ) ? res : sphere2;
    res				= ( res.x < sphere3.x ) ? res : sphere3;
	
    return res;
}

vec2 castRay( in vec3 ro, in vec3 rd, in float maxd )
{
	float precis = 0.001;
    float h=precis*2.0;
    float t = 0.0;
    float m = -1.0;
    for( int i=0; i<60; i++ )
    {
        if( abs(h)<precis||t>maxd ) continue;//break;
        t += h;
	    vec2 res = map( ro+rd*t );
        h = res.x;
	    m = res.y;
    }

    if( t>maxd ) m=-1.0;
    return vec2( t, m );
}

vec3 calcNormal( in vec3 pos )
{
	vec3 eps = vec3( 0.001, 0.0, 0.0 );
	vec3 nor = vec3(
	    map(pos+eps.xyy).x - map(pos-eps.xyy).x,
	    map(pos+eps.yxy).x - map(pos-eps.yxy).x,
	    map(pos+eps.yyx).x - map(pos-eps.yyx).x );
	return normalize(nor);
}

vec3 render( in vec3 ro, in vec3 rd )
{ 
    vec3 col = vec3(0.0);      
    vec2 res = castRay(ro,rd,20.0);
    
    if( res.y>-0.5 )
    {
		if( res.y == 2.0 )
			return vec3(1);

        vec3 pos = ro + res.x * rd;
        vec3 nor = calcNormal( pos );

		col = areaLights( pos, nor, rd );        
	}
    
	return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 q = fragCoord.xy/iResolution.xy;
    vec2 p = -1.0+2.0*q;
	p.x *= iResolution.x/iResolution.y;

	vec3 ro = vec3(0,0.1,-1.5);
	vec3 ta = vec3(0,0,0);

	vec3 cw = normalize( ta-ro );
	vec3 cp = vec3( 0.0, 1.0, 0.0 );
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv = normalize( cross(cu,cw) );
	vec3 rd = normalize( p.x*cu + p.y*cv + 2.5*cw );
	
	updateLights();
    vec3 col = render( ro, rd );

	fragColor=vec4( col, 1.0 );
}
