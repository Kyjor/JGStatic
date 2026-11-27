#pragma once

#include "../../jg_static.h"

#define CELL 10.0
#define GRID_N 3
#define ROOM_N 9
#define ENEMY_MAX 12
#define PICKUP_MAX 16
#define FLOATER_MAX 6
#define OBJ_ID 100

enum {
    ST_TITLE = 0,
    ST_HUB,
    ST_MISSION,
    ST_UPGRADE,
    ST_DEAD,
    ST_WIN
};

enum { MT_CLEAR = 0, MT_SURVIVE, MT_DESTROY };
enum { ET_GRUNT = 0, ET_RUNNER, ET_TANK, ET_TURRET };
enum { WP_SIDE = 0, WP_SMG, WP_SHOT, WP_RAIL, WP_COUNT };
enum { SND_SHOT = 0, SND_DEATH, SND_JUMP };
enum { DIR_N = 0, DIR_E, DIR_S, DIR_W };

#define KEY_LSHIFT 1073742049
#define KEY_RSHIFT 1073742053
#define KEY_LEFT 1073741904
#define KEY_RIGHT 1073741903
#define KEY_UP 1073741906
#define KEY_DOWN 1073741905
#define KEY_RETURN 13
#define KEY_KP_ENTER 1073741912
#define SCAN_A 4
#define SCAN_D 7
#define SCAN_S 22
#define SCAN_W 26
#define SCAN_SPACE 44
#define SCAN_RIGHT 79
#define SCAN_LEFT 80
#define SCAN_DOWN 81
#define SCAN_UP 82
#define SCAN_LSHIFT 225
#define SCAN_RSHIFT 229

typedef struct Player {
    double x, y, z;
    double vx, vy, vz;
    int on_ground;
    int jump_was;
    double hp, max_hp;
    double speed_mul, dmg_mul, mag_mul, rate_mul, armor, regen;
    int magnet;
    double hurt_cd;
    double flash;
    int weapon;
    int mag[WP_COUNT];
    double fire_cd;
    double reload_t;
    int reloading;
    double charge;
} Player;

typedef struct Room {
    int used;
    int door[4];
    int planned;
    int spawned_n;
    int etype[4];
    double sx[4];
    double sz[4];
    int covers;
    double cx[3];
    double cz[3];
} Room;

typedef struct Run {
    int state;
    unsigned seed;
    int mission_index;
    int mission_type;
    double mission_time;
    double survive_need;
    double wave_t;
    int exit_open;
    double obj_hp;
    double obj_max;
    int start_room;
    int exit_room;
    int theme_r, theme_g, theme_b;
    int floor_r, floor_g, floor_b;
    int wall_r, wall_g, wall_b;
    int offers[3];
    int offer_sel;
    int loadout;
    Room rooms[ROOM_N];
} Run;

typedef struct Enemy {
    int alive;
    int type;
    int room;
    double x, z;
    double vx, vz;
    double hp;
    double cd;
    double tele;
    double flash;
} Enemy;

extern Run run;
extern Player player;
extern unsigned g_rng;

extern int key_w, key_a, key_s, key_d, key_shift, key_space;
extern int mouse_left, mouse_edge, mouse_up_edge;
extern int req_reload, req_weapon, req_confirm, req_left, req_right, req_up, req_down;
extern double cam_yaw, cam_pitch, view_punch, view_yaw_kick;
extern int pointer_x, pointer_y;
extern int ui_arm, ui_drop, ui_hub, ui_offer, ui_weapon;

static inline double g_wrap(double a) {
    const double pi = 3.141592653589793;
    const double turn = 6.283185307179586;
    while (a > pi) a -= turn;
    while (a < -pi) a += turn;
    return a;
}

static inline double g_sin(double a) {
    double a2;
    a = g_wrap(a);
    a2 = a * a;
    return a * (1.0 - a2 / 6.0 + (a2 * a2) / 120.0 - (a2 * a2 * a2) / 5040.0);
}

static inline double g_cos(double a) {
    double a2;
    a = g_wrap(a);
    a2 = a * a;
    return 1.0 - a2 / 2.0 + (a2 * a2) / 24.0 - (a2 * a2 * a2) / 720.0;
}

static inline double g_sqrt(double v) {
    double g;
    int i;
    if (v <= 0.0) return 0.0;
    g = v > 1.0 ? v * 0.5 : 1.0;
    for (i = 0; i < 8; i++) g = 0.5 * (g + v / g);
    return g;
}

unsigned game_rand(void);

void player_reset_run(void);
void player_spawn(int room);
void player_apply_upgrade(int id);
void player_hurt(double dmg);
void player_update(double dt);
double eye_x(void);
double eye_y(void);
double eye_z(void);

void weapons_refill(void);
void weapons_switch(int weapon);
void weapons_reload(void);
void weapons_update(double dt);
void weapons_draw(void);
const char *weapon_name(int weapon);
int mag_max(int weapon);

void spawn_wave(void);
void enemies_clear(void);
void enemies_fill_room(int room);
void enemies_register(void);
void enemies_update(double dt);
void enemies_draw(int current_room);
void enemy_hit(int id, double dmg, double ix, double iz);
int enemies_alive(void);
int hostiles_left(void);
void pickups_clear(void);
void floaters_clear(void);
void floaters_draw(void);
void floater_add(int value);

void procgen_build(unsigned seed);
void procgen_colliders(void);
void procgen_draw(int current_room);
int room_index_at(double x, double z);
void room_center(int room, double *x, double *z);

void mission_begin(void);
void mission_frame(double dt);
void mission_hit_objective(double dmg);

void meta_boot(void);
int meta_unlocked(int weapon);
int meta_scrap(void);
int meta_price(int weapon);
void meta_add_scrap(int amount);
void meta_try_buy(int weapon);
void meta_roll_offers(void);
const char *upgrade_label(int id);
void menu_frame(double dt);

void hud_mission(void);
void hud_menu(void);
