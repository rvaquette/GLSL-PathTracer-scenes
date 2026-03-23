#ifndef OPT_SHADERTOY_LIGHT

// START_BUFFERD_CODE
bool enableTonemap = true;
bool enableAces = false;
bool simpleAcesFit = false;
vec3 backgroundCol = vec3(1.000000, 1.000000, 1.000000);
// END_BUFFERD_CODE

uniform float invSampleCounter;

in vec2 TexCoords;

/*
 * MIT License
 *
 * Copyright(c) 2019 Asif Ali
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
 
// Sources:
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
// https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl

// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
mat3 ACESInputMat = mat3
(
    vec3(0.59719, 0.35458, 0.04823),
    vec3(0.07600, 0.90834, 0.01566),
    vec3(0.02840, 0.13383, 0.83777)
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
mat3 ACESOutputMat = mat3
(
    vec3(1.60475, -0.53108, -0.07367),
    vec3(-0.10208, 1.10813, -0.00605),
    vec3(-0.00327, -0.07276, 1.07602)
);

vec3 RRTAndODTFit(vec3 v)
{
    vec3 a = v * (v + 0.0245786f) - 0.000090537f;
    vec3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

vec3 ACESFitted(vec3 color)
{
    color = color * ACESInputMat;

    // Apply RRT and ODT
    color = RRTAndODTFit(color);

    color = color * ACESOutputMat;

    // Clamp to [0, 1]
    color = clamp(color, 0.0, 1.0);

    return color;
}

vec3 ACES(in vec3 c)
{
    float a = 2.51f;
    float b = 0.03f;
    float y = 2.43f;
    float d = 0.59f;
    float e = 0.14f;

    return clamp((c * (a * c + b)) / (c * (y * c + d) + e), 0.0, 1.0);
}

float Luminance(vec3 c)
{
    return 0.212671 * c.x + 0.715160 * c.y + 0.072169 * c.z;
}

vec3 Tonemap(in vec3 c, float limit)
{
    return c * 1.0 / (1.0 + Luminance(c) / limit);
}

void CreateTonemapImage( sampler2D pathTraceTexture, out vec4 outCol )
{
	vec4 col = texture(pathTraceTexture, TexCoords) * invSampleCounter;
    vec3 color = col.rgb;
    float alpha = col.a;

    if (enableTonemap)
    {
        if (enableAces)
        {
            if (simpleAcesFit)
                color = ACES(color);
            else
                color = ACESFitted(color);
        }
        else
            color = Tonemap(color, 1.5);
    }

    color = pow(color, vec3(1.0 / 2.2));

    float outAlpha = 1.0;
    vec3 bgCol = backgroundCol;

#ifdef OPT_TRANSPARENT_BACKGROUND
    outAlpha = alpha;
    float checkerSize = 10.0;
    float res = max(sign(mod(floor(fragCoord.x / checkerSize) + floor(fragCoord.y / checkerSize), 2.0)), 0.0);
    bgCol = mix(vec3(0.1), vec3(0.2), res);
#endif

#if defined(OPT_BACKGROUND) || defined(OPT_TRANSPARENT_BACKGROUND)
    outCol = vec4(mix(bgCol, color, alpha), outAlpha);
#else
    outCol = vec4(color, 1.0);
#endif
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    CreateTonemapImage(iChannel0, fragColor);
}

#else

// Set to the iChannel containing the alphabet texture
#define FONT_TEXTURE iChannel3

/// SETTINGS ///

// Horizontal character spacing (default: 0.5)
#define CHAR_SPACING 0.44

/// STRING CREATION ///

// Create a basic string
#define makeStr(func_name) float func_name(vec2 u) { _print 

// Create a string with an int parameter
#define makeStr1i(func_name) float func_name(vec2 u, int i) { _print

// Create a string with a float parameter
#define makeStr1f(func_name) float func_name(vec2 u, float i) { _print

// Create a string with two floats parameter
#define makeStr2f(func_name) float func_name(vec2 u, float i, float j) { _print

// ... Or create your own strings with any parameters
#define makeStrXX(func_name) float func_name(vec2 u, ...) { _print

// Terminate a string
#define _end    ); return d; }

/// SPECIAL FUNCTIONS ///

// Dynamic uppercase character
// i: [0-25]
#define _ch(i)  _ 65+int(i)

// Dynamic digit
// i: [0-9]
#define _dig(i) _ 48+int(i)

// Floating point debug
// x:   value to print
// dec: number of decimal places to print
#define _dec(x, dec) ); d += _decimal(FONT_TEXTURE, u, x, dec); (0

/// SPECIAL CHARACTERS ///

// Space
#define __    ); u.x -= CHAR_SPACING; (0

#define _EXC  _ 33 // " ! "
#define _DBQ  _ 34 // " " "
#define _NUM  _ 35 // " # "
#define _DOL  _ 36 // " $ "
#define _PER  _ 37 // " % "
#define _AMP  _ 38 // " & "
#define _QUOT _ 39 // " ' "
#define _LPR  _ 40 // " ( "
#define _RPR  _ 41 // " ) "
#define _MUL  _ 42 // " * "
#define _ADD  _ 43 // " + "
#define _COM  _ 44 // " , "
#define _SUB  _ 45 // " - "
#define _DOT  _ 46 // " . "
#define _DIV  _ 47 // " / "
#define _COL  _ 58 // " : "
#define _SEM  _ 59 // " ; "
#define _LES  _ 60 // " < "
#define _EQU  _ 61 // " = "
#define _GRE  _ 62 // " > "
#define _QUE  _ 63 // " ? "
#define _AT   _ 64 // " @ "
#define _LBR  _ 91 // " [ "
#define _ANTI _ 92 // " \ "
#define _RBR  _ 93 // " ] "
#define _UND  _ 95 // " _ "

/// CHARACTER DEFINITIONS ///

// Uppercase letters (65-90)
#define _A _ 65
#define _B _ 66
#define _C _ 67
#define _D _ 68
#define _E _ 69
#define _F _ 70
#define _G _ 71
#define _H _ 72
#define _I _ 73
#define _J _ 74
#define _K _ 75
#define _L _ 76
#define _M _ 77
#define _N _ 78
#define _O _ 79
#define _P _ 80
#define _Q _ 81
#define _R _ 82
#define _S _ 83
#define _T _ 84
#define _U _ 85
#define _V _ 86
#define _W _ 87
#define _X _ 88
#define _Y _ 89
#define _Z _ 90

// Lowercase letters (97-122)
#define _a _ 97
#define _b _ 98
#define _c _ 99
#define _d _ 100
#define _e _ 101
#define _f _ 102
#define _g _ 103
#define _h _ 104
#define _i _ 105
#define _j _ 106
#define _k _ 107
#define _l _ 108
#define _m _ 109
#define _n _ 110
#define _o _ 111
#define _p _ 112
#define _q _ 113
#define _r _ 114
#define _s _ 115
#define _t _ 116
#define _u _ 117
#define _v _ 118
#define _w _ 119
#define _x _ 120
#define _y _ 121
#define _z _ 122

// Digits (48-57)
#define _0 _ 48
#define _1 _ 49
#define _2 _ 50
#define _3 _ 51
#define _4 _ 52
#define _5 _ 53
#define _6 _ 54
#define _7 _ 55
#define _8 _ 56
#define _9 _ 57

/// Internal functions ///

// Start
#define _print  float d = 0.; (u.x += CHAR_SPACING

// Update
#define _       ); u.x -= CHAR_SPACING; d += _char(FONT_TEXTURE, u,

// Print character
float _char(sampler2D s, vec2 u, int id) {
    vec2 p = vec2(id%16, 15. - floor(float(id)/16.));
         p = (u + p) / 16.;
         u = step(abs(u-.5), vec2(.5));
    return texture(s, p).r * u.x * u.y;
}


// Color declarations
#define RED     vec3( 1,.3,.4)
#define GREEN   vec3(.2, 1,.4)

makeStr(printStr0)  _S _h _a _d _e _r _COL __ _O _L _D _S _H _A _C _K _R _O _O _F _T _O _P _P _R _O _P _2 _G _A _M _E _R _E _A _D _Y  _end
makeStr(printStr1)  _DIV _EXC _ANTI __ _R _u _n __ _t _h _e __ _J _S __ _C _o _d _e __ _t _o __ _e _x _e _c _u _t _e __ _DIV _EXC _ANTI _end
makeStr(printStr2)  __ __ __ __ __ __ __ __ __ __ __ _t _h _e __ _s _h _a _d _e _r _end
makeStr(printStr3)  __ __ __ __ __ __ __ __ __ __ __ __ __ __ __ _o _r _end
makeStr(printStr4)  __ __ __ _I _n _s _t _a _l _l __ _t _h _e __ _C _h _r _o _m _e __ _e _x _t _e _n _s _i _o _n _end
makeStr(printStr5)  __ __ __ __ __ __ __ _LPR _S _e _e __ _f _i _r _s _t __ _c _o _m _m _e _n _t _RPR _end

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.y;
    
    vec3 col = vec3(0);
    
    // Font Size (higher values = smaller font)
    const float font_size = 9.;
    
    uv *= font_size;        // Scale font with font_size
    
    uv.y -= font_size - 1.;
    col += printStr0(uv);   
    
    uv.y += 1.;
    col += RED * printStr1(uv);   
    
    uv.y += 1.;
    col += RED * printStr2(uv); 
    
    uv.y += 1.5;
    col += GREEN * printStr3(uv); 
    
    uv.y += 1.5;
    col += GREEN * printStr4(uv); 
    
    uv.y += 2.;
    col += printStr5(uv); 
    
    fragColor = vec4(col, 1.);
}

#endif
