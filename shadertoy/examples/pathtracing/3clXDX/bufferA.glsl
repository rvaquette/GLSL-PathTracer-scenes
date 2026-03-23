#define APERTURE 0.1      /* diameter of the lens */
#define VERTICAL_FOV 25.  /* degrees */

#define MAX_BOUNCES 7
#define SAMPLES_PER_PIXEL 8


#define SRGB_TO_LINEAR(R,G,B) pow(vec3(R,G,B) / vec3(255,255,255), vec3(2.2))
const vec3 _gold   = SRGB_TO_LINEAR(255,226,115);
const vec3 _silver = SRGB_TO_LINEAR(252,250,245);
const vec3 _copper = SRGB_TO_LINEAR(250,208,192);


const int _numSpheres = 8;
Sphere[_numSpheres] _spheres;
void InitScene()
{
    vec3 v = vec3(.15,.5,.85);
    
    // Ground
	_spheres[0].Center = vec3(0,-1000,0);
    _spheres[0].Radius = 1000.;
    _spheres[0].Mat.BaseColor = v.bbb;
    _spheres[0].Mat.Metalness = 0.;
    _spheres[0].Mat.Roughness = 0.2;
    _spheres[0].Mat.Emissive = 0.;
    _spheres[0].Mat.IsCheckerHack = true;
    
    // Light    
	_spheres[1].Center = vec3(-35,35,35);
    _spheres[1].Radius = 15.;
    _spheres[1].Mat.BaseColor = vec3(1);
    _spheres[1].Mat.Metalness = 0.;
    _spheres[1].Mat.Roughness = 0.;
    _spheres[1].Mat.Emissive = 10.;
    
    
    // Metal balls
    _spheres[2].Center = vec3(-5,2.,2.5);
    _spheres[2].Radius = 2.;
    _spheres[2].Mat.BaseColor = _silver;
    _spheres[2].Mat.Metalness = 1.;
    _spheres[2].Mat.Roughness = 0.02;
    _spheres[2].Mat.Emissive = 0.;
    
	_spheres[3].Center = vec3(0,2.,2.5);
    _spheres[3].Radius = 2.;
    _spheres[3].Mat.BaseColor = _gold;
    _spheres[3].Mat.Metalness = 1.;
    _spheres[3].Mat.Roughness = 0.2;
    _spheres[3].Mat.Emissive = 0.;
    
    _spheres[4].Center = vec3(5.,2.,2.5);
    _spheres[4].Radius = 2.;
    _spheres[4].Mat.BaseColor = _copper;
    _spheres[4].Mat.Metalness = 1.;
    _spheres[4].Mat.Roughness = 0.7;
    _spheres[4].Mat.Emissive = 0.;
    
    
    // RGB balls
    _spheres[5].Center = vec3(-5.,2,-2.5);
    _spheres[5].Radius = 2.;
    _spheres[5].Mat.BaseColor = v.brr;
    _spheres[5].Mat.Metalness = 0.;
    _spheres[5].Mat.Roughness = .65;
    _spheres[5].Mat.Emissive = 0.;
    
	_spheres[6].Center = vec3(0,2,-2.5);
    _spheres[6].Radius = 2.;
    _spheres[6].Mat.BaseColor = v.rbr;
    _spheres[6].Mat.Metalness = 0.;
    _spheres[6].Mat.Roughness = 0.05;
    _spheres[6].Mat.Emissive = 6.;
    
    _spheres[7].Center = vec3(5.,2.,-2.5);
    _spheres[7].Radius = 2.;
    _spheres[7].Mat.BaseColor = v.rrb;
    _spheres[7].Mat.Metalness = 0.;
    _spheres[7].Mat.Roughness = .01;
    _spheres[7].Mat.Emissive = 0.;
    
}


// OTHER //////////////////////////////////////////////////////////////////////////////////
    
vec4 EncodeNumFramesAccumulated(float frame)
{
    return vec4(frame,0,0,0);
}

float DecodeNumFramesAccumulated()
{
    return texelFetch(iChannel0, ivec2(0,0), 0).r;
}

mat3 ViewLookAtMatrix(vec3 eye, vec3 target, float roll)
{
	vec3 rollVec = vec3(sin(roll), cos(roll), 0.);
	vec3 w = normalize(eye-target); // right handed TODO Change all math to left handed? 
	vec3 u = normalize(cross(rollVec,w));
	vec3 v = normalize(cross(w,u));
    return mat3(u, v, w);
}
      

// SCENE //////////////////////////////////////////////////////////////////////////////////
           
bool HitSphere(Sphere sph, Ray ray, float tMin, float tMax, inout Hit outHit)
{
    vec3 oc = ray.Origin - sph.Center;
    
    float a = dot(ray.Dir, ray.Dir);
    float half_b = dot(oc, ray.Dir);
    float c = length2(oc) - sph.Radius*sph.Radius;
    float discriminant = half_b*half_b - a*c;
    
    
    if (discriminant > 0.) 
    {
        float root = sqrt(discriminant);
        float temp = (-half_b - root)/a;
       
        if (temp > tMin && temp < tMax) 
        {
            outHit.LengthAlongRay = temp;
            outHit.Pos = ray.Origin + ray.Dir*temp;
            
            //vec3 outwardNormal = (hit.Pos - sph.Center) / sph.Radius;
            //hit.IsFrontFace = dot(outwardNormal, ray.Dir) < 0.;
            //hit.Normal = hit.IsFrontFace ? outwardNormal : -outwardNormal;
            outHit.Normal = (outHit.Pos - sph.Center) / sph.Radius;
            outHit.Mat = sph.Mat;
        	return true;
        }
        
        temp = (-half_b + root)/a;
        if (temp > tMin && temp < tMax)
        { 
            outHit.LengthAlongRay = temp;
            outHit.Pos = ray.Origin + ray.Dir*temp;
            
            //vec3 outwardNormal = (hit.Pos - sph.Center) / sph.Radius;
            //hit.IsFrontFace = dot(outwardNormal, ray.Dir) < 0.;
            //hit.Normal = hit.IsFrontFace ? outwardNormal : -outwardNormal;
            outHit.Normal = (outHit.Pos - sph.Center) / sph.Radius;
            outHit.Mat = sph.Mat;
        	return true;
        }
    }
    
    return false;
}

bool FindClosestHit(Ray ray, inout Hit outHit)
{
    float tMin = 0.0001;
    float closestSoFar = BIG_FLOAT;
    
    bool hitAnything = false;

    Hit tempHit;
    for (int i = 0; i < _numSpheres; i++)
    {
        Sphere sph = _spheres[i];
        if (HitSphere(sph, ray, tMin, closestSoFar, tempHit))
        {
			hitAnything = true;
            closestSoFar = tempHit.LengthAlongRay;
            outHit = tempHit;
        }
    }
    
    return hitAnything;
}

vec3 _skyColor;

vec3 Color(Ray ray, float seed)
{
    const float epsilon = 0.001;
    
	vec3 attenuation = vec3(1);
    Hit hit;
    
    
    for (int bounce = 0; bounce < MAX_BOUNCES; bounce++)
    {
		if (FindClosestHit(ray, hit))
        {
            if (hit.Mat.IsCheckerHack) // Quick hack to add some checkery goodness
            {
            	vec3 fragPos = ray.Origin + ray.Dir*hit.LengthAlongRay; 
                fragPos *= .3;
                vec2 q = floor(vec2(fragPos.x, fragPos.z));
    			float f = mod(q.x+q.y, 2.0);  // xor pattern
                
                hit.Mat.BaseColor = mix(_copper, vec3(.12), f);
                hit.Mat.Roughness = mix(0.75, 0.2, f);
                //hit.Mat.Metalness = 0.;
            }
            
            if (hit.Mat.Emissive > epsilon)
            {
            	attenuation *= hit.Mat.Emissive * vec3(hit.Mat.BaseColor); 
                break; // End tracing
            }
             
            
            // Random values
            float raySeed = seed + 7.1*float(iFrame) + 5681.123 + float(bounce)*92.13;
            bool isDiffuseRay = hash11(raySeed + 23.5123) < 0.5; // TODO this should be weighted by the Fresnel term so we fire more useful rays. Need to think about it to it's unbiased as our F0 is RGB.
            
            
            // Fire a ray
            vec3 L = isDiffuseRay
                ? hit.Normal + RandomUnitVector(raySeed)
                : reflect(ray.Dir, hit.Normal) + hit.Mat.Roughness*RandomInUnitSphere(raySeed+17.1321);
            
            
            // Some constants
            vec3 fragPos = ray.Origin + ray.Dir*hit.LengthAlongRay; // intersection point
            vec3 V = normalize(ray.Origin - fragPos); // View dir
            float VdotN = max(dot(V,hit.Normal), 0.0);
            
            
            // Fresnel term
            vec3 F0 = vec3(0.04); // Good average 'Fresnel at 0 degrees' value for common dielectrics
            F0 = mix(F0, hit.Mat.BaseColor, vec3(hit.Mat.Metalness));
            vec3 F = FresnelSchlick(VdotN, F0);
            
            
            // Diffuse vs Specular contribution
          	vec3 kS = F;                          	// Specular contribution
            vec3 kD = vec3(1.0) - kS;           	// Diffuse contribution
            
            
            // Finally, compute our output values
            attenuation *= isDiffuseRay 
                ? mix(/*kD**/hit.Mat.BaseColor, vec3(0.0), hit.Mat.Metalness)  // Metals, aka conductors, absorb all transmitted light
                : kS;//mix(kS, kS*hit.Mat.BaseColor, hit.Mat.Metalness);   // I swear i read that metals reflect their own color but everything i'm trying looks unnatural...
            
            ray.Dir = normalize(L);  // Not 100% if ray must be unit length, but it gives me peace of mind.
        	ray.Origin = hit.Pos + hit.Normal * epsilon; // Slightly off the hit surface stops self intersection
        }
        else
        {
            // We hit sky!
            attenuation *= _skyColor;
            break; // End tracing
        }
    }
    
    return attenuation;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float aspect = iResolution.x / iResolution.y;
    //vec2 uv = (2.*(fragCoord) - iResolution.xy) / iResolution.yy; // -(aspect,1) -> (aspect,1)
    vec2 uvNorm = (fragCoord) / iResolution.xy;                     //       (0,0) -> (1,1)
	vec2 m = iMouse.xy == vec2(0) 
        ? vec2(-.9,-0.2)                                           // Put default cam somewhere perdy
        : (2.*iMouse.xy - iResolution.xy) / iResolution.yy;         // -(aspect,1) -> (aspect,1)
    
    
    vec3 oldCol = vec3(0);
    
    // HandleState
    {
        float numFramesAccumulated = DecodeNumFramesAccumulated();
        oldCol = texelFetch(iChannel0, ivec2(fragCoord), 0).xyz;       
        
        if(iFrame == 0 || numFramesAccumulated == 0.) {
            oldCol = vec3(0,0,0);
        }

        // Track accumulated frames
        if (ivec2(fragCoord) == ivec2(0,0))
        {
            numFramesAccumulated++;

             // Get mouse state
            bool mousePressed = iMouse.z > 0.0;
            if (mousePressed) { 
                numFramesAccumulated = 0.; 
            }

            fragColor = EncodeNumFramesAccumulated(numFramesAccumulated);
            return;
        }
    }
 
    
    InitScene();
    
    
    vec3 newCol = vec3(0);
    for (int sampleId = 0; sampleId < SAMPLES_PER_PIXEL; sampleId++) // TODO Test if stratifying samples improves convergence
    {
    	float seed = hash11( dot( fragCoord, vec2(12.9898, 78.233) ) + 1113.1*hash11(float(iFrame*sampleId)) );
    
        // Camera ray
        Ray ray;
        {
            // Position the camera
            vec3 camPos = 24. * vec3(
                sin(-m.x*PI), 
                mix(0.05, 2., smoothstep(-.75,.75,m.y)), 
                cos(m.x*PI));
            vec3 camTarget = vec3(0,1,0);

            
            // Compute ray at origin from lens
            vec3 rayStart = APERTURE * 0.5 * vec3(RandomInUnitCircle(seed + 84.123), 0.);
            vec3 lensRay;
            {
                // Sub pixel offset
                vec2 pixelOffset = hash21(seed+13.271) / iResolution.xy;
                float s = uvNorm.x + pixelOffset.x;
                float t = uvNorm.y + pixelOffset.y;

                // Calc point in target image plane
	            float focalDist = length(camTarget - camPos);
                float vertical = focalDist* 2.*tan(radians(VERTICAL_FOV/2.));
                float horizontal = vertical*aspect;
                vec3 lowerLeftCorner = -vec3(horizontal/2., vertical/2., focalDist);
                vec3 rayEnd = lowerLeftCorner + vec3(s*horizontal, t*vertical, 0.);
                
                lensRay = normalize(rayEnd - rayStart);
            }

            
            // Aim the ray
            mat3 viewMat = ViewLookAtMatrix(camPos, camTarget, 0.);
            ray.Origin = camPos + viewMat * rayStart;
            ray.Dir = viewMat * lensRay;
        }

        _skyColor = .2*mix(vec3(1.), 2.*vec3(.5,.7,1.), 0.5*uvNorm.y + .5);
    	newCol += Color(ray, seed);
    }
    newCol /= float(SAMPLES_PER_PIXEL);
    
    
    fragColor = vec4(oldCol + newCol, 1.0);
}


