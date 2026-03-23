// There are EIGHT coordinates reserved by this system. fragCoord == 

// iMouse.xy: fragCoord + 0.5 of the last mouse event 
// iMouse.z: Mouse button currently down.
// iMouse.w: Mousedown event

// fragCoord will be 0.5, 1.5, 2.5, etc.
// iMouse will be 0.0, 1.0, 2.0... I've no fucking idea why.

//thanks to Fabrice Neyret for algorhitm https://www.shadertoy.com/view/llySRh
//and thanks to otaviogood for font texture
#define C_r2l(c) out_color += char(U,64+c).xxxx; U.x+=.5
#define C_l2r(c) out_color += char(U,64+c).xxxx; U.x-=.5

#define _SPACE -32
#define _MINUS -19
#define _PERIOD -18
#define _A 1
#define _B 2
#define _C 3
#define _D 4
#define _E 5
#define _F 6
#define _G 7
#define _H 8
#define _I 9
#define _J 10
#define _K 11
#define _L 12
#define _M 13
#define _N 14
#define _O 15
#define _P 16
#define _Q 17
#define _R 18
#define _S 19
#define _T 20
#define _U 21
#define _V 22
#define _W 23
#define _X 24
#define _Y 25
#define _Z 26

vec4 char(vec2 p, int c) 
{
    if (p.x<.0|| p.x>1. || p.y<0.|| p.y>1.) return vec4(0,0,0,1e5);
	return textureGrad( iChannel0, p/16. + fract( vec2(c, 15-c/16) / 16. ), dFdx(p/16.),dFdy(p/16.) );
}

#define BLACK vec4(0.0) 
#define WHITE vec4(1.0)

vec2 fragCoord_to_uv(in vec2 fragCoord) {
    vec2 uv = fragCoord - iResolution.xy/2.0;
    return uv*2.0/iResolution.x;
}

vec2 mouse_to_fragCoord() {
    return iMouse.xy + 0.5;
}

vec2 mouse_to_uv() {
    return fragCoord_to_uv(mouse_to_fragCoord());
}

vec4 draw_float(in float f, in vec2 position, in float fract_digits, in float font_size, in vec2 uv) {
    vec4 out_color = vec4(0.0);
    bool negative = false;

    if(f == reserved_float) {
        return vec4(0.0);
    }


    if(f < 0.0) {
        negative = true;
        f = -f;
    }

    // Add juuuuust enough to f that we'll round off the last digit. It'll turn
    // 0.999999 into 0.9999995 which will then round off to 1.000000. Given how
    // often normalized axial vectors end up being <0.999999, 0.0, 0.0>, this is
    // a good thing.
    f += 5.0 * pow(10.0, -(fract_digits + 1.0));

    vec2 U = (uv - position)*64.0/font_size;
    // Not sure I can explain this. It has to do with the default-to-centering of the font system and
    // the left-to-right nature of printing in most cases.
    U.x += (0.50 + 0.25); 

    int fraction = int(fract(f) * pow(10.0, fract_digits));
    for(float i=0.0; i<fract_digits; i+=1.0) {
        C_r2l((fraction%10) - 16);
        fraction /= 10;
    }
    C_r2l(_PERIOD); // decimal point
    
    int mantissa = int(f);
    
    do{
        C_r2l(mantissa%10 - 16);
        mantissa /= 10;
    } while(mantissa != 0);
    if(negative) {
        C_r2l(_MINUS);
    }
    
    return out_color;
}

vec4 draw_string(in int[10]s, in vec2 position, in float font_size, in vec2 uv) {
    vec4 out_color = vec4(0.0);

    vec2 U = (uv - position)*64.0/font_size;
    // Not sure I can explain this. It has to do with the default-to-centering of the font system and
    // the left-to-right nature of printing in most cases.
    U.x += (0.25); 

    for(int i=0; i<10; i++) {
        C_l2r(s[i]);
    }

    return out_color;
}

int fps_string[10] = int[10](_F, _P, _S, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE);
int normal_string[10] = int[10](_N, _O, _R, _M, _A, _L, _SPACE, _SPACE, _SPACE, _SPACE);
int color_string[10] = int[10](_C, _O, _L, _O, _R, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE);
int distance_string[10] = int[10](_D, _I, _S, _T, _A, _N, _C, _E, _SPACE, _SPACE);
int iterations_string[10] = int[10](_I, _T, _E, _R, _A, _T, _I, _O, _N, _S);
vec4 debug_overlay(vec2 fragCoord) {
    vec2 uv = fragCoord_to_uv(fragCoord);
    
    vec4 out_color = BLACK;

    float fps = 1.0/iTimeDelta;
    vec2 position = vec2(1.0, -0.57);
    float font_size = 2.9;
    float char_width = font_size / 128.0;
    float char_height = font_size / 64.0;
    position.x -= char_width * 3.0;
    out_color += draw_float(fps, position, 1.0, font_size, uv);
    out_color += draw_string(fps_string, position, font_size, uv);

    float str_left_side = -0.99;
    float val_left_side = -0.33;
    float first_row = 0.51;
    float skip_right = 0.44;
    float skip_down = char_height * 0.75;
    position.y = first_row+skip_down;
    vec4 texel;
#if 1
    position.x = str_left_side;
    position.y -= skip_down;
    
    texel = texture(iChannel1, vec2(0.5, 0.5)/iResolution.xy);
    out_color += draw_string(normal_string, position, font_size, uv);
    position.x = val_left_side;
    out_color += draw_float(texel.r, position, 6.0, font_size, uv);
    position.x += skip_right;
    out_color += draw_float(texel.g, position, 6.0, font_size, uv);
    position.x += skip_right;
    out_color += draw_float(texel.b, position, 6.0, font_size, uv);
    position.x += skip_right;
    out_color += draw_float(texel.a, position, 6.0, font_size, uv);
#endif
#if 1
    position.x = str_left_side;
    position.y -= skip_down;
    
    texel = texture(iChannel1, vec2(1.5, 0.5)/iResolution.xy);
    out_color += draw_string(color_string, position, font_size, uv);
    position.x = val_left_side;
    out_color += draw_float(texel.r, position, 6.0, font_size, uv);
    position.x += skip_right;
    out_color += draw_float(texel.g, position, 6.0, font_size, uv);
    position.x += skip_right;
    out_color += draw_float(texel.b, position, 6.0, font_size, uv);
    position.x += skip_right;
    out_color += draw_float(texel.a, position, 6.0, font_size, uv);
#endif
#if 1
    position.x = str_left_side;
    position.y -= skip_down;
    
    texel = texture(iChannel1, vec2(2.5, 0.5)/iResolution.xy);
    out_color += draw_string(distance_string, position, font_size, uv);
    position.x = val_left_side;
    out_color += draw_float(texel.x, position, 6.0, font_size, uv);
#endif
#if 1
    position.x = str_left_side;
    position.y -= skip_down;
    
    texel = texture(iChannel1, vec2(3.5, 0.5)/iResolution.xy);
    out_color += draw_string(iterations_string, position, font_size, uv);
    position.x = val_left_side;
    out_color += draw_float(texel.r, position, 1.0, font_size, uv);
#endif
    
    // "Mouse Click To Debug"
    position.x = -0.485;
    position.y = -0.5;
    font_size = 6.0;
    vec2 U = (uv - position)*64.0/font_size;
    C_l2r(_M);C_l2r(_O);C_l2r(_U);C_l2r(_S);C_l2r(_E);C_l2r(_SPACE);
    C_l2r(_C);C_l2r(_L);C_l2r(_I);C_l2r(_C);C_l2r(_K);C_l2r(_SPACE);
    C_l2r(_T);C_l2r(_O);C_l2r(_SPACE);C_l2r(_D);C_l2r(_E);C_l2r(_B);C_l2r(_U);C_l2r(_G);
    

    return out_color;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
#if DEBUG
    debug_trace_index = -1;
    debug_trace_occurred = false;
    bool masked_overlay = false;
    if(fragCoord.y == 0.5 && fragCoord.x < (0.5 + 8.0)) {
        masked_overlay = true;
        debug_trace_index = int(fragCoord.x);
        render(fragColor, mouse_to_fragCoord(), iResolution, iTime);
        fragColor=vec4(1.0);
    } else {
        render(fragColor, fragCoord, iResolution, iTime);
    }
    
    if(debug_trace_index >= 0) {
        if(debug_trace_occurred) {
            fragColor = debug_trace_value;
        } else {
            fragColor = vec4(reserved_float);
        }
    }
   
    
    // Protect the reserved pixels from being overwritten. Otherwise, the debug values
    // we get in the next frame won't be the ones TRACEd, but the rgb values we wrote there
    // as part of the overlay rendering.
    if(!masked_overlay) {
        float empty_radius = 3.0;
        float reticle_size = 30.0;
        if((abs(iMouse.x - fragCoord.x) <= 2.5 || abs(iMouse.y - fragCoord.y) <= 2.5) &&
           (abs(iMouse.x - fragCoord.x) > empty_radius || abs(iMouse.y - fragCoord.y) > empty_radius) &&
           (abs(iMouse.x - fragCoord.x) < reticle_size && abs(iMouse.y - fragCoord.y) < reticle_size)) {
            if(abs(iMouse.x - fragCoord.x) <= 1.0 || abs(iMouse.y - fragCoord.y) <= 1.0) {
                fragColor = vec4(1.0);
            } else {
                fragColor = vec4(0.0);
            }
        }

        vec4 overlay = debug_overlay(fragCoord);
        if(overlay != vec4(0.0)) {
            fragColor = overlay;
        }
    }
#else
    render(fragColor, fragCoord, iResolution, iTime);
#endif
}
