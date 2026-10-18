#pragma once
#include "opentune/tone_synth.h"
#include "opentune/metronome.h"
#include <oboe/Oboe.h>
#include <atomic>
#include <array>
#include <chrono>
#include <memory>
#include <thread>

// A single output owner for either reference or metronome. Control is serialized
// by Kotlin; all oscillator/envelope/scheduler state belongs to the callback.
class ReferenceEngine final : public oboe::AudioStreamDataCallback, public oboe::AudioStreamErrorCallback {
public:
    int64_t owner=0;
    bool isMetronome() const {return metronomeMode_;}
    std::string start(int64_t token,double hz,opentune::ToneVoice voice=opentune::ToneVoice::sine,double gain=1) {
        owner=token;const auto error=open();if(!error.empty())return error;
        tone_=std::make_unique<opentune::ToneSynth>(stream_->getSampleRate(),hz,voice,gain);
        return begin();
    }
    std::string startMetronome(int64_t token,opentune::MetroConfig config,int gain=100) {
        if(gain<0||gain>100)return "invalid_gain";
        owner=token;metronomeMode_=true;const auto word=config.pack();
        const auto error=open();if(!error.empty())return error;
        metro_=std::make_unique<opentune::MetronomeSynth>(stream_->getSampleRate(),config);
        metro_->setGain(gain,true);requestedGain_.store(gain);seenGain_=gain;
        requested_.store(word);seenConfig_=word;cached_=metro_->position();mailbox_.publish(cached_);
        return begin();
    }
    void updateMetronome(opentune::MetroConfig config,int gain) {if(gain<0||gain>100)return;requested_.store(config.pack(),std::memory_order_release);requestedGain_.store(gain,std::memory_order_release);}
    void pauseMetronome(bool value) noexcept {requestedPause_.store(value?1u:0u,std::memory_order_release);}
    bool playing() const {return !finished_.load(std::memory_order_acquire)&&error_.load()==0;}
    int rate() const {return stream_?stream_->getSampleRate():0;}
    int error() const {return error_.load();}
    std::array<double,19> metronomeSnapshot() {
        opentune::MetroPosition newest;
        if(mailbox_.read(newest))cached_=newest;
        return opentune::metroSnapshot(owner,rate(),playing(),error(),cached_.config!=requested_.load()||cached_.gain!=requestedGain_.load(),cached_);
    }
    ~ReferenceEngine() override {
        if(stream_) {
            releasing_.store(true,std::memory_order_release);
            for(int i=0;i<60&&playing();++i)std::this_thread::sleep_for(std::chrono::milliseconds(2));
            stream_->requestStop();stream_->close();
        }
    }
    oboe::DataCallbackResult onAudioReady(oboe::AudioStream*,void* output,int32_t count) override {
        if(!output||count<=0){error_.store(static_cast<int>(oboe::Result::ErrorInternal));return oboe::DataCallbackResult::Stop;}
        if(metronomeMode_) {
            const auto word=requested_.load(std::memory_order_acquire);
            if(word!=seenConfig_){metro_->queue(opentune::MetroConfig::unpack(word));seenConfig_=word;}
            const auto gain=requestedGain_.load(std::memory_order_acquire);
            if(gain!=seenGain_){metro_->setGain(static_cast<int>(gain));seenGain_=gain;}
            const auto pause=requestedPause_.load(std::memory_order_acquire);
            if(pause!=seenPause_){metro_->setPaused(pause!=0);seenPause_=pause;}
            if(releasing_.load(std::memory_order_acquire))metro_->release();
            metro_->render(static_cast<float*>(output),count);mailbox_.publish(metro_->position());
            if(metro_->finished())finished_.store(true,std::memory_order_release);
        } else {
            if(releasing_.load(std::memory_order_acquire))tone_->release();
            tone_->render(static_cast<float*>(output),count);
            if(tone_->finished())finished_.store(true,std::memory_order_release);
        }
        return finished_.load()?oboe::DataCallbackResult::Stop:oboe::DataCallbackResult::Continue;
    }
    bool onError(oboe::AudioStream*,oboe::Result error) override {error_.store(static_cast<int>(error));return true;}
private:
    std::string open() {
        oboe::AudioStreamBuilder b;
        b.setDirection(oboe::Direction::Output)->setChannelCount(1)->setFormat(oboe::AudioFormat::Float)
            ->setFormatConversionAllowed(true)->setSharingMode(oboe::SharingMode::Shared)
            ->setUsage(oboe::Usage::Media)->setContentType(oboe::ContentType::Music)
            ->setPerformanceMode(oboe::PerformanceMode::LowLatency)->setDataCallback(this)->setErrorCallback(this);
        auto error=b.openStream(stream_);
        if(error!=oboe::Result::OK){b.setPerformanceMode(oboe::PerformanceMode::None);error=b.openStream(stream_);}
        if(error!=oboe::Result::OK)return oboe::convertToText(error);
        if(stream_->getChannelCount()!=1||stream_->getFormat()!=oboe::AudioFormat::Float)return "unsupported_format";
        return "";
    }
    std::string begin() {const auto r=stream_->requestStart();return r==oboe::Result::OK?"":oboe::convertToText(r);}
    std::shared_ptr<oboe::AudioStream> stream_;
    std::unique_ptr<opentune::ToneSynth> tone_;
    std::unique_ptr<opentune::MetronomeSynth> metro_;
    opentune::MetroMailbox mailbox_;
    opentune::MetroPosition cached_; // only serialized control reads/writes
    bool metronomeMode_=false;
    uint32_t seenConfig_=0; // callback-only after requestStart
    uint32_t seenGain_=100,seenPause_=0;
    std::atomic<uint32_t> requested_{0};
    std::atomic<uint32_t> requestedGain_{100},requestedPause_{0};
    std::atomic<bool> releasing_{false},finished_{false};
    std::atomic<int> error_{0};
};
