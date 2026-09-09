"""Encode rendered canvas frames as GIFs; no artwork generation or retouching."""
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parent
for name in ['overview','east','bones']:
    frames=[Image.open(p).convert('RGB') for p in sorted((root/'frames').glob(f'{name}_*.png'))]
    assert len(frames)==24
    palette=frames[0].quantize(colors=256)
    frames=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    frames[0].save(root/f'{name}.gif',save_all=True,append_images=frames[1:],duration=40,loop=0,disposal=2)
    with Image.open(root/f'{name}.gif') as result:
        assert result.n_frames==24
    print(name, '24 frames, 960ms, infinite repeat')

sheet=Image.open(root/'hunter_walk_24x8.png')
assert sheet.mode=='RGBA' and sheet.getextrema()[3][0]==0
assert sheet.size==(6144,2048)
print('Transparent sheet verified:',sheet.size)
for row,direction in enumerate(['S','SW','W','NW','N','NE','E','SE']):
    frames=[]
    for col in range(24):
        frame=Image.new('RGB',(256,256),'#20323d')
        tile=sheet.crop((col*256,row*256,(col+1)*256,(row+1)*256))
        frame.paste(tile,(0,0),tile)
        frames.append(frame)
    palette=frames[0].quantize(colors=256)
    frames=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    frames[0].save(root/f'walk_{direction}.gif',save_all=True,append_images=frames[1:],duration=40,loop=0,disposal=2)
