const vec4  groundAlbedo         = vec4(0.3);
// Ray marching steps. More steps mean better accuracy but worse performance
const int TRANSMITTANCE_STEPS     = 128;
const int IN_SCATTERING_STEPS     = 128;

//-----------------------------------------------------------------------------
// Constants

// All parameters that depend on wavelength (vec4) are sampled at
// 630, 560, 490, 430 nanometers

const float g = 0.8;

const float groundRadius        = 6371.; // km
const float atmosphereThickness = 1e2;   // km
const float atmosphereRadius    = groundRadius + atmosphereThickness;
const vec3 viewPos = vec3(0, 6371.001, 0);
const vec3 sunDir = normalize(vec3(8, 0, -4));

const vec4 sun_spectral_irradiance = vec4(1.679, 1.828, 1.986, 1.307);
const vec4 molecular_scattering_coefficient_base = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);
const vec4 ozone_absorption_cross_section = vec4(3.472e-25, 3.914e-25, 1.349e-25, 1.103e-26);

const float ozoneMean = 3e2;

const vec4 aerosol_absorption_cross_section = vec4(2.8722e-24, 4.6168e-24, 7.9706e-24, 1.3578e-23);
const vec4 aerosol_scattering_cross_section = vec4(1.5908e-22, 1.7711e-22, 2.0942e-22, 2.4033e-22);
const float aerosol_base_density = 1.3681e20;
const float aerosol_background_density = 2e6;
const float aerosol_height_scale = 0.73;

//-----------------------------------------------------------------------------

float iSphere(vec3 ro, vec3 rd, float rad)
{
    float b = dot(ro, rd),
          d = rad * rad - dot2(ro - b * rd);
    
    if (d < 0.) return -1.;
    
    d = sqrt(d);
    
    return d > -b ? -b + d : -b - d;
}

/*
 * Rayleigh phase function.
 */
float molecular_phase_function(float cosTheta)
{
    return .0596831 * (1. + cosTheta * cosTheta);
}

/*
 * Henyey-Greenstrein phase function.
 */
float aerosol_phase_function(float cosTheta)
{
    float gg  = g * g,
          den = 1. + gg + 2. * g * cosTheta;
    
    return INV4PI * (1. - gg) / den / sqrt(den);
}

/*
 * Return the molecular volume scattering coefficient (km^-1) for a given altitude
 * in kilometers.
 */
vec4 get_molecular_scattering_coefficient(float h)
{
    return molecular_scattering_coefficient_base * exp(-.07771971 * pow(h, 1.16364243));
}

/*
 * Return the molecular volume absorption coefficient (km^-1) for a given altitude
 * in kilometers.
 */
vec4 get_molecular_absorption_coefficient(float h)
{
    h += 1e-4; // Avoid division by 0
    float density = 3.78547397e20 / h * exp(-sqr(log(h) - 3.22261) * 5.55555555);
    return ozone_absorption_cross_section * ozoneMean * density;
}

float get_aerosol_density(float h)
{
    return aerosol_base_density * exp(-h / aerosol_height_scale) + aerosol_background_density;
}

/*
 * Get the collision coefficients (scattering and absorption) of the
 * atmospheric medium for a given point at an altitude h.
 */
void get_atmosphere_collision_coefficients(float h,
                                           out vec4 aerosol_absorption,
                                           out vec4 aerosol_scattering,
                                           out vec4 molecular_absorption,
                                           out vec4 molecular_scattering,
                                           out vec4 extinction)
{
    h = max(h, 0.); // In case height is negative
    
    float aerosol_density = get_aerosol_density(h);
    aerosol_absorption = aerosol_absorption_cross_section * aerosol_density;
    aerosol_scattering = aerosol_scattering_cross_section * aerosol_density;
    
    molecular_absorption = get_molecular_absorption_coefficient(h);
    molecular_scattering = get_molecular_scattering_coefficient(h);
    extinction = aerosol_absorption + aerosol_scattering + molecular_absorption + molecular_scattering;
}

vec2 rd2uv(vec3 rd)
{
    vec2 uv;
    
    vec3 ard = abs(rd);

    if(ard.x > ard.y && ard.x > ard.z)
    {
        uv = .5 * rd.yz / rd.x + .5;
        if(rd.x > 0.) uv.y++;
    }
    else if(ard.y > ard.z)
    {
        uv = .5 * rd.zx / rd.y + .5;
        uv.x += 1.;
        if(rd.y > 0.) uv.y++;
    }
    else
    {
        uv = .5 * rd.xy / rd.z + .5;
        uv.x += 2.;
        if(rd.z > 0.) uv.y++;
    }
    
    return uv / vec2(3, 2);
}

vec3 uv2rd(vec2 uv)
{
    uv *= vec2(3, 2);
    ivec2 i = ivec2(uv);
    
    uv = fract(uv) - .5;
    
    vec3 rd = normalize(vec3(uv, .5));
    
    if(i.y < 1) rd = -rd;
    
    return i.x < 1 ? rd.zxy : i.x < 2 ? rd.yzx : rd;
}

vec4 LUT(float cosTheta, float normalized_altitude)
{
    return texture(iChannel0, uv2rd(vec2(cosTheta * .5 + .5, normalized_altitude)));
}

void mainCubemap(out vec4 O, vec2 I, vec3 ro, vec3 rd)
{
    if (SKYTYPE < 2) return;
    
    if (iFrame > 1) { O = texture(iChannel0, rd); return; }
    
    if (iFrame > 0)
    {
        ro = viewPos;

        float tmax = iSphere(ro, rd, groundRadius);

        if (tmax < 0.) tmax = iSphere(ro, rd, atmosphereRadius);

        float cosTheta = dot(-rd, sunDir);

        float molecular_phase = molecular_phase_function(cosTheta);
        float aerosol_phase = aerosol_phase_function(cosTheta);

        float dt = tmax / float(IN_SCATTERING_STEPS);

        vec4 L = vec4(0),
             transmittance = vec4(1);

        vec3 pos = ro;

        for (int i = 0; i < IN_SCATTERING_STEPS; ++i)
        {
            float d = length(pos);
            vec3 zenith_dir = pos / d;
            float altitude = d - groundRadius;
            float normalized_altitude = altitude / atmosphereThickness;

            cosTheta = dot(zenith_dir, sunDir);

            vec4 aerosol_absorption, aerosol_scattering;
            vec4 molecular_absorption, molecular_scattering;
            vec4 extinction;
            get_atmosphere_collision_coefficients(
                altitude,
                aerosol_absorption, aerosol_scattering,
                molecular_absorption, molecular_scattering,
                extinction);

            vec4 transmittance_to_sun = LUT(cosTheta, normalized_altitude);

            // Solid angle subtended by the planet from a point at d distance
            // from the planet center.
            // 2nd order scattering from the ground
            vec4 L_ground = .5 * (1. - sqrt(max(1. - sqr(groundRadius / d), 0.))) * groundAlbedo * INVPI * LUT(cosTheta, 0.) * LUT(1., 0.) / LUT(1., normalized_altitude) * cosTheta;

            // Fit of Earth's multiple scattering coming from other points in the atmosphere
            vec4 L_ms = vec4(.00434, .00694, .01188, .02) / (1. + 5. * exp(-17.92 * cosTheta));

            vec4 ms = L_ms + L_ground;

            vec4 S = sun_spectral_irradiance *
                (molecular_scattering * (molecular_phase * transmittance_to_sun + ms) +
                 aerosol_scattering   * (aerosol_phase   * transmittance_to_sun + ms));

            vec4 step_transmittance = exp(-dt * extinction);

            // Energy-conserving analytical integration
            // "Physically Based Sky, Atmosphere and Cloud Rendering in Frostbite"
            // by Sébastien Hillaire

            L += transmittance * S * (1. - step_transmittance) / extinction;
            transmittance *= step_transmittance;

            pos += rd * dt;
        }

        O.xyz = mat4x3(137.672389239975, -8.632904716299537, -1.7181567391931372,
                       32.549094028629234, 91.29801417199785, -12.005406444382531,
                       -38.91428392614275, 34.31665471469816, 29.89044807197628,
                       8.572844237945445, -11.103384660054624, 117.47585277566478) * L;
        return;
    }
    
    I = rd2uv(rd);
    
    float cosTheta = I.x * 2. - 1.;

    ro = vec3(0, 0, groundRadius + atmosphereThickness * I.y);
    rd = vec3(-sqrt(1. - cosTheta * cosTheta), 0, cosTheta);

    float tmax = iSphere(ro, rd, groundRadius);
    if (tmax < 0.) tmax = iSphere(ro, rd, atmosphereRadius);
    
    float dt = tmax / float(TRANSMITTANCE_STEPS);

    O = vec4(0);
    
    for (int i = 0; i < TRANSMITTANCE_STEPS; i++)
    {
        vec4 aerosol_absorption, aerosol_scattering,
             molecular_absorption, molecular_scattering,
             extinction;
        
        get_atmosphere_collision_coefficients(
            length(ro) - groundRadius,
            aerosol_absorption, aerosol_scattering,
            molecular_absorption, molecular_scattering,
            extinction);

        O += extinction;
        
        ro += rd * dt;
    }

    O = exp(-O * dt);
}
