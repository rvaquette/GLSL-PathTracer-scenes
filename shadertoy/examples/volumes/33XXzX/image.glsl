const vec3 BOUNDS_EXTENTS = vec3(1., 1.56, .5);

// Cloud params
const float DENSITY = 9.;
const float STEP_SIZE = .051;
const float LIGHT_STEP_SIZE = .051;
const float NOISE_SCALE = .9;
const float FALLOFF = .3;
const float ONE_OVER_FALLOFF = 1./FALLOFF;
const float ROTATION_FACTOR = .033333333;
const float ROTATION_FACTOR_RAD = ROTATION_FACTOR * 6.2831853;

// Light params
const vec3 TO_LIGHT = normalize(vec3(.5,.75,-.51));
const vec3 LIGHT_COLOR = vec3(.98,1.,.9);
const float CLOUD_SCATTER_FACTOR =1.;

 
// Sky params
const vec3 SKY_COLOR = .8* vec3(.21,.5,.96);


const mat3 NROT = mat3(0.4119822,  0.0587266,  0.9092974,
  -0.6812427, -0.6428728,  0.3501755,
   0.6051273, -0.7637183, -0.2248451);
const float deg2rad = 0.0174533;


float torus(in vec3 p, in vec2 rs)
{
    vec2 q = vec2(length(p.xz)-rs.x,p.y);
  	return length(q)-rs.y;
}

float map(in vec3 p, float time)
{
    float d = torus(p.xzy - vec3(0.,0.,0.66), vec2(.5, .5));
    float bof = mix(1.,-1.,gain8(1.-abs(fract(ROTATION_FACTOR*time)-.5)*2.));
    d = min(d,xyPlaneLine(p, vec2(0.,-1.06), vec2(bof*0.4784,.514651))-.5);
    return d;
}

float noise(in vec3 p)
{
    p = fract(p);
    float blend;
    vec2 uv = three2two(p, iResolution.xy, blend);
    vec2 smpl = texture(iChannel0,uv).xy;
    return mix(smpl.x,smpl.y,blend);
}


float density(in vec3 p, in float time, in float dist)
{
    p = NROT*p;
    float ang = ROTATION_FACTOR_RAD * time;
    p += .8*vec3(cos(ang), 0.,sin(ang));
    float noi = noise(p*NOISE_SCALE);
    noi -= clamp(1.+dist*ONE_OVER_FALLOFF,0.,1.);
    return clamp(noi, 0., 1.) * DENSITY;
}


float ltrace(in vec3 sta, in vec3 dir, in float time)
{
    float end = boxIntersection(sta, dir, BOUNDS_EXTENTS).y;
    if (end <= 0.)
        return 1.;
    float trans = 1.;
    float t = LIGHT_STEP_SIZE*.5;
    for (int i = 0; i < 100; ++i)
    //while (trans >= .01 && t < end)
        
    {
        vec3 p = sta + t * dir;
        float d = map(p, time);
        if (d < 0.)
        	trans *= exp(-density(p, time, d) * LIGHT_STEP_SIZE);
        t += LIGHT_STEP_SIZE;
       	if (trans <= .02 || t >= end)
            return trans;
        
    }
    return trans;
}


vec4 trace(in vec3 sta, in vec3 dir, in vec3 light, in float time)
{
    vec2 dists = boxIntersection(sta, dir, BOUNDS_EXTENTS);
    if (dists.y <= 0.)
        return vec4(0.,0.,0.,0.);
    float trans = 1.;
    vec3 col = vec3(0.);
    float t = max(dists.x, 0.);
    for (int i = 0; i < 100; ++i)
    //while (t < dists.y && trans >= .02)
    {
        vec3 p = sta + t * dir;
        float d = map(p, time);
        if (d > .001)
            t += max(STEP_SIZE, d);
        else
        {
            float den = d >=  0. ? 0. : density(p, time, d);
            if (den > 0.05)
            {
                den *= STEP_SIZE;
        		col += CLOUD_SCATTER_FACTOR * den * trans * ltrace(p, light, time) * LIGHT_COLOR;
        		trans *= exp(-den);
            }
            t += STEP_SIZE;
		}
        if (t >= dists.y || trans <= .02)
            break;
    }
    return vec4(col, 1.-trans);
    
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;
    vec2 st = uv - .5;
    float aspect = iResolution.x/iResolution.y;
    st.x *= aspect;
    float time = iTime;
    
    // Camera
    vec3 dir = normalize(vec3(st, 3.732050)); // 30 deg vfov
    vec3 cam = vec3(0.,0.05,-12.);
    float ang = ROTATION_FACTOR_RAD*time;
    float sn = sin(ang), cs = cos(ang);
    vec3 light = TO_LIGHT;
    mat2 lrot = mat2(cs, -sn, sn, cs);
    light.xz = lrot * light.xz;
    float sn2=-.5, cs2 =0.866025; // 30 deg tilt
    mat3 mat = mat3(cs,0.,-sn,-sn2*sn,cs2,-cs*sn2,sn*cs2,sn2,cs*cs2);
    dir = mat * dir;
    cam = mat * cam;
    /*cam.xz = lrot * cam.xz;
    dir.xz = lrot * dir.xz;*/
    
    // Trace
    vec4 clo = trace(cam, dir, light, time);
    vec3 col = mix(vec3(1.),SKY_COLOR,.8+.2*(1.-(1.-uv.y)*(1.-uv.y)));
    col = clo.xyz + (1.-clo.w) * col;
    
    // Post
    col = vec3(pow(col.x, .45), pow(col.y, .45), pow(col.z, .45));
    col = col*col*(3.-2.*col);
    col *= 1.-.27*dot(st,st);
    col += sin(2342.*uv.x+139.*uv.y)*0.00196078;//dither
    
    
    //vec3 col=texture(iChannel0, uv).xxx;
    //col=vec3(-map(vec3(4.*st,0.),time));

    // Output to screen
    fragColor = vec4(col,1.0);
}

