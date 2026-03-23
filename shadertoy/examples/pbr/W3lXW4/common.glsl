float c01(float a) {return clamp(a,0.,1.);}

//DAVE HOSKINS' HASH FUNCTIONS
float rnd11(float p)
{
    p = fract(p * .1031);
    p *= p + 33.33;
    return fract(2.*p*p);
}

vec3 rnd23(vec2 p)
{
	vec3 p3 = fract(p.xyx * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy+p3.yzz)*p3.zyx);
}

vec3 rnd33(vec3 p3)
{
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// rotation function
mat2 rot(float a) {return mat2(cos(a),sin(a),-sin(a),cos(a));}

// fade in, stay on for d duration and then fade out 
float block(float t, float d, float fi, float fo) {
	return c01(t/fi+1.)*c01((d-t)/fo+1.);
}

// out 1 for half the time and then 0 for the rest, with fade in/out
float chop(float t) {
	return c01(min(fract(t)*30.,fract(1.-t)*30.-15.));
}

// only for webgl, as it gives infinites when normalizing a zero vector, which lead to visual glitches
vec3 safenorm(vec3 val) {
    float vald=length(val);
    if(vald<=0.) return vec3(0,1,0);
    return val/vald;
}
