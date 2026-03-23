const float
    INF = 1./0.000001,
    OBJ_INF = -10.;

// array of intervals
const int iv_len = 2; // iva.length() length of array of intervals (memory allocation)

struct Interval {
  // distance, normal(gradient), material_index
  float t0; vec3 n0; float m0; // low_bound
  float t1; vec3 n1; float m1; // hight_bound
};

const Interval iEmpty = Interval(+INF, vec3(-1), OBJ_INF , -INF, vec3(+1), OBJ_INF);

bool IsEmptyInterval(in Interval[iv_len] iva, int iva_num) {
    return (iva_num == 0 && iva[0].t0 == +INF && iva[0].t1 == -INF);}

bool IsFullInterval(in Interval[iv_len] iva, int iva_num) {
    return (iva_num == 1 && iva[0].t0 == -INF && iva[0].t1 == +INF);}

void intersect( in  Interval[iv_len] iva, in  int iva_num
              , in  Interval[iv_len] ivb, in  int ivb_num
              , out Interval[iv_len] ivc, out int ivc_num) {
    // init
    int iva_id  = 0; // iva_id < iva_num <= iva.length()
    int ivb_id  = 0; // ivb_id < ivb_num <= ivb.length()
    int ivc_id  = 0;
    ivc_num = 0;     // ivc_num <= ivc.length() 
    
    // loop through all intervals
    while( iva_id < iva_num && ivb_id < ivb_num && ivc_id <= ivc.length() ) {
        // left bound
        //float t0 = max(iva[iva_id].t0, ivb[ivb_id].t0);        
        float t0; vec3 n0; float m0;
        if (iva[iva_id].t0 > ivb[ivb_id].t0) {
            t0 = iva[iva_id].t0;
            n0 = iva[iva_id].n0;
            m0 = iva[iva_id].m0;
        } else {
            t0 = ivb[ivb_id].t0;
            n0 = ivb[iva_id].n0;
            m0 = ivb[ivb_id].m0;
        }
         
        // right bound
        //float t1 = min(iva[iva_id].t1, ivb[ivb_id].t1);        
        float t1; vec3 n1; float m1;
        if (iva[iva_id].t1 < ivb[ivb_id].t1) {
            t1 = iva[iva_id].t1;
            n1 = iva[iva_id].n1;
            m1 = iva[iva_id].m1;
        } else {
            t1 = ivb[ivb_id].t1;
            n1 = ivb[iva_id].n1;
            m1 = ivb[ivb_id].m1;
        }        
               
        // check if interval is valid and write
        // c(t0 <= t1) { // closed interval [t0,t1]
        if (t0 < t1) { 
        // half open interval [t0,t1[ TEST:
            ivc[ivc_id].t0 = t0;
            ivc[ivc_id].n0 = n0;
            ivc[ivc_id].m0 = m0;
            
            ivc[ivc_id].t1 = t1;
            ivc[ivc_id].n1 = n1;
            ivc[ivc_id].m1 = m1;

            ivc_id +=1;
        }
        
        // check if i-th interval's right bound is
        // smaler increment iva_id else increment ivb_id
        if (iva[iva_id].t1 < ivb[ivb_id].t1)
            iva_id += 1;
        else
            ivb_id += 1;
    }
    // write size of output interval
    ivc_num = ivc_id;
}

void complement( in  Interval[iv_len] iva, in  int iva_num
               , in vec3 ray_d 
               , out Interval[iv_len] ivc, out int ivc_num) {
    // init
    int iva_id = 0;   // Read the first interval.
    int ivc_id = -1;  // Pre-increment befor write to intervalarray.
    float iva_pre_t1; // data previous interval far-bound
    vec3 iva_pre_n1;
    float iva_pre_m1;
    
    // case empty-interval [+INF,-INF] -> [-INF,..]
    if(iva_num == 0 && iva[0].t0 == +INF){
        ivc_id = -1;
        
        iva_pre_t1 = -INF;
        iva_pre_n1 = -ray_d;
        iva_pre_m1 = OBJ_INF;
    }else{
    // Add interval at -INF.
      if(iva[0].t0 == -INF){
        // case full-interval [-INF, +INF] -> empty-interval [+INF,-INF]
        if(iva_num == 1 && iva[0].t1 == +INF){
          ivc[0].t0 = +INF;
          ivc[0].n0 = +ray_d;
          ivc[0].m0 = OBJ_INF;
          
          ivc[0].t1 = -INF;       
          ivc[0].n1 = -ray_d; 
          ivc[0].m1 = OBJ_INF;
        }
        // case [-INF,iva[0].t1]
        ivc_id = -1;
        
        // Don't create an interval.      
      } else {
        //
        ivc_id = 0;
        
        // Create interval [t0,t1] -> [-INF, iva[0].t0].
        ivc[0].t0 = -INF;       
        ivc[0].n0 = -ray_d;
        ivc[0].m0 = OBJ_INF;
        
        ivc[0].t1 = iva[0].t0;
        ivc[0].n1 = -iva[0].n0;        
        ivc[0].m1 = iva[0].m0;        
      }
      // Save bound data.
      iva_pre_t1 = iva[0].t1;
      iva_pre_n1 = iva[0].n1;
      iva_pre_m1 = iva[0].m1;
    }
    
    // Add inbetweenintervals.
    for(int i=0; i<iva_num-1; i++){
        // preincrement
        iva_id += 1;
        ivc_id += 1;
        
        // Write interval.        
        ivc[ivc_id].t0 = iva_pre_t1;
        ivc[ivc_id].n0 = -iva_pre_n1;
        ivc[ivc_id].m0 = iva_pre_m1;
        
        ivc[ivc_id].t1 = iva[iva_id].t0;
        ivc[ivc_id].n1 = -iva[iva_id].n0;
        ivc[ivc_id].m1 = iva[iva_id].m0;
        
        // Save bound data.
        iva_pre_t1 = iva[iva_id].t1;
        iva_pre_n1 = iva[iva_id].n1;
        iva_pre_m1 = iva[iva_id].m1;        
    }
    
    // Add interval at +INF.
    if(iva_pre_t1 != +INF) {
        // preincrement
        ivc_id += 1;
        
        // write interval
        ivc[ivc_id].t0 = iva_pre_t1;
        ivc[ivc_id].n0 = -iva_pre_n1;
        ivc[ivc_id].m0 = iva_pre_m1;        
        
        ivc[ivc_id].t1 = +INF;        
        ivc[ivc_id].n1 = ray_d;
        ivc[ivc_id].m1 = OBJ_INF;       
   }
      
    ivc_num = ivc_id + 1;
}

void substract( in  Interval[iv_len] iva, in  int iva_num
              , in  Interval[iv_len] ivb, in  int ivb_num
              , in vec3 ray_d
              , out Interval[iv_len] ivc, out int ivc_num) {
    Interval[iv_len] it; int it_num;          
    complement(ivb ,ivb_num, ray_d, it ,it_num);
    intersect (iva ,iva_num ,it ,it_num ,ivc ,ivc_num);             
}

// https://iquilezles.org/articles/boxfunctions
int iBox( in vec3 ro, in vec3 rd, in vec3 siz, in float mat , out Interval iv) 
{
    vec3 m = 1.0/rd;
    vec3 k = vec3(rd.x>=0.0?siz.x:-siz.x, rd.y>=0.0?siz.y:-siz.y, rd.z>=0.0?siz.z:-siz.z);
    vec3 t1 = (-ro - k)*m;
    vec3 t2 = (-ro + k)*m;
    float tN = max(max(t1.x,t1.y),t1.z);
    float tF = min(min(t2.x,t2.y),t2.z);
	if( tN>tF || tF<0.0 ) {    
        iv = iEmpty;
        return 0;
    } else {
    iv = Interval( tN, -sign(rd)*step(vec3(tN),t1), mat,
                   tF, -sign(rd)*step(t2,vec3(tF)), mat);
    return 1;
    }
}

// just solve for t, |ro+t*d|² = r²
int iSphere( in vec3 ro, in vec3 rd, in float r , in float mat, out Interval iv)
{   
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r*r;
    float h = b*b - c;
    if( h<0.0 )
    {
        iv = iEmpty;
    } else {
        h = sqrt( h );
        float ta = -b-h; vec3 na = (ro+ta*rd)/r;
        float tb = -b+h; vec3 nb = -(ro+tb*rd)/r;
        iv = Interval(ta, na, mat, tb, nb, mat);
        return 1;
    }
}

// just solve for t, < ro+t*d, nor > - k = 0
int iPlane( in vec3 ro, in vec3 rd, in vec4 pla, in float mat , out Interval iv)
{
    // TODO: Redo the math. Refactor the code.
    vec3  n = pla.xyz;
    float h = pla.w;

    float k1 = dot(ro, n);
    float k2 = dot(rd, n);
    float t = (h - k1) / k2;

    if ( t < 0.) {
        if (k2 < 0.)
        {
            iv = Interval(0.0, n, mat, INF, -n, mat);
            return 1;
        }    
        else
        {
            iv = iEmpty;
            return 0;
        }
    }
    else {
        if (k2 < 0.)
        {
            
            iv = Interval(t, n, mat, INF, -n, mat);
            return 1;
        }
        else
        {
            iv = Interval(-INF, n, mat, t, -n, mat);
            return 1;
        }
    }
}

// ray
struct Ray
{
    vec3 o;
    vec3 d;
};
    
Ray transform( Ray r, mat4x4 m )
{
	return Ray( (m*vec4(r.o,1.0)).xyz, (m*vec4(r.d,0.0)).xyz );
}

// complex transformations
vec2 cmul(vec2 za,vec2 zb){
    return za*mat2(zb.x,-zb.y,zb.yx);}

// 3d transformations
const float
    PI = abs(atan(0., -1.));
const float
    PI_2 = PI/2.;

mat4 rotationAxisAngle( vec3 v, vec2 ei_a )
{
    float c = ei_a.x;
    float s = ei_a.y;
    float ic = 1.0 - c;

    return mat4
    ( v.x*v.x*ic + c,     v.y*v.x*ic - s*v.z, v.z*v.x*ic + s*v.y, 0.0,
      v.x*v.y*ic + s*v.z, v.y*v.y*ic + c,     v.z*v.y*ic - s*v.x, 0.0,
      v.x*v.z*ic - s*v.y, v.y*v.z*ic + s*v.x, v.z*v.z*ic + c,     0.0,
	  0.0,                0.0,                0.0,                1.0 );
}

mat4 translate( vec3 t )
{
    return mat4
    (1.,0.,0.,0.
    ,0.,1.,0.,0.
	,0.,0.,1.,0.
	,t       ,1.);
}

// colorspace
vec3 h2rgb(float h)
{
    vec3 rgb = vec3(0.);
    rgb = vec3(clamp( abs(mod(h*6.0+vec3(0.,4.,2.),6.)-3.)-1., 0., 1. ));
    rgb = rgb*rgb*(3.-2.*rgb); // cuivbc smoothing
    return rgb;
}

// srgb <--> rgb (linear)
vec3 srgb2rgb(vec3 col)
{
    return pow(col, vec3(2.2));
}

vec3 rgb2srgb(vec3 col)
{
    return pow(col, vec3(1./2.2));
}
