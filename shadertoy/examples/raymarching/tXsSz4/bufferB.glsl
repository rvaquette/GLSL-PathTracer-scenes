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

// Second light gathering pass. It gathers light from all surfaces.
// (could skip parts of the surface on same side as light, but that optimization is not implemented)

// In order to get slightly better performance, it does it in two halves (so the next pass will need to add the halves together).
// Otherwise there would be too few active threads and GPU utilization would be poor.
// (disabled if SPLIT_PASSES == 0)

// Messy because unfortunately I had to specialize parts of the loop to improve frame rate on an iGPU
// Much of this code is identical to BufferC and BufferD shaders, sorry. 
// I'm wary of moving complex code into functions (especially passing textures as parameters, as Shadertoy forces you to do with Common
//      functions) because of problems with WebGL shader compilation in Windows.

// iChannel0 is output of previous pass (BufferA)
// iChannel1 is previous content of BufferD (stores sphere and light locations)

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int x = int(fragCoord.x);
    int y = int(fragCoord.y);
    
    if (y >= BUFFER_B_AND_C_ROW_COUNT || x >= MESH_X_COUNT) {
        return;
    }
    
    vec3 sphere_c = texelFetch(iChannel1, ivec2(BUFFER_D_SPHERE_CURRENT_POSITION, BUFFER_D_MISC_DATA_ROW), 0).rgb;
    
    if (iFrame == 0 || texelFetch(iChannel1, ivec2(BUFFER_D_MAGIC_NUMBER, BUFFER_D_MISC_DATA_ROW), 0) != MAGIC_NUMBER) {
        sphere_c = SPHERE_INITIAL_POSITION;
    }


    #if SPLIT_PASSES
    bool is_second_half = y >= MESH_SQUARE_ROWS;
    
    y &= MESH_SQUARE_ROWS - 1;
    #endif

    
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

        int index_src, end_index;
        
        #if SPLIT_PASSES
        if ( ! is_second_half) {
            index_src = 0;
            end_index = base < MESH_OFFSET_TOP ? MESH_OFFSET_BACK : MESH_OFFSET_TOP;
        } else {
            index_src = base < MESH_OFFSET_TOP ? MESH_OFFSET_BACK : MESH_OFFSET_TOP;
            end_index = base == MESH_OFFSET_BACK ? MESH_OFFSET_BACK : MESH_OFFSET_SPHERE;
        }
        #else
        index_src = 0;
        end_index = base == MESH_OFFSET_BACK ? MESH_OFFSET_BACK : MESH_OFFSET_SPHERE;
        #endif
        
        for ( ; index_src < min(0, iFrame) + end_index; index_src++) {
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
            
            sum += rad * ffsum;
        }
        
        #if SPLIT_PASSES
        if (is_second_half)
        #endif
        
        {
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

                // get outbound flux for patch (radiosity times patch area)
                vec3 rad = texelFetch(iChannel0, ivec2(MESH_X_OFFSET_SPHERE + row_and_col.x, row_and_col.y), 0).rgb;
            
                sum += rad * ffsum;
            }
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
        
        int index_src, end_index;
        
        #if SPLIT_PASSES
        if ( ! is_second_half) {
            index_src = 0;
            end_index = MESH_OFFSET_TOP;
        } else {
            index_src = MESH_OFFSET_TOP;
            end_index = MESH_OFFSET_SPHERE;
        }
        #else
        index_src = 0;
        end_index = MESH_OFFSET_SPHERE;
        #endif
        
        for ( ; index_src < min(0, iFrame) + end_index; index_src++) {
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
    
    #if SHOW_FIRST_BOUNCE

    #if SPLIT_PASSES
    if (is_second_half)
    #endif
    {
        // Add radiant exitance (emitted component of radiosity) if any, to get total radiosity
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
            final_color += get_light_scale(light_i_minmax, light_j_minmax) * LIGHT_AMOUNT;
        }
    }
    #endif
    
    // compute outbound flux by multiplying by area (larger patches reflect more light and emit more light)
    // Need to also multiply by some large number because otherwise the values are too small for 16-bit floating point
    final_color *= PATCH_FLUX_ENCODE_SCALE * area_for_patch(receiving_patch_index);

    fragColor = vec4(final_color, 1.0);
}


