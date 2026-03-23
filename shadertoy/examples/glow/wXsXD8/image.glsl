#define MAX_DIST 500.0

#define INTEGRATE_UNBOUNDED_STUFF 1
// set to 0 to make the density of the glowy stuff 1/(distance^2)
// by default it's 1/distance, which means the total glow contribution grows with MAX_DIST
// I think it looks better with 1/distance
// but, hey, neither of these functions come from "physics"
// (or, if they do, it is only by coincidence)
//
// p.s. looks really nice when MAX_DIST is huge (thanks @CLPB for pointing this out)

const vec3 light = vec3(0.48, 0.64, -0.6);

vec3 ball1;
vec3 ball2;
vec3 ball3;

vec3 radii;

float sdf1(in vec3 pt) {
    return length(max(vec3(0.0), abs(pt - ball1) - 0.5 * radii.x)) - 0.25 * radii.x;
}

float sdf2(in vec3 pt) {
    vec2 tor = vec2(length(pt.xy - ball2.xy) - 0.75 * radii.y, pt.z);
    return length(tor) - 0.25* radii.y;
}

float sdf3(in vec3 pt) {
    return length(pt - ball3) - radii.z;
}

vec3 sdfs(in vec3 pt) {
    return vec3(sdf1(pt), sdf2(pt), sdf3(pt));
}

float sdf(in vec3 pt) {
    return min(sdf1(pt), min(sdf2(pt), sdf3(pt)));
}

float min_comp(in vec3 comps) {
    return min(comps.x, min(comps.y, comps.z));
}

vec3 sdf_grad(in vec3 pt) {
    float f = sdf(pt);
    const float h = 0.001;
    const float h_inv = 1000.0;
    
    return vec3(sdf(pt + vec3(h, 0.0, 0.0)) - f,
                sdf(pt + vec3(0.0, h, 0.0)) - f,
                sdf(pt + vec3(0.0, 0.0, h)) - f);
}

float raymarch(in vec3 orig, in vec3 dir, out vec3 integral) {
    integral = vec3(0.0);
    float curr = 0.0;
    const float step_ratio = 0.25;
    vec3 curr_sdf = sdfs(orig);
    float dist = step_ratio * min_comp(curr_sdf);
    vec3 next_sdf = sdfs(orig + dir * dist);
    // integral from 0 to d of 1/(a+bx) =
    // screw it, just average some things.
    integral = dist * (0.25 / curr_sdf + 1.0 / (curr_sdf + next_sdf) + 0.25 / next_sdf);
    float total_dist = dist;
    const vec3 thresh = vec3(0.004);
    for (int i = 0; i < 128; ++i) {
        curr_sdf = next_sdf;
        dist = step_ratio * min_comp(curr_sdf);
        total_dist += dist;
        next_sdf = sdfs(orig + total_dist * dir);
        vec3 mid = 0.5 * (curr_sdf + next_sdf);
#if INTEGRATE_UNBOUNDED_STUFF        
        integral += dist * (0.25 / max(thresh, curr_sdf) + 
                            0.5 / max(thresh, mid ) + 
                            0.25 / max(thresh, next_sdf));
#else
        integral += dist * (0.25 / max(thresh, curr_sdf * curr_sdf) + 
                            0.5 / max(thresh , mid * mid ) + 
                            0.25 / max(thresh, next_sdf * next_sdf));
#endif        
        if (min_comp(next_sdf) < 1.0e-3 || total_dist > MAX_DIST) {
            return total_dist;
        }
    }
    return total_dist;
}
        

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    
    vec3 orig = vec3(0.0, 0.1, -1.25);
    vec3 dir = normalize(vec3(uv, 1.0));
    
    mat3 tilt = mat3(1.0, 0.0, 0.0,
                0.0, 0.28, -0.96,
                0.0, 0.96, 0.28); 
    orig = tilt * orig;
    dir = tilt * dir;
    
    float theta = 0.6 * iTime;
    float ct = cos(theta);
    float st = sin(theta);
    
    float rad = 0.6;

    ball1 = rad * vec3(ct, st, 0.0);

    ct = cos(theta + 2.0 * 3.141592654 / 3.0);
    st = sin(theta + 2.0 * 3.141592654 / 3.0);
    ball2 = rad * vec3(ct, st, 0.0);
    
    ct = cos(theta - 2.0 * 3.141592654 / 3.0);
    st = sin(theta - 2.0 * 3.141592654 / 3.0);
    ball3 = rad * vec3(ct, st, 0.0);

    vec3 integral;
    
    radii = 0.3 + 0.2 * vec3(0.);
    
    float raydist = raymarch(orig, dir, integral);

#if INTEGRATE_UNBOUNDED_STUFF    
    vec3 col = smoothstep(0.15 * (1.0 *  radii), vec3(0.0), 0.45/(integral));
#else
    vec3 col = smoothstep(0.15 * (1.0 *  radii), vec3(0.0), 1.5/(integral));    
#endif    
    
    if (raydist < MAX_DIST) {
        vec3 pt = orig + raydist * dir;
        vec3 norm = normalize(sdf_grad(pt));
        vec3 bounce = normalize(reflect(dir, norm));
        col += 0.25 * smoothstep(0.95, 1.0, dot(bounce, light)) * vec3(0.9, 0.8, 1.0);
    }

    // Output to screen
    fragColor = vec4(col,1.0);
}
