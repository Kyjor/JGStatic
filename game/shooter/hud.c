#include "game.h"

static int over(int x, int y, int w, int h) {
    return pointer_x >= x && pointer_y >= y && pointer_x < x + w && pointer_y < y + h;
}

static int ui_button(int x, int y, int w, int h, const char *label, int hot) {
    int hover = over(x, y, w, h);
    int on = hot || hover;
    int fr = on ? 72 : 28;
    int fg = on ? 46 : 24;
    int fb = on ? 28 : 34;
    int br = on ? 240 : 110;
    int bg = on ? 186 : 90;
    int bb = on ? 96 : 70;
    int tw = 0;
    const char *p;
    for (p = label; *p; p++) tw += 6;
    jg3_hud_panel(x, y, w, h, fr, fg, fb, br, bg, bb);
    jg3_hud_text(x + (w - tw) / 2, y + (h - 7) / 2, 1, 240, 228, 200, label);
    return hover && mouse_edge;
}

static void cursor(void) {
    jg3_hud_panel(pointer_x, pointer_y, 2, 9, 255, 236, 180, 40, 28, 16);
    jg3_hud_panel(pointer_x, pointer_y, 7, 2, 255, 236, 180, 40, 28, 16);
}

static void offer_button(int index, int x, int y, int w) {
    int sel = index == run.offer_sel;
    if (ui_button(x, y, w, 22, upgrade_label(run.offers[index]), sel)) ui_offer = index;
}

static void shop_buttons(int x, int y) {
    int w;
    for (w = 1; w < WP_COUNT; w++) {
        if (meta_unlocked(w)) continue;
        if (ui_button(x, y, 148, 20, weapon_name(w), 0)) ui_weapon = w;
        jg3_hud_digits(x + 108, y + 6, meta_price(w), 1, 1, 230, 200, 90);
        y += 24;
    }
}

void hud_mission(void) {
    const char *label = "CLEAR";
    int hp, maxhp, filled, gap;
    double sp;
    int cr = 236, cg = 228, cb = 196;
    if (run.mission_index >= 4) label = "BOSS";
    else if (run.mission_type == MT_SURVIVE) label = "SURVIVE";
    else if (run.mission_type == MT_DESTROY) label = "DESTROY";
    jg3_hud_panel(4, 4, 148, 18, 18, 16, 24, 90, 78, 60);
    jg3_hud_text(10, 9, 1, 220, 214, 196, label);
    jg3_hud_digits(92, 9, run.mission_index + 1, 1, 1, 220, 214, 196);
    if (run.mission_type == MT_SURVIVE && !run.exit_open) {
        int left = (int)(run.survive_need - run.mission_time + 0.999);
        if (left < 0) left = 0;
        jg3_hud_digits(110, 9, left, 2, 1, 170, 220, 170);
    }
    if (run.mission_type == MT_DESTROY && run.obj_hp > 0 && run.obj_max > 0) {
        int of = (int)(run.obj_hp * 100.0 / run.obj_max);
        jg3_hud_bar(10, 26, 136, 5, of, 220, 180, 60, 36, 28, 20);
    }
    jg3_hud_panel(214, 4, 102, 18, 22, 18, 12, 140, 110, 40);
    jg3_hud_text(220, 9, 1, 210, 180, 80, "SCRAP");
    jg3_hud_digits(262, 9, meta_scrap(), 1, 1, 230, 200, 90);
    jg3_hud_panel(0, 208, 320, 32, 16, 14, 20, 70, 58, 48);
    hp = (int)(player.hp + 0.5);
    if (hp < 0) hp = 0;
    maxhp = (int)(player.max_hp + 0.5);
    filled = maxhp > 0 ? hp * 100 / maxhp : 0;
    jg3_hud_bar(8, 226, 96, 8, filled, 186, 64, 54, 36, 22, 26);
    jg3_hud_digits(8, 214, hp, 1, 1, 230, 210, 200);
    jg3_hud_text(120, 218, 1, 220, 210, 186, weapon_name(player.weapon));
    jg3_hud_digits(250, 218, player.mag[player.weapon], 2, 1, 236, 220, 170);
    if (player.reloading) jg3_hud_text(124, 118, 1, 230, 200, 120, "RELOAD");
    if (player.charge > 0.02)
        jg3_hud_bar(110, 132, 90, 4, (int)(player.charge * 100), 130, 190, 255, 20, 24, 40);
    if (run.exit_open) jg3_hud_text(136, 28, 1, 120, 220, 140, "EXIT");
    sp = g_sqrt(player.vx * player.vx + player.vz * player.vz);
    gap = 3 + (int)(sp * 0.4);
    if (player.weapon == WP_SHOT) gap += 3;
    if (player.reloading) gap += 2;
    if (player.hurt_cd > 0) { cr = 230; cg = 70; cb = 64; }
    jg3_crosshair(gap, cr, cg, cb);
    floaters_draw();
}

void hud_menu(void) {
    ui_arm = 0;
    ui_drop = 0;
    ui_hub = 0;
    ui_offer = -1;
    ui_weapon = -1;
    jg3_hud_panel(214, 4, 102, 18, 22, 18, 12, 140, 110, 40);
    jg3_hud_text(220, 9, 1, 210, 180, 80, "SCRAP");
    jg3_hud_digits(262, 9, meta_scrap(), 1, 1, 230, 200, 90);
    if (run.state == ST_TITLE) {
        jg3_hud_panel(70, 48, 180, 120, 22, 18, 28, 120, 96, 64);
        jg3_hud_text(124, 68, 2, 236, 214, 150, "RAID");
        if (ui_button(110, 118, 100, 28, "ARM", 0)) ui_arm = 1;
    } else if (run.state == ST_HUB) {
        int w;
        jg3_hud_panel(8, 28, 304, 196, 18, 16, 24, 80, 68, 56);
        jg3_hud_text(16, 36, 1, 220, 214, 196, "LOADOUT");
        for (w = 0; w < WP_COUNT; w++) {
            int x = 16 + w * 74;
            if (meta_unlocked(w)) {
                if (ui_button(x, 50, 70, 22, weapon_name(w), run.loadout == w)) ui_weapon = w;
            } else {
                if (ui_button(x, 50, 70, 22, "", 0)) ui_weapon = w;
                jg3_hud_text(x + 6, 57, 1, 230, 200, 90, "BUY");
                jg3_hud_digits(x + 32, 57, meta_price(w), 1, 1, 230, 200, 90);
            }
        }
        jg3_hud_text(16, 82, 1, 190, 186, 170, "DROP GEAR");
        offer_button(0, 16, 96, 200);
        offer_button(1, 16, 122, 200);
        offer_button(2, 16, 148, 200);
        if (ui_button(224, 148, 76, 22, "DROP", 1)) ui_drop = 1;
    } else if (run.state == ST_UPGRADE) {
        jg3_hud_panel(40, 36, 240, 160, 18, 16, 24, 90, 78, 60);
        jg3_hud_text(112, 48, 1, 220, 214, 196, "PICK ONE");
        offer_button(0, 56, 70, 208);
        offer_button(1, 56, 100, 208);
        offer_button(2, 56, 130, 208);
    } else if (run.state == ST_DEAD || run.state == ST_WIN) {
        jg3_hud_panel(50, 28, 220, 180, 18, 16, 24, 90, 70, 60);
        if (run.state == ST_DEAD) jg3_hud_text(136, 40, 2, 220, 80, 70, "DEAD");
        else jg3_hud_text(142, 40, 2, 140, 220, 150, "WIN");
        shop_buttons(86, 78);
        if (ui_button(100, 168, 120, 24, "HUB", 1)) ui_hub = 1;
    }
    cursor();
}
