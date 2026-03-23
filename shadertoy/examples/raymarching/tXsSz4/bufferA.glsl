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

// Since this is the first pass, it only needs to gathers light from the light source (not from all surfaces).

// iChannel1 contains sphere and light locations (BufferD)

vec3 get_point_for_patch(vec3 sphere_c, int index, float f_row, float f_column, out vec3 N) {
    if (index < MESH_OFFSET_SPHERE) {
        N = get_normal_for_patch_not_sphere(index);
        
        return get_point_for_patch_not_sphere(index, get_mesh_base_index(index), f_row, f_column);
    } else {
        return get_point_for_patch_on_sphere(sphere_c, index, f_row, f_column, N);
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int x = int(fragCoord.x);
    int y = int(fragCoord.y);
    
    if (y >= MESH_SQUARE_ROWS || x >= MESH_X_COUNT) {
        return;
    }
    
    vec3 sphere_c = texelFetch(iChannel1, ivec2(BUFFER_D_SPHERE_CURRENT_POSITION, BUFFER_D_MISC_DATA_ROW), 0).rgb;
    
    bool use_initial_data = iFrame == 0 || texelFetch(iChannel1, ivec2(BUFFER_D_MAGIC_NUMBER, BUFFER_D_MISC_DATA_ROW), 0) != MAGIC_NUMBER;
    
    if (use_initial_data) {
        sphere_c = SPHERE_INITIAL_POSITION;
    }
    
    bool is_sphere = x >= MESH_X_OFFSET_SPHERE;

    int base = is_sphere ? MESH_X_OFFSET_SPHERE : (x & ~(MESH_SQUARE_COLUMNS-1));
    int columns = is_sphere ? MESH_SPHERE_COLUMNS : MESH_SQUARE_COLUMNS;

    x -= base;
    base *= MESH_SQUARE_ROWS;

    
    float sum = 0.;

    int light_side_base;
    ivec2 light_i_minmax, light_j_minmax;
    
    if (use_initial_data) { 
        light_side_base = LIGHT_SIDE_INITIAL*MESH_COUNT_SQUARE;
        light_i_minmax = LIGHT_I_MINMAX_INITIAL;
        light_j_minmax = LIGHT_J_MINMAX_INITIAL;
    } else {
        int light_side;
        ivec2 val = floatBitsToInt(texelFetch(iChannel1, ivec2(BUFFER_D_LIGHT_DATA, BUFFER_D_MISC_DATA_ROW), 0).xy);
        
        light_side = unpack_light_side(val.x);
        light_i_minmax = unpack_light_i_minmax(val.x);
        light_j_minmax = unpack_light_j_minmax(val.y);
        
        light_side_base = light_side*MESH_COUNT_SQUARE;
    }
    
    float light_scale = get_light_scale(light_i_minmax, light_j_minmax);
    
    int receiving_patch_index = base + y*columns + x;
    
    #if SHOW_THIRD_BOUNCE
    if (base != light_side_base) {
        vec3 N1_a;
        vec3 P1_a = get_point_for_patch(sphere_c, receiving_patch_index, 0.25, 0.25, N1_a);
        vec3 N1_b;
        vec3 P1_b = get_point_for_patch(sphere_c, receiving_patch_index, 0.25, 0.75, N1_b);
        vec3 N1_c;
        vec3 P1_c = get_point_for_patch(sphere_c, receiving_patch_index, 0.75, 0.25, N1_c);
        vec3 N1_d;
        vec3 P1_d = get_point_for_patch(sphere_c, receiving_patch_index, 0.75, 0.75, N1_d);
        
        // indexes of patches for which form factor is precomputed
        ivec2 edge_ff = get_edge_form_factor_indexes(base, x, y);
        
        // precomputing some things to speed up the shadow checks in the inner loop (not used if is_sphere)
        vec3 sph_delta_a = P1_a-sphere_c;
        vec3 sph_delta_b = P1_b-sphere_c;
        vec3 sph_delta_c = P1_c-sphere_c;
        vec3 sph_delta_d = P1_d-sphere_c;
        
        float sph_val_a = dot(sph_delta_a,sph_delta_a) - SPHERE_RADIUS*SPHERE_RADIUS;
        float sph_val_b = dot(sph_delta_b,sph_delta_b) - SPHERE_RADIUS*SPHERE_RADIUS;
        float sph_val_c = dot(sph_delta_c,sph_delta_c) - SPHERE_RADIUS*SPHERE_RADIUS;
        float sph_val_d = dot(sph_delta_d,sph_delta_d) - SPHERE_RADIUS*SPHERE_RADIUS;
        
        int light_row_inc = MESH_SQUARE_COLUMNS - 1 + light_j_minmax.x - light_j_minmax.y;
        int light_cell_count = (light_i_minmax.y - light_i_minmax.x + 1) * (light_j_minmax.y - light_j_minmax.x + 1);
        int light_index_start = light_side_base + light_i_minmax.x*MESH_SQUARE_COLUMNS + light_j_minmax.x;
        
        int j = light_j_minmax.x;
        int index_src = light_index_start;
        
        for (int lcell=0; lcell < light_cell_count; lcell++) {
            vec3 N2 = get_normal_for_patch_not_sphere(index_src);
            
            float ffsum = 0.0;

            for (float sample_src_i = 0.25; sample_src_i < 1.; sample_src_i += 0.5) {
                for (float sample_src_j = 0.25; sample_src_j < 1.; sample_src_j += 0.5) {
                    vec3 P2 = get_point_for_patch_not_sphere(index_src, light_side_base, sample_src_i, sample_src_j);
                    
                    ffsum += form_factor(sph_delta_a, sph_val_a, P1_a, P2, N1_a, N2, ! is_sphere);
                    ffsum += form_factor(sph_delta_b, sph_val_b, P1_b, P2, N1_b, N2, ! is_sphere);
                    ffsum += form_factor(sph_delta_c, sph_val_c, P1_c, P2, N1_c, N2, ! is_sphere);
                    ffsum += form_factor(sph_delta_d, sph_val_d, P1_d, P2, N1_d, N2, ! is_sphere);              
                }
            }
            
            // Form factor for pair of squares that are at right angles to one another, sharing an edge
            // Value is expected to be multiplied by -PI * 16. (factor is divided out at the end of the loop)
            // Value is also expected to be divided by receiving patch area (we multiply by area later to get flux)
            //      hence the multiplication by SQUARE_PATCH_RECIPROCAL_AREA
            // (difference is less noticeable in this pass though)
            if (index_src==edge_ff.x || index_src==edge_ff.y) {
                ffsum = -PI * 16. * 0.20004377607540316 * SQUARE_PATCH_RECIPROCAL_AREA;
            }
            
            sum += ffsum;

            index_src++;
            
            if (++j > light_j_minmax.y) {
                j = light_j_minmax.x;
                index_src += light_row_inc;
            }
        }
    }
    #endif
    
    // Computing the outbound flux for this patch

    // (Currently there's only one light and these are scene-wide constants, but applying them here leaves open the possibility of adding more lights.)
    vec3 flux_multiplier = light_scale * LIGHT_AMOUNT;
    
    // Getting irradiance from the integration performed by the above loops
    // 1./16. is the divisor for the integration sampling (which wasn't multiplied in the integration loop)
    // Area of each light source patch also wasn't multiplied in the integration loop, so do it now.
    vec3 final_color = sum * (-1./PI * 1./16. * SQUARE_PATCH_AREA) * flux_multiplier;
    
    // Multiply irradiance by albedo to get reflected part of radiosity
    final_color *= get_albedo(base);
    
    #if SHOW_SECOND_BOUNCE
    // Add radiant exitance (emitted component of radioisity) if any, to get total radiosity
    if (base == light_side_base && x >= light_j_minmax.x && x <= light_j_minmax.y && y >= light_i_minmax.x && y <= light_i_minmax.y) {
        final_color += flux_multiplier;
    }
    #endif

    // Compute outbound flux by multiplying by area (larger patches reflect more light and emit more light)
    // (could do this above, but want to be consistent with the other shaders)
    // Need to also multiply by some large number because otherwise the values are too small for 16-bit floating point
    final_color *= PATCH_FLUX_ENCODE_SCALE*area_for_patch(receiving_patch_index);

    fragColor = vec4(final_color, 1.0);
}


