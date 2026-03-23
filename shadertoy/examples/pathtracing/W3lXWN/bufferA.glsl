const int spp = 5;
// camera
vec3 cam_pos = vec3(0, 0.5, 2.5); // CPU->GPU
vec3 right = vec3(1, 0, 0), up = vec3(0, 1, 0); // CPU->GPU
vec3 dir = normalize(vec3(0, 0, 1)); // CPU
vec3 left_lower_corner; // CPU->GPU
float aspect_ratio;
float fov = radians(45.); // CPU
float plane_width, plane_height; // CPU
ray get_ray(vec2 uv){ 
    vec3 target;
    target = left_lower_corner + 
             plane_width * uv.x * right + 
             plane_height * uv.y * up;
    return ray(cam_pos, target - cam_pos);
}
void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    
    
    seed = iTime + fragCoord.y * fragCoord.x / iResolution.x + fragCoord.y / iResolution.y;
    aspect_ratio = iResolution.x / iResolution.y; 
    plane_height = 2.0*tan(fov / 2.0); 
    plane_width = aspect_ratio * plane_height; 
    left_lower_corner = -plane_width / 2.0 * right + (-plane_height / 2.0) * up - dir + cam_pos;

    vec3 color = vec3(0, 0 ,0);
    for(int i = 0; i < spp; i ++){
        vec2 uv = (fragCoord + vec2(rnd(), rnd()) - 0.5f)/iResolution.xy;
        ray r = get_ray(uv);
        color += trace(r, 20);
    }
    if(isnan(color.x) || isnan(color.y) || isnan(color.z)) color = vec3(1, 1, 1);
    if(isinf(color.x) || isinf(color.y) || isinf(color.z)) color = vec3(1, 1, 1);
    color /= float(spp);
    //if(color[0] == color[1] && color[1] == color[2] && color[0] == 0.0) color[0] = 1.0;
    //if(isnan(color.x) || isnan(color.y) || isnan(color.z)) color = vec3(10000, 1000, 1000);
    //if(isinf(color.x) || isinf(color.y) || isinf(color.z)) color = vec3(1000, 0, 1000);
    if(color.x < 0. || color.y < 0. || color.z < 0.) color = vec3(1000, 1000, 1000);
    //if(color.x == color.y && color.y == color.z && color.z == 0.) color = vec3(1, 1, 0);
    //color = clamp(color, 0.0, 1.0);
    // https://www.shadertoy.com/view/tddSz4
    vec4 prev = texelFetch(iChannel0, ivec2(fragCoord), 0);
    float w = prev.w + 1.0;
    color = color + to_linear(prev.xyz) * prev.w;
    color /= w;
    fragColor = vec4(to_gamma(color), w);
    //fragColor = vec4(fragCoord / iResolution.xy, 0, 1.0);
}
