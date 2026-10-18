#include "opentune/metronome.h"
#include <algorithm>
#include <cmath>
#include <stdexcept>
namespace opentune {
namespace { constexpr double pi=3.14159265358979323846; }
bool MetroConfig::valid() const { return bpm>=20&&bpm<=300&&beats>=1&&beats<=12&&(denominator==4||denominator==8)&&divisions>=1&&divisions<=4; }
uint32_t MetroConfig::pack() const {
    if(!valid()) throw std::invalid_argument("invalid metronome configuration");
    return packedUnchecked();
}
uint32_t MetroConfig::packedUnchecked() const noexcept {
    return static_cast<uint32_t>(bpm-20)|static_cast<uint32_t>(beats-1)<<9|static_cast<uint32_t>(denominator==8)<<13|static_cast<uint32_t>(divisions-1)<<14|static_cast<uint32_t>(accent)<<16;
}
MetroConfig MetroConfig::unpack(uint32_t w) noexcept { return {static_cast<int>(w&511)+20,static_cast<int>((w>>9)&15)+1,(w&(1u<<13))?8:4,static_cast<int>((w>>14)&3)+1,(w&(1u<<16))!=0}; }
MetronomeSynth::MetronomeSynth(int rate,MetroConfig c):rate_(rate),clickLength_(rate*12/1000),attack_(std::max(1,rate/1000)),config_(c) {
    if(rate<8000||rate>192000||!c.valid())throw std::invalid_argument("unsupported metronome rate/configuration");
}
double MetronomeSynth::period() const { return rate_*60.0/config_.bpm*4/config_.denominator/config_.divisions; }
void MetronomeSynth::tick() noexcept {
    if(hasPending_) {config_=pending_;hasPending_=false;step_=0;anchor_=frame_;anchorTicks_=0;}
    beat_=step_/config_.divisions;division_=step_%config_.divisions;
    const bool main=division_==0;
    const bool strong=main&&config_.accent&&beat_==0;
    const bool secondary=main&&config_.accent&&config_.beats==6&&config_.denominator==8&&beat_==3;
    // +6.0206 dB digital amplitude over Tools1, with a 0.44 FS ceiling.
    // Relative accents, synthesis envelope and sample-clock timing stay intact.
    amplitude_=2.0*(strong?.22:secondary?.18:main?.14:.07);
    frequency_=strong?1700:secondary?1450:main?1200:850;
    clickAge_=0;phase_=0;lastTick_=frame_;++ticks_;
    step_=(step_+1)%(config_.beats*config_.divisions);
    ++anchorTicks_;next_=static_cast<double>(anchor_)+anchorTicks_*period();
}
void MetronomeSynth::release() noexcept { if(releaseAge_<0)releaseAge_=0; }
bool MetronomeSynth::setGain(int percent,bool immediate) noexcept {
    if(percent<0||percent>100)return false;
    gainPercent_=percent;targetGain_=percent/100.;if(immediate||(pauseRequested_&&pauseGain_<=0))gain_=targetGain_;return true;
}
void MetronomeSynth::render(float* output,int count) noexcept {
    for(int i=0;i<count;++i) {
        ++outputFrames_;
        if(pauseRequested_&&pauseGain_<=0&&releaseAge_<0) {gain_=targetGain_;output[i]=0;continue;}
        const double transportStep=1./std::max(1,rate_/200);
        pauseGain_+=std::clamp((pauseRequested_?0.:1.)-pauseGain_,-transportStep,transportStep);
        if(pauseRequested_&&pauseGain_<=0)gain_=targetGain_; // also the exact fade-completion sample
        if(!finished_&&releaseAge_<0&&static_cast<double>(frame_)>=next_)tick();
        double value=0;
        if(!finished_&&clickAge_<clickLength_) {
            const double age=static_cast<double>(clickAge_)/clickLength_;
            const double envelope=std::min(1.0,static_cast<double>(clickAge_)/attack_)*.5*(1+std::cos(pi*age));
            value=amplitude_*envelope*std::sin(phase_);
        }
        if(releaseAge_>=0) {
            const int length=std::max(1,rate_/200);
            value*=.5*(1+std::cos(pi*std::min(releaseAge_,length)/length));
            if(++releaseAge_>length)finished_=true;
        }
        const double slew=1./std::max(1,rate_/200);
        gain_+=std::clamp(targetGain_-gain_,-slew,slew);
        output[i]=finished_?0:static_cast<float>(value*gain_*pauseGain_);
        ++frame_;if(clickAge_<clickLength_)++clickAge_;phase_+=2*pi*frequency_/rate_;if(phase_>=2*pi)phase_-=2*pi;
    }
}
MetroPosition MetronomeSynth::position() const noexcept { return {frame_,ticks_,lastTick_,beat_,division_,config_.packedUnchecked(),gainPercent_,pauseRequested_?(pauseGain_<=0?2:1):(pauseGain_<1?3:0),outputFrames_}; }
uint64_t MetronomeSynth::advanceToNextTickForTest() {
    frame_=static_cast<uint64_t>(std::ceil(next_));tick();return frame_;
}
std::array<double,19> metroSnapshot(uint64_t owner,int rate,bool running,int error,bool pending,const MetroPosition& p) noexcept {
    const auto c=MetroConfig::unpack(p.config);
    return {3,static_cast<double>(owner),running?1.:0.,static_cast<double>(rate),static_cast<double>(p.frames),static_cast<double>(p.beat),static_cast<double>(p.division),static_cast<double>(p.ticks),static_cast<double>(c.bpm),static_cast<double>(c.beats),static_cast<double>(c.denominator),static_cast<double>(c.divisions),c.accent?1.:0.,static_cast<double>(error),pending?1.:0.,static_cast<double>(p.lastTickFrame),static_cast<double>(p.gain),static_cast<double>(p.transport),static_cast<double>(p.outputFrames)};
}
void MetroMailbox::publish(const MetroPosition& p) noexcept {
    sequence_.fetch_add(1,std::memory_order_acq_rel);
    frameLow_.store(static_cast<uint32_t>(p.frames),std::memory_order_relaxed);frameHigh_.store(static_cast<uint32_t>(p.frames>>32),std::memory_order_relaxed);
    tickLow_.store(static_cast<uint32_t>(p.ticks),std::memory_order_relaxed);tickHigh_.store(static_cast<uint32_t>(p.ticks>>32),std::memory_order_relaxed);
    lastLow_.store(static_cast<uint32_t>(p.lastTickFrame),std::memory_order_relaxed);lastHigh_.store(static_cast<uint32_t>(p.lastTickFrame>>32),std::memory_order_relaxed);
    position_.store(static_cast<uint32_t>(p.beat+1)|(static_cast<uint32_t>(p.division+1)<<8),std::memory_order_relaxed);config_.store(p.config,std::memory_order_relaxed);
    gain_.store(static_cast<uint32_t>(p.gain),std::memory_order_relaxed);
    transport_.store(static_cast<uint32_t>(p.transport),std::memory_order_relaxed);
    outputLow_.store(static_cast<uint32_t>(p.outputFrames),std::memory_order_relaxed);outputHigh_.store(static_cast<uint32_t>(p.outputFrames>>32),std::memory_order_relaxed);
    sequence_.fetch_add(1,std::memory_order_release);
}
bool MetroMailbox::read(MetroPosition& p) const noexcept {
    for(int i=0;i<4;++i) {
        const auto before=sequence_.load(std::memory_order_acquire);if(before&1)continue;
        p.frames=frameLow_.load(std::memory_order_relaxed)|(static_cast<uint64_t>(frameHigh_.load(std::memory_order_relaxed))<<32);
        p.ticks=tickLow_.load(std::memory_order_relaxed)|(static_cast<uint64_t>(tickHigh_.load(std::memory_order_relaxed))<<32);
        p.lastTickFrame=lastLow_.load(std::memory_order_relaxed)|(static_cast<uint64_t>(lastHigh_.load(std::memory_order_relaxed))<<32);
        const auto pos=position_.load(std::memory_order_relaxed);p.beat=static_cast<int>(pos&255)-1;p.division=static_cast<int>((pos>>8)&255)-1;p.config=config_.load(std::memory_order_relaxed);
        p.gain=static_cast<int>(gain_.load(std::memory_order_relaxed));
        p.transport=static_cast<int>(transport_.load(std::memory_order_relaxed));
        p.outputFrames=outputLow_.load(std::memory_order_relaxed)|(static_cast<uint64_t>(outputHigh_.load(std::memory_order_relaxed))<<32);
        std::atomic_thread_fence(std::memory_order_acquire);
        if(sequence_.load(std::memory_order_relaxed)==before)return true;
    }
    return false;
}
}
