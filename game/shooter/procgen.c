#include "game.h"

unsigned g_rng = 1;

unsigned game_rand(void) {
    g_rng = g_rng * 1664525u + 1013904223u;
    return g_rng;
}

void room_center(int room, double *x, double *z) {
    int gx, gz;
    if (room < 0 || room >= ROOM_N) room = 0;
    gx = room % GRID_N;
    gz = room / GRID_N;
    if (x) *x = gx * CELL + CELL * 0.5;
    if (z) *z = gz * CELL + CELL * 0.5;
}

int room_index_at(double x, double z) {
    int gx = (int)(x / CELL);
    int gz = (int)(z / CELL);
    int i;
    if (gx < 0 || gz < 0 || gx >= GRID_N || gz >= GRID_N) return -1;
    i = gz * GRID_N + gx;
    if (!run.rooms[i].used) return -1;
    return i;
}

static int first_used(void) {
    int i;
    for (i = 0; i < ROOM_N; i++) if (run.rooms[i].used) return i;
    return 0;
}

static void clear_rooms(void) {
    int i, k;
    for (i = 0; i < ROOM_N; i++) {
        Room *r = &run.rooms[i];
        r->used = 0;
        r->planned = 0;
        r->spawned_n = 0;
        r->covers = 0;
        for (k = 0; k < 4; k++) {
            r->door[k] = 0;
            r->etype[k] = 0;
            r->sx[k] = 0;
            r->sz[k] = 0;
        }
        for (k = 0; k < 3; k++) {
            r->cx[k] = 0;
            r->cz[k] = 0;
        }
    }
}

static void link_doors(void) {
    int i;
    for (i = 0; i < ROOM_N; i++) {
        int gx, gz;
        if (!run.rooms[i].used) continue;
        gx = i % GRID_N;
        gz = i / GRID_N;
        if (gz > 0 && run.rooms[i - GRID_N].used) run.rooms[i].door[DIR_N] = 1;
        if (gx < GRID_N - 1 && run.rooms[i + 1].used) run.rooms[i].door[DIR_E] = 1;
        if (gz < GRID_N - 1 && run.rooms[i + GRID_N].used) run.rooms[i].door[DIR_S] = 1;
        if (gx > 0 && run.rooms[i - 1].used) run.rooms[i].door[DIR_W] = 1;
    }
}

static void place_covers(int room) {
    Room *r = &run.rooms[room];
    double cx, cz;
    int s, c = 0;
    room_center(room, &cx, &cz);
    for (s = 0; s < 4 && c < 3; s++) {
        double ox = (s == 0 || s == 3) ? -1.75 : 1.75;
        double oz = (s < 2) ? -1.75 : 1.75;
        double x = cx + ox;
        double z = cz + oz;
        if (c >= 2 && (game_rand() % 3) == 0) continue;
        if (r->door[DIR_N] && z < cz - 2.3) z = cz - 0.35;
        if (r->door[DIR_S] && z > cz + 2.3) z = cz + 0.35;
        if (r->door[DIR_W] && x < cx - 2.3) x = cx - 0.35;
        if (r->door[DIR_E] && x > cx + 2.3) x = cx + 0.35;
        r->cx[c] = x;
        r->cz[c] = z;
        c++;
    }
    r->covers = c;
}

static int roll_type(int room) {
    unsigned roll = game_rand() % 100;
    if (run.mission_index >= 4 && room == run.exit_room) {
        if (roll < 35) return ET_TANK;
        if (roll < 60) return ET_TURRET;
        if (roll < 80) return ET_RUNNER;
        return ET_GRUNT;
    }
    if (run.mission_index >= 3 && roll < 18) return ET_TANK;
    if (run.mission_index >= 2 && roll < 30) return ET_TURRET;
    if (run.mission_index >= 1 && roll < 48) return ET_RUNNER;
    return ET_GRUNT;
}

static void plan_enemies(int room) {
    Room *r = &run.rooms[room];
    double cx, cz;
    int count, k;
    if (room == run.start_room) {
        r->planned = 0;
        return;
    }
    count = 1 + (int)(game_rand() % 2);
    if (run.mission_index >= 2 && (game_rand() % 2) == 0) count++;
    if (run.mission_type == MT_SURVIVE) count = 1;
    if (run.mission_index >= 4 && room == run.exit_room) count = 4;
    if (count > 4) count = 4;
    room_center(room, &cx, &cz);
    r->planned = count;
    for (k = 0; k < count; k++) {
        double ang = k * 1.57079632679;
        r->etype[k] = roll_type(room);
        if (run.mission_index >= 4 && room == run.exit_room && k == 0) r->etype[k] = ET_TANK;
        if (run.mission_index >= 4 && room == run.exit_room && k == 1) r->etype[k] = ET_TURRET;
        r->sx[k] = cx + g_cos(ang) * 0.95;
        r->sz[k] = cz + g_sin(ang) * 0.95;
    }
}

void procgen_build(unsigned seed) {
    int want, n, guard, cx, cz, i;
    g_rng = seed ? seed : 1u;
    clear_rooms();
    want = 5 + (int)(game_rand() % 3);
    if (run.mission_index >= 4) want = 7;
    cx = 1;
    cz = 1;
    run.rooms[cz * GRID_N + cx].used = 1;
    n = 1;
    guard = 0;
    while (n < want && guard < 80) {
        int dir = (int)(game_rand() % 4);
        int nx = cx;
        int nz = cz;
        int idx;
        if (dir == 0) nz--;
        else if (dir == 1) nx++;
        else if (dir == 2) nz++;
        else nx--;
        guard++;
        if (nx < 0 || nz < 0 || nx >= GRID_N || nz >= GRID_N) continue;
        cx = nx;
        cz = nz;
        idx = nz * GRID_N + nx;
        if (!run.rooms[idx].used) {
            run.rooms[idx].used = 1;
            n++;
        }
    }
    link_doors();
    run.start_room = run.rooms[4].used ? 4 : first_used();
    run.exit_room = run.start_room;
    {
        int best_d = -1;
        int sgx = run.start_room % GRID_N;
        int sgz = run.start_room / GRID_N;
        for (i = 0; i < ROOM_N; i++) {
            int d;
            if (!run.rooms[i].used || i == run.start_room) continue;
            d = i % GRID_N - sgx;
            if (d < 0) d = -d;
            {
                int dz = i / GRID_N - sgz;
                if (dz < 0) dz = -dz;
                d += dz;
            }
            if (d > best_d) {
                best_d = d;
                run.exit_room = i;
            }
        }
    }
    for (i = 0; i < ROOM_N; i++) {
        if (!run.rooms[i].used) continue;
        place_covers(i);
        plan_enemies(i);
    }
}

static const double WALL_T = 0.38;
static const double WALL_H = 2.65;

static void add_x_span(double x0, double x1, double z, int inward_pos) {
    double len = x1 - x0;
    double zz;
    if (len < 0.2) return;
    zz = inward_pos ? z : z - WALL_T;
    jg3_add_aabb(x0, 0, zz, len, WALL_H, WALL_T);
}

static void add_z_span(double z0, double z1, double x, int inward_pos) {
    double len = z1 - z0;
    double xx;
    if (len < 0.2) return;
    xx = inward_pos ? x : x - WALL_T;
    jg3_add_aabb(xx, 0, z0, WALL_T, WALL_H, len);
}

static void add_x_wall(double x0, double x1, double z, int inward_pos, int gap, double gap0, double gap1) {
    if (!gap) add_x_span(x0, x1, z, inward_pos);
    else {
        add_x_span(x0, gap0, z, inward_pos);
        add_x_span(gap1, x1, z, inward_pos);
    }
}

static void add_z_wall(double z0, double z1, double x, int inward_pos, int gap, double gap0, double gap1) {
    if (!gap) add_z_span(z0, z1, x, inward_pos);
    else {
        add_z_span(z0, gap0, x, inward_pos);
        add_z_span(gap1, z1, x, inward_pos);
    }
}

void procgen_colliders(void) {
    int i;
    jg3_clear_colliders();
    jg3_add_aabb(-4, -2, -4, 42, 2, 42);
    for (i = 0; i < ROOM_N; i++) {
        double x0, z0, x1, z1, mx, mz, g0x, g1x, g0z, g1z;
        int c;
        if (!run.rooms[i].used) continue;
        x0 = (i % GRID_N) * CELL;
        z0 = (i / GRID_N) * CELL;
        x1 = x0 + CELL;
        z1 = z0 + CELL;
        mx = (x0 + x1) * 0.5;
        mz = (z0 + z1) * 0.5;
        g0x = mx - 1.2;
        g1x = mx + 1.2;
        g0z = mz - 1.2;
        g1z = mz + 1.2;
        add_x_wall(x0, x1, z0, 1, run.rooms[i].door[DIR_N], g0x, g1x);
        add_x_wall(x0, x1, z1, 0, run.rooms[i].door[DIR_S], g0x, g1x);
        add_z_wall(z0, z1, x0, 1, run.rooms[i].door[DIR_W], g0z, g1z);
        add_z_wall(z0, z1, x1, 0, run.rooms[i].door[DIR_E], g0z, g1z);
        for (c = 0; c < run.rooms[i].covers; c++) {
            jg3_add_aabb(run.rooms[i].cx[c] - 0.42, 0, run.rooms[i].cz[c] - 0.42, 0.84, 1.7, 0.84);
        }
    }
}

static int visible(int room, int current) {
    int dx, dz;
    if (!run.rooms[room].used) return 0;
    if (current < 0) return room == run.start_room;
    dx = room % GRID_N - current % GRID_N;
    dz = room / GRID_N - current / GRID_N;
    if (dx < 0) dx = -dx;
    if (dz < 0) dz = -dz;
    return dx + dz <= 1;
}

static void draw_x_span(double x0, double x1, double z, int r, int g, int b) {
    if (x1 - x0 < 0.15) return;
    jg3_draw_quad(x0, 0, z, x1, 0, z, x1, WALL_H, z, x0, WALL_H, z, r, g, b);
}

static void draw_z_span(double z0, double z1, double x, int r, int g, int b) {
    if (z1 - z0 < 0.15) return;
    jg3_draw_quad(x, 0, z0, x, 0, z1, x, WALL_H, z1, x, WALL_H, z0, r, g, b);
}

static void draw_x_wall(double x0, double x1, double z, int gap, double gap0, double gap1, int r, int g, int b) {
    if (!gap) draw_x_span(x0, x1, z, r, g, b);
    else {
        draw_x_span(x0, gap0, z, r, g, b);
        draw_x_span(gap1, x1, z, r, g, b);
    }
}

static void draw_z_wall(double z0, double z1, double x, int gap, double gap0, double gap1, int r, int g, int b) {
    if (!gap) draw_z_span(z0, z1, x, r, g, b);
    else {
        draw_z_span(z0, gap0, x, r, g, b);
        draw_z_span(gap1, z1, x, r, g, b);
    }
}

void procgen_draw(int current) {
    int i;
    for (i = 0; i < ROOM_N; i++) {
        double x0, z0, x1, z1, mx, mz, g0x, g1x, g0z, g1z;
        int c;
        if (!visible(i, current)) continue;
        x0 = (i % GRID_N) * CELL;
        z0 = (i / GRID_N) * CELL;
        x1 = x0 + CELL;
        z1 = z0 + CELL;
        mx = (x0 + x1) * 0.5;
        mz = (z0 + z1) * 0.5;
        g0x = mx - 1.2;
        g1x = mx + 1.2;
        g0z = mz - 1.2;
        g1z = mz + 1.2;
        jg3_draw_grid(x0, 0, z0, CELL, CELL, 2.0, run.floor_r, run.floor_g, run.floor_b);
        draw_x_wall(x0, x1, z0 + WALL_T, run.rooms[i].door[DIR_N], g0x, g1x, run.wall_r, run.wall_g, run.wall_b);
        draw_x_wall(x0, x1, z1 - WALL_T, run.rooms[i].door[DIR_S], g0x, g1x, run.wall_r, run.wall_g, run.wall_b);
        draw_z_wall(z0, z1, x0 + WALL_T, run.rooms[i].door[DIR_W], g0z, g1z, run.wall_r, run.wall_g, run.wall_b);
        draw_z_wall(z0, z1, x1 - WALL_T, run.rooms[i].door[DIR_E], g0z, g1z, run.wall_r, run.wall_g, run.wall_b);
        for (c = 0; c < run.rooms[i].covers; c++) {
            jg3_draw_box(run.rooms[i].cx[c], 0.85, run.rooms[i].cz[c], 0.84, 1.7, 0.84,
                         run.wall_r - 28, run.wall_g - 24, run.wall_b - 20);
        }
    }
    if (run.mission_type == MT_DESTROY && run.obj_hp > 0 && visible(run.exit_room, current)) {
        double ox, oz, h;
        room_center(run.exit_room, &ox, &oz);
        h = 0.35 + 1.2 * (run.obj_hp / (run.obj_max > 0 ? run.obj_max : 1));
        jg3_draw_cylinder(ox, 0, oz, 0.34, h, 6, 214, 176, 64);
    }
    if (run.exit_open && visible(run.exit_room, current)) {
        double ex, ez;
        room_center(run.exit_room, &ex, &ez);
        ez += 3.15;
        jg3_draw_quad(ex - 0.75, 0.05, ez - 0.75, ex + 0.75, 0.05, ez - 0.75,
                      ex + 0.75, 0.05, ez + 0.75, ex - 0.75, 0.05, ez + 0.75,
                      48, 200, 96);
    }
}
