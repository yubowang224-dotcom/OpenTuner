#include "opentune/c_api.h"
#include "opentune/analyzer.h"
#include <stdexcept>
struct ot_analyzer { opentune::Analyzer analyzer; ot_analyzer(int rate, double a4) : analyzer(rate, a4) {} };
extern "C" {
uint32_t ot_abi_version() { return 1; }
ot_analyzer* ot_create(int32_t rate, double a4) { try { return new ot_analyzer(rate, a4); } catch (...) { return nullptr; } }
void ot_destroy(ot_analyzer* handle) { delete handle; }
int32_t ot_window_size(const ot_analyzer* h) { return h ? h->analyzer.windowSize() : OT_INVALID; }
int32_t ot_analyze(ot_analyzer* h, const float* pcm, int32_t count, double time, ot_result* out) {
    if (!h || !out || out->size != sizeof(ot_result)) return OT_INVALID;
    *out = {}; out->size = sizeof(ot_result); out->midi = -1;
    try {
        const auto r = h->analyzer.analyze(pcm, count, time, false);
        *out = {sizeof(ot_result), static_cast<int32_t>(r.validity), r.midi, r.sequence,
            r.timeSeconds, r.rawHz, r.trackedHz, r.cents, r.score, r.rmsDb, r.clipFraction, r.computeMs};
        return OT_OK;
    } catch (const std::invalid_argument&) { return OT_INVALID; } catch (...) { return OT_INTERNAL; }
}
}
