///////////////////////////////////////////////////////////////////////////////////

struct Material {
    vec3 colour;
    float diffuse;
    float specular;
};
    
struct Ray {
    vec3 pos;
    vec3 dir;
};
    
struct Light {
    vec3 pos;
    vec3 colour;
};
    
struct Result {
    vec3 pos;
    vec3 normal;
    Material mat;
    vec4 fog;
};

///////////////////////////////////////////////////////////////////////////////////

float blerp(float x, float y0, float y1, float y2, float y3) {
	float a = y3 - y2 - y0 + y1;
	float b = y0 - y1 - a;
	float c = y2 - y0;
	float d = y1;
	return a * x * x * x + b * x * x + c * x + d;
}

float rand(vec2 co){
  return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float perlin(float x, float h) {
	float a = floor(x);
	return blerp(mod(x, 1.0),
		rand(vec2(a-1.0, h)), rand(vec2(a-0.0, h)),
		rand(vec2(a+1.0, h)), rand(vec2(a+2.0, h)));
}

void ViewVector(in float time, out vec3 p0, out vec3 p1)
{
    float ft = time-1.0;
	p0 = vec3(4.0 - perlin(ft*0.25, 7.5)*8.0, 3.0 - perlin(ft*0.25, 8.5)*6.0, 0.0);  
    ft+=0.5;
	p1 = vec3(4.0 - perlin(ft*0.25, 7.5)*8.0, 3.0 - perlin(ft*0.25, 8.5)*6.0, 0.0); 
}
