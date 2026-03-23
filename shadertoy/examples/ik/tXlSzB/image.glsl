//     ___    ___     ___     ___     ___    _  __  
//    | __|  /   \   | _ )   | _ \   |_ _|  | |/ /  
//    | _|   | - |   | _ \   |   /    | |   | ' <   
//   _|_|_   |_|_|   |___/   |_|_\   |___|  |_|\_\  
// _| """ |_|"""""|_|"""""|_|"""""|_|"""""|_|"""""| 
// "`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'
// Forward And Backward Reaching Inverse Kinematics
// take a lookie in common to configure it.
// It only shows the basic principle.
// Obvious cases like full stretch and close enough are not handled.

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;
    float scale = iResolution.x / iResolution.y;
    float bias = -0.2;
    uv.x = uv.x * scale + bias;
    
    // generate the points
    vec2 p[NUM_POINTS];
    for (int i = 0; i < NUM_POINTS; ++i)
        p[i] = vec2(0.0, float(i)*LENGTH);
        
    // generate the goal
    float time = iTime;//0.3;
    vec2 goal = vec2 (0.7 + cos (time) * 0.4, 0.5 + sin (time) * 0.4);
    if (iMouse.z > 0.0)
    {
        goal = vec2(iMouse.x / iResolution.x, iMouse.y / iResolution.y);
        goal.x = goal.x * scale + bias;
    }

    // Inverse Kinematics
    vec2 b[NUM_POINTS], f[NUM_POINTS];
    for (int i = 0; i < NUM_POINTS; ++i)
        f[i] = p[i];
    for (int i = 0; i < NUM_ITERATIONS; ++i)
    {
        backward (f, b, goal);
        forward (b, f, p[0]);
    }

    // Output to screen
    float d = dist(f,uv);
    vec4 c = vec4(d < 0.01 ? 1.0 : 0.0, 0, 0, 1) + vec4(clamp(1.0-d, 0.0, 1.0) * 0.2);
    c += vec4(dist(goal, uv) < 0.03 ? 1.0 : 0.0);
    fragColor = c;
}
