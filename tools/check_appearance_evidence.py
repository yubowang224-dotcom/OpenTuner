"""Local appearance evidence, no phone or acoustic performance claims."""
import csv
import hashlib
import json
import subprocess
from pathlib import Path
import numpy as np

root = Path(__file__).resolve().parents[1]
out = root / 'artifacts/appearance2'
def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

old = rows(root / 'docs/evidence/wave-trigger10ms.csv')
new = rows(root / 'build/appearance-dsp/waveform-results/waveform.csv')
report = {'kind': 'Windows host synthetic tests, not Android measurement', 'trigger': {}}
for hz in sorted({r['hz'] for r in new}, key=float):
    a, b = [r for r in old if r['hz'] == hz], [r for r in new if r['hz'] == hz]
    report['trigger'][hz] = {'conditions': len(b), '10ms': sum(int(r['triggered']) for r in a), '20ms': sum(int(r['triggered']) for r in b)}
report['display_compute_ms'] = dict(zip(['median', 'p95'], np.percentile([float(r['compute_ms']) for r in new], [50,95])))
report['max_relative_sample_error'] = max(float(r['max_sample_error']) / float(r['amplitude']) for r in new)
report['alias_db_range'] = [min(float(r['attenuation_db']) for r in rows(root/'build/appearance-dsp/waveform-results/antialias.csv')), max(float(r['attenuation_db']) for r in rows(root/'build/appearance-dsp/waveform-results/antialias.csv'))]
report['additional_display_age_ms'] = {'maximum': max((float(a['start_seconds'])-float(b['start_seconds']))*1000 for a,b in zip(old,new)), 'mean': np.mean([(float(a['start_seconds'])-float(b['start_seconds']))*1000 for a,b in zip(old,new)])}
for filename in ['analyzer.cpp', 'pitch_tracker.cpp', 'features.cpp', 'c_api.cpp']:
    relative = 'native/src/' + filename
    baseline = subprocess.check_output(['git', 'show', '4ae838a:'+relative], cwd=root)
    current = (root/relative).read_bytes().replace(b'\r\n',b'\n')
    assert baseline.replace(b'\r\n',b'\n') == current, relative
report['pitch_sources_unchanged_from'] = '4ae838a'
a=rows(root/'artifacts/stage25-evaluation/frames.csv')
b=rows(root/'build/appearance-dsp/evaluation/frames.csv')
assert len(a)==len(b)
differences = sum(any(x[k]!=y[k] for k in x if k!='compute_ms') for x,y in zip(a,b))
assert differences == 0, differences
report['pitch_comparison']={'rows':len(a), 'non_timing_differences':differences}
(out/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
