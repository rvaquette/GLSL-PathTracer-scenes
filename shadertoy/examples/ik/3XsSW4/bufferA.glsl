// User Inputs

// References:
// "Special Shadertoy features" by Fabrice: https://shadertoyunofficial.wordpress.com/2016/07/20/special-shadertoy-features/
// "keyboard debugging" by mattz: https://www.shadertoy.com/view/4dGyDm
// "Input - Keyboard" by iq: https://www.shadertoy.com/view/lsXGzf
// "Input - Mouse" by iq: https://www.shadertoy.com/view/Mss3zH

// Shows how to use the mouse input (only left button supported):
//
//      mouse.xy  = mouse position during last button down
//  abs(mouse.zw) = mouse position during last button click
// sign(mouze.z)  = button is down
// sign(mouze.w)  = button is clicked

const int K_PAD_0 = 96;
const int K_PAD_1 = 97;
const int K_PAD_2 = 98;
const int K_PAD_3 = 99;
const int K_PAD_4 = 100;
const int K_PAD_5 = 101;
const int K_PAD_6 = 102;
const int K_PAD_7 = 103;
const int K_PAD_8 = 104;
const int K_PAD_9 = 105;

const int K_NUM_0 = 48;
const int K_NUM_1 = 49;
const int K_NUM_2 = 50;
const int K_NUM_3 = 51;
const int K_NUM_4 = 52;
const int K_NUM_5 = 53;
const int K_NUM_6 = 54;
const int K_NUM_7 = 55;
const int K_NUM_8 = 56;
const int K_NUM_9 = 57;


#define ID(c) (distance(C, c)<1.)
#define getState(k)    ((texelFetch( iChannel0, ivec2(k, 0), 0 ).x)>.5)
#define getKeypress(k) ((texelFetch( iChannel0, ivec2(k, 1), 0 ).x)>.5)
#define getToggle(k)   ((texelFetch( iChannel0, ivec2(k, 2), 0 ).x)>.5)
        
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    if(iFrame < 2 ) {
        fragColor = vec4(0);
        return;
    }
    
    vec2 C = fragCoord;
    vec4 last = texelFetch(iChannel1, ivec2(C), 0);
    
    if(ID(C_MOUSE)){
    
        // Mouse
        if(sign(iMouse.z)>.0)
            fragColor = iMouse;
        else
            fragColor = last;
        return;
        
    }
    else
    if(ID(C_CAMERA)){
    
        // Numpad
        fragColor = last;
        bool isFreeCamera = bool(last.y);
        
        if(getKeypress(K_PAD_0) || getState(K_NUM_0) && sign(iMouse.z)<=.0)fragColor = vec4(0, 0, 0, 0);
        
        //if(getState(K_PAD_0))fragColor = vec4(0, true, 0, 0);
        if(getState(K_PAD_1) || getState(K_NUM_1))fragColor = vec4(1, true, 0, 0);
        //if(getState(K_PAD_2))fragColor = vec4(2, true, 0, 0);
        if(getState(K_PAD_3) || getState(K_NUM_3))fragColor = vec4(3, true, 0, 0);
        //if(getState(K_PAD_4))fragColor = vec4(4, true, 0, 0);
        //if(getState(K_PAD_6))fragColor = vec4(6, true, 0, 0);
        if(getState(K_PAD_7) || getState(K_NUM_7))fragColor = vec4(7, true, 0, 0);
        //if(getState(K_PAD_8))fragColor = vec4(8, true, 0, 0);
        //if(getState(K_PAD_9))fragColor = vec4(9, true, 0, 0);
        return;
        
    }
    else
    {
        // Blank
        fragColor = vec4(0.0,0.0,1.0,1.0);
    }
}
