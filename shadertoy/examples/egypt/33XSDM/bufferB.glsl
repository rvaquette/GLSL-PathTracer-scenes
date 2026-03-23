// This buffers get the normal UV map of a square

vec2 Normal(vec2 pos) //Calculates the normal of a point in the 2D Square
{
    return float(pos.y >= 0.5) * vec2(0.0, 1.0) + float(!(pos.y >= 0.5))*(
               float(pos.y <= -0.5) * vec2(0.0, -1.0) + float(!(pos.y <= -0.5)) * (
                   float(pos.x >= 0.5) * vec2(1.0, 0.0) + float(!(pos.x >= 0.5))*
                       vec2(-1.0, 0.0) ));
}
vec2 integral(vec2 pos)
{
    float interval = 0.01; //Interval of the integral
    vec2 sum = vec2(0.0, 0.0); 
    
    for(float alpha = 0.0; alpha < 4.0; alpha += interval)
    {
        vec2 squareposition = float(alpha <= 1.0) * vec2(0.5, -0.5 + alpha) + float(!(alpha <= 1.0)) *(
                                float(alpha <= 2.0) * vec2(0.5 - (alpha - 1.0) , 0.5) + float(!(alpha <= 2.0))*(
                                  float(alpha <= 3.0) * vec2(-0.5, 0.5 - (alpha - 2.0)) + float(!(alpha <= 3.0))*
                                    vec2(-0.5 + (alpha - 3.0), -0.5)));
        
        vec2 val = (1.0/(max(length(squareposition - pos), 0.001))) * Normal(squareposition); // Normal of point Square multiplied by the weight it has on position pos.
        
        sum = sum + interval * val;
    }
    return (1.0/(2.0*4.0))*sum; // Normalization of path length
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from -1 to 1)
    vec2 uv = fragCoord/iResolution.xy;
    uv = 2.0*uv - 1.0;
    uv = uv * vec2(iResolution.x / iResolution.y, 1.0); //Corrects Distortion caused by screen
    
    vec2 i = integral(uv); // Gets the extension of the identity of function of the circunference to the entire space
    fragColor = vec4(0.5) + 0.5*vec4(i.xy, 1.0, 0.0); //Convert normal vector to standard RGB representation.

       
    
}
