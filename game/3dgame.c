#include <stdio.h>
#include "../jg_static.h"
//gcc -o game 3dgame.c   -L/home/kyjor/Documents/Projects/Julia/JGStatic/lib_desktop   -Wl,-rpath,/home/kyjor/Documents/Projects/Julia/JGStatic/lib_desktop   -ljg_static   -lSDL2_image -lSDL2_mixer -lSDL2   -rdynamic

// gcc -o game 3dgame.c \
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
}

void game_load() {
}

static int key_w;
static int key_a;
static int key_s;
static int key_d;
static int key_shift;
static int key_space;
static int jump_was_down;
static int shot_pending;

static double cam_x;
static double cam_y = 1.6;
static double cam_z = 1.5;
static double cam_yaw;
static double cam_pitch;
static double vel_y;
static int on_ground = 1;

void game_update(double dt) {
    if (dt > 0.05) dt = 0.05;

    double speed = key_shift ? 9.0 : 4.5;
    double sy = 0.0;
    double cy = 1.0;
    /* Approximate sin/cos for movement from yaw via small steps is awkward in C
       without libm linked specially; use the same angle the camera already has
       via a short Taylor expansion. */
    {
        double a = cam_yaw;
        while (a > 3.141592653589793) a -= 6.283185307179586;
        while (a < -3.141592653589793) a += 6.283185307179586;
        double a2 = a * a;
        sy = a * (1.0 - a2 / 6.0 + (a2 * a2) / 120.0);
        cy = 1.0 - a2 / 2.0 + (a2 * a2) / 24.0;
    }

    double mx = 0.0;
    double mz = 0.0;
    if (key_w) { mx += sy; mz += cy; }
    if (key_s) { mx -= sy; mz -= cy; }
    if (key_a) { mx -= cy; mz += sy; }
    if (key_d) { mx += cy; mz -= sy; }
    double len2 = mx * mx + mz * mz;
    if (len2 > 0.0001) {
        double invlen = 1.0;
        if (len2 > 1.0001) {
            double g = len2;
            int i;
            for (i = 0; i < 6; i++) g = 0.5 * (g + len2 / g);
            invlen = 1.0 / g;
        }
        cam_x += mx * invlen * speed * dt;
        cam_z += mz * invlen * speed * dt;
    }

    if (key_space && !jump_was_down && on_ground) {
        vel_y = 5.2;
        on_ground = 0;
    }
    jump_was_down = key_space;

    vel_y -= 16.0 * dt;
    cam_y += vel_y * dt;
    if (cam_y <= 1.6) {
        cam_y = 1.6;
        vel_y = 0.0;
        on_ground = 1;
    }

    if (cam_x < -4.5) cam_x = -4.5;
    if (cam_x > 4.5) cam_x = 4.5;
    if (cam_z < 0.5) cam_z = 0.5;
    if (cam_z > 13.0) cam_z = 13.0;
}

void game_late_update(void) {
}

void game_key_pressed(int key) {
    if (key == 'w' || key == 'W') key_w = 1;
    else if (key == 'a' || key == 'A') key_a = 1;
    else if (key == 's' || key == 'S') key_s = 1;
    else if (key == 'd' || key == 'D') key_d = 1;
    else if (key == 1073742049) key_shift = 1; /* LSHIFT */
    else if (key == ' ') key_space = 1;
}

void game_key_released(int key) {
    if (key == 'w' || key == 'W') key_w = 0;
    else if (key == 'a' || key == 'A') key_a = 0;
    else if (key == 's' || key == 'S') key_s = 0;
    else if (key == 'd' || key == 'D') key_d = 0;
    else if (key == 1073742049) key_shift = 0;
    else if (key == ' ') key_space = 0;
}

void game_mouse_moved(int dx, int dy) {
    cam_yaw += (double)dx * 0.0022;
    cam_pitch -= (double)dy * 0.0022;
    if (cam_pitch > 1.4) cam_pitch = 1.4;
    if (cam_pitch < -1.4) cam_pitch = -1.4;
}

void game_mouse_pressed(int button) {
    if (button == 1) shot_pending = 1;
}

void game_draw() {
}

void game_shutdown() {
}

int game_wants_3d(void) {
    return 1;
}

double game_model_yaw(void) {
    return cam_yaw;
}

double game_cam_x(void) { return cam_x; }
double game_cam_y(void) { return cam_y; }
double game_cam_z(void) { return cam_z; }
double game_cam_yaw(void) { return cam_yaw; }
double game_cam_pitch(void) { return cam_pitch; }

int game_consume_shot(void) {
    int s = shot_pending;
    shot_pending = 0;
    return s;
}
