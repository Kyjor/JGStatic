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
void game_mouse_released(int button);
/* Absolute pointer in the 320x240 framebuffer. */
void game_pointer(int x, int y);

/* 3D world. Draws and hit spheres are cleared by jg3_begin_frame.
   Colliders stay until jg3_clear_colliders. Boxes are centered.
   AABBs are min-corner plus size. Raycast returns a sphere id,
   -2 for an AABB, or -1 for a miss. hit_mask bit 0 = AABBs, bit 1 = spheres. */
void jg3_begin_frame(void);
void jg3_set_clear(int r, int g, int b);
void jg3_draw_box(double x, double y, double z, double sx, double sy, double sz, int r, int g, int b);
void jg3_draw_cylinder(double x, double y, double z, double radius, double height, int segs, int r, int g, int b);
void jg3_draw_quad(double x0, double y0, double z0, double x1, double y1, double z1, double x2, double y2, double z2, double x3, double y3, double z3, int r, int g, int b);
void jg3_draw_grid(double x, double y, double z, double sx, double sz, double step, int r, int g, int b);
/* Box in a camera basis. sx along right, sy along up, sz along forward. */
void jg3_draw_viewbox(double x, double y, double z, double sx, double sy, double sz, double rx, double ry, double rz, double ux, double uy, double uz, double fx, double fy, double fz, int r, int g, int b);
void jg3_clear_colliders(void);
void jg3_add_aabb(double x, double y, double z, double sx, double sy, double sz);
void jg3_move_collide(double px, double py, double pz, double dx, double dy, double dz, double radius, double height, double *out_x, double *out_y, double *out_z);
void jg3_add_hit_sphere(int id, double x, double y, double z, double radius);
int jg3_raycast(double ox, double oy, double oz, double dx, double dy, double dz, double max_t, int hit_mask, int ignore_id, double *out_t);
void jg3_hud_bar(int x, int y, int w, int h, int filled, int r, int g, int b, int br, int bg, int bb);
void jg3_hud_digits(int x, int y, int value, int min_digits, int scale, int r, int g, int b);
void jg3_hud_text(int x, int y, int scale, int r, int g, int b, const char *text);
void jg3_crosshair(int gap, int r, int g, int b);
/* Filled rect with a 1px border. r,g,b is the fill. br,bg,bb is the border. */
void jg3_hud_panel(int x, int y, int w, int h, int r, int g, int b, int br, int bg, int bb);
/* 1 hides the cursor and captures the mouse. 0 shows it for menus. */
void jg3_mouse_look(int on);
/* 1 while the SDL scancode is held. Indexed like SDL_Scancode. */
int jg3_key(int scancode);
void jg3_screen_flash(int r, int g, int b, int amount);
void jg_play_sound(int id);

#ifdef __cplusplus
}
#endif
#endif /* JG_STATIC_H */
