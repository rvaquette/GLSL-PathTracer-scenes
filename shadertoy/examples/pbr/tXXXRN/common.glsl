/*
    Copyright (c) 2021 al-ro

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

#define PI 3.14159
#define TWO_PI (2.0 * PI)
#define HALF_PI (0.5 * PI)

#define GAMMA 2.2
#define INV_GAMMA (1.0/GAMMA)

// When 1, we sample the environment map mip levels, getting more blurred results. 
// See changes in BufferC. 
// This can be used with HDR environment maps to get rid of fireflies in specular reflections.
#define ENV_FILTERING 0

#define SH_SAMPLE_COUNT 1024.0
#define SH_LOW_SAMPLE_COUNT 128.0

#define BRDF_SAMPLE_COUNT 1024
#define BRDF_LOW_SAMPLE_COUNT 128

#if ENV_FILTERING == 1
    #define SAMPLE_COUNT 1024
    #define LOW_SAMPLE_COUNT 128
#else
    #define SAMPLE_COUNT 1024
    #define LOW_SAMPLE_COUNT 128
#endif

//  Variable iterator initializer to stop loop unrolling
#define ZERO (min(iFrame,0))

// Normal mapping will lead to an impossible surface where the view ray and normal dot product
// is negative. Using PBR, this leads to negative radiance and black artefacts at detail 
// fringes. See "Microfacet-based Normal Mapping for Robust Monte Carlo Path Tracing" by 
// Schüssler et al. for a discussion of a physically correct solution. 
// We just clamp the dot product with a normal to some small value.
const float minDot = 1e-5;

// Clamped dot product
float dot_c(vec3 a, vec3 b){
	return max(dot(a, b), minDot);
}

// Get orthonormal basis from surface normal
// https://graphics.pixar.com/library/OrthonormalB/paper.pdf
void pixarONB(vec3 n, out vec3 b1, out vec3 b2){
	float sign_ = n.z >= 0.0 ? 1.0 : -1.0;
	float a = -1.0 / (sign_ + n.z);
	float b = n.x * n.y * a;
	b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
	b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec3 gamma(vec3 col){
	return pow(col, vec3(INV_GAMMA));
}

vec3 inv_gamma(vec3 col){
	return pow(col, vec3(GAMMA));
}

float saturate(float x){
    return max(0.0, min(x, 1.0));
}

float modulo(float m, float n){
  return mod(mod(m, n) + n, n);
}
