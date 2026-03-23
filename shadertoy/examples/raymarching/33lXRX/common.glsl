#define MIN_FLOAT 1e-6
#define MAX_FLOAT 1e6
const float PI = acos(-1.); 
struct Ray{vec3 origin, direction;};
    
bool plane_hit(in vec3 ro, in vec3 rd, in vec3 po, in vec3 pn, out float dist) {
    float denom = dot(pn, rd);
    if (denom > MIN_FLOAT) {
        vec3 p0l0 = po - ro;
        float t = dot(p0l0, pn) / denom;
        if(t >= MIN_FLOAT && t < MAX_FLOAT){
			dist = t;
            return true;
        }
    }
    return false;
}

vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

mat3 viewMatrix(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat3(s, u, -f);
}

