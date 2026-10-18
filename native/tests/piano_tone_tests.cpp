#include "opentune/tone_synth.h"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace opentune;
int main(int argc,char**argv){try{
 const std::filesystem::path dir=argc>1?argv[1]:"piano-tones";
 std::filesystem::create_directories(dir);std::ofstream csv(dir/"tones.csv");
 csv<<"rate,a4,midi,target_hz,measured_hz,error_cents,peak,release_finished\n";
 double maxError=0,maxPeak=0;int conditions=0;
 for(int rate:{16000,44100,48000})for(double a4:{400.,480.})for(int midi=21;midi<=108;midi++){
  const double hz=a4*std::pow(2.,(midi-69)/12.);
  ToneSynth tone(rate,hz);std::vector<float> pcm(rate/2);tone.render(pcm.data(),static_cast<int>(pcm.size()));
  double first=-1,last=-1,peak=0;int crossings=0;
  for(size_t i=1;i<pcm.size();i++){
   if(!std::isfinite(pcm[i]))throw std::runtime_error("nonfinite tone");
   peak=std::max(peak,std::abs(static_cast<double>(pcm[i])));
   if(i>static_cast<size_t>(rate/20)&&pcm[i-1]<=0&&pcm[i]>0){
    const double crossing=i-1-pcm[i-1]/static_cast<double>(pcm[i]-pcm[i-1]);
    if(first<0)first=crossing;last=crossing;++crossings;
   }
  }
  if(crossings<3)throw std::runtime_error("too few crossings");
  const double measured=(crossings-1)*rate/(last-first),error=1200*std::log2(measured/hz);
  tone.release();std::vector<float> tail(rate/20);tone.render(tail.data(),static_cast<int>(tail.size()));
  if(std::abs(error)>1||peak>.150001||pcm.front()!=0||!tone.finished()||tail.back()!=0)
   throw std::runtime_error("piano tone frequency/envelope/level failed");
  maxError=std::max(maxError,std::abs(error));maxPeak=std::max(maxPeak,peak);++conditions;
  csv<<rate<<','<<a4<<','<<midi<<','<<hz<<','<<measured<<','<<error<<','<<peak<<','<<tone.finished()<<'\n';
 }
 int rejected=0;for(double a4:{400.,480.})try{ToneSynth tooHigh(8000,a4*std::pow(2.,39./12));}catch(const std::invalid_argument&){++rejected;}
 if(rejected!=2)throw std::runtime_error("8k C8 must explicitly reject, never octave-fold");
 std::cout<<conditions<<" production sine tones: max absolute zero-crossing error "<<maxError<<"c, peak "<<maxPeak<<" FS; attack/release passed; 8k C8 rejects 2/2. No phone loudness evidence.\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
