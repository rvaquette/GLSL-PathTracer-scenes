//MIT License

//Copyright (c) [2020] [Ender Doe]

//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

#define LEARNING_RATE 0.005
#define CLIP_DURATION 3.
#define TRAIN_DURATION (CLIP_DURATION * 20.)
#define PI 3.1415926535897932384626433832

// Each frag has an independent neural net composed
// of relu -> reulu -> (relu, relu, relu); a shape of (1,1,3)
// Buffer A is the shader being learned
// Buffer B C D are the bias and weights for nodes per frag
// There is some duplicated computation, trading storage for re compute
// Layers are updated one at a time so training is very stochastic

float getT(float iTime){
 return 0.5 + 0.5 * cos(iTime * PI);
}
float rnd(vec2 n) {
    return fract(sin(dot(n.xy, vec2(12.9898, 78.233)))* 43758.5453);
}

// alternate getT which randomly samples t values, pretty interesting
// float getT(float iTime){
// return step(TRAIN_DURATION, iTime) * mod(iTime, CLIP_DURATION) +
//     (1. - step(TRAIN_DURATION, iTime)) * rnd(vec2(iTime, iTime + 0.3));
//}


float relu(float x) {
    return max(0., x);
}

float reluD(float x) {
    return step(0., x);
}


float meanSquaredError (vec3 groundTruth, vec3 prediction) {
    vec3 diff = groundTruth - prediction;
    float loss = ((diff.x * diff.x)+(diff.y * diff.y)+(diff.z*diff.z)) * (1./3.);
 
 return loss;
}

// CIE XYZ, color space
//https://arxiv.org/pdf/1902.00267.pdf
mat3 CIE_XYZ_MAT = mat3(
    0.489989, 0.310008, 0.2,
    0.176962, 0.81240, 0.010,
    0, 0.01, 0.99
);
vec3 meanSquaredErrorGrad (vec3 groundTruth, vec3 prediction) {
    vec3 predXYZ = CIE_XYZ_MAT * prediction;
    vec3 truthXYZ = CIE_XYZ_MAT * groundTruth;
    return CIE_XYZ_MAT * vec3(
        (predXYZ.r - truthXYZ.r),
        (predXYZ.g - truthXYZ.g),
        (predXYZ.b - truthXYZ.b) 
    ); 
}


vec3 forwardPropagationPrediction(float t, vec4 w1_b1_w2_b2, vec4 w3_b3_w4_b4, vec4 w5_b5_w6_b6)
{
    float a1 = relu(w1_b1_w2_b2.x *  t + w1_b1_w2_b2.y);
    float a2 = relu(w1_b1_w2_b2.z * a1 + w1_b1_w2_b2.w);
    float a3 = relu(w3_b3_w4_b4.x * a2 + w3_b3_w4_b4.y);
    
    float r = relu(w3_b3_w4_b4.z * a3 + w3_b3_w4_b4.w);
    float g = relu(w5_b5_w6_b6.x * a3 + w5_b5_w6_b6.y);
    float b = relu(w5_b5_w6_b6.z * a3 + w5_b5_w6_b6.w);
    
    return vec3(r, g, b);
}

vec4 updatedParametersBufferB(float t, vec4 w1_b1_w2_b2, vec4 w3_b3_w4_b4, vec4 w5_b5_w6_b6, vec3 Y){
    float a1 = relu(w1_b1_w2_b2.x *  t + w1_b1_w2_b2.y);
    float a2 = relu(w1_b1_w2_b2.z * a1 + w1_b1_w2_b2.w);
    float a3 = relu(w3_b3_w4_b4.x * a2 + w3_b3_w4_b4.y);
    float r = relu(w3_b3_w4_b4.z * a3 + w3_b3_w4_b4.w);
    float g = relu(w5_b5_w6_b6.x * a3 + w5_b5_w6_b6.y);
    float b = relu(w5_b5_w6_b6.z * a3 + w5_b5_w6_b6.w);
    
    vec3 prediction = forwardPropagationPrediction(t, w1_b1_w2_b2, w3_b3_w4_b4, w5_b5_w6_b6);
    vec3 lossGrad = meanSquaredErrorGrad(Y, prediction);
    float bD =  reluD(w5_b5_w6_b6.z * a3 + w5_b5_w6_b6.w);
    float gD =  reluD(w5_b5_w6_b6.x * a3 + w5_b5_w6_b6.y);
    float rD =  reluD(w3_b3_w4_b4.z * a3 + w3_b3_w4_b4.w);
    float a3D =  reluD(w3_b3_w4_b4.x * a2 + w3_b3_w4_b4.y);
    float a2D =  reluD(w1_b1_w2_b2.z * a1 + w1_b1_w2_b2.w);
    float a1D =  reluD(w1_b1_w2_b2.x *  t + w1_b1_w2_b2.y);
    float layer3D = dot(vec3(w3_b3_w4_b4.z, w5_b5_w6_b6.x, w5_b5_w6_b6.z), vec3(rD * lossGrad.r, gD * lossGrad.g, bD * lossGrad.z));
    
    return vec4(
        w1_b1_w2_b2.x - LEARNING_RATE * (a1D * (a2D * w1_b1_w2_b2.z) * (a3D * w3_b3_w4_b4.x) * layer3D) * t,
        w1_b1_w2_b2.y - LEARNING_RATE * (a1D * (a2D * w1_b1_w2_b2.z) * (a3D * w3_b3_w4_b4.x) * layer3D),
        w1_b1_w2_b2.z - LEARNING_RATE * (a2D * (a3D * w3_b3_w4_b4.x) * layer3D) * a1,
        w1_b1_w2_b2.w - LEARNING_RATE * (a2D * (a3D * w3_b3_w4_b4.x) * layer3D)
    );
}
vec4 updatedParametersBufferC(float t, vec4 w1_b1_w2_b2, vec4 w3_b3_w4_b4, vec4 w5_b5_w6_b6, vec3 Y){
    float a1 = relu(w1_b1_w2_b2.x *  t + w1_b1_w2_b2.y);
    float a2 = relu(w1_b1_w2_b2.z * a1 + w1_b1_w2_b2.w);
    float a3 = relu(w3_b3_w4_b4.x * a2 + w3_b3_w4_b4.y);
    float r = relu(w3_b3_w4_b4.z * a3 + w3_b3_w4_b4.w);
    float g = relu(w5_b5_w6_b6.x * a3 + w5_b5_w6_b6.y);
    float b = relu(w5_b5_w6_b6.z * a3 + w5_b5_w6_b6.w);
    
    vec3 prediction = forwardPropagationPrediction(t, w1_b1_w2_b2, w3_b3_w4_b4, w5_b5_w6_b6);
    vec3 lossGrad = meanSquaredErrorGrad(Y, prediction);
    
    float bD =  reluD(w5_b5_w6_b6.z * a3 + w5_b5_w6_b6.w);
    float gD =  reluD(w5_b5_w6_b6.x * a3 + w5_b5_w6_b6.y);
    float rD =  reluD(w3_b3_w4_b4.z * a3 + w3_b3_w4_b4.w);
    float a3D =  reluD(w3_b3_w4_b4.x * a2 + w3_b3_w4_b4.y);
    float layer3D = dot(vec3(w3_b3_w4_b4.z, w5_b5_w6_b6.x, w5_b5_w6_b6.z), vec3(rD * lossGrad.r, gD * lossGrad.g, bD * lossGrad.b));
    
    return vec4(
        w3_b3_w4_b4.x - LEARNING_RATE * (a3D * layer3D) * a2,
        w3_b3_w4_b4.y - LEARNING_RATE * (a3D * layer3D),
        w3_b3_w4_b4.z - LEARNING_RATE * (rD * lossGrad.r) * a3,
        w3_b3_w4_b4.w - LEARNING_RATE * (rD * lossGrad.r)
    );
}
vec4 updatedParametersBufferD(float t, vec4 w1_b1_w2_b2, vec4 w3_b3_w4_b4, vec4 w5_b5_w6_b6, vec3 Y){
    float a1 = relu(w1_b1_w2_b2.x *  t + w1_b1_w2_b2.y);
    float a2 = relu(w1_b1_w2_b2.z * a1 + w1_b1_w2_b2.w);
    float a3 = relu(w3_b3_w4_b4.x * a2 + w3_b3_w4_b4.y);
    float r  = relu(w3_b3_w4_b4.z * a3 + w3_b3_w4_b4.w);
    float g  = relu(w5_b5_w6_b6.x * a3 + w5_b5_w6_b6.y);
    float b  = relu(w5_b5_w6_b6.z * a3 + w5_b5_w6_b6.w);
    
    vec3 prediction = forwardPropagationPrediction(t, w1_b1_w2_b2, w3_b3_w4_b4, w5_b5_w6_b6);
    vec3 lossGrad = meanSquaredErrorGrad(Y, prediction);
    
    float bD =  reluD(w5_b5_w6_b6.z * a3 + w5_b5_w6_b6.w);
    float gD =  reluD(w5_b5_w6_b6.x * a3 + w5_b5_w6_b6.y);
   
    return vec4(
        w5_b5_w6_b6.x - LEARNING_RATE * (gD * lossGrad.g) * a3,
        w5_b5_w6_b6.y - LEARNING_RATE * (gD * lossGrad.g),
        w5_b5_w6_b6.z - LEARNING_RATE * (bD * lossGrad.b) * a3,
        w5_b5_w6_b6.w - LEARNING_RATE * (bD * lossGrad.b)
    );
}
