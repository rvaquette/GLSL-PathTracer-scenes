// Heightmap for a knitted texture.

float saturate(float x){
	return clamp(x, 0.0, 1.0);
}

float remap(float x, float low1, float high1, float low2, float high2){
	return low2 + (x - low1) * (high2 - low2) / (high1 - low1);
}

vec2 rotate(vec2 p, float angle){
	return mat2(cos(angle), sin(angle), -sin(angle), cos(angle)) * p;
}

float circularOut(float f){
  return sqrt((2.0 - f) * f);
}

float getCellHeight(vec2 p, vec2 id){
    
    vec2 height;
    
    float d = circularOut(1.0-length(p.x));
    float detail;
    float angle;
    
    float theta = sin(7.38);
	float detailTheta = sin(1.68);
    
    float repeat = 4.0;
    float threadRepeat = 10.0;
    
    if(mod(id.x, 2.0) == 0.0){
        detail = 0.85*abs(cos(repeat*(rotate(p, theta)).x));
        angle = detailTheta;
    }else{
        detail = 0.85*abs(cos(-repeat*(rotate(p, -theta)).x));
        angle = -detailTheta;
    }
    
    d = pow(d, 2.0) * saturate(remap(d, detail, 1.1, 0.0, 1.0));
    detail = 0.12 * sin(threadRepeat*(rotate(p, angle)).x);
  
    return saturate(remap(d, detail, 1.0, 0.0, 1.0));

}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){    
    
    bool resolutionChanged = (texelFetch(iChannel0, ivec2(0.5, 2.5), 0).x == 1.0);
    
    // Draw map at the first frame or when the resolution has changed.
    if(iFrame < 1 || resolutionChanged || length(texture(iChannel2, vec2(0)).rgb) > 0.0){
    	vec2 scale = vec2(10.0, 10.0);
        vec2 uv;
        float height;
        uv = fragCoord.xy/iResolution.xy;
        uv *= scale;
        vec2 p = fract(uv)-0.5;
        vec2 id = floor(uv);

        height = getCellHeight(p, id);
        fragColor = vec4(height, 
                         length(texture(iChannel2, (fragCoord/iResolution.xy)).rgb), 
                         0.0, 
                         1.0);
    }else{
        fragColor = texelFetch(iChannel1, ivec2(fragCoord), 0);
    }
}