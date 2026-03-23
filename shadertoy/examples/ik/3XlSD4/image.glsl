
/*
    FABRIK inverse kinematics solver by chronos
    -------------------------------------------------

    FABRIK: Forwards And Backwards Reaching Inverse Kinematics.
    Simple and quick approximate IK solver.
    
    One issue with this approach, besides being approximate,
    is that it doesn't always give continuous/smooth solutions,
    which can lead to undesirable popping when used in e.g procedural animation.
    
    Inspired by: "A simple procedural animation technique" by argonaut
    https://www.youtube.com/watch?v=qlfh_rv6khY
    
    See also: "Curious Blob" https://www.shadertoy.com/view/MffyD4
    
    self link: https://www.shadertoy.com/view/MfXcRj
*/

const int num_iterations = 5;
const int num_nodes = 4;

float seg(vec2 a, vec2 b, vec2 p)
{
    b-=a; p-=a;
    return length(clamp(dot(p,b)/dot(b,b), 0., 1.) * b - p);
}


float dsc(vec2 a, float r, vec2 p)
{
    return length(a - p) - r;
}

float crc(vec2 a, float r, vec2 p)
{
    return abs(length(a - p) - r);
}

float target(vec2 a, float r, vec2 p)
{
    return min(seg(a-vec2(r), a+vec2(r), p), seg(a-vec2(-r,r), a+vec2(-r,r), p));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float zoom = .5;
    vec2 uv = zoom*(2.*fragCoord-iResolution.xy)/iResolution.y;
    
    vec2 mouse = zoom*(2.*iMouse.xy-iResolution.xy)/iResolution.y;
    if(length(iMouse.xy) < 10.) mouse = zoom*vec2(1.3*cos(iTime*.3), .75*sin(iTime)); // Idle mouse animation
    
    float ps = zoom*2./iResolution.y;
    
    vec3 bg_color = vec3(3,6,9)*.1 * (1.-length(uv*.5));
    
    vec3 color = bg_color;
    
    float link_size = 0.2; // Distance constraint between consequtive nodes
    
    // Allocate and initialize nodes
    vec2 nodes[num_nodes];
    for(int n = 0; n < num_nodes; n++)
    {
        nodes[n] = vec2(n,0)*link_size;
    }
    
    // FABRIK:
    for(int i = 0; i < num_iterations; i++)
    {
        // Forwards:
        nodes[num_nodes-1] = mouse;
        
        
        // Enforce constraints (from last to first)
        for(int n = num_nodes-2; n > 0; n--)
        {
            nodes[n] = normalize(nodes[n] - nodes[n+1]) * link_size + nodes[n+1];
        }
        
        // Backwards:
        nodes[0] = vec2(0);
        
        // Enforce constraints (from first to last)
        for(int n = 0; n < num_nodes-1; n++)
        {
            nodes[n+1] = normalize(nodes[n+1] - nodes[n]) * link_size + nodes[n];
        }
    }
    
    
    // Drawing
    
    float r = 0.05; // Drawn circle radius
    
    for(int i = 0; i < num_nodes-1; i++) // Iterate over chain
    {
        float disc = smoothstep(ps, -ps, dsc(nodes[i], r, uv));
        float circle = smoothstep(2. * ps, .5*ps, crc(nodes[i], r, uv));
        float segment = smoothstep(2. * ps, .5*ps, seg(nodes[i], nodes[i+1], uv));

        color = mix(color, vec3(1), segment);
        color = mix(color, bg_color, disc);
        color = mix(color, vec3(1), circle);
    }
    
    float disc = smoothstep(ps, -ps, dsc(nodes[num_nodes-1], r, uv));
    float circle = smoothstep(2. * ps, .5*ps, crc(nodes[num_nodes-1], r, uv));

    color = mix(color, bg_color, disc); // last disc
    color = mix(color, vec3(1), circle);// last circle
    
    float d = target(mouse, 0.025, uv);
    float alpha = smoothstep(2.*ps, ps, d);
    color = mix(color, vec3(1), alpha); // Target X

    color = mix(color, vec3(1), smoothstep(ps, -ps, dsc(nodes[0], r*0.6, uv))); // Anchor
    
    
    color = pow(color, vec3(1./2.2)); // Approximate gamma
    color += (texelFetch(iChannel0, ivec2(fragCoord)%1024, 0).rgb-0.5)/255.; // Dither
    fragColor = vec4(color, 1);
}
