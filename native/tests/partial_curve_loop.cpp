#include "partial_fixture.h"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
using namespace opentune;
int main(int argc,char**argv){try{
 if(argc!=3)throw std::invalid_argument("usage: partial_curve_loop production-targets.csv output-directory");
 const std::filesystem::path dir=argv[2];std::filesystem::create_directories(dir);
 std::ifstream input(argv[1]);std::string line;std::getline(input,line);if(line!="midi,a4,target_first_hz,b")throw std::invalid_argument("curve CSV header");
 struct Target{int midi;double a4,hz,b;};std::vector<Target> targets;
 while(std::getline(input,line)){
  std::istringstream row(line);std::string field;std::vector<std::string> fields;while(std::getline(row,field,','))fields.push_back(field);
  if(fields.size()!=4)throw std::invalid_argument("curve CSV row");
  const Target t{std::stoi(fields[0]),std::stod(fields[1]),std::stod(fields[2]),std::stod(fields[3])};
  if(t.midi==33||t.midi==45||t.midi==69||t.midi==93)targets.push_back(t);
 }
 if(targets.size()!=4)throw std::invalid_argument("four guide target keys required");
 std::ofstream out(dir/"frames.csv"),summary(dir/"cases.csv");
 out<<std::setprecision(15)<<"midi,rate,target_hz,truth_hz,offset_et,delta,missing,time,steady,ready,model_first,observed_first,measured_hz,cents,error_cents\n";
 summary<<"midi,rate,delta,missing,steady,ready,max_error_cents\n";
 int total=0,valid=0,conditions=0;double maxError=0;bool fixture=false,largeOffset=false;
 for(const auto& t:targets)for(int rate:{44100,48000})for(double delta:{-17.,17.})for(bool missing:{false,true}){
  PartialAnalyzer analyzer(rate,t.a4,t.midi,t.hz);const double truth=t.hz*std::pow(2,delta/1200),ideal=truth/std::sqrt(1+t.b),et=t.a4*std::pow(2,(t.midi-69)/12.);
  const double offset=centsBetween(t.hz,et);largeOffset|=std::abs(offset)>60;
  std::vector<float> pcm(rate*3/2);
  for(int i=0;i<static_cast<int>(pcm.size());i++){
   const double time=i/static_cast<double>(rate);double x=0;
   for(int n=1;n<=16;n++){
    if(missing&&n==1)continue;const double hz=n*ideal*std::sqrt(1+t.b*n*n);if(hz>=std::min(18000.,rate*.42))continue;
    x+=.12/std::pow(n,.7)*std::exp(-time*(.15+.025*n))*std::sin(2*3.14159265358979323846*hz*time+.17*n);
   }
   pcm[i]=static_cast<float>(x);
  }
  int denominator=0,accepted=0;double caseError=0;
  for(int end=analyzer.windowSize();end<=static_cast<int>(pcm.size());end+=analyzer.hopSize()){
   const double time=end/static_cast<double>(rate);const auto p=analyzer.analyze(pcm.data()+end-analyzer.windowSize(),analyzer.windowSize(),time);const auto pitch=partialPitch(p,t.a4);
   const bool ready=p.reason==PartialReason::ready,steady=time>=1.1;double observed=0;for(int n=0;n<p.count;n++)if(p.partials[n].order==1)observed=p.partials[n].hz;
   const double cents=ready?centsBetween(pitch.trackedHz,t.hz):0,error=ready?std::abs(cents-delta):0;
   out<<t.midi<<','<<rate<<','<<t.hz<<','<<truth<<','<<offset<<','<<delta<<','<<missing<<','<<time<<','<<steady<<','<<ready<<','<<p.firstHz<<','<<observed<<','<<pitch.trackedHz<<','<<cents<<','<<error<<'\n';
   if(!fixture&&t.midi==33&&rate==48000&&delta==17&&!missing&&ready){writePartialFixture(dir/"curve-offset.json",p,rate,t.a4,t.midi);fixture=true;}
   if(!steady)continue;++total;++denominator;if(ready){++valid;++accepted;caseError=std::max(caseError,error);maxError=std::max(maxError,error);}
  }
  summary<<t.midi<<','<<rate<<','<<delta<<','<<missing<<','<<denominator<<','<<accepted<<',';if(accepted)summary<<caseError;summary<<'\n';
  if(accepted<denominator*.95||caseError>2)throw std::runtime_error("individual curve-loop condition failed");++conditions;
 }
 if(!largeOffset||!fixture)throw std::runtime_error("missing cross-layer >60-cent case");
 std::cout<<conditions<<" production curve->nonharmonic PCM->fit->target cents conditions: "<<valid<<'/'<<total<<" accepted, max cents error "<<maxError<<"; >60c ET offset exercised. Host only.\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
