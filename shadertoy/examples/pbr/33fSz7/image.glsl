// Cubemap Car Paint
// by Hazel Quantock 2018
// This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. http://creativecommons.org/licenses/by-nc-sa/4.0/

vec3 Paint( vec3 pos, vec3 normal, vec3 ray )
{
    float fresnel = pow( 1.+dot(normal,ray), 5. );

    vec4 paint[] = vec4[](
        // Albedo RGB, Proportion of metallic "flakes" in the paint
        vec4(3.1,3.3,3.5, .0), // matt white
        vec4(.8,.06,.01, 1.), // TVR
        vec4(.63,.49,.56, .5), // mercedes
        vec4(1.7,1.7,1.7, .4), // silver
        vec4(2,.02,.04, .1), // red
        //vec4(1.5,.8,.1, .7), // gold
        vec4(.0,.35,2, .7), // metallic blue
        vec4(.01,.03,.05, 1) // metallic black
    );

    // cycle through the colours
    int idx = int(clamp(floor((2.5-pos.z)*float(paint.length())/5.),0.,float(paint.length()-1)));
    int idx3 = int(floor(iTime/2.));
    int idx2 = idx3%(paint.length()+1);
    idx3 /= paint.length()+1;
    if ( idx2 != paint.length() ) idx = idx2;
    
  	if ( idx3 > 0 && abs(abs(pos.x)-.17) < .12 ) idx = (idx3-1)%paint.length(); // stripes
//idx = 5;
    
    vec3 albedo = paint[idx].rgb;
    float metallicity = paint[idx].a;

    vec3 refl = reflect(ray,normal);
    return mix(
        mix ( 
            LDRtoHDR(textureLod( iChannel0, normal, 6. ).rgb), // diffuse
            LDRtoHDR(textureLod( iChannel0, refl, 4. ).rgb), // metallic
            metallicity
        ) * albedo,
        LDRtoHDR(texture( iChannel1, refl ).rgb), // clearcoat
        mix( .02, 1., fresnel )
    );
}



vec3 WorldToObject( vec3 pos )
{
    pos.xz = pos.xz*(3./5.) + (4./5.)*pos.zx*vec2(1,-1);
    return pos;
}

// smooth abs
float sabs( float a, float r )
{
    return length(vec2(a,r))-r*.2; // offset it a little to fight shrinkage!
}

float smax( float a, float b, float r )
{
    // average of a and b, plus smooth-abs of half the difference between them
    return (a+b)/2. + sabs( (a-b)/2., r );
}

float smin( float a, float b, float r )
{
    return (a+b)/2. - sabs( (a-b)/2., r );
}

float SDF( vec3 pos )
{
    // rotate car to line up more nicely with the background
    pos = WorldToObject( pos );

    pos.x = sabs(pos.x,.1);
    
    return
        smax(
            -pos.y - .5,
            smax(
                smax(
                    //pos.x - 1.,
                    length(pos.xy)-1.,
                    smin(
                        smax(
                        	length( pos - vec3(0,-.3,-1) ) - 1.3,
                        	dot(pos,normalize(vec3(0,1,.05))) - .9,
                            .1
                        ),
                        smin(
                        	dot(pos,normalize(vec3(-.2,1,.07))) - .25,
                        	dot(pos,normalize(vec3(0,1,.08))) - .32,
                            .01
                        ),
	                    .03
                    ),
                    .1
                ),
                max(
                    dot(pos - vec3(0,-.5,2.5),normalize(vec3(.2,1,1))),
                    dot(pos,normalize(vec3(0,-.2,-1))) - 2.5 ),
                .1
            ),
            .05
        );
    
    
/*    return
            (
    	        length(pos)-1.// sphere
	            + dot(normalize(pos),sin(pos.yzx/.1)*.1) // knobbles
            ) * .707 // Keep gradient in [-1,1]. Can probably go higher than this but be on the safe side
        ;*/
}

float epsilon = .0004; // todo: compute from t everywhere it's used (see "size of pixel"\/\/)
int loopCount = 200; // because of the early out this can actually be pretty high without costing much

float Trace( vec3 rayStart, vec3 rayDirection, float far, out int count )
{
    float t = 0.;
    
    float h = 0.;
    float lasth = 0.;
    float bestt = 0.;
    float bestDist = far;
    float sdf = 0.;
    for ( int i=0; i < loopCount; i++ )
    {
        lasth = h;
        sdf = SDF( rayDirection*t+rayStart );
        h = sdf + epsilon*.5;
		t += h;
        if ( sdf < bestDist ) { bestt = t; bestDist = sdf; } // not sure if all these conditionals will compile well, could flip to use step and mix
        count = i;
        if ( h < epsilon || t > far ) break;
    }

    if ( sdf == bestDist )
    {
        // improve precision
		float lastt = t-epsilon;
		float lastsdf = SDF( rayDirection*lastt+rayStart );
		float sdf = SDF( rayDirection*t+rayStart );
        
       	t = mix( lastt, t, (0.-lastsdf)/(sdf-lastsdf) );
    }
    else if ( t < bestt*2. )
    {
        // use the closest sample we had, to avoid sampling back-sides and things
        t = bestt;
		// this can add a fringe, but maybe better than the alternative
    }
    
    return t;
}

void mainImage( out vec4 fragColour, in vec2 fragCoord )
{
//    vec3 camPos = vec3(1.*(iMouse.xy/iResolution.xy-.5),-3);
    vec3 camPos = vec3(0,0,-7);
    vec2 a = vec2(.1,iTime*.3);
    camPos.yz = camPos.yz*cos(a.x)+sin(a.x)*vec2(-1,1)*camPos.zy;
    camPos.zx = camPos.zx*cos(a.y)+sin(a.y)*vec2(-1,1)*camPos.xz;
    
    vec3 camK = normalize(vec3(0)-camPos);
    vec3 camI = normalize(cross(vec3(0,1,0),camK));
    vec3 camJ = cross(camK,camI);
    
    float zoom = 2.;
    vec3 ray = vec3((fragCoord-.5*iResolution.xy)/iResolution.y,zoom);
    ray = ray.x*camI + ray.y*camJ + ray.z*camK;
    ray = normalize(ray);
    
    int count = 0;
    const float far = exp2(6.);
    float t = Trace( camPos, ray, far, count );
    
    fragColour = vec4(vec3(.05),1);
    
    if ( t < far )
    {
    	vec3 pos = camPos + t*ray;

        // size of 1 pixel
		// tan(a) = h / zoom
		// h = .5 / (resolution.y*.5)
        vec2 d = vec2(-1,1) * t / (zoom*iResolution.y);
        vec3 normal = normalize(
            	SDF(pos+d.xxx)*d.xxx +
            	SDF(pos+d.xyy)*d.xyy +
            	SDF(pos+d.yxy)*d.yxy +
            	SDF(pos+d.yyx)*d.yyx
            );
        
	    // rotate car to line up more nicely with the background
        pos = WorldToObject( pos );
        
		//fragColour.rgb = fract( pos );
        //fragColour.rgb = normal*.5+.5;
        fragColour.rgb = Paint( pos, normal, ray );
    }
    else
    {
        fragColour.rgb = LDRtoHDR(texture( iChannel1, ray ).rgb);
    }
    
    // exposure
    fragColour.rgb *= 1.8;
    
    fragColour.rgb = HDRtoLDR( fragColour.rgb );
}

