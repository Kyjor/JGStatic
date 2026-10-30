#ifndef JG_STATIC_H
#define JG_STATIC_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void open_window(char *name);
void delay();
void render_clear();
void render_present();
int init();
int poll_events();
#endif /* JG_STATIC_H */
