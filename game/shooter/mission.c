#include "game.h"

static void set_theme(void) {
    int m = run.mission_index;
    if (m <= 0) {
        run.theme_r = 28; run.theme_g = 22; run.theme_b = 36;
        run.floor_r = 96; run.floor_g = 86; run.floor_b = 70;
        run.wall_r = 124; run.wall_g = 112; run.wall_b = 98;
    } else if (m == 1) {
        run.theme_r = 16; run.theme_g = 30; run.theme_b = 28;
        run.floor_r = 68; run.floor_g = 98; run.floor_b = 80;
        run.wall_r = 92; run.wall_g = 122; run.wall_b = 104;
    } else if (m == 2) {
        run.theme_r = 14; run.theme_g = 22; run.theme_b = 40;
        run.floor_r = 68; run.floor_g = 82; run.floor_b = 112;
        run.wall_r = 98; run.wall_g = 116; run.wall_b = 146;
    } else if (m == 3) {
        run.theme_r = 38; run.theme_g = 16; run.theme_b = 20;
        run.floor_r = 112; run.floor_g = 72; run.floor_b = 66;
        run.wall_r = 136; run.wall_g = 86; run.wall_b = 78;
    } else {
        run.theme_r = 30; run.theme_g = 14; run.theme_b = 40;
        run.floor_r = 98; run.floor_g = 70; run.floor_b = 116;
        run.wall_r = 126; run.wall_g = 90; run.wall_b = 148;
    }
}

static void open_exit(void) {
    if (run.exit_open) return;
    run.exit_open = 1;
    jg_play_sound(SND_JUMP);
    jg3_screen_flash(70, 190, 120, 100);
}

static void mission_complete(void) {
    meta_add_scrap(12 + run.mission_index * 8);
    jg3_screen_flash(90, 210, 140, 120);
    jg_play_sound(SND_JUMP);
    if (run.mission_index >= 4) {
        run.state = ST_WIN;
        return;
    }
    meta_roll_offers();
    run.state = ST_UPGRADE;
}

void mission_hit_objective(double dmg) {
    double dealt;
    if (run.mission_type != MT_DESTROY || run.obj_hp <= 0) return;
    dealt = dmg * player.dmg_mul;
    run.obj_hp -= dealt;
    floater_add((int)(dealt + 0.5));
    if (run.obj_hp < 0) run.obj_hp = 0;
}

void mission_begin(void) {
    if (run.mission_index >= 4) run.mission_type = MT_CLEAR;
    else run.mission_type = (int)((run.seed + (unsigned)run.mission_index) % 3u);
    run.mission_time = 0;
    run.wave_t = 0;
    run.exit_open = 0;
    run.survive_need = 24.0 + run.mission_index * 4.0;
    run.obj_max = 42.0 + run.mission_index * 18.0;
    run.obj_hp = run.obj_max;
    set_theme();
    procgen_build(run.seed + (unsigned)run.mission_index * 131u);
    enemies_clear();
    pickups_clear();
    floaters_clear();
    procgen_colliders();
    player_spawn(run.start_room);
    player.hp = player.max_hp;
    player.hurt_cd = 0.4;
    weapons_refill();
}

static void mission_rules(double dt) {
    double ex, ez, dx, dz;
    run.mission_time += dt;
    if (run.mission_type == MT_SURVIVE && !run.exit_open) {
        run.wave_t += dt;
        if (run.wave_t > 6.4) {
            run.wave_t = 0;
            spawn_wave();
        }
        if (run.mission_time >= run.survive_need) open_exit();
    } else if (run.mission_type == MT_CLEAR) {
        if (hostiles_left() <= 0) open_exit();
    } else if (run.obj_hp <= 0) {
        open_exit();
    }
    if (!run.exit_open) return;
    room_center(run.exit_room, &ex, &ez);
    ez += 3.15;
    dx = player.x - ex;
    dz = player.z - ez;
    if (dx * dx + dz * dz < 1.45 * 1.45) mission_complete();
}

void mission_frame(double dt) {
    int cur;
    int dead;
    jg3_begin_frame();
    jg3_set_clear(run.theme_r, run.theme_g, run.theme_b);
    if (req_reload) weapons_reload();
    if (req_weapon >= 0) weapons_switch(req_weapon);
    player_update(dt);
    cur = room_index_at(player.x, player.z);
    if (cur >= 0) enemies_fill_room(cur);
    enemies_register();
    if (run.mission_type == MT_DESTROY && run.obj_hp > 0) {
        double ox, oz;
        room_center(run.exit_room, &ox, &oz);
        jg3_add_hit_sphere(OBJ_ID, ox, 1.15, oz, 0.55);
    }
    weapons_update(dt);
    enemies_update(dt);
    dead = player.hp <= 0;
    if (!dead) mission_rules(dt);
    procgen_draw(cur);
    enemies_draw(cur);
    weapons_draw();
    hud_mission();
    if (dead && run.state == ST_MISSION) {
        player.hp = 0;
        run.state = ST_DEAD;
        jg_play_sound(SND_DEATH);
    }
}
