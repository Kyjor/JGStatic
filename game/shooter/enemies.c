#include "game.h"

static Enemy enemies[ENEMY_MAX];

typedef struct Pickup {
    int alive;
    double x, z;
    int value;
} Pickup;

typedef struct Floater {
    int alive;
    int value;
    double life;
    int x;
    double y;
} Floater;

static Pickup picks[PICKUP_MAX];
static Floater floats[FLOATER_MAX];

static int enemy_spawn(int type, double x, double z, int room);

static double enemy_radius(int type) {
    if (type == ET_TANK) return 0.46;
    if (type == ET_TURRET) return 0.34;
    if (type == ET_RUNNER) return 0.26;
    return 0.30;
}

static double enemy_height(int type) {
    if (type == ET_TANK) return 1.55;
    if (type == ET_TURRET) return 0.9;
    if (type == ET_RUNNER) return 0.95;
    return 1.15;
}

static double enemy_hp_for(int type) {
    double hp = 32;
    if (type == ET_TANK) hp = 90;
    else if (type == ET_TURRET) hp = 38;
    else if (type == ET_RUNNER) hp = 20;
    hp *= 1.0 + 0.22 * run.mission_index;
    if (run.mission_index >= 4 && type == ET_TANK) hp *= 1.65;
    return hp;
}

static int has_los(double x, double y, double z) {
    double dx = eye_x() - x;
    double dy = eye_y() - y;
    double dz = eye_z() - z;
    double dist = g_sqrt(dx * dx + dy * dy + dz * dz);
    double t = 0;
    int hit;
    if (dist < 0.08) return 1;
    dx /= dist;
    dy /= dist;
    dz /= dist;
    hit = jg3_raycast(x, y, z, dx, dy, dz, dist, 1, -1, &t);
    if (hit == -2 && t < dist - 0.3) return 0;
    return 1;
}

static void pickup_spawn(double x, double z, int value) {
    int i;
    for (i = 0; i < PICKUP_MAX; i++) {
        if (picks[i].alive) continue;
        picks[i].alive = 1;
        picks[i].x = x;
        picks[i].z = z;
        picks[i].value = value;
        return;
    }
}

void floater_add(int value) {
    int i;
    if (value < 1) value = 1;
    for (i = 0; i < FLOATER_MAX; i++) {
        if (floats[i].alive) continue;
        floats[i].alive = 1;
        floats[i].value = value;
        floats[i].life = 0.7;
        floats[i].x = 136 + (int)(game_rand() % 48);
        floats[i].y = 96;
        return;
    }
}

void enemies_clear(void) {
    int i;
    for (i = 0; i < ENEMY_MAX; i++) enemies[i].alive = 0;
}

void pickups_clear(void) {
    int i;
    for (i = 0; i < PICKUP_MAX; i++) picks[i].alive = 0;
}

void floaters_clear(void) {
    int i;
    for (i = 0; i < FLOATER_MAX; i++) floats[i].alive = 0;
}

static int enemy_spawn(int type, double x, double z, int room) {
    int i;
    for (i = 0; i < ENEMY_MAX; i++) {
        if (enemies[i].alive) continue;
        enemies[i].alive = 1;
        enemies[i].type = type;
        enemies[i].room = room;
        enemies[i].x = x;
        enemies[i].z = z;
        enemies[i].vx = 0;
        enemies[i].vz = 0;
        enemies[i].hp = enemy_hp_for(type);
        enemies[i].cd = 0.4;
        enemies[i].tele = 0;
        enemies[i].flash = 0;
        return 1;
    }
    return 0;
}

void enemies_fill_room(int room) {
    Room *r;
    if (room < 0 || room >= ROOM_N) return;
    if (room == run.start_room) return;
    r = &run.rooms[room];
    while (r->spawned_n < r->planned) {
        int k = r->spawned_n;
        if (!enemy_spawn(r->etype[k], r->sx[k], r->sz[k], room)) return;
        r->spawned_n++;
    }
}

int enemies_alive(void) {
    int i, n = 0;
    for (i = 0; i < ENEMY_MAX; i++) if (enemies[i].alive) n++;
    return n;
}

int hostiles_left(void) {
    int i, n = enemies_alive();
    for (i = 0; i < ROOM_N; i++) {
        if (!run.rooms[i].used) continue;
        if (run.rooms[i].spawned_n < run.rooms[i].planned)
            n += run.rooms[i].planned - run.rooms[i].spawned_n;
    }
    return n;
}

void enemy_hit(int id, double dmg, double ix, double iz) {
    double dealt;
    if (id < 0 || id >= ENEMY_MAX) return;
    if (!enemies[id].alive) return;
    dealt = dmg * player.dmg_mul;
    enemies[id].hp -= dealt;
    enemies[id].vx += ix;
    enemies[id].vz += iz;
    enemies[id].flash = 0.1;
    floater_add((int)(dealt + 0.5));
    if (enemies[id].hp <= 0) {
        enemies[id].alive = 0;
        pickup_spawn(enemies[id].x, enemies[id].z, 3 + enemies[id].type * 2);
        jg_play_sound(SND_DEATH);
    }
}

void enemies_register(void) {
    int i;
    for (i = 0; i < ENEMY_MAX; i++) {
        if (!enemies[i].alive) continue;
        jg3_add_hit_sphere(i, enemies[i].x, 1.15, enemies[i].z, enemy_radius(enemies[i].type) + 0.22);
    }
}

static void steer(Enemy *e, double dt, double speed, double stop_dist) {
    double dx = player.x - e->x;
    double dz = player.z - e->z;
    double dist = g_sqrt(dx * dx + dz * dz);
    double ox, oy, oz;
    if (dist > 0.001) {
        dx /= dist;
        dz /= dist;
    }
    if (dist > stop_dist && e->tele <= 0) {
        dx *= speed;
        dz *= speed;
    } else {
        dx = 0;
        dz = 0;
    }
    e->vx -= e->vx * 6.0 * dt;
    e->vz -= e->vz * 6.0 * dt;
    jg3_move_collide(e->x, 0, e->z, (dx + e->vx) * dt, 0, (dz + e->vz) * dt, enemy_radius(e->type), enemy_height(e->type), &ox, &oy, &oz);
    (void)oy;
    e->x = ox;
    e->z = oz;
}

static void try_shot(Enemy *e, double range, double windup, double cooldown) {
    double dx, dz, dist, ey;
    if (e->cd > 0) return;
    dx = player.x - e->x;
    dz = player.z - e->z;
    dist = g_sqrt(dx * dx + dz * dz);
    if (dist > range) return;
    ey = enemy_height(e->type) * 0.62;
    if (!has_los(e->x, ey, e->z)) return;
    e->tele = windup;
    e->cd = cooldown;
}

void enemies_update(double dt) {
    int i;
    for (i = 0; i < ENEMY_MAX; i++) {
        Enemy *e = &enemies[i];
        double scale;
        if (!e->alive) continue;
        if (e->flash > 0) e->flash -= dt;
        if (e->cd > 0) e->cd -= dt;
        scale = 1.0 + 0.05 * run.mission_index;
        if (e->type == ET_RUNNER) {
            double dx = player.x - e->x;
            double dz = player.z - e->z;
            double dist = g_sqrt(dx * dx + dz * dz);
            steer(e, dt, 4.7, 1.05);
            if (dist < 1.2 && e->cd <= 0) {
                player_hurt(13 * scale);
                e->cd = 0.72;
            }
        } else if (e->type == ET_TANK) {
            steer(e, dt, 1.35, 3.4);
            if (e->tele > 0) {
                e->tele -= dt;
                if (e->tele <= 0) {
                    e->tele = 0;
                    if (has_los(e->x, 1.05, e->z)) player_hurt(16 * scale);
                }
            } else {
                try_shot(e, 8.0, 0.72, 1.55);
            }
        } else if (e->type == ET_TURRET) {
            e->vx = 0;
            e->vz = 0;
            if (e->tele > 0) {
                e->tele -= dt;
                if (e->tele <= 0) {
                    e->tele = 0;
                    if (has_los(e->x, 0.6, e->z)) player_hurt(8 * scale);
                }
            } else {
                try_shot(e, 13.0, 0.48, 0.95);
            }
        } else {
            steer(e, dt, 2.35, 5.0);
            if (e->tele > 0) {
                e->tele -= dt;
                if (e->tele <= 0) {
                    e->tele = 0;
                    if (has_los(e->x, 0.8, e->z)) player_hurt(9 * scale);
                }
            } else {
                try_shot(e, 10.5, 0.36, 1.15);
            }
        }
    }
    for (i = 0; i < PICKUP_MAX; i++) {
        double dx, dz, d2, range;
        if (!picks[i].alive) continue;
        dx = player.x - picks[i].x;
        dz = player.z - picks[i].z;
        d2 = dx * dx + dz * dz;
        range = 0.7 + player.magnet * 2.6;
        if (player.magnet > 0 && d2 < range * range && d2 > 0.0001) {
            double inv = 1.0 / g_sqrt(d2);
            picks[i].x += dx * inv * 7.0 * dt;
            picks[i].z += dz * inv * 7.0 * dt;
            dx = player.x - picks[i].x;
            dz = player.z - picks[i].z;
            d2 = dx * dx + dz * dz;
        }
        if (d2 < 0.42 * 0.42) {
            meta_add_scrap(picks[i].value);
            picks[i].alive = 0;
            jg_play_sound(SND_JUMP);
        }
    }
    for (i = 0; i < FLOATER_MAX; i++) {
        if (!floats[i].alive) continue;
        floats[i].life -= dt;
        floats[i].y -= 22.0 * dt;
        if (floats[i].life <= 0) floats[i].alive = 0;
    }
}

static int room_visible(int room, int current) {
    int dx, dz;
    if (room < 0 || room >= ROOM_N) return 0;
    if (!run.rooms[room].used) return 0;
    if (current < 0) return room == run.start_room;
    dx = room % 3 - current % 3;
    dz = room / 3 - current / 3;
    if (dx < 0) dx = -dx;
    if (dz < 0) dz = -dz;
    return dx + dz <= 1;
}

void enemies_draw(int current_room) {
    int i;
    for (i = 0; i < ENEMY_MAX; i++) {
        Enemy *e = &enemies[i];
        int r, g, b;
        double h, rad;
        if (!e->alive) continue;
        if (!room_visible(e->room, current_room)) continue;
        r = 176; g = 64; b = 58;
        if (e->type == ET_RUNNER) { r = 214; g = 140; b = 48; }
        if (e->type == ET_TANK) { r = 120; g = 42; b = 48; }
        if (e->type == ET_TURRET) { r = 150; g = 158; b = 170; }
        if (e->flash > 0) { r = 245; g = 240; b = 230; }
        else if (e->tele > 0 && e->tele < 0.22) { r = 245; g = 220; b = 140; }
        h = enemy_height(e->type);
        rad = enemy_radius(e->type);
        jg3_draw_cylinder(e->x, 0, e->z, rad, h, 6, r, g, b);
        if (e->type == ET_TANK)
            jg3_draw_box(e->x, h + 0.12, e->z, 0.5, 0.24, 0.5, r - 20, g, b);
        if (e->type == ET_TURRET)
            jg3_draw_box(e->x, h, e->z, 0.62, 0.22, 0.62, 90, 94, 100);
    }
    for (i = 0; i < PICKUP_MAX; i++) {
        double bob;
        if (!picks[i].alive) continue;
        bob = 0.22 + 0.06 * g_sin(run.mission_time * 3.2 + picks[i].x);
        jg3_draw_box(picks[i].x, bob, picks[i].z, 0.22, 0.22, 0.22, 230, 190, 70);
    }
}

void floaters_draw(void) {
    int i;
    for (i = 0; i < FLOATER_MAX; i++) {
        if (!floats[i].alive) continue;
        jg3_hud_digits(floats[i].x, (int)floats[i].y, floats[i].value, 1, 1, 255, 228, 150);
    }
}

void spawn_wave(void) {
    int cur = room_index_at(player.x, player.z);
    double cx, cz;
    int n, k;
    if (cur < 0) cur = run.start_room;
    room_center(cur, &cx, &cz);
    n = 1 + (int)(game_rand() % 2);
    for (k = 0; k < n; k++) {
        int type = ET_GRUNT;
        unsigned roll = game_rand() % 100;
        double ox, oz;
        if (run.mission_index >= 1 && roll < 40) type = ET_RUNNER;
        if (run.mission_index >= 2 && roll < 18) type = ET_TURRET;
        if (run.mission_index >= 3 && roll < 10) type = ET_TANK;
        ox = cx + ((int)(game_rand() % 5) - 2) * 1.15;
        oz = cz + ((int)(game_rand() % 5) - 2) * 1.15;
        enemy_spawn(type, ox, oz, cur);
    }
}
