
#define EPSILON 0.00001
const float PI = 3.1415926535897932384626433832795;
const float TWO_PI = 2.0 * PI;
const float HALF_PI = 0.5 * PI;

const vec3 _X = vec3(1.0, 0.0, 0.0);
const vec3 _Y = vec3(0.0, 1.0, 0.0);
const vec3 _Z = vec3(0.0, 0.0, 1.0);

// ray-plane intersection test
// @return side of plane hit
//    0 : no hit
//    1 : front
//    2 : back
int intersect_plane (in vec3 ro, in vec3 rd, in vec3 po, in vec3 pd, out vec3 hit)
{   
    float D = dot(po, pd);       // re-parameterize plane to normal + distance
    float tn = D - dot(ro, pd);  // ray pos w.r.t. plane (frnt, back, on)
    float td = dot (rd, pd);     // ray ori w.r.t. plane (towards, away, parallel)
    
    if (td > -EPSILON  &&  td < EPSILON)  return 0;  // parallel to plane
    
    float t = tn / td;          // dist along ray to hit
    if (t < 0.0)  return 0;     // plane lies behind ray
    hit = ro + t * rd;          // got a hit
    return (tn > 0.0) ? 2 : 1;  // which side of the plane?
}

// ray-sphere intersection
// @return side of hit
//    0 : no hit
//    1 : outside
//    2 : inside
int intersect_sphere (in vec3 ro, in vec3 rd, in vec3 po, in float rad, out vec3 hit)
{
    float R = rad;
    float RSq = R*R;
	vec3 d = ro - po;
    float DSq = dot(d,d);

    //float a = 1.0;
    float b = 2.0 * dot(d, rd);
    float c = dot(d,d) - RSq;    
	float descrim = b*b - 4.0*c;

    if (descrim < 0.0)  return 0;  // no hit

    float det = sqrt(descrim);
    float t0 = (-b + det) / 2.0;
    float t1 = (-b - det) / 2.0;
    float t = min(t0, t1);
	hit = ro + t * rd;
    return (DSq > RSq) ? 1 : 2;    // outside | inside
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy; // [0, 1]
    vec2 st = 2.0 * uv - vec2(1.0);             // [-1, 1]

    float asp = iResolution.x / iResolution.y;
    float inv_asp = iResolution.y / iResolution.x;
    
    // adjust st coords to range [-1, 1] in Y, [-asp, asp] in X
    //
  	// really, this should do a check for the aspect to determine which
    // axis to adjust, but we're working in landscape for now.
    vec2 st_adj = vec2(st.x * asp, st.y);
    
    // camera settings
    float dist = 2.0 + 0.5*sin(0.5*iTime);
    float theta = 0.1230596391*iTime;
    float cx = dist * sin(theta);
    float cz = dist * cos(theta);
    vec3 cam_ori = vec3(cx, 1.0+0.125*sin(0.215934771*iTime), cz);
    vec3 cam_look = vec3(0.0, 0.50, 0.0);
    vec3 cam_dir = normalize(cam_look - cam_ori);
    
    // over, up, norm basis vectors for camera
  	vec3 cam_nrm = cam_dir;
    vec3 roll = vec3(0.0, 0.05*sin(1.215233*iTime), 0.0);
    vec3 cam_ovr = normalize(cross(cam_dir, _Y) + roll);
    vec3 cam_uhp = normalize(cross(cam_ovr, cam_nrm));
    
    // scene
    vec3 po = vec3(0.0);
    vec3 pd = vec3(0.0, 1.0, 0.0);
    
 	// ray
    vec3 ro = cam_ori;

    float cam_dist = 3.0;
    vec3 rt = cam_ori + cam_dist*cam_dir;
    rt += st_adj.x * cam_ovr;
    rt += st_adj.y * cam_uhp;
    vec3 rd = normalize(rt - cam_ori);
    
    vec3 hit;
    int side = intersect_plane (ro, rd, po, pd, hit);

    // sky
    if (side == 0) {
        fragColor = texture(iChannel1, rd);
    }
    
    // plane
    //  - figure out UV on plane to sample texture
    vec3 dee = hit - po;
    float tSize = 1.0 / 2.0;
    vec2 p_uv = vec2(dot(dee, _X) * tSize, dot(dee, _Z) * tSize);
	vec4 tx_clr = texture( iChannel0, p_uv);
    
    if (side == 1)
        fragColor = tx_clr;
    else if (side == 2)
        fragColor = tx_clr * vec4(0.5);
    
    // sphere
    vec3 so = vec3(0.0, 0.5, 0.0);
    float rad = 0.5;

    // shaddow sample ray
    if (side > 0) {
	    vec3 s_ro = hit;
   		vec3 s_rd = pd;
    	side = intersect_sphere (s_ro, s_rd, so, rad, hit);
    	if (side > 0)  fragColor *= 0.3;
    }
        
    // sphere intersection & shading
    side = intersect_sphere (ro, rd, so, rad, hit);
    if (side > 0) {
        vec3 hitNorm = normalize(hit - so);
        float adj = dot(hitNorm, -rd);
        fragColor = adj * vec4(0.0, 0.54, 0.78, 1.0);
        
		float inv_adj = 1.0 - adj;
        vec3 ref_ori = hit;
        vec3 ref_dir = reflect(rd, hitNorm);
        if (side == 2)
            ref_dir *= -1.0;
        vec4 tex_clr = pow(inv_adj, 0.75) * texture(iChannel1, ref_dir);
        fragColor = mix(fragColor, tex_clr, 0.35);
    }
    
    // vignette, 'cuz why not...
    float r_in = 0.75;
    float wid = 1.15;
    float r_out = r_in + wid;
    float d = length(st);
    float adj = 1.0-smoothstep(r_in, r_out, d);
    fragColor *= vec4(vec3(adj), 1.0);
        
}




