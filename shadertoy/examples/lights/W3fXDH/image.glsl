//<300 chars playlist: https://www.shadertoy.com/playlist/fXlGDN

//twigl: https://t.co/WEhc3HtswZ
//tweet: https://twitter.com/XorDev/status/1487518399550955520

void mainImage(out vec4 O, vec2 I)
{
    //Make sure the output is 0.0
    O -= O;
    //Initialize variables
    vec2 r = iResolution.xy, a, b;
    //Iterate through points
    for(int i; i<81;
    //Add projected, colored points to output
    O += (cos(a.y/.1+vec4(0,1,2,0))+1.)/length((I+I-r-r*b/(b.y+9.))/r.y-a*.4)/3e2)
        //2D point position (-4 to +4)
        a = vec2(i%9,i++/9)-4.,
        //Rotated position
        b = a*mat2(cos(iTime*.3+vec4(0,11,33,0))),
        //Heightfield
        a = texture(iChannel0, (a+iTime)/3e2).gr;
}
