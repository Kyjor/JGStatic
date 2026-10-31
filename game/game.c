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

void game_load() {
    printf("load func\n");
}

void game_update() {

}

void game_key_pressed(int key) {
    printf("key pressed: %d", key);
    printf("\n");
}

void game_draw() {

}

void game_key_released(int key) {
    printf("key released: %d", key);
    printf("\n");
}


void game_shutdown() {
    printf("shutdown func\n");
}
