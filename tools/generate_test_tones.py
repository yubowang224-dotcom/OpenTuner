"""Original synthetic acoustic-check signals; no copyrighted instrument samples."""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import sys
import wave

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'artifacts/test-tones')
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    rate=48000; duration=4.0; manifest=[]
    for name in ['220Hz','440Hz','880Hz','glide-220-880','step-220-440-880','silence-440']:
        pcm=array.array('h'); phase=0
        for i in range(int(rate*duration)):
            t=i/rate
            hz=float(name[:-2]) if name.endswith('Hz') else 440
            if name.startswith('glide'): hz=220*2**(2*t/duration)
            if name.startswith('step'): hz=220 if t<1.3 else 440 if t<2.6 else 880
            amplitude=.25
            if name.startswith('silence'):
                # 0–1s and 2–3s tone; 1–2s and 3–4s exact silence.
                amplitude=0 if int(t)%2 else amplitude
                edge=t%1
                amplitude*=min(1,edge/.01,(1-edge)/.01)
            # Outer 10ms fades protect the speaker, not a fake detector signal.
            envelope=max(0,min(1,t/.01,(duration-t)/.01))
            phase+=2*math.pi*hz/rate
            pcm.append(round(32767*amplitude*envelope*math.sin(phase)))
        if sys.byteorder!='little': pcm.byteswap()
        path=args.output/f'{name}.wav'
        with wave.open(str(path),'wb') as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate); f.writeframes(pcm.tobytes())
        manifest.append(dict(file=path.name,seconds=duration,sample_rate=rate,format='mono signed16 LE',peak_amplitude=.25,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (args.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(f'Generated {len(manifest)} original WAVs in {args.output.resolve()}')
if __name__=='__main__': main()
