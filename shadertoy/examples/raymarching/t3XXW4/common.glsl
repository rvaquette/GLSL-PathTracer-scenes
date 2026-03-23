#define RES    (iResolution.xy)
#define MINRES (min(RES.x, RES.y))
#define ZERO   (0)

const float pi  = 3.14159265359;
const vec3  v1  = vec3(1.0);
const vec3  v0  = vec3(0.0);
const vec3  vX  = vec3(1.0, 0.0, 0.0);
const vec3  vY  = vec3(0.0, 1.0, 0.0);
const vec3  vZ  = vec3(0.0, 0.0, 1.0);
const vec4  v41 = vec4(1.0);

//--------------------------------------------------------------------------
// keyboard conveniences
//
#define KEY_IS_DOWN(key, chan) (texelFetch(chan, ivec2(key, 0), 0).r > 0.0)
#define KEY_TOGGLED(key, chan) (texelFetch(chan, ivec2(key, 2), 0).r > 0.0)


//--------------------------------------------------------------------------
// ray stuff
//
struct ray_t {
    vec3  ro;
    vec3  rd;
    vec3  amt;   // [0, 1] amount of light left in the ray
    float side;  // -1 = inside, 1 = outside.
    bool  DLR;   // Diffuse Lighting Ray.
    float ior;   // index of refraction at ro.
};

struct hit_t {
    bool  hit;
    float t;
    vec3  pnt;
    vec3  nrm;
    uint  mtl;
};

struct mapSample_t {
    float dist;
    uint  mtl;
};
#define MST mapSample_t

struct mtl_t {
    float ior;
    float diffVsTrns;
    vec3  color;
    vec4  absorption;  // transmissive color, density.  eg (0.8, 0.7, 0.1, 30.0)
};


//--------------------------------------------------------------------------

// https://en.wikipedia.org/wiki/Schlick%27s_approximation
float schlickR0(in float n1, in float n2) {
    // same if n1 and n2 are swapped.
    float q  = (n1 - n2) / (n1 + n2);
    float q2 = q * q;
    return q2;
}

float schlick(in float R0, in float cosTheta) {
    float q  = 1.0 - cosTheta;
    float q5 = q * q * q * q * q;
    return R0 + ((1.0 - R0) * q5);
}

//--------------------------------------------------------------------------------
// famous indices
const float ior_air                =  1.0003;
const float ior_aerogel            =  1.03;
const float ior_ice                =  1.309;
const float ior_water              =  1.333;
const float ior_quartz             =  1.46;
const float ior_borosilicate_glass =  1.5168;
const float ior_diamond            =  2.42;
const float ior_shiny1             =  4.0;    // ad hoc
const float ior_mrr                =  1e2;    // ad hoc

//--------------------------------------------------------------------------

// fifo queue.
// This is a basic ringbuffer.
// NO ERROR CHECKING
//
// usage:
// #define Q_TYPE and Q_MAX_ENTRIES,
// then put Q_IMPLEMENTATION.
// (Q_MAX_ENTRIES is a uint)
//
// for example:
// #define Q_TYPE        ray_t
// #define Q_MAX_ENTRIES 16u
// Q_IMPLEMENTATION
//
// orion elenzil 2022.
#define Q_IMPLEMENTATION                           \
const uint gQCapacity = Q_MAX_ENTRIES;             \
const uint gQNumSlots = gQCapacity + 1u;           \
Q_TYPE gQ[gQNumSlots];                             \
uint gQHead = 0u;                                  \
uint gQTail = 0u;                                  \
                                                   \
uint QCount() {                                    \
    if (gQHead >= gQTail) {                        \
        return gQHead - gQTail;                    \
    }                                              \
    else {                                         \
        return gQNumSlots - (gQTail - gQHead);     \
    }                                              \
}                                                  \
                                                   \
uint QSpaceLeft() {                                \
    return gQCapacity - QCount();                  \
}                                                  \
                                                   \
bool QIsFull() {                                   \
    return QSpaceLeft() == 0u;                     \
}                                                  \
                                                   \
bool QIsEmpty() {                                  \
    return QCount() == 0u;                         \
}                                                  \
                                                   \
uint _QEnqueueIndex() {                            \
    gQHead = (gQHead + 1u) % gQNumSlots;           \
    return gQHead;                                 \
}                                                  \
                                                   \
uint _QDequeueIndex() {                            \
    gQTail = (gQTail + 1u) % gQNumSlots;           \
    return gQTail;                                 \
}                                                  \
                                                   \
void QEnqueue(Q_TYPE item) {                       \
    gQ[_QEnqueueIndex()] = item;                   \
}                                                  \
                                                   \
Q_TYPE QDequeue() {                                \
    return gQ[_QDequeueIndex()];                   \
}

//--------------------------------------------------------------------------

// https://iquilezles.org/articles/distfunctions
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

// https://iquilezles.org/articles/distfunctions
float sdBoxFrame(in vec3 p, in vec3 b, in float e ) {
  p = abs(p)-b;
  vec3 q = abs(p+e)-e;
  return min(min(
      length(max(vec3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
      length(max(vec3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
      length(max(vec3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
}

// https://iquilezles.org/articles/distfunctions
float sdCappedCylinder( vec3 p, float h, float r )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r,h);
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

// https://iquilezles.org/articles/distfunctions
float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}



//--------------------------------------------------------------------------

mat2 rot2(in float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat2(c, s, -s, c);
}

//--------------------------------------------------------------------------

// from https://www.cs.princeton.edu/courses/archive/fall00/cs426/lectures/raycast/sld017.htm
void rayVsPlane(in ray_t ray, in vec3 n, in float d, uint mtl, inout hit_t hit) {
    float t = -(dot(ray.ro, n) + d) / (dot(ray.rd, n));
    if (t > 0.0 && t < hit.t) {
        hit.hit = true;
        hit.t   = t;
        hit.mtl = mtl;
        hit.pnt = ray.ro + hit.t * ray.rd;
        hit.nrm = n;
    }
}

//--------------------------------------------------------------------------

void opUnion(inout mapSample_t cur, mapSample_t new) {
    if (new.dist < cur.dist) {
        cur.dist = new.dist;
        cur.mtl  = new.mtl;
    }
}

void opMinus(inout float cur, in float new) {
    cur = -min(new, -cur);
}

void opMinus(inout mapSample_t cur, mapSample_t new) {
    if (-new.dist > cur.dist) {
        cur.dist = -new.dist;
        cur.mtl  = new.mtl;
    }
}

void opInter(inout float cur, in float new) {
    cur = max(cur, new);
}

void opInter(inout mapSample_t cur, mapSample_t new) {
    if (new.dist > cur.dist) {
        cur.dist = new.dist;
        cur.mtl  = new.mtl;
    }
}

void opUnion(inout float cur, float new) {
    cur = min(cur, new);
}

// https://iquilezles.org/articles/smin
// polynomial smooth min
float smin( float a, float b, float k )
{
    float h = max( k-abs(a-b), 0.0 )/k;
    return min( a, b ) - h*h*k*(1.0/4.0);
}



