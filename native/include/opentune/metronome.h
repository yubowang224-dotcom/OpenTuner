#pragma once
#include <atomic>
#include <array>
#include <cstdint>
namespace opentune {
struct MetroConfig {
    int bpm=120, beats=4, denominator=4, divisions=1;
    bool accent=true;
    bool valid() const;
    uint32_t pack() const; // validated by the non-RT caller
    uint32_t packedUnchecked() const noexcept; // after control validation
    static MetroConfig unpack(uint32_t word) noexcept;
};
struct MetroPosition {
    uint64_t frames=0, ticks=0, lastTickFrame=0;
    int beat=-1, division=-1;
    uint32_t config=0;
    int gain=100;
    int transport=0; // 0 playing, 1 fading to pause, 2 paused, 3 fading in
    uint64_t outputFrames=0; // callback heartbeat, advances even when music is paused
};
class MetronomeSynth {
public:
    MetronomeSynth(int rate, MetroConfig config);
    bool queue(MetroConfig config) noexcept { if(!config.valid())return false;pending_=config;hasPending_=true;return true; }
    bool setGain(int percent,bool immediate=false) noexcept;
    void release() noexcept;
    void setPaused(bool value) noexcept {pauseRequested_=value;}
    void render(float* output,int count) noexcept;
    bool finished() const { return finished_; }
    MetroPosition position() const noexcept;
    // Host-only long-duration timing exercise: same production event scheduler,
    // advances silent intervals without pretending to have rendered their audio.
    uint64_t advanceToNextTickForTest();
private:
    void tick() noexcept;
    double period() const;
    int rate_, clickLength_, attack_, clickAge_=0, step_=0, releaseAge_=-1;
    int beat_=-1, division_=-1;
    uint64_t frame_=0, ticks_=0, lastTick_=0, anchor_=0, anchorTicks_=0;
    double next_=0, phase_=0, frequency_=1200, amplitude_=0;
    MetroConfig config_,pending_;
    bool hasPending_=false,finished_=false;
    int gainPercent_=100;
    double gain_=1,targetGain_=1,pauseGain_=1;
    bool pauseRequested_=false;
    uint64_t outputFrames_=0;
};
// Atomic fields avoid C++ data races on both 32/64-bit Android. Only callback
// writes; control reader retries boundedly and may retain its last coherent copy.
std::array<double,19> metroSnapshot(uint64_t owner,int rate,bool running,int error,bool pending,const MetroPosition& p) noexcept;
class MetroMailbox {
    static_assert(std::atomic<uint32_t>::is_always_lock_free);
public:
    void publish(const MetroPosition& p) noexcept;
    bool read(MetroPosition& p) const noexcept;
private:
    std::atomic<uint32_t> sequence_{0}, frameLow_{0},frameHigh_{0},tickLow_{0},tickHigh_{0},lastLow_{0},lastHigh_{0},position_{0},config_{0},gain_{100},transport_{0},outputLow_{0},outputHigh_{0};
};
}
