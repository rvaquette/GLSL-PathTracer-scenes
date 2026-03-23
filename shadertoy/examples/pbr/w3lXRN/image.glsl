//////////////////////////////////////////////////////////////////////
//
// "heavy metal squiggle orb" by mattz
// License https://creativecommons.org/licenses/by/4.0/
//
// An infinite variety of ornate spherical Truchet tilings.
//
// Demo automatically cycles through a "playlist" of 16 polyhedra.
//
// Use the mouse to rotate the orb or click in the lower-left corner
// to restore automatic rotation.
//
// KEYS: (these break out of demo mode):
//
//   A/S prev/next in playlist
//
//   Q/W change symmetry (tetrahedral/octahedral/icosahedral)
//   E/R modify vertex location (7 possibilities)
//   T/Y modify random seed (2^16 possibilities!)
//
// To return to demo mode, press D (won't do anything if paused)
//
// See https://en.wikipedia.org/wiki/Uniform_polyhedron#Summary_tables
// for all possibile polyhedra (note this shader doesn't implement the
// snub variants).
//
// Background: I had a lot of fun writing "rainbow noodle orbs" 
// (https://www.shadertoy.com/view/tsVBDW) but the woven Truchet
// tiling in that shader was too slow to raymarch. 
//
// By using only single spherical arcs (torus segments) for each
// connection within a tile, and by exploiting symmetries within
// each tile, I was able to make things fast enough to raymarch 
// while still maintaining some really interesting diversity of
// appearances.
//
//////////////////////////////////////////////////////////////////////

const float PI = 3.141592653589793;
const float TOL = 1e-5;

ivec3 setup = ivec3(3, 0, 0);
float decorate = 1.0;

#define MAX_POLYGON 10

//////////////////////////////////////////////////////////////////////
// inverse linear interpolation

float unlerp(float lo, float hi, float x) {
    return clamp((x-lo)/(hi-lo), 0.0, 1.0);
}

//////////////////////////////////////////////////////////////////////
// from https://www.shadertoy.com/view/XlGcRh 
// original by Dave Hoskins

vec3 hashwithoutsine31(float p) {
   vec3 p3 = fract(vec3(p,p,p) * vec3(.1031, .1030, .0973));
   p3 += dot(p3, p3.yzx+33.33);
   return fract((p3.xxy+p3.yzz)*p3.zyx);
}

//////////////////////////////////////////////////////////////////////
// rotate about arbitrary axis/angle

mat3 rotate(in vec3 k, in float t) {
    
    if (abs(t) < TOL) {
        return mat3(1.);
    }
    
    mat3 K = mat3(0, k.z, -k.y,
                  -k.z, 0, k.x,
                  k.y, -k.x, 0);
                  
    return mat3(1.) + (mat3(sin(t)) + (1. - cos(t))*K)*K;

}

//////////////////////////////////////////////////////////////////////
// Wythoff construction

ivec3 construct(in vec3 p, 
                out vec3 face_normal, out vec3 v_cur,
                out float poly_edge_dist, out int nface) {
               
    //////////////////////////////////////////////////
    // step 1: construct Schwarz triangle with vertex
    // at (0, 0, 1) and along x=0 and y=0 planes
    //
    // this is a (P, Q, R) triangle with Q=3 and R=2
    //
    //  Q=3 *--__
    //      |    ^^--__
    /// R=2 *----------* P = 3, 4, or 5
    //
    // where p=3, 4, or 5
   
    int degree = setup.x;
    int spoint = setup.y;
    
    float tp = PI / float(degree);
    float cp = cos(tp);
    
    vec3 lp = vec3(1, 0, 0);
    vec3 lq = vec3(0, 1, 0);

    vec3 lr = vec3(-0.5, -cp, sqrt(0.75 - cp*cp));
    
    mat3 tri_edges = mat3(lp, lq, lr);
    
    vec3 vP = normalize(cross(lq, lr));
    vec3 vR = vec3(0, 0, 1);
    vec3 vQ = normalize(cross(lr, lp));
    
    mat3 tri_verts = mat3(vP, vQ, vec3(0, 0, 1));

    //////////////////////////////////////////////////
    // step 2: mirror point into triangle
    
    mat3 M = mat3(1.);
    
    mat3 Mr = mat3(1.) - 2.*outerProduct(lr, lr);

    for (int i=0; i<5; ++i) {
        if (p.x < 0.) { p.x = -p.x; M[0] = -M[0]; }
        if (p.y < 0.) { p.y = -p.y; M[1] = -M[1]; }
        if (dot(p, lr) < 0.) { p = reflect(p, lr); M *= Mr; }
    }
        
    //////////////////////////////////////////////////
    // step 3: polygon construction

    ivec3 npoly = ivec3(0);
    
    vec3 poly_vertex;
        
    if (spoint == 0) {
        // polygon vertex at degree-P triangle vertex, so all triangles
        poly_vertex = vP;
        npoly = ivec3(0, 1, 0);
    } else if (spoint == 1) {
        // polygon vertex at degree-3 triangle vertex, so all P-gons
        poly_vertex = vQ;
        npoly = ivec3(1, 0, 0);
    } else if (spoint == 2) {
        // polygon vertex at degree-2 triangle vertex, so alternation of triangles and P-gons
        poly_vertex = vR;
        npoly = ivec3(1, 1, 0);
    } else if (spoint == 3) {
        // polygon vertex at bisector of degree-P angle, alternation of 2P and triangles
        poly_vertex = normalize(cross(lp, lq - lr));
        npoly = ivec3(2, 1, 0);
    } else if (spoint == 4) {
        // polygon vertex at bisector of degree-Q angle, alternation of hexagons and P-gons
        poly_vertex = normalize(cross(lq, lr - lp));
        npoly = ivec3(1, 2, 0);
    } else if (spoint == 5) {
        // polygon vertex at bisector of degree-2 angle, alternation of triangles, P-gons, squares
        poly_vertex = normalize(cross(lr, lp - lq));
        npoly = ivec3(1, 1, 2);
    } else {
        // polygon vertex at circumcenter
        poly_vertex = normalize(cross(lp - lq, lq - lr));
        npoly = ivec3(2, 2, 2);
    }
    
    mat3 poly_edges = mat3(normalize(cross(poly_vertex, lp)),
                           normalize(cross(poly_vertex, lq)),
                           normalize(cross(poly_vertex, lr)));
        
    poly_edge_dist = 1e5;
    
    vec3 pe = p * poly_edges;
    bool is_even = true;
    
    ivec3 npolys = ivec3(degree, 3, 2) * npoly;
    
    v_cur = M * poly_vertex;

    for (int vidx=0; vidx<3; ++vidx) {
        
        if (npoly[vidx] >= 0) {
        
            int idx0 = (vidx + 1) % 3;
            int idx1 = (vidx + 2) % 3;
                    
            float d0 = pe[idx0];
            float d1 = pe[idx1];
            
            if (d0 <= 0. && d1 >= 0.) {
            
                d0 = -d0;
            
                if (d0 < d1) {
                    poly_edge_dist = d0;
                } else {
                    poly_edge_dist = d1;
                }
                
                face_normal = M*tri_verts[vidx];
                nface = npolys[vidx];
                                
            }
            
        }
    }
    
    return npolys;
    
}

//////////////////////////////////////////////////////////////////////
// squared distance from point p to a circle perpendicular to vector n 
// passing thru point p0

float dcircle2(vec3 p, vec3 n, vec3 p0) {

    float k = dot(p0, n);
    
    vec3 c = k*n;
    
    p -= c;
    p0 -= c;
    
    float z = dot(p, n);
    
    vec3 xy = p - z*n;
    
    vec3 pc = normalize(xy)*length(p0);
    
    vec3 q = p - pc;
    
    return dot(q, q);
    
}

//////////////////////////////////////////////////////////////////////
// distance function

vec2 map(in vec3 p) {


    p = rotate(vec3(0.18549298, 0.58241682, 0.79144362), 0.5) * p;

    // phases for animation
    float crack_visibility = smoothstep(0.0, 0.45, decorate);
    float torus_visibility = smoothstep(0.55, 1.0, decorate);
    
    ////////////////////////////////////////////////////////////
    // Wythoff construction

    float extra = float(setup.z);
    
    vec3 face_normal, v_cur;
    float poly_edge_dist;
    int nface;
    
    ivec3 npolys = construct(p, 
                             face_normal, v_cur,
                             poly_edge_dist, nface);
                             
    ////////////////////////////////////////////////////////////
    // Compute the canonical index of the current polygon 
    // vertex from 0 ... nface - 1
    
    vec3 r0 = vec3(0.7027036, 0.68125974, 0.56301879);
    vec3 r1 = vec3(0.65254045, 0.98167042, 0.49662301);
    
    float dr0 = abs(dot(face_normal, r0));
    float dr1 = abs(dot(face_normal, r1));
    
    vec3 rando_dir = dr0 < dr1 ? r0 : r1;
    
    vec3 basis_u = normalize(cross(rando_dir, face_normal));
    vec3 basis_v = cross(face_normal, basis_u);
    
    vec2 uv = (vec2(dot(v_cur, basis_u), dot(v_cur, basis_v)));

    float rot_angle = 0.5 + 0.5*atan(uv.y, uv.x)/PI;
    float fnface = float(nface);
    
    float idx = floor(rot_angle*fnface);

    ////////////////////////////////////////////////////////////
    // Now set up to do compute the torus distances
    
    // Rotation by angle increment
    float dtheta = 2.*PI/fnface;    
    mat3 R = rotate(face_normal, dtheta);
    
    // Get second-closest vertex
    vec3 v_next = dot(p, cross(v_cur, face_normal)) < 0. ? R*v_cur : v_cur*R;

    // Figure out whether we're doing one or two nodes per
    // polygon edge (note odd-numbered polygons like triangles
    // and pentagons require this)
    bool use_midpoint = (npolys % 2 == ivec3(0)) && setup.xy != ivec2(4, 1);

    // Compute torus minor radius
    float kwidth = use_midpoint ? 0.16 : 0.07;
    float torus_r0 = kwidth*acos(dot(v_cur, v_next));    

    // Fraction to sink torii down into sphere
    float sink_by = 1.0 - mix(1.01*torus_r0, 0.25*torus_r0, torus_visibility);
        
    // Random vector per face
    face_normal = normalize(face_normal);
    vec3 rface = hashwithoutsine31(floor(64.*dot(face_normal, rando_dir) + extra + 0.5));
    
    // Choose a random integer rotation for symmetric tiles
    float ioffs = floor(rface.z * fnface);

    // We need to keep nodes closer together if there are triangles
    // or squares in this tiling
    bool any34 = any(equal(npolys, ivec3(3))) || any(equal(npolys, ivec3(4)));

    // How close together to put two nodes on same edge 
    // (closeness = 1 means midpoint of edge)
    float closeness = use_midpoint ?  1.0 : any34 ? 0.65 : 0.55;

    ////////////////////////////////////////////////////////////
    // Time to compute the torus distances!
    
    float d_torus = 1e5;
    
    if (rface.x < 0.75) {

        // Bilaterally symmetric cell - expensive distance 
        // query to multiple torii

        // Canonical polygon vertex 0 and vertex 1 
        vec3 p0 = rotate(face_normal, (ioffs - idx)*dtheta) * v_cur;
        vec3 p1 = R*p0;

        // Nodes along canonical edge
        vec3 n0 = sink_by*normalize(p0 + closeness*p1);
        vec3 n1 = sink_by*normalize(closeness*p0 + p1);

        // Polygon edge
        vec3 polygon_edge = cross(p0, p1);
        
        // Choose centerline for bilateral symmetry.
        // No big difference for odd polygons but
        // two distinct looks for even polygons.
        
        vec3 pc;
                        
        if ((!use_midpoint && rface.y < 0.45)) {
            // arc centers distributed along
            // line passing thru edge midpoint
            pc = p0 + p1;
        } else {
            // arc centers distributed along
            // line passing thru vertex
            pc = p0;
        }

        vec3 center_line = cross(pc, face_normal);
        vec3 lateral_line = cross(center_line, face_normal);
                
        int cnt = nface / 2 + 1;
        
        // We may be able to take advantage of extra symmetry
        // so make a copy of current point to do so
        vec3 p_torus = p;

        if (nface % 2 == 0) {
            if (dot(p_torus, lateral_line) > 0.) { 
                p_torus = reflect(p_torus, normalize(lateral_line)); 
            }
            cnt = nface / 4 + 1;
        }
        
        for (int i=0; i<MAX_POLYGON; ++i) {

            if (i >= cnt) { break; }

            vec3 ctr = normalize(cross(polygon_edge, center_line));

            d_torus = min(d_torus, dcircle2(p_torus, ctr, n0));

            if (!use_midpoint) {
                d_torus = min(d_torus, dcircle2(p_torus, ctr, n1));
            }

            n0 = R*n0;
            n1 = R*n1;

            polygon_edge = R*polygon_edge;

        }

    } else {
    
        // Radially symmetric cell

        // Nodal point is between cur vertex and next vertex
        vec3 v_node = normalize(v_cur + closeness*v_next);
        
        vec3 ctr;
            
        if (use_midpoint) {

            // Center torus on previous or current vertex?
            if (mod(idx, 2.0) == step(rface.y, 0.5)) {
                ctr = v_cur;
            } else {
                ctr = v_next;
            }
            
        } else {
        
            float p_vertex = (nface == 3 ? 0.5 : 0.95);
        
            // Vertex-centered or edge-centered torus?
            if (rface.y < p_vertex) {
                ctr = v_cur;
            } else {
                ctr = normalize(v_cur + v_next);
            }

        }
    
        // Compute distance
        d_torus = dcircle2(p, ctr, sink_by*v_node);
    
    }
    
    // We postponed some sqrt calls when computing torus distances
    d_torus = sqrt(d_torus) - torus_r0;
    
    ////////////////////////////////////////////////////////////
    // Do final distance & material computation
    
    float crack_size = mix(-2e-3, 0.18*torus_r0, crack_visibility);

    float d_sphere = length(p) - 1.0;

    float d_uncracked = min(d_torus, d_sphere);    
    
    float d_crack = poly_edge_dist - crack_size;
    
    float d_crack_subtracted = max(d_uncracked, -d_crack);
    
    float d_eroded = d_uncracked + max(1.5*crack_size, 0.);
    
    float material = step(d_torus, d_sphere) + 1.0;
    if (d_crack < 1e-3) { material = 0.0; }
    
    float d_final = min(d_crack_subtracted, d_eroded);
    
    return vec2(d_final, material);
    
}

//////////////////////////////////////////////////////////////////////
// IQ's distance marcher

vec2 castRay(in vec3 ro, in vec3 rd, float tmin, float tmax) {

    const float precis = 0.002;   
    
    float h = 2.0*precis;

    float t = tmin;
    float m = -1.0;
    
    const int rayiter = 50;
    
    vec3 color;

    for( int i=0; i<rayiter; i++ ) {

        if( abs(h)<precis||t>tmax ) { break; }
        
        t += h;
        
        vec2 res = map( ro+rd*t );

        h = res.x;
        m = res.y;
        
    }    

    if (t > tmax) {
        m = -1.0;
    }

    return vec2(t, m);

}

//////////////////////////////////////////////////////////////////////
// IQ's normal calculation. 

vec3 calcNormal( in vec3 pos ) {
    vec3 eps = vec3( 0.001, 0.0, 0.0 );
    vec3 q;
    vec3 nor = vec3(
        map(pos+eps.xyy).x - map(pos-eps.xyy).x,
        map(pos+eps.yxy).x - map(pos-eps.yxy).x,
        map(pos+eps.yyx).x - map(pos-eps.yyx).x );
    return normalize(nor);
}


//////////////////////////////////////////////////////////////////////
// From IQ: https://www.shadertoy.com/view/ldX3R8

float ambientOcclusion(vec3 p, vec3 n){
    const int steps = 3;
    const float delta = 0.5;

    float a = 0.0;
    float weight = 2.0;
    float m;
    for(int i=1; i<=steps; i++) {
        float d = (float(i) / float(steps)) * delta; 
        a += weight*(d - map(p + n*d).x);
        weight *= 0.5;
    }
    return clamp(1.0 - a, 0.0, 1.0);
}

//////////////////////////////////////////////////////////////////////
// Rendering function

vec3 shade( in vec3 ro, in vec3 rd, mat3 rot, float tmin, float tmax){

    vec2 tm = castRay(ro, rd, tmin, tmax);        
    
    mat3 rtex = rot * rotate(vec3(1, 0, 0), 0.25);

    if (tm.y < 0.0) {

        return texture(iChannel1, rd*rtex).xyz;

    } else {        

        vec3 pos = ro + tm.x*rd;
        vec3 n = calcNormal(pos);
        
        vec3 color = vec3(1);
        
        vec3 rray = reflect(-ro, n);

        vec3 scolor = (tm.y == 2. ? vec3(1, 0.8, 0.65) : vec3(1));
        
        float sstrength = 0.5;
        float sexp = 20.0;
        
        if (tm.y == 2.) {
            color = scolor;
            scolor *= texture(iChannel2, rray*rtex).xyz * mix(scolor, vec3(1), 0.75);
            sstrength = 0.95;
        } else {
            color = vec3(0.1);
            scolor = texture(iChannel1, rray*rtex).xyz;
            if (tm.y == 0.) {
                color *= 0.5;
                sstrength = 0.05;
            }

        }
        
        //color = scolor = vec3(1);
        
        pos -= n * map(pos).x;
        
        vec3 L = normalize(vec3(-0.25, 1.0, 1.0));
        L = rot*L;

        vec3 diffamb = (0.7*clamp(dot(n, L), 0.0, 1.0) + 0.3) * color;

        return mix(diffamb, scolor, sstrength) * ambientOcclusion(pos, n);

    }

}

//////////////////////////////////////////////////////////////////////
// do the things

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {

    // distance from camera to sphere centers
    const float cdist = 6.0;
    
    // center-relative fragment coordinates
    vec2 uv = fragCoord.xy - 0.5*iResolution.xy;
        
    // focal length in pixels
    float f = 0.45/iResolution.y;
    
    // approx size of orb in pixels
    float xlim = 1.1/(cdist*f);

    // fetch state from previous render pass
    vec4 cur_state = texelFetch(iChannel0, ivec2(0, 0), 0);
    vec4 next_state = texelFetch(iChannel0, ivec2(1, 0), 0);
    
    // handle interpolating between states
    float which = 0.0;
    
    // are we transitioning?
    if (next_state.x != 0.0) {

        // at which = 0, cur_state, which = 1, next_state
        which = unlerp(cur_state.w, next_state.w, iTime);

        // stagger state transition by screen x coord
        float delta = clamp(-uv.x/xlim, -1.0, 1.0);

        // bigger k means smaller transition band
        float k = 0.2; 
        
        // minimum transition band size
        const float gutter = 0.01;
        
        // which is always between 0 and 1
        which = unlerp(k, 1.0-k, which + k*delta);
        
        // remove sphere decorations when which near 0.5
        decorate = unlerp(gutter, 1.0, 2.0*abs(fract(which)-0.5));
        
        if (cur_state.xy == next_state.xy) {
            decorate = 0.5*decorate + 0.5;
        }
        

    }

    // get vertex degree, triangle point, random seed for this fragment
    setup = ivec3(which <= 0.5 ? cur_state.xyz : next_state.xyz);
        
    // error checking
    if (setup.x < 3 || setup.x > 5 || setup.y < 0 || setup.y > 6) {
        fragColor = vec4(1, 0, 0, 0);
        return;
    }

    // set up rotation vector    
    float t = iTime;
    vec2 theta;
        
    theta.y = 2.*PI*t/6.0;
    theta.x = 0.35*PI*sin(2.*PI*t/15.0);
       
    if (max(iMouse.x, iMouse.y) > 0.1*iResolution.y) { 
        theta.x = (iMouse.y - .5*iResolution.y) * 5.0/iResolution.y; 
        theta.y = (iMouse.x - .5*iResolution.x) * -10.0/iResolution.x; 
    }
    
    // ray origin and direction
    vec3 rd = normalize(vec3(f*uv, -1));
    vec3 ro = vec3(0, 0, cdist);
    
    // handle orb rotation
    mat3 R = rotate(vec3(0, 1, 0), theta.y)*rotate(vec3(1, 0, 0), theta.x);
 
    // trace scene
    vec3 color = shade(R*ro, R*rd, R, cdist-1.2, cdist+1.2);        

    // "gamma correct" :P
    color = pow(color, vec3(0.7));

    fragColor = vec4(color, 1);
    
}

