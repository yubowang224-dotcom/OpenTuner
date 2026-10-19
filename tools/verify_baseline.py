"""Verify frozen comparator reverses to the recorded stage-2 source hashes."""
import hashlib
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
folder=root/'native/tests/baseline_stage2'
provenance=json.loads((folder/'provenance.json').read_text(encoding='utf-8'))
for original,expected in provenance['source_sha256'].items():
    content=(folder/Path(original).name).read_text(encoding='utf-8')
    content=content.replace('stage2baseline','opentune').replace('#include "analyzer.h"','#include "opentune/analyzer.h"')
    content=content.replace('    bool frameQualified = false; // observation adapter only, no algorithm change\n','').replace('    result.frameQualified=qualifiedCandidate;\n','')
    actual=hashlib.sha256(content.encode('utf-8')).hexdigest()
    if actual!=expected:raise SystemExit(f'Frozen baseline drift: {original}: {actual} != {expected}')
print('Frozen Stage2 baseline matches recorded original hashes after reversing declared adapters')
