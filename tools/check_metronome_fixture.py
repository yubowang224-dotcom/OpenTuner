"""Read-only check of a tiny production C++ metronome ABI snapshot."""
import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=Path('build/release-prep-dsp/transport-results/fixture.json'));a=p.parse_args()
expected=json.loads(Path('test/fixtures/metronome-transport.json').read_text(encoding='utf-8'));actual=json.loads(a.source.read_text(encoding='utf-8'))
assert expected==actual and len(actual)==19 and actual[0]==3 and actual[17]==2 and actual[18]>actual[4]
print('Committed production C++ metronome ABI3 paused fixture matches regenerated output; not phone evidence')
