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
#ifndef JG_NO_MAIN
int main(void) {
    game_loop();

    return 0;
}
#endif

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
static double gravity = 9.81;
static double jump_force = 5.5;
static int jump_cooldown = 0;
static int jump_was_down = 0;

void game_update(double dt) {
    (void)dt;
    double vx = 0.0;
    double speed = 6.5;
    if (key_left) vx -= speed;
    if (key_right) vx += speed;
    set_entity_velocity_x(2, vx);
    if (key_up && !jump_was_down && entity_on_ground(2))
    {
        set_entity_velocity_y(2, -jump_force);
    }
    
    jump_was_down = key_up;

}

void game_late_update(void) {
    //camera_move(dx, dy);
    camera_set_position(get_entity_position_x(2) - 10, get_entity_position_y(2) - 8);
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

int game_wants_3d(void) {
    return 0;
}

double game_model_yaw(void) {
    return 0.0;
}

double game_cam_x(void) { return 0.0; }
double game_cam_y(void) { return 0.0; }
double game_cam_z(void) { return 0.0; }
double game_cam_yaw(void) { return 0.0; }
double game_cam_pitch(void) { return 0.0; }
int game_consume_shot(void) { return 0; }
void game_mouse_moved(int dx, int dy) { (void)dx; (void)dy; }
void game_mouse_pressed(int button) { (void)button; }
