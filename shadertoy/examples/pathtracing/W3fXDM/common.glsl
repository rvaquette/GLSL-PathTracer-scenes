
#define NOHIT 1e10

struct its
{
	float t;
	vec3 n;    //normal 
	
};

const its  NO_its=its(NOHIT,vec3(0));
struct span
{
	its n;
	its f;
};
/*----------------------------------
REFERENCE TABLE
(span 1= AB, span 2 = CD)

-------Union---Inter----Sub--
ABCD | AB, CD |  -   | AB
ACBD | AD     | CB   | AC
ACDB | AB     | CD   | AC, DB
CABD | CD     | AB   | -
CADB | CB     | AD   | DB
CDAB | CD, AB | -    | AB

if result is a double span: 
use first span if in front of the viewer, 
otherwise use second span
------------------------------------*/

span Inter(span a, span b)
{
   bvec4 cp = bvec4(a.n.t<b.n.t,a.n.t<b.f.t,a.f.t<b.n.t,a.f.t<b.f.t); 
   if(cp.x && cp.z) return span(NO_its,NO_its);
   else if(cp.x && !cp.z && cp.w)  return span(b.n,a.f);
   else if(cp.x && !cp.z && !cp.w) return b;
   else if(!cp.x && cp.y &&  cp.w) return a;
   else if(!cp.x && cp.y &&  !cp.w) return span(a.n,b.f);
   else return span(NO_its,NO_its);
}

span Sub(span a, span b)
{
   bvec4 cp = bvec4(a.n.t<b.n.t,a.n.t<b.f.t,a.f.t<b.n.t,a.f.t<b.f.t); 
   
   if     (cp.x && cp.z) return a;
   else if(cp.x && !cp.z && cp.w)  return span(a.n,b.n);
   else if(cp.x && !cp.z && !cp.w && b.n.t>0.) return span(a.n,b.n); 
   else if(cp.x && !cp.z && !cp.w && b.n.t<0.) return span(b.f,a.f); //+ secondary span =  span(b.f,a.f)
   else if(!cp.x && cp.y && cp.w) return span(NO_its,NO_its);
   else if(!cp.x && cp.y && !cp.w) return span(b.f,a.f);
   else return a;
   
}

// useful if transparent 
span Union(span a, span b)
{

   bvec4 cp = bvec4(a.n.t<b.n.t,a.n.t<b.f.t,a.f.t<b.n.t,a.f.t<b.f.t); 
   if(b.n.t==NOHIT) return a;
   else if(a.n.t==NOHIT) return b;    
   else if     (cp.x  && cp.z  && a.f.t>0.) return a;
   else if(cp.x  && cp.z  && a.f.t<0.) return b;
   else if(cp.x  && !cp.z && cp.w) return span(a.n,b.f);
   else if(cp.x  && !cp.z && !cp.w) return a;
   else if(!cp.x && cp.y  && cp.w) return b;
   else if(!cp.x && cp.y  && !cp.w) return span(b.n,a.f);
   else if(!cp.x && !cp.y  && a.f.t>0.) return b;
   else /*if(!cp.x && !cp.y  && a.f.t<0.) */ return a;   
}


//-----------Intersection functions--(based on Iq)------------------
span iSphere( in vec3 ro, in vec3 rd, float ra )
{
    vec3 oc = ro ;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - ra*ra;
    float h = b*b - c;
    if( h<0. ) return span(NO_its,NO_its); // no intersection
    h = sqrt( h );
    vec3 oNor =normalize(ro-(b+h)*rd); 
    vec3 fNor= normalize(ro-(b-h)*rd); 
    return span(its(-b-h,oNor) , its(-b+h,-fNor));
}

span iBox( in vec3 ro, in vec3 rd, vec3 boxSize) 
{
    vec3 m = 1./rd; 
    vec3 n = m*ro;   
    vec3 k = abs(m)*boxSize;

    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
    if( tN>tF ) return span(NO_its,NO_its); // no intersection
    vec3 oNor = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz); 
    vec3  fNor=- sign(rd)*step(t2.xyz,t2.yzx)*step(t2.xyz,t2.zxy); 
    return  span(its(tN,oNor) , its(tF,fNor));
}

span iRBox( in vec3 ro, in vec3 rd, vec3 boxSize,mat3 rot  ) {
	mat3 txx = inverse( rot );   
    span s= iBox(txx*ro,txx*rd,boxSize);
    s.n.n=(rot*s.n.n).xyz;
    s.f.n=(rot*s.f.n).xyz;    
    return s;
}


//  plane with thickness h
span iPlane( in vec3 ro, in vec3 rd, in vec3 n ,float h)
{
    float d1= -dot(ro,n)/dot(rd,n),   d2= -(dot(ro-h*n,n))/dot(rd,n);
    vec3  u = normalize(cross(n,vec3(0,0,1))), v = normalize(cross(u,n) );
    vec3 oNor=n;
    if(d1<d2) return span(its(d1,-oNor),its(d2,oNor));
    return span(its(d2,oNor),its(d1,-oNor));
}


span iCylinder( in vec3 ro, in vec3 rd, in vec3 cb, in vec3 ca, float cr )
{
    vec3  oc = ro - cb;
    float card = dot(ca,rd);
    float caoc = dot(ca,oc);
    float a = 1.0 - card*card;
    float b = dot( oc, rd) - caoc*card;
    float c = dot( oc, oc) - caoc*caoc - cr*cr;
    float h = b*b - a*c;
    if( h<0.0 ) return span(NO_its,NO_its); //no intersection
    h = sqrt(h);
    vec2 t =vec2(-b-h,-b+h)/a;
    vec2 d= vec2(dot(oc +t.x*rd,ca) ,dot(oc +t.y*rd,ca) );
    vec3 nN=normalize( oc +t.x*rd -d.x*ca),nF=normalize( oc +t.y*rd -d.y*ca);
    its iN= its( t.x, nN); //todo uv
    its iF= its( t.y, nF);
    return  span(iN , iF );   
}
//---------mixed functions--------------------------

struct Hit{   
    float d;
    vec3 n;
    int id;
};


Hit nearestHit( Hit a, Hit b)
{   
   if(a.d<b.d) return a;
   else return b;
}



//------------------------------------
Hit getHit(span s, int mat){
    
    if(s.f.t < 0.  ) return Hit(NOHIT,vec3(0),0);    
    its ix = s.n;
    if(s.n.t<0.) ix=s.f;
    return Hit( ix.t,ix.n,mat);
}

// Iq 


mat3 rotationAxisAngle( vec3 v, float angle )
{
    float s = sin( angle );
    float c = cos( angle );
    float ic = 1.0 - c;

    return mat3( v.x*v.x*ic + c,     v.y*v.x*ic - s*v.z, v.z*v.x*ic + s*v.y,
                 v.x*v.y*ic + s*v.z, v.y*v.y*ic + c,     v.z*v.y*ic - s*v.x,
                 v.x*v.z*ic - s*v.y, v.y*v.z*ic + s*v.x, v.z*v.z*ic + c);
}


