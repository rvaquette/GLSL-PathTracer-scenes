//Eclipse 1: https://www.shadertoy.com/view/4d2fzw
//Eclipse 2: https://www.shadertoy.com/view/NdlfzX
//Eclipse 3: https://www.shadertoy.com/view/slffRX

void mainImage(out vec4 O,vec2 I)
{
    I -= .5*iResolution.xy; //Center
    O -= O;
	O = mix(texture(iChannel0,iTime/1e2 //Scrolling texture
    +.6/(O += 1.-O+sqrt(max(1.-dot(I/=2e2,I),0.))).x*I) * //2D projection
        max(I.x*.3+I.y*.9+--O*.1+.5,.1), //Lighting
            vec4(1.2,.8,.6,1)/dot(I,I),--O*O); //Radiant light
}

//2021 version, 233 chars:
/*
void mainImage(out vec4 O,vec2 I)
{
    vec2 P = I-.5*iResolution.xy;
    O = vec4(P/=2e2,sqrt(max(1.-dot(P,P),0.)),0);
	O = mix(texture(iChannel0,iTime/1e2+.3*O.xy/sqrt(O.z))*max(O.x*.3+O.y*.9+O.z*.1+.5,.1),
            vec4(1.2,.8,.6,1)/dot(P,P),pow(1.-O.z,2.));
}
*/

//239 chars:
/*
void mainImage(out vec4 O,vec2 I)
{
    vec2 P = (I-.5*iResolution.xy)/2e2;
    vec3 R = vec3(P,sqrt(max(1.-dot(P,P),0.)));
	O = mix(texture(iChannel0,.01*iTime+.3*R.xy/sqrt(R.z))*max(R.x*.3+R.y*.9+R.z*.1+.5,.1),
            vec4(.6,.4,.3,1)/dot(P,P*.5),pow(1.-R.z,2.));
}
*/

//Original 253 chars:
/*
void mainImage(out vec4 O,vec2 I)
{
    vec2 P = (I-.5*iResolution.xy)/2e2;
    vec3 R = vec3(P,sqrt(1.-dot(P,P)));
	O = mix(texture(iChannel0,.01*iTime+.3*R.xy/sqrt(R.z))*max(R.x*.3+R.y*.9+R.z*.1+.5,.1),
            vec4(.6,.4,.3,1)/dot(P,P*.5),pow(1.-sqrt(max(1.-dot(P,P),0.)),2.));
}
*/
