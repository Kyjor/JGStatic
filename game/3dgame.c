#include "shooter/game.h"

/* Desktop, from the JGStatic repo root. Run the binary from game/ so assets resolve.
   gcc -o game/game game/3dgame.c game/shooter/player.c game/shooter/weapons.c \
     game/shooter/enemies.c game/shooter/procgen.c game/shooter/mission.c \
     game/shooter/meta.c game/shooter/hud.c \
     -Llib_desktop -Wl,-rpath,'$ORIGIN/../lib_desktop' \
     -ljg_static -lSDL2_image -lSDL2_mixer -lSDL2 -rdynamic -lm
*/

#ifndef JG_NO_MAIN
int main(void) {
    game_loop();
    return 0;
}
#endif

Run run;
Player player;

int key_w, key_a, key_s, key_d, key_shift, key_space;
int mouse_left, mouse_edge, mouse_up_edge;
int req_reload, req_weapon = -1, req_confirm, req_left, req_right, req_up, req_down;
double cam_yaw, cam_pitch, view_punch, view_yaw_kick;
int pointer_x = 160, pointer_y = 120;
int ui_arm, ui_drop, ui_hub, ui_offer = -1, ui_weapon = -1;

void game_configure(void) {
}

void game_load(void) {
    req_weapon = -1;
    meta_boot();
}

void game_update(double dt) {
    if (dt > 0.05) dt = 0.05;
    jg3_mouse_look(run.state == ST_MISSION);
    if (run.state == ST_MISSION) mission_frame(dt);
    else menu_frame(dt);
    mouse_edge = 0;
    mouse_up_edge = 0;
    req_reload = 0;
    req_weapon = -1;
    req_confirm = 0;
    req_left = 0;
    req_right = 0;
    req_up = 0;
    req_down = 0;
}

void game_late_update(void) {
}

void game_key_pressed(int key) {
    if (key == 'w' || key == 'W') {
        key_w = 1;
        req_up = 1;
    } else if (key == 'a' || key == 'A') {
        key_a = 1;
        req_left = 1;
    } else if (key == 's' || key == 'S') {
        key_s = 1;
        req_down = 1;
    } else if (key == 'd' || key == 'D') {
        key_d = 1;
        req_right = 1;
    } else if (key == KEY_UP) {
        req_up = 1;
    } else if (key == KEY_LEFT) {
        req_left = 1;
    } else if (key == KEY_DOWN) {
        req_down = 1;
    } else if (key == KEY_RIGHT) {
        req_right = 1;
    } else if (key == KEY_LSHIFT || key == KEY_RSHIFT) {
        key_shift = 1;
    } else if (key == ' ') {
        key_space = 1;
    } else if (key == 'r' || key == 'R') {
        req_reload = 1;
    } else if (key == '1') {
        req_weapon = 0;
    } else if (key == '2') {
        req_weapon = 1;
    } else if (key == '3') {
        req_weapon = 2;
    } else if (key == '4') {
        req_weapon = 3;
    } else if (key == KEY_RETURN || key == KEY_KP_ENTER) {
        req_confirm = 1;
    }
}

void game_key_released(int key) {
    if (key == 'w' || key == 'W') key_w = 0;
    else if (key == 'a' || key == 'A') key_a = 0;
    else if (key == 's' || key == 'S') key_s = 0;
    else if (key == 'd' || key == 'D') key_d = 0;
    else if (key == KEY_LSHIFT || key == KEY_RSHIFT) key_shift = 0;
    else if (key == ' ') key_space = 0;
}

void game_mouse_moved(int dx, int dy) {
    if (run.state != ST_MISSION) return;
    cam_yaw += (double)dx * 0.00215;
    cam_pitch -= (double)dy * 0.00215;
    if (cam_pitch > 1.35) cam_pitch = 1.35;
    if (cam_pitch < -1.15) cam_pitch = -1.15;
}

void game_pointer(int x, int y) {
    pointer_x = x;
    pointer_y = y;
}

void game_mouse_pressed(int button) {
    if (button == 1) {
        if (!mouse_left) mouse_edge = 1;
        if (run.state == ST_MISSION) mouse_left = 1;
    }
}

void game_mouse_released(int button) {
    if (button == 1) {
        if (mouse_left) mouse_up_edge = 1;
        mouse_left = 0;
    }
}

void game_draw(void) {
}

void game_shutdown(void) {
}

int game_wants_3d(void) {
    return 1;
}

double game_model_yaw(void) {
    return cam_yaw;
}

double game_cam_x(void) { return eye_x(); }
double game_cam_y(void) { return eye_y(); }
double game_cam_z(void) { return eye_z(); }

double game_cam_yaw(void) {
    return cam_yaw + view_yaw_kick;
}

double game_cam_pitch(void) {
    double p = cam_pitch + view_punch;
    if (p > 1.45) p = 1.45;
    if (p < -1.35) p = -1.35;
    return p;
}

int game_consume_shot(void) {
    return 0;
}
