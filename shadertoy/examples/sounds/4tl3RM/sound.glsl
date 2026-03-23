// Robin
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Created by David Hoskins.

// Random pitch movements plus a high speed warble cut into three phrases. 
// Background leafy wind noise plus stereo answer calls from the trees.

float Hash(float p)
{
	vec2 p2 = fract(vec2(p * 5.3983, p * 5.4427));
    p2 += dot(p2.yx, p2.xy + vec2(21.5351, 14.3137));
	return fract(p2.x * p2.y * 95.4337);
}
//----------------------------------------------------------------------------------------
vec2 Hash(vec2 p)
{
	p  = fract(p * vec2(1.3983, 1.4427));
    p += dot(p.yx, p.xy +  vec2(3.5351, 4.3137));
	return fract(vec2(p.x * p.y * 5.4337, p.x * p.y * 7.597));
}


float Noise(float n)
{
    float f = fract(n);
    n = floor(n);
    f = f*f*(3.0-2.0*f);
    return mix(Hash(n), Hash(n+1.0), f)-.5;
   
}

float NoiseSlope(float n, float loc)
{
    float f = fract(n);
    n = floor(n);
    f = smoothstep(0.0, loc, f);
    return mix(Hash(n), Hash(n+1.0), f);
}

//--------------------------------------------------------------------------
vec2 Noise( in vec2 x )
{
    vec2 p = floor(x);
    vec2 f = fract(x);
    f = f*f*(3.0-2.0*f);
    vec2 res = mix(mix( Hash(p + 0.0), Hash(p + vec2(1.0, 0.0)),f.x),
                   mix( Hash(p + vec2(0.0, 1.0) ), Hash(p + vec2(1.0, 1.0)),f.x),f.y);
    return res-.5;
}

//--------------------------------------------------------------------------
vec2 FBM( vec2 p )
{
    p = mod(p, 200.0);
    vec2 f;
	f  = 0.5000	 * Noise(p); p = p * 3.;
	f += 0.2500  * Noise(p); p = p * 3.;
	f += 0.1250  * Noise(p); p = p * 3.;
    f += 0.062125 * Noise(p); p = p * 3.;
    return f;
}


float TweetVolume(float t)
{
    float n = NoiseSlope(t*11.0, .1) * abs(sin(t*14.0))*.5;
    n = (n*smoothstep(0.4, 0.9, NoiseSlope(t*.5+4.0, .1)));
    return min(n*n * 2.0, 1.0);
}

float Tweet(float t)
{
    float which = mod(floor(t/3.0), 3.0);
    t = mod(t, 3.0);
    float f;
    // which = 1.5;
    // Divided into three different phrases...
    if (which >= 2.0)
    {
        t = 1.5-t;
        f = sin(6.2831*2.5*t)*Noise(t*14.3+3.0)*100.0+5000.0;
        f += cos(50.0*6.2831*t);
        f = sin(6.2831*f*t);
    }else
    if (which >= 1.0)
    {
        t = 1.5-t;
        f = (sin(6.2831*3.0*t)*Noise(t*12.5))*100.0+4500.0;
        f += cos(50.0*6.2831*t);
        f = sin(6.2831*f*t);
    }else
    {
        t = t - 1.5;
       	f = sin(6.2831*2.0*t)*Noise(t*8.1-100.0)*100.0+5000.0;
        f += cos(50.0*6.2831*t);
        f = sin(6.2831*f*t);
    }
    return f;
}

vec2 mainSound( in int samp,float time)
{
    
    float gTime= time;
    vec2 pos = vec2(gTime * (1250.5), gTime * (1200.2));
    vec2 noise = FBM(pos)* .15 + FBM(pos*8.0)* (.1*Noise(gTime*.4)+.1);
    
    float volume = TweetVolume(gTime);
    
    vec2 audio =  (vec2(Tweet(gTime)) * volume + noise) ;
    audio += vec2( Tweet(gTime+300.0)* TweetVolume(gTime+300.0), Tweet(gTime+120.0)* TweetVolume(gTime+220.0))* .08;
    return audio* smoothstep(.0, 2.0, time) * smoothstep(180.0, 170.0, time);
}