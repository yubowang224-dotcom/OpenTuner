"""Tiny production PartialAnalyzer/ABI4 synthetic fixtures. Never a production PCM input."""
import argparse
import hashlib
import json
import math
from pathlib import Path

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=Path,default=root/'build/m3-dsp/partial-results')
parser.add_argument('--check',action='store_true')
parser.add_argument('--curve-source',type=Path,default=root/'build/m3-dsp/curve-loop')
args=parser.parse_args();dest=root/'test/fixtures/partial';dest.mkdir(parents=True,exist_ok=True)
sources=['native/src/partial_analyzer.cpp','native/include/opentune/partial_analyzer.h','native/tests/partial_tests.cpp','native/tests/partial_fixture.h']
manifest=dict(kind='Original host synthetic stiff-string PCM, production Analyzer and ABI4 serializer; not Android/real piano',sources_lf_sha256={p:hashlib.sha256((root/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in sources})
for name in ['fixture.json']+[f'fixture-{midi}.json' for midi in [33,45,57,69,81,93]]+[f'fixture-strong-{midi}.json' for midi in [33,45,57,69,81,93]]:
    data=json.loads((args.source/name).read_text(encoding='utf-8'))
    assert data[0]==4 and data[5]==2 and data[13]==0 and len(data)==64+4*data[57]
    if args.check:
        expected=json.loads((dest/name).read_text(encoding='utf-8'))
        assert len(data)==len(expected),name
        for index,(a,b) in enumerate(zip(data,expected)):
            assert math.isclose(a,b,abs_tol=1e-9 if index==51 else 1e-7,rel_tol=1e-7),(name,index,a,b)
    else:(dest/name).write_text(json.dumps(data,separators=(',',':'))+'\n',encoding='utf-8')
if args.check:assert json.loads((dest/'manifest.json').read_text(encoding='utf-8'))==manifest
else:(dest/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Thirteen tiny production partial fixtures match' if args.check else 'Thirteen production partial fixtures generated')

curve=json.loads((args.curve_source/'curve-offset.json').read_text(encoding='utf-8'))
assert curve[0]==4 and curve[59]==33 and curve[48]==0
if args.check:
    expected=json.loads((dest/'curve-offset.json').read_text(encoding='utf-8'))
    assert len(curve)==len(expected)
    assert all(math.isclose(x,y,abs_tol=1e-9 if i==51 else 1e-7,rel_tol=1e-7) for i,(x,y) in enumerate(zip(curve,expected)))
else:(dest/'curve-offset.json').write_text(json.dumps(curve,separators=(',',':'))+'\n',encoding='utf-8')
print('Cross-layer production curve-offset fixture matches')
