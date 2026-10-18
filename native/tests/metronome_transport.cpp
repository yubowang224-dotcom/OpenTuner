#include "opentune/metronome.h"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace opentune;
void require(bool value,const char* message){if(!value)throw std::runtime_error(message);}
int main(int argc,char**argv){try{
 const std::filesystem::path dir=argc>1?argv[1]:"transport-results";std::filesystem::create_directories(dir);
 std::ofstream csv(dir/"transport.csv");csv<<"rate,divisions,prefix,pause_fade_transport_samples,paused_output_samples,resume_compared_samples,max_after_fade_error,stop_finished\n";
 int conditions=0;bool fixture=false;
 for(int rate:{8000,44100,48000,192000})for(int div:{1,4})for(int prefix:{100,rate/4}){
  MetroConfig config{137,6,8,div,true};MetronomeSynth tested(rate,config),continuous(rate,config);
  const int tail=rate,freeze=rate;std::vector<float> buffer(rate),resumed(tail),expected(prefix+rate/100+tail+16);
  tested.render(buffer.data(),prefix);const auto before=tested.position();tested.setPaused(true);tested.setPaused(true);
  tested.render(buffer.data(),rate/100);const auto paused=tested.position();
  require(paused.transport==2&&paused.frames-before.frames<=static_cast<uint64_t>(rate/200+1),"bounded fade reaches pause");
  tested.render(buffer.data(),freeze);const auto after=tested.position();
  require(after.frames==paused.frames&&after.ticks==paused.ticks&&after.beat==paused.beat&&after.division==paused.division&&after.lastTickFrame==paused.lastTickFrame,"paused musical phase/count moved");
  require(after.outputFrames-paused.outputFrames==static_cast<uint64_t>(freeze),"paused callback heartbeat did not advance");
  require(std::all_of(buffer.begin(),buffer.end(),[](float x){return x==0;}),"paused PCM must be exact silence");
  if(!fixture&&rate==48000&&div==4){
   const auto wire=metroSnapshot(17,rate,true,0,false,after);std::ofstream json(dir/"fixture.json");json<<std::setprecision(17)<<'[';for(size_t i=0;i<wire.size();i++){if(i)json<<',';json<<wire[i];}json<<"]\n";fixture=true;
  }
  tested.setPaused(false);tested.setPaused(false);tested.render(resumed.data(),tail);continuous.render(expected.data(),static_cast<int>(paused.frames)+tail);
  double error=0;for(int i=rate/200+2;i<tail;i++)error=std::max(error,std::abs(static_cast<double>(resumed[i])-expected[paused.frames+i]));
  require(error<1e-7,"resume oscillator/scheduler phase differs from unpaused production PCM");
  require(tested.position().ticks==continuous.position().ticks&&tested.position().lastTickFrame==continuous.position().lastTickFrame,"resume beat scheduling phase differs");
  // Explicitly pause inside a click, change gain to zero and immediately resume
  // without even one paused render block: sample zero must already be silent.
  MetronomeSynth muted(rate,config),audible(rate,config);
  muted.render(buffer.data(),100);audible.render(buffer.data(),100);
  muted.setPaused(true);audible.setPaused(true);
  muted.render(buffer.data(),rate/100);audible.render(buffer.data(),rate/100);
  muted.setGain(0);muted.setPaused(false);audible.setPaused(false);
  muted.render(buffer.data(),rate/100);
  require(std::all_of(buffer.begin(),buffer.begin()+rate/100,[](float x){return x==0;}),"gain zero during pause leaked resumed first samples");
  audible.render(buffer.data(),rate/100);
  if(rate>=44100)require(std::any_of(buffer.begin(),buffer.begin()+rate/100,[](float x){return std::abs(x)>1e-4;}),"mute test lacks an audible resume control");
  // Gain may also arrive during the fade, before the fully paused branch.
  MetronomeSynth fadingMute(rate,config);fadingMute.render(buffer.data(),100);fadingMute.setPaused(true);fadingMute.render(buffer.data(),rate/500);fadingMute.setGain(0);fadingMute.render(buffer.data(),rate/100);
  require(fadingMute.position().transport==2,"fade mute never reached pause");fadingMute.setPaused(false);fadingMute.render(buffer.data(),rate/100);
  require(std::all_of(buffer.begin(),buffer.begin()+rate/100,[](float x){return x==0;}),"gain zero during pause fade leaked resumed first samples");
  // Resume on the exact sample that first reaches pause, without a later
  // already-paused iteration to settle gain. This closes the block-boundary case.
  MetronomeSynth exactMute(rate,config);exactMute.render(buffer.data(),100);exactMute.setPaused(true);exactMute.render(buffer.data(),rate/500);exactMute.setGain(0);
  int iterations=0;while(exactMute.position().transport!=2&&iterations++<rate/200+2)exactMute.render(buffer.data(),1);
  require(exactMute.position().transport==2,"exact fade boundary absent");exactMute.setPaused(false);exactMute.render(buffer.data(),rate/100);
  require(std::all_of(buffer.begin(),buffer.begin()+rate/100,[](float x){return x==0;}),"exact fade-completion mute leaked resumed first sample");
  // Queue changes while paused: no hidden reset until next subdivision on resume.
  tested.setPaused(true);tested.render(buffer.data(),rate/100);const auto held=tested.position();tested.queue({120,3,4,2,false});tested.setGain(0);tested.render(buffer.data(),rate);
  require(tested.position().frames==held.frames&&tested.position().config==held.config,"paused config must not run musical clock");
  tested.setPaused(false);tested.render(buffer.data(),rate);require(MetroConfig::unpack(tested.position().config).bpm==120,"pending config did not apply after resume");
  require(std::all_of(buffer.begin(),buffer.end(),[](float x){return x==0;}),"mute while resuming must remain silent after gain slew");
  tested.setPaused(true);tested.render(buffer.data(),rate/100);tested.release();tested.release();tested.render(buffer.data(),rate/100);require(tested.finished(),"stop while paused must release resources boundedly");
  MetronomeSynth restarted(rate,config);restarted.render(buffer.data(),100);require(restarted.position().beat==0&&restarted.position().division==0&&restarted.position().ticks==1,"new start must reset first beat");
  csv<<rate<<','<<div<<','<<prefix<<','<<paused.frames-before.frames<<','<<after.outputFrames-paused.outputFrames<<','<<tail-rate/200-2<<','<<error<<','<<tested.finished()<<'\n';++conditions;
 }
 require(fixture,"fixture absent");std::cout<<conditions<<" production pause/resume PCM cases: freeze/silence/heartbeat/phase/config/mute/stop/restart passed\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
