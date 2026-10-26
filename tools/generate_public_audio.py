"""Regenerate original public WAVs from public format specs; requires numpy 2.3.5.
No source recordings or source PCM are read. Paths are relative to the requested root.
"""
from pathlib import Path
import argparse,hashlib,json,wave
import numpy as np
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def original_tone(spec,root):
    """New audio only; read input FORMAT, never input PCM. Preserve runtime contracts."""
    dst=root/spec['path']; rate=spec['rate']; frames=spec['frames']; channels=spec['channels']
    key=dst.stem.lower(); seed=int.from_bytes(hashlib.sha256(key.encode()).digest()[:8],'little')
    rng=np.random.default_rng(seed); t=np.arange(frames,dtype=np.float64)/rate
    duration=frames/rate; noise=rng.uniform(-1,1,frames)
    shot=any(x in key for x in ('shot','blast','launch','impact','break','explode'))
    loop=any(x in key for x in ('sustain','facing','shepard','lightning','flight','glide','shield')) and not any(x in key for x in ('ready','break'))
    ready=any(x in key for x in ('ready','complete','revive_full','mara','relay'))
    if loop:
        # Integer periods and a smooth end taper make safe loopable original tones.
        freq=max(1,round(110*duration))/max(duration,.001)
        y=.09*np.sin(2*np.pi*freq*t)+.035*np.sin(2*np.pi*(2*freq)*t)
        y*=.6+.4*np.sin(2*np.pi*round(4*duration)*t/max(duration,.001))**2
    elif shot:
        y=.48*noise*np.exp(-t*35)+.25*np.sin(2*np.pi*(90*t+7*(1-np.exp(-t*20))))*np.exp(-t*16)
    elif ready:
        gate=np.exp(-((np.mod(t,.22))/.12)**2)
        y=.16*(np.sin(2*np.pi*660*t)+.55*np.sin(2*np.pi*990*t))*gate*np.minimum(1,np.maximum(0,(duration-t)*15))
    else:
        y=(.16*noise+.10*np.sin(2*np.pi*380*t))*np.exp(-t*12)
        if any(x in key for x in ('drink','shake','consume','peel','open')):
            y=.12*noise*(.4+.6*np.sin(2*np.pi*9*t)**2)*np.exp(-t*max(1,3/max(duration,.1)))
    edge=min(256,frames//2)
    if edge:
        y[:edge]*=np.linspace(0,1,edge); y[-edge:]*=np.linspace(1,0,edge)
    pcm=np.int16(np.clip(y,-.85,.85)*32767)
    if channels>1:pcm=np.repeat(pcm[:,None],channels,axis=1)
    dst.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(dst),'wb') as w:
        w.setnchannels(channels);w.setsampwidth(2);w.setframerate(rate);w.writeframes(pcm.astype('<i2').tobytes())
    return dict(path=dst.name,rate=rate,frames=frames,channels=channels,sha256=sha(dst),origin='New original procedural sound; no source PCM read')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--spec',required=True,type=Path);parser.add_argument('--root',required=True,type=Path);args=parser.parse_args()
    count=0
    for item in json.loads(args.spec.read_text())['files']:
        destination=(args.root/item['path']).resolve()
        if not destination.is_relative_to(args.root.resolve()):raise ValueError('Unsafe specification path')
        result=original_tone(item,args.root)
        if result['sha256']!=item['sha256']:raise ValueError('Generated sound differs: '+item['path'])
        count+=1
    print('Regenerated and hash-verified',count,'original sounds')
