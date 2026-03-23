bool iSphere(mat4 txx, float rad,  ray r, float tmin, float tmax, inout hitRecord rec)
{
    vec3 ro = (inverse(txx) * vec4(r.o, 1)).xyz,
	     rd = (inverse(txx) * vec4(r.d, 0)).xyz;
    
    float b = dot(ro, rd),
          d = rad * rad - dot2(ro - b * rd);

    if (d < 0.) return false;
    
    d = sqrt(d);
    
    float N = -b - d,
          F = -b + d;
    
    float t = N < tmin ? F : N;
    
    if(t < tmin || t > tmax) return false;
    
    rec.t = t;
    rec.p = r.o + r.d * t;
    rec.n = (txx * vec4(ro + rd * t, 0) / rad).xyz;
    
    return true;
}

bool iBox(mat4 txx, vec3 rad, ray r, float tmin, float tmax, inout hitRecord rec)
{
    vec3 ro = (inverse(txx) * vec4(r.o, 1)).xyz,
	     rd = (inverse(txx) * vec4(r.d, 0)).xyz,
         
    k = rad * sign(rd),
                  
	t1 = (-ro - k) / rd,
	t2 = (-ro + k) / rd;
    
    float N = max(max(t1.x, t1.y), t1.z),
          F = min(min(t2.x, t2.y), t2.z);
    
    if(N > F) return false;
    
    vec4 res = N > tmin ? vec4(N,  step(vec3(N), t1))
                        : vec4(F, -step(t2, vec3(F)));
    
    if(res.x < tmin || res.x > tmax) return false;
    
    rec.t = res.x;
    rec.p = r.o + r.d * res.x;
    rec.n = (txx * vec4(-sign(rd) * res.yzw, 0)).xyz;
	
	return true;
}

bool sphere(mat4 txx, float rad, ray r, float tmin, float tmax, out float t)
{
    vec3 ro = (inverse(txx) * vec4(r.o, 1)).xyz,
	     rd = (inverse(txx) * vec4(r.d, 0)).xyz;
    
    float b = dot(ro, rd),
          d = rad * rad - dot2(ro - b * rd);

    if (d < 0.) return false;
    
    d = sqrt(d);
    
    float N = -b - d,
          F = -b + d;
    
    t = N < tmin ? F : N;
    
    if(t < tmin || t > tmax) return false;
    
    return true;
}

bool box(mat4 txx, vec3 rad, ray r, float tmin, float tmax, out float t)
{
    vec3 ro = (inverse(txx) * vec4(r.o, 1)).xyz,
	     rd = (inverse(txx) * vec4(r.d, 0)).xyz,

	k = rad * sign(rd),
                  
	t1 = (-ro - k) / rd,
	t2 = (-ro + k) / rd;
    
    float N = max(max(t1.x, t1.y), t1.z),
          F = min(min(t2.x, t2.y), t2.z);
    
    if(N > F || F < tmin || N > tmax) return false;
    
    t = N > tmin ? N : F;
	
	return true;
}

material DIFFUSE(vec3 col, float roughness)
{
    material mat  = initMat;
    mat.baseColor = col;
    mat.roughness = roughness;
    
    return mat;
}

material METAL(vec3 col, float roughness)
{
    material mat  = initMat;
    mat.baseColor = col;
    mat.metallic  = 1.;
    mat.roughness = roughness;
    
    return mat;
}

material GLASS(vec3 col, float IOR, float roughness)
{
    material mat  = initMat;
    mat.baseColor = col;
    mat.roughness = roughness;
    mat.specTrans = 1.;
    mat.IOR       = IOR;
    
    return mat;
}

material LIGHT(vec3 col)
{
    material mat = initMat;
    mat.emission = col;
    
    return mat;
}

material VOLUME(vec3 col)
{
    material mat  = initMat;
    mat.baseColor = col;
    
    return mat;
}

vec2 opU(vec2 d1, vec2 d2)
{
	return (d1.x < d2.x) ? d1 : d2;
}

vec2 map(vec3 p)
{
    vec2 res = vec2(1e20, 0);

    return res;
}

vec3 calcNormal( in vec3 pos )
{
    vec3 n = vec3(0.0);
    for( int i=ZERO; i<4; i++ )
    {
        vec3 e = 0.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e * abs(map(pos+0.0005*e).x);
    }
    return normalize(n);
}

bool marchHit(ray r, float tmin, float tmax, inout hitRecord rec)
{
    vec2 res = vec2(-1);

    float t = tmin;
    for(int i = 0; i < 256 && t < tmax; i++)
    {
        vec2 h = map(r.o + r.d * t);
        if(abs(h.x) < .0001 * t)
        { 
            rec.t = t;
            rec.p = r.o + r.d * t;
            rec.n = calcNormal(rec.p);
            rec.mat = DIFFUSE(vec3(1), 1.);
            return true;
        }
        t += h.x;
    }
    
    return false;
}

bool worldHit(ray r, float tmin, float tmax, out hitRecord rec)
{
    rec.t = tmax;
    
    bool hit = false;
    
    if(iBox(noTransform, vec3(1e3, .01, 1e3), r, tmin, rec.t, rec))
    
        hit = true,
        rec.mat = DIFFUSE(vec3(.5), 1.);
    
    if (iSphere(translate(vec3(0, 1, 0)), 1., r, tmin, rec.t, rec))
    
        hit = true,
        rec.mat = GLASS(vec3(1), 1.5, 0.);
    
    if (iSphere(translate(vec3(-4, 1, 0)), 1., r, tmin, rec.t, rec))
    
        hit = true,
        rec.mat = DIFFUSE(vec3(.4, .2, .1), 1.);
    
    if (iSphere(translate(vec3(4, 1, 0)), 1., r, tmin, rec.t, rec))
    
        hit = true, 
        rec.mat = METAL(vec3(.7, .6, .5), 0.);
    
    vec2 ro = r.o.xz, rd = r.d.xz, p = floor(ro), s = sign(rd), m,
         d = (p - ro + .5 + s * .5) / rd, cen;
    
    bool bhit = false;
    
    float t;
    if(box(translate(vec3(0, .2, 0)), vec3(12, .2, 12), r, tmin, rec.t, t))
    for(int i = ZERO; i < 40; i++)
    {
        for(int j = ZERO; j < 4; j++)
        {
            cen = p - vec2(j / 2, j % 2);
            
            if (all(lessThan(abs(cen), vec2(12))))
            {
                cen += .2 + .9 * hash2(cen);

                if (sqr(abs(abs(cen.x) - 2.) - 2.) + sqr(cen.y) > .8)
                if (iSphere(translate(vec3(cen.x, .2, cen.y)), .2, r, tmin, rec.t, rec))
                {
                    bhit = true;
                    
                    vec4 ran = hash4(cen);

                    if(ran.w < .8)
                    {
                        if      (ran.w < .3) rec.mat = DIFFUSE(ran.xyz * ran.xyz * .9 + .1, 1.);
                        else if (ran.w < .5) rec.mat = METAL(.5 * ran.xyz + .5, .5 * hash(ran));
                        else                 rec.mat = GLASS(.5 * ran.xyz + .5, 1.5, 0.);
                    }

                    else rec.mat = LIGHT(4. * ran.xyz);
                }
            }
        }

        if(bhit)
        {
            hit = true;
            break;
        }
            
        m = step(d, d.yx);
        d += m / abs(rd);
        p += m * s;
    }
    
    //if(marchHit(r, tmin, rec.t, rec)) hit = true;
    
    return hit;
}

vec3 skyTexture(vec3 rd)
{
    if(SKYTYPE == 1) return (1. - vec3(.25, .15, 0) * (rd.y + 1.));
    if(SKYTYPE == 2) return .7 * texture(iChannel0, rd).xyz;
    
    return vec3(0);
}

vec3 sphericalDirection(float sinTheta, float cosTheta, float sinPhi, float cosPhi) {
    return vec3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
}

vec3 uniformSampleCone(float cosThetaMax, vec3 X, vec3 Y, vec3 Z)
{
    float cosTheta = mix(cosThetaMax, 1., rand);
    float sinTheta = sqrt(1. - cosTheta * cosTheta);
    float phi = rand * TAU;
    vec3 V = sphericalDirection(sinTheta, cosTheta, sin(phi), cos(phi));
    return V.x * X + V.y * Y + V.z * Z;
}

const float scale = 2.,

            r1  =   0.836,
            r2  =   3.210,
            r3  =   0.448,
            r4  = -11.500,
            r5  =   0.283,
            r6  = - 0.385,
            r7  =   0.505,
            r8  = - 0.532,
            r9  =   1.060,
            r10 = - 1.200,
            
            d1 = 0.1075,
            d2 = 0.0165,
            d3 = 0.1555,
            d4 = 0.0505,
            d5 = 0.1890,
            d6 = 0.0505,
            d7 = 0.2122,
            d8 = 0.0097,
            d9 = 0.1390,
            
            N1 = 1.64238,
            N2 = 1.62306,
            N3 = 1.57566,
            N4 = 1.67270,
            N5 = 1.64238,
            N6 = 1.64238,
            
            V1 = 48.0,
            V2 = 56.9,
            V3 = 41.2,
            V4 = 32.2,
            V5 = 48.0,
            V6 = 48.0,
            
            A  = .4444 * scale;
            
const float N = 1.4, AD = .6308 / N * scale, ID = .864,
            k1 = .19749, k2 = .61588, k3 = .20134;
float I;

struct lens
{
    // Radius, Thickness, IOR, Abbe number, Semi-Diameter
    float R, d, N, V, h;
};

const int numLenses = 10;
const lens[] lenses = lens[](lens(r1,  d1, N1, V1, .36),
                             lens(r2,  d2, 1., 0., .36),
                             lens(r3,  d3, N2, V2, .32),
                             lens(r4,  d4, N3, V3, .32),
                             lens(r5,  d5, 1., 0., .22),
                             lens(r6,  d6, N4, V1, .22),
                             lens(r7,  d7, N5, V1, .29),
                             lens(r8,  d8, 1., 0., .29),
                             lens(r9,  d9, N6, V1, .29),
                             lens(r10, 0., 1., 0., .29));

cam c;

bool iLens(float pos, float h, float R, ray r, float tmin, float tmax, inout hitRecord rec)
{
    vec3 oc = r.o - c.w * (R + pos) - c.o, p;
    
    float b = dot(oc, r.d),
          d = R * R - dot2(oc - b * r.d);
          
    if(d < 0.) return false;
    
    d = sqrt(d);
    
    float t = -b - d, s = -sign(R),
          zCap = sqrt(R * R - h * h);
    
    if(t > tmin && t < tmax && s * dot(p = oc + r.d * t, c.w) > zCap)
    {
        rec.t = t;
        rec.p = r.o + r.d * t;
        rec.n = p / abs(R);
        return true;
    }
    
    t = -b + d;
    
    if(t > tmin && t < tmax && s * dot(p = oc + r.d * t, c.w) > zCap)
    {
        rec.t = t;
        rec.p = r.o + r.d * t;
        rec.n = -p / abs(R);
        return true;
    }
	
	return false;
}

vec3 color(ray r)
{
    vec3 col = vec3(1), emitted = vec3(0);
    float pdf;
	hitRecord rec;
    
    #ifdef USE_LENS
    
    float zMax = 0.;
    float[numLenses] lensPos;
    lens L, l;
    
    for(int i = ZERO; i < numLenses; i++)
    {
        l = lenses[i];
        lensPos[i] = zMax;
        zMax += l.d * scale;
    }
    
    #ifdef DISPERSION
    float waveMix = halton(seed.w);
    #else
    float waveMix = .5;
    #endif
    
    l = lenses[numLenses - 1]; l.R *= scale; l.h *= scale;
    
    vec3 oc = c.o - c.w * (l.R - lensPos[numLenses - 1] - sign(l.R) * sqrt(l.R * l.R - l.h * l.h)) - r.o,
         Z = normalize(oc), X, Y;
    
    onb(Z, X, Y);
    
    float cosThetaMax = sqrt(max(0., 1. - l.h * l.h / dot2(oc)));
    
    r.d = uniformSampleCone(cosThetaMax, X, Y, Z);
    
    col *= /* TAU * (1. - cosThetaMax) */ dot(r.d, -c.w) / PI;
    
    float tmin = 1e-3 * scale;
    int lensID = numLenses;
    
    for (int i = ZERO; i < 20; i++)
    {
        lensID += int(sign(dot(r.d, c.w)));
        
        L = lenses[lensID];
        
        L.R *= scale;
        L.h *= scale;
        
        if(iLens(lensPos[lensID], L.h, L.R, r, tmin, 1e5, rec))
        {
            vec3  o = r.o - c.o - A * c.w;
            float t = -dot(c.w, o) / dot(r.d, c.w);
            
            if(t > 0. && t < rec.t)
            if(4. * dot2(o + r.d * t) > AD) return vec3(0);
            
            if(lensID > 0) l = lenses[lensID - 1];
            else           l = lens(0., 0., 1., 0., 0.);
            
            if(dot(r.d, c.w) < 0.)
            {
                lens temp = L;
                L = l; l = temp;
            }
            
            float n1 = L.N,
                  n2 = l.N,
                  IOR, F;
            
            float d = 550. / 4. / n1,
                  nCoat = sqrt(n1 * n2);
            
            #ifdef DISPERSION
            
            if(n1 > 1.) n1 -= (waveMix - .5) * (n1 - 1.) / L.V;
            if(n2 > 1.) n2 -= (waveMix - .5) * (n2 - 1.) / l.V;
            
            #endif
            
            IOR = n2 / n1;
            
            #ifdef ANTI_REFLECTION_COATING
            
            F = Reflectance(400. + 300. * waveMix, d, acos(dot(-r.d, rec.n)), n1, nCoat, n2);
            
            #else
            
            F = dielectricFresnel(abs(dot(r.d, rec.n)), IOR);
            
            #endif
            
            r = ray(rec.p, rand < F ? reflect(r.d, rec.n) : refract(r.d, rec.n, IOR));
        }
        else break;
    }
    
    if(lensID > -1) return vec3(0);
    #endif
    
    for (int i = ZERO; i < 10; i++)
    {
        if (worldHit(r, .01, 1e5, rec))
        {
            emitted += col * rec.mat.emission;
            
            if(luma(col) < 1e-6) break;
            
            ray scattered;
            scattered.o = rec.p;
            
            rec.eta = rec.mat.IOR;
            if(dot(rec.n, r.d) > 0.) rec.n = -rec.n;
            else rec.eta = 1. / rec.eta;
            vec3 BSDF = DisneySample(rec, -r.d, scattered.d, pdf);
            if(pdf > 0.) col *= BSDF / pdf;
            else break;
            
            r = scattered;
            
            #ifdef RUSSIAN_ROULETE
            float p = 1. - 1. / luma(col + 1.);
        	if (rand > p) break;
            col /= p;
            #endif
        }
        
        else
        {
            emitted += col * skyTexture(r.d);
            break;
    	}
    }
    
    #ifdef USE_LENS
    
        emitted *= 5. * N * N;
        #ifdef DISPERSION
        emitted *= 4. * max(1. - abs(4. * waveMix - vec3(3, 2, 1)), 0.);
        #endif
    
    #endif

    return emitted;
}

cam camera(vec3 ro, vec3 lp, vec3 vup, float vfov, float aperture, float d)
{
    cam c;
    
    float hh = tan(radians(vfov) / 2.) * d,
          hw = R.x / R.y * hh;
          
    c.rad = aperture / 2.;
    c.o = ro;
    c.w = normalize(ro - lp);
    c.u = normalize(cross(vup, c.w));
    c.v = cross(c.w, c.u);
    c.llc = c.o - hw * c.u - hh * c.v - d * c.w;
    c.hor = 2. * hw * c.u;
    c.ver = 2. * hh * c.v;
    
    d /= scale;
    I = scale * (d + k1) / (k2 * d - k3);
    
    return c;
}

ray getRay(cam c, vec2 uv)
{
    #ifdef USE_LENS
    uv -= .5;
    uv.x *= R.x / R.y;
    uv   *= .6 * ID * scale;
    
    return ray(c.o - uv.x * c.u - uv.y * c.v + c.w * I, c.w);
    
    #else
    vec2 rd = c.rad * ranDisk();
    
    c.o += c.u * rd.x + c.v * rd.y;
    
    return ray(c.o, normalize(c.llc + uv.x * c.hor + uv.y * c.ver - c.o));
    #endif
}

void mainImage(out vec4 O, vec2 I)
{
    O = vec4(0);
    
    if(iFrame < 2 && SKYTYPE > 1) return;
    
    seed = uvec4(I, iFrame, iTime);
    
    vec2 uv = (I + rand2 - .5) / R.xy;
    
    c = camera(vec3(13, 2, 3), vec3(0), vec3(0, 1, 0), 28., AD, 10.);
    
    vec3 col = deNaN(color(getRay(c, uv)));
    
    if(texelFetch(iChannel2, ivec2(32, 0), 0).x < .5) O = texelFetch(iChannel1, ivec2(I), 0);
    
    O += vec4(col, 1);
}
