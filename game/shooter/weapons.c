#include "game.h"

typedef struct WepDef {
    double cooldown;
    double reload;
    int mag;
    double damage;
    double recoil;
    int pellets;
    double spread;
    int automatic;
    int pierce;
} WepDef;

static const WepDef WEPS[WP_COUNT] = {
    {0.24, 1.00, 12, 17, 0.030, 1, 0.0, 0, 0},
    {0.072, 1.15, 32, 6.5, 0.012, 1, 0.008, 1, 0},
    {0.56, 1.45, 6, 8.5, 0.058, 5, 0.05, 0, 0},
    {0.15, 1.70, 4, 48, 0.072, 1, 0.0, 0, 1}
};

static const char *NAMES[WP_COUNT] = {"SIDEARM", "SMG", "SHOTGUN", "RAIL"};

const char *weapon_name(int weapon) {
    if (weapon < 0 || weapon >= WP_COUNT) return "GUN";
    return NAMES[weapon];
}

int mag_max(int weapon) {
    int n;
    if (weapon < 0 || weapon >= WP_COUNT) return 1;
    n = (int)(WEPS[weapon].mag * player.mag_mul + 0.5);
    if (n < 1) n = 1;
    return n;
}

void weapons_refill(void) {
    int i;
    for (i = 0; i < WP_COUNT; i++) player.mag[i] = mag_max(i);
    player.reloading = 0;
    player.reload_t = 0;
    player.charge = 0;
    player.fire_cd = 0;
}

void weapons_switch(int weapon) {
    if (weapon < 0 || weapon >= WP_COUNT) return;
    if (!meta_unlocked(weapon)) return;
    if (player.weapon == weapon) return;
    player.weapon = weapon;
    player.reloading = 0;
    player.reload_t = 0;
    player.charge = 0;
}

void weapons_reload(void) {
    if (player.reloading) return;
    if (player.weapon < 0 || player.weapon >= WP_COUNT) return;
    if (player.mag[player.weapon] >= mag_max(player.weapon)) return;
    player.reloading = 1;
    player.reload_t = WEPS[player.weapon].reload;
    player.charge = 0;
}

static void fire_dir(double yaw, double pitch, double dmg, int pierce) {
    double fx = g_sin(yaw) * g_cos(pitch);
    double fy = g_sin(pitch);
    double fz = g_cos(yaw) * g_cos(pitch);
    double ox = eye_x();
    double oy = eye_y();
    double oz = eye_z();
    int ignore = -1;
    int left = pierce ? 2 : 1;
    while (left > 0) {
        double t = 0;
        int id = jg3_raycast(ox, oy, oz, fx, fy, fz, 36.0, 3, ignore, &t);
        if (id < 0) break;
        if (id == OBJ_ID) {
            mission_hit_objective(dmg);
            break;
        }
        enemy_hit(id, dmg, fx * 5.2, fz * 5.2);
        if (!pierce) break;
        ignore = id;
        ox += fx * (t + 0.25);
        oy += fy * (t + 0.25);
        oz += fz * (t + 0.25);
        left--;
    }
}

static void do_fire(const WepDef *wep, double scale) {
    int i;
    double yaw = cam_yaw + view_yaw_kick;
    double pitch = cam_pitch + view_punch;
    for (i = 0; i < wep->pellets; i++) {
        double off = 0;
        double sway = ((int)(game_rand() % 100) - 50) * 0.00018;
        if (wep->pellets > 1) off = (i - wep->pellets / 2) * wep->spread;
        fire_dir(yaw + off + sway, pitch + sway * 0.6, wep->damage * scale, wep->pierce);
    }
    if (player.mag[player.weapon] > 0) player.mag[player.weapon]--;
    player.fire_cd = wep->cooldown / (1.0 + player.rate_mul);
    view_punch += wep->recoil;
    view_yaw_kick += ((int)(game_rand() % 3) - 1) * wep->recoil * 0.4;
    player.flash = 0.06;
    jg_play_sound(SND_SHOT);
    jg3_screen_flash(255, 220, 150, wep->pierce ? 80 : 42);
}

void weapons_update(double dt) {
    const WepDef *wep;
    int trigger;
    if (player.fire_cd > 0) player.fire_cd -= dt;
    if (player.weapon < 0 || player.weapon >= WP_COUNT) return;
    wep = &WEPS[player.weapon];
    if (player.reloading) {
        player.charge = 0;
        player.reload_t -= dt;
        if (player.reload_t <= 0) {
            player.reloading = 0;
            player.mag[player.weapon] = mag_max(player.weapon);
        }
        return;
    }
    if (player.mag[player.weapon] <= 0) {
        weapons_reload();
        return;
    }
    if (player.weapon == WP_RAIL) {
        if (mouse_left) {
            player.charge += dt / 0.5;
            if (player.charge > 1) player.charge = 1;
        }
        if (mouse_up_edge) {
            if (player.charge > 0.35) do_fire(wep, 0.4 + player.charge * 0.75);
            player.charge = 0;
        }
        return;
    }
    trigger = wep->automatic ? mouse_left : mouse_edge;
    if (trigger && player.fire_cd <= 0) do_fire(wep, 1);
}

static void view_basis(double *fx, double *fy, double *fz, double *rx, double *ry, double *rz, double *ux, double *uy, double *uz) {
    double yaw = cam_yaw + view_yaw_kick;
    double pitch = cam_pitch + view_punch;
    *fx = g_sin(yaw) * g_cos(pitch);
    *fy = g_sin(pitch);
    *fz = g_cos(yaw) * g_cos(pitch);
    *rx = g_cos(yaw);
    *ry = 0;
    *rz = -g_sin(yaw);
    *ux = (*fy) * (*rz) - (*fz) * (*ry);
    *uy = (*fz) * (*rx) - (*fx) * (*rz);
    *uz = (*fx) * (*ry) - (*fy) * (*rx);
}

static void view_part(double ox, double oy, double oz, double lx, double ly, double lz, double sx, double sy, double sz,
                       double fx, double fy, double fz, double rx, double ry, double rz, double ux, double uy, double uz,
                       int r, int g, int b) {
    jg3_draw_viewbox(ox + rx * lx + ux * ly + fx * lz, oy + ry * lx + uy * ly + fy * lz, oz + rz * lx + uz * ly + fz * lz,
                     sx, sy, sz, rx, ry, rz, ux, uy, uz, fx, fy, fz, r, g, b);
}

void weapons_draw(void) {
    double fx, fy, fz, rx, ry, rz, ux, uy, uz;
    double ox, oy, oz, kick, dip;
    int r = 70, g = 74, b = 82;
    view_basis(&fx, &fy, &fz, &rx, &ry, &rz, &ux, &uy, &uz);
    kick = player.flash > 0 ? 0.05 : 0;
    dip = player.reloading ? 0.07 : 0;
    ox = eye_x() + rx * 0.16 - ux * (0.13 + dip) + fx * (0.38 - kick);
    oy = eye_y() + ry * 0.16 - uy * (0.13 + dip) + fy * (0.38 - kick);
    oz = eye_z() + rz * 0.16 - uz * (0.13 + dip) + fz * (0.38 - kick);
    if (player.weapon == WP_SHOT) { r = 120; g = 78; b = 48; }
    if (player.weapon == WP_RAIL) { r = 70; g = 110; b = 160; }
    if (player.weapon == WP_SMG) { r = 90; g = 96; b = 70; }
    view_part(ox, oy, oz, 0, 0, 0.02, 0.05, 0.06, 0.22, fx, fy, fz, rx, ry, rz, ux, uy, uz, r, g, b);
    view_part(ox, oy, oz, 0, -0.055, -0.04, 0.028, 0.08, 0.045, fx, fy, fz, rx, ry, rz, ux, uy, uz, r - 16, g - 16, b - 12);
    view_part(ox, oy, oz, 0, 0.01, 0.16, 0.02, 0.02, 0.14, fx, fy, fz, rx, ry, rz, ux, uy, uz, r + 28, g + 24, b + 18);
    if (player.flash > 0)
        view_part(ox, oy, oz, 0, 0.01, 0.26, 0.05, 0.05, 0.05, fx, fy, fz, rx, ry, rz, ux, uy, uz, 255, 220, 120);
}
