////// GUI //////

const float EPSILON = 0.00001;
const float SLIDER_BAR_HEIGHT = 0.02;

struct Rect {
    vec2 start;
    vec2 size;
};

struct Slider {
    Rect bar;
    vec2 slider;
};

Slider CreateSlider(vec4 bar, vec2 blockSize) {
    return Slider(
        Rect(bar.xy, bar.zw), blockSize
    );
}

bool IsInsideRect(vec2 coord, Rect rect) {
    vec2 start = rect.start;
    vec2 end = start + rect.size;
    vec2 isInsideRect = smoothstep(start - EPSILON, start + EPSILON, coord) 
        - smoothstep(end - EPSILON, end + EPSILON, coord);
    return isInsideRect.x * isInsideRect.y > 0.;
}

vec4 DrawSlider(vec2 coord, Slider slider, int index) {
    // draw bar
    bool isInsideBar = IsInsideRect(coord, slider.bar);
    
    //float last = textureLod(iChannel0, vec2(.5) / iChannelResolution[0].xy, 0.0).r;
    float last = texelFetch(iChannel0, ivec2(index), 0).r;
    vec2 mouseCoord = iMouse.xy / iResolution.xy;
    bool isMouseInsideBar = IsInsideRect(mouseCoord, slider.bar);
    float curX = last * slider.bar.size.x + slider.bar.start.x;
    if (isMouseInsideBar) {
        curX = mouseCoord.x;
        last = (mouseCoord.x - slider.bar.start.x) / slider.bar.size.x;
    }
    
    Rect realSlider = Rect(vec2(curX, slider.bar.start.y + .5 *(slider.bar.size.y - slider.slider.y)), slider.slider);
    bool isInsideBlock = IsInsideRect(coord, realSlider);
    
    if (isInsideBlock) {
        return vec4(1.,1.,1.,1.);
    } else  if (isInsideBar) {
        return vec4(.5,.5,.5,1.);
    }
    
    return vec4(iFrame == 0 ? .5 : last, .0, 0., 0.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 uv = fragCoord / iResolution.xy;
    Slider slider1 = CreateSlider(vec4(0.01, 0.5, 0.15, 0.02), vec2(0.01, 0.03));
    
    fragColor = DrawSlider(uv, slider1, 0);
}
