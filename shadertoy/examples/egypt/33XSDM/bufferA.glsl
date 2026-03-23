// This buffer gets the normal UV map of a circle

#define PI 3.14159265359

vec2 GetPoint(float alpha)
{
    vec2 circlepos = 0.7 * vec2(cos(alpha * 2.0 * PI / 4.0), sin(alpha * 2.0 * PI / 4.0));
    vec2 squarepos = float(alpha <= 1.0) * vec2(0.5, -0.5 + alpha) + float(!(alpha <= 1.0)) *(
                                float(alpha <= 2.0) * vec2(0.5 - (alpha - 1.0) , 0.5) + float(!(alpha <= 2.0))*(
                                  float(alpha <= 3.0) * vec2(-0.5, 0.5 - (alpha - 2.0)) + float(!(alpha <= 3.0))*
                                    vec2(-0.5 + (alpha - 3.0), -0.5)));
    float rate = 2.0*sin(iTime) - 1.0;
    return circlepos;
    return rate*circlepos + (1.0 - rate)*squarepos;
}
vec2 Normal(float alpha) //Calculates the normal of a point in the S1 circunference
{
    vec2 pos = GetPoint(alpha);
    vec2 circnormal = normalize(pos);
    vec2 squarenormal = float(pos.y >= 0.5) * vec2(0.0, 1.0) + float(!(pos.y >= 0.5))*(
               float(pos.y <= -0.5) * vec2(0.0, -1.0) + float(!(pos.y <= -0.5)) * (
                   float(pos.x >= 0.5) * vec2(1.0, 0.0) + float(!(pos.x >= 0.5))*
                       vec2(-1.0, 0.0) ));
    
    float rate = 2.0*sin(iTime) - 1.0;
    return circnormal;
    return rate*circnormal + (1.0-rate)*squarenormal; // The normal of the S1 circunference is the identity
}
vec2 integral(vec2 pos)
{
    float interval = 0.01; //Interval of the ingral
    vec2 sum = vec2(0.0, 0.0); //Value we are going to return
    
    for(float alpha = 0.0; alpha < 4.0; alpha += interval)
    {
        vec2 val = (1.0/(max(length(GetPoint(alpha) - pos), 0.001))) * Normal(alpha); // Normal of point Circlepos multiplied by the weight it has on position pos.
        sum = sum + interval * val;
    }
    return (1.0/(4.0*PI))*sum; // We normalize it by the length of the path, which is precisely the perimeter of S1. That is, 2PI
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
