"""Reviewable small synthetic C++ display/FFT fixtures; no phone recordings.

Generate with CTest display_pcm_waveform, then --update explicitly. CI uses
--check after native tests. Flutter tests use checked-in fixtures, never build/.
"""
import argparse
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=root / 'build/dsp/waveform-results')
parser.add_argument('--update', action='store_true')
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
destination = root / 'test/fixtures/waveform'
manifest = {'source': 'native/tests/waveform_tests.cpp and production WaveformDisplay/Analyzer',
            'kind': 'original synthetic signals, not microphone recordings',
            'sample_rate': 48000, 'input_ms': 80, 'display_ms': 20, 'trigger_search_ms': 20, 'sha256': {}}
for name in ['sine440', 'dual', 'silence', 'noise']:
    filename = name + '.json'
    source = args.source / filename
    generated = json.loads(source.read_text(encoding='utf-8'))
    if args.update:
        destination.mkdir(parents=True, exist_ok=True)
        # C++ ofstream uses CRLF on Windows; repository text uses LF. Hash the
        # canonical text so a fresh Linux checkout reproduces the same manifest.
        (destination / filename).write_text(source.read_text(encoding='utf-8'), encoding='utf-8', newline='\n')
    expected = json.loads((destination / filename).read_text(encoding='utf-8'))
    for key in generated:
        actual, reference = generated[key], expected[key]
        tolerance = 1e-4 if key == 'spectrum' else 1e-6 if key == 'samples' else 1e-9
        if isinstance(actual, list):
            assert len(actual) == len(reference), (name, key, 'length')
            assert max(abs(a-b) for a,b in zip(actual, reference)) <= tolerance, (name, key)
        elif isinstance(actual, (int, float)) and not isinstance(actual, bool):
            assert abs(actual-reference) <= tolerance, (name, key)
        else:
            assert actual == reference, (name, key)
    manifest['sha256'][filename] = hashlib.sha256((destination / filename).read_text(encoding='utf-8').encode('utf-8')).hexdigest()
if args.update:
    (destination / 'provenance.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
else:
    recorded = json.loads((destination / 'provenance.json').read_text(encoding='utf-8'))
    assert recorded['sha256'] == manifest['sha256'], 'Committed fixture hash drift'
print('Four committed synthetic waveform fixtures match regenerated native output')
