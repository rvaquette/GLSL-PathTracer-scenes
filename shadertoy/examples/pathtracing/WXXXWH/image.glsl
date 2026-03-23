/*
    GGX VNDF - Multiple scattering using random walk algorithm

    Author:
        @LVutner

    Credits: 
        @Stubman - Raycast logic
        @selfshadow - GGX heightfield function

    Info:
        Very simple example of multiple scattered GGX material.
        Based on "Multiple-Scattering Microfacet BSDFs with the Smith Model"

    References:
        [R. Cook & K. Torrance, 1982] "A Reflectance Model for Computer Graphics"
        [B. Walter et al, 2007] "Microfacet Models for Refraction through Rough Surfaces"
        [E. Heitz, 2014] "Understanding the Masking-Shadowing Function in Microfacet-based BRDFs"  
        [E. Heitz, 2018] "Sampling the GGX Distribution of Visible Normals"
        [E. Heitz & J. Dupuy, 2015] "Implementing a Simple Anisotropic Rough Diffuse Material with Stochastic Evaluation"
        [E. Heitz, 2016] "Multiple-Scattering Microfacet BSDFs with the Smith Model"
        [J. Dupuy & A. Benyoub, 2023] "Sampling Visible GGX Normals with Spherical Caps"
*/

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Sample scene color
    vec3 color = texelFetch(iChannel0, ivec2(fragCoord), 0).xyz;

    //Apply exposure
    color *= 2.0;

    //Tonemapping
    color = color * ACESInputMat;
    color = RRTAndODTFit(color);
    color = color * ACESOutputMat;
    color = clamp(color, 0.0, 1.0);

    //Transform from linear to sRGB
    color = fromLinear(color);

    // Output to screen
    fragColor = vec4(color, 1.0);
}
