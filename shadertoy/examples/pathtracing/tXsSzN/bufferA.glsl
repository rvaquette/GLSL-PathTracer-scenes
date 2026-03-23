#define DEBUG_SDF 0
#define DEBUG_SINGLE_FRAME 0

const int samples = 64;
const int walk_iterations = 10;

// https://www.shadertoy.com/view/4llXD7
float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

float sdCutDisk( in vec2 p, in float r, in float h )
{
    float w = sqrt(r*r-h*h); // constant for any given shape
    p.x = abs(p.x);
    float s = max( (h-r)*p.x*p.x+w*w*(h+r-2.0*p.y), h*p.x-w*p.y );
    return (s<0.0) ? length(p)-r :
           (p.x<w) ? h - p.y     :
                     length(p-vec2(w,h));
}

float sdArc( in vec2 p, in vec2 sc, in float ra, float rb )
{
    // sc is the sin/cos of the arc's aperture
    p.x = abs(p.x);
    return ((sc.y*p.x>sc.x*p.y) ? length(p-sc*ra) : 
                                  abs(length(p)-ra)) - rb;
}

vec3 colormap(in float d)
{
  vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
	col *= 1.0 - exp(-6.0*abs(d));
	col *= 0.8 + 0.2*cos(150.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );
    return col;
}

float get_t()
{
  return 20.*fract(float(iFrame)*0.005);
}


float dist(in vec2 xy)
{
 // return -sdCircle( xy , 0.5);
  //return -min(
  //  sdCircle( xy , 0.25),
  //  sdBox(xy,vec2(0.5,0.125)));
  float d = sdCircle( xy+vec2(0.,0.02) , 0.4);
  
  float t = get_t();
  
  if(int(t)>3)
  {
    d = min(min(d,
      max(sdCutDisk( xy , 0.48, 0.0),-sdCutDisk( xy , 0.42, 0.0))),
      sdBox(xy+vec2(0.,-0.05),vec2(0.5,0.125)));
  }
  float x = xy.x;
  switch(int(t))
  {
    default:
    case 5:
      float s = min(t-5.0,1.);
      float th = mix(1.570796,0.2,3.*s*s-2.*s*s*s);
      d = max(d, -sdArc( vec2(xy.x,-xy.y-0.07), vec2(cos(th),sin(th)), 0.2, 0.02));
    case 4:
    case 3:
      x = abs(x);
    case 2:
      d = max(d, -sdCircle( vec2( x ,xy.y)-vec2(0.125,0.12) , 0.06));
    case 1:
    case 0: break;
  }
  return -d;
  /*return -max(max(d, 
      -sdCircle( vec2(abs(xy.x),xy.y)-vec2(0.18,0.17) , 0.07)
      ),
      -sdArc( vec2(xy.x,-xy.y-0.07), vec2(cos(0.2),sin(0.2)), 0.2, 0.02)
      );*/
}
// from https://www.shadertoy.com/view/wdffWj
// --------------------------------------
// oldschool rand() from Visual Studio
// --------------------------------------
int  seed = 1;
void srand(int s ) {
    seed = s;
}
int randi(void) {
    seed = seed * 0x343fd + 0x269ec3;
    return (seed >> 16) & 32767;
}
float rand(void) {
    return float(randi())/32767.0;
}
// --------------------------------------

// --------------------------------------
// hash to initialize the random sequence (copied from Hugo Elias)
// --------------------------------------
int hash( int n ) {
	n = (n << 13) ^ n;
    return n * (n * n * 15731 + 789221) + 1376312589;
}

// --------------------------------------

vec2 randomOnCircle( void ) {
    float theta = 6.28318530 * rand();
    return vec2(cos(theta), sin(theta));
}

float G(in float r, in float R)
{
  return log(R/r)/6.28318530;
}

vec3 wos(in vec2 xy0)
{
  const float epsilon = 0.0001;
  float u = 0.0;
  float R1;
  vec2 w1;
  float r_y1;
  vec2 xy = xy0;
  // Puffiness factor (4.0 for circle → sphere)
  const float f_y = 4.0;
  
  for(int i = 0;i<walk_iterations;i++)
  {
    float R = dist(xy);
    if( R < epsilon && i > 0) break;
    //float h = rand()+0.0001; 
    //u += -R*R*log(h);
    //h = exp(-1);
    u += R*R;
    vec2 w = randomOnCircle();
    xy += R*w;
    if(i == 0)
    {
      R1 = R;
      w1 = w;
      //r_y1 = R*sqrt(h);
    }
  }
  u *= 0.25*f_y;

  //vec2 v1 = (xy1-xy0)/R1;
  //float r_y = r_y1;
  //float theta_y = rand()*6.28318530;
  //vec2 ymxy = r_y*vec2(cos(theta_y),sin(theta_y));
  //vec2 dG_y = ymxy/6.28318530*(1.0/r_y/r_y - 1./R1/R1);
  //vec2 g = 2./R1*u*v1 + R1*R1*3.14159265*f_y*dG_y;
  // For uniform f, I claim the expected value of the 
  // ∇ f-contribution is the 0 vector.
  vec2 g = 2.*u*w1/R1;
  return vec3(u,g);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
  // Normalized pixel coordinates (from 0 to 1)
  vec2 xy = fragCoord/iResolution.y - vec2(0.5*iResolution.x/iResolution.y,0.5);
  ivec2 q = ivec2(fragCoord);
  srand(hash(q.x + hash(q.y + hash(iFrame))));
  float R = dist(xy);
  vec4 fColor;
#if DEBUG_SDF
  fColor = vec4(colormap(2.0*r),1.0);
#else

  vec3 Kd = vec3(0.95,0.85,0.15);
  vec3 Ks = vec3(1.,1.,1.);
  vec3 Kf = 0.4*Ks;
  vec3 Ka = 0.1*Kd;
  if(R<0.0)
  {
    //fColor = vec4(colormap(2.0*R),1.0);
    fColor = vec4(Ka,1.0);
  }else
  {
    vec3 u_g = vec3(0.0,0.,0.);
    for(int i = 0;i<samples;i++)
    {
      u_g += wos(xy);
    }
    u_g /= float(samples);
    float z = sqrt(u_g.x);
    vec3 n = normalize(vec3(-u_g.yz*0.5/z,1));
    const int nlights = 2;
    vec3 lights[nlights];
    lights[0] = normalize(vec3(1.5,2.,1.));
    lights[1] = normalize(vec3(-1.5,2.,1.));
    vec3 Kl[nlights];
    Kl[0] = vec3(1.,0.6,0.6);
    Kl[1] = vec3(.6,0.6,1.0);
    vec3 color = vec3(0.,0.,0.);
    vec3 p = vec3(xy,z);
    vec3 c = vec3(0.,0.,5.);
    vec3 v = normalize(c-p);
    for(int i = 0;i<2;i++)
    {
      vec3 l = lights[i];
      float d = max(dot(n,l),0.);
      vec3 h = normalize(l+v);
      float s = pow(max(dot(n,h),0.),100.);
      color += Kl[i]*(Kd*d+Ks*s);
    }
    float NE = dot(n,v);
    float f = pow(max(sqrt(1. - NE*NE),0.0), 50.);
    color += Kf*f+Ka;
    
    fColor = vec4(color,1.0);
    //fColor = vec4(n*0.5+0.5,1.0);
    //vec3 xyz = vec3(xy,z);
    //fColor = vec4(2.0*z*vec3(1.0,0.0,0.0),1.0);
    //fColor = vec4(0.5+sign(u)*vec3(0.5,0.5,0.5),1.0);
  }
#endif
#if DEBUG_SINGLE_FRAME
  fragColor = fColor;
#else
  vec4 data = texelFetch(iChannel0, ivec2(fragCoord), 0);
  if(get_t() < 0.3)
  {
    fragColor = fColor;
  }else if( int(get_t()) < 6)
  {
    // A little bit of motion blur to reduce aliasing.
    fragColor = vec4(mix(data.rgb/data.w,fColor.rgb, 0.3),1.0);
  }else
  {
    // when the animation is static, just accumate (main shader takes average)
    fragColor = data + fColor;
  }
#endif
}
