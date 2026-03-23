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

#define BOUNCY 0 // if 1, use some alternative parameters (less useful as a global illumination test)

// NO_INTERPOLATION         = no interpolation (show patches)
// BILINEAR_INTERPOLATION   = bilinear interpolation
// CATMULL_ROM              = Catmull-Rom cubic spline with linear extrapolation at edges (Catmull-Rom extrapolation is too crazy)
// CUBIC_BSPLINE            = Cubic B-spline
// MITCHELL_NETRAVALI       = Mitchell-Netravali cubic spline
// (B-spline avoids ringing artifacts but I think it blurs the shadows too much, and Mitchell-Netravali doesn't seem to help much)
#define INTERPOLATION CATMULL_ROM

// This must be 8, 16, 32, or 64
//      16 is the default
//      32 should be ok if you have a fast GPU (may freeze your phone or iGPU)
//      64 will be slow even on a high-end GPU (will likely freeze your phone or iGPU, and won't work correctly for 16-bit float buffers)
// Note: Doubling this number multiplies the work required by 16!
#define MESH_SIZE 16

#define SHOW_LIGHT_SOURCE 1

// NOTE: series acceleration is disabled if these are not all set to 1
#define SHOW_DIRECT_LIGHT 1
#define SHOW_FIRST_BOUNCE 1
#define SHOW_SECOND_BOUNCE 1
#define SHOW_THIRD_BOUNCE 1

// if 1, use a linear combination of values from pass 1, pass 3, and pass4 as an estimate for the converged value
//  (will be missing light in places not reached by the first two or three bounces, but it will look much closer to the specified albedo)
#define USE_SERIES_ACCELERATION 1

// Bounds on the amount of extra light added (as multiple of difference between final two passes) so the series acceleration can't go too wildly off the rails
// I looked at a scatter plot of the error divided by delta, and 1-4 appeared to be a reasonable range.
#define USE_SERIES_ACCELERATION_SAFETY_BOUNDS_MIN 1.
#define USE_SERIES_ACCELERATION_SAFETY_BOUNDS_MAX 4.


// color and albedo of the surfaces
const vec3 ROOM_ALBEDO = vec3(0.85);
const vec3 LEFT_WALL_ALBEDO = vec3(0.85, 0.15, 0.15);
const vec3 RIGHT_WALL_ALBEDO = vec3(0.15, 0.65, 0.25);

#if BOUNCY == 0
const vec3 SPHERE_ALBEDO = vec3(0.85);
#else
const vec3 SPHERE_ALBEDO = vec3(0.95, 0.05, 0.1);
#endif

// This value will be divided by number of patches that cover the light
const vec3 LIGHT_AMOUNT = vec3(0.586 * float(MESH_SIZE*MESH_SIZE));

// interval (seconds) between switching light position randomly
const float LIGHT_CHANGE_INTERVAL = 4.;

// Initial light position (in case you want to test some specific position)
// i and j ranges are inclusive (values should be in range 0...MESH_SIZE-1 or 0...MESH_SIZE-1)
const int LIGHT_SIDE_INITIAL = 3; // 0=left, 1=right, 2=bottom, 3=top, 4=back
const ivec2 LIGHT_I_MINMAX_INITIAL = ivec2((MESH_SIZE>>1) - (MESH_SIZE>>3), (MESH_SIZE>>1) + (MESH_SIZE>>3) - 1);
const ivec2 LIGHT_J_MINMAX_INITIAL = ivec2((MESH_SIZE>>1) - (MESH_SIZE>>3), (MESH_SIZE>>1) + (MESH_SIZE>>3) - 1);


#if BOUNCY == 0 // using low velocity and low gravity for sphere ("floaty"?)

// must be less than 0.5
// if size is reduced, shadows may be inaccurate when the sphere is in a corner
const float SPHERE_RADIUS = 0.25;

const vec3 SPHERE_INITIAL_POSITION = vec3(1. - SPHERE_RADIUS, SPHERE_RADIUS, 0.5);

// initial velocity of the sphere
// NOTE: the y component of velocity is reset to this value's y component whenever the sphere collides with the floor
const vec3 SPHERE_INITIAL_VELOCITY = 0.25*vec3(-0.437, 0.8, 0.313);

// Vertical acceleration. Positive values don't currently work, sorry (zero works because of the a-posteriori collision checks)
const float GRAVITY = -0.1;

#else // BOUNCY

const float SPHERE_RADIUS = 0.05;
const vec3 SPHERE_INITIAL_POSITION = vec3(1. - SPHERE_RADIUS, SPHERE_RADIUS, 0.5);
const vec3 SPHERE_INITIAL_VELOCITY = vec3(-1.75, 2.384, 1.183);
const float GRAVITY = -2.7;

#endif


// if 1, use a hash of iDate.w so the light positions will be different in each run
#define MORE_RANDOM_LIGHT_POSITIONS 1


const float VIEW_ANGLE_FACTOR = 2.; // Lower value means wider FOV
const float CAMERA_Z = -2.;         // Values >= 0. are not supported. Values > -0.5 may cause unexpected clipping


// If 1, the numerical integration performed by pass 2 and 3 (in BufferB and BufferC) will be split into two parts.
// Two values for each patch need to be added together when used in pass 3 and 4.
// This means that for those two passes, more threads are doing the work, which may help GPU utilization.
// Doesn't make a big difference to frame rate, but it makes the animation much smoother on my iGPU.
// Not using this approach for pass4 because I didn't want to do twice as many texture fetches during the final render, and it
//      might also prevent applying safety bounds to the series acceleration.
// (Obviously the underlying problem is that this is all a really silly thing to be doing in pixel shaders, rather
//      than a compute shader which could use standard reduction techniques.)
#define SPLIT_PASSES 1


// Changing this is probably only useful if MORE_RANDOM_LIGHT_POSITIONS == 0
const uint HASH_SEED = 0x85d59261u;



// How to scale the light flux values so they are not too small to represent as 16-bit floats (in case the buffers are half-precision)
const float PATCH_FLUX_ENCODE_SCALE = 1024.;
const float PATCH_FLUX_DECODE_SCALE = 1./PATCH_FLUX_ENCODE_SCALE;

#define FP16_BUFFER_COMPATIBLE (MESH_SIZE < 64)


// Nothing below this point is configurable


// Constants used to specify interpolation type
#define NO_INTERPOLATION 0
#define BILINEAR_INTERPOLATION 1
#define CATMULL_ROM 2
#define CUBIC_BSPLINE 3
#define MITCHELL_NETRAVALI 4


const float PI = 3.141592653589793;


/*
    Mesh size restrictions in the code:
        Sizes are powers of 2
        For squares, number of rows and columns must be same
        Spheres must have same number of rows as squares
        Number of columns for spheres is twice the number of rows
*/
#if MESH_SIZE == 8
const int MESH_SQUARE_ROWS = 8;
const int MESH_SQUARE_COLUMNS = 8;
const int MESH_SQUARE_SHIFT = 3; // Always same for rows and columns, currently
const int MESH_SPHERE_ROWS = 8;
const int MESH_SPHERE_COLUMNS = 16;
#elif MESH_SIZE == 32
const int MESH_SQUARE_ROWS = 32;
const int MESH_SQUARE_COLUMNS = 32;
const int MESH_SQUARE_SHIFT = 5; // Always same for rows and columns, currently
const int MESH_SPHERE_ROWS = 32;
const int MESH_SPHERE_COLUMNS = 64;
#elif MESH_SIZE == 64
const int MESH_SQUARE_ROWS = 64;
const int MESH_SQUARE_COLUMNS = 64;
const int MESH_SQUARE_SHIFT = 6; // Always same for rows and columns, currently
const int MESH_SPHERE_ROWS = 64;
const int MESH_SPHERE_COLUMNS = 128;
#else // default to 16
const int MESH_SQUARE_ROWS = 16;
const int MESH_SQUARE_COLUMNS = 16;
const int MESH_SQUARE_SHIFT = 4; // Always same for rows and columns, currently
const int MESH_SPHERE_ROWS = 16;
const int MESH_SPHERE_COLUMNS = 32;
#endif

const int MESH_SPHERE_ROW_SHIFT = MESH_SQUARE_SHIFT + 1;

const int MESH_COUNT_SQUARE = MESH_SQUARE_ROWS*MESH_SQUARE_COLUMNS;
const int MESH_COUNT_SPHERE = MESH_SPHERE_ROWS*MESH_SPHERE_COLUMNS;

const float SQUARE_PATCH_RECIPROCAL_AREA = float(MESH_SQUARE_ROWS * MESH_SQUARE_COLUMNS);
const float SQUARE_PATCH_AREA = 1. / SQUARE_PATCH_RECIPROCAL_AREA;


// Much of the code uses contiguous indexes for mesh patches (1D rather than 2D)
const int MESH_OFFSET_LEFT = 0;
const int MESH_OFFSET_RIGHT = MESH_OFFSET_LEFT + MESH_COUNT_SQUARE;
const int MESH_OFFSET_BOTTOM = MESH_OFFSET_RIGHT + MESH_COUNT_SQUARE;
const int MESH_OFFSET_TOP = MESH_OFFSET_BOTTOM + MESH_COUNT_SQUARE;
const int MESH_OFFSET_BACK = MESH_OFFSET_TOP + MESH_COUNT_SQUARE;
const int MESH_OFFSET_SPHERE = MESH_OFFSET_BACK + MESH_COUNT_SQUARE;
const int MESH_COUNT = MESH_OFFSET_SPHERE + MESH_COUNT_SPHERE;

// Meshes are stored in the buffers as 2D blocks of values (to be more GPU-friendly)
// They are all placed at the top of the buffer (all have same start y value)
// The following constants give the starting x value for each mesh:
const int MESH_X_OFFSET_LEFT = 0;
const int MESH_X_OFFSET_RIGHT = MESH_X_OFFSET_LEFT + MESH_SQUARE_COLUMNS;
const int MESH_X_OFFSET_BOTTOM = MESH_X_OFFSET_RIGHT + MESH_SQUARE_COLUMNS;
const int MESH_X_OFFSET_TOP = MESH_X_OFFSET_BOTTOM + MESH_SQUARE_COLUMNS;
const int MESH_X_OFFSET_BACK = MESH_X_OFFSET_TOP + MESH_SQUARE_COLUMNS;
const int MESH_X_OFFSET_SPHERE = MESH_X_OFFSET_BACK + MESH_SQUARE_COLUMNS;
const int MESH_X_COUNT = MESH_X_OFFSET_SPHERE + MESH_SPHERE_COLUMNS;

// These constants are only used for encoding the location of the light
// (light can't be on the sphere, sorry!)
const int SIDE_LEFT = 0;
const int SIDE_RIGHT = 1;
const int SIDE_BOTTOM = 2;
const int SIDE_TOP = 3;
const int SIDE_BACK = 4;

// y coordinate for misc. data in BufferD
const int BUFFER_D_MISC_DATA_ROW = 2*MESH_SQUARE_ROWS;

// x coordinates for misc. data in BufferD
const int BUFFER_D_MAGIC_NUMBER = 0;
const int BUFFER_D_LIGHT_DATA = 1;
const int BUFFER_D_SPHERE_CURRENT_POSITION = 2;
const int BUFFER_D_SPHERE_PREV_FRAME_POSITION = 3;
const int BUFFER_D_SPHERE_P0 = 4;
const int BUFFER_D_SPHERE_V0 = 5;
const int BUFFER_D_SPHERE_DATA_MAX = 5; // largest of the above values
const int BUFFER_D_LIGHT_CURRENT_SEQNUM = 6;

const vec4 MAGIC_NUMBER = vec4(958,-293,-408,283);

#if SPLIT_PASSES
const int BUFFER_B_AND_C_ROW_COUNT = 2*MESH_SQUARE_ROWS;
#else
const int BUFFER_B_AND_C_ROW_COUNT = MESH_SQUARE_ROWS;
#endif



int get_mesh_base_index(int index) {
    return min(index & ~(MESH_COUNT_SQUARE-1), MESH_OFFSET_SPHERE);
}

ivec2 get_row_and_column(bool is_sphere, int offset) {
    int columns_mask = is_sphere ? (MESH_SPHERE_COLUMNS-1) : (MESH_SQUARE_COLUMNS-1);
    int row_shift = is_sphere ? MESH_SPHERE_ROW_SHIFT : MESH_SQUARE_SHIFT;

    return ivec2(offset & columns_mask, offset >> row_shift);
}

// Although a contiguous range of indexes is used for all patches, most of the code is specialized to
// work with either the squares or the sphere (for performance reasons) hence the specialized functions here.

vec3 get_point_for_patch_on_sphere(vec3 sphere_c, int index, float f_row, float f_column, out vec3 N) {
    vec2 row_and_col = vec2(get_row_and_column(true, index - MESH_OFFSET_SPHERE));
    
    #if 1 // this should be better (especially for patches in the circle at the top and bottom of the sphere)
    
    float t = PI/float(MESH_SPHERE_ROWS) * row_and_col.y;
    float stheta0 = sin(t + PI*(-0.5));
    float stheta1 = sin(t + PI*(-0.5 + 1./float(MESH_SPHERE_ROWS)));
    float y = (1.-f_row)*stheta0 + f_row*stheta1;
    
    float cos_theta = sqrt(1. - y*y);
    
    #else // this might be faster but it doesn't seem to make much difference
    
    float theta = PI*(-0.5 + 1./float(MESH_SPHERE_ROWS) * (row_and_col.y + f_row));
    float y = sin(theta);
    float cos_theta = cos(theta);
    
    #endif

    float phi = 2. / float(MESH_SPHERE_COLUMNS) * PI*(row_and_col.x + f_column);

    float x = cos(phi)*cos_theta;
    float z = sin(phi)*cos_theta;

    N = vec3(x, y, z);
    
    return sphere_c + SPHERE_RADIUS * vec3(x, y, z);
}

vec3 get_normal_for_patch_not_sphere(int index) {
    int base = get_mesh_base_index(index);
    vec3 N;
    
    if (index < MESH_OFFSET_RIGHT) {
        N = vec3(1, 0, 0);
    } else if (index < MESH_OFFSET_BOTTOM) {
        N = vec3(-1, 0, 0);
    } else if (index < MESH_OFFSET_TOP) {
        N = vec3(0, 1, 0);
    } else if (index < MESH_OFFSET_BACK) {
        N = vec3(0, -1, 0);
    } else {
        N = vec3(0, 0, -1);
    }

    return N;
}

vec3 get_point_for_patch_not_sphere(int index, int base, float f_row, float f_column) {
    vec2 frow_and_col = vec2(get_row_and_column(false, index - base));

    float s = 1. / float(MESH_SQUARE_COLUMNS) * (frow_and_col.x + f_column);
    float t = 1. / float(MESH_SQUARE_ROWS) * (frow_and_col.y + f_row);
    
    vec3 P;

    if (base == MESH_OFFSET_LEFT) {
        P = vec3(0, t, s);
    } else if (base == MESH_OFFSET_RIGHT) {
        P = vec3(1, t, s);
    } else if (base == MESH_OFFSET_BOTTOM) {
        P = vec3(s, 0, t);
    } else if (base == MESH_OFFSET_TOP) {
        P = vec3(s, 1, t);
    } else {
        P = vec3(s, t, 1);
    }

    return P;
}

// This is one of the most performance-critical functions (used in the inner loops)
// sphere_check_value is precomputed value of dot(P1_sphere_c_delta, P1_sphere_c_delta) - SPHERE_RADIUS*SPHERE_RADIUS
// Returns -PI * form factor (final sum needs to be scaled)
float form_factor(vec3 P1_sphere_c_delta, float sphere_check_value, vec3 P1, vec3 P2, vec3 N1, vec3 N2, bool need_shadow_check) {
    vec3 V = P2 - P1;
    
    float d1 = dot(N1, V);
    float d2 = dot(N2, V);
    
    float dist_sq = dot(V, V);

    if (need_shadow_check) { // this is only done when neither P1 or P2 is on the sphere
        // Test if the discriminant in the sphere intersection formula is positive.
        // In this scene, if the line intersects the sphere, it's impossible for P1 and P2 to be on same side of sphere
        
        float b = dot(V, P1_sphere_c_delta);

        if (b*b > dist_sq * sphere_check_value) {
            return 0.;
        }
    } else {
        // P1 or P2 is on the sphere
        // Check if either normal is pointing away from the other point
        // Also check if the points are very close together (can't happen if neither point is on the sphere)
        // (if points are close together, assume they are simply in shadow to avoid precision issues)
        if (dist_sq < 2e-4 || d1 <= 0. || d2 >= 0.) {
            return 0.;
        }
    }
    
    return d1*d2 / (dist_sq*dist_sq);
}

// Simplified version of the above function, for case where one of the points is on the sphere.
// This is one of the most performance-critical functions (used in the inner loops)
// Returns -PI * form factor (final sum needs to be scaled)
float form_factor_no_sphere_check(vec3 P1, vec3 P2, vec3 N1, vec3 N2) {
    vec3 V = P2 - P1;

    float dist_sq = dot(V, V);

    // Also check if the points are very close together
    // (if points are close together, assume they are simply in shadow to avoid precision issues)
    if (dist_sq < 2e-4) {
        return 0.;
    }

    float d1 = dot(N1, V);
    float d2 = dot(N2, V);

    // Check if either normal is pointing away from the other point
    if (d1 <= 0. || d2 >= 0.) {
        return 0.;
    }
    
    return d1*d2 / (dist_sq*dist_sq);
}

float area_for_patch(int index) {
    if (index >= MESH_OFFSET_SPHERE) {
        float row = float((index - MESH_OFFSET_SPHERE) >> MESH_SPHERE_ROW_SHIFT);

        float theta1 = PI*(-0.5 + 1./float(MESH_SPHERE_ROWS)*row);
        float theta2 = PI*(-0.5 + 1./float(MESH_SPHERE_ROWS)*(row + 1.));

        return SPHERE_RADIUS*SPHERE_RADIUS * 2.*PI * 1./float(MESH_SPHERE_COLUMNS) * abs(sin(theta1) - sin(theta2));
    } else {
        return SQUARE_PATCH_AREA;
    }
}

// Functions for packing and unpacking the light data into integer bits that are safe to store as a 16-bit float
// Need to make sure no data is stored in bits that will be lost during conversion to/from 16-bit float,
//      also making sure that the bit pattern is not a NaN, or infinity, or denormal when converted to 16-bit

#if FP16_BUFFER_COMPATIBLE
ivec2 pack_light_info(int side_num, ivec2 i_minmax, ivec2 j_minmax) {
    return (ivec2(side_num | (i_minmax.x << 3) | (i_minmax.y << 8), (j_minmax.x << 3) | (j_minmax.y << 8)) << 13) | 0x40000000;
}

int unpack_light_side(int val) {
    return (val >> 13) & 7;
}

ivec2 unpack_light_i_minmax(int val) {
    return ivec2((val >> 16) & (MESH_SQUARE_ROWS-1), (val >> 21) & (MESH_SQUARE_ROWS-1));
}

ivec2 unpack_light_j_minmax(int val) {
    return ivec2((val >> 16) & (MESH_SQUARE_COLUMNS-1), (val >> 21) & (MESH_SQUARE_COLUMNS-1));
}
#else
ivec2 pack_light_info(int side_num, ivec2 i_minmax, ivec2 j_minmax) {
    return ivec2(side_num | (i_minmax.x << 3) | (i_minmax.y << 11), (j_minmax.x << 3) | (j_minmax.y << 11)) | 0x40000000;
}

int unpack_light_side(int val) {
    return val & 7;
}

ivec2 unpack_light_i_minmax(int val) {
    return ivec2((val >> 3) & (MESH_SQUARE_ROWS-1), (val >> 11) & (MESH_SQUARE_ROWS-1));
}

ivec2 unpack_light_j_minmax(int val) {
    return ivec2((val >> 3) & (MESH_SQUARE_COLUMNS-1), (val >> 11) & (MESH_SQUARE_COLUMNS-1));
}
#endif

float get_light_scale(ivec2 i_minmax, ivec2 j_minmax) { // i.e. divide by number of patches covered by light
    return 1. / float((i_minmax.y - i_minmax.x + 1)*(j_minmax.y - j_minmax.x + 1));
}

vec3 get_albedo(int base_index) {
    if (base_index==MESH_OFFSET_LEFT) {
        return LEFT_WALL_ALBEDO;
    } else if (base_index==MESH_OFFSET_RIGHT) {
        return RIGHT_WALL_ALBEDO;
    } else if (base_index==MESH_OFFSET_SPHERE) {
        return SPHERE_ALBEDO;
    } else {
        return ROOM_ALBEDO;
    }
}

// Form factors are precomputed for squares that are next to each other
// This is not for performance, but rather because numeric integration with just four points
//      on each patch is very inaccurate for those pairs.
// (assumes there won't be any shadow, which is not safe if the sphere size is reduced)
// To avoid performance impact, figure out what the mesh index would be for the other patch
//      for each of these cases to apply.
ivec2 get_edge_form_factor_indexes(int base, int x, int y) {
    ivec2 indexes = ivec2(-1);
    
    if (base==MESH_OFFSET_LEFT) {
        if (x==MESH_SQUARE_COLUMNS-1) {
            indexes.x = MESH_OFFSET_BACK + 0 + y*MESH_SQUARE_COLUMNS;
        }
        
        if (y==0) {
            indexes.y = MESH_OFFSET_BOTTOM + 0 + x*MESH_SQUARE_COLUMNS;
        } else if (y==MESH_SQUARE_ROWS-1) {
            indexes.y = MESH_OFFSET_TOP + 0 + x*MESH_SQUARE_COLUMNS;
        }
    } else if (base==MESH_OFFSET_RIGHT) {
        if (x==MESH_SQUARE_COLUMNS-1) {
            indexes.x = MESH_OFFSET_BACK + MESH_SQUARE_COLUMNS-1 + y*MESH_SQUARE_COLUMNS;
        }
        
        if (y==0) {
            indexes.y = MESH_OFFSET_BOTTOM + MESH_SQUARE_COLUMNS-1 + x*MESH_SQUARE_COLUMNS;
        } else if (y==MESH_SQUARE_ROWS-1) {
            indexes.y = MESH_OFFSET_TOP + MESH_SQUARE_COLUMNS-1 + x*MESH_SQUARE_COLUMNS;
        }
    } else if (base==MESH_OFFSET_BACK) {
        if (x==0) {
            indexes.x = MESH_OFFSET_LEFT + MESH_SQUARE_COLUMNS-1 + y*MESH_SQUARE_COLUMNS;
        } else if (x==MESH_SQUARE_COLUMNS-1) {
            indexes.x = MESH_OFFSET_RIGHT + MESH_SQUARE_COLUMNS-1 + y*MESH_SQUARE_COLUMNS;
        }
        
        if (y==0) {
            indexes.y = MESH_OFFSET_BOTTOM + (MESH_SQUARE_ROWS-1)*MESH_SQUARE_COLUMNS + x;
        } else if (y==MESH_SQUARE_ROWS-1) {
            indexes.y = MESH_OFFSET_TOP + (MESH_SQUARE_ROWS-1)*MESH_SQUARE_COLUMNS + x;
        }
    } else if (base==MESH_OFFSET_TOP) {
        if (x==0) {
            indexes.x = MESH_OFFSET_LEFT + (MESH_SQUARE_ROWS-1)*MESH_SQUARE_COLUMNS + y;
        } else if (x==MESH_SQUARE_COLUMNS-1) {
            indexes.x = MESH_OFFSET_RIGHT + (MESH_SQUARE_ROWS-1)*MESH_SQUARE_COLUMNS + y;
        }
        
        if (y==MESH_SQUARE_ROWS-1) {
            indexes.y = MESH_OFFSET_BACK + (MESH_SQUARE_ROWS-1)*MESH_SQUARE_COLUMNS + x;
        }
    } else if (base==MESH_OFFSET_BOTTOM) {
        if (x==0) {
            indexes.x = MESH_OFFSET_LEFT + 0*MESH_SQUARE_COLUMNS + y;
        } else if (x==MESH_SQUARE_COLUMNS-1) {
            indexes.x = MESH_OFFSET_RIGHT + 0*MESH_SQUARE_COLUMNS + y;
        }
        
        if (y==MESH_SQUARE_ROWS-1) {
            indexes.y = MESH_OFFSET_BACK + 0*MESH_SQUARE_COLUMNS + x;
        }
    }
   
    return indexes;
}

