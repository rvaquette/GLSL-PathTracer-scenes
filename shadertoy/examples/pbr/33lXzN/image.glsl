const float PI = float(3.14159);
    
struct AppState
{
    float	menuId;
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
    s.focusObjRot  	= data.xy;
    s.objRot    	= data.zw;
}

float saturate(float x)
{
    return clamp(x, 0., 1.);
}

vec3 saturate(vec3 x)
{
    return clamp(x, vec3(0.), vec3(1.));
}

float Smooth(float x)
{
	return smoothstep(0., 1., saturate(x));   
}

float Circle(vec2 p, float r)
{
    return (length(p / r) - 1.) * r;
}

void Rotate(inout vec2 p, float a) 
{
    p = cos(a) * p + sin(a) * vec2(p.y, -p.x);
}

float Capsule(vec2 p, float r, float c) 
{
	return mix(length(p.x) - r, length(vec2(p.x, abs(p.y) - c)) - r, step(c, abs(p.y)));
}

float TextSDF(vec2 p, float glyph)
{
    p = abs(p.x - .5) > .5 || abs(p.y - .5) > .5 ? vec2(0.) : p;
    return 2. * (texture(iChannel3, p / 16. + fract(vec2(glyph, 15. - floor(glyph / 16.)) / 16.)).w - 127. / 255.);
}

vec3 FresnelTerm(vec3 specularColor, float vdoth)
{
	vec3 fresnel = specularColor + (1. - specularColor) * pow((1. - vdoth), 5.);
	return fresnel;
}

float RoundBox(vec3 p, vec3 b, float r)
{
	return length(max(abs(p) - b, 0.0)) - r;
}

float Sphere(vec3 p, float s)
{
	return length(p) - s;
}

float UnionRound(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float Displace(float scale, float ampl, vec3 p)
{
    p *= ampl;
	return scale * sin(p.x) * sin(p.y) * sin(p.z);
}

float Scene(vec3 p, mat3 localToWorld)
{  
    p = p * localToWorld;
    
    float ret = Sphere(p, 1.2);
    //ret = RoundBox(p, vec3(1.0, 1.0, 0.3), 0.1);
    ret += Displace(0.05, 7.0, p);
    
	return ret;
}

float CastRay(in vec3 ro, in vec3 rd, mat3 localToWorld)
{
    const float maxd = 5.0;
    
	float h = 0.5;
    float t = 0.0;
   
    for (int i = 0; i < 50; ++i)
    {
        if (h < 0.001 || t > maxd) 
        {
            break;
        }
        
	    h = Scene(ro + rd * t, localToWorld);
        t += h;
    }

    if (t > maxd)
    {
        t = -1.0;
    }
	
    return t;
}

vec3 SceneNormal(in vec3 pos, mat3 localToWorld)
{
	vec3 eps = vec3(0.001, 0.0, 0.0);
	vec3 nor = vec3(
	    Scene(pos + eps.xyy, localToWorld) - Scene(pos - eps.xyy, localToWorld),
	    Scene(pos + eps.yxy, localToWorld) - Scene(pos - eps.yxy, localToWorld),
	    Scene(pos + eps.yyx, localToWorld) - Scene(pos - eps.yyx, localToWorld));
	return normalize(nor);
}

float AshikhminD(float roughness, float ndoth)
{
	float r2    = roughness * roughness;
	float cos2h = ndoth * ndoth;
	float sin2h = 1. - cos2h;
	float sin4h = sin2h * sin2h;
	return (sin4h + 4. * exp(-cos2h / (sin2h * r2))) / (PI * (1. + 4. * r2) * sin4h);
}

float AshikhminV(float ndotv, float ndotl)
{
	return 1. / (4. * (ndotl + ndotv - ndotl * ndotv));
}

float CharlieD(float roughness, float ndoth)
{
    float rcpR  = 1. / roughness;
    float cos2h = ndoth * ndoth;
    float sin2h = 1. - cos2h;
    return (2. + rcpR) * pow(sin2h, rcpR * .5) / (2. * PI);
}

float L(float x, float r)
{
	r = saturate(r);
	r = 1.0 - (1. - r) * (1. - r);

	float a = mix( 25.3245,  21.5473, r);
	float b = mix( 3.32435,  3.82987, r);
	float c = mix( 0.16801,  0.19823, r);
	float d = mix(-1.27393, -1.97760, r);
	float e = mix(-4.85967, -4.32054, r);

	return a / (1. + b * pow(x, c)) + d * x + e;
}

float CharlieV(float roughness, float ndotv, float ndotl)
{
	float visV = ndotv < .5 ? exp(L(ndotv, roughness)) : exp(2. * L(.5, roughness) - L(1. - ndotv, roughness));
	float visL = ndotl < .5 ? exp(L(ndotl, roughness)) : exp(2. * L(.5, roughness) - L(1. - ndotl, roughness));

	return 1. / ((1. + visV + visL) * (4. * ndotv * ndotl));
}

void DrawScene(inout vec3 color, vec2 p, in AppState s)
{
    vec3 lightColor    = vec3(1.);
    vec3 lightDir      = normalize(vec3(-0.3, 0.5, 1.));
	vec3 baseColor     = 0.25 * pow(vec3(0.87, 0.53, 0.66), vec3(2.2));
    vec3 diffuseColor  = 0.25 * baseColor;
    vec3 specularColor = sqrt(baseColor);
    float roughness    = max(.001, s.roughness);  
    
    p -= vec2(0., 10.);
    p *= .011;
    
    float yaw = 2.7 - s.objRot.x;
    mat3 rotZ = mat3(
        vec3(cos(yaw), 0.0, -sin(yaw)),
		vec3(0.0, 1.0, 0.0),        
        vec3(sin(yaw), 0.0, cos(yaw))
       );
    
    float phi = -0.1 + s.objRot.y;
    mat3 rotY = mat3(
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, cos(phi), sin(phi)),
        vec3(0.0, -sin(phi), cos(phi))
       );
    
    mat3 localToWorld = rotY * rotZ;  
    
    lightDir = localToWorld * lightDir;
    
	vec3 rayOrigin 	= vec3(0.0, .3, -3.5);
    vec3 rayDir 	= normalize(vec3(p.x, p.y, 2.0));    
	float t = CastRay(rayOrigin, rayDir, localToWorld);
    if (t > 0.0)
    {
        vec3 pos = rayOrigin + t * rayDir;
        vec3 normal = SceneNormal(pos, localToWorld);        
        vec3 viewDir = -rayDir;
        vec3 refl = reflect(rayDir, normal);

        vec3 halfVec = normalize(viewDir + lightDir);
        float vdoth = saturate(dot(viewDir, halfVec));
        float ndoth	= saturate(dot(normal, halfVec));
        float ndotv = saturate(dot(normal, viewDir));
        float ndotl = saturate(dot(normal, lightDir));
        

		vec3 diffuse = lightColor * diffuseColor * saturate(dot(normal, lightDir));
        
        vec3 f = FresnelTerm(specularColor, vdoth);

        float d = AshikhminD(roughness, ndoth);
        float v = AshikhminV(ndotv, ndotl);
        
		if (s.menuId == 1.)
        {
            d = CharlieD(roughness, ndoth);
        	v = AshikhminV(ndotv, ndotl);
        }
        else if (s.menuId == 2.)
        {
            d = CharlieD(roughness, ndoth);
        	v = CharlieV(roughness, ndotv, ndotl);
        }        
        
        vec3 specular = lightColor * f * (d * v * PI * ndotl);
        
        color = diffuse + specular;
        color = pow(color, vec3(1. / 2.2));
    }
    else
    {
        // shadow
        float planeT = -(rayOrigin.y + 1.2) / rayDir.y;
        if (planeT > 0.0)
        {
            vec3 p = rayOrigin + planeT * rayDir;
            
            float radius = .7;
            color *= 0.7 + 0.3 * smoothstep(0.0, 1.0, saturate(length(p + vec3(0.0, 1.0, -0.5)) - radius));
        }		
    }
}

void MenuText(inout vec3 color, vec2 p, in AppState s)
{
    p -= vec2(-160, 62);
    
    vec2 scale = vec2(4., 8.);
    vec2 t = floor(p / scale);   
    
    uint v = 0u;
	v = t.y == 2. ? (t.x < 4. ? 1768452929u : (t.x < 8. ? 1768777835u : (t.x < 12. ? 5653614u : 0u))) : v;
	v = t.y == 1. ? (t.x < 4. ? 1918986307u : (t.x < 8. ? 1147496812u : (t.x < 12. ? 1752383839u : (t.x < 16. ? 1835559785u : 5664361u)))) : v;
	v = t.y == 0. ? (t.x < 4. ? 1918986307u : (t.x < 8. ? 1147496812u : (t.x < 12. ? 86u : 0u))) : v;
	v = t.x >= 0. && t.x < 20. ? v : 0u;
    
	float c = float((v >> uint(8. * t.x)) & 255u);
    
    vec3 textColor = vec3(.3);
    if (t.y == 2. - s.menuId)
    {
        textColor = vec3(0.74, 0.5, 0.12);
	}

    p = (p - t * scale) / scale;
    p.x = (p.x - .5) * .5 + .5;
    float sdf = TextSDF(p, c);
    if (c != 0.)
    {
    	color = mix(textColor, color, smoothstep(-.05, +.05, sdf));
    }
}

void SliderText(inout vec3 color, vec2 p, in AppState s)
{
    p -= vec2(67, 76);
    
    vec2 scale = vec2(4., 8.);
    vec2 t = floor(p / scale);   
    
    uint v = 0u;
	v = t.y == 0. ? (t.x < 4. ? 1735749458u : (t.x < 8. ? 1936027240u : 14963u)) : v;
	v = t.x >= 0. && t.x < 12. ? v : 0u;
    
	float c = float((v >> uint(8. * t.x)) & 255u);
    
    vec3 textColor = vec3(.3);

    p = (p - t * scale) / scale;
    p.x = (p.x - .5) * .5 + .5;
    float sdf = TextSDF(p, c);
    if (c != 0.)
    {
    	color = mix(textColor, color, smoothstep(-.05, +.05, sdf));
    } 
}

void DrawRadial(inout vec3 color, vec2 p, in AppState s)
{
    p -= vec2(-164, 73);
    
	// radial
    float c2 = Capsule(p - vec2(0., 1.), 3., 8.5);
    float c1 = Circle(p + vec2(0., 7. - 8. * (2. - s.menuId)), 2.5);
    
    color = mix(color, vec3(0.9), Smooth(-c2 * 2.));
	color = mix(color, vec3(0.3), Smooth(-c1 * 2.));    
}

void DrawSlider(inout vec3 color, vec2 p, in AppState s)
{
    p -= vec2(110, 94.5);
    
    p.y += 15.;
    float c1 = Capsule(p.yx - vec2(0., 20.), 1., 20.);
    c1 = min(c1, Circle(p - vec2(40. * s.roughness, 0.), 2.5));

	color = mix(color, vec3(0.3), Smooth(-c1 * 2.));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord.xy / iResolution.xy;    
	vec2 q = fragCoord.xy / iResolution.xy;
    vec2 p = -1. + 2. * q;
	p.x *= iResolution.x / iResolution.y;    
    p *= 100.;
    
    AppState s;
    LoadState(s);  

    vec3 color = vec3(1., .98, .94) * mix(1.0, 0.4, Smooth(abs(.5 - uv.y)));
    float vignette = q.x * q.y * (1.0 - q.x) * (1.0 - q.y);
    vignette = saturate(pow(32.0 * vignette, 0.05));
    color *= vignette;
    
    DrawScene(color, p, s);
    MenuText(color, p, s);
    SliderText(color, p, s);
    DrawRadial(color, p, s);
    DrawSlider(color, p, s);

	fragColor = vec4(color, 1.);
}
