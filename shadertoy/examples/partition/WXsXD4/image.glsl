// =======================================
//  Making Music in Shadertoy - Episode 3
//     Marimba, Saw Bass, "Wah" Synth
// =======================================
// See the video : https://youtu.be/9XeE0v5JLiQ
//
// See Sound tab for the sound synthesis.


#define R(th) mat2(cos(th), -sin(th), sin(th), cos(th))


// =============================================
// SDFs by Inigo Quilez
// https://iquilezles.org/
// The MIT License
// Copyright © 2018 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// https://www.shadertoy.com/view/Nlj3WR
float sdBox( in vec2 p, in vec2 rad )
{
    p = abs(p)-rad;
    return max(p.x,p.y);
}

// https://www.shadertoy.com/view/7tj3DR
float sdEllipse( in vec2 p, in vec2 r )
{
    p = abs(p);
    p = max(p,(p-r).yx);
    float m = dot(r,r);
    float d = p.y-p.x;
    return p.x - (r.y*sqrt(m-d*d)-r.x*d)*r.x/m;
}


// ==============================================


float eighthNote(in vec2 U, float w)
{
    U = 15.*U;
    w *= 15.;
    float col = 0.;
    
    
    // Note head
    vec2 p = U - vec2(-3.6,-9.8);
    p = R(0.4)*p;
    col = mix(col, 1., smoothstep(w,0., sdEllipse(p, vec2(4.2,2.6))));
    // Note stem
    col = mix(col, 1., smoothstep(w,0., sdBox(U - vec2(0.,1.5),vec2(0.4,10.1))));
    // Note flag
    // Intersection of two circles
    p = U - vec2(0,-1.4);
    float d_in = length(p) - 7.0;
    p += vec2(3,0) * R(-0.4);
    float d_out = length(p) - 10.0;
    float d = max(-d_in, d_out);
    d = max(d, -(p*R(0.4)).y);// is up
    d = max(d, -U.x);// is right
    col = mix(col, 1., smoothstep(w, 0., d));
    
    // Upper part of the note flag
    float r_right = 3.7;
    p = U - vec2(0.4+r_right,11.6);
    d = r_right - length(p);
    d = max(d, -U.x);
    d = max(d, p.y);
    d = max(d, -p.y-r_right);
    d = max(d, p.x+0.5*r_right);
    col = mix(col, 1., smoothstep(w, 0., d));
    
    return col;
}


void mainImage( out vec4 O, in vec2 U )
{
    U = (2.*U-iResolution.xy)/iResolution.y;
    
    U *= 5.;
    float w = 1.5*fwidth(U.x);
    U.x += iTime;
    float sx = 1.5;
    float notei = round(U.x/sx);
    U.x -= notei*sx;
    U.y += asin(0.9*sin(iTime + fract(notei*0.618)*2.*3.14159));
    
    vec3 col = vec3(1. - eighthNote(U,w));
    
    // Output to screen
    O = vec4(col,1.0);
}
