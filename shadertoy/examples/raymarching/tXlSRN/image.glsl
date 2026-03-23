////////////////////////////////////////////////////////////////////////////////
//
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0
// Unported License.
//
// "Raytracing Booleans Intervals"
//
// created by Colling Patrik (cyperus) in 2025
//
// - No guarantee that the code will behave correctly in any case!
//
// DESCRIPTION:
// - Raytrace using boolean operators on interval arrays.
//
// REFERENCES:
// by iq
//   https://www.shadertoy.com/view/mlfGRM "Raytracing Booleans"
// by cyperus
//   https://www.shadertoy.com/view/3flSRM "boolean interval array ops"
//
////////////////////////////////////////////////////////////////////////////////

const float
    OBJ_BG =-1., OBJ_CAM = 0., OBJ_A = 1., OBJ_B = 2.;

// global definition empty interval array
int ivd_num = 0;
Interval ivd[iv_len] = Interval[iv_len] (
  iEmpty,
  iEmpty);

void raycast( in Ray r, ivec2 id )
{
    // transform one of the primitives
    float time = iTime;
    float a = 0.5 *time; vec2 ei_a = vec2(cos(a),sin(a));
   	mat4 rot = rotationAxisAngle( normalize(vec3(1.0,1.0,0.0)), ei_a);
	mat4 tra = translate( vec3(0.0,0.0,0.2*sin(time)) );
	mat4 txx = tra * rot;
    mat4 tix = inverse(txx);

    // by transforming the ray with its inverse
    Ray rt = transform( r, tix );
    
    // intersect primitives
    Interval iva0, ivb0;
    int iva_num, ivb_num;
    
    if( id.x==0 )
    {
        iva_num = iSphere(r.o,r.d,0.3, OBJ_A, iva0);
        
        vec4 pl = vec4(normalize(-vec3(0.,0.,1.)),-0.1);
        ivb_num = iPlane(rt.o,rt.d,pl,OBJ_B, ivb0);
        ivb0.n0 = (txx * vec4(ivb0.n0,0.)).xyz;
        ivb0.n1 = (txx * vec4(ivb0.n1,0.)).xyz;        
    }
    else if( id.x==1 )
    {
        iva_num = iSphere(r.o,r.d,0.3,OBJ_A,iva0);
        
        ivb_num = iBox(rt.o,rt.d,vec3(0.4,0.2,0.1),OBJ_B, ivb0);
        ivb0.n0 = (txx * vec4(ivb0.n0,0.)).xyz;
        ivb0.n1 = (txx * vec4(ivb0.n1,0.)).xyz;
    }
    else
    if( id.x==2 )
    {
        iva_num = iBox(r.o,r.d,vec3(0.3,0.2,0.1), OBJ_A, iva0);
        
        ivb_num = iSphere(rt.o,rt.d,0.3,OBJ_B,ivb0);
        ivb0.n0 = (txx * vec4(ivb0.n0,0.)).xyz;
        ivb0.n1 = (txx * vec4(ivb0.n1,0.)).xyz;
    }
    else
    {
        iva_num = iBox(r.o,r.d,vec3(0.4,0.1,0.2),OBJ_A, iva0);
        
        ivb_num = iBox(rt.o,rt.d,vec3(0.3,0.3,0.2),OBJ_B, ivb0);
        ivb0.n0 = (txx * vec4(ivb0.n0,0.)).xyz;
        ivb0.n1 = (txx * vec4(ivb0.n1,0.)).xyz;
    }
    
    // init interval vectors iva ivb using 1 interval of maximal 2 intervals.
    Interval iva[iv_len] = Interval[iv_len] ( iva0, iEmpty );
    Interval ivb[iv_len] = Interval[iv_len] ( ivb0, iEmpty );
    
    // operation between objects
    if( id.y==1 )
        { intersect( iva, iva_num, ivb, ivb_num, ivd, ivd_num); }
    else
        { substract( iva, iva_num, ivb, ivb_num, r.d, ivd, ivd_num); }
    
    #if 0
    // init interval vector ivc with the camera ray range using 1 interval of maximal 2 intervals.
    int ivc_num = 1;
    Interval ivc[iv_len] = Interval[iv_len] (
      Interval( 0.1, vec3(-r.d), OBJ_CAM , +INF, vec3(+1), OBJ_CAM),
      iEmpty );
    // intersection camera ray range with object
    intersect( ivd, ivd_num, ivc, ivc_num , ivd, ivd_num);
    #endif
}

//#define TEST_BOUNDS
//#define COLOR_PLAIN
//#define COLOR_NORMAL
//#define COLOR_BACKGROUND

#define AA 1
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // global normalize mouse coordinates
    vec2 gm = PI*(2.0*iMouse.xy-iResolution.xy)/iResolution.y;
       
    // arcball camera
    vec2 ei_ay = vec2(cos(gm.x),-sin(gm.x)); vec2 ei_ax = vec2(cos(gm.y),sin(gm.y));
    vec3 ro = vec3(0,0,1); ro.zx = cmul(ro.zx, ei_ay); ro.yz = cmul(ro.yz, ei_ax);
    vec3 up = vec3(0,1,0); up.zx = cmul(up.zx, ei_ay); up.yz = cmul(up.yz, ei_ax);   
    vec3 ta = vec3(0,0,0);
    
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,up) );
    vec3 vv = normalize( cross(uu,ww) );
    
    // global normalize pixel coordinates
    vec2 gp = (2.0*fragCoord-iResolution.xy)/iResolution.y;

    // screen tiles
    const vec2 uvgrid = vec2(4,2);
    ivec2 id = ivec2(uvgrid*fragCoord/iResolution.xy);
    vec2 res = iResolution.xy/uvgrid;
    vec2 q   = mod(fragCoord,res);
    
    // render
    vec3 tot = vec3(0.0); 
    #if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (2.0*(q+o)-res.xy)/res.y;
        #else    
        vec2 p = (2.0*q-res.xy)/res.y;
        #endif
        
        // ray direction
        vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );
        
        // background
	    vec3 col = vec3(0.07) * (1.0-0.3*length(gp));
        #ifdef COLOR_BACKGROUND
        col += 0.1*cos( float(5*id.y+id.x)+vec3(0,2,4));
        #endif

        // raycast 
        raycast( Ray(ro,rd), id);
        
        // from back to front
        vec3 ray_col = col;
        
        #ifdef TEST_BOUNDS
        int i = 0, j = 0;
        #else
        for(int i = iv_len-1; i>=0; i--) // loop over intervals
        #endif
        {
        #ifndef TEST_BOUNDS
            for(int j = 2-1; j>=0; j--)  // loop over bounds inside interval
        #endif
            {
                float t, objid;
                vec3 nor;
                if(j == 0)
                {
                    t = ivd[i].t0;
                    nor = ivd[i].n0;
                    objid = ivd[i].m0;
                }
                else
                {
                    t = ivd[i].t1;
                    nor = ivd[i].n1;
                    objid = ivd[i].m1;
                }
                                
                if( t > 0.0 )
                {
                    // surface intersection point
                    vec3  pos = ro + t*rd;
                    //if (isnan(length(nor))) continue;
                    if (dot(nor,rd) > 0.0) nor = -nor;
                    //nor = normalize(nor);

                    // material
                    vec3 mate = vec3(0.); // undefined
                    //if( objid == OBJ_BG )
                    //     vec3 mate = col;
                    if( objid == OBJ_CAM )
                         vec3 mate = vec3(0.8);
                    if( objid == OBJ_A )
                    {
                        #ifdef COLOR_PLAIN
                        mate = vec3(0.0,0.5,0.5);
                        #else
                        vec3 pa = cos(60.0*pos); 
                        mate = vec3(0.1,0.5,0.7) + vec3(0.9,0.5,0.3)*smoothstep(-1.0,1.0,pa.x+pa.y+pa.z);
                        #endif    
                    }
                    if( objid == OBJ_B)
                        mate = vec3(0.9,0.4,0.0);

                    // lighting
                    vec3  lig = normalize(vec3(0.7,0.5,-0.4));
                    vec3  hal = normalize(-rd+lig);
                    //float dif = clamp( dot(nor,lig), 0.0, 1.0 );
                    float dif = clamp( abs(dot(nor,lig)), 0.0, 1.0 );
                    float amb = clamp( 0.6 + 0.6, 0.6, 1.0 );
                    
                    col *= 1.5*mate*amb;
                    col += 0.5 *mate*vec3(1.00,0.90,0.70)*dif;
                    col += 0.2*pow(clamp(dot(hal,nor),0.0,1.0),24.0)*dif;
                }
                #ifdef COLOR_NORMAL
                col = pow(0.5 + 0.5*nor,vec3(2.2));
                #endif
                ray_col = mix(ray_col, col, exp( -0.5 * pow(t, 4.) ) );
            }
        }
        // gamma
        ray_col = rgb2srgb(ray_col);
	
	    tot += ray_col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

    // dither to remove banding in the background
    tot += fract(sin(fragCoord.x*vec3(13,17,11)+fragCoord.y*vec3(1,7,5))*158.391832)/255.0;

    fragColor = vec4( tot, 1.0 );
}

//

