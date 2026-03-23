
const int multisamples = 4; // Max 4
const int max_reflections = 6;
const float zoom = 2.0;

const float eyedistance = 7.5; // Note: These depend on each other
const float min_distance = 3.0;
const float max_distance = 10.5;
const float min_stepsize = 0.25;
const int maxsteps = 30;

const float pi = 3.1415926326;

vec4 sphere1;
vec4 sphere2;
vec4 sphere3;

float sq(float x) { return x * x; }
float sq(vec3 x) { return dot(x, x); }

float f(vec3 p)
{
    return 1.0 - (
        sphere1.w / sq(sphere1.xyz - p) + 
        sphere2.w / sq(sphere2.xyz - p) +
        sphere3.w / sq(sphere3.xyz - p));
}

vec3 fd(vec3 p)
{
    vec3 d1 = sphere1.xyz - p;
    vec3 d2 = sphere2.xyz - p;
    vec3 d3 = sphere3.xyz - p;
    return 2.0 * (
        sphere1.w * d1 / sq(sq(d1)) +
        sphere2.w * d2 / sq(sq(d2)) +
        sphere3.w * d3 / sq(sq(d3)));
}

float stepsize(vec3 p)
{
    float md = sqrt(min(min(
        sq(p - sphere1.xyz), 
        sq(p - sphere2.xyz)), 
        sq(p - sphere3.xyz)));
    return max(min_stepsize, (md - 1.0) * 0.667);
}

vec4 ray(vec3 p, vec3 d)
{
    float k = min_distance;
    for (int j = 0; j < max_reflections; ++j)
    {
        for (int i = 0; i < maxsteps; ++i)
        {
            if (k > max_distance)
                return texture(iChannel0, d);
            float ss = stepsize(p + d * k);
            if (f(p + d * (k + ss)) < 0.0)
            {
                k += ss - min_stepsize * 0.5;
                k += f(p + d * k) / dot(d, fd(p + d * k));
                k += f(p + d * k) / dot(d, fd(p + d * k));
                p += d * k;
                d = reflect(d, normalize(fd(p)));
                k = 0.0;
                break;
            }
            k += ss;
        }
    }
    return texture(iChannel0, d);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float t = iTime;

    vec4 vs1 = cos(t * vec4(0.87, 1.13, 1.2, 1.0) + vec4(0.0, 3.32, 0.97, 2.85)) * vec4(-1.7, 2.1, 2.37, -1.9);
    vec4 vs2 = cos(t * vec4(1.07, 0.93, 1.1, 0.81) + vec4(0.3, 3.02, 1.15, 2.97)) * vec4(1.77, -1.81, 1.47, 1.9);

    sphere1 = vec4(vs1.x, 0.0, vs1.y, 1.0);
	sphere2 = vec4(vs1.z, vs1.w, vs2.z, 0.9);
	sphere3 = vec4(vs2.x, vs2.y, vs2.w, 0.8);

    float ry = -iMouse.x / iResolution.x * pi * 2.0;
    float rx = -(iMouse.y / iResolution.y - 0.5) * pi;

    vec4 cs = cos(vec4(ry, rx, ry - pi * 0.5, rx - pi * 0.5));
    vec3 forward = -vec3(cs.x * cs.y, cs.w, cs.z * cs.y);
	vec3 up = vec3(cs.x * cs.w, -cs.y, cs.z * cs.w);
	vec3 left = cross(up, forward);
    vec3 eye = -forward * eyedistance;

	vec2 uv = zoom * (fragCoord.xy - iResolution.xy * 0.5) / iResolution.x;
    vec2 uvh = zoom * vec2(0.5) / iResolution.x;
    vec3 dirs[4];
    dirs[0] = vec3(forward + uv.y * up + uv.x * left);
	dirs[1] = vec3(forward + (uv.y + uvh.y) * up + (uv.x + uvh.x) * left);
	dirs[2] = vec3(forward + (uv.y + uvh.y) * up + uv.x * left);
	dirs[3] = vec3(forward + uv.y * up + (uv.x + uvh.x) * left);
    
    vec4 color = vec4(0.0);
    for (int i = 0; i < multisamples; ++i)
        color += ray(eye, normalize(dirs[i]));
    fragColor = color / float(multisamples);
}

