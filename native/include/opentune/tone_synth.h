#pragma once
#include <cstdint>
#include <array>
namespace opentune {
enum class ToneVoice { sine=0, guitar=1 };
// Callback-owned synthesis state. Control thread signals release through its
// owner's atomic flag; no allocation, locks or shared floating-point writes.
class ToneSynth {
public:
    ToneSynth(int sampleRate, double hz, ToneVoice voice=ToneVoice::sine, double level=1);
    void release();
    void render(float* output, int count);
    bool finished() const { return finished_; }
private:
    int rate_, attack_, releaseLength_, releaseAt_ = -1;
    int64_t frame_ = 0;
    double phase_ = 0, step_, releaseGain_ = 0;
    bool finished_ = false;
    ToneVoice voice_;
    double level_;
    std::array<double,8> partials_{}, decay_{};
    int partialCount_=0;
};
}
