#define NUM_POINTS 5
#define NUM_ITERATIONS 2
#define LENGTH (1.0 / float(NUM_POINTS - 1)) 

float dist (vec2 p1, vec2 p2, vec2 p)
{
    float l = length (p2-p1);
    float ool = 1.0f / l;
    vec2 n = (p2-p1) * ool;
    vec2 pn = vec2(n.y, -n.x);
    float d = dot(p-p1, n) * ool;
    
    return d < 0.0 ? length(p-p1) : (d > 1.0 ? length(p-p2) : abs(dot(p - p1, pn)));
}

float dist (vec2 point, vec2 p)
{
    return length (point - p);
}

float dist (vec2 points[NUM_POINTS], vec2 p)
{
    float d = 99999.0f;
    for (int i = 0; i < NUM_POINTS - 1; ++i)
    {
        vec2 p1 = points[i];
        vec2 p2 = points[i + 1];
        d = min(d, dist(p1, p2, p));
    }
    return d;
}

void backward(vec2 src[NUM_POINTS], out vec2 dst[NUM_POINTS], vec2 goal)
{
    dst[NUM_POINTS - 1] = goal;
    for (int i = NUM_POINTS - 2; i >= 0; --i)
    {
        vec2 n = normalize (src[i] - dst[i+1]);
        dst[i] = dst[i+1] + n * LENGTH;
    }
}

void forward(vec2 src[NUM_POINTS], out vec2 dst[NUM_POINTS], vec2 goal)
{
    dst[0] = goal;
    for (int i = 1; i < NUM_POINTS; ++i)
    {
        vec2 n = normalize(src[i] - dst[i-1]);
        dst[i] = dst[i-1] + n * LENGTH;
    }
}

