// control loop

const float FOCUS_SLIDER = 1.;
const float FOCUS_OBJ    = 2.;

struct AppState
{
    float   menuId;
    float   roughness;
    float   focus;
    vec2    focusObjRot;
    vec2    objRot;
};

vec4 LoadValue(int x, int y)
{
    return texelFetch(iChannel0, ivec2(x, y), 0);
}

void LoadState(out AppState s)
{
    vec4 data;

    data = LoadValue(0, 0);
    s.menuId    = data.x;
    s.roughness = data.y;
    s.focus     = data.z;
    
    data = LoadValue(1, 0);
    s.focusObjRot   = data.xy;
    s.objRot        = data.zw;
}

void StoreValue(vec2 re, vec4 va, inout vec4 fragColor, vec2 fragCoord)
{
    fragCoord = floor(fragCoord);
    fragColor = (fragCoord.x == re.x && fragCoord.y == re.y) ? va : fragColor;
}

vec4 SaveState(in AppState s, in vec2 fragCoord)
{
    if (iFrame <= 0)
    {
        s.menuId      = 0.0;
        s.roughness   = 0.5;
        s.focus       = 0.0;
        s.focusObjRot = vec2(0.0);
        s.objRot      = vec2(0.0);
    }
    
    vec4 ret = vec4(0.);
    StoreValue(vec2(0., 0.), vec4(s.menuId, s.roughness, s.focus, 0.0), ret, fragCoord);
    StoreValue(vec2(1., 0.), vec4(s.focusObjRot, s.objRot), ret, fragCoord);
    return ret;
}

float saturate(float x)
{
    return clamp(x, 0., 1.);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    if (fragCoord.x >= 8. || fragCoord.y >= 8.) 
    {
        discard;    
    }

    AppState s;
    LoadState(s);
    
    vec4 q = iMouse / iResolution.xyxy;
    vec4 m = -1. + 2. * q;
    m.xz *= iResolution.x / iResolution.y;    
    m *= 100.;    

    vec4 sliderM = m - vec2(110, 94.5).xyxy;
    if (sliderM.z >= -4. && sliderM.z < 44. && sliderM.w >= -20. && sliderM.w < -10.)
    {
        s.focus = FOCUS_SLIDER;
    } 
    else if (m.w > -100. && m.w < 40. && abs(m.z + 20.) < 70.)
    {
        if (s.focus != FOCUS_OBJ)
        {
            s.focusObjRot = s.objRot; 
        }
        s.focus = FOCUS_OBJ;
    }
    else
    {
        s.focus = 0.;
        vec2 mp = (m.xy - vec2(-160, -1));
        float menuId = mp.x < 40. || (mp.x < 60. && (mp.y > 18. && mp.y < 24.)) ? 10. - floor(mp.y / 8.) : -1.;
        if (menuId >= 0. && menuId <= 2.)
        {
            s.menuId = menuId;
        }
    }

    if (s.focus == FOCUS_SLIDER)
    {
        s.roughness = saturate(sliderM.x / 40.);    
    } 
    if (s.focus == FOCUS_OBJ)
    {
        s.objRot = s.focusObjRot + .04 * (m.xy - m.zw);
    }
    
    fragColor = SaveState(s, fragCoord);
}
