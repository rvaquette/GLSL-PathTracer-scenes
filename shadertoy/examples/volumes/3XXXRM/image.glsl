#define PI 3.14159265358979
#define MARCH_SCALE 1.0


vec4 background(vec3 rd)
{
  float t = 1.0 - abs(rd.z);
  return mix(vec4(0.5, 0.5, 0.5, 1.0), vec4(0.5, 0.5, 0.8, 1.0), 1.0-t*t);
}

struct marchResult
{
  vec3 pos;
  vec3 norm;
  float inBounds;
  float depth;
  vec4 color;
};

struct transparentMarchResult
{
  float opacity;
  vec4 color;
};

struct OrbLightDescription
{
    vec3 pos;
    float Radius;
    vec3 color;
};

vec3 GetLightColor(int lightIndex)
{
    switch(lightIndex)
    {
        case 0: return vec3(1, 0.0, 1.0);
        case 1: return vec3(0, 1.0, 0.0);
    }
    return vec3(0, 0.0, 1.0);
}

OrbLightDescription GetLight(int lightIndex)
{
    const float lightMultiplier = 17.0f;
    float theta = iTime * 0.7 + float(lightIndex) * PI * 2.0 / float(3);
    float radius = 28.5f;
    
    OrbLightDescription orbLight;
    orbLight.pos = vec3(radius * cos(theta), radius * sin(theta), 16.0 + sin(theta * 2.0) * 2.5);
    orbLight.color = GetLightColor(lightIndex) * lightMultiplier;
    orbLight.Radius = 0.8f;

    return orbLight;
}

// --------------------------------------------//
//               Noise Functions
// --------------------------------------------//
// Taken from Inigo Quilez's Rainforest ShaderToy:
// https://www.shadertoy.com/view/4ttSWf
float hash1( float n )
{
    return fract( n*17.0*fract( n*0.3183099 ) );
}

// Taken from Inigo Quilez's Rainforest ShaderToy:
// https://www.shadertoy.com/view/4ttSWf
float noise( in vec3 x )
{
    vec3 p = floor(x);
    vec3 w = fract(x);
    
    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    
    float n = p.x + 317.0*p.y + 157.0*p.z;
    
    float a = hash1(n+0.0);
    float b = hash1(n+1.0);
    float c = hash1(n+317.0);
    float d = hash1(n+318.0);
    float e = hash1(n+157.0);
	float f = hash1(n+158.0);
    float g = hash1(n+474.0);
    float h = hash1(n+475.0);

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z);
}

const mat3 m3  = mat3( 0.00,  0.80,  0.60,
                      -0.80,  0.36, -0.48,
                      -0.60, -0.48,  0.64 );

// Taken from Inigo Quilez's Rainforest ShaderToy:
// https://www.shadertoy.com/view/4ttSWf
float fbm_4( in vec3 x )
{
    float f = 2.0;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;
    for( int i=min(0, iFrame); i<4; i++ )
    {
        float n = noise(x);
        a += b*n;
        b *= s;
        x = f*m3*x;
    }
	return a;
}

// Taken from https://iquilezles.org/articles/distfunctions
float sdSphere( vec3 p, float s )
{
  return length(p)-s;
}

// Taken from https://iquilezles.org/articles/distfunctions
float sdPlane( vec3 p )
{
	return p.z;
}

float SmoothUnion( float d1, float d2, float k ) 
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

float QueryVolumetricDistanceField(vec3 ro)
{
  vec3 fbmCoord = (ro + 2.0 * vec3(iTime, 0.0, iTime)) / 1.5f;
  float sdfValue = sdSphere(ro - vec3(-8.0, 2.0 + 20.0 * sin(iTime), -1), 5.6);
  sdfValue = SmoothUnion(sdfValue,sdSphere(ro - vec3(8.0, 8.0 + 12.0 * cos(iTime), 3), 5.6), 3.0f);
  sdfValue = SmoothUnion(sdfValue, sdSphere(ro - vec3(5.0 * sin(iTime), 3.0, 0), 8.0), 3.0) + 7.0 * fbm_4(fbmCoord / 3.2);
  sdfValue = SmoothUnion(sdfValue, sdPlane(ro + vec3(0, 0.4, 0)), 22.0);
  return sdfValue;
}

// 18 ops + mod
marchResult traceToOpaque(vec3 ro, vec3 rd)
{
  float d = -ro.z / rd.z;
  ro += d*rd;
  float tileIdx = mod(floor(ro.x * 0.2) + floor(ro.y * 0.2), 2.0);
  
  marchResult result;
  result.inBounds = step(0.0, d);
  result.pos = ro;
  result.norm = vec3(0.0, 0.0, 1.0);
  result.color = vec4(vec3(0.2 + 0.6*tileIdx), 1.0);
  result.depth = d;
  return result;
}

// 400 ops, 54 calls to QueryVField
// ~40,000 ops
marchResult marchToTransparent(vec3 ro, vec3 rd)
{
  int i = 0;
  float d = 0.0;
  float depth = 0.0;
  for (; i < 50; ++i)
  {
    d = QueryVolumetricDistanceField(ro);
    ro += 1.0*d*rd;
    depth += d;
    if (d < 0.1)
    {
      break;
    }
  }
  marchResult result;
  result.pos = ro;
  bool inBounds = i < 50 || dot(ro, ro) < 1e4;
  result.inBounds = inBounds ? 1.0 : 0.0;
  if (inBounds)
  {
    result.color = vec4(1, 1, 1, 1);
    d = QueryVolumetricDistanceField(ro);
    result.norm.x = QueryVolumetricDistanceField(ro + vec3(0.001, 0.0, 0.0)) - d;
    result.norm.y = QueryVolumetricDistanceField(ro + vec3(0.0, 0.001, 0.0)) - d;
    result.norm.z = QueryVolumetricDistanceField(ro + vec3(0.0, 0.0, 0.001)) - d;
    result.norm = normalize(result.norm);
    result.depth = depth;
  }
  return result;
}

// 700 ops
float fogDensity(in vec3 pos)
{
  //return QueryVolumetricDistanceField(pos) < 0.0 ? 1.0 : 0.0;
  return clamp(-QueryVolumetricDistanceField(pos), 0.0, 0.5);
}

// 10 ops
float massTransparency(float mass)
{
  return pow(0.9, mass*10.0);
}

// 10 ops
float massOpacity(float mass)
{
  return 1.0 - pow(0.9, mass * 5.0);
}

// 20 calls to volume field
// 14,000 ops
float fastOpacityIntegral(vec3 ro, vec3 re)
{
  float intervalLength = length(ro-re);
  vec3 rd = (re-ro) / intervalLength;
  float stepLength = max(0.5, intervalLength / 20.0);
  float totalMass = 0.0;
  float d = 0.0;
  vec3 pos = ro;
  
  do
  {
    float depth = QueryVolumetricDistanceField(pos);
    if (depth > 2.0) break;
    float thisStepLength = max(stepLength, depth);
    //return massOpacity(clamp(-depth, 0.0, 5.0));
    totalMass += thisStepLength * clamp(-depth, 0.0, 5.0);
    d += thisStepLength;
    pos += thisStepLength*rd;
  } while (false && d < intervalLength && totalMass < 4.0);
  return massOpacity(totalMass);
}

// (intervalLength/stepLength) calls to fogDensity, 700 ops per
// up to 100ish in the far corners:
// 100,000 ops
float fastOpacityIntegral2(vec3 ro, vec3 re)
{
  float totalMass = 0.0;
  const float stepLength = 1.0;
  float fogDepth = max(0.0, QueryVolumetricDistanceField(ro));
  // approximate integral as (distance into fog) * (fog density)
  return fogDepth * clamp(fogDepth, 0.0, 1.0);
  float intervalLength = length(ro-re);
  vec3 rd = normalize(re-ro);
  vec3 pos = ro;
  for (int i = 0; i < int(floor(intervalLength / stepLength)); ++i)
  {
    totalMass += stepLength * fogDensity(pos);
    pos += rd*stepLength;
    //if (totalMass > -10.0) break;
  }
  return massOpacity(totalMass);
}

// 38 ops, 1 squaredSphereChordLength call, 1 massOpacity call
// 63 ops
float fastOpacityIntegral3(vec3 ro, vec3 re)
{
  float totalMass = 0.0;
  float intervalLength = length(ro-re);
  vec3 rd = (re-ro) / intervalLength;
  vec3 pos = 0.5 * (ro+re);
  // this is some bullshit
  // just pretend the fog is a big sphere and calculate (squared) distance through it
  
  //totalMass = 0.0002 * intervalLength * squaredSphereChordLength(vec3(0.5, 0.5, 0.6)*pos - vec3(0,0,5), rd, 10.0);
  return massOpacity(totalMass);
}

// 4 + 3*(3 + 10 + 11 + 8) ops
// 100 ops, 3 calls to fastOpacityIntegral2
// 300,000 ops
vec4 calcLight(vec3 pos, vec3 norm)
{
  vec4 ambientLight = 0.3*vec4(1,1,1,0);
  vec4 color = vec4(0,0,0,1);
  for (int i = 0; i < 3; ++i)
    {
      OrbLightDescription light = GetLight(i);
      vec3 toLight = light.pos - pos;
      float dist = length(toLight);
      float cosAngle = max(0.0, dot(toLight, norm)) / dist;
      // use the more accurate opacity integral for the lighting that gets calculated once per pixel
      color.rgb += light.color * cosAngle * 1.0/dist * (1.0 - fastOpacityIntegral(pos, light.pos));
      //color.rgb += (cosAngle * 1.0/dist) * light.color;
    }
    return color + ambientLight;
}

// 100 ops, 3 calls to fastOpacityIntegral3
vec4 calcLight(vec3 pos)
{
  vec4 ambientLight = 0.3*vec4(1,1,1,0);
  vec4 color = vec4(0,0,0,1);
  for (int i = 0; i < 3; ++i)
    {
      OrbLightDescription light = GetLight(i);
      vec3 toLight = light.pos - pos;
      float dist = length(toLight);
      // this gets integrated over again anyway so who gives a shit
      //color.rgb += light.color * 1.0/dist * (1.0 - fastOpacityIntegral3(light.pos, pos));
      color.rgb += light.color * 1.0/dist * (1.0 - fastOpacityIntegral(pos, light.pos));
      //color.rgb += light.color * 1.0/dist;
    }
    return color + ambientLight;
}

// 1000 ops, 100 calls to fogDensity, 100 calls to massOpacity, 100 calls to calcLight
// 75,000 ops, 100 calls to calcLight(vec3)
transparentMarchResult marchThroughTransparent(vec3 ro, vec3 rd, float maxDepth, vec3 backgroundColor)
{
  vec3 color = vec3(0);
  vec3 fogBaseColor = vec3(0.8);
  float densityIntegral = 0.0;
  //vec3 color = backgroundColor;
  const float stepLength = 0.25;
  float previousDensity = 0.0;
  float density = 0.0;
  float totalTransparency = 1.0;
  vec3 pos = ro;
  float maxStepsFloat = min(100.0, maxDepth / stepLength);
  int maxSteps = int(maxStepsFloat);
  float finalStep = min(stepLength, maxDepth - float(maxSteps)*stepLength);
  for (int i = 0; i < maxSteps; ++i)
  {
    // could improve this by detecting when we're outside the fog
    pos += stepLength*rd;
    density = fogDensity(pos);
    //float intervalMass = 0.5*stepLength*(previousDensity + density);
    float intervalMass = 2.0*stepLength*(density);
    //float intervalOpacity = massOpacity(intervalMass);
    float intervalTransparency = massTransparency(intervalMass);
    float prevTransparency = totalTransparency;
    totalTransparency *= intervalTransparency;
    float intervalWeight = prevTransparency - totalTransparency;
    vec3 intervalColor = fogBaseColor * calcLight(pos).rgb;
    color += intervalColor * intervalWeight;
    
    densityIntegral += intervalMass;
    previousDensity = density;
  }
  pos += finalStep*rd;
  density = fogDensity(pos);
  //float intervalMass = 0.5*stepLength*(previousDensity + density);
  float intervalMass = 2.0*finalStep*(density);
  //float intervalOpacity = massOpacity(intervalMass);
  float intervalTransparency = massTransparency(intervalMass);
  float prevTransparency = totalTransparency;
  totalTransparency *= intervalTransparency;
  float intervalWeight = prevTransparency - totalTransparency;
  vec3 intervalColor = fogBaseColor * calcLight(pos).rgb;
  color += intervalColor * intervalWeight;
  
  densityIntegral += intervalMass;
  previousDensity = density;
  //color = mix(color, intervalColor, intervalOpacity);
  //color = vec3(abs(pos.z));
  //color = vec3(float(maxSteps) / 10.0);
  
  transparentMarchResult result;
  result.opacity = 1.0 - totalTransparency;
  result.color = vec4(color + backgroundColor*totalTransparency, 1);
  // result.emission = vec4(0,0,0,0);
  return result;
}

// called once per pixel = 810,000 times
// some ops, one call to traceToOpaque, one call to calcLight(vec3, vec3), one call to marchToTransparent,
// one call to marchThroughTransparent
// 810k * (18 + 1 calcLight(vec3, vec3) + 40k + 75k + 100 calcLight(vec3))
// 92G + 810k calcLight(vec3, vec3) + 81M calcLight(vec3)
// i forgot that FMAs are a thing while calculating this fffffffuuuuuuuuuuuuuuuuuuuuuuuuuu
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from -1 to 1)
    vec2 uv = (2.0 * fragCoord - iResolution.xy) /iResolution.x;
    
    vec3 cameraPos = vec3(-70.0 * cos(0.5), 70.0*sin(0.5), 35.0);
    vec3 cameraDirection = -normalize(cameraPos);
    float nearPlane = 1.5;
    vec3 cameraUp = vec3(0.0, 0.0, 1.0);
    cameraUp = cameraUp - dot(cameraUp, cameraDirection) * cameraDirection;
    vec3 cameraRight = cross(cameraDirection, cameraUp);
    vec3 rd = normalize(nearPlane*cameraDirection + uv.x*cameraRight + uv.y*cameraUp);
    
    // draw background
    fragColor = background(rd);
    
    // draw floor
    marchResult floorRes = traceToOpaque(cameraPos, rd);
    vec4 light = calcLight(floorRes.pos, floorRes.norm);
    fragColor = mix(fragColor, floorRes.color * light, floorRes.inBounds);
    
    
    // raymarch volumetric
    marchResult marchRes = marchToTransparent(cameraPos, rd);
    float maxDepth = floorRes.inBounds == 1.0 ? floorRes.depth - marchRes.depth : 100.0f;
    transparentMarchResult transRes = marchThroughTransparent(marchRes.pos, rd, maxDepth, fragColor.rgb);
    fragColor = transRes.color;
    
    //fragColor.rgb = vec3(fastOpacityIntegral(floorRes.pos, cameraPos));
    //fragColor.rgb = vec3(-QueryVolumetricDistanceField(floorRes.pos));
    
    
    //light = calcLight(marchRes.pos, marchRes.norm);
    //surfColor *= light;
    //surfColor.rgb = 0.5 + 0.5*marchRes.norm;
    //fragColor = mix(fragColor, surfColor, transRes.opacity);
    //fragColor.rgb = vec3(10.0 / maxDepth);
    fragColor.rgb = pow(fragColor.rgb, vec3(1.0/2.2));
    fragColor.a = 1.0;
}
