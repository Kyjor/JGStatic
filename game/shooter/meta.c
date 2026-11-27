#include "game.h"

static int unlocked[WP_COUNT] = {1, 0, 0, 0};
static int bank;
static unsigned run_serial = 1;
static const int PRICES[WP_COUNT] = {0, 28, 52, 84};
static const char *LABELS[8] = {
    "MAX HP", "SPEED", "DAMAGE", "MAG", "REGEN", "MAGNET", "RATE", "ARMOR"
};

void meta_boot(void) {
    unlocked[0] = 1;
    unlocked[1] = 0;
    unlocked[2] = 0;
    unlocked[3] = 0;
    bank = 0;
    run_serial = 1;
    run.state = ST_TITLE;
    run.loadout = 0;
    run.offer_sel = 0;
    player_reset_run();
}

int meta_unlocked(int weapon) {
    if (weapon < 0 || weapon >= WP_COUNT) return 0;
    return unlocked[weapon];
}

int meta_scrap(void) { return bank; }

int meta_price(int weapon) {
    if (weapon < 0 || weapon >= WP_COUNT) return 0;
    return PRICES[weapon];
}

void meta_add_scrap(int amount) {
    if (amount > 0) bank += amount;
}

void meta_try_buy(int weapon) {
    if (weapon <= 0 || weapon >= WP_COUNT) return;
    if (unlocked[weapon]) return;
    if (bank < PRICES[weapon]) return;
    bank -= PRICES[weapon];
    unlocked[weapon] = 1;
    jg_play_sound(SND_JUMP);
}

const char *upgrade_label(int id) {
    if (id < 0 || id > 7) return "?";
    return LABELS[id];
}

void meta_roll_offers(void) {
    int used_a = -1;
    int used_b = -1;
    int i;
    for (i = 0; i < 3; i++) {
        int guard = 0;
        int id = 0;
        do {
            id = (int)(game_rand() % 8);
            guard++;
        } while (guard < 16 && (id == used_a || id == used_b));
        run.offers[i] = id;
        if (i == 0) used_a = id;
        if (i == 1) used_b = id;
    }
    run.offer_sel = 0;
}

static void cycle_weapon(int dir) {
    int i;
    int w = run.loadout;
    for (i = 0; i < WP_COUNT; i++) {
        w += dir;
        if (w < 0) w = WP_COUNT - 1;
        if (w >= WP_COUNT) w = 0;
        if (meta_unlocked(w)) {
            run.loadout = w;
            return;
        }
    }
}

static void start_run(void) {
    run.seed = run_serial * 997u + 13u;
    run_serial++;
    run.mission_index = 0;
    player_reset_run();
    player_apply_upgrade(run.offers[run.offer_sel]);
    player.weapon = run.loadout;
    if (!meta_unlocked(player.weapon)) player.weapon = WP_SIDE;
    weapons_refill();
    mission_begin();
    run.state = ST_MISSION;
}

static void confirm_upgrade(void) {
    player_apply_upgrade(run.offers[run.offer_sel]);
    run.mission_index++;
    mission_begin();
    run.state = ST_MISSION;
}

void menu_frame(double dt) {
    (void)dt;
    jg3_begin_frame();
    jg3_set_clear(10, 8, 16);
    hud_menu();
    if (run.state == ST_TITLE) {
        if (req_confirm || ui_arm) {
            run.state = ST_HUB;
            run.loadout = WP_SIDE;
            meta_roll_offers();
        }
    } else if (run.state == ST_HUB) {
        if (req_left) cycle_weapon(-1);
        if (req_right) cycle_weapon(1);
        if (req_up) run.offer_sel = (run.offer_sel + 2) % 3;
        if (req_down) run.offer_sel = (run.offer_sel + 1) % 3;
        if (ui_weapon >= 0) {
            if (meta_unlocked(ui_weapon)) run.loadout = ui_weapon;
            else meta_try_buy(ui_weapon);
        }
        if (ui_offer >= 0) run.offer_sel = ui_offer;
        if (req_confirm || ui_drop) start_run();
    } else if (run.state == ST_UPGRADE) {
        if (req_left) run.offer_sel = (run.offer_sel + 2) % 3;
        if (req_right) run.offer_sel = (run.offer_sel + 1) % 3;
        if (req_up) run.offer_sel = (run.offer_sel + 2) % 3;
        if (req_down) run.offer_sel = (run.offer_sel + 1) % 3;
        if (ui_offer >= 0) run.offer_sel = ui_offer;
        if (req_weapon >= 0 && req_weapon < 3) {
            run.offer_sel = req_weapon;
            confirm_upgrade();
        } else if (req_confirm || ui_offer >= 0) {
            confirm_upgrade();
        }
    } else if (run.state == ST_DEAD || run.state == ST_WIN) {
        if (req_weapon >= 1 && req_weapon <= 3) meta_try_buy(req_weapon);
        if (ui_weapon >= 1) meta_try_buy(ui_weapon);
        if (req_confirm || ui_hub) {
            run.state = ST_HUB;
            meta_roll_offers();
        }
    }
}
