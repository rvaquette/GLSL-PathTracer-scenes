/* KEYBOARD INPUT */

// reference: https://www.shadertoy.com/view/ltsyRS

// KEY_UP = move camera forward
// KET_DOWN = move camera backward
#define KEY_UP 38
#define KEY_DOWN 40

const float speed = 10.0;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float outData = 0.0;
    

        outData = texelFetch(iChannel0, ivec2(1, 0), 0).r +
                (iTimeDelta * speed) * texelFetch(iChannel1, ivec2(KEY_UP, 0), 0).r -
        		(iTimeDelta * speed) * texelFetch(iChannel1, ivec2(KEY_DOWN, 0), 0).r;
    
    fragColor = vec4(outData, 0.0, 0.0, 1.0);
}
