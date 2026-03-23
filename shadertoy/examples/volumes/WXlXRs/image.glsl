#define pi 3.14159265359
#define tau 6.28318530718

#define MAXSAMPLES 15
#define RAYEXP 2.0

#define SKY 0.4 * vec3(76.0, 94.0, 112.0)/255.0

#define FOV 4.0
#define CAM_FREQ 1.1
#define CAM_DIST 7.0

vec2 r2d(vec2 p,float a)
{
	float c = cos(a);
    float s = sin(a);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

int iMod(int a, int b)
{
    return a - b * (a/b);
}


float density(vec3 p)
{
    vec3 p1 = 3.0 * (p*pi/6.0);

    p1.y -= 3.0 * iTime;

    p1.x += sin(p1.y + iTime*3.0)*0.5;
    p1.y += cos(p1.z + iTime*3.0)*0.5;
    p1.z += sin(p1.x - iTime*3.0)*0.5;

    float noise = pow(cos(p1.x) * cos(p1.y) * cos(p1.z), 2.0);

    return mix(0.05, 0.9, smoothstep(0.1, 0.6, noise));

}

vec3 color(vec3 p)
{
    float d = density(p);
    return mix(vec3(0.0, 0.5, 1.0), vec3(0.5, 1.0, 0.0), density(p));
}

bool in_cube(vec3 p, vec3 c_o, vec3 c_d)
{
    return (p.x>c_o.x)&&(p.x<c_o.x+c_d.x)&&(p.y>c_o.y)&&(p.y<c_o.y+c_d.y)&&(p.z>c_o.z)&&(p.z<c_o.z+c_d.z);
}

float transmittance(vec3 p_a, vec3 p_b, float samples)
{
    float l_i = 1.0;

    float dx = length(p_a - p_b) / samples;

    for (float i=0.0; i<samples; i++)
    {
        vec3 sample_pos = mix(p_a, p_b, 1.0 - i/samples);

        if (in_cube(sample_pos, vec3(-3.0), vec3(6.0)))
        {
            float sample_density = density(sample_pos);

            l_i  *= pow(1.0 - sample_density, dx);
        }
    }
    return l_i;
}


float plane_hit(vec3 o, vec3 d, int axis, float depth, vec2 p_o, vec2 p_d)
{
    float hit_dist = 0.0;
    float rayl = (depth - o[axis]) / d[axis] ;

    if (rayl<=0.0)
    {
        return -1.0;
    }

    vec3 intpoint = o + d * rayl;

    int axis_1 = iMod(axis+1, 3);
    int axis_2 = iMod(axis+2, 3);

    if ((intpoint[axis_1]>p_o.x)&&(intpoint[axis_1]<p_o.x+p_d.x)&&(intpoint[axis_2]>p_o.y)&&(intpoint[axis_2]<p_o.y+p_d.y)){
        return rayl;
    }

    return -1.0;
}

vec3 cube_hit(vec3 p, vec3 d, vec3 c_o, vec3 c_d)
{ //(x, y) -> scalars for ray ; (z) -> number of intersections

    vec3 hit_dist = vec3(0.0);
    int hit_ind = 0;

    //x1
    float i1 = plane_hit(p, d, 0, c_o.x, c_o.yz, c_d.yz);

    if (i1>0.0){
        hit_dist[hit_ind]=i1;
        hit_ind+=1;
    }

    //x2
    i1 = plane_hit(p, d, 0, c_o.x+c_d.x, c_o.yz, c_d.yz);
    if (i1>0.0){
        hit_dist[hit_ind]=i1;
        hit_ind+=1;
    }

    //y1
    i1 = plane_hit(p, d, 1, c_o.y, c_o.zx, c_d.zx);
    if (i1>0.0){
        hit_dist[hit_ind]=i1;
        hit_ind+=1;
    }

    //y2
    i1 = plane_hit(p, d, 1, c_o.y+c_d.y, c_o.zx, c_d.zx);
    if (i1>0.0){
        hit_dist[hit_ind]=i1;
        hit_ind+=1;
    }

    //z1
    i1 = plane_hit(p, d, 2, c_o.z, c_o.xy, c_d.xy);
    if (i1>0.0){
        hit_dist[hit_ind]=i1;
        hit_ind+=1;
    }

    //z2
    i1 = plane_hit(p, d, 2, c_o.z+c_d.z, c_o.xy, c_d.xy);
    if (i1>0.0){
        hit_dist[hit_ind]=i1;
        hit_ind+=1;
    }

    hit_dist.z = float(hit_ind);

    hit_dist.xy = vec2(max(hit_dist.x, hit_dist.y), min(hit_dist.x, hit_dist.y));

    //if (hit_ind<2 && hit_ind>0){hit_dist.x = hit_dist.y;}

    return hit_dist;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord ) {

    vec2 uv = (gl_FragCoord.xy - iResolution.xy * 0.5)/iResolution.x;
    
    vec3 col = SKY;

    vec3 ray = vec3(uv * FOV, 1.0);
    
    float rotr = iTime * CAM_FREQ;
    
    vec3 ori = vec3(sin(rotr), 0.0, cos(rotr)) * CAM_DIST;
    
    ray.zx = r2d(ray.zx, rotr - pi);
    

    vec3 light_pos = vec3(cos(iTime), sin(2.0 * iTime), 0.0)*3.0;
    vec3 light_col = vec3(8.0);

    vec3 rayhit = cube_hit(ori, ray, vec3(-3.0, -3.0, -3.0), vec3(6.0, 6.0, 6.0)) ;

    float rayd = length(ray * (rayhit.x - rayhit.y));
    float rayd2 = length(ori + ray * rayhit.y);

    vec3 u = cube_hit(ori, ray, light_pos, vec3(0.25));

    if (u.z>0.1){col = light_col;}

    if (rayhit.z>0.0 && (u.z<0.1 || u.y>rayhit.y)){
        float k = round(64.0 * rayd / 6.0 + 2.0);
        float dx = rayd / k;

        float ray_intensity = 1.0; // transmittance between current sample position and camera
        vec3 pixel_color = vec3(0.0); // sum of reflected light

        for (float i=0.0; i<k; i++){
        
            float ray_scale = mix(rayhit.y, rayhit.x, (1.0*i)/(k-1.0));

            vec3 sample_pos = ori + ray * ray_scale;

            float sample_density = density(sample_pos);

            vec3 sample_color = color(sample_pos);

            vec3 light_int = light_pos + (sample_pos - light_pos) * cube_hit(light_pos, sample_pos - light_pos, vec3(-3.0), vec3(6.0)).y;

            vec3 light_intensity = transmittance(light_int, sample_pos, 20.0) * light_col * pow(0.3 * length(light_pos - sample_pos)+1.0, -2.0);

            // * pow(length(light_pos - sample_pos)+1.0, -2.0)

            float scatter = (1.0 - pow((1.0 - sample_density), dx));

            pixel_color += pow(ray_intensity, RAYEXP) * scatter * (light_intensity + SKY) * sample_color;
            ray_intensity *= (1.0 - scatter); //take into account that different wavelengths are passsed
        }
        col = pixel_color + col * ray_intensity;
    }

    fragColor = vec4(col,1.0);
}



