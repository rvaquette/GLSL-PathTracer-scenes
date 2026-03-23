
void mainImage( out vec4 fragColor, in vec2 fragCoord ){
  vec4 data = texelFetch(iChannel0, ivec2(fragCoord), 0);
  // take average
  fragColor = vec4(data.xyz / data.w, 1.0 );
}


