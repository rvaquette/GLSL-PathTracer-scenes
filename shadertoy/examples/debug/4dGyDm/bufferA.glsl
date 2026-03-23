/// Keyboard input

const int K_BACKSPACE = 8;
const int K_TAB = 9;
const int K_ENTER = 13;
const int K_SHIFT = 16;
const int K_CAPSLOCK = 20;
const int K_ESCAPE = 27;
const int K_SPACE = 32;
const int K_PGUP = 33;
const int K_PGDN = 34;
const int K_END = 35;
const int K_HOME = 36;
const int K_LEFT = 37;
const int K_UP = 38;
const int K_RIGHT = 39;
const int K_DOWN = 40;
const int K_INSERT = 45;
const int K_DELETE = 46;
const int K_0 = 48;
const int K_9 = 57;
const int K_A = 65;
const int K_Z = 90;

const int TABSIZE = 4;

// Key codes (-32) to ASCII
const int[] key_map = int[](
    32,  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  0,   0,   0,   0,   0,   0,
    0,   97,  98,  99,  100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
    112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   59,  61,  44,  45,  46,  47,
    96,  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   91,  92,  93,  39
);

const int[] shift_key_map = int[](
    32,  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    41,  33,  64,  35,  36,  37,  94,  38,  42,  40,  0,   0,   0,   0,   0,   0,
    0,   65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,
    80,  81,  82,  83,  84,  85,  86,  87,  88,  89,  90,  0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   58,  43,  60,  95,  62,  63,
    126, 0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   123, 124, 125, 34
);

bool key_down(int key) {
    return texelFetch(iChannel1, ivec2(key, 0), 0).r > 0.;
}

bool key_pressed(int key) {
    return texelFetch(iChannel1, ivec2(key, 1), 0).r > 0.;
}

bool key_toggled(int key) {
    return texelFetch(iChannel1, ivec2(key, 2), 0).r > 0.;
}

int get_key_press() {
    for (int k = 1; k < 256; k++) {
        if (key_pressed(k)) {
            return k;
        }
    }
    return 0;
}

int key_to_char(int key, bool shift, bool caps) {
    if (key < 32 || key >= 32 + key_map.length())
        return 0;
    if (key >= K_A && key <= K_Z)
        shift = shift ^^ caps;
    return shift ? shift_key_map[key-32] : key_map[key-32];
}

/// Memory

int mem_addr;
vec4 mem_cell;

vec4 read_mem(int addr) {
    return texelFetch(iChannel0, addr_to_coord(addr), 0);
}

void write_mem(int addr, vec4 val) {
    if (mem_addr == addr) mem_cell = val;
}

void clear_mem() {
    mem_cell = vec4(0);
}

// Initial text
const int[] START_TEXT = int[](
    72,101,108,108,111,44,32,87,111,114,108,100,33
);

void init_text() {
    int start_row = TEXT_DIM.y / 2;
    int start_col = (TEXT_DIM.x - START_TEXT.length()) / 2;
    int start_addr = TEXT_ADDR + start_row*TEXT_DIM.x + start_col;
    for (int i = 0; i < START_TEXT.length(); i++) {
        write_mem(start_addr + i, vec4(START_TEXT[i]));
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 coord = ivec2(fragCoord);
    mem_addr = coord_to_addr(coord);
    mem_cell = texelFetch(iChannel0, coord, 0);
    
    if (iFrame < 4) {
        init_text();
    }

    int cursor = int(read_mem(CURSOR_ADDR).r);

    bool shift = key_down(K_SHIFT);
    bool caps = key_toggled(K_CAPSLOCK);
    bool ins = key_toggled(K_INSERT);
    int key = get_key_press();

    int char = key_to_char(key, shift, caps);
    if (char > 0) {
        write_mem(TEXT_ADDR + cursor, vec4(char));
        if (!ins) cursor += 1;
    }
    else if (key == K_BACKSPACE) {
        if (cursor > 0) {
            cursor -= 1;
            write_mem(TEXT_ADDR + cursor, vec4(0));
        }
    }
    else if (key == K_DELETE) {
        write_mem(TEXT_ADDR + cursor, vec4(0));
    }
    else if (key == K_ENTER) {
        cursor = (cursor / TEXT_DIM.x + 1) * TEXT_DIM.x;
    }
    else if (key == K_LEFT) {
        cursor -= 1;
    }
    else if (key == K_RIGHT) {
        cursor += 1;
    }
    else if (key == K_UP) {
        cursor -= TEXT_DIM.x;
    }
    else if (key == K_DOWN) {
        cursor += TEXT_DIM.x;
    }
    else if (key == K_HOME) {
        cursor = cursor / TEXT_DIM.x * TEXT_DIM.x;
    }
    else if (key == K_END) {
        cursor = (cursor / TEXT_DIM.x + 1) * TEXT_DIM.x - 1;
    }
    else if (key == K_PGUP) {
        cursor = cursor % TEXT_DIM.x;
    }
    else if (key == K_PGDN) {
        cursor = cursor % TEXT_DIM.x + TEXT_SIZE - TEXT_DIM.x;
    }
    else if (key == K_TAB) {
        if (shift) {
            cursor = (cursor - 1) / TABSIZE * TABSIZE;
        } else {
            cursor = (cursor / TABSIZE + 1) * TABSIZE;
        }
    }
    else if (key == K_ESCAPE) {
        clear_mem();
        cursor = 0;
    }
    
    if (key != 0) {
        write_mem(PRESS_TIME_ADDR, vec4(iTime));
    }

    cursor = clamp(cursor, 0, TEXT_SIZE-1);
    write_mem(CURSOR_ADDR, vec4(cursor));

    fragColor = mem_cell;
}
