
float pi;

float note_freq(float note) { return 440.*pow(2.,note/12.); }
const int tmajor[7] = int[7](0,2,4,5,7,9,11);
float major(float k) {
    return 3. + float(tmajor[int(k+140.)%7])+floor(k/7.)*12.; // B Major
}

//////////// synth params

// seed, overtones, sharpness, width
vec4 seeding=vec4(31,60,1.2,0.03);
// repeat, attack, sustain duration, release
vec4 enveloppe = vec4(4,1.,2.5,.5);

float decay = 1.;

// AMP
float pregain = 0.2;
float gain = 1.;

// enveloppe based on time t
float env(float t) {
    return c01(t/enveloppe.y) * c01(1.-(t-enveloppe.y-enveloppe.z)/enveloppe.w);
}

// main synth of the intro
// play 40 frequencies randomly chosen as integer multiplier of the base frequency
// for each of thoses frequency, play 40 instances with slight phase and frequency offsets
float realsynth(vec3 note) {
	if(note.y<-98.) return 0.;

    float s=0.;    
    for(float i=0.; i<40.; ++i) {
        float id = i+seeding.x;
		float cur = note.y;
		float freq = note_freq(cur);
		float over = rnd11(id);
		freq *= 1.+floor(pow(over,seeding.z)*seeding.y);
		float amp = pow(1.-over, note.x*decay);
		for(float j=1.; j<40.; ++j) {
			float sub = freq * (1.+(rnd11(id+j*.3)-.5) * seeding.w);
			s += amp*sin(sub*pi*2.*note.x + 2.*pi*rnd11(id+j*.7+.1)) * 2.;
		}
    }

	s*=note.z*pregain;
	s *= sqrt(gain / (1369. + (gain - 1.) * s * s));
	
	return s;
}

float pad(float time, float h) {
	float rt = mod(time, enveloppe.x);
	float ch = major(h+floor(rnd11(floor(time/enveloppe.x))*5.)*2.-16.);
	return realsynth(vec3(rt,ch,env(rt)));
}

float lead(float time) {
	float note = floor(time*4.);
	float t=fract(time*4.)/4.;

	// melody from the "pink sky" part
	float val = float(int[16](3,-99,5,-99,7,6,-99,-99,5,7,6,8,7,5,6,4)[int(note)%16]);
	if(mod(floor(note),4.)==0.)val+=mod(floor(note/16.),4.)*2.-2.;
	float mus = realsynth(vec3(t,major(val-4.),env(t)));
	mus += realsynth(vec3(t,major(val),env(t)))*(0.5+sin(time)*0.5);
	mus += realsynth(vec3(t,major(val-12.),env(t)))*(0.5+sin(time*0.7)*0.5);
	return mus;
}

float snare( float _phase ) {
  return clamp(sin( _phase * 800.) * exp( -_phase * 30. ) , -0.5, 0.5);
}

// random growling sound
vec2 growl(float tt, float id) {
	seeding.y=rnd11(id)*40.+3.;
	seeding.z=rnd11(id+.1)*40.;
	return abs(vec2(1,0)*rot(rnd11(id+.27)))*realsynth(vec3(tt,major(-32.+floor(24.*rnd11(id+.13))),1.));
}

// fade smoothly from a random growling sound to the next
vec2 growl2(float t, float r) {
	float tt=fract(t/r);
	float nn=floor(t/r);
	return mix(growl((tt+1.)*r,nn),growl(tt*r,nn+1.), pow(smoothstep(0.,1.,tt),1.));
}


vec2 mainSound( int samp, float time_base )
{
    
    pi =acos(-1.);
    
    float time = max(0.,time_base - 1.03);

    vec2 mus = vec2(0);
    float beat = fract(time);

    // global control of the song parts
    vec2 lead1 = vec2(0.6,.4) * block(time-91.,25.4,1.,.1); // pink sky part
    vec2 lead3 = vec2(0.5) * block(time-34.,30.,1.,.8); // sound for all the little spheres
    vec2 pad1 = 0.4*abs(vec2(sin(time*.2),cos(time*.25))) * block(time-24.5,68.5,8.,4.);
    vec2 bass = vec2(.7,.3)*block(time-36.,80.,.1,.1);
    vec2 drum = bass.yx;
    vec2 gro = vec2(1.-.8*block(time-40.,77.,4.,4.));
    float lead2 = block(time-67.,22.,2.,2.); // glowy sphere music

    // pad
    //seeding=vec4(31,60,1.2,0.03);
    //enveloppe=vec4(4,1.,2.5,.5);
    float padoc = -16.+lead2*8.;
    mus += pad1*pad(time, padoc)*vec2(1.2,0.2);
    mus += pad1*pad(time+1., padoc+2.) * chop(time*7.)*vec2(0.7,0.8);
    mus += pad1*pad(time+2., padoc+4.) * (0.5+0.5*chop(time*10.))*vec2(0.2,1.2);

    // lead 2 (glowy sphere)
    seeding=vec4(20,60,40,0.06+0.055*sin(time/10.)*sin(time/7.));
    enveloppe=vec4(1,.01,0.01,.4);

    float chord = mod(floor(time*2.), 8.)-2.;
    vec2 lead2b = 0.5*vec2(0.4,.6) * lead2;
    mus += lead2b*realsynth(vec3(fract(time),major(chord),exp(-fract(time)*3.)));
    mus += lead2b*realsynth(vec3(fract(time),major(chord+3.),exp(-fract(time)*3.)));
    mus += lead2b*realsynth(vec3(fract(time*3.),major(chord + mod(floor(time*3.),4.)*2. - 4.),exp(-fract(time*3.))));

    // lead 3 (sound of all the little spheres)
    seeding=vec4(77,30,20.+cos(time/30.)*17.,0.02+cos(time)*.04);
    enveloppe=vec4(0.5,.01,0.06,.02);
    for (int i=0; i<12; ++i) {
        mus += lead3*pad(time-float(i%4)-float(i/4)*0.3, -float(i%4*2))*(4.-float(i%4))*.15;
    }

    // lead 1 (pink sky part)
    seeding=vec4(22,60,12.+sin(time/16.)*10.,0.013);
    enveloppe=vec4(1,.01,0.12,.11);
    pregain=10.;
    gain=2.;
    mus += lead1 * lead(time) * 0.07;
    mus += lead1 * lead(time-.5) * 0.02;
    mus += lead1 * lead(time-.25) * 0.01;

    // bass
    seeding.z = 60.;
    mus += bass*0.13*realsynth(vec3(fract(time+.5),-40.,exp(-fract(time*4.)*4.)));

    // growling sounds
    pregain=0.2;
    gain=1.;
    seeding=vec4(22,60,2,0.07+1.0);
    enveloppe=vec4(1,.1,0.8,.1);

    // to produce some sfx, I just boost the growing a lot with appropriate fading
    // menacing sound when the wall approach the sphere, just before it stars glowing
    float crash=block(time-65.2,0.4,1.5,1.);
    // crash just before the yellow part
    crash=max(crash,block(time-117.5,0.2,.5,3.));
    // "click" when all the little purple spheres light's up
    crash=max(crash,block(time-30.1,0.1,.1,1.));
    gro+=crash*5.;
    decay = 0.1;
    vec2 gr = growl2(time, 8.)*2.;
    gr += growl2(time, 4.);
    gr += growl2(time, 2.);
    // add an extra glowing sound at the end part
    gr += growl2(time, 0.05)*0.5*block(time-124.,10.,4.,8.);
    // crank the gain to the max for the growling
    gr *= 100.;
    gain = 2.;
    gr *= sqrt(gain / (1369. + (gain - 1.) * gr * gr));
    mus += gro*gr*0.15;

    // dunking the music when the kick hit
    float mub = c01(beat*100.)*c01(exp(-beat*5.));
    mus *= 1.-mub;

    // kick
    float k = sin(beat*307.3)*cos(beat*100.)*exp(-beat*4.);
    k += sin(beat*200.)*exp(-beat*20.);
    mus += drum*max(-0.5,min(0.5,k));

    // snare
    mus += drum*snare(fract(time+0.5))*lead1;
    mus += drum*snare(fract(time/2.+0.25))*2.;
    mus += drum*snare(fract(time/4.+0.0525))*2.;

    // highhats
    float beat2 = min(fract(time*2.), fract(time*6.));
    mus += drum*(1.-block(time-64.,8.,.1,.1))*fract(sin(beat2*142.454)*485.523) * exp(-beat2*10.) * 0.1 * step(mod(time,16.),12.);

    // global fade-in and fade-out
    mus *= block(time-2.,141.,2.,1.);

    return clamp(mus,-1.,1.);
   
}