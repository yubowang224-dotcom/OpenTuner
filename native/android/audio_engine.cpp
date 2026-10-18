#include "opentune/analyzer.h"
#include "opentune/waveform.h"
#include "opentune/piano_analyzer.h"
#include "opentune/partial_analyzer.h"
#include "reference_engine.h"
#include "opentune/spsc_ring.h"
#include <oboe/Oboe.h>
#include <jni.h>
#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <thread>
#include <algorithm>
#include <cmath>
#include <android/api-level.h>
#include <android/log.h>

namespace {
using Clock = std::chrono::steady_clock;
// JNI control methods are serialized by one Kotlin executor. Only the callback
// produces audio; only the worker consumes it. All storage precedes requestStart.
class Engine final : public oboe::AudioStreamDataCallback, public oboe::AudioStreamErrorCallback {
public:
    int64_t session() const { return session_; } // serialized control thread only
    std::string start(int64_t session, bool unprocessed, double reference,bool piano,int partialMidi=-1,double associationHz=0) {
        session_ = session; reference_=reference;partialMidi_=partialMidi;
        oboe::Result opened = oboe::Result::ErrorInternal;
        for (int attempt = 0; attempt < 3; ++attempt) {
            oboe::AudioStreamBuilder b;
            b.setDirection(oboe::Direction::Input)->setChannelCount(1)->setFormat(oboe::AudioFormat::Float)
                ->setFormatConversionAllowed(true)->setSharingMode(oboe::SharingMode::Shared)
                ->setPerformanceMode(attempt == 0 ? oboe::PerformanceMode::LowLatency : oboe::PerformanceMode::None)
                ->setInputPreset(unprocessed && attempt < 2 ? oboe::InputPreset::Unprocessed : oboe::InputPreset::VoiceRecognition)
                ->setDataCallback(this)->setErrorCallback(this);
            if (android_get_device_api_level() >= 28) b.setSessionId(oboe::SessionId::Allocate);
            // No sample-rate request and no app resampling. Oboe negotiates the
            // device stream rate; mono/float conversion may be performed by Oboe.
            opened = b.openStream(stream_);
            if (opened == oboe::Result::OK) break;
        }
        if (opened != oboe::Result::OK) return oboe::convertToText(opened);
        rate_ = stream_->getSampleRate();
        if (stream_->getChannelCount() != 1 || stream_->getFormat() != oboe::AudioFormat::Float || rate_ < 8000 || rate_ > 192000) {
            stream_->close(); stream_.reset(); return "unsupported_format";
        }
        channels_ = stream_->getChannelCount(); format_ = static_cast<int>(stream_->getFormat());
        api_ = static_cast<int>(stream_->getAudioApi()); burst_ = stream_->getFramesPerBurst();
        capacity_ = stream_->getBufferCapacityInFrames(); device_ = stream_->getDeviceId();
        preset_ = static_cast<int>(stream_->getInputPreset());
        recordingSession_ = static_cast<int>(stream_->getSessionId());
        // One control-thread diagnostic per open. Never log samples or RT frames.
        __android_log_print(ANDROID_LOG_INFO, "OpenTuneAudio", "session=%lld rate=%d channels=%d format=%d api=%d burst=%d capacity=%d device=%d preset=%d processing=unknown",
            static_cast<long long>(session_),rate_,channels_,format_,api_,burst_,capacity_,device_,preset_);
        if(partialMidi>=21)partial_=std::make_unique<opentune::PartialAnalyzer>(rate_,reference,partialMidi,associationHz);
        else if(piano)piano_=std::make_unique<opentune::PianoAnalyzer>(rate_,reference);
        else analyzer_ = std::make_unique<opentune::Analyzer>(rate_, reference);
        waveform_ = std::make_unique<opentune::WaveformDisplay>(rate_);
        frame_.resize(windowSize()); scratch_.resize(std::max(1, rate_ / 50));
        running_.store(true);
        worker_ = std::thread([this] { work(); });
        const auto started = stream_->requestStart();
        if (started != oboe::Result::OK) { stop(); return oboe::convertToText(started); }
        return "";
    }
    void stop() {
        // Closing waits for data callback completion before ring/engine deletion.
        if (stream_) { stream_->requestStop(); stream_->close(); }
        running_.store(false, std::memory_order_release);
        if (worker_.joinable()) worker_.join();
        stream_.reset(); analyzer_.reset(); piano_.reset();partial_.reset();waveform_.reset();
    }
    ~Engine() override { stop(); }
    oboe::DataCallbackResult onAudioReady(oboe::AudioStream*, void* data, int32_t count) override {
        // Strict RT boundary: bounded sample copy + lock-free 32-bit atomics only.
        if (!data || count <= 0) { error_.store(static_cast<int32_t>(oboe::Result::ErrorInternal)); return oboe::DataCallbackResult::Stop; }
        const auto copied = ring_.push(static_cast<const float*>(data), static_cast<size_t>(count));
        samples_.fetch_add(static_cast<uint32_t>(count), std::memory_order_relaxed);
        if (copied != static_cast<size_t>(count)) dropped_.fetch_add(static_cast<uint32_t>(count - copied), std::memory_order_release);
        return oboe::DataCallbackResult::Continue;
    }
    bool onError(oboe::AudioStream*, oboe::Result error) override {
        error_.store(static_cast<int32_t>(error), std::memory_order_release);
        // Our serialized control executor owns close; avoid a second Oboe close
        // racing that owner. Polling sees the error and stops/releases the stream.
        return true;
    }
    std::vector<double> snapshot(bool details) {
        visuals_.store(details, std::memory_order_relaxed);
        std::lock_guard<std::mutex> lock(resultMutex_);
        const auto& r = latest_;
        const auto& wave=latestWave_;
        const bool includeVisuals=details && wave.count>0 && r.spectrumCount>0;
        const double age = r.sequence ? sourceLagMs_ + std::chrono::duration<double, std::milli>(Clock::now() - published_).count() : 1e9;
        std::vector<double> values(48 + (includeVisuals ? wave.count + r.spectrumCount : 0), 0);
        values[0]=partial_?4:3; values[1]=static_cast<double>(session_); values[2]=static_cast<double>(r.sequence);
        values[3]=r.timeSeconds; values[4]=age; values[5]=static_cast<int>(r.validity);
        values[6]=r.rawHz; values[7]=r.trackedHz; values[8]=r.midi; values[9]=r.cents;
        values[10]=r.score; values[11]=r.rmsDb; values[12]=r.clipFraction; values[13]=r.computeMs;
        values[14]=rate_; values[15]=channels_; values[16]=format_; values[17]=api_;
        values[18]=burst_; values[19]=capacity_; values[20]=samples_.load(); values[21]=dropped_.load()+consumerDropped_.load();
        values[22]=discontinuities_; values[23]=error_.load(); values[24]=includeVisuals?wave.duration():0;
        values[25]=r.spectrumBinHz; values[26]=includeVisuals ? r.spectrumCount : 0;
        values[27]=device_; values[28]=preset_; values[29]=recordingSession_;
        values[30]=r.noiseFloorDb; values[31]=r.noiseKnown; values[32]=r.levelMarginDb;
        values[33]=r.centroidHz; values[34]=r.harmonicRatio; values[35]=r.cmndfMinimum;
        values[36]=r.candidateCount; values[37]=r.pitchRate; values[38]=r.consistency;
        values[39]=static_cast<int>(r.trackState); values[40]=r.frameQualified; values[41]=r.score;
        if(partial_) {
            opentune::appendPartialPayload(values,latestPartial_,partialMidi_);
            return values;
        }
        if (includeVisuals) {
            values[42]=wave.count; values[43]=wave.stepSeconds; values[44]=wave.startSeconds;
            values[45]=wave.triggered?1:0; values[46]=wave.decimation; values[47]=wave.computeMs;
            std::copy_n(wave.samples.begin(),wave.count,values.begin()+48);
            std::copy_n(r.spectrum.begin(), r.spectrumCount, values.begin()+48+wave.count);
        }
        return values;
    }
private:
    int windowSize()const{return partial_?partial_->windowSize():piano_?piano_->windowSize():analyzer_->windowSize();}
    int hopSize()const{return partial_?partial_->hopSize():piano_?piano_->hopSize():analyzer_->hopSize();}
    void resetAnalysis(){if(partial_)partial_->reset();else if(piano_)piano_->reset();else analyzer_->reset();}
    opentune::Analysis analyze(double end,bool visuals){return piano_?piano_->analyze(frame_.data(),windowSize(),end,visuals):analyzer_->analyze(frame_.data(),windowSize(),end,visuals);}
    opentune::Analysis partialAnalysis(double end,opentune::PartialResult& p) {
        p=partial_->analyze(frame_.data(),windowSize(),end);
        return opentune::partialPitch(p,reference_);
    }
    void work() {
        int filled = 0; uint64_t processed = 0, captured = 0; uint32_t seenDrops = 0, previousCaptured = 0;
        try {
        while (running_.load(std::memory_order_acquire)) {
            const uint32_t capturedNow=samples_.load();
            captured+=static_cast<uint32_t>(capturedNow-previousCaptured); previousCaptured=capturedNow;
            const uint32_t drops = dropped_.load(std::memory_order_acquire);
            if (drops != seenDrops || ring_.size() > static_cast<size_t>(rate_ / 5)) {
                const size_t discarded = ring_.discard();
                // Consumer drops counted separately; no producer counter write race.
                consumerDropped_.fetch_add(static_cast<uint32_t>(discarded));
                { std::lock_guard<std::mutex> lock(resultMutex_); ++discontinuities_; latest_ = {}; latestWave_={};latestPartial_={}; latest_.sequence=++publishSequence_; published_=Clock::now(); sourceLagMs_=0; }
                filled=0; resetAnalysis(); processed=captured; seenDrops=drops;
            }
            const size_t read = ring_.pop(scratch_.data(), scratch_.size());
            if (!read) { std::this_thread::sleep_for(std::chrono::milliseconds(2)); continue; }
            for (size_t i=0; i<read; ++i) {
                frame_[filled++] = scratch_[i]; ++processed;
                if (filled == windowSize()) {
                    const bool visuals=visuals_.load();
                    opentune::PartialResult partialResult;
                    auto r = partial_?partialAnalysis(static_cast<double>(processed)/rate_,partialResult):analyze(static_cast<double>(processed)/rate_, visuals);
                    const auto wave=visuals&&!partial_?waveform_->extract(frame_.data(),filled,r.timeSeconds,r.frameQualified):opentune::DisplayWave{};
                    { std::lock_guard<std::mutex> lock(resultMutex_); r.sequence=++publishSequence_; latest_=r; latestWave_=wave;latestPartial_=partialResult; published_=Clock::now(); sourceLagMs_=(ring_.size()+read-i-1)*1000.0/rate_; }
                    const int retained=filled-hopSize();
                    std::move(frame_.begin()+hopSize(), frame_.end(), frame_.begin()); filled=retained;
                }
            }
        }
        } catch (...) { error_.store(static_cast<int32_t>(oboe::Result::ErrorInternal)); }
    }
    std::shared_ptr<oboe::AudioStream> stream_;
    std::unique_ptr<opentune::Analyzer> analyzer_;
    std::unique_ptr<opentune::PianoAnalyzer> piano_;
    std::unique_ptr<opentune::PartialAnalyzer> partial_;
    opentune::PartialResult latestPartial_;
    double reference_=440;int partialMidi_=-1;
    std::unique_ptr<opentune::WaveformDisplay> waveform_;
    opentune::DisplayWave latestWave_;
    opentune::SpscRing<65536> ring_;
    std::vector<float> frame_, scratch_;
    std::thread worker_;
    std::atomic<bool> running_{false}, visuals_{false};
    std::atomic<uint32_t> samples_{0}, dropped_{0}, consumerDropped_{0};
    std::atomic<int32_t> error_{0};
    std::mutex resultMutex_;
    opentune::Analysis latest_;
    Clock::time_point published_{};
    double sourceLagMs_=0; // software backlog only; hardware input latency unknown
    uint64_t discontinuities_=0, publishSequence_=0;
    int64_t session_=0;
    int rate_=0, channels_=0, format_=0, api_=0, burst_=0, capacity_=0, device_=0, preset_=0, recordingSession_=-1;
};
std::unique_ptr<Engine> engine;
std::unique_ptr<ReferenceEngine> referenceTone;
}
extern "C" JNIEXPORT jstring JNICALL Java_org_opentune_tuner_MainActivity_nativeStart(JNIEnv* env, jobject, jlong session, jboolean unprocessed, jdouble reference,jboolean piano) {
    try {
        referenceTone.reset(); engine.reset(); engine=std::make_unique<Engine>();
        const auto error=engine->start(session, unprocessed, reference,piano);
        if (!error.empty()) engine.reset();
        return env->NewStringUTF(error.c_str());
    } catch (const std::exception& e) { engine.reset(); return env->NewStringUTF(e.what()); }
}
extern "C" JNIEXPORT jstring JNICALL Java_org_opentune_tuner_MainActivity_nativePartialStart(JNIEnv* env,jobject,jlong session,jboolean unprocessed,jdouble reference,jint midi,jdouble association) {
    try {
        if(midi<21||midi>108)throw std::invalid_argument("partial target");
        referenceTone.reset();engine.reset();engine=std::make_unique<Engine>();
        const auto error=engine->start(session,unprocessed,reference,true,midi,association);
        if(!error.empty())engine.reset();return env->NewStringUTF(error.c_str());
    }catch(const std::exception& e){engine.reset();return env->NewStringUTF(e.what());}
}
extern "C" JNIEXPORT void JNICALL Java_org_opentune_tuner_MainActivity_nativeStop(JNIEnv*, jobject, jlong owner) {
    if (engine && engine->session()==owner) engine.reset();
}
extern "C" JNIEXPORT jdoubleArray JNICALL Java_org_opentune_tuner_MainActivity_nativeSnapshot(JNIEnv* env, jobject, jboolean details) {
    try {
    if (!engine) return env->NewDoubleArray(0);
    const auto data=engine->snapshot(details);
    auto array=env->NewDoubleArray(static_cast<jsize>(data.size()));
    if (array) env->SetDoubleArrayRegion(array,0,static_cast<jsize>(data.size()),data.data());
    return array;
    } catch (...) { return env->NewDoubleArray(0); }
}

extern "C" JNIEXPORT jstring JNICALL Java_org_opentune_tuner_MainActivity_nativeToneStart(JNIEnv* env, jobject, jlong token, jdouble hz,jint voice,jdouble gain) {
    try {
        engine.reset(); referenceTone.reset(); referenceTone=std::make_unique<ReferenceEngine>();
        const auto error=referenceTone->start(token,hz,static_cast<opentune::ToneVoice>(voice),gain);
        if (!error.empty()) referenceTone.reset();
        return env->NewStringUTF(error.c_str());
    } catch (const std::exception& e) { referenceTone.reset(); return env->NewStringUTF(e.what()); }
}
extern "C" JNIEXPORT void JNICALL Java_org_opentune_tuner_MainActivity_nativeToneStop(JNIEnv*, jobject, jlong owner) {
    if (referenceTone && referenceTone->owner==owner) referenceTone.reset();
}
extern "C" JNIEXPORT jdoubleArray JNICALL Java_org_opentune_tuner_MainActivity_nativeToneStatus(JNIEnv* env, jobject, jlong owner) {
    double data[3]{};
    if (referenceTone && referenceTone->owner==owner && !referenceTone->isMetronome()) {
        data[0]=referenceTone->playing(); data[1]=referenceTone->rate(); data[2]=referenceTone->error();
        if (!data[0]) referenceTone.reset();
    }
    auto array=env->NewDoubleArray(3);
    if(array) env->SetDoubleArrayRegion(array,0,3,data);
    return array;
}

extern "C" JNIEXPORT jstring JNICALL Java_org_opentune_tuner_MainActivity_nativeMetroStart(JNIEnv* env,jobject,jlong owner,jint word,jint gain) {
    try {
        engine.reset();referenceTone.reset();referenceTone=std::make_unique<ReferenceEngine>();
        const auto error=referenceTone->startMetronome(owner,opentune::MetroConfig::unpack(static_cast<uint32_t>(word)),gain);
        if(!error.empty())referenceTone.reset();return env->NewStringUTF(error.c_str());
    }catch(const std::exception& e){referenceTone.reset();return env->NewStringUTF(e.what());}
}
extern "C" JNIEXPORT void JNICALL Java_org_opentune_tuner_MainActivity_nativeMetroUpdate(JNIEnv*,jobject,jlong owner,jint word,jint gain) {
    const auto config=opentune::MetroConfig::unpack(static_cast<uint32_t>(word));
    if(config.valid()&&referenceTone&&referenceTone->owner==owner&&referenceTone->isMetronome())referenceTone->updateMetronome(config,gain);
}
extern "C" JNIEXPORT void JNICALL Java_org_opentune_tuner_MainActivity_nativeMetroPause(JNIEnv*,jobject,jlong owner,jboolean paused) {
    if(referenceTone&&referenceTone->owner==owner&&referenceTone->isMetronome())referenceTone->pauseMetronome(paused);
}
extern "C" JNIEXPORT jdoubleArray JNICALL Java_org_opentune_tuner_MainActivity_nativeMetroStatus(JNIEnv* env,jobject,jlong owner) {
    if(!referenceTone||referenceTone->owner!=owner||!referenceTone->isMetronome())return env->NewDoubleArray(0);
    const auto data=referenceTone->metronomeSnapshot();auto array=env->NewDoubleArray(static_cast<jsize>(data.size()));
    if(array)env->SetDoubleArrayRegion(array,0,static_cast<jsize>(data.size()),data.data());return array;
}
