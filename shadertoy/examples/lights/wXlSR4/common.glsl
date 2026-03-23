const float INF = 1e6;
const float PI = radians(180.);
const float R0 = 3.;
const float R2 = 3.;
const int BSEG = 15;
const int FPS = 10;
const vec3 RGB = vec3(1.0,0.3,0.1);

const mat4 BSPLINE = 1./6. * mat4(
    -1, 3,-3, 1, 
     3,-6, 0, 4, 
    -3, 3, 3, 1, 
     1, 0, 0, 0);
     
const mat4 BEZIER = mat4(
    -1,  3, -3, 1,
     3, -6,  3, 0,
    -3,  3,  0, 0,
     1,  0,  0, 0);

const vec2[] SIG = vec2[](
    vec2(0.248, 0.479),
    vec2(0.428, 0.729),
    vec2(0.398, 0.940),
    vec2(0.292, 0.898),
    vec2(0.320, 0.490),
    vec2(0.396, 0.284),
    vec2(0.328, 0.201),
    vec2(0.315, 0.229),
    vec2(0.509, 0.529),
    vec2(0.514, 0.395),
    vec2(0.575, 0.373),
    vec2(0.620, 0.501),
    vec2(0.732, 0.270),
    vec2(0.753, 0.081),
    vec2(0.684, 0.095),
    vec2(0.85 , 0.509),
    vec2(0.895, 0.620));

