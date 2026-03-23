// CC0: Trailing the Twinkling Tunnelwisp
//  A bit of Saturday coding (also Norway’s Constitution Day).
//  Some artifacts remain, but it’s good enough for my standards.

//  Music by Pestis created for Cassini's Cosmic Conclusion
//   https://demozoo.org/productions/367582/

// For those that like it as a twigl: https://twigl.app?ol=true&ss=-OQdLCgeO21o1boSdWJO

// Optimized on bytes (hopefully I didn't butcher it)
vec2 mainSound(int s,float t) {
  // FYI: This code is intended to be as small as possible. 
  //  As a consequence even harder to read than usual.

  // Accumulator for the final sound output
  vec2 r;
  for(float i,j;++i<4.;)
  for(j=0.;++j<5.;){
    // Variable a must be declared inside the loop body, not in the for loop declaration
    //  It should work to group all variables in the for loop but for some reason it doesn't.
    // a controls the overall progression of the sound, b is the fractional part for modulation
    float a=t*j/32.+i/3.,b=fract(a),c;

    // n is the base frequency vector, m will accumulate harmonics
    // Create stereo effect with slight offset
    vec2 m,n=vec2(t,t+3.)+t/j;

    // Create rich harmonic content by summing sine waves with increasing frequencies
    // Gradually increasing frequency multiplier
    for(c=3.;c<4.1;n+=c*=1.02)
      // Sum harmonics with amplitude falloff (1/c)
      m+=sin(n*c)/c;

    // Only contribute sound during the first part of the composition
    if(a<9.)
      // Complex waveform combining multiple modulations:
      // Carrier wave
      r+=sin(
          // Add accumulated harmonics
          m
          // Slow modulation based on time
          +4.*sin(t/j/47.)
          // Modulator wave
          *sin(
              // Exponential pitch shifting
              exp2(mod(a-b,3.)/6.+8.5)
              // Time-varying phase
              *t*j*i+i+j
          )
      )
      // Amplitude envelope for attack/decay
      *exp2(-b*12.-1./b+6.-(i+j)/3.);
  }
  // Return the final stereo waveform
  return r;
}