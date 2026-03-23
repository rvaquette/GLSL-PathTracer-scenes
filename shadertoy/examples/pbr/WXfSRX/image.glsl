#define rot(a)  mat2(cos(a+vec4(0,11,33,0)))                       // rotation
#define rB      length(max(a,0.)) + min(max(a.x,max(a.y,a.z)),0.)  // round cube https://iquilezles.org/articles/distfunctions
#define C(r,l)  max( length(q.xy) - r, a.z-l )                     // cylinder
float h;                                                           // material id

float map( vec3 q) {               // --- scene SDF
    vec3 a = abs(q) - vec3(1,1,0);                                 // glass part
    float t = rB - 1., c,b,j;
    q.xy -= .5,
    c = min(q.x, j=.5*q.x+q.y),
    t = h = max(t, -c );
    
    t = min(t, length(q-vec3(-.2,.5,0)) - 1. );                    // rear part
    
    a = abs(q) - vec3(.5,.5,0),                                    // top & jow arch
    b = rB - 1.1;
    b = max( b, abs(c)-.15 );
    a.x+=.2; b = min( b, max(rB-1., j-.8 ) );                      // rear arch
    q -= vec3(-.2,.1,0);
    b = min(b, C(.7,1.1 ) );                                       // ears
    b = min(b, c = max( abs(length(q.xy)-.45)-.05,a.z-1.2) );
    b = min(b, max(C(.5,1.2), abs(j+.05)-.1));
    q.y-=.08; b = min(b, C(.2,1.2) );
    t = min( t,b );
    t = max( t, -min(j+.15, rB-.95) );
    return t;
}

void M(out vec4 O, vec2 U)       // --- mainImage, oversampled below
{
    float t=9.,_h;                                                 // hit object id 
    vec3  R = iResolution, e = vec3(-1,1,1)*1e-3, N,
          D = normalize(vec3(U+U, -3.5*R.y) - R),                  // ray direction
          p = 9./R, q,                                             // marching point along ray 
          M = iMouse.z > 0. ? iMouse.xyz/R -.5: vec3(20,8,0)/1e2*cos(.3*iTime+vec3(0,11,0)); // auto thumbnail
     
    for (O=vec4(1); O.x > 0. && t > .01; O-=.01)
        q = p,
        q.yz *= rot(.5-6.*M.y),                                    // rotations
        q.xz *= rot(2.-6.*M.x), 
        t = map(q),
        p += .5*t*D;                                               // step forward = dist to obj
    
    _h=h;                                                          // normal
    N = normalize( vec3( map(q+e.xyy)/e.xyy + map(q+e.yxy)/e.yxy + map(q+e.yyx)/e.yyx + map(q+e.xxx)/e.xxx ));
    N.xz *= rot(-2.+6.*M.x);
    N.yz *= rot(-.5+6.*M.y);                                       // back to cam space

    if (t>=.01) return;
  //O = vec4(dot(N,vec3(1,1,1))/1.7);
    O = texture(iChannel0, reflect(D,N));                          // reflection map
    t==_h ? O *= 10.*mix(pow(1.+dot(D,N),5.),1., .03)              // glass: Fresnel ( Schlick approx )
          : O *= 2.*vec4(1,.8,.4,1);                               // metal: gold
}




// === easy adaptive sampling. === https://shadertoyunofficial.wordpress.com/2021/03/09/advanced-tricks/
//                           more: https://www.shadertoy.com/results?query=easy+adaptive+sampling
void mainImage(out vec4 O, vec2 U) {
    M(O,U);
    if ( fwidth(length(O)) > .01 ) {  // difference threshold between neighbor pixels
        vec4 o;
        for (int k=0; k < 9; k+= k==3?2:1 )
          { M(o,U+vec2(k%3-1,k/3-1)/3.); O += o; }
        O /= 9.;
     // O.r++;                        // uncomment to see where the oversampling occurs
    }
}
