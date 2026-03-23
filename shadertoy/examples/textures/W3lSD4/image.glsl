//Tweet: https://twitter.com/XorDev/status/1518681953872064514
//Twigl: https://t.co/BVcKVKeqMv

//<512 Chars playlist: shadertoy.com/playlist/N3SyzR

//Macro for "length" because it's used 5 times!
#define L length

//FabriceNeyret2 helped save 10 chars.
void mainImage( out vec4 O, vec2 I)
{
    //Raymarch loop
    for(
            //Resolution for scaling
            vec3 r = iResolution, 
            //Ray direction
            d = (r-vec3(I+I,r.y)).yxz/r.y,
            //Starting position (approx. vec3(0,0,3))
            p = 3./r,
            //Rotation vector
            q;

            //Iterate 200 times
            r.z++ < 2e2;

            //March forward using warped sphere SDF (stalk and cap respectively)
            p += d*min(L(vec3(q.yz,.9+.2*q/(q-2.))),
                 L(vec3(q.yz*.5,L(q)-2.5-q+q*q.y*.1))) - d
        )
        
        //Rotate sample point
        q = p,
        q.yz *= mat2(cos(iTime*.2-vec4(0,11,33,0))),
        //Output color based on distance, with spots and back glow.
        O = vec4(1,3,8,0) * max((3.-L(p))/clamp(L(mod(q,.3)*1e2-9.),7.,9.), .1/dot(d,d));
}

///319 char version:
/*
//Macro for "length" because it's used 5 times!
#define L length(vec3

//FabriceNeyret2 helped save 10 chars.
void mainImage( out vec4 O, vec2 I)
{
    //Raymarch loop
    for(
            //Resolution for scaling
            vec3 r = iResolution, 
            //Ray direction
            d = (r-vec3(I+I,r.y)).yxz/r.y,
            //Starting position (approx. vec3(0,0,3))
            p = 3./r,
            //Rotation vector
            q;

            //Iterate 200 times
            r.z++ < 2e2;

            //March forward using warped sphere SDF (stalk and cap respectively)
            p += d*min(L(q.yz,.9+.2*q/(q-2.))),
                 L(q.yz*.5,L(q))-2.5-q+q*q.y*.1))) - d
        )
        
        //Rotate sample point
        q = p,
        q.yz *= mat2(cos(iTime*.2-vec4(0,11,33,0))),
        //Output color based on distance, with spots and back glow.
        O = vec4(1,3,8,0) * max((3.-L(p)))/clamp(L(9)-mod(q,.3)*1e2),7.,9.), .1/dot(d,d));
}
*/

///Original Version [335 chars]
/*
#define L length

void mainImage( out vec4 O, vec2 I)
{
    //Resolution for scaling
    vec3 r = iResolution, 
    //Ray direction
    d=vec3(I+I,0)-r.xyy,
    //Starting position (approx. vec3(0,0,3))
    p=3./r,
    //Rotation vector
    q,
    //Iteration variable for loop
    i=r;
    
    //Divide ray by length and iterate.
    for(d/=r.y; i.z++<2e2;
    //March forward using warped sphere SDF (stalk and cap respectively)
    p += d*min(L(vec3(.9+.2*q.y/(q.y+2.),q.xz)),
    L(vec3(q.y-2.5+L(q)+q.x*q.y*.1,q.xz*.5)))-d )
        //Rotate sample point
        q = p,
        q.xz *= mat2(cos(iTime*.2+vec4(0,11,33,0)));
    
    //Output color based on distance, with spots and back glow.
    O = vec4(1,3,7,0)*max((3.-L(p))/clamp(L(mod(q,.3)/.1-.9),.7,1.)*.1,.1/dot(d,d));
}
*/
