// Drifting Shore
// by nusan
// PC 4k intro made for Revision 2024

// this version has sound from sound cloud
// it's in case compiling the shader sound makes you browser crash

// To play it properly with sound in sync
// wait for the soundcloud bellow to load
// restart the soundcloud by pressing it's restart button
// restart the whole thing by pressing the button on the left under the image

// you can adjust SAMPLE_COUNT in "Buffer A" tab if you want to adjust the quality

// Original code is here: https://github.com/TheNuSan/Lev4k/tree/DriftingShore

// a version with sound computed using shader is here:
// https://www.shadertoy.com/view/Mcy3RR

// this code is often a mess, it was made in a rush to meet approaching revision's deadline
// so don't judge it too harshly, it could be sizecoded a lot more but I didn't have time

////////////////////////////
// POST-PROCESS           //
////////////////////////////

float time;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	time = max(0.,iTime-1.);
	
	vec2 uv = fragCoord.xy/iResolution.xy;
	
	// get back the color from the first pass framebuffer
	vec4 value=texture(iChannel0,uv);    
    vec3 col=value.xyz;

	// compute bloom by sampling the mipmaps of the first pass
	vec3 cumul = vec3(0);
	for(float i=0.; i<32.; ++i) {
		// spiral pattern with a per-pixel random rotation
		vec2 off=vec2((i+.1)/32.,0)*rot(i*4.+rnd23(gl_FragCoord.xy).x*7.);
		vec4 cur = textureLod(iChannel0, uv + off*140./iResolution.xy, 4.5);
		cumul += cur.xyz;
	}
	// apply the bloom 
	col += cumul * 0.01 * pow(smoothstep(.0,1.,dot(cumul.xyz,vec3(.1))),0.5);
	
	// vignetting
	col *= 1.-length(uv-.5)*1.2;
	col *= 1.08*(2.51*col+0.03)/(col*(2.43*col+0.59)+0.14); // "filmic" tonemapping

	// global fade-in / fade-out
	col *= block(time-4.,139.,4.,1.);
        
	fragColor = vec4(col, 1);
}
