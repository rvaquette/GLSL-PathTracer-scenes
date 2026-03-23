const int MEM_WIDTH = 64;

const int CURSOR_ADDR = 0;
const int PRESS_TIME_ADDR = 1;
const int TEXT_ADDR = 2;

const ivec2 TEXT_DIM = ivec2(40, 15);
const int TEXT_SIZE = TEXT_DIM.x * TEXT_DIM.y;
const ivec2 CHAR_DIM = ivec2(4, 6);
const ivec2 SCREEN_DIM = TEXT_DIM * CHAR_DIM;

int coord_to_addr(ivec2 coord) {
    return coord.x < MEM_WIDTH ? coord.x + MEM_WIDTH*coord.y : -1;
}

ivec2 addr_to_coord(int id) {
    return ivec2(id % MEM_WIDTH, id / MEM_WIDTH);
}
