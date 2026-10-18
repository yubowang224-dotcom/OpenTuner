#include "opentune/metronome.h"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <vector>
using namespace opentune;
void require(bool v,const char*msg){if(!v)throw std::runtime_error(msg);}
int main(int argc,char**argv){try {
 const std::filesystem::path dir=argc>1?argv[1]:"metro-results";std::filesystem::create_directories(dir);
 std::ofstream report(dir/"timing.csv");report<<std::setprecision(15)<<"rate,bpm,beats,denominator,divisions,accent,rendered_seconds,onsets,max_scheduled_event_error_samples,long_clock_ticks,long_clock_max_error_samples\n";
 std::ofstream levels(dir/"levels.csv");levels<<std::setprecision(15)<<"rate,bpm,beats,denominator,divisions,accent,beat,division,peak_fs,rms_click_fs,legacy_rms_click_fs,gain_db\n";
 int cases=0;
 for(int rate:{44100,48000})for(int bpm:{20,73,120,137,300})for(auto signature:std::vector<std::pair<int,int>>{{2,4},{3,4},{4,4},{6,8}})for(int div:{1,2,3,4})for(bool accent:{false,true}){
  MetroConfig c{bpm,signature.first,signature.second,div,accent};require(MetroConfig::unpack(c.pack()).pack()==c.pack(),"config roundtrip");
  MetronomeSynth s(rate,c);const double period=rate*60.0/bpm*4/c.denominator/div;
  // Two bars of actual PCM (at least two complete 6/8 accent groups).
  const int ticks=c.beats*div*2, length=static_cast<int>(std::ceil((ticks-1)*period))+rate/40;
  std::vector<float> pcm(length);for(int i=0;i<length;i+=193)s.render(pcm.data()+i,std::min(193,length-i));
  std::vector<int> onsets;bool previous=false;
  for(int i=0;i<length;++i){const bool nonzero=std::abs(pcm[i])>1e-8f;require(std::isfinite(pcm[i])&&std::abs(pcm[i])<=.440001,"finite bounded louder metronome audio");
   // A click includes sine zero crossings. A silent run of 2ms separates clicks.
   if(nonzero&&!previous){bool quiet=true;for(int j=std::max(0,i-rate/500);j<i;++j)if(std::abs(pcm[j])>1e-8)quiet=false;if(quiet)onsets.push_back(i);}
   previous=nonzero;
  }
  require(static_cast<int>(onsets.size())==ticks,"actual rendered onset count");double maximum=0;
  for(int i=0;i<ticks;++i){const int event=static_cast<int>(std::ceil(i*period));require(onsets[i]==event+1,"onset follows scheduled zero-phase sample by one sample");
   maximum=std::max(maximum,std::abs((onsets[i]-1)-i*period));
   const int beat=(i/div)%c.beats,sub=i%div;
   const double amp=sub==0?(accent&&beat==0?.22:accent&&c.beats==6&&c.denominator==8&&beat==3?.18:.14):.07;
   double peak=0,energy=0,oldEnergy=0;const int samples=rate*12/1000;
   const double frequency=sub==0?(accent&&beat==0?1700:accent&&c.beats==6&&c.denominator==8&&beat==3?1450:1200):850;
   for(int j=0;j<samples;++j){
    const double x=pcm[event+j];peak=std::max(peak,std::abs(x));energy+=x*x;
    const double envelope=std::min(1.,j/static_cast<double>(std::max(1,rate/1000)))*.5*(1+std::cos(3.14159265358979323846*j/samples));
    const double original=amp*envelope*std::sin(2*3.14159265358979323846*frequency*j/rate);oldEnergy+=original*original;
    require(std::abs(x-2*original)<1e-6,"new click differs from exact two-times legacy waveform");
   }
   require(peak>amp*1.80&&peak<=2*amp+.000001,"accent/subdivision louder amplitude");
   const double actualRms=std::sqrt(energy/samples),oldRms=std::sqrt(oldEnergy/samples),db=20*std::log10(actualRms/oldRms);
   require(std::abs(db-6.020599913)<1e-5,"measured metronome gain ratio");
   levels<<rate<<','<<bpm<<','<<c.beats<<','<<c.denominator<<','<<div<<','<<accent<<','<<beat<<','<<sub<<','<<peak<<','<<actualRms<<','<<oldRms<<','<<db<<'\n';
  }
  require(maximum<1.000001,"sample-domain render error");
  MetronomeSynth clock(rate,c);double longError=0;int longTicks=0;
  for(double ideal=0;ideal<rate*600.;ideal=++longTicks*period){const auto at=clock.advanceToNextTickForTest();longError=std::max(longError,std::abs(static_cast<double>(at)-ideal));}
  require(longError<1.000001,"ten-minute sample clock drift");
  report<<rate<<','<<bpm<<','<<c.beats<<','<<c.denominator<<','<<div<<','<<accent<<','<<static_cast<double>(length)/rate<<','<<onsets.size()<<','<<maximum<<','<<longTicks<<','<<longError<<'\n';++cases;
 }
 // Requested parameters apply at the next subdivision boundary, not mid-click.
 MetronomeSynth changed(48000,{120,4,4,1,true});std::vector<float> buffer(30000);changed.render(buffer.data(),1000);auto before=changed.position();
 require(changed.queue({300,6,8,4,true}),"valid pending update");changed.render(buffer.data(),1000);require(changed.position().config==before.config,"no early update");
 changed.render(buffer.data(),23000);auto after=changed.position();require(MetroConfig::unpack(after.config).bpm==300,"update reaches boundary");require(after.lastTickFrame==24000&&after.beat==0&&after.division==0,"boundary anchored update restarts bar");
 require(!changed.queue({0,0,0,0,true}),"invalid update rejected");changed.release();changed.release();changed.render(buffer.data(),1000);require(changed.finished(),"bounded release");for(int i=300;i<1000;++i)require(buffer[i]==0,"stop tail zero");
 for(int rate:{8000,44100,48000,192000})for(int gain:{0,25,50,100}){
  MetronomeSynth full(rate,{300,6,8,4,true}),scaled(rate,{300,6,8,4,true});require(scaled.setGain(gain,true),"initial gain accepted");
  std::vector<float> reference(rate),actual(rate);full.render(reference.data(),rate);scaled.render(actual.data(),rate);
  for(int i=0;i<rate;i++)require(std::abs(actual[i]-reference[i]*gain/100.)<1e-7,"measured user gain ratio or mute differs");
  require(full.position().ticks==scaled.position().ticks&&full.position().lastTickFrame==scaled.position().lastTickFrame,"gain changes timing");
 }
 MetronomeSynth volume(48000,{120,4,4,1,true});volume.render(buffer.data(),100);const auto originalPosition=volume.position();
 require(volume.setGain(0),"live mute request");volume.render(buffer.data(),1000);
 require(volume.position().ticks==originalPosition.ticks&&volume.position().lastTickFrame==originalPosition.lastTickFrame&&volume.position().gain==0,"volume change resets beat or loses actual gain");
 for(int i=241;i<1000;i++)require(buffer[i]==0,"gain reaches mute within 5ms");
 require(volume.setGain(10)&&volume.setGain(90)&&volume.setGain(50),"rapid volume latest accepted");volume.render(buffer.data(),10);require(volume.position().gain==50,"latest volume wins");
 require(!volume.setGain(-1)&&!volume.setGain(101),"invalid volume rejected");volume.release();volume.render(buffer.data(),1000);require(volume.finished(),"volume plus stop releases");
 MetronomeSynth stopping(48000,{120,4,4,1,true});stopping.render(buffer.data(),100);
 stopping.release();stopping.release();stopping.render(buffer.data(),300);
 require(std::abs(buffer[0])>.01,"stop test begins inside audible click");
 require(stopping.finished()&&stopping.position().ticks==1,"stop prevents new ticks");
 for(int i=241;i<300;++i)require(buffer[i]==0,"active-click release reaches silence within 5ms");
 MetronomeSynth coalesced(44100,{73,4,4,1,false});coalesced.render(buffer.data(),10);
 coalesced.queue({100,3,4,2,true});coalesced.queue({137,6,8,3,false});
 coalesced.advanceToNextTickForTest();
 require(MetroConfig::unpack(coalesced.position().config).bpm==137,"latest queued config wins");
 MetroMailbox mailbox;std::atomic<bool> done{false};std::thread writer([&]{for(uint32_t i=1;i<100000;++i)mailbox.publish({i,2ull*i,3ull*i,static_cast<int>(i%6),static_cast<int>(i%4),i,static_cast<int>(i%101),static_cast<int>(i%4),5ull*i});done.store(true);});
 while(!done.load()){MetroPosition p;if(mailbox.read(p)&&p.frames)require(p.ticks==2*p.frames&&p.lastTickFrame==3*p.frames&&p.config==p.frames&&p.gain==static_cast<int>(p.frames%101)&&p.transport==static_cast<int>(p.frames%4)&&p.outputFrames==5*p.frames,"coherent mailbox including gain");}writer.join();
 std::cout<<cases<<" actual-audio cases and ten-minute clock cases passed; update/release/atomic snapshot passed\n";return 0;
}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}}
