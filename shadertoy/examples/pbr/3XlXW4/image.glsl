// special thanks to TDM
// https://www.shadertoy.com/view/XsfXWX

// tuning knobs

	// enable or disable adaptive tone map
	#define ENABLE_TONE_MAP

	// define adaptive tone map gamma
	#define TONE_MAP_GAMMA 2.3

// do not modify these
#define PI 3.1415926535897932384626433832795
#define PI_MODIFIER 4.0

vec3 obj_pos = vec3(0.0,0.0,-10.0);
float obj_size = 5.0;

float sphere(vec3 dir, vec3 center, float radius) {
    vec3 rp = -center;
	float b = dot(rp,dir);
	float dist = b * b - (dot(rp,rp) - radius * radius);
	if(dist <= 0.0) return -1.0;
	return -b - sqrt(dist);
}

float somestep(float t) {
    return pow(t,4.0);
}

vec3 textureAVG(samplerCube tex, vec3 tc) {
    const float diff0 = 0.35;
    const float diff1 = 0.12;
 	vec3 s0 = texture(tex,tc).xyz;
    vec3 s1 = texture(tex,tc+vec3(diff0)).xyz;
    vec3 s2 = texture(tex,tc+vec3(-diff0)).xyz;
    vec3 s3 = texture(tex,tc+vec3(-diff0,diff0,-diff0)).xyz;
    vec3 s4 = texture(tex,tc+vec3(diff0,-diff0,diff0)).xyz;
    
    vec3 s5 = texture(tex,tc+vec3(diff1)).xyz;
    vec3 s6 = texture(tex,tc+vec3(-diff1)).xyz;
    vec3 s7 = texture(tex,tc+vec3(-diff1,diff1,-diff1)).xyz;
    vec3 s8 = texture(tex,tc+vec3(diff1,-diff1,diff1)).xyz;
    
    return (s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8) * 0.111111111;
}

vec3 textureBlured(samplerCube tex, vec3 tc) {
   	vec3 r = textureAVG(tex,vec3(1.0,0.0,0.0));
    vec3 t = textureAVG(tex,vec3(0.0,1.0,0.0));
    vec3 f = textureAVG(tex,vec3(0.0,0.0,1.0));
    vec3 l = textureAVG(tex,vec3(-1.0,0.0,0.0));
    vec3 b = textureAVG(tex,vec3(0.0,-1.0,0.0));
    vec3 a = textureAVG(tex,vec3(0.0,0.0,-1.0));
        
    float kr = dot(tc,vec3(1.0,0.0,0.0)) * 0.5 + 0.5; 
    float kt = dot(tc,vec3(0.0,1.0,0.0)) * 0.5 + 0.5;
    float kf = dot(tc,vec3(0.0,0.0,1.0)) * 0.5 + 0.5;
    float kl = 1.0 - kr;
    float kb = 1.0 - kt;
    float ka = 1.0 - kf;
    
    kr = somestep(kr);
    kt = somestep(kt);
    kf = somestep(kf);
    kl = somestep(kl);
    kb = somestep(kb);
    ka = somestep(ka);    
    
    float d;
    vec3 ret;
    ret  = f * kf; d  = kf;
    ret += a * ka; d += ka;
    ret += l * kl; d += kl;
    ret += r * kr; d += kr;
    ret += t * kt; d += kt;
    ret += b * kb; d += kb;
    
    return ret / d;
}

vec3 toneMap(vec3 color, float gamma)
{
    // kudos to Roman Galashov, aka RomBinDaHouse
    color = exp(-1.0 / (2.72 * color + 0.15));
	color = pow(color, vec3(1.0 / gamma));
	return color;
}

vec3 getColor(vec3 R) {
    float dist = sphere(R, obj_pos, obj_size);    
    if(dist > 0.0) {
        
        // material
        float roughness = sin(iTime * 0.5) * 0.5 + 0.5;
        vec3 light_color = textureBlured(iChannel1, normalize(R * 0.8)).xyz;
                
    	vec3 point = R * dist;
        
        // NL
    	vec3 N = normalize(point - obj_pos);
        vec3 L = normalize(vec3(-0.5, 1.0, 0.0));
        
        // dots
        float NdotV = clamp(dot(N, -R), 0.0, 1.0);
        float NdotL = clamp(dot(L,  N), 0.0, 1.0);
        vec3  RrefN = reflect(R, N);
        
        // specular power
        float specular_mod   = 1.0 - roughness;
        float specular_power = clamp(pow(clamp(dot(L, RrefN), 0.0, 1.0), 1.0 / specular_mod) * specular_mod, 0.0, 1.0);
        
        // IBL
        vec3 ibl_diffuse    = textureBlured(iChannel1, N);
        vec3 ibl_reflection = textureBlured(iChannel1, RrefN);
        
        // fresnel
        float fresnel_pow  = 35.0;
        float fresnel_base = NdotV;
        float fresnel_exp  = pow(fresnel_base, fresnel_pow);
        float fresnel_term = specular_power + fresnel_exp;
        
        // specular
        float normalization_term = ((specular_power + PI_MODIFIER) / PI_MODIFIER * PI);
        float specular_term      = normalization_term * specular_power;
        float vis_alpha          = 1.0 / (sqrt((PI / 4.0) * specular_power + (PI / 2.0)));
        float vis_term           = clamp((NdotL * (1.0 - vis_alpha) + vis_alpha) * (NdotV * (1.0 - vis_alpha) + vis_alpha), 0.0, 1.0);
        
        // reflection        
        vec3 refl = texture(iChannel1, RrefN).xyz;
        refl = mix(refl, ibl_reflection, 1.0 - vis_term);
        refl = mix(refl, ibl_reflection, roughness);
        
        // final colors
        vec3 specular_color = specular_term * fresnel_term * vis_term * light_color;
        vec3 diffuse_color  = mix(ibl_diffuse, refl, vis_term);

        vec3 final_color = diffuse_color + specular_color;
        
        #ifdef ENABLE_TONE_MAP
        float luma = dot(final_color, vec3(0.2126, 0.7152, 0.0722));
        return mix(final_color, toneMap(final_color, luma * TONE_MAP_GAMMA), 1.0 - luma);
        #else
    	return final_color;
        #endif
        
    } else {      
        
        return texture(iChannel0, R).xyz;
    }
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {   
	vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;
    vec3 dir = normalize(vec3(uv.xy,-1.0));
   
    // rotation
    float c = cos(iTime / 20.0);
    float s = sin(iTime / 20.0);
    dir.xz = vec2(dir.x * c - dir.z * s, dir.x * s + dir.z * c);
    obj_pos.xz = vec2(obj_pos.x * c - obj_pos.z * s, obj_pos.x * s + obj_pos.z * c);
    
    // color
	fragColor = vec4(getColor(dir),1.0);
}

