const vec3 COLOR = vec3(.5, 1, 1);

// Note these are octal literals
const int[] font = int[](
    //           !       "       #       $       %       &       '
    000000, 020222, 000055, 067676, 036736, 041241, 065252, 000022,
    //   (       )       *       +       ,       -       .       /
    021112, 024442, 000525, 002720, 012000, 000700, 020000, 011244,
    //   0       1       2       3       4       5       6       7
    025552, 022232, 071243, 034243, 044755, 034317, 025716, 022447,
    //   8       9       :       ;       <       =       >       ?
    025252, 034752, 002020, 012020, 042124, 007070, 012421, 020243,
    //   @       A       B       C       D       E       F       G
    025643, 055752, 035353, 061116, 035553, 071317, 011317, 065516,
    //   H       I       J       K       L       M       N       O
    055755, 072227, 025446, 055355, 071111, 055575, 055553, 075557,
    //   P       Q       R       S       T       U       V       W
    011353, 065552, 055353, 034216, 022227, 075555, 025555, 057555,
    //   X       Y       Z       [       \       ]       ^       _
    055255, 022255, 071247, 031113, 044211, 064446, 000052, 070000,
    //   `       a       b       c       d       e       f       g
    000021, 065600, 035311, 061600, 065644, 061720, 022724, 034656,
    //   h       i       j       k       l       m       n       o
    055311, 022202, 012202, 053511, 022223, 057700, 055300, 075700,
    //   p       q       r       s       t       u       v       w
    013530, 046560, 011300, 032130, 042272, 065500, 025500, 077500,
    //   x       y       z       {       |       }       ~
    052500, 034650, 031230, 062326, 022222, 032623, 000630, 000000
);

vec4 read_mem(int addr) {
    return texelFetch(iChannel0, addr_to_coord(addr), 0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;
    uv.y = 1. - uv.y;
    ivec2 px = ivec2(uv * vec2(SCREEN_DIM));
    ivec2 cell = px / CHAR_DIM;
    ivec2 cp = px % CHAR_DIM;

    int ind = cell.x + cell.y * 40;
    int char = int(read_mem(TEXT_ADDR + ind).r);
    int cursor = int(read_mem(CURSOR_ADDR).r);
    float press_time = read_mem(PRESS_TIME_ADDR).r;

    int bits = font[clamp(char-32, 0, font.length()-1)];
    bool v = cp.y < 5 && cp.x < 3 && bool(bits >> (3*cp.y + cp.x) & 1);
    if (ind == cursor) {
        bool blink = fract((iTime - press_time) / 1.) < .5;
        v = v || (cp.y == 5 && blink);
    }

    vec3 col = float(v) * COLOR;

    // Display memory contents
    //acol = texture(iChannel0, uv/8.).rgb/256.;

    // Output to screen
    fragColor = vec4(col, 1.0);
}
