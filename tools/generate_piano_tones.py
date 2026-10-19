"""Original M2 external-speaker test tones; not calibrated acoustic references."""
import argparse
import array
import json
import math
from pathlib import Path
import sys
import wave

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,default=Path('artifacts/m2/test-tones'))
args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
rate=48000;manifest=[]
for note,midi,a4 in [('A0',21,440),('A2',45,440),('A4',69,440),('C7',96,440),('C8',108,440),('A0',21,400),('C8',108,480),('A4',69,442)]:
    hz=a4*2**((midi-69)/12);pcm=array.array('h')
    for i in range(rate*4):
        t=i/rate
        envelope=min(1,t/.03,max(0,(4-t)/.03))
        # Silence on both sides makes onset/loss checks repeatable.
        value=0 if t<.5 or t>3.5 else .2*envelope*math.sin(2*math.pi*hz*(t-.5))
        # Smooth the actual tone segment, not just the file boundaries.
        value*=max(0,min(1,(t-.5)/.03,(3.5-t)/.03))
        pcm.append(round(value*32767))
    if sys.byteorder!='little':pcm.byteswap()
    name=f'{note}-a4-{a4}.wav'
    with wave.open(str(args.output/name),'wb') as output:
        output.setparams((1,2,rate,0,'NONE','not compressed'));output.writeframes(pcm.tobytes())
    manifest.append(dict(file=name,hz=hz,a4=a4,midi=midi,rate=rate,active_seconds=[.5,3.5]))
(args.output/'manifest.json').write_text(json.dumps(dict(kind='synthetic PCM for external computer speaker, not phone precision certification',tones=manifest),indent=2)+'\n',encoding='utf-8')
print(f'Generated {len(manifest)} original 4-second PCM files in {args.output.resolve()}')
