from PIL import Image, ImageDraw, ImageFilter
import numpy as np, os
# Run from the repo root: python3 design/logo/make_icons.py
SRC='design/logo/source.jpg'
OUT='design/logo'
BG=np.array([0x1B,0x21,0x24],float)
im=np.asarray(Image.open(SRC).convert('RGB')).astype(float)
h,w,_=im.shape
# estimate local background with a heavy blur of border-ish pixels: use per-pixel dist from mean bg colour
bgc=np.median(np.concatenate([im[:40].reshape(-1,3),im[-40:].reshape(-1,3),im[:,:40].reshape(-1,3),im[:,-40:].reshape(-1,3)]),axis=0)
d=np.linalg.norm(im-bgc,axis=2)
t0,t1=22,70
a=np.clip((d-t0)/(t1-t0),0,1)
# remove isolated specks outside the cork: keep largest blob region via dilation mask
mask=Image.fromarray((a>0.5).astype(np.uint8)*255).filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.MinFilter(9))
m=np.asarray(mask)>0
from collections import deque
# connected components (coarse) on downsampled mask
small=np.asarray(mask.resize((256,256)))>0
lab=np.zeros(small.shape,int);best=None;n=0
for y in range(256):
  for x in range(256):
    if small[y,x] and not lab[y,x]:
      n+=1;q=deque([(y,x)]);lab[y,x]=n;c=0
      while q:
        cy,cx=q.popleft();c+=1
        for dy,dx in((1,0),(-1,0),(0,1),(0,-1)):
          ny,nx=cy+dy,cx+dx
          if 0<=ny<256 and 0<=nx<256 and small[ny,nx] and not lab[ny,nx]:
            lab[ny,nx]=n;q.append((ny,nx))
      if best is None or c>best[1]: best=(n,c)
keep=np.asarray(Image.fromarray((lab==best[0]).astype(np.uint8)*255).resize((w,h)).filter(ImageFilter.MaxFilter(21)))>0
a=a*keep
af=np.maximum(a,1e-3)[...,None]
fg=np.clip((im-(1-af)*bgc)/af,0,255)
rgba=np.dstack([fg,a*255]).astype(np.uint8)
fgimg=Image.fromarray(rgba,'RGBA')
bbox=fgimg.getchannel('A').point(lambda v:255 if v>20 else 0).getbbox()
mark=fgimg.crop(bbox)
mark.save(f'{OUT}/mark-transparent.png')
print('bbox',bbox,mark.size)
def place(canvas,frac,bg=None):
  c=Image.new('RGBA',(canvas,canvas),(0,0,0,0) if bg is None else tuple(int(v) for v in BG)+(255,))
  s=frac*canvas/max(mark.size)
  mk=mark.resize((round(mark.width*s),round(mark.height*s)),Image.LANCZOS)
  c.alpha_composite(mk,((canvas-mk.width)//2,(canvas-mk.height)//2));return c
# master logo on slate
place(1024,0.62,bg=True).convert('RGB').save(f'{OUT}/logo.png')
place(1024,0.62).save(f'{OUT}/logo-transparent.png')
R='android/app/src/main/res'
dens={'mdpi':1,'hdpi':1.5,'xhdpi':2,'xxhdpi':3,'xxxhdpi':4}
def rounded(img,r):
  m=Image.new('L',img.size,0);ImageDraw.Draw(m).rounded_rectangle([0,0,img.width-1,img.height-1],r,fill=255)
  out=img.copy();out.putalpha(m);return out
def circle(img):
  m=Image.new('L',img.size,0);ImageDraw.Draw(m).ellipse([0,0,img.width-1,img.height-1],fill=255)
  out=img.copy();out.putalpha(m);return out
for k,f in dens.items():
  d=f'{R}/mipmap-{k}';os.makedirs(d,exist_ok=True)
  L=round(48*f); big=place(L*8,0.66,bg=True)
  rounded(big,L*8*0.18).resize((L,L),Image.LANCZOS).save(f'{d}/ic_launcher.png',optimize=True)
  circle(big).resize((L,L),Image.LANCZOS).save(f'{d}/ic_launcher_round.png',optimize=True)
  F=round(108*f)
  # adaptive: mark within the 66dp safe zone (~56% of 108)
  place(F*4,0.55).resize((F,F),Image.LANCZOS).save(f'{d}/ic_launcher_foreground.png',optimize=True)
# play-store style 512
rounded(place(2048,0.66,bg=True),0).resize((512,512),Image.LANCZOS).convert('RGB').save(f'{OUT}/ic_launcher-512.png')
# monochrome layer for Android 13 themed icons: the mark's silhouette
for k,f in dens.items():
  F=round(108*f); fg=place(F*4,0.55).resize((F,F),Image.LANCZOS)
  al=fg.getchannel('A'); mono=Image.new('RGBA',fg.size,(255,255,255,0)); mono.putalpha(al)
  mono.save(f'{R}/mipmap-{k}/ic_launcher_monochrome.png',optimize=True)
