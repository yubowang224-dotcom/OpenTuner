#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// ABI v1. Caller owns input and output, which are never retained. Handle is
// exclusively owned by one worker; destroy only after all calls have returned.
typedef struct ot_analyzer ot_analyzer;
typedef struct ot_result {
    uint32_t size;
    int32_t validity, midi;
    uint64_t sequence;
    double end_seconds, raw_hz, tracked_hz, cents, score, rms_db, clip_fraction, compute_ms;
} ot_result;
enum { OT_OK = 0, OT_INVALID = -1, OT_INTERNAL = -2 };
uint32_t ot_abi_version(void);
ot_analyzer* ot_create(int32_t sample_rate, double reference_hz);
void ot_destroy(ot_analyzer* handle);
int32_t ot_window_size(const ot_analyzer* handle);
int32_t ot_analyze(ot_analyzer* handle, const float* pcm, int32_t count, double end_seconds, ot_result* result);
#ifdef __cplusplus
}
#endif
