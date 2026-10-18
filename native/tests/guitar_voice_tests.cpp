#include "opentune/tone_synth.h"
#include "opentune/analyzer.h"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <vector>
#include <stdexcept>
using namespace opentune;
namespace {
constexpr double pi=3.14159265358979323846;
void require(bool b,const char*m){if(!b)throw std::runtime_error(m);}
double rms(const std::vector<float>&v,int from,int to){double sum=0;for(int i=from;i<to;i++)sum+=v[i]*v[i];return std::sqrt(sum/(to-from));}
double amplitude(const std::vector<float>&v,int rate,double hz,int from,int to){double real=0,imag=0,sum=0;for(int i=from;i<to;i++){const double w=.5-.5*std::cos(2*pi*(i-from)/(to-from-1.));sum+=w;real+=v[i]*w*std::cos(2*pi*hz*i/rate);imag-=v[i]*w*std::sin(2*pi*hz*i/rate);}return 2*std::hypot(real,imag)/sum;}
void wav(const std::filesystem::path&p,const std::vector<float>&v,int rate){
 std::ofstream f(p,std::ios::binary);const uint32_t bytes=static_cast<uint32_t>(v.size()*2),length=bytes+36,byteRate=rate*2;const uint16_t one=1,bits=16,two=2;
 f.write("RIFF",4);f.write(reinterpret_cast<const char*>(&length),4);f.write("WAVEfmt ",8);const uint32_t fmt=16;f.write(reinterpret_cast<const char*>(&fmt),4);f.write(reinterpret_cast<const char*>(&one),2);f.write(reinterpret_cast<const char*>(&one),2);f.write(reinterpret_cast<const char*>(&rate),4);f.write(reinterpret_cast<const char*>(&byteRate),4);f.write(reinterpret_cast<const char*>(&two),2);f.write(reinterpret_cast<const char*>(&bits),2);f.write("data",4);f.write(reinterpret_cast<const char*>(&bytes),4);
 for(float x:v){const auto value=static_cast<int16_t>(std::lround(x*32767));f.write(reinterpret_cast<const char*>(&value),2);}
}
}
int main(int argc,char**argv){try{
 const std::filesystem::path dir=argc>1?argv[1]:"voice-results";std::filesystem::create_directories(dir);
 std::ofstream cases(dir/"voice.csv");cases<<std::setprecision(15)<<"rate,hz,gain,peak,median_pitch_error,p95_pitch_error,valid_frames,total_frames,fundamental_amplitude,second_amplitude,off_harmonic_amplitude\n";
 int conditions=0;double maximumError=0,maximumPeak=0;
 for(int rate:{8000,44100,48000,96000,192000})for(double hz:{73.416191979,82.406889228,110.,146.832383959,184.997211355,246.941650628,329.627556913})for(double gain:{.25,.8,1.}){
  ToneSynth tone(rate,hz,ToneVoice::guitar,gain);std::vector<float> p(static_cast<int>(rate*.6));tone.render(p.data(),static_cast<int>(p.size()));
  double peak=0;for(float x:p){require(std::isfinite(x),"nonfinite guitar sample");peak=std::max(peak,std::abs(static_cast<double>(x)));}require(peak<=.650001*gain,"guitar exceeds declared peak bound");require(p.front()==0,"attack starts with discontinuity");
  Analyzer a(rate);int count=0,valid=0;std::vector<double> errors;
  for(int end=static_cast<int>(rate*.2);end+a.windowSize()<=static_cast<int>(p.size());end+=a.hopSize()){
   const auto r=a.analyze(p.data()+end,a.windowSize(),(end+a.windowSize())/static_cast<double>(rate),false);++count;if(r.validity==Validity::valid){++valid;errors.push_back(std::abs(centsBetween(r.trackedHz,hz)));}
  }
  std::sort(errors.begin(),errors.end());require(valid>=count*.9,"guitar reference rejected by production pitch core");require(!errors.empty()&&errors.back()<5,"synthesized guitar wrong pitch");
  maximumError=std::max(maximumError,errors.back());maximumPeak=std::max(maximumPeak,peak);
  const int from=static_cast<int>(rate*.05),to=static_cast<int>(rate*.5);
  const double fundamental=amplitude(p,rate,hz,from,to),second=amplitude(p,rate,2*hz,from,to),off=amplitude(p,rate,1.5*hz,from,to);
  require(fundamental>0&&second>fundamental*.5&&second<fundamental*.8,"missing or wrong harmonic content");require(off<fundamental*.005,"unexpected noninteger partial");
  cases<<rate<<','<<hz<<','<<gain<<','<<peak<<','<<errors[errors.size()/2]<<','<<errors[static_cast<size_t>(std::ceil(errors.size()*.95))-1]<<','<<valid<<','<<count<<','<<fundamental<<','<<second<<','<<off<<'\n';++conditions;
  // release begins at the current envelope value; do not jump at the stop call.
  ToneSynth normal(rate,hz,ToneVoice::guitar,gain),stopped(rate,hz,ToneVoice::guitar,gain);
  for(int elapsed:{1,7,40,250}){
   normal=ToneSynth(rate,hz,ToneVoice::guitar,gain);stopped=ToneSynth(rate,hz,ToneVoice::guitar,gain);
   std::vector<float> scratch(std::max(1,rate*elapsed/1000));normal.render(scratch.data(),static_cast<int>(scratch.size()));stopped.render(scratch.data(),static_cast<int>(scratch.size()));
   stopped.release();stopped.release();float expected=0,actual=0;normal.render(&expected,1);stopped.render(&actual,1);require(std::abs(expected-actual)<1e-7,"stop envelope discontinuity");
   scratch.resize(rate/10);stopped.render(scratch.data(),static_cast<int>(scratch.size()));require(stopped.finished()&&scratch.back()==0,"stop did not release in 30ms");
  }
 }
 std::ofstream levels(dir/"levels.csv");levels<<std::setprecision(15)<<"hz,voice,gain,segment,from_seconds,to_seconds,rms_fs,peak_fs,harmonic_energy_above300_fs2\n";
 for(double hz:{73.416191979,82.406889228,110.,329.627556913})for(int voice:{0,1})for(double gain:voice==0?std::vector<double>{1}:std::vector<double>{.8,1}){
  ToneSynth tone(48000,hz,static_cast<ToneVoice>(voice),gain);std::vector<float> p(48000*4);tone.render(p.data(),static_cast<int>(p.size()));require(tone.finished()&&p.back()==0,"automatic release must finish");
  int segment=0;for(const auto range:std::vector<std::pair<double,double>>{{0,.25},{.25,1},{1,3},{0,3.03}}){
   const int from=static_cast<int>(48000*range.first),to=static_cast<int>(48000*range.second);double peak=0,energy=0;for(int i=from;i<to;i++)peak=std::max(peak,std::abs(static_cast<double>(p[i])));
   for(int harmonic=1;harmonic<=8;harmonic++)if(hz*harmonic>=300){const double a=amplitude(p,48000,hz*harmonic,from,to);energy+=a*a/2;}
   levels<<hz<<','<<voice<<','<<gain<<','<<segment++<<','<<range.first<<','<<range.second<<','<<rms(p,from,to)<<','<<peak<<','<<energy<<'\n';
  }
  if(hz<83)wav(dir/(std::string(voice?"guitar-":"sine-")+std::to_string(static_cast<int>(hz))+"-"+std::to_string(static_cast<int>(gain*100))+".wav"),p,48000);
 }
 for(int rate:{8000,48000}){
  ToneSynth muted(rate,110,ToneVoice::guitar,0);std::vector<float> p(rate*4);muted.render(p.data(),static_cast<int>(p.size()));require(std::all_of(p.begin(),p.end(),[](float x){return x==0;}),"zero gain not silent");
 }
 for(double invalid:{-1.,1.01}){bool rejected=false;try{ToneSynth bad(48000,110,ToneVoice::guitar,invalid);}catch(const std::invalid_argument&){rejected=true;}require(rejected,"invalid gain accepted");}
 std::cout<<conditions<<" guitar voice conditions; max accepted frame error "<<maximumError<<"c, max peak "<<maximumPeak<<"FS; harmonic/stop/automatic release/mute/gain bounds passed; levels.csv records early/late/full RMS and >=300Hz harmonic energy\n";
 return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
