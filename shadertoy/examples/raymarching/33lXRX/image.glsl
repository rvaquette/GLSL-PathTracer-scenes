#define MAX_MARCHING_STEPS 64
#define EPSILON 0.0001
#define TINT vec3(.6, 1., 1.2)

float smin( float a, float b, float k ){
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

float sdRoundCone(vec3 p, float r1, float r2, float h){
  vec2 polar = vec2(atan(p.z, p.x)/(PI*2.)+.5,
                    smoothstep(-2.5,5., p.y));
  float n = .75 * texture(iChannel0, polar).x;
  vec2 q = vec2( length(p.xz), p.y);
    
  float b = (r1-r2)/h;
  float a = sqrt(1.0-b*b)-n;
  float k = dot(q,vec2(-b,a));

  if( k < 0.0 ) return length(q + vec2(0., -.1)) - r1 - n;

  return dot(q, vec2(a,b) ) - r1;
}

float world(vec3 p){
    float result = smin(p.x,
        sdRoundCone(vec3(abs(p.x), p.yz) + vec3(-.75, 1.5, 0.), 1., .25, 3.), 1.);
    return result;
}

float march(vec3 eye, vec3 marchingDirection){
	const float precis = .01;
    float t = 0.0;
	float l = 0.0;
    for(int i=0; i<MAX_MARCHING_STEPS; i++){
	    float hit = world( eye + marchingDirection * t );
        if( hit < precis ) return t;
        t += hit;
    }
    return -1.;
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        world(vec3(p.x + EPSILON, p.y, p.z)) - world(vec3(p.x - EPSILON, p.y, p.z)),
        world(vec3(p.x, p.y + EPSILON, p.z)) - world(vec3(p.x, p.y - EPSILON, p.z)),
        world(vec3(p.x, p.y, p.z  + EPSILON)) - world(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

vec4 render(in vec2 fragCoord){
	vec3 color = vec3(0.);
    float a = (sin(iTime) * .5 + .5);
    a = mix(PI/4., PI*3./4., a);
    vec3 eye = vec3(15. * sin(a), 0., 15. * cos(a));
    vec3 viewDir = rayDirection(45., iResolution.xy, fragCoord);
    vec3 worldDir = viewMatrix(eye, vec3(0., .2, 0.), vec3(0., 1., 0.)) * viewDir;
	
    float hit = march(eye, worldDir);
    if (hit > 0.) {
        vec3 p = (eye + hit * worldDir);
        vec3 norm = estimateNormal(p);
        color = TINT * (1.-abs(dot(worldDir, norm)));
    }
    return vec4(color, 1.);
}

#define AA 2
void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    fragColor = vec4(0.);
    for(int y = 0; y < AA; ++y)
        for(int x = 0; x < AA; ++x){
            fragColor += clamp(render(fragCoord + vec2(x, y) / float(AA)), 0., 1.);
        }
    fragColor.rgb /= float(AA * AA);
}
