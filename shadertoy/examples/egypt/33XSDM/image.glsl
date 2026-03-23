// Given a path I: [0, 1] -> R^n, and a function defined on 
// this path f: [0, 1] -> R^n ->R^m
// Consider then the extension
// F: R^n -> R^m defined by
// F(x) = C * integral_{i in I} f(i) / (dist(X - I(i))) d I(i) 
// C being a normalizing constant, usually the length of the path I in R^n.
// Then F is a continuous extension of f in the entire space!
//
// We are going to extend the normal map.
// If we have the circle S1 = {x : |x| = 1}, then for each point in S1, it's normal is itself
// That is: N(x) = x for every point x in S1. 
// On the other hand, for a square, the normal of a point x is (+1, 0), (-1, 0), (0, +1) or (0, -1)
// depending on which side of the square the point is.
// Regardless, we have a normal N defined on this path.
// We are going to extend this normal onto the entire plane and then light using common techniques!

vec4 GetLight(vec2 uv) // Calculates the light of a point given it's normal
{
    vec3 ligdir = normalize(vec3(cos(iTime), sin(iTime), -0.4 + 0.4*sin(iTime*0.5))); //Direction of the Light
    
    vec2 tex = float(uv.x <= 1.0) *
                    texture(iChannel0, uv - vec2(0.0, 1.0)).xy + float(!(uv.x <= 1.0))*
                    texture(iChannel1, uv - vec2(1.0, 1.0)).xy;
    
    vec3 normal = normalize(2.0*vec3(tex, 0.0) - 1.0); //Convert RGB Coordinates back into Normal vectors
    
    float intensity = dot(ligdir, normal); //Light it
    
    vec4 Color = normalize(vec4(1.0, 0.0, 0.5, 0.0));
    vec4 BColor = vec4(0.0, 0.0, 0.2, 0.0);
    
    return intensity*Color + (1.0-intensity)*BColor;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = 2.0*fragCoord/iResolution.xy;
    fragColor = float(uv.y <= 1.0) * 
        (uv.x <= 1.0 ? texture(iChannel0, uv) : texture(iChannel1, uv - vec2(1.0, 0.0))) +  float(!(uv.y <= 1.0)) *// uv.y <= 1.0
        GetLight(uv); // 1.0 <= uv.y <= 2.0
    
    float border = 0.005;
    float condition = float(((uv.x <= 1.0 + border && uv.x >= 1.0 - border) || (uv.y <= 1.0 + border && uv.y >= 1.0 - border)));
    fragColor = condition *
                    vec4(0.0) + (1.0 - condition) *fragColor;
}
