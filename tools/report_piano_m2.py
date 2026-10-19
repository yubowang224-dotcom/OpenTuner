"""Report production PianoAnalyzer/ToneSynth host measurements, never phone evidence."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--build', type=Path, default=root/'build/m2-dsp')
parser.add_argument('--output', type=Path, default=root/'artifacts/m2/results')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
def read(name):
    with (args.build/name).open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream))
def percentile(values, q):
    return float(np.percentile(values, q, method='inverted_cdf'))

summary = json.loads((args.build/'piano-results/summary.json').read_text(encoding='utf-8'))
assert summary['conditions'] == 1408 and not summary['quick']
assert summary['goal_failures'] == summary['octave_errors'] == summary['false_valid'] == 0
frames = read('piano-results/frames.csv')
cases = read('piano-results/cases.csv')
summary['evidence'] = 'Original synthetic host PCM, not phone/recorded piano/professional acoustic certification'
summary['bins'] = {}
for name, low, high in [('low_A0_B2',21,47), ('mid_C3_B5',48,83), ('high_C6_C8',84,108)]:
    data = [r for r in frames if low <= int(r['midi']) <= high and r['steady']=='1']
    valid = [r for r in data if r['valid']=='1']
    errors = [abs(float(r['error_cents'])) for r in valid]
    group = [r for r in cases if low <= int(r['midi']) <= high]
    summary['bins'][name] = dict(conditions=len(group), frames=len(data), valid=len(valid),
        median_abs_cents=percentile(errors,50), p95_abs_cents=percentile(errors,95),
        max_case_jitter_sd_cents=max(float(r['jitter_sd']) for r in group),
        first_valid_ms_range=[min(float(r['first_ms']) for r in group),max(float(r['first_ms']) for r in group)])
summary['dynamic'] = read('piano-state/response.csv')
tones = read('piano-tones/tones.csv')
summary['synthesis'] = dict(conditions=len(tones), max_abs_cents=max(abs(float(r['error_cents'])) for r in tones),
    max_peak_fs=max(float(r['peak']) for r in tones), all_release_finished=all(r['release_finished']=='1' for r in tones),
    method='Subsample rising zero-crossing period, last-first after 50 ms; 0.5 s production sine at 16/44.1/48 kHz, A4 400/480, all 88 keys')
fingerprints=json.loads((root/'docs/evidence/m1-pitch-source-hashes.json').read_text(encoding='utf-8'))
for path,expected in fingerprints['sha256_lf'].items():
    assert hashlib.sha256((root/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==expected, path
summary['general_dsp_unchanged'] = fingerprints['sha256_lf']
summary['source_sha256_lf'] = {p:hashlib.sha256((root/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [
    'native/src/piano_analyzer.cpp','native/include/opentune/piano_analyzer.h','native/tests/piano_tests.cpp',
    'native/tests/piano_state_tests.cpp','native/tests/piano_tone_tests.cpp']}
summary['raw_sha256'] = {name:hashlib.sha256((args.build/name).read_bytes()).hexdigest() for name in [
    'piano-results/frames.csv','piano-results/cases.csv','piano-state/states.csv','piano-state/response.csv','piano-tones/tones.csv']}
(args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')

fig, ax = plt.subplots(figsize=(9,3.8))
for signal in ['pure','detuned17','strong_partials','missing_fundamental']:
    data=[r for r in cases if r['signal']==signal]
    ax.scatter([int(r['midi']) for r in data],[float(r['p95_cents']) for r in data],s=10,label=signal)
ax.set(xlabel='Actual key MIDI (A0=21, C8=108)',ylabel='Case P95 absolute error (cents)',title='1408 synthetic stable cases: all steady frames accepted; not phone precision')
ax.legend(fontsize=8,ncol=2);ax.grid(alpha=.2);fig.tight_layout();fig.savefig(args.output/'piano-errors.png',dpi=150);plt.close(fig)
states=read('piano-state/states.csv')
data=[r for r in states if r['case']=='step_silence_return' and r['rate']=='48000']
fig,ax=plt.subplots(figsize=(9,3.8))
time=[float(r['time']) for r in data]
for field,label in [('truth_hz','Source frequency (no sound in shaded interval)'),('raw_hz','Raw estimate'),('tracked_hz','Accepted tracked Hz')]:
    values=[]
    for r in data:
        valid=(r['valid']=='1') if field=='tracked_hz' else float(r[field])>0
        if field=='truth_hz' and 1.6 <= float(r['time']) < 2.2: valid=False
        values.append(float(r[field]) if valid else np.nan)
    assert np.isnan(values).any() if field in ['truth_hz','tracked_hz'] else True
    ax.plot(time,values,label=label,marker='.' if field=='tracked_hz' else None,markersize=3)
ax.axvspan(1.6,2.2,color='gray',alpha=.2);ax.set(xlabel='Input end sample time (s)',ylabel='Hz',title='180 ms piano window: low-note step / stop / return (host, 48 kHz)');ax.legend(fontsize=8);ax.grid(alpha=.2);fig.tight_layout();fig.savefig(args.output/'piano-response.png',dpi=150);plt.close(fig)
fig,axes=plt.subplots(1,2,figsize=(9,3.5))
names=list(summary['bins']);x=np.arange(len(names));bins=list(summary['bins'].values())
axes[0].bar(x,[100*v['valid']/v['frames'] for v in bins]);axes[0].set(ylim=(0,105),ylabel='All steady frame acceptance (%)')
axes[1].bar(x,[v['max_case_jitter_sd_cents'] for v in bins]);axes[1].set(ylabel='Maximum case jitter SD (cents)')
for ax in axes:ax.set_xticks(x,['A0–B2','C3–B5','C6–C8']);ax.grid(axis='y',alpha=.2)
fig.suptitle('Independent piano matrix; clean stationary synthetic PCM only');fig.tight_layout();fig.savefig(args.output/'piano-coverage-jitter.png',dpi=150);plt.close(fig)
print(json.dumps({k:v for k,v in summary.items() if k not in ['general_dsp_unchanged','source_sha256_lf','raw_sha256']},indent=2))
