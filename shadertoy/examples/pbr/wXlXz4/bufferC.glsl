// Buffer C calculates the actual sky-view! It's a lat-long map (or maybe altitude-azimuth is the better term),
// but the latitude/altitude is non-linear to get more resolution near the horizon.

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    if (fragCoord.x >= (skyLUTRes.x+1.5) || fragCoord.y >= (skyLUTRes.y+1.5)) {
        return;
    }
    float u = clamp(fragCoord.x, 0.0, skyLUTRes.x-1.0)/skyLUTRes.x;
    float v = clamp(fragCoord.y, 0.0, skyLUTRes.y-1.0)/skyLUTRes.y;

    float azimuthAngle = (u - 0.5)*2.0*PI;

    // Non-linear mapping of altitude. See Section 5.3 of the paper.

    float adjV;
    if (v < 0.5) {
		float coord = 1.0 - 2.0*v;
		adjV = -coord*coord;
	} else {
		float coord = v*2.0 - 1.0;
		adjV = coord*coord;
	}

    vec3 viewPos = getViewPos(iTime);

    float height = length(viewPos); vec3 up = viewPos / height;
    float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height) - 0.5*PI;
    float altitudeAngle = adjV*0.5*PI - horizonAngle;

    float cosAltitude = cos(altitudeAngle);
    vec3 rayDir = vec3(cosAltitude*sin(azimuthAngle), sin(altitudeAngle), -cosAltitude*cos(azimuthAngle));

    float sunAltitude = (0.5*PI) - acos(dot(getSunDir(iTime), up));
    vec3 sunDir = vec3(0.0, sin(sunAltitude), -cos(sunAltitude));

    vec3 lum = raymarchScattering(iChannel0, iChannelResolution[0].xy,
                                  iChannel1, iChannelResolution[1].xy,
                                  viewPos, rayDir, sunDir, float(numScatteringSteps));
    fragColor = vec4(lum, 1.0);
}

