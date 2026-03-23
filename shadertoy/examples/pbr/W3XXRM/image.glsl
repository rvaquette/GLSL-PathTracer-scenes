const float earthRadius = 2.0;
const float atmosphereOffset = 0.1;
const vec3 earthPosition = vec3(0.0, 0.0, 3.0);

float PI = acos(-1.0);

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))

vec2 iSphere(in vec3 ro, in vec3 rd, in vec3 sph, in float rad) {
	vec3 oc = ro - sph;
	float b = dot(oc, rd);
	float c = dot(oc, oc) - rad*rad;
	vec2 t = vec2(b*b - c);
	if( t.x > 0.0) 
		return -b - sqrt(t) * vec2(1.0, -1.0);
	return vec2(-1.0);

}

struct spectralWave {
	float wavelength;
	float amp;
};
	
spectralWave createWave(float freq, float amp) {
	return spectralWave(freq, amp);
}
	
vec3 calculateConeColor(spectralWave wave) {
	vec3 dist1 = (wave.wavelength - vec3(580.0, 520.0, 445.0)) / vec3(60.0, 50.0, 50.0);
	float dist2 = (wave.wavelength - 380.0) / 25.0;
	
	return (exp(-dist1 * dist1) * vec3(0.92, 1.0, 0.95) + exp(-dist2 * dist2) * vec3(0.006, 0.0, 0.0)) * wave.amp;
}

float calculateDensity(vec3 worldPosition) {
	return exp(-(length(worldPosition - earthPosition) - earthRadius) * 100.) * 2000000000000.0;
}

float calculateTransmittanceOverT(vec3 rayPosition, vec3 lightDir, float scatteringAmount) {
	const int steps = 8;
	float stepLength = 0.01;
	
	float od = 0.0;
	
	for (int i = 0; i < steps; i++) {
		od += calculateDensity(rayPosition) * stepLength;
		rayPosition += lightDir * stepLength;
		stepLength *= 2.0;
	}
	
	return exp(-od * scatteringAmount);
}

spectralWave rayleighScattering(vec3 origin, vec3 worldVector, vec3 lightDir, float wavelength, vec2 sphereEarth, vec2 sphereAtmo, float dither, float phase) {
	if (sphereAtmo.x <= 0.0) {
		return createWave(wavelength, 0.0);
	}
	
	const int steps = 10;
	
	vec3 startPos = origin + worldVector * max(sphereAtmo.x, 0.0);
	vec3 endPos = origin + worldVector * (sphereEarth.x > 0.0 ? sphereEarth.x : sphereAtmo.y);
	
	vec3 increment = (endPos - startPos) / float(steps);
	float stepSize = length(increment);
	
	vec3 rayPosition = startPos + increment * dither;
	
	float scatteringAmount = 1.0 / pow(wavelength, 4.0);
	float transmittence = 1.0;
	float scattering = 0.0;
	
	for (int i = 0; i < steps; i++) {
		float depth = calculateDensity(rayPosition) * stepSize;
		float stepTransmittance = exp(-scatteringAmount * depth);
		
		scattering += (1.0 - stepTransmittance) * transmittence * calculateTransmittanceOverT(rayPosition, lightDir, scatteringAmount);
		transmittence *= stepTransmittance;
		
		rayPosition += worldVector * stepSize;
	}
	
	return createWave(wavelength, scattering * phase);	
}


void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 uv = fragCoord/iResolution.xy;

	vec2 wPos = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
	vec3 worldVector = normalize(vec3(wPos, 1.0));
	
	vec3 color = vec3(0.0);
	vec3 bbColor = vec3(0.0);
	const float minFreq = 400.0;
	const float maxFreq = 650.0;
	const float freqStep = 50.0;
	vec3 totalWeight = vec3(0.0);
    
    float rotation = iTime;
    
    if (iMouse.x > 1.0) {
        rotation = (0.5 - iMouse.x / iResolution.x) * 2.0 * PI;
    }
	
	vec3 lightDir = normalize(vec3(sin(rotation), 1.0, cos(rotation)));
	vec3 rayOrigin = vec3(0.0, 0.0, 0.0);
	
	vec2 sphereEarth = iSphere(rayOrigin, worldVector, earthPosition, earthRadius);
	vec2 sphereAtmo = iSphere(rayOrigin, worldVector, earthPosition, earthRadius + atmosphereOffset);
	float VoL = dot(lightDir, worldVector);
	
	float phase = (VoL * VoL + 1.0) / PI;
	
	float dither = bayer16(gl_FragCoord.xy);

	for (float freq = minFreq; freq <= maxFreq; freq += freqStep) {
		vec3 currConeColor = calculateConeColor(createWave(freq, 1.0));
		vec3 weight = currConeColor;
		totalWeight += weight;
		bbColor += calculateConeColor(rayleighScattering(rayOrigin, worldVector, lightDir, freq, sphereEarth, sphereAtmo, dither, phase)) * weight;
	}

	color = bbColor / totalWeight;
	color = pow(color, vec3(2.2));
	color *= 20.0;
    color /= color + 1.0;
	color = pow(color, vec3(1.0 / 2.2));
    
    fragColor = vec4(color, 1.0);
}
