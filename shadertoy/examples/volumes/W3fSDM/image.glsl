// Kali's 'Extruder' - https://www.shadertoy.com/view/dtdSzM
// with my galaxy ripple - https://www.shadertoy.com/view/fsSSzw
#define  steps_multiplier .01
#define  extrusion  .5
#define  height_scale  .2
#define  rotationXY  iTime*.1
#define  rotationXZ  0.
#define  rotationYZ  -.3
#define  cameraX  0.
#define  cameraY  .3
#define  cameraZ  -1.2
#define  fov  .8
#define  lightdirX  1.
#define  lightdirY  1.
#define  lightdirZ  1.
#define  ambient  .5
#define  diffuse  1.
#define  invert  false
#define  distortX  0.
#define  distortY  0.
#define  distortZ  0.
#define  distort_scale  0.
#define  fudge_factor  .5

#define resolution iResolution

float maxdist=50., det=.001;
vec3 objcol;

mat2 rot(float a) {
    float s=sin(a), c=cos(a);
    return mat2(c,s,-s,c);
}

float box(vec3 p, vec3 c) {
    return length(max(vec3(0.),abs(p)-c));
}

float de(vec3 p) {
  p.xy*=rot(p.z*distortZ*5.);
  p.xz*=rot(-p.y*distortY);
  p.yz*=rot(p.x*distortX);
  float st=steps_multiplier*.3;
  float extrude=extrusion*5.;
  p.z+=extrude*.5;
  p.z+=.5;
  vec3 p2=p;
  p2.x*=3./5.;
  if(!invert) objcol=texture(iChannel0,p2.xy*.15*(1.+p.z*3.*(distort_scale))+.5).rgb;
  else objcol=1.-texture(iChannel0,p2.xy*.15*(1.+p.z*3.*(distort_scale))+.5).rgb;
  float l=length(objcol)*.5*height_scale*2.;
  float z=p.z;
  p.z=mod(p.z,st)-st*.5;
  float d=box(p, vec3(5.,3.,.01));
  d=max(d,abs(z)-extrude*.5);
  d+=smoothstep(1.-(z+extrude*.5)/extrude,0.,l)*.05;
  return d*fudge_factor;
  }

vec3 normal(vec3 p) {
    vec2 e=vec2(0.,det);
    return normalize(vec3(de(p+e.yxx),de(p+e.xyx),de(p+e.xxy))-de(p));
}

vec3 march(vec3 from, vec3 dir) {
    vec3 p, col=vec3(0.);
    float d, td=0.;
    for (int i=0; i<2000; i++) {
        p=from+dir*td;
        d=de(p);
        if (d<det || td>maxdist) break;
        td+=d;
    }
    if (d<det) {
        p-=dir*det;
        vec3 n=normal(p);
        vec3 ldir=normalize(vec3(lightdirX,lightdirY,lightdirZ));
        col+=objcol*max(ambient,max(0.,dot(ldir,n))*diffuse);
    }
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = gl_FragCoord.xy/resolution.xy-.5;
    uv.x*=resolution.x/resolution.y;
    vec3 from=vec3(cameraX*4.,cameraY*4.,cameraZ*10.);
     vec3 dir=normalize(vec3(uv,fov*3.));
    from.xz*=rot(rotationXZ*3.1416);
    dir.xz*=rot(rotationXZ*3.1416);
    from.yz*=rot(-rotationYZ*3.1416);
    dir.yz*=rot(-rotationYZ*3.1416);
    from.xy*=rot(rotationXY*3.1416);
    dir.xy*=rot(rotationXY*3.1416);
    vec3 col = march(from,dir);
    fragColor = vec4(col,1.0);
}


