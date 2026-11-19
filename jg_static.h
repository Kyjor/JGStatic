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
/* Pan the view. +x moves right, +y moves down, in world units. */
void camera_move(double dx, double dy);
void entity_move(int32_t index, double dx, double dy);
double get_entity_position_x(int32_t index);
double get_entity_position_y(int32_t index);
void set_entity_position(int32_t index, double x, double y);
void camera_set_position(double x, double y);
#endif /* JG_STATIC_H */
