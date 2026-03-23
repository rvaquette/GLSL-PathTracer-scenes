// Fork of "Scattered Rays" by wyatt. https://shadertoy.com/view/Xfjczc
// 2024-08-04 11:57:33

Main {

    Q = .6*B(U)/float(iFrame);
    if (A(U).x==0.)Q += .2*sin(0.+2.*U.y/R.y+U.x/R.x*vec4(1,2,3,4));
}
