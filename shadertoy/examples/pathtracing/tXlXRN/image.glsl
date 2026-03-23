// ---------------------------------------------------------------------
// Things to try (in Buffer A):
//
// * Disable GGX_SAMPLING to see the effect of importance sampling
// * Play with scene and materials
// * Play with NUM_SAMPLES and NUM_DEPTH
// * Play with SOLO_DEPTH to see the effects of a ray depth on the final image
// * Play with SHADOW_EPSILON to adjust Shadow Acne and Peter Panning
// * Disable SSAA to see its effects
// * Play with FOCAL_LENGTH 
// ---------------------------------------------------------------------

// Shader entry point
void mainImage(out vec4 fragColor, vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec3 col = vec3(0.);
    
    // Read texture in Buffer A
    col = texture(iChannel0, uv).rgb;
    
    // Inverse gamma function
    col = pow(col, vec3(1. / 2.2));
    
    // Post-processing: color grading
    col = pow(col, vec3(0.8, 0.85, 0.9));
    
    // Post-processing: vignette
    col *= 0.5 + 0.5 * pow(16.0 * uv.x * uv.y *
                           (1.0 - uv.x) * (1.0 - uv.y), 0.2);
    
    // Return fragment color
    fragColor = vec4(col, 1.0);
}

