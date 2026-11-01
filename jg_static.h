#ifndef JG_STATIC_H
#define JG_STATIC_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void open_window(char *name);
void delay();
void render_clear();
void game_loop();
void render_present();
int init();
int poll_events();
/* Scene file -> one arena. Null on failure. Pointer also stored in scene_slot. */
void *load_scene(const uint8_t *path);
uint64_t scene_slot(int32_t do_set, uint64_t value);
#endif /* JG_STATIC_H */
