#pragma once
#include "opentune/partial_analyzer.h"
#include <filesystem>
#include <fstream>
#include <iomanip>
// Test-only stream metadata; all acoustic values come from the production fit.
// No production generated-PCM endpoint. Only nondeterministic compute_ms is zeroed.
inline void writePartialFixture(const std::filesystem::path& path,const opentune::PartialResult& p,int rate,double a4,int midi){
 const auto a=opentune::partialPitch(p,a4);std::vector<double> wire(48,0);
 wire[1]=7;wire[2]=p.sequence;wire[3]=p.time;wire[5]=static_cast<int>(a.validity);wire[6]=a.rawHz;wire[7]=a.trackedHz;wire[8]=a.midi;wire[9]=a.cents;wire[10]=a.score;wire[11]=a.rmsDb;wire[12]=a.clipFraction;wire[14]=rate;wire[15]=1;wire[16]=2;wire[17]=2;wire[18]=192;wire[19]=1536;wire[28]=9;wire[29]=-1;wire[39]=static_cast<int>(a.trackState);
 opentune::appendPartialPayload(wire,p,midi);std::ofstream json(path);json<<std::setprecision(17)<<'[';
 for(size_t i=0;i<wire.size();i++){if(i)json<<',';json<<wire[i];}json<<"]\n";
}
