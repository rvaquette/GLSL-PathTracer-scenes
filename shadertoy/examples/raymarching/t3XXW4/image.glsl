//---------------------------------------------------------------------
// keyboard stuff

bool        kPipOn      =   false;      // heat map.       1
bool        kPixelate   =   false;      // chunky pixels.  2
bool        kShadows    =   true;       // shadows.        3
bool        kFullRays   =   true;       // quality.        4
bool        kMtl1       =   false;      // material        5
bool        kCut        =   false;      // cutting plane   6
bool        kHollow     =   false;      // hollow geometry 7

void readKeyboard() {
    const int ZRO = 48;
    kPipOn    =  KEY_TOGGLED(ZRO + 1, iChannel2);
    kPixelate =  KEY_TOGGLED(ZRO + 2, iChannel2);
    kShadows  = !KEY_TOGGLED(ZRO + 3, iChannel2);
    kFullRays = !KEY_TOGGLED(ZRO + 4, iChannel2);
    kMtl1     =  KEY_TOGGLED(ZRO + 5, iChannel2);
    kCut      =  KEY_TOGGLED(ZRO + 6, iChannel2);
    kHollow   =  KEY_TOGGLED(ZRO + 7, iChannel2);
}

//---------------------------------------------------------------------
// materials

const uint mtl_0                 =  0u;
const uint mtl_floor             =  1u;
const uint mtl_green_glass       =  2u;
const uint mtl_other_glass       =  3u;
const uint mtl_cup_glass         =  3u;
const uint mtl_debug             =  5u;
const uint mtl_count             =  6u;

const mtl_t materials[mtl_count] = mtl_t[](
    //    ior   trn   alb                  transmissance
    mtl_t(1.0 , 0.0 , v1                 , v41),                         // sky
    mtl_t(2.0 , 0.0 , v1                 , v41),                         // floor
    mtl_t(1.5 , 1.0 , v0                 , vec4(0.1, 0.7, 0.2 ,  1.3)), // glass chartreuse
    mtl_t(1.8 , 1.0 , v0                 , vec4(0.3, 0.9, 0.4 ,  2.0)),  // other glass
    mtl_t(1.8 , 1.0 , v0                 , vec4(0.3, 0.9, 0.4 ,  2.0)),  // cup glass
    mtl_t(2.0 , 0.0 , vec3(0.8, 0.6, 0.6), v41)                          // debug
);


//---------------------------------------------------------------------
// viewport stuff

const float cPipScale   =   0.4;        // heatmap size
const float cPixelation =   8.0;
      float gVPZoom     =   0.8;
      float gVPEps      =   1e9;        // viewport epsilon
      float gVPLW       =   1e9;        // viewport linewidth
      float gT          =   0.0;
      float gFOVFac     =   0.5;        // smaller = zoomier
      float gCamDist    =  30.0;
      float gMapCount   =   0.0;
      vec3  gRGB;
      
// raymarch stuff
const uint  cMaxMarchSteps = 900u;      // crazy high for internal reflection
const uint  cHeatMapSteps  = 150u;      // march steps used in heatmap visualization
const float cWSEps         =   0.0001;
const float gUnderStepFac  =   0.98;
const float cSurfEps       =   cWSEps * 3.0;
const float cMinRayAmt     =   0.4 / 256.0;
const uint  cMaxRays       = 2010u;
      uint  gRayCount;
const uint  cHeatMapRays   =   20u;
      uint  gMaxRays       =   cMaxRays; // toggled at runtime
      uint  gMtl           =   mtl_green_glass;
      
//---------------------------------------------------------------------
// scene stuff

float gCutPlaneOffset = 1e8; // set at runtime

void configScene() {
    gCutPlaneOffset = kCut  ? 0.0 : -1e8;
    gMtl            = kMtl1 ? mtl_debug : mtl_green_glass;
}


vec4 opElongate( in vec3 p, in vec3 h )
{
    vec3 q = abs(p)-h;
    return vec4( max(q,0.0), min(max(q.x,max(q.y,q.z)),0.0) );
}

MST map(in vec3 p) {
    gMapCount += 1.0;

    MST   ret = MST(1e9, mtl_0);
    
    float d = ret.dist;
    vec3  q;
    vec4  w;
    
    // centimeters
    const float outRad          = 11.0;
    const float height          = 18.0;
    const float mainThickness   =  0.8;
    const float hover           =  0.001;
    const float wallThick       =  0.1;
    const float handleClearance =  2.0;
    
    const float handleRad        = 3.3;
    const float handleHeight     = height / 2.0 + mainThickness - 3.5;
    const float handleVertOffset = 1.0;
    const float handleWidth      = 0.8;
    const float handleDepth      = 5.0;
    const float handleThickness  = 0.4;
    
    const float cylRad = outRad - mainThickness;
    
    // bottom is a cylinder
    q = p;
    q.y -= mainThickness + wallThick + hover;
    d = min(d, sdCappedCylinder(q, mainThickness, cylRad));
    
    // walls are a space-expanded torus
    q = p;
    q.y -= mainThickness + wallThick + height / 2.0 + hover;
    w = opElongate(q, vec3(0.0, height / 2.0, 0.0));
    
    d = min(d, w.w + sdTorus(w.xyz, vec2(cylRad, mainThickness)));
    
    d = kHollow ? abs(d) : d;
    d -=wallThick;
    
    // handle
    q = p;
    q.y -= mainThickness + wallThick + height / 2.0 + hover + handleVertOffset;
    q.z -= outRad;
    w = opElongate(q, vec3(handleWidth, handleHeight - handleRad, handleDepth - handleRad));
    float hd = w.w + sdTorus(w.yxz, vec2(handleRad, handleThickness));
    opMinus(hd, p.z - outRad);
    
    d = smin(d, hd, 0.3);
    
    d = max(d, p.x + gCutPlaneOffset);

    ret.dist = d;
    ret.mtl = gMtl;


    return ret;
}

// https://iquilezles.org/articles/normalsSDF
vec3 mapNormal(vec3 p){
    vec3 n = vec3(0.0);
    for(int i = ZERO; i < 4; i++){
        vec3 e = 0.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e*map(p+e*cWSEps).dist;
    }
    return normalize(n);
}


void rayVsScene(in ray_t r, inout hit_t h, in uint maxSteps) {
    // tack on a plane via analytic intersection.
    rayVsPlane (r, vY, 0.0, mtl_floor, h);

    float t = 0.0;
    
    for (uint n = 0u; n < maxSteps && t < 1e3; ++n) {
        vec3 p = r.ro + r.rd * t;
        MST ms = map(p);
        float absDist = abs(ms.dist);
        if (t < h.t && (absDist < cWSEps)) {
            h.hit      = true;
            h.t        = t;
            h.pnt      = p;
            h.nrm      = mapNormal(p);
            h.mtl      = ms.mtl;
            
            if (h.mtl == gMtl) {
                // bumps
                const float bumpSize = 0.01;
                h.nrm.y += sin(p.y * 7.12 + sin(p.y * 1.0) * 3.0 ) * (1.0 + 0.7 * sin(p.x * 2.0)) * bumpSize;
                h.nrm    = normalize(h.nrm);
            }
            
            return;
        }


        t += absDist * gUnderStepFac;
    }
}

#define Q_TYPE        ray_t
#define Q_MAX_ENTRIES 15u
Q_IMPLEMENTATION

vec3 gSunDir = normalize(vec3(-1.0, 1.0, -1.0));
vec3 toneSky(in ray_t r) {
    return v1;
    return r.rd * 0.5 + 0.5;
}

vec3 toneFloor(in vec2 p) {
    if (abs(p.y) < 2.2) {
        p.x += gT;
    }
    p = fract(p * 0.2 - 0.5);
    float f = length(p * 2.0 - 1.0);
    return 0.5 + 0.2 * smoothstep(0.9, 0.88, f) * v1;
}

vec3 tone(in ray_t r, in hit_t h) {
    switch (h.mtl) {
        case mtl_0:
            return toneSky(r);
        case mtl_floor:
            return toneFloor(h.pnt.xz);
        default:
            return materials[h.mtl].color;
    }
}


void runRays() {

    // accumulates in gRGB.
    
    gRayCount = 0u;
    gMaxRays = kFullRays ? cMaxRays : 8u;
    
    while (!QIsEmpty()) {
        gRayCount += 1u;
        ray_t r = QDequeue();
        
        
        hit_t h = hit_t(false, 1e9, v0, vX, mtl_0);
        h.mtl = mtl_0;
        rayVsScene(r, h, cMaxMarchSteps);
        
        if (!h.hit) {
            // no hit - escapes to the sky
            gRGB += r.amt * toneSky(r);
        }
        else {
            // a hit!
            // "nrm" here is the hit-facing normal,
            // while h.nrm is the "outward" facing normal.
            
            mtl_t m = materials[h.mtl];
                        
            vec3  nrm     = h.nrm * r.side;
            float R0      = schlickR0(m.ior, ior_air);
            vec3  reflAmt = v1 * schlick  (R0, dot(r.rd, -nrm));            
            vec3  trnsAmt = m.diffVsTrns * (1.0 - reflAmt);
            vec3  diffAmt = (1.0 - m.diffVsTrns) * (1.0 - reflAmt);

            if (r.side < 0.0) {
                // just traveled through media, attenuate !
                r.amt *= exp(-m.absorption.w * h.t * (1.0 - m.absorption.rgb));
            }

            reflAmt *= r.amt;
            trnsAmt *= r.amt;
            diffAmt *= r.amt;
            
            if (gRayCount >= gMaxRays) {
                continue;
            }
            
            // diffuse

            if (QSpaceLeft() < 1u) {
                continue;
            }
                        
            if (dot(diffAmt, diffAmt) > cMinRayAmt * cMinRayAmt) {
                // diffuse lighting at surfaces.
                
                float sunDot      = dot(gSunDir, h.nrm);
                if (sunDot > 0.0) {

                    // cast a diffuse lighting ray.
                    ray_t dlrRay;
                    dlrRay.ro         = h.pnt + h.nrm * cSurfEps;
                    dlrRay.rd         = gSunDir;
                    dlrRay.amt        = diffAmt * sunDot * tone(r, h);
                    dlrRay.side       = 1.0;
                    dlrRay.ior        = 1.0;
                    dlrRay.DLR        = true;
                    
                    if (dot(dlrRay.amt, dlrRay.amt) > cMinRayAmt * cMinRayAmt) {
                        if (!kShadows) {
                            // if no shadows, advance the ray to the sky
                            dlrRay.ro += dlrRay.rd * 1e4;
                        }
                        QEnqueue(dlrRay);
                    }
                }
            }


            // transmission
            
            if (QSpaceLeft() < 1u) {
                continue;
            }
            
            if (dot(trnsAmt, trnsAmt) > cMinRayAmt * cMinRayAmt) {
                if (!r.DLR) {
                    float eta = r.ior / m.ior;
                    if (r.side < 0.0) {
                     //   eta = 1.0 / eta;
                    }
                    vec3 trnRayDir = refract(r.rd, nrm, eta);
                    if (dot(trnRayDir, trnRayDir) < 0.001) {
                        // total internal reflection.
                        reflAmt += trnsAmt;
                    }
                    else {
                        // the treatment of "side" here is not accounting for
                        // the possibility of both sides being inside.
                        // but it looks good !
                        ray_t trnRay;
                        trnRay.ro   = h.pnt - nrm * cSurfEps;
                        trnRay.rd   = trnRayDir;
                        trnRay.side = -r.side;
                        trnRay.amt  = trnsAmt;
                        trnRay.DLR  = false;
                        trnRay.ior  = m.ior;

                        QEnqueue(trnRay);
                    }
                }
                else {
                    // is DLR ray: diffuse lighting ray not refracted, reflected, etc.
                    ray_t trnRay;
                    trnRay.ro   = h.pnt - nrm * cSurfEps;
                    trnRay.rd   = r.rd;
                    trnRay.side = -r.side;
                    trnRay.amt  = trnsAmt;
                    trnRay.DLR  = true;
                    trnRay.ior  = 1.0;

                    QEnqueue(trnRay);
                }
            }

            // reflection
            if (QSpaceLeft() < 1u) {
                continue;
            }
            if (!r.DLR && dot(reflAmt, reflAmt) > cMinRayAmt * cMinRayAmt) {
                ray_t rflRay;
                rflRay.ro   = h.pnt + nrm * cSurfEps;
                rflRay.rd   = reflect(r.rd, nrm);
                rflRay.side = r.side;
                rflRay.amt  = reflAmt;
                rflRay.DLR  = false;
                rflRay.ior  = r.ior;

                QEnqueue(rflRay);
            }
        }
    }
}


float viewportFromScreen(in float D) {
    return D * 2.0 / MINRES / gVPZoom;
}

vec2 viewportFromScreen(in vec2 XY) {
    return vec2(viewportFromScreen(XY.x - RES.x / 2.0),
                viewportFromScreen(XY.y - RES.y / 2.0));
}


void mainImage(out vec4 RGBA, in vec2 XY)
{
    readKeyboard();
    
    // modify XY for pixelation station
    if (kPixelate) {
        XY = XY - (fract(XY / cPixelation ) - 0.5) * cPixelation;
    }

    // modify XY for picture-in-picture
    bool isPip = kPipOn && (XY.x < RES.x * cPipScale && XY.y < RES.y * cPipScale);
    if (isPip) {
        XY /= cPipScale;
    }
    
    vec2 xy = viewportFromScreen(XY);
    gVPEps  = viewportFromScreen(2.0);
    gVPLW   = viewportFromScreen(2.0);
    gT      = iTime * pi * 2.0 / 7.0;
    vec2 ms = iMouse.xy / iResolution.xy;
    vec2 mss;
    if (length(iMouse.xy) < 20.0) {
        mss.x = gT * 0.1 - ms.x * 6.0 - pi/2.0;
        mss.y = sin(gT * 0.131 + 10.5) * 0.2 + 0.5;
    }
    else {
        mss.x = -ms.x * pi * 2.3;
        mss.y =  ms.y;
    }
    
    vec2  camYMinMax = vec2(0.01, 2.0);
    float theta      = mss.x;
    float camY       = mix(camYMinMax[1], camYMinMax[0], smoothstep(0.0, 1.0, sqrt(mss.y)));
    vec3  lookFrom   = vec3(sin(theta), camY, cos(theta)) * gCamDist;
    vec3  lookTo     = vY * 10.0;
    
    vec3  camFw      = normalize(lookTo - lookFrom);
    vec3  camRt      = normalize(cross(camFw, vY));
    vec3  camUp      = cross(camRt, camFw);
    
    configScene();
    
    ray_t r;
    r.ro    = lookFrom;
    r.rd    = normalize(camFw + (camRt * xy.x + camUp * xy.y) * gFOVFac);
    r.amt   = v1;
    MST mst = map(r.ro);
    r.side  = sign(mst.dist);
    r.ior   = mst.dist < cWSEps ? materials[mst.mtl].ior : 1.0;
    r.DLR   = false;
    QEnqueue(r);
    
    gRGB = v0;
    runRays();
    
    gRGB = pow(gRGB, vec3(1.0/2.2));
    
    if (isPip) {
        const vec3 cCool = vec3(0.0, 0.0, 0.2);
        const vec3 cHot  = vec3(1.0, 0.9, 0.2);
        float temp = gMapCount / float(cHeatMapSteps * cHeatMapRays);
        gRGB = mix(cCool, cHot, pow(temp, 0.6));
    }

    RGBA = vec4(gRGB, 1.0);
}
