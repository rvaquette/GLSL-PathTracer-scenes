/*
    Copyright (C) 2024 Kaia Vintr
    
    Code is licensed only for personal, non-commercial use on the Shadertoy
    website. You may not copy all or any part of the code into another Shadertoy
    shader (whether by using Shadertoy's "fork" feature or by some other means).
    You may not distribute or use all or any part of the code outside of
    the Shadertoy website, even if the code is accessed via the Shadertoy API or
    web server. You may not use the code or its output to train or fine-tune
    machine learning models (e.g. "AI" models). You may not use the code to
    create image or video content for publication or distribution, except
    screenshots or brief video clips of the output of the unmodified code to be
    used strictly in a manner that would be permitted as "fair use" under U.S.
    copyright law (for example, you may not use the code to create NFTs or
    YouTube videos). If any provision of these license terms is held to be
    invalid or unenforceable, that provision shall be limited to the minimum
    extent necessary, and the remaining provisions shall remain in full effect.
    
    Please contact Kaia Vintr with questions regarding this code
    via direct message to @kaiavintr.bsky.social on BlueSky (preferred)
    or @KaiaVintr on Twitter, or via a comment on this shader.
    
    URL of the Shadertoy website page where this code is intended to be used
    (page for this "shader"):
    https://www.shadertoy.com/view/lX2BDV
    
    Code is archived at:
    https://github.com/kaiavintr/shadertoy_experiments/tree/main/ClassicalRadiosityTest
    
*/

// Various things are configurable -- see Common

// This shader performs simple ray-casting rendering of the box and sphere, using the
//  radiosity data from the final pass.
// Complication 1 is that it needs to interpolate the radiosity data.
// Complication 2 is that it anti-aliases the edges.

// iChannel0 is output of the final light gathering pass (i.e. BufferD) which also contains the sphere and light position data

#define CUBIC(t, C0, C1, C2, C3) (C0 + (C1 + (C2 + C3*t)*t)*t)

vec3 LINEAR_TO_SRGB(vec3 C) {
    // Note: this is a direct translation of the sRGB definition into branch-less GLSL (other people's code likely looks similar)
    return mix(12.92*C, 1.055*pow(C, vec3(1./2.4)) - 0.055, step(0.0031308, C));
}

float rgb_to_luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Shift energy from clipped color components into other components, but don't modify representable colors
// Avoids unexpected cyan, yellow, and magenta pixels and tries to use correct luminance even if color is out of gamut
vec3 gamut_clip(vec3 c) {
    float maxcomp = max(max(c.r, c.g), c.b);
    
    if (maxcomp <= 1.005) {
        return c;
    } else {
        float target_luminance = rgb_to_luminance(c);
        
        vec3 representable = c / maxcomp;
        
        float representable_luminance = rgb_to_luminance(representable);
        
        // Find a color that is a linear blend between brightest representable color with same chroma + saturation as c, and white,
        //      and has same luminance as c (target_luminance).
        // If target_luminance >= 1. white will be used.
        // (1.00001 could probably be safely changed to 1. in GLSL) 
        return mix(c, vec3(1), clamp((target_luminance - representable_luminance) / (1.00001 - representable_luminance), 0., 1.));
    }
}

mat3 make_camera_rotation_matrix(vec4 mouse4, vec3 resolution) {
    vec2 mouse = mouse4.x == 0. && mouse4.y == 0. || mouse4.x > resolution.x || mouse4.y > resolution.y
            ? 0.5*resolution.xy
            : mouse4.xy;
    
    mouse = 2. * (mouse.xy / resolution.xy - 0.5);
    
    float xz = PI * 0.4*mouse.x;
    float yz = 0.5*PI * 0.8*clamp(mouse.y, -0.999, 0.999);
    
    float cos_yz = cos(yz);
    
    vec3 dir_z = normalize(vec3(sin(xz)*cos_yz, sin(yz), cos(xz)*cos_yz)); // (normalize is for precision loss only)
    vec3 dir_x = normalize(cross(vec3(0, 1, 0), dir_z));

    return mat3(dir_x, normalize(cross(dir_z, dir_x)), dir_z); // (normalize is for precision loss only)
}

float intersect_sphere(vec3 C, float r, vec3 V, vec3 ray_O) {
    ray_O -= C;

    float a = dot(V, ray_O);

    float d = a*a - dot(ray_O, ray_O) + r*r;

    return d >= 0. ? -sqrt(d) - a : 1e20;
}

// Distance to axis-aligned plane
// rV is (e.g.) 1./V.x, where V is the normalized view ray
float plane_distance(float c, float rV, float origin) {
    float d = (c - origin)  * rV;

    return d > 0. ? d : 1e20;
}

#if INTERPOLATION == MITCHELL_NETRAVALI
float mitchell_netravali(float x) {
    // I hope I didn't mess this one up (anyway, it looks right)
    
    x = min(abs(x), 2.);

    return x < 1. ? (
            (7./6.*x - 2.)*x*x + 8./9.
        ) : (
            ((-7./18.*x + 2.)*x - 10./3.)*x + 16./9.
        );
}
#endif

#if INTERPOLATION == CUBIC_BSPLINE
// Optimized functions for computing cubic B-spline smoothing coefficients (a bit unnecessary here)
// I think these work for t in interval (-0.5, 1.5)

float bspline_eval_low(float t) {
    t = min(t, 1.);

    return 1./6.*(t*(t*(t - 2.*abs(t) + 3.) - 3.) + 1.);
}

float bspline_eval_low2(float t) {
    t = abs(t) - 1.;

    return 1./6.*(t*(t*(t - 2.*abs(t) + 3.) - 3.) + 1.);
}

float bspline_eval_high(float t) {
    t = abs(t - 1.) - 1.;

    return 1./6.*(t*(t*(t - 2.*abs(t) + 3.) - 3.) + 1.);
}

float bspline_eval_high2(float t) {
    t = min(1.-t, 1.);

    return 1./6.*(t*(t*(t - 2.*abs(t) + 3.) - 3.) + 1.);
}
#endif

// x is in interval (-0.5, 1.5)
// returns coefficients for values at x=-1, x=0, x=1 and x=2
vec4 get_interp_coefficients(float x) {
#if INTERPOLATION == NO_INTERPOLATION // No interpolation
    return vec4(
        0.,
        x < 0.5 ? 1. : 0.,
        x >= 0.5 ? 1. : 0.,
        0.
    );
#elif INTERPOLATION == BILINEAR_INTERPOLATION // Linear
    return vec4(
        0.,
        1. - x,
        x,
        0.
    );
#elif INTERPOLATION == CATMULL_ROM // Catmull-Rom
    return vec4(
        0.5*x*((2. - x)*x - 1.),
        (1.5*x - 2.5)*x*x + 1.,
        ((-1.5*x + 2.)*x + 0.5)*x,
        0.5*x*x*(x - 1.)
    );
#elif INTERPOLATION == CUBIC_BSPLINE
    return vec4(
        bspline_eval_low(x),
        bspline_eval_low2(x),
        bspline_eval_high(x),
        bspline_eval_high2(x)
    );
#else // Mitchell-Netravali
    return vec4(
        mitchell_netravali(x+1.),
        mitchell_netravali(x),
        mitchell_netravali(x-1.),
        mitchell_netravali(x-2.)
    );
#endif
}

// For anti-aliasing an edge, given two points on the edge, the coordinate of the pixel, and a distance
float get_edge_antialias_alpha(vec2 fragCoord, vec2 P1, vec2 P2, float blur_dist) {
    vec2 gap = fragCoord - P1.xy;
    vec2 V = normalize(P2.xy-P1.xy);
    
    return smoothstep(0., blur_dist, length(gap - dot(gap, V)*V));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    fragCoord -= 0.5*iResolution.xy;

    vec3 V;
    float pix_scale; // used for anti-aliasing; computed while normalizing the view ray
    
    {
        vec3 V0 = vec3(fragCoord, VIEW_ANGLE_FACTOR*iResolution.y);
        
        pix_scale = 1./length(V0);
        
        V = pix_scale * V0;
    }
    
    vec3 ray_O = vec3(0.5, 0.5, 1.*CAMERA_Z); // view ray origin
    mat3 rotation_matrix = make_camera_rotation_matrix(iMouse, iResolution);
    
    V = rotation_matrix * V;
    ray_O = rotation_matrix * (ray_O-vec3(0.5,0.5,0.25)) + vec3(0.5,0.5,0.25);
    
    ray_O.z = min(ray_O.z, -0.01);
    
    vec3 rV = 1. / V; // used for axis-aligned plane intersection
    
    // Check if ray passes through the front of the box (nothing outside the box is rendered)
    {
        float t_front = plane_distance(0., rV.z, ray_O.z);
        
        vec3 p = ray_O + t_front*V;
        
        if (p.x < 0. || p.x > 1. || p.y < 0. || p.y > 1.) {
            fragColor = vec4(0,0,0,1);
            return;
        }
    }
    
    float t_left = ray_O.x < 0. ? 1e20 : plane_distance(0., rV.x, ray_O.x);
    float t_right = ray_O.x > 1. ? 1e20 : plane_distance(1., rV.x, ray_O.x);
    float t_bottom = ray_O.y < 0. ? 1e20 : plane_distance(0., rV.y, ray_O.y);
    float t_top = ray_O.y > 1. ? 1e20 : plane_distance(1., rV.y, ray_O.y);
    float t_back = plane_distance(1., rV.z, ray_O.z);
    
    float t_inter = min(min(min(t_left, t_bottom), min(t_right, t_top)), t_back);
    
    vec3 final_color = vec3(0);
    
    if (t_inter < 1e6) {
        float back_antialias_alpha = 1.;
        
        if (t_inter != t_back) {
            vec3 P1 = t_inter == t_left || t_inter == t_bottom ? vec3(0., 0., 1.) : vec3(1., 1., 1.);
            vec3 P2 = t_inter == t_left || t_inter == t_top ? vec3(0., 1., 1.) : vec3(1., 0., 1.);
            
            P1 = (P1 - ray_O) * rotation_matrix;
            P2 = (P2 - ray_O) * rotation_matrix;
            
            back_antialias_alpha = get_edge_antialias_alpha(fragCoord, P1.xy * (VIEW_ANGLE_FACTOR*iResolution.y / P1.z), 
                                               P2.xy * (VIEW_ANGLE_FACTOR*iResolution.y / P2.z), 2.);
        }

        vec3 p = ray_O + t_inter*V;
    
        float side_antialias_alpha = 1.;
        
        if (t_inter == t_left || t_inter == t_right) {
            vec3 P1 = vec3(t_inter == t_left ? 0. : 1., p.y < 0.5 ? 0. : 1., 0.);
            
            vec3 P2 = P1 + vec3(0., 0., 1.);
            
            P1 = (P1 - ray_O) * rotation_matrix;
            P2 = (P2 - ray_O) * rotation_matrix;
            
            side_antialias_alpha = get_edge_antialias_alpha(fragCoord, P1.xy * (VIEW_ANGLE_FACTOR*iResolution.y / P1.z), 
                                               P2.xy * (VIEW_ANGLE_FACTOR*iResolution.y / P2.z), 2.);
        }
    
        // Choose which mesh to use
        // Get coordinates of the point within the mesh where we need the radiosity value
        float fi;
        float fj;
        int base_x;
    
        if (t_inter == t_left) {
            fi = float(MESH_SQUARE_ROWS)*p.y;
            fj = float(MESH_SQUARE_COLUMNS)*p.z;
            base_x = MESH_X_OFFSET_LEFT;
        } else if (t_inter == t_right) {
            fi = float(MESH_SQUARE_ROWS)*p.y;
            fj = float(MESH_SQUARE_COLUMNS)*p.z;
            base_x = MESH_X_OFFSET_RIGHT;
        } else if (t_inter == t_bottom) {
            fi = float(MESH_SQUARE_ROWS)*p.z;
            fj = float(MESH_SQUARE_COLUMNS)*p.x;
            base_x = MESH_X_OFFSET_BOTTOM;
        } else if (t_inter == t_top) {
            fi = float(MESH_SQUARE_ROWS)*p.z;
            fj = float(MESH_SQUARE_COLUMNS)*p.x;
            base_x = MESH_X_OFFSET_TOP;
        } else {
            fi = float(MESH_SQUARE_ROWS)*p.y;
            fj = float(MESH_SQUARE_COLUMNS)*p.x;
            base_x = MESH_X_OFFSET_BACK;
        }
        
        // Treating the patch radiosity values as values at the center of the patch,
        //      so convert coordinates to that coordinate system
        fi -= 0.5;
        fj -= 0.5;
        
        // Get row and column index of the patch whose center is (e.g.) below and to the left
        //      of the point we want, clamping it to valid mesh coordinates
        int meshi0 = clamp(int(floor(fi)), 0, MESH_SQUARE_ROWS-1);
        int meshj0 = clamp(int(floor(fj)), 0, MESH_SQUARE_COLUMNS-1);
        
        // Get row and column index of the patch whose center is (e.g.) above and to the right
        int meshi1 = min(meshi0 + 1, MESH_SQUARE_ROWS-1);
        int meshj1 = min(meshj0 + 1, MESH_SQUARE_COLUMNS-1);
        
        // If we are at the (e.g.) top or right edge we will be extrapolating, so make sure we
        //      have pairs of distinct rows and columns
        meshi0 = meshi1 - 1;
        meshj0 = meshj1 - 1;
        
        // Get fractional coordinates relative to the (e.g.) below, left coordinate
        // These will be in (0, 1) if we are interpolating, and in (-0.5, 1.5) if extrapolating.
        fi -= float(meshi0);
        fj -= float(meshj0);
        
        // Get interpolation or smoothing coefficients for both directions
        vec4 C = get_interp_coefficients(fi);
        vec4 C2 = get_interp_coefficients(fj);
        
        // Get coordinates of neighboring patches, for use with cubic interpolation or smoothing
        int meshin1 = max(0, meshi0 - 1);
        int meshi2 = min(MESH_SQUARE_ROWS-1, meshi1 + 1);

        int meshjn1 = max(0, meshj0 - 1);
        int meshj2 = min(MESH_SQUARE_COLUMNS-1, meshj1 + 1);
        
        // For Catmull-Rom only, if extrapolating switch to linear extrapolation
        // (Catmull-Rom extrapolation doesn't seem to be usable - produces bright areas at most of the edges)
        #if INTERPOLATION == CATMULL_ROM
        if (meshi1 == meshi2 || meshin1 == meshi0) {
            C = vec4(0., 1. - fi, fi, 0.);
        }

        if (meshj1 == meshj2 || meshjn1 == meshj0) {
            C2 = vec4(0., 1. - fj, fj, 0.);
        }
        #endif
        
        final_color = (C.x*(
                    C2.x*texelFetch(iChannel0, ivec2(base_x + meshjn1, meshin1), 0).rgb 
                        + C2.y*texelFetch(iChannel0, ivec2(base_x + meshj0, meshin1), 0).rgb
                        + C2.z*texelFetch(iChannel0, ivec2(base_x + meshj1, meshin1), 0).rgb
                        + C2.w*texelFetch(iChannel0, ivec2(base_x + meshj2, meshin1), 0).rgb
                        )
                
                + C.y*(
                    C2.x*texelFetch(iChannel0, ivec2(base_x + meshjn1, meshi0), 0).rgb 
                        + C2.y*texelFetch(iChannel0, ivec2(base_x + meshj0, meshi0), 0).rgb
                        + C2.z*texelFetch(iChannel0, ivec2(base_x + meshj1, meshi0), 0).rgb
                        + C2.w*texelFetch(iChannel0, ivec2(base_x + meshj2, meshi0), 0).rgb
                        )
                + C.z*(
                    C2.x*texelFetch(iChannel0, ivec2(base_x + meshjn1, meshi1), 0).rgb 
                        + C2.y*texelFetch(iChannel0, ivec2(base_x + meshj0, meshi1), 0).rgb
                        + C2.z*texelFetch(iChannel0, ivec2(base_x + meshj1, meshi1), 0).rgb
                        + C2.w*texelFetch(iChannel0, ivec2(base_x + meshj2, meshi1), 0).rgb
                        )
                + C.w*(
                    C2.x*texelFetch(iChannel0, ivec2(base_x + meshjn1, meshi2), 0).rgb 
                        + C2.y*texelFetch(iChannel0, ivec2(base_x + meshj0, meshi2), 0).rgb
                        + C2.z*texelFetch(iChannel0, ivec2(base_x + meshj1, meshi2), 0).rgb
                        + C2.w*texelFetch(iChannel0, ivec2(base_x + meshj2, meshi2), 0).rgb
                        )
                    );
        
        // If we are close to one of the sides of the cube face (other than the front) then we are
        //      anti-aliasing, so we need to blend with a value from a neighboring face.
        // Get the value to blend with
        // Because we are using linear extrapolation by default at the edges, (in the Catmull-Rom case)
        //      we should normally only need to fetch two values from the neighboring mesh.
        
        if (side_antialias_alpha < 0.995) {
            // To make things simpler, we ONLY do this for the left and right faces 
            //      (this is sufficient for anti-aliasing)
            
            int index = (p.y < 0.5 ? MESH_X_OFFSET_BOTTOM + 0 : MESH_X_OFFSET_TOP + 0) + (t_inter == t_left ? 0 : MESH_SQUARE_COLUMNS-1);
            int inc = t_inter == t_left ? 1 : -1;
            
            vec3 other_color0 = (C2.x*texelFetch(iChannel0, ivec2(index, meshjn1), 0).rgb
                + C2.y*texelFetch(iChannel0, ivec2(index, meshj0), 0).rgb
                + C2.z*texelFetch(iChannel0, ivec2(index, meshj1), 0).rgb
                + C2.w*texelFetch(iChannel0, ivec2(index, meshj2), 0).rgb
                    );
            
            #if INTERPOLATION == NO_INTERPOLATION
            vec3 other_color = other_color0;
            #else
            index += inc;

            vec3 other_color1 = (C2.x*texelFetch(iChannel0, ivec2(index, meshjn1), 0).rgb
                + C2.y*texelFetch(iChannel0, ivec2(index, meshj0), 0).rgb
                + C2.z*texelFetch(iChannel0, ivec2(index, meshj1), 0).rgb
                + C2.w*texelFetch(iChannel0, ivec2(index, meshj2), 0).rgb
                    );
            
            #if INTERPOLATION != CUBIC_BSPLINE && INTERPOLATION != MITCHELL_NETRAVALI
            vec3 other_color = mix(other_color0, other_color1, -0.5);
            #else
            index += inc;

            vec3 other_color2 = (C2.x*texelFetch(iChannel0, ivec2(index, meshjn1), 0).rgb
                + C2.y*texelFetch(iChannel0, ivec2(index, meshj0), 0).rgb
                + C2.z*texelFetch(iChannel0, ivec2(index, meshj1), 0).rgb
                + C2.w*texelFetch(iChannel0, ivec2(index, meshj2), 0).rgb
                    );
            
            vec4 C3 = get_interp_coefficients(-0.5);
            
            vec3 other_color = (C3.x + C3.y)*other_color0 + C3.z*other_color1 + C3.w*other_color2;
            #endif
            #endif
            
            final_color = mix(other_color, final_color, side_antialias_alpha);
        }        
        
        if (back_antialias_alpha < 0.995) {
            // This type of blending is done for all faces except the back face
            
            ivec2 idx_inc2;
            ivec2 idx0, idx1, idx2, idx3;
            
            if (t_inter == t_left || t_inter == t_right) {
                int idx_start = t_inter == t_left ? MESH_X_OFFSET_BACK + 0 : MESH_X_OFFSET_BACK + MESH_SQUARE_COLUMNS-1;
                idx0 = ivec2(idx_start, meshin1);
                idx1 = ivec2(idx_start, meshi0);
                idx2 = ivec2(idx_start, meshi1);
                idx3 = ivec2(idx_start, meshi2);
                idx_inc2 = ivec2(t_inter == t_left ? 1 : -1, 0);
            } else {
                int idx_start = t_inter == t_bottom ? 0 : MESH_SQUARE_ROWS-1;
                idx0 = ivec2(MESH_X_OFFSET_BACK + meshjn1, idx_start);
                idx1 = ivec2(MESH_X_OFFSET_BACK + meshj0, idx_start);
                idx2 = ivec2(MESH_X_OFFSET_BACK + meshj1, idx_start);
                idx3 = ivec2(MESH_X_OFFSET_BACK + meshj2, idx_start);
                idx_inc2 = ivec2(0, t_inter == t_bottom ? 1 : -1);
                C = C2;
            }
        
            vec3 other_color0 = (C.x*texelFetch(iChannel0, idx0, 0).rgb
                + C.y*texelFetch(iChannel0, idx1, 0).rgb
                + C.z*texelFetch(iChannel0, idx2, 0).rgb
                + C.w*texelFetch(iChannel0, idx3, 0).rgb
                    );
            
            #if INTERPOLATION == NO_INTERPOLATION
            vec3 other_color = other_color0;
            #else
            vec3 other_color1 = (C.x*texelFetch(iChannel0, idx0 + idx_inc2, 0).rgb
                + C.y*texelFetch(iChannel0, idx1 + idx_inc2, 0).rgb
                + C.z*texelFetch(iChannel0, idx2 + idx_inc2, 0).rgb
                + C.w*texelFetch(iChannel0, idx3 + idx_inc2, 0).rgb
                    );

            #if INTERPOLATION != CUBIC_BSPLINE && INTERPOLATION != MITCHELL_NETRAVALI
            vec3 other_color = mix(other_color0, other_color1, -0.5);
            #else
            idx_inc2 *= 2;

            vec3 other_color2 = (C.x*texelFetch(iChannel0, idx0 + idx_inc2, 0).rgb
                + C.y*texelFetch(iChannel0, idx1 + idx_inc2, 0).rgb
                + C.z*texelFetch(iChannel0, idx2 + idx_inc2, 0).rgb
                + C.w*texelFetch(iChannel0, idx3 + idx_inc2, 0).rgb
                    );
            
            vec4 C3 = get_interp_coefficients(-0.5);
            
            vec3 other_color = (C3.x + C3.y)*other_color0 + C3.z*other_color1 + C3.w*other_color2;
            #endif
            #endif
            
            final_color = mix(other_color, final_color, back_antialias_alpha);
        }
    }
    
    // Get the clamped (but otherwise still linear) final pixel color for the image behind the sphere
    //      so we can blend with the light and sphere edge for anti-aliasing.
    final_color = gamut_clip(final_color);
    
    #if SHOW_LIGHT_SOURCE
    {
        // using .zw instead of .xy, because we want the old value (in case the bufferD shader has just changed the light position)
        ivec2 val = floatBitsToInt(texelFetch(iChannel0, ivec2(BUFFER_D_LIGHT_DATA, BUFFER_D_MISC_DATA_ROW), 0).zw);
        
        int light_side = unpack_light_side(val.x);
        ivec2 light_i_minmax = unpack_light_i_minmax(val.x);
        ivec2 light_j_minmax = unpack_light_j_minmax(val.y);
        
        // Get intersection of view ray with the plane containing the light
        // (re-doing this to save the shader code from having to keep those
        //          5 values in registers)
        float light_t = 1e20;
        
        {
            vec3 plane;
    
            if (light_side == SIDE_TOP) plane = vec3(1., ray_O.y, rV.y);
            else if (light_side == SIDE_BOTTOM) plane = vec3(0., ray_O.y, rV.y);
            else if (light_side == SIDE_LEFT) plane = vec3(0., ray_O.x, rV.x);
            else if (light_side == SIDE_RIGHT) plane = vec3(1., ray_O.x, rV.x);
            else plane = vec3(1., ray_O.z, rV.z);
            
            light_t = (plane.x - plane.y)  * plane.z;
        }
        
        if (light_t > 0.) {
            vec3 p = ray_O + light_t*V;
            
            vec2 coord;
            
            if (light_side == SIDE_TOP || light_side == SIDE_BOTTOM) coord = p.xz;
            else if (light_side == SIDE_LEFT || light_side == SIDE_RIGHT) coord = p.zy;
            else coord = p.xy;

            float alpha = 1.; // blending factor for the light (1 = opaque)
            
            // increment because these values are inclusive, and need the edges
            light_i_minmax.y++;
            light_j_minmax.y++;
            
            vec2 minmax_i = 1./float(MESH_SQUARE_ROWS) * vec2(light_i_minmax);
            vec2 minmax_j = 1./float(MESH_SQUARE_COLUMNS) * vec2(light_j_minmax);
            
            // anti-alias edges if we need to
            if (coord.x < minmax_j.x || coord.x > minmax_j.y || coord.y < minmax_i.x || coord.y > minmax_i.y) {

                // Get the 3D points for the corners of the light
                vec3 P1, P2, P3, P4;
                
                if (light_side == SIDE_TOP || light_side == SIDE_BOTTOM) {
                    float y = light_side == SIDE_BOTTOM ? 0. : 1.;
                
                    P1 = vec3(minmax_j.x, y, minmax_i.x);
                    P2 = vec3(minmax_j.y, y, minmax_i.x);
                    P3 = vec3(minmax_j.y, y, minmax_i.y);
                    P4 = vec3(minmax_j.x, y, minmax_i.y);
                } else if (light_side == SIDE_BACK) {
                    P1 = vec3(minmax_j.x, minmax_i.x, 1.);
                    P2 = vec3(minmax_j.y, minmax_i.x, 1.);
                    P3 = vec3(minmax_j.y, minmax_i.y, 1.);
                    P4 = vec3(minmax_j.x, minmax_i.y, 1.);
                } else {
                    float x = light_side == SIDE_LEFT ? 0. : 1.;
                    
                    P1 = vec3(x, minmax_i.x, minmax_j.x);
                    P2 = vec3(x, minmax_i.x, minmax_j.y);
                    P3 = vec3(x, minmax_i.y, minmax_j.y);
                    P4 = vec3(x, minmax_i.y, minmax_j.x);
                }
                
                P1 = (P1-ray_O)*rotation_matrix;
                P2 = (P2-ray_O)*rotation_matrix;
                P3 = (P3-ray_O)*rotation_matrix;
                P4 = (P4-ray_O)*rotation_matrix;
                
                P1.xy *= VIEW_ANGLE_FACTOR*iResolution.y / P1.z;
                P2.xy *= VIEW_ANGLE_FACTOR*iResolution.y / P2.z;
                P3.xy *= VIEW_ANGLE_FACTOR*iResolution.y / P3.z;
                P4.xy *= VIEW_ANGLE_FACTOR*iResolution.y / P4.z;
                
                const float edge_dist = 2.;
                
                // anti-alias the edges
                if (coord.y < minmax_i.x) alpha *= 1. - get_edge_antialias_alpha(fragCoord, P1.xy, P2.xy, edge_dist);
                if (coord.x > minmax_j.y) alpha *= 1. - get_edge_antialias_alpha(fragCoord, P2.xy, P3.xy, edge_dist);
                if (coord.y > minmax_i.y) alpha *= 1. - get_edge_antialias_alpha(fragCoord, P3.xy, P4.xy, edge_dist);
                if (coord.x < minmax_j.x) alpha *= 1. - get_edge_antialias_alpha(fragCoord, P4.xy, P1.xy, edge_dist);
                
                // prevent the anti-aliased corners from stretching too far
                if (alpha != 0. && light_side != SIDE_BACK) {
                    vec2 V1 = normalize(P1.xy - P2.xy);
                    vec2 V4 = normalize(P4.xy - P1.xy);
                    
                    float d = dot(fragCoord - P1.xy, normalize(V1 - V4));

                    vec2 V2 = normalize(P2.xy - P3.xy);
                    
                    d = max(d, dot(fragCoord - P2.xy, normalize(V2 - V1)));
                    
                    vec2 V3 = normalize(P3.xy - P4.xy);
                    
                    d = max(d, dot(fragCoord - P3.xy, normalize(V3 - V2)));
                    d = max(d, dot(fragCoord - P4.xy, normalize(V4 - V3)));
                    
                    alpha *= 1. - smoothstep(edge_dist, 2.*edge_dist, d);
                }
            }
            
            // Fade the light out when seen from the side to avoid artifacts
            if (alpha != 0. && light_side != SIDE_BACK) {
                float t = 1.;
                if (light_side == SIDE_TOP) t = V.y;
                else if (light_side == SIDE_BOTTOM) t = -V.y;
                else if (light_side == SIDE_LEFT) t = -V.x;
                else if (light_side == SIDE_RIGHT) t = V.x;
                
                alpha *= smoothstep(0., 0.02, t);
            }
        
            final_color = mix(final_color, vec3(1), alpha);
        }
    }
    #endif
    
    {
        vec3 sphere_c = texelFetch(iChannel0, ivec2(BUFFER_D_SPHERE_PREV_FRAME_POSITION, BUFFER_D_MISC_DATA_ROW), 0).rgb;
        
        vec3 C = sphere_c - ray_O;
        
        // Get vector from camera to sphere center in terms of V and a vector orthonormal to V
        // Use this information for anti-aliasing

        // (If this code seems like overkill, I figured it out for my bubbles shader and so
        //  I happened to have it available)
        
        float proj = dot(V, C);
        
        vec3 U = C - proj*V;
        
        float dist_from_center = length(U);

        U /= dist_from_center;
        
        float blur_scale = pix_scale * proj;

        float pix_dist_blurred = (dist_from_center - SPHERE_RADIUS) / blur_scale;
        
        if (proj > 0. && pix_dist_blurred < 0.75) { // skip if pixel is too far from sphere
            vec3 W = V;
            
            if (pix_dist_blurred > -0.75) {
                // If pixel is close to edge of sphere, choose a good point on the sphere to use
                // (like using centroid in typical graphics pipeline anti-aliasing)
                
                // Function that gets the amount to shift, so point is approximate centroid of the part of the sphere covered by the pixel
                float shift = blur_scale * CUBIC(pix_dist_blurred, -0.27758603, -0.56839415, -0.1731804, 0.1215896);
                
                W = normalize(C - (dist_from_center + shift) * U);
                
                // W is now used as the view ray instead of V
            }
            
            float t = intersect_sphere(sphere_c, SPHERE_RADIUS, W, ray_O);
        
            vec3 p = ray_O + t*W - sphere_c;
            
            p *= 1./SPHERE_RADIUS;
            
            // Get spherical coordinates
            float theta = asin(max(-1., min(1., p.y)));
            float phi = atan(p.z, p.x);
            
            // Get row coordinate for mesh
            float fi = float(MESH_SPHERE_ROWS) * (0.5 + 1./PI * theta);
            
            fi -= 0.5;
            
            if (phi < 0.) {
                phi += 2.*PI;
            }

            // Get column coordinate for mesh
            float fj = float(MESH_SPHERE_COLUMNS) / (2.*PI) * phi;
            
            fj -= 0.5;
            
            int base_x = MESH_X_OFFSET_SPHERE;
            int columns = MESH_SPHERE_COLUMNS;
            int rows = MESH_SPHERE_ROWS;

            int meshi0 = max(0, int(floor(fi)));
            
            meshi0 = min(MESH_SPHERE_ROWS-1, meshi0);
            
            int meshj = int(floor(fj));
            
            fj -= float(meshj);
            
            int meshj0 = meshj & (MESH_SPHERE_COLUMNS-1);
            int meshj1 = (meshj + 1)  & (MESH_SPHERE_COLUMNS-1);

            int meshi1 = meshi0 + 1;
            
            if (meshi1 >= MESH_SPHERE_ROWS) {
                meshi0 -= 1;
                meshi1 -= 1;
            }
            
            fi -= float(meshi0);
                
            vec4 C = get_interp_coefficients(fi);
            vec4 C2 = get_interp_coefficients(fj);
            
            int meshin1 = max(meshi0 - 1, 0);
            int meshi2 = min(meshi1 + 1, MESH_SPHERE_ROWS-1);

            int meshjn1 = (meshj0 - 1) & (MESH_SPHERE_COLUMNS-1);
            int meshj2 = (meshj1 + 1) & (MESH_SPHERE_COLUMNS-1);
            
            // For Catmull-Rom, use linear interpolation at top and bottom of sphere
            //      to avoid extrapolation (which can give weird values)
            #if INTERPOLATION == CATMULL_ROM
            if (meshi1 == meshi2 || meshin1 == meshi0) {
                C = vec4(0., 1. - fi, fi, 0.);
            }
            #endif

            vec3 v00, v01, v10, v11;
            
            vec3 c = (
                C.x*(C2.x*texelFetch(iChannel0, ivec2(base_x + int(meshjn1), int(meshin1)), 0).rgb 
                    + C2.y*texelFetch(iChannel0, ivec2(base_x + int(meshj0), int(meshin1)), 0).rgb
                    + C2.z*texelFetch(iChannel0, ivec2(base_x + int(meshj1), int(meshin1)), 0).rgb
                    + C2.w*texelFetch(iChannel0, ivec2(base_x + int(meshj2), int(meshin1)), 0).rgb
                    )
                + C.y*(C2.x*texelFetch(iChannel0, ivec2(base_x + int(meshjn1), int(meshi0)), 0).rgb 
                    + C2.y*(v00 = texelFetch(iChannel0, ivec2(base_x + meshj0, meshi0), 0).rgb)
                    + C2.z*(v01 = texelFetch(iChannel0, ivec2(base_x + meshj1, meshi0), 0).rgb)
                    + C2.w*texelFetch(iChannel0, ivec2(base_x + int(meshj2), int(meshi0)), 0).rgb
                    )
                + C.z*(C2.x*texelFetch(iChannel0, ivec2(base_x + int(meshjn1), int(meshi1)), 0).rgb 
                    + C2.y*(v10 = texelFetch(iChannel0, ivec2(base_x + meshj0, meshi1), 0).rgb)
                    + C2.z*(v11 = texelFetch(iChannel0, ivec2(base_x + meshj1, meshi1), 0).rgb)
                    + C2.w*texelFetch(iChannel0, ivec2(base_x + int(meshj2), int(meshi1)), 0).rgb
                    )
                + C.w*(C2.x*texelFetch(iChannel0, ivec2(base_x + int(meshjn1), int(meshi2)), 0).rgb 
                    + C2.y*texelFetch(iChannel0, ivec2(base_x + int(meshj0), int(meshi2)), 0).rgb
                    + C2.z*texelFetch(iChannel0, ivec2(base_x + int(meshj1), int(meshi2)), 0).rgb
                    + C2.w*texelFetch(iChannel0, ivec2(base_x + int(meshj2), int(meshi2)), 0).rgb
                    )
                    );
            
            float alpha = smoothstep(-0.75, 0.75, -pix_dist_blurred);
            
            // Clamp color before blending so bright values don't mess up anti-aliasing
            final_color = mix(final_color, gamut_clip(c), alpha);
        }
    }
    
    // Anti-alias the outer edges
    {
        vec3 P1 = (vec3(0., 0., 0.) - ray_O) * rotation_matrix;
        vec3 P2 = (vec3(0., 1., 0.) - ray_O) * rotation_matrix;
        vec3 P3 = (vec3(1., 1., 0.) - ray_O) * rotation_matrix;
        vec3 P4 = (vec3(1., 0., 0.) - ray_O) * rotation_matrix;
        
        P1.xy *= VIEW_ANGLE_FACTOR*iResolution.y / P1.z;
        P2.xy *= VIEW_ANGLE_FACTOR*iResolution.y / P2.z;
        P3.xy *= VIEW_ANGLE_FACTOR*iResolution.y / P3.z;
        P4.xy *= VIEW_ANGLE_FACTOR*iResolution.y / P4.z;
        
        float alpha = get_edge_antialias_alpha(fragCoord, P1.xy, P2.xy, 2.);
        alpha *= get_edge_antialias_alpha(fragCoord, P2.xy, P3.xy, 2.);
        alpha *= get_edge_antialias_alpha(fragCoord, P3.xy, P4.xy, 2.);
        alpha *= get_edge_antialias_alpha(fragCoord, P4.xy, P1.xy, 2.);
        
        final_color *= alpha;
    }
    
    fragColor = vec4(LINEAR_TO_SRGB(final_color), 1.0);
}


