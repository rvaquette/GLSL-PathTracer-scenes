/*

RIOW:

Inspired by Reinder’s RIOW implementation (removed classes)
and knightcrawler25’s GLSL-PathTracer: https://github.com/knightcrawler25/GLSL-PathTracer
Sky texture by fgarlin: https://www.shadertoy.com/view/msXXDS

Fake “Real” Camera:

Special Thanks To:

	•	chronos: for importance sampling, and creating the 2D simulation to debug
	•	01000001
	•	ArmandB: lens cap idea, and for helping out with the lens intersection function
	•	Igneus: for suggesting the use of LDS for wavelength selection
	•	beans_please: for bloom and halation
    •	and many others I’ve probably forgotten to mention…

Inspired by:

	•	youtube.com/watch?v=YE9rEQAGpLw
	•	youtube.com/watch?v=jT9LWq279OI
    •	youtube.com/watch?v=2SsTk657Uw0

Based on placeholderart.wordpress.com/2015/01/19/implementation-notes-physically-based-lens-flares/
and https://www.ipol.im/pub/art/2017/192/?utm_source=doi

Modify settings in the "Common" tab

*/

// ACES Cinematic Tonemapping by afl_ext: https://www.shadertoy.com/view/XsGfWV

#define sRGB(c) pow(c, vec3(1) / 2.2) // sorry ttg :))

void mainImage(out vec4 O, vec2 I)
{
    O = vec4(0);
    
    if(1.5 * abs(I.x - .5 * R.x) > R.y) return;
    
    #ifdef FILM_GRAIN
    O = texture(iChannel1, I / R.xy);
    O /= O.w;
    #else
    O = texture(iChannel0, I / R.xy);
    O.xyz = flimTransform(O.xyz / O.w);
    #endif
    O.xyz = sRGB(O.xyz);
}
