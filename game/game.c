#include <stdio.h>
#include "../jg_static.h"
//gcc -o game game.c   -L/home/kyjor/Documents/Projects/Julia/JGStatic/lib_desktop   -Wl,-rpath,/home/kyjor/Documents/Projects/Julia/JGStatic/lib_desktop   -ljg_static   -lSDL2_image -lSDL2_mixer -lSDL2   -rdynamic

// gcc -o game game.c \
//   -L/Users/kyleconel/Documents/Projects/JGStatic/lib_desktop \
//   -Wl,-rpath,/Users/kyleconel/Documents/Projects/JGStatic/lib_desktop \
//   -L/opt/homebrew/lib \
//   -Wl,-rpath,/opt/homebrew/lib \
//   -ljg_static -lSDL2_image -lSDL2_mixer -lSDL2 \
//   -framework Cocoa \
//   -rdynamic
int main(void) {
    game_loop();

    return 0;
}

void game_configure() {
    printf("configure func\n");
}

void game_load() {
    printf("load func\n");
}

static int key_left;
static int key_right;
static int key_up;
static int key_down;

void game_update() {
    double dx = 0.0;
    double dy = 0.0;
    if (key_left) dx -= 0.1;
    if (key_right) dx += 0.1;
    if (key_up) dy -= 0.1;
    if (key_down) dy += 0.1;
    //camera_move(dx, dy);
    camera_set_position(get_entity_position_x(2) - 10 + dx, get_entity_position_y(2) - 8 + dy);
    entity_move(2, dx, dy);
}

void game_key_pressed(int key) {
    if (key == 1073741904) key_left = 1;
    else if (key == 1073741903) key_right = 1;
    else if (key == 1073741906) key_up = 1;
    else if (key == 1073741905) key_down = 1;
}

void game_draw() {

}

void game_key_released(int key) {
    if (key == 1073741904) key_left = 0;
    else if (key == 1073741903) key_right = 0;
    else if (key == 1073741906) key_up = 0;
    else if (key == 1073741905) key_down = 0;
}


void game_shutdown() {
    printf("shutdown func\n");
}
