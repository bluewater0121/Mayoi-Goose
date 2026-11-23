#ifndef MAYOI_SHIM_H
#define MAYOI_SHIM_H
#include <stdint.h>

// Pointers into Goose storage: a pointer-bearing Win32 struct field takes the
// address of the first element of a Goose array.
uint64_t gsp16(uint16_t *p);
uint64_t gsp8(uint8_t *p);
uint64_t gsp32(uint32_t *p);
uint64_t gsp64(uint64_t *p);

void gs_memmove(uint8_t *dst, const uint8_t *src, int64_t n);
int64_t gs_setdpi(void);
void gs_memset(uint8_t *dst, int64_t n, uint8_t v);
int64_t gs_clip_get(uint8_t *out, int64_t cap);
int64_t gs_clip_put(const uint8_t *data, int64_t len);
int64_t gs_confirm(uint64_t hwnd, const uint8_t *text, int64_t len);
int64_t gs_pick_folder(uint64_t hwnd, uint8_t *out, int64_t cap);
int64_t gs_pick_file(uint64_t hwnd, uint8_t *out, int64_t cap);
int64_t gs_run_cmd(const uint8_t *cmd, int64_t len, uint8_t *out, int64_t cap,
                   const uint8_t *cwd, int64_t cwdlen);
int64_t gs_path_join(const uint8_t *a, int64_t alen, const uint8_t *b, int64_t blen,
                     uint8_t *out, int64_t cap);
int64_t gs_file_time(const uint8_t *path, int64_t len);
int64_t gs_class_proc(void);
// Draws one Lucide icon (mask table generated from cmd/mayoi/icons.go) tinted
// with a COLORREF into a memory DC; caches the tinted bitmap per size/color.
int64_t gs_icon_draw(uint64_t hdc, int32_t idx, int32_t x, int32_t y, int32_t size, uint32_t color);
#endif





