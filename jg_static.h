#ifndef JG_STATIC_H
#define JG_STATIC_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void open_window(char *name);
void delay();
void render_clear();
int game_loop(void);
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
void set_entity_velocity_x(int32_t index, double vx);
void set_entity_velocity_y(int32_t index, double vy);
int entity_on_ground(int32_t index);
void camera_set_position(double x, double y);
int game_wants_3d(void);
double game_model_yaw(void);
double game_cam_x(void);
double game_cam_y(void);
double game_cam_z(void);
double game_cam_yaw(void);
double game_cam_pitch(void);
int game_consume_shot(void);
void game_mouse_moved(int dx, int dy);
void game_mouse_pressed(int button);
#endif /* JG_STATIC_H */
