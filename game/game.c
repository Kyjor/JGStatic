#include <stdio.h>
#include "../jg_static.h"
//gcc -o game game.c   -L/home/kyjor/Documents/Projects/Julia/JGStatic/lib_desktop   -Wl,-rpath,/home/kyjor/Documents/Projects/Julia/JGStatic/lib_desktop   -ljg_static   -lSDL2_image -lSDL2_mixer -lSDL2   -rdynamic

int main(void) {
    int res = init();
    printf("Init %d\n", res);

    open_window("Test");
    printf("Window opened\n");
    printf("Renderer init\n");

    int exit = 0;
    while(exit == 0) {
        render_clear();
        exit = poll_events();

        render_present();
        delay();
    }

    printf("Window opened");

    return 0;
}

void game_update() {
    printf("update func\n");
}
