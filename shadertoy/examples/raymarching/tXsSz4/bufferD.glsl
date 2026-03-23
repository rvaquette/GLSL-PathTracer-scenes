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

// Final light gathering pass. It gathers light from all surfaces.

// BufferD also stores the sphere position and velocity, and the light position, so this shader updates those

// Messy because unfortunately I had to specialize parts of the loop to improve frame rate on an iGPU
// Much of this code is identical to BufferB and BufferC shaders, sorry. 
// I'm wary of moving complex code into functions (especially passing textures as parameters, as Shadertoy forces you to do with Common
//      functions) because of problems with WebGL shader compilation in Windows.

// iChannel0 is output of previous pass (BufferC)
// iChannel1 is previous content of BufferD
// iChannel2 is output of first pass, i.e. BufferA (not required if USE_SERIES_ACCELERATION is 0)
// output of second pass is not used for series acceleration

uint hash_fn1(uint h) { // fmix32 with added constant for seed
    h ^= h >> 16;

    h = h*0x85ebca6bu + HASH_SEED;

    h ^= h >> 13;

    h = h*0xc2b2ae35u;

    return h ^ (h >> 16);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int x = int(fragCoord.x);
    int y = int(fragCoord.y);
    
    if (y >= MESH_SQUARE_ROWS || x >= MESH_X_COUNT) {
        if (y == BUFFER_D_MISC_DATA_ROW && x == BUFFER_D_MAGIC_NUMBER) {
            fragColor = MAGIC_NUMBER;
        } else if (y == BUFFER_D_MISC_DATA_ROW && x == BUFFER_D_LIGHT_DATA) {
            bool use_initial_data = iFrame == 0 || texelFetch(iChannel1, ivec2(BUFFER_D_MAGIC_NUMBER, BUFFER_D_MISC_DATA_ROW), 0) != MAGIC_NUMBER;
            
            vec2 prev_val = texelFetch(iChannel1, ivec2(BUFFER_D_LIGHT_DATA, BUFFER_D_MISC_DATA_ROW), 0).xy;
            
            // Light position gets changed every LIGHT_CHANGE_INTERVAL seconds, so assign an integer sequence number to each interval and check if
            //      current number is different from last number (which must be encoded in a way supported by 16-bit float buffers).
            
            int prev_seqnum = (floatBitsToInt(texelFetch(iChannel1, ivec2(BUFFER_D_LIGHT_CURRENT_SEQNUM, BUFFER_D_MISC_DATA_ROW), 0).x) >> 13) & 0x3fff;
            
            vec2 new_val = prev_val;
            
            int seqnum = int(1./LIGHT_CHANGE_INTERVAL * iTime);
            
            if (use_initial_data || (seqnum & 0x3fff) != prev_seqnum) {
                ivec2 ival;
                
                if (use_initial_data) {
                    ival = pack_light_info(LIGHT_SIDE_INITIAL, LIGHT_I_MINMAX_INITIAL, LIGHT_J_MINMAX_INITIAL);
                } else {
                    #if MORE_RANDOM_LIGHT_POSITIONS
                    int h = int(hash_fn1(uint(iDate.w*1024.0)));
                    #else
                    int h = int(hash_fn1(uint(seqnum)));
                    #endif
                    
                    int side = h & 63;
                    
                    // Getting value mod 5 (probably a silly way to do it)
                    if (side >= 40) side -= 40;
                    if (side >= 20) side -= 20;
                    if (side >= 10) side -= 10;
                    if (side >= 5) side -= 5;
                    
                    ivec2 ivals = ivec2((h>>6)&(MESH_SQUARE_ROWS-1), (h>>(6 + MESH_SQUARE_SHIFT))&(MESH_SQUARE_ROWS-1));
                    ivec2 jvals = ivec2((h>>(6 + 2*MESH_SQUARE_SHIFT))&(MESH_SQUARE_COLUMNS-1), (h>>(6 + 3*MESH_SQUARE_SHIFT))&(MESH_SQUARE_COLUMNS-1));
                    
                    if (ivals.x > ivals.y) ivals = ivals.yx;
                    if (jvals.x > jvals.y) jvals = jvals.yx;
                    
                    ival = pack_light_info(side, ivals, jvals);
                }
                
                new_val = intBitsToFloat(ival);
                
                if (use_initial_data) prev_val = new_val;
            }
            
            // Store previous value in .zw so Image shader can use it
            fragColor = vec4(new_val, prev_val);
        } else if (y == BUFFER_D_MISC_DATA_ROW && x == BUFFER_D_LIGHT_CURRENT_SEQNUM) {
            // Store the current light position sequence number so we can test if it has changed in the next frame
            fragColor = vec4(intBitsToFloat((int(1./LIGHT_CHANGE_INTERVAL * iTime)<<13) | 0x40000000), 0., 0., 0.);
        } else if (y == BUFFER_D_MISC_DATA_ROW && x <= BUFFER_D_SPHERE_DATA_MAX) {
            bool use_initial_data = iFrame == 0 || texelFetch(iChannel1, ivec2(BUFFER_D_MAGIC_NUMBER, BUFFER_D_MISC_DATA_ROW), 0) != MAGIC_NUMBER;
            
            // Simple frictionless motion, elastic collision, and gravity simulation
            // Continuous collision detection, but with additional a-posteriori collision checks for robustness
        
            vec4 p = texelFetch(iChannel1, ivec2(BUFFER_D_SPHERE_P0, BUFFER_D_MISC_DATA_ROW), 0);
            vec3 v = texelFetch(iChannel1, ivec2(BUFFER_D_SPHERE_V0, BUFFER_D_MISC_DATA_ROW), 0).xyz;
            
            // Not used here -- just copied to BUFFER_D_SPHERE_PREV_FRAME_POSITION so the Image shader can use it
            vec3 p_old = texelFetch(iChannel1, ivec2(BUFFER_D_SPHERE_CURRENT_POSITION, BUFFER_D_MISC_DATA_ROW), 0).xyz;
            
            // "time 0" is stored in p.w (time at which position was p.xyz, and velocity was v.xyz)
            // This value is being stored in a buffer that might use a 16-bit float format (e.g. on mobile), so it needs to be kept small.
            // Probably the best solution would have been to encode the full 32-bit float value (or a fixed point value) across multiple texture values,
            //      but I decided to try changing the code to work only with times in the interval (0,4) instead :)
            
            float use_time = mod(iTime, 4.);
            
            if (use_initial_data) {
                p = vec4(SPHERE_INITIAL_POSITION.xyz, use_time);
                v = SPHERE_INITIAL_VELOCITY;
                p_old = p.xyz;
            }
            
            if (use_time < p.w) {
                p.w -= 4.;
            }
            
            float t = use_time - p.w; // current time relative to "time 0"
            
            // Find any (or at most 4) collisions that occurred in time interval (0, t)
            // If no collisions, jump ahead (updating p and v) to keep time values small
            for (int itr = 0; itr < 4; itr++) {
                // Get times of possible collisions relative to "time 0"
                
                // Walls are easy (the open side of the box is treated like a glass wall)
                // Only checking for collision with side that the sphere is moving towards
                //      so it shouldn't be possible to get trapped.
                float t_inter_x = v.x < 0. ? (SPHERE_RADIUS-p.x) / v.x : (1. - SPHERE_RADIUS - p.x) / v.x;
                float t_inter_z = v.z < 0. ? (SPHERE_RADIUS-p.z) / v.z : (1. - SPHERE_RADIUS - p.z) / v.z;
                
                float t_inter_floor, t_inter_ceil;
                
                vec3 p2 = p.xyz + t*v.xyz;
                
                p2.y += 0.5*GRAVITY*t*t;
                    
                vec3 v2 = v + t*GRAVITY;
                
                // First check if the sphere has already gotten too close to the ceiling or floor, in which case immediately bounce
                if (p2.y > 1. - SPHERE_RADIUS - 1e-6) {
                    t_inter_floor = 1e20;
                    t_inter_ceil = t;
                } else if (p2.y < SPHERE_RADIUS + 1e-6) {
                    t_inter_floor = t;
                    t_inter_ceil = 1e20;
                } else {
                    // Otherwise, get intersection with floor and/or ceiling by solving quadratic equations
                    
                    float disc1 = v.y*v.y - 2.*GRAVITY*(p.y - SPHERE_RADIUS);
                    
                    // Check for collision with floor regardless of current velocity because trajectory can curve down
                    if (disc1 >= 0.) { // (There should always be two intersections unless the sphere fell through the floor somehow)
                        disc1 = sqrt(disc1);
                        
                        // Always want the later intersection (GRAVITY is negative, so this is the one where we subtract disc1)
                        t_inter_floor = (-v.y - disc1) / GRAVITY;
                        
                        // if t_inter_floor < 0, it means the sphere has fallen through the floor somehow
                        // this situation will be caught by the a-posteriori collision check
                    } else {
                        t_inter_floor = 1e20;
                    }
                    
                    float disc2 = v.y*v.y - 2.*GRAVITY*(p.y - 1. + SPHERE_RADIUS);
                    
                    // Check for collision with ceiling only if sphere is currently moving towards it
                    if (v2.y > 0. && disc2 >= 0.) {
                        disc2 = sqrt(disc2);
                        
                        // Always want the first intersection (GRAVITY is negative, so this is the one where we add disc2)
                        t_inter_ceil = (-v.y + disc2) / GRAVITY;
                        
                        // (if t_inter_ceil <= 0, it means the sphere has already gone through the ceiling somehow)
                    } else {
                        t_inter_ceil = 1e20;
                    }
                }
                
                // Get time of first collision
                float t_inter = min(min(t_inter_x, t_inter_z), min(t_inter_floor, t_inter_ceil));
                
                // If no collision before t, and t is large, advance "time 0" by some power of 2 value
                if (t_inter > t) {
                    if (t >= 4.) t_inter = 4.;
                    else if (t >= 2.) t_inter = 2.;
                    else if (t >= 1.) t_inter = 1.;
                    else if (t >= 0.5) t_inter = 0.5;
                    else if (t >= 0.25) t_inter = 0.25;
                }
                
                if (t_inter > t) {
                    break;
                }
                
                p.xzw += vec3(t_inter*v.xz, t_inter);
                p.y += t_inter*v.y + 0.5*GRAVITY*t_inter*t_inter;

                v.y += GRAVITY*t_inter;

                // Handle bounces by setting corresponding components of position and velocity, avoiding
                //     precision loss (for v.y anyway) by using absolute value of initial velocity.
            
                if (t_inter==t_inter_floor || p.y < SPHERE_RADIUS + 1e-6) {
                    v.y = abs(SPHERE_INITIAL_VELOCITY.y);
                    p.y = SPHERE_RADIUS;
                } else if (t_inter==t_inter_ceil || p.y > 1. - SPHERE_RADIUS - 1e-6) {
                    v.y = -abs(v.y);
                    p.y = 1. - SPHERE_RADIUS;
                }

                if ((t_inter==t_inter_x && v.x < 0.) || p.x < SPHERE_RADIUS + 1e-6) {
                    v.x = abs(SPHERE_INITIAL_VELOCITY.x);
                    p.x = SPHERE_RADIUS;
                } else if ((t_inter==t_inter_x && v.x > 0.) || p.x > 1. - SPHERE_RADIUS - 1e-6) {
                    v.x = -abs(SPHERE_INITIAL_VELOCITY.x);
                    p.x = 1. - SPHERE_RADIUS;
                }
                
                if ((t_inter==t_inter_z && v.z < 0.) || p.z < SPHERE_RADIUS + 1e-6) {
                    v.z = abs(SPHERE_INITIAL_VELOCITY.z);
                    p.z = SPHERE_RADIUS;
                } else if ((t_inter==t_inter_z && v.z > 0.) || p.z > 1. - SPHERE_RADIUS - 1e-6) {
                    v.z = -abs(SPHERE_INITIAL_VELOCITY.z);
                    p.z = 1. - SPHERE_RADIUS;
                }
                
                t = use_time - p.w;

                // repeat to handle literal corner cases
            }
            
            // Other shaders want the current sphere position
            vec3 new_p = p.xyz + t*v;
            
            new_p.y += 0.5*GRAVITY*t*t;
           
            if (x==BUFFER_D_SPHERE_P0) fragColor = p;
            else if (x==BUFFER_D_SPHERE_V0) fragColor = vec4(v, 0.);
            else if (x==BUFFER_D_SPHERE_CURRENT_POSITION) fragColor = vec4(new_p, 0.);
            else if (x==BUFFER_D_SPHERE_PREV_FRAME_POSITION) fragColor = vec4(p_old, 0.); // store old position because it's still needed by Image
        }
        
        return;
    }
    
    vec3 sphere_c = texelFetch(iChannel1, ivec2(BUFFER_D_SPHERE_CURRENT_POSITION, BUFFER_D_MISC_DATA_ROW), 0).rgb;
    
    if (iFrame == 0 || texelFetch(iChannel1, ivec2(BUFFER_D_MAGIC_NUMBER, BUFFER_D_MISC_DATA_ROW), 0) != MAGIC_NUMBER) {
        sphere_c = SPHERE_INITIAL_POSITION;
    }
    
    bool is_sphere = x >= MESH_X_OFFSET_SPHERE;

    int base = is_sphere ? MESH_X_OFFSET_SPHERE : (x & ~(MESH_SQUARE_COLUMNS-1));
    int columns = is_sphere ? MESH_SPHERE_COLUMNS : MESH_SQUARE_COLUMNS;

    x -= base;
    base *= MESH_SQUARE_ROWS;
    

    int receiving_patch_index = base + y*columns + x;
    
    vec3 sum = vec3(0);
    
    if (base != MESH_OFFSET_SPHERE) {
        vec3 N1 = get_normal_for_patch_not_sphere(receiving_patch_index);
        
        vec3 P1_a = get_point_for_patch_not_sphere(receiving_patch_index, base, 0.25, 0.25);
        vec3 P1_b = get_point_for_patch_not_sphere(receiving_patch_index, base, 0.25, 0.75);
        vec3 P1_c = get_point_for_patch_not_sphere(receiving_patch_index, base, 0.75, 0.25);
        vec3 P1_d = get_point_for_patch_not_sphere(receiving_patch_index, base, 0.75, 0.75);
        
        // indexes of patches for which form factor is precomputed
        ivec2 edge_ff = get_edge_form_factor_indexes(base, x, y);
        
        // precomputing some things to speed up the shadow checks in the inner loop
        vec3 sph_delta_a = P1_a-sphere_c;
        vec3 sph_delta_b = P1_b-sphere_c;
        vec3 sph_delta_c = P1_c-sphere_c;
        vec3 sph_delta_d = P1_d-sphere_c;
        
        float sph_val_a = dot(sph_delta_a,sph_delta_a) - SPHERE_RADIUS*SPHERE_RADIUS;
        float sph_val_b = dot(sph_delta_b,sph_delta_b) - SPHERE_RADIUS*SPHERE_RADIUS;
        float sph_val_c = dot(sph_delta_c,sph_delta_c) - SPHERE_RADIUS*SPHERE_RADIUS;
        float sph_val_d = dot(sph_delta_d,sph_delta_d) - SPHERE_RADIUS*SPHERE_RADIUS;
        
        int end_index = base == MESH_OFFSET_BACK ? MESH_OFFSET_BACK : MESH_OFFSET_SPHERE;
        
        for (int index_src = 0; index_src < min(0, iFrame) + end_index; index_src++) {
            if (index_src == base) index_src += MESH_COUNT_SQUARE;
            
            float ffsum = 0.0;
            vec3 N2 = get_normal_for_patch_not_sphere(index_src);
            int base_src = get_mesh_base_index(index_src);
            
            for (float sample_i = 0.25; sample_i < 1.; sample_i += 0.5) {
                for (float sample_j = 0.25; sample_j < 1.; sample_j += 0.5) {
                    vec3 P2 = get_point_for_patch_not_sphere(index_src, base_src, sample_i, sample_j);
                    
                    ffsum += form_factor(sph_delta_a, sph_val_a, P1_a, P2, N1, N2, true);
                    ffsum += form_factor(sph_delta_b, sph_val_b, P1_b, P2, N1, N2, true);
                    ffsum += form_factor(sph_delta_c, sph_val_c, P1_c, P2, N1, N2, true);
                    ffsum += form_factor(sph_delta_d, sph_val_d, P1_d, P2, N1, N2, true);
                }
            }
            
            // Form factor for pair of squares that are at right angles to one another, sharing an edge
            // Value is expected to be multiplied by -PI * 16. (factor is divided out at the end of the loop)
            // Value is also expected to be divided by receiving patch area (we multiply by area later to get flux)
            //      hence the multiplication by SQUARE_PATCH_RECIPROCAL_AREA
            if (index_src==edge_ff.x || index_src==edge_ff.y) {
                ffsum = -PI * 16. * 0.20004377607540316 * SQUARE_PATCH_RECIPROCAL_AREA;
            }

            ivec2 row_and_col = get_row_and_column(false, index_src - base_src);

            // Shifting right by MESH_SQUARE_SHIFT gives the y part of a patch index, which happens to be the texture x offset
            //      here because number of rows and columns is the same in the square meshes
            // (Code should be refactored to detect when index_src has moved to the next mesh, and call more expensive functions
            //      to get both base_src and texture x offset, so they can be arbitrary.)
            row_and_col.x += base_src >> MESH_SQUARE_SHIFT;

            // get outbound flux for patch (radiosity times patch area)
            vec3 rad = texelFetch(iChannel0, row_and_col, 0).rgb;

            #if SPLIT_PASSES
            // add the second part of the flux for that patch
            rad += texelFetch(iChannel0, row_and_col + ivec2(0, MESH_SQUARE_ROWS), 0).rgb;
            #endif
            
            sum += rad * ffsum;
        }
        
        for (int index_src = MESH_OFFSET_SPHERE; index_src < min(0, iFrame) + MESH_COUNT; index_src++) {
            float ffsum = 0.0;
            
            for (float sample_i = 0.25; sample_i < 1.; sample_i += 0.5) {
                for (float sample_j = 0.25; sample_j < 1.; sample_j += 0.5) {
                    vec3 N2;
                    vec3 P2 = get_point_for_patch_on_sphere(sphere_c, index_src, sample_i, sample_j, N2);
                    
                    ffsum += form_factor_no_sphere_check(P1_a, P2, N1, N2);
                    ffsum += form_factor_no_sphere_check(P1_b, P2, N1, N2);
                    ffsum += form_factor_no_sphere_check(P1_c, P2, N1, N2);
                    ffsum += form_factor_no_sphere_check(P1_d, P2, N1, N2);
                }
            }

            ivec2 row_and_col = get_row_and_column(true, index_src - MESH_OFFSET_SPHERE);

            row_and_col.x += MESH_X_OFFSET_SPHERE;

            // get outbound flux for patch (radiosity times patch area)
            vec3 rad = texelFetch(iChannel0, row_and_col, 0).rgb;

            #if SPLIT_PASSES
            // add the second part of the flux for that patch
            rad += texelFetch(iChannel0, row_and_col + ivec2(0, MESH_SQUARE_ROWS), 0).rgb;
            #endif
            
            sum += rad * ffsum;
        }
    } else {
        vec3 N1_a;
        vec3 P1_a = get_point_for_patch_on_sphere(sphere_c, receiving_patch_index, 0.25, 0.25, N1_a);
        
        vec3 N1_b;
        vec3 P1_b = get_point_for_patch_on_sphere(sphere_c, receiving_patch_index, 0.25, 0.75, N1_b);

        vec3 N1_c;
        vec3 P1_c = get_point_for_patch_on_sphere(sphere_c, receiving_patch_index, 0.75, 0.25, N1_c);

        vec3 N1_d;
        vec3 P1_d = get_point_for_patch_on_sphere(sphere_c, receiving_patch_index, 0.75, 0.75, N1_d);
        
        for (int index_src = 0; index_src < min(0, iFrame) + MESH_OFFSET_SPHERE; index_src++) {
            vec3 N2 = get_normal_for_patch_not_sphere(index_src);
            int base_src = get_mesh_base_index(index_src);
            
            float ffsum = 0.0;
            
            for (float sample_i = 0.25; sample_i < 1.; sample_i += 0.5) {
                for (float sample_j = 0.25; sample_j < 1.; sample_j += 0.5) {
                    vec3 P2 = get_point_for_patch_not_sphere(index_src, base_src, sample_i, sample_j);
                    
                    ffsum += form_factor_no_sphere_check(P1_a, P2, N1_a, N2);
                    ffsum += form_factor_no_sphere_check(P1_b, P2, N1_b, N2);
                    ffsum += form_factor_no_sphere_check(P1_c, P2, N1_c, N2);
                    ffsum += form_factor_no_sphere_check(P1_d, P2, N1_d, N2);
                }
            }

            ivec2 row_and_col = get_row_and_column(false, index_src - base_src);

            // Shifting right by MESH_SQUARE_SHIFT gives the y part of a patch index, which happens to be the texture x offset
            //      here because number of rows and columns is the same in the square meshes
            // (Code should be refactored to detect when index_src has moved to the next mesh, and call more expensive functions
            //      to get both base_src and texture x offset, so they can be arbitrary.)
            row_and_col.x += base_src >> MESH_SQUARE_SHIFT;

            // get outbound flux for patch (radiosity times patch area)
            vec3 rad = texelFetch(iChannel0, row_and_col, 0).rgb;

            #if SPLIT_PASSES
            // add the second part of the flux for that patch
            rad += texelFetch(iChannel0, row_and_col + ivec2(0, MESH_SQUARE_ROWS), 0).rgb;
            #endif
            
            sum += rad * ffsum;
        }
    }
    
    // Get irradiance from the integration performed by the above loops
    // 1./16. is the divisor for the integration sampling (which wasn't multiplied in the loop)
    // -1./PI is another factor that was omitted for performance reasons
    // PATCH_FLUX_DECODE_SCALE is a decoding factor that should have been applied to values fetched from the buffer
    vec3 final_color = -1./PI * 1./16. * PATCH_FLUX_DECODE_SCALE * sum;
    
    // Multiply irradiance by albedo to get reflected part of radiosity
    final_color *= get_albedo(base);
    
    // NOTE: the output of this shader does not include the emitted part of radiosity because that would mess up the smoothing interpolation used in the final render
    
    
    #if USE_SERIES_ACCELERATION && SHOW_DIRECT_LIGHT && SHOW_FIRST_BOUNCE && SHOW_SECOND_BOUNCE && SHOW_THIRD_BOUNCE

    // Get radiant exitance (emitted component of radiosity) if any
    // This is not included in the output value, but needs to be subtracted from the previous passes' values for series acceleration
    // (or could include it in this pass's value temporarily, but then would need to subtract it again)
    vec3 emitted_radiosity = vec3(0.);
    
    {
        int light_side;
        ivec2 light_i_minmax, light_j_minmax;
        
        if (iFrame == 0 || texelFetch(iChannel1, ivec2(BUFFER_D_MAGIC_NUMBER, BUFFER_D_MISC_DATA_ROW), 0) != MAGIC_NUMBER) { 
            light_side = LIGHT_SIDE_INITIAL;
            light_i_minmax = LIGHT_I_MINMAX_INITIAL;
            light_j_minmax = LIGHT_J_MINMAX_INITIAL;
        } else {
            ivec2 val = floatBitsToInt(texelFetch(iChannel1, ivec2(BUFFER_D_LIGHT_DATA, BUFFER_D_MISC_DATA_ROW), 0).xy);
            
            light_side = unpack_light_side(val.x);
            light_i_minmax = unpack_light_i_minmax(val.x);
            light_j_minmax = unpack_light_j_minmax(val.y);
        }
        
        if (base == light_side*MESH_COUNT_SQUARE && x >= light_j_minmax.x && x <= light_j_minmax.y && y >= light_i_minmax.x && y <= light_i_minmax.y) {
            emitted_radiosity = get_light_scale(light_i_minmax, light_j_minmax) * LIGHT_AMOUNT;
        }
    }
    
    {
        // Scale the values from previous passes and subtract emitted component of radiosity so they match the value we are using for this pass (pass4)
        
        float scale = PATCH_FLUX_DECODE_SCALE / area_for_patch(receiving_patch_index);
        
        vec3 pass1 = scale*texelFetch(iChannel2, ivec2(fragCoord), 0).rgb - emitted_radiosity;
        
        vec3 pass3 = texelFetch(iChannel0, ivec2(fragCoord), 0).rgb;

        #if SPLIT_PASSES
        // add second part of flux value for pass3
        pass3 += texelFetch(iChannel0, ivec2(int(fragCoord.x), int(fragCoord.y) + MESH_SQUARE_ROWS), 0).rgb;
        #endif

        pass3 = scale*pass3 - emitted_radiosity;

        vec3 pass4 = final_color;
        
        /*
          I was trying to find an optimal factor for Successive Over-Relaxation, and I tried plugging multiple previous iteration
              values into least squares optimization (linear regression), arriving at these factors for 4 Jacobi iterations.
           Different factors may be needed for different scenes (or different parts of the scene) so I don't know how useful it is in production.
           Least squares factor for pass2 was very small, so I left that term out (I wonder if there is an interesting explanation for this)
           I chose to use factors that sum to 1 although this is not strictly necessary (otherwise the scene would be brightened or darkened
              by a constant factor).
        
           "Overrelaxation" for Jacobi iterations similarly computes some linear combination of the output of plain Jacobi iterations
                (but likely not the optimal one).

           I haven't yet found a mention of this approach in the literature (but tricks like computing "unshot radiosity" and adding
                it as an ambient term are used).
           Radiosity usually uses (more efficient) Gauss-Seidel or Southwell iterations, where the trick probably wouldn't apply.
           I'm only using Jacobi iterations because of Shadertoy limitations.

           It might seem like cheating, or deviating from physically-based methods, but the justification is that the result is a better
                approximation (in the least squares sense) of true radiosity than simply stopping after 4 iterations, and it's similar to
                (but better than) overrelaxation, which is a standard technique (with caveat that this might be only true for certain scenes,
                and different factors might be needed for different scenes). Likely it should be combined with heuristics.
        
           Optimal factors in my test scene (for reference, probably not useful):
                1 iteration (i.e. just uniformly brightening the direct illumination): 1.55648131
                2 iterations: -1.04410677   2.33088677
                3 iterations: -0.3501546   -2.81371846   3.91354126
                4 iterations:  0.50251172  -0.00687071  -4.60680061   5.14673214
                5 iterations: -0.15431121   1.22304458   0.82183848  -8.54643738   7.68658215
                6 iterations: -0.12238599  -0.23040211   2.29687337   0.39079672 -10.73858488   9.39628568
                7 iterations:  0.0501386   -0.42917315  -0.57671934   4.85683415  -0.84644954 -13.93106196  11.86946711
                8 iterations:  0.03361997   0.09671265  -0.98298705  -0.64599411   7.91240836  -3.29352597 -16.13602052  14.01715472
           But it's probably more stable/robust to use only the last few passes.
           
           Using just the last two passes (with factors summing to 1) is equivalent to adding a multiple of the final delta (see below).
           
        */
        
        final_color = 0.5*pass1 + - 4.65*pass3 + 5.15*pass4;
        
        // Safety bounds
        // Seems like a good idea since lighting is often going to be very different than the scene I optimized for.
        // I looked at a scatter plot of the error divided by delta, and 1-4 appeared to be a reasonable range
        vec3 delta = pass4 - pass3;
        
        final_color = clamp(final_color, pass4 + USE_SERIES_ACCELERATION_SAFETY_BOUNDS_MIN*delta,
                                         pass4 + USE_SERIES_ACCELERATION_SAFETY_BOUNDS_MAX*delta);
    }
    #endif

    fragColor = vec4(final_color, 1.0);
}


