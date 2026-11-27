#include "game.h"

void player_reset_run(void) {
    int i;
    player.x = player.y = player.z = 0;
    player.vx = player.vy = player.vz = 0;
    player.on_ground = 1;
    player.jump_was = 0;
    player.max_hp = 100;
    player.hp = 100;
    player.speed_mul = 1;
    player.dmg_mul = 1;
    player.mag_mul = 1;
    player.rate_mul = 0;
    player.armor = 1;
    player.regen = 0;
    player.magnet = 0;
    player.hurt_cd = 0;
    player.flash = 0;
    player.weapon = 0;
    player.fire_cd = 0;
    player.reload_t = 0;
    player.reloading = 0;
    player.charge = 0;
    for (i = 0; i < WP_COUNT; i++) player.mag[i] = 0;
    cam_yaw = 0;
    cam_pitch = 0;
    view_punch = 0;
    view_yaw_kick = 0;
}

void player_spawn(int room) {
    double x = 0;
    double z = 0;
    room_center(room, &x, &z);
    player.x = x;
    player.y = 0;
    player.z = z;
    player.vx = 0;
    player.vy = 0;
    player.vz = 0;
    player.on_ground = 1;
    cam_yaw = 0;
    cam_pitch = 0;
    view_punch = 0;
    view_yaw_kick = 0;
}

void player_apply_upgrade(int id) {
    if (id == 0) {
        player.max_hp += 25;
        player.hp += 25;
    } else if (id == 1) {
        player.speed_mul += 0.1;
    } else if (id == 2) {
        player.dmg_mul += 0.15;
    } else if (id == 3) {
        player.mag_mul += 0.25;
    } else if (id == 4) {
        player.regen += 3.5;
    } else if (id == 5) {
        player.magnet += 1;
    } else if (id == 6) {
        player.rate_mul += 0.12;
    } else if (id == 7) {
        player.armor *= 0.85;
    }
}

void player_hurt(double dmg) {
    if (dmg <= 0 || player.hurt_cd > 0 || run.state != ST_MISSION) return;
    player.hp -= dmg * player.armor;
    player.hurt_cd = 0.42;
    view_punch -= 0.045;
    jg3_screen_flash(190, 36, 32, 150);
}

double eye_x(void) { return player.x; }
double eye_y(void) { return player.y + 1.48; }
double eye_z(void) { return player.z; }

void player_update(double dt) {
    double sy, cy, mx, mz, len2, wish_x, wish_z, speed, sp, fall;
    double ox, oy, oz;
    int was_ground;

    view_punch -= view_punch * 9.0 * dt;
    view_yaw_kick -= view_yaw_kick * 12.0 * dt;
    if (player.hurt_cd > 0) player.hurt_cd -= dt;
    if (player.flash > 0) player.flash -= dt;
    if (player.regen > 0 && player.hp < player.max_hp && player.hurt_cd <= 0)
        player.hp += player.regen * dt;
    if (player.hp > player.max_hp) player.hp = player.max_hp;

    sy = g_sin(cam_yaw);
    cy = g_cos(cam_yaw);
    mx = 0;
    mz = 0;
    if (jg3_key(SCAN_W) || jg3_key(SCAN_UP)) { mx += sy; mz += cy; }
    if (jg3_key(SCAN_S) || jg3_key(SCAN_DOWN)) { mx -= sy; mz -= cy; }
    if (jg3_key(SCAN_A) || jg3_key(SCAN_LEFT)) { mx -= cy; mz += sy; }
    if (jg3_key(SCAN_D) || jg3_key(SCAN_RIGHT)) { mx += cy; mz -= sy; }
    len2 = mx * mx + mz * mz;
    wish_x = 0;
    wish_z = 0;
    if (len2 > 0.0001) {
        double inv = 1.0 / g_sqrt(len2);
        wish_x = mx * inv;
        wish_z = mz * inv;
    }
    speed = ((jg3_key(SCAN_LSHIFT) || jg3_key(SCAN_RSHIFT)) ? 7.35 : 4.55) * player.speed_mul;
    if (len2 > 0.0001) {
        player.vx = wish_x * speed;
        player.vz = wish_z * speed;
    } else if (player.on_ground) {
        sp = g_sqrt(player.vx * player.vx + player.vz * player.vz);
        if (sp > 0.0001) {
            double ns = sp - sp * 10.0 * dt;
            if (ns < 0) ns = 0;
            player.vx *= ns / sp;
            player.vz *= ns / sp;
        }
    }

    if (jg3_key(SCAN_SPACE) && !player.jump_was && player.on_ground) {
        player.vy = 5.55;
        player.on_ground = 0;
        jg_play_sound(SND_JUMP);
    }
    player.jump_was = jg3_key(SCAN_SPACE);

    fall = player.vy;
    was_ground = player.on_ground;
    if (player.on_ground && player.vy <= 0) player.vy = -1.2;
    player.vy -= 18.5 * dt;
    if (player.vy < -24) player.vy = -24;

    jg3_move_collide(player.x, player.y, player.z,
                     player.vx * dt, player.vy * dt, player.vz * dt,
                     0.32, 1.55, &ox, &oy, &oz);
    if (player.vy <= 0 && oy >= player.y - 0.0001) {
        if (!was_ground && fall < -8.0) view_punch -= 0.06;
        player.on_ground = 1;
        player.vy = 0;
    } else {
        player.on_ground = 0;
    }
    if (player.vy > 0 && oy <= player.y + 0.0001) player.vy = 0;
    player.x = ox;
    player.y = oy;
    player.z = oz;
}
