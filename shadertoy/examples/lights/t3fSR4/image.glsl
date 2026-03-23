/*
    "Milky" by @XorDev
    
    100 stars in a disc

    x.com/XorDev/status/1727908092304617661
    
    Warning: I squared the whole-number index to get around linear
    patterns, but it leads to large numbers and precision loss
    After 90 seconds there's noticeable patterns and a complete
    breakdown at 400 seconds. Still cool, but a more stable solution
    would be to multiply by a smaller value like "sin(w)"
*/

void mainImage( out vec4 fragColor, in vec2 fragCoord)
{
    //Initialize animate time (10x speed)
    float t = iTime/0.1,
    //Fractional starting index
    f = fract(-t),
    //Whole-index for star
    w = 0.0;
    
    //Screen uvs, centered and aspect correct (-0.5 to +0.5)
    vec2 suv = (fragCoord - iResolution.xy*0.5) / iResolution.y;
    
    //Prepare the sum of the star colors
    vec3 rgb = vec3(0.0);
    
    //Loop through 100 stars
    for(float i = f; i<1e2; i++)
    {
        //Find the whole-number star index
        w = round(i+t);
        //Square to prevent linear patterns. sin is a better alternative
        w *= w; //sin(w)
        //Pick a color using the index
        rgb += (cos(w+vec3(0,1,2))+1.)
        //Vary the brightness with the index
        * exp(cos(w/.1)/.6)
        //Fade in and out
        * min(1e3-i/.1+9.,i) / 5e4
        //Attentuate outward
        / length(suv
        //Set the star position
        + .05*cos(w/.31+vec2(0,5))*sqrt(i));
    }
    
    //Increase contrast
    rgb *= rgb;
    
    //Tanh tonemap:
    //https://www.shadertoy.com/view/ms3BD7
    rgb = tanh(rgb);
    
    fragColor = vec4(rgb, 1.0);
}

//Original in 262 chars
/*
void mainImage( out vec4 O, in vec2 I)
{
    //Initialize time, fractional index and whole-index
    float t = iTime/.1, f = -fract(t), w;
    
    //Clear fragColor and loop through 100 stars
    for(O*=w; f++<1e2;
    
        //Set the whole index and pick a color
        O+=(cos((w*=w=round(f+t))+vec4(0,1,2,3))+1.)
        //Vary the brightness with the index
        *exp(cos(w/.1)/.6)
        //Fade in and out
        *min(1e3-f/.1+9.,f)/5e4
        //Attentuate outward
        /length((I-iResolution.xy*.5)/iResolution.y
        //Set the star position
        +.05*cos(w/.31+vec2(0,5))*sqrt(f)));
    
    O = tanh(O*O);
}
*/
