// Copyright © 2019-2023 HK-SHAO
// MIT Licensed: https://shao.fun/blog/w/taichi-ray-tracing.html

// 数学常量
const float ZERO = 0.0;
const float PI   = 3.141592653589;
const float TAU  = 2.0 * PI;

// Buffer A Shared
const ivec2 MEMORY_BOUNDARY = ivec2(4, 3);

const ivec2 PMOUSE     = ivec2(0, 0);
const ivec2 TARGET     = ivec2(1, 0);
const ivec2 TMOUSE     = ivec2(2, 0);

const ivec2 RESOLUTION = ivec2(0, 1);
const ivec2 POSITION   = ivec2(1, 1);
const ivec2 ROTATION   = ivec2(2, 1);

const ivec2 MOVING     = ivec2(0, 2);

mat3 CameraRotation(vec2 m) {
    m *= mat2(vec2(0, -1), vec2(1, 0));
    vec2 s = sin(m), c = cos(m);
    
    mat3 rotX = mat3(1.0, 0.0, 0.0, 0.0, c.x, s.x, 0.0, -s.x, c.x);
    mat3 rotY = mat3(c.y, 0.0, -s.y, 0.0, 1.0, 0.0, s.y, 0.0, c.y);
    
    return rotY * rotX;
}

// Update History

// next: https://www.shadertoy.com/view/Dtj3DG

// 2023.01.12
// 1. ~~use a cheaper way for calculating orthonormal basis.~~
// 2. use branchlessONB to building an Orthonormal Basis.

// 2022.12.30
// 1. fix blackened colors caused by incorrect light absorption.
// 2. that also improved the frame rate.
// 3. correct cumulative brightness in the alpha channel instead of always being one.
// 4. which reduces noise.
// 5. ~~discard pixels that are too dark, it brighten the pixel quality.~~

// 2022.12.26
// 1. enables metal to be used in IOR.
// 2. small optimization of performance.
// 3. simplified reflection operations.
// 4. use plain black background.

// 2022.12.24
// 1. fixed camera jamming when looking up and down.

// 2022.12.23
// 1. fix the blackening of rough transparent material, it improved the frame rate.
// 2. fix the camera misalignment when full screen.
// 3. fix the inability to propagate reflected light inside an object.
// 4. optimize the judgment about self-luminous light source.
// 5. some formatting optimizations and minor efficiency optimizations.
// 6. gamma correction for skybox.

// 2022.12.21
// 1. make the rotation of the view smooth.
// 2. automatically perform noise reduction when stopping movement.
// 3. hold down space to force a screen refresh.
