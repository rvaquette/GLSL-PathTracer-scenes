///////// Bloom by
// source: https://www.shadertoy.com/view/lsXGWn  by use Seven
//

const float blurSize = 1.0/512.0;
const float intensity = 0.35;
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   vec4 sum = vec4(0);
   vec2 texcoord = fragCoord.xy/iResolution.xy;
   int j;
   int i;

   //thank you! http://www.gamerendering.com/2008/10/11/gaussian-blur-filter-shader/ for the 
   //blur tutorial
   // blur in y (vertical)
   // take nine samples, with the distance blurSize between them
   sum += texture(iChannel0, vec2(texcoord.x - 4.0*blurSize, texcoord.y)) * 0.05;
   sum += texture(iChannel0, vec2(texcoord.x - 3.0*blurSize, texcoord.y)) * 0.09;
   sum += texture(iChannel0, vec2(texcoord.x - 2.0*blurSize, texcoord.y)) * 0.12;
   sum += texture(iChannel0, vec2(texcoord.x - blurSize, texcoord.y)) * 0.15;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y)) * 0.16;
   sum += texture(iChannel0, vec2(texcoord.x + blurSize, texcoord.y)) * 0.15;
   sum += texture(iChannel0, vec2(texcoord.x + 2.0*blurSize, texcoord.y)) * 0.12;
   sum += texture(iChannel0, vec2(texcoord.x + 3.0*blurSize, texcoord.y)) * 0.09;
   sum += texture(iChannel0, vec2(texcoord.x + 4.0*blurSize, texcoord.y)) * 0.05;
	
	// blur in y (vertical)
   // take nine samples, with the distance blurSize between them
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y - 4.0*blurSize)) * 0.05;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y - 3.0*blurSize)) * 0.09;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y - 2.0*blurSize)) * 0.12;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y - blurSize)) * 0.15;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y)) * 0.16;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y + blurSize)) * 0.15;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y + 2.0*blurSize)) * 0.12;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y + 3.0*blurSize)) * 0.09;
   sum += texture(iChannel0, vec2(texcoord.x, texcoord.y + 4.0*blurSize)) * 0.05;

 		vec4 col ;
    	texcoord.xy*=1.005;texcoord.x-=.005;texcoord.y-=.005;
    if(texture(iChannel0,texcoord).w >0.5) col =sum + texture(iChannel0, texcoord);
    else col = sum*.2+ texture(iChannel0, texcoord);
	   fragColor = col;
}
