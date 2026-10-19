"""Summarize measured production C++ M1 output; no phone loudness claims."""
import argparse
import csv
import hashlib
import json
import math
import wave
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--build',type=Path,default=root/'build/m1-dsp')
parser.add_argument('--output',type=Path,default=root/'artifacts/m1-guitar/results')
parser.add_argument('--comparison',type=Path,help='Optional saved previous evaluation/frames.csv; absent is explicitly not compared')
args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
def read(relative):
    with (args.build/relative).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
summary=json.loads((args.build/'guitar-results/summary.json').read_text(encoding='utf-8'))
summary['kind']='Original synthetic signals, Windows host; not Android SPL/loudness/latency'
v=read('voice-results/voice.csv');level=read('voice-results/levels.csv');m=read('metronome-results/levels.csv')
summary['voice']={'conditions':len(v),'max_case_p95_pitch_cents':max(float(x['p95_pitch_error']) for x in v),'peak_max_fs':max(float(x['peak']) for x in v),'accepted_frames':sum(int(x['valid_frames']) for x in v),'total_frames':sum(int(x['total_frames']) for x in v),'default_gain':.8,'rms_gain_db_vs_legacy':{}}
for hz in sorted({x['hz'] for x in level},key=float):
    old=[x for x in level if x['hz']==hz and x['voice']=='0']
    current=[x for x in level if x['hz']==hz and x['voice']=='1' and x['gain']=='0.8']
    summary['voice']['rms_gain_db_vs_legacy'][hz]=[20*math.log10(float(b['rms_fs'])/float(a['rms_fs'])) for a,b in zip(old,current)]
summary['metro']={'events':len(m),'measured_gain_db_range':[min(float(x['gain_db']) for x in m),max(float(x['gain_db']) for x in m)],'max_peak_fs':max(float(x['peak_fs']) for x in m),'target_gain_percent_default':100,'gain_slew_ms':5}
fingerprints=json.loads((root/'docs/evidence/m1-pitch-source-hashes.json').read_text(encoding='utf-8'))
for path,expected in fingerprints['sha256_lf'].items():
    assert hashlib.sha256((root/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==expected,path
summary['pitch_source_unchanged_from']='4120511'
comparison=args.comparison or root/'artifacts/stage25-evaluation/frames.csv'
actual=read('evaluation/frames.csv')
if comparison.exists():
    with comparison.open(encoding='utf-8-sig') as f:baseline=list(csv.DictReader(f))
    assert len(baseline)==len(actual)
    differences=sum(any(a[k]!=b[k] for k in a if k!='compute_ms') for a,b in zip(baseline,actual));assert differences==0,differences
    summary['regression']={'rows':len(actual),'non_timing_differences':differences}
else:
    summary['regression']={'rows':len(actual),'status':'not compared: no optional saved previous CSV; source fingerprints checked'}
(args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')

fig,ax=plt.subplots(figsize=(8,3.6))
for index,(hz,values) in enumerate(summary['voice']['rms_gain_db_vs_legacy'].items()):ax.bar(np.arange(4)+(index-1.5)*.18,values,width=.18,label=f'{float(hz):.1f} Hz')
ax.set_xticks(range(4),['0–0.25 s','0.25–1 s','1–3 s','Aggregate\n0–3.03 s']);ax.axhline(0,color='gray',lw=.8);ax.set_ylabel('RMS change vs old sine (dB)');ax.set_title('Production synthetic pluck, gain 0.8: attack gain and decay tradeoff');ax.legend(ncol=4,fontsize=8);ax.grid(axis='y',alpha=.2);fig.tight_layout();fig.savefig(args.output/'reference-rms.png',dpi=160);plt.close(fig)
fig,ax=plt.subplots(figsize=(8,3.6))
for name in ['sine-82-100.wav','guitar-82-80.wav','guitar-82-100.wav']:
    with wave.open(str(args.build/'voice-results'/name)) as f:rate=f.getframerate();pcm=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2')/32767
    ax.plot(np.arange(int(rate*.05))/rate*1000,pcm[:int(rate*.05)],label=name.removesuffix('.wav'),lw=1)
ax.set(xlabel='Actual sample time (ms)',ylabel='Amplitude (FS)',title='Production samples: E2 sine and harmonic pluck (original synthesis)');ax.legend(fontsize=8);ax.grid(alpha=.2);fig.tight_layout();fig.savefig(args.output/'reference-wave.png',dpi=160);plt.close(fig)
cases=read('guitar-results/cases.csv');fig,ax=plt.subplots(figsize=(8,3.6))
for signal in sorted({x['signal'] for x in cases}):
    data=[x for x in cases if x['signal']==signal];ax.scatter([float(x['hz']) for x in data],[float(x['p95_cents']) for x in data],s=14,label=signal)
ax.set(xlabel='Target frequency (Hz)',ylabel='Case P95 absolute cents',title='336 preset × rate × harmonic cases; 100% steady acceptance');ax.legend(fontsize=8);ax.grid(alpha=.2);fig.tight_layout();fig.savefig(args.output/'preset-errors.png',dpi=160);plt.close(fig)
for f in args.output.glob('*.png'):assert f.stat().st_size>1000
summary['artifact_sha256']={p.relative_to(args.build).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [args.build/'guitar-results/frames.csv',args.build/'guitar-results/cases.csv',args.build/'voice-results/voice.csv',args.build/'voice-results/levels.csv',args.build/'metronome-results/levels.csv']}
(args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8');print(json.dumps(summary,indent=2))
