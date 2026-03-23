// thanks to cornusammois for the rotation :)
// thanks to unbird, for removing the normalize in cubemap

// permutation trick for normal calculus based on classic differential way
#define E (n=n.zxy, d(p+n)-d(p-n))

// sphere with radius 2. and some texture displace, illusion of sphere rotation and shape
#define d(p) (length(p) - 2. + texture(iChannel1, (p+iTime/5.).xy).x*.01)

// other with better shape for 276c :
//#define d(p) (length(p) - 2. + textureLod(iChannel1, (p).xy/5.+iTime/15.,1.).x*.1)

void mainImage( out vec4 f, vec2 g )
{
    vec3 
        n = iResolution,					// screensize, normal variable
    	r = normalize(vec3(g+g-n.xy,n.y)),	// ray direction
    	p = n -= n;							// ray origin at zero, normal reset to zero
    
    p.z -= 3.;								// ray origin at -3 along z axis
    
    //for (int i=99;i-->0;p+=r*d(p));		// webgl2 form of for loop with included sphere tracing iteration
    for(int i=99;i>0;i--)
    	p+=r*d(p);
    
    n.z=.01;								// normal precision
    
    f = texture(iChannel0,vec3(E,E,E));		// cubemap lookup with calculated normal
}


